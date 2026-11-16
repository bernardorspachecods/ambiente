import Foundation

/// Splits process output into lines on `\n` or `\r` (yt-dlp separates progress with either).
/// Works on bytes and decodes whole lines, so a multi-byte character split across two reads survives.
public struct LineSplitter: Sendable {
    private var buffer = Data()

    public init() {}

    public mutating func append(_ data: Data) -> [String] {
        buffer.append(data)
        var lines: [String] = []
        while let index = buffer.firstIndex(where: { $0 == 0x0A || $0 == 0x0D }) {
            let line = buffer[buffer.startIndex..<index]
            lines.append(String(decoding: line, as: UTF8.self))
            buffer = Data(buffer[buffer.index(after: index)...])
        }
        return lines
    }

    /// The last line, when the output did not end with a line break.
    public mutating func finish() -> [String] {
        defer { buffer = Data() }
        return buffer.isEmpty ? [] : [String(decoding: buffer, as: UTF8.self)]
    }
}

public enum YtDlpSource: Equatable, Sendable { case updated, bundled }

public enum BinaryChoice {
    /// The in-app updated copy wins only while it is newer than the one shipped in the app,
    /// so rebuilding the app with a newer yt-dlp is never shadowed by an older update.
    public static func ytDlp(updatedModified: Date?, bundledModified: Date?) -> YtDlpSource? {
        switch (updatedModified, bundledModified) {
        case (nil, nil): nil
        case (let updated?, nil): .updated
        case (nil, _?): .bundled
        case (let updated?, let bundled?): updated > bundled ? .updated : .bundled
        }
    }
}

/// Stops the player from skipping forever through a folder of unplayable files.
public struct PlaybackFailureGuard: Sendable {
    private var failures = 0

    public init() {}

    /// True if it is worth trying the next track (fewer failures in a row than tracks).
    public mutating func shouldSkip(afterFailureIn trackCount: Int) -> Bool {
        failures += 1
        return failures < trackCount
    }

    public mutating func recordSuccess() { failures = 0 }
}
