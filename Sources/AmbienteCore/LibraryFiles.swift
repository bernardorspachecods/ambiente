import Foundation

public enum LibraryFileError: LocalizedError, Equatable {
    case invalidName
    case alreadyExists
    case nothingProduced
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidName: "That name isn't valid."
        case .alreadyExists: "Something with that name already exists."
        case .nothingProduced: "The download finished but no audio file was produced."
        case .failed(let message): message
        }
    }
}

/// File operations on the library. Pure file system, so they are tested on temporary folders.
public enum LibraryFiles {
    /// Renames a track's file, keeping its extension. Returns the new URL.
    public static func renameTrack(_ url: URL, to input: String, fileManager fm: FileManager = .default) throws -> URL {
        guard var name = AudioLibrary.sanitizedFolderName(input) else { throw LibraryFileError.invalidName }
        let ext = url.pathExtension
        if !ext.isEmpty, name.lowercased().hasSuffix("." + ext.lowercased()) {
            name = String(name.dropLast(ext.count + 1))
        }
        guard !name.isEmpty else { throw LibraryFileError.invalidName }
        let target = url.deletingLastPathComponent().appendingPathComponent(name).appendingPathExtension(ext)
        try move(url, to: target, fileManager: fm)
        return target
    }

    /// Renames an ambiente folder inside `root`. Returns the new URL.
    public static func renameFolder(_ folder: URL, in root: URL, to input: String, fileManager fm: FileManager = .default) throws -> URL {
        guard let name = AudioLibrary.sanitizedFolderName(input) else { throw LibraryFileError.invalidName }
        let target = root.appendingPathComponent(name, isDirectory: true)
        try move(folder, to: target, fileManager: fm)
        return target
    }

    /// Moves `source` to `target`. Refuses to replace anything, except that a change of
    /// letter case only goes through a temporary name (the file system sees both names
    /// as the same item) and is rolled back if the second step fails.
    private static func move(_ source: URL, to target: URL, fileManager fm: FileManager) throws {
        guard target != source else { return }
        let caseOnly = target.path.lowercased() == source.path.lowercased()
        guard caseOnly || !fm.fileExists(atPath: target.path) else { throw LibraryFileError.alreadyExists }
        do {
            if caseOnly {
                let temp = source.deletingLastPathComponent().appendingPathComponent(".rename-\(UUID().uuidString)")
                try fm.moveItem(at: source, to: temp)
                do {
                    try fm.moveItem(at: temp, to: target)
                } catch {
                    try? fm.moveItem(at: temp, to: source)
                    throw error
                }
            } else {
                try fm.moveItem(at: source, to: target)
            }
        } catch {
            throw LibraryFileError.failed(error.localizedDescription)
        }
    }

    /// Moves the finished `.m4a` files from `scratch` into `folder` (created if it vanished),
    /// never replacing an existing track: a taken name gets " (2)", " (3)"...
    /// The name is claimed by the move itself, so two downloads finishing together cannot collide.
    public static func publish(from scratch: URL, to folder: URL, fileManager fm: FileManager = .default) throws -> [URL] {
        let files = ((try? fm.contentsOfDirectory(at: scratch, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension.lowercased() == "m4a" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard !files.isEmpty else { throw LibraryFileError.nothingProduced }
        do { try fm.createDirectory(at: folder, withIntermediateDirectories: true) } catch {
            throw LibraryFileError.failed(error.localizedDescription)
        }
        var moved: [URL] = []
        for file in files {
            let base = file.deletingPathExtension().lastPathComponent
            var number = 1
            while true {
                let name = number == 1 ? "\(base).m4a" : "\(base) (\(number)).m4a"
                let target = folder.appendingPathComponent(name)
                do {
                    try fm.moveItem(at: file, to: target)
                    moved.append(target)
                    break
                } catch let error as CocoaError where error.code == .fileWriteFileExists && number < 1000 {
                    number += 1
                } catch {
                    throw LibraryFileError.failed(error.localizedDescription)
                }
            }
        }
        return moved
    }
}
