import AmbienteCore
import Foundation
import Observation

@MainActor
@Observable
final class DownloadModel {
    enum State: Equatable {
        case idle
        case downloading(progress: Double?)
        case done(String)
        case failed(String)
    }

    enum UpdateState: Equatable {
        case idle
        case updating
        case updated(String)
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var updateState: UpdateState = .idle

    var isBusy: Bool {
        if case .downloading = state { return true }
        return updateState == .updating
    }

    @ObservationIgnored private var process: Process?

    /// Downloads one video's audio as m4a into `folder`. Calls `onFinish` on success.
    func download(link: String, into folder: AmbienteFolder, onFinish: @escaping () -> Void) {
        guard !isBusy else { return }
        guard let url = YouTubeDownload.validatedURL(link) else {
            state = .failed("Isto não parece um link válido (http/https).")
            return
        }
        guard let ytDlp = Binaries.ytDlp else {
            state = .failed("yt-dlp não encontrado na app. Corre scripts/fetch-binaries.sh e volta a gerar a app.")
            return
        }
        state = .downloading(progress: nil)

        let proc = Process()
        proc.executableURL = ytDlp
        proc.arguments = YouTubeDownload.arguments(url: url, folder: folder.url, ffmpeg: Binaries.ffmpeg)
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        let collector = OutputCollector { [weak self] line in
            guard let progress = YouTubeDownload.progress(fromLine: line) else { return }
            Task { @MainActor in
                guard let self, case .downloading = self.state else { return }
                self.state = .downloading(progress: progress)
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
            Task { @MainActor in
                guard let self else { return }
                self.process = nil
                if status == 0 {
                    self.state = .done("Faixa adicionada a \(folder.name).")
                    onFinish()
                } else if finished.terminationReason == .uncaughtSignal {
                    self.state = .idle
                } else {
                    self.state = .failed(YouTubeDownload.errorMessage(fromOutput: output))
                }
            }
        }
        do {
            try proc.run()
            process = proc
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            state = .failed("Não consegui executar o yt-dlp: \(error.localizedDescription)")
        }
    }

    func cancel() {
        process?.terminate()
    }

    func dismissStatus() {
        if !isBusy { state = .idle }
    }

    // MARK: yt-dlp updater

    /// Downloads the latest standalone yt-dlp into Application Support and checks it runs.
    func updateYtDlp() {
        guard !isBusy else { return }
        updateState = .updating
        Task {
            do {
                let version = try await Self.fetchLatestYtDlp()
                updateState = .updated("yt-dlp \(version)")
            } catch {
                updateState = .failed(error.localizedDescription)
            }
        }
    }

    private nonisolated static func fetchLatestYtDlp() async throws -> String {
        let source = URL(string: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos")!
        let (temp, response) = try await URLSession.shared.download(from: source)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw UpdateError("O GitHub não respondeu como esperado.")
        }
        let fm = FileManager.default
        try fm.createDirectory(at: Binaries.supportDirectory, withIntermediateDirectories: true)
        let staged = Binaries.supportDirectory.appendingPathComponent("yt-dlp.new")
        try? fm.removeItem(at: staged)
        try fm.moveItem(at: temp, to: staged)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: staged.path)

        // Only replace the working copy if the new one actually runs.
        let version = try run(staged, ["--version"])
        guard !version.isEmpty else { throw UpdateError("O yt-dlp descarregado não arranca.") }
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
        guard proc.terminationStatus == 0 else { throw UpdateError("O yt-dlp descarregado não arranca.") }
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
