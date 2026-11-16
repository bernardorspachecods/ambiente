import Foundation

/// Pure helpers for the yt-dlp integration: validating input, building
/// arguments and reading progress. Running the process lives in the app target.
public enum YouTubeDownload {
    /// Returns the URL if it is an http(s) link, otherwise nil.
    public static func validatedURL(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host, host.contains(".")
        else { return nil }
        return url
    }

    /// Arguments for a single-video audio download into `folder` as m4a.
    /// `--` ends option parsing so a link can never be read as a flag.
    public static func arguments(url: URL, folder: URL, ffmpeg: URL?) -> [String] {
        var args = [
            "--no-playlist",
            "--newline",
            "--no-colors",
            "-x", "--audio-format", "m4a", "--audio-quality", "0",
            "--embed-thumbnail", "--embed-metadata",
            "-o", folder.appendingPathComponent("%(title)s.%(ext)s").path,
        ]
        if let ffmpeg { args += ["--ffmpeg-location", ffmpeg.path] }
        args += ["--", url.absoluteString]
        return args
    }

    /// Download percentage (0...1) from a yt-dlp output line such as
    /// `[download]  42.3% of 3.21MiB at ...`, or nil for other lines.
    public static func progress(fromLine line: String) -> Double? {
        guard line.hasPrefix("[download]"),
              let end = line.firstIndex(of: "%") else { return nil }
        let head = line[line.index(line.startIndex, offsetBy: "[download]".count)..<end]
        guard let value = Double(head.trimmingCharacters(in: .whitespaces)) else { return nil }
        return min(max(value / 100, 0), 1)
    }

    /// A readable message from yt-dlp's output: its last `ERROR:` line, else a fallback.
    public static func errorMessage(fromOutput output: String) -> String {
        let line = output.split(whereSeparator: \.isNewline)
            .last { $0.hasPrefix("ERROR:") }
            .map { String($0.dropFirst("ERROR:".count)).trimmingCharacters(in: .whitespaces) }
        return line ?? "O download falhou."
    }
}
