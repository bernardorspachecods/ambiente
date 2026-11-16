import AmbienteCore
import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class DownloadModel {
    struct Job: Identifiable, Equatable {
        enum Status: Equatable {
            case queued
            case downloading(progress: Double?)
            case done
            case failed(String)
        }

        let id = UUID()
        let url: URL
        let folder: URL
        var title: String?
        var status: Status = .queued

        var displayName: String { title ?? url.absoluteString }
        var isActive: Bool {
            switch status {
            case .queued, .downloading: true
            case .done, .failed: false
            }
        }
    }

    enum UpdateState: Equatable {
        case idle
        case updating
        case failed(String)
    }

    private(set) var jobs: [Job] = []
    /// Called on the main actor each time a track lands in the library.
    @ObservationIgnored var onTrackAdded: (() -> Void)?
    static let maxConcurrent = 3
    private(set) var updateState: UpdateState = .idle
    private(set) var installedVersion: String?
    private(set) var latestVersion: String?
    @ObservationIgnored private var lastCheck: Date?

    /// True only when GitHub has a newer yt-dlp than the one in use.
    var updateAvailable: Bool {
        guard let installed = installedVersion, let latest = latestVersion else { return false }
        return Self.isNewer(latest, than: installed)
    }

    nonisolated static func isNewer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").compactMap { Int($0) }
        let y = b.split(separator: ".").compactMap { Int($0) }
        guard !x.isEmpty, !y.isEmpty else { return false }
        return x.lexicographicallyPrecedes(y) == false && x != y
    }

    var isBusy: Bool { updateState == .updating }
    var isDownloading: Bool { jobs.contains { $0.isActive } }

    @ObservationIgnored private var processes: [UUID: Process] = [:]
    @ObservationIgnored private var cancelled: Set<UUID> = []

    private static var scratchRoot: URL { Binaries.supportDirectory.appendingPathComponent("downloads", isDirectory: true) }

    init() {
        // No download can be running at launch, so anything here is debris from an interrupted one.
        try? FileManager.default.removeItem(at: Self.scratchRoot)
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.processes.values.forEach { $0.terminate() } }
        }
    }

    /// Moves finished m4a files from `scratch` into `folder`, never overwriting existing tracks.
    private nonisolated static func publish(from scratch: URL, to folder: URL) -> Bool {
        let fm = FileManager.default
        let files = ((try? fm.contentsOfDirectory(at: scratch, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension.lowercased() == "m4a" }
        guard !files.isEmpty else { return false }
        for file in files {
            var target = folder.appendingPathComponent(file.lastPathComponent)
            var n = 2
            while fm.fileExists(atPath: target.path) {
                let base = file.deletingPathExtension().lastPathComponent
                target = folder.appendingPathComponent("\(base) (\(n)).m4a")
                n += 1
            }
            guard (try? fm.moveItem(at: file, to: target)) != nil else { return false }
        }
        return true
    }

    // MARK: Jobs

    /// Queues one download per link into `folder`; up to `maxConcurrent` run at once.
    func enqueue(_ urls: [URL], into folder: URL) {
        for url in urls {
            if jobs.contains(where: { $0.isActive && $0.url == url && $0.folder == folder }) { continue }
            var job = Job(url: url, folder: folder)
            if Binaries.ytDlp == nil {
                job.status = .failed("yt-dlp not found in the app. Run scripts/fetch-binaries.sh and rebuild the app.")
            }
            jobs.append(job)
        }
        pump()
    }

    /// Cancels an active job or dismisses a finished one.
    func remove(_ id: UUID) {
        if let process = processes[id] {
            cancelled.insert(id)
            process.terminate()
        } else {
            jobs.removeAll { $0.id == id }
        }
    }

    func clearDone() {
        jobs.removeAll { $0.status == .done }
    }

    private func update(_ id: UUID, _ change: (inout Job) -> Void) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        change(&jobs[index])
    }

    private func pump() {
        while processes.count < Self.maxConcurrent,
              let next = jobs.first(where: { $0.status == .queued && processes[$0.id] == nil }) {
            start(next)
        }
    }

    private func start(_ job: Job) {
        guard let ytDlp = Binaries.ytDlp else {
            update(job.id) { $0.status = .failed("yt-dlp not found in the app.") }
            return
        }
        let id = job.id
        let folder = job.folder
        update(id) { $0.status = .downloading(progress: nil) }

        // Work in a scratch folder and publish only a finished file, so an interrupted
        // download never leaves a truncated track (or its .webm/.webp leftovers) in the library.
        let scratch = Self.scratchRoot.appendingPathComponent(id.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)

        let proc = Process()
        proc.executableURL = ytDlp
        proc.arguments = YouTubeDownload.arguments(url: job.url, folder: scratch, ffmpeg: Binaries.ffmpeg)
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        let collector = OutputCollector { [weak self] line in
            let progress = YouTubeDownload.progress(fromLine: line)
            let title = YouTubeDownload.title(fromLine: line)
            guard progress != nil || title != nil else { return }
            Task { @MainActor in
                self?.update(id) { job in
                    if let title, job.title == nil { job.title = title }
                    if let progress, case .downloading = job.status { job.status = .downloading(progress: progress) }
                }
            }
        }
        pipe.fileHandleForReading.readabilityHandler = { handle in
            collector.append(handle.availableData)
        }
        proc.terminationHandler = { [weak self] finished in
            pipe.fileHandleForReading.readabilityHandler = nil
            collector.append(pipe.fileHandleForReading.readDataToEndOfFile())
            let output = collector.text
            let status = finished.terminationStatus
            let published = status == 0 && Self.publish(from: scratch, to: folder)
            try? FileManager.default.removeItem(at: scratch)
            Task { @MainActor in
                guard let self else { return }
                self.processes[id] = nil
                if self.cancelled.remove(id) != nil {
                    self.jobs.removeAll { $0.id == id }
                } else if status == 0, !published {
                    self.update(id) { $0.status = .failed("The download finished but no audio file was produced.") }
                } else if status == 0 {
                    self.update(id) { $0.status = .done }
                    self.onTrackAdded?()
                } else {
                    self.update(id) { $0.status = .failed(YouTubeDownload.errorMessage(fromOutput: output)) }
                }
                self.pump()
            }
        }
        do {
            try proc.run()
            processes[id] = proc
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            try? FileManager.default.removeItem(at: scratch)
            update(id) { $0.status = .failed("Could not run yt-dlp: \(error.localizedDescription)") }
        }
    }

    // MARK: yt-dlp updates

    /// Reads the installed version and asks GitHub for the latest one.
    /// Throttled to once every 6 hours unless `force` is set; failures stay silent.
    func checkForUpdate(force: Bool = false) {
        if !force, let lastCheck, Date().timeIntervalSince(lastCheck) < 6 * 3600 { return }
        guard let ytDlp = Binaries.ytDlp else { return }
        lastCheck = Date()
        Task {
            let installed = await Task.detached { try? Self.run(ytDlp, ["--version"]) }.value
            let latest = await Task.detached { try? await Self.fetchLatestVersion() }.value
            if let installed { installedVersion = installed }
            if let latest { latestVersion = latest }
        }
    }

    /// Downloads the latest standalone yt-dlp into Application Support and checks it runs.
    func updateYtDlp() {
        guard !isBusy else { return }
        updateState = .updating
        Task {
            do {
                let version = try await Self.fetchLatestYtDlp()
                installedVersion = version
                latestVersion = version
                updateState = .idle
            } catch {
                updateState = .failed(error.localizedDescription)
            }
        }
    }

    private nonisolated static func fetchLatestVersion() async throws -> String {
        let url = URL(string: "https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest")!
        let (data, _) = try await URLSession.shared.data(from: url)
        struct Release: Decodable { let tag_name: String }
        return try JSONDecoder().decode(Release.self, from: data).tag_name
    }

    private nonisolated static func fetchLatestYtDlp() async throws -> String {
        let source = URL(string: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos")!
        let (temp, response) = try await URLSession.shared.download(from: source)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw UpdateError("GitHub did not respond as expected.")
        }
        let fm = FileManager.default
        try fm.createDirectory(at: Binaries.supportDirectory, withIntermediateDirectories: true)
        let staged = Binaries.supportDirectory.appendingPathComponent("yt-dlp.new")
        try? fm.removeItem(at: staged)
        try fm.moveItem(at: temp, to: staged)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: staged.path)

        // Only replace the working copy if the new one actually runs.
        let version = try run(staged, ["--version"])
        guard !version.isEmpty else { throw UpdateError("The downloaded yt-dlp does not start.") }
        _ = try fm.replaceItemAt(Binaries.updatedYtDlp, withItemAt: staged)
        return version
    }

    private nonisolated static func run(_ executable: URL, _ args: [String]) throws -> String {
        let proc = Process()
        proc.executableURL = executable
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        try proc.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else { throw UpdateError("The downloaded yt-dlp does not start.") }
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct UpdateError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

/// Thread-safe accumulator that emits complete lines (yt-dlp separates progress with \n or \r).
private final class OutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = ""
    private var all = ""
    private let onLine: @Sendable (String) -> Void

    init(onLine: @escaping @Sendable (String) -> Void) { self.onLine = onLine }

    var text: String { lock.withLock { all } }

    func append(_ data: Data) {
        guard !data.isEmpty else { return }
        let chunk = String(decoding: data, as: UTF8.self)
        var lines: [String] = []
        lock.withLock {
            all += chunk
            buffer += chunk
            let parts = buffer.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "\n" || $0 == "\r" })
            buffer = String(parts.last ?? "")
            lines = parts.dropLast().map(String.init)
        }
        lines.forEach(onLine)
    }
}
