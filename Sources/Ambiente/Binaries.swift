import AmbienteCore
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

    /// The updated copy while it is newer than the bundled one, otherwise the bundled one.
    static var ytDlp: URL? {
        let fm = FileManager.default
        func usable(_ url: URL?) -> (url: URL, modified: Date?)? {
            guard let url, fm.isExecutableFile(atPath: url.path) else { return nil }
            return (url, (try? fm.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date)
        }
        let updated = usable(updatedYtDlp)
        let bundled = usable(bundledYtDlp)
        switch BinaryChoice.ytDlp(updatedModified: updated?.modified, bundledModified: bundled?.modified) {
        case .updated: return updated?.url
        case .bundled: return bundled?.url
        case nil: return updated?.url ?? bundled?.url
        }
    }
}
