import Foundation

public struct DownloadJob: Identifiable, Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        case queued
        case downloading(progress: Double?)
        case done
        case failed(String)
    }

    public let id: UUID
    public let url: URL
    public let folder: URL
    public var title: String?
    public var status: Status

    public init(id: UUID = UUID(), url: URL, folder: URL, title: String? = nil, status: Status = .queued) {
        self.id = id
        self.url = url
        self.folder = folder
        self.title = title
        self.status = status
    }

    public var displayName: String { title ?? url.absoluteString }
    public var isActive: Bool {
        switch status {
        case .queued, .downloading: true
        case .done, .failed: false
        }
    }
}

/// The state of the download list: who waits, who runs (at most `maxConcurrent`), who finished.
/// It does no I/O; the app starts and stops the real processes and reports back.
public struct DownloadQueue: Sendable {
    public enum Outcome: Equatable, Sendable {
        case success
        case failure(String)
    }

    public enum RemoveAction: Equatable, Sendable {
        case removed
        case terminateProcess
        case unknown
    }

    public private(set) var jobs: [DownloadJob] = []
    public let maxConcurrent: Int
    private var cancelRequested: Set<UUID> = []

    public init(maxConcurrent: Int = 3) { self.maxConcurrent = maxConcurrent }

    public var isDownloading: Bool { jobs.contains { $0.isActive } }

    /// Adds one job per link, skipping a link already queued or running for the same folder.
    /// With `failWith` the jobs are added already failed (e.g. yt-dlp missing).
    public mutating func enqueue(_ urls: [URL], into folder: URL, failWith message: String? = nil) {
        for url in urls {
            if jobs.contains(where: { $0.isActive && $0.url == url && $0.folder == folder }) { continue }
            jobs.append(DownloadJob(url: url, folder: folder, status: message.map { .failed($0) } ?? .queued))
        }
    }

    /// Moves queued jobs to downloading while there is capacity, and returns the ones to launch.
    public mutating func startable() -> [DownloadJob] {
        var started: [DownloadJob] = []
        var running = jobs.filter { if case .downloading = $0.status { true } else { false } }.count
        for index in jobs.indices where jobs[index].status == .queued && running < maxConcurrent {
            jobs[index].status = .downloading(progress: nil)
            running += 1
            started.append(jobs[index])
        }
        return started
    }

    public mutating func update(_ id: UUID, title: String?, progress: Double?) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        if let title, jobs[index].title == nil { jobs[index].title = title }
        if let progress, case .downloading = jobs[index].status { jobs[index].status = .downloading(progress: progress) }
    }

    /// Records how a running job ended. A job that finished successfully is kept even if a
    /// cancel was requested a moment earlier (its file is already in the library); a cancelled
    /// job that failed disappears.
    public mutating func finish(_ id: UUID, outcome: Outcome) {
        let wasCancelled = cancelRequested.remove(id) != nil
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        switch outcome {
        case .success:
            jobs[index].status = .done
        case .failure(let message):
            if wasCancelled { jobs.remove(at: index) } else { jobs[index].status = .failed(message) }
        }
    }

    /// Cancels a running job (the caller must terminate its process) or removes any other one.
    public mutating func remove(_ id: UUID) -> RemoveAction {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return .unknown }
        if case .downloading = jobs[index].status {
            cancelRequested.insert(id)
            return .terminateProcess
        }
        jobs.remove(at: index)
        return .removed
    }

    public mutating func clearDone() { jobs.removeAll { $0.status == .done } }
}
