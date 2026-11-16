import Foundation

/// Where the external tools live. yt-dlp can be replaced at runtime by a copy in
/// Application Support (so updating never touches the signed app); ffmpeg is bundled.
enum Binaries {
    static var supportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Ambiente", isDirectory: true)
    }

    static var updatedYtDlp: URL { supportDirectory.appendingPathComponent("yt-dlp") }
    static var bundledYtDlp: URL? { Bundle.main.resourceURL?.appendingPathComponent("yt-dlp") }
    static var ffmpeg: URL? { Bundle.main.resourceURL?.appendingPathComponent("ffmpeg") }

    /// Updated copy first, bundled copy as the fallback.
    static var ytDlp: URL? {
        let fm = FileManager.default
        if fm.isExecutableFile(atPath: updatedYtDlp.path) { return updatedYtDlp }
        if let bundled = bundledYtDlp, fm.isExecutableFile(atPath: bundled.path) { return bundled }
        return nil
    }
}
