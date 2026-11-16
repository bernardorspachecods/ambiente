import Foundation
@testable import AmbienteCore

// Foundation lives only in this file: the CommandLineTools Testing overlay
// (_Testing_Foundation) has no module, so a file must not import both.

func urls(_ names: [String]) -> [URL] { names.map { URL(fileURLWithPath: "/m/\($0).m4a") } }
func url(_ name: String) -> URL { urls([name])[0] }

func makeLibraryFixture() throws -> String {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent("ambiente-test-\(UUID().uuidString)")
    for dir in ["Lowfi", "Clássico", ".hidden"] {
        try fm.createDirectory(at: root.appendingPathComponent(dir), withIntermediateDirectories: true)
    }
    for file in ["loose.m4a", "Lowfi/one.m4a", "Lowfi/cover.jpg", "Lowfi/TWO.MP3"] {
        try Data().write(to: root.appendingPathComponent(file))
    }
    return root.path
}

func folderNames(root: String) -> [String] {
    AudioLibrary.folders(in: URL(fileURLWithPath: root)).map(\.name)
}

func trackNames(root: String, folder: String) -> [String] {
    AudioLibrary.tracks(in: URL(fileURLWithPath: root).appendingPathComponent(folder)).map(\.lastPathComponent)
}

func removeFixture(_ root: String) { try? FileManager.default.removeItem(atPath: root) }

func sampleArguments() -> [String] {
    YouTubeDownload.arguments(
        url: URL(string: "https://youtu.be/x")!,
        folder: URL(fileURLWithPath: "/m/Lowfi"),
        ffmpeg: URL(fileURLWithPath: "/app/ffmpeg"))
}

// MARK: File operation helpers (String-based so the Testing file needs no Foundation)

func makeTempRoot() throws -> String {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("ambiente-test-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root.path
}

func touch(_ root: String, _ paths: [String]) throws {
    for path in paths {
        let file = URL(fileURLWithPath: root).appendingPathComponent(path)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(path.utf8).write(to: file)
    }
}

/// Names (case preserved) of the items inside `root/dir`, sorted, including hidden ones.
func listing(_ root: String, _ dir: String = "") -> [String] {
    let url = URL(fileURLWithPath: root).appendingPathComponent(dir)
    return ((try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []).sorted()
}

func contents(_ root: String, _ path: String) -> String? {
    try? String(contentsOf: URL(fileURLWithPath: root).appendingPathComponent(path), encoding: .utf8)
}

/// Returns the new file name, or the error description.
func renameTrack(_ root: String, _ path: String, to name: String) -> String {
    do {
        return try LibraryFiles.renameTrack(URL(fileURLWithPath: root).appendingPathComponent(path), to: name).lastPathComponent
    } catch { return "error: \(error.localizedDescription)" }
}

func renameFolder(_ root: String, _ dir: String, to name: String) -> String {
    let base = URL(fileURLWithPath: root)
    do {
        return try LibraryFiles.renameFolder(base.appendingPathComponent(dir), in: base, to: name).lastPathComponent
    } catch { return "error: \(error.localizedDescription)" }
}

/// Publishes `scratch` into `folder` (both relative to root); returns moved file names or the error.
func publish(_ root: String, scratch: String, to folder: String) -> [String] {
    let base = URL(fileURLWithPath: root)
    do {
        return try LibraryFiles.publish(from: base.appendingPathComponent(scratch), to: base.appendingPathComponent(folder))
            .map(\.lastPathComponent)
    } catch { return ["error: \(error.localizedDescription)"] }
}

func splitLines(_ chunks: [[UInt8]]) -> [String] {
    var splitter = LineSplitter()
    var lines: [String] = []
    for chunk in chunks { lines += splitter.append(Data(chunk)) }
    return lines + splitter.finish()
}

func choiceName(updated: Double?, bundled: Double?) -> String {
    let result = BinaryChoice.ytDlp(
        updatedModified: updated.map { Date(timeIntervalSince1970: $0) },
        bundledModified: bundled.map { Date(timeIntervalSince1970: $0) })
    switch result {
    case .updated: return "updated"
    case .bundled: return "bundled"
    case nil: return "none"
    }
}

func installedState(_ path: String) -> Bool {
    AppLocation.isInstalled(bundlePath: path, home: "/Users/me")
}
