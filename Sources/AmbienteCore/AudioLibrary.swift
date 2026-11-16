import Foundation

/// A folder under the library root. Each subfolder is one "ambiente".
public struct AmbienteFolder: Identifiable, Hashable, Sendable {
    public let url: URL
    public var id: String { name }
    public var name: String { url.lastPathComponent }

    public init(url: URL) { self.url = url }
}

/// Reads the library from disk. No database: the folders are the truth.
public enum AudioLibrary {
    public static let audioExtensions: Set<String> = ["m4a", "mp3", "aac", "wav", "aiff", "aif", "caf", "flac"]

    public static var defaultRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Music/Ambiente", isDirectory: true)
    }

    /// Visible subfolders of `root`, sorted by name (locale-aware).
    public static func folders(in root: URL, fileManager: FileManager = .default) -> [AmbienteFolder] {
        let entries = (try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return entries
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .map(AmbienteFolder.init)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Playable audio files directly inside `folder`, sorted by name.
    public static func tracks(in folder: URL, fileManager: FileManager = .default) -> [URL] {
        let entries = (try? fileManager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        return entries
            .filter { audioExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    /// A safe folder name from user input: trimmed, no path separators or leading dots.
    /// Returns nil when nothing usable is left.
    public static func sanitizedFolderName(_ input: String) -> String? {
        let cleaned = input
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let name = String(cleaned.drop(while: { $0 == "." })).trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }
}
