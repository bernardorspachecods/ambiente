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
