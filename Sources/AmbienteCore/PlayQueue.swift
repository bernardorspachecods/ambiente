import Foundation

/// How playback continues after the last track of a round.
public enum RepeatMode: String, Sendable, CaseIterable {
    case off, all, one
}

/// Playback order over a set of tracks, in file order or shuffled.
/// A shuffled round plays every track once; a new round is reshuffled and
/// never starts with the track that just played (when there is more than one).
public struct PlayQueue: Sendable {
    public typealias Shuffler = @Sendable ([URL]) -> [URL]

    private let shuffler: Shuffler
    private var tracks: [URL]
    private var order: [URL]
    private var position: Int
    public private(set) var isShuffled: Bool

    public init(tracks: [URL], shuffled: Bool = true, shuffler: @escaping Shuffler = { $0.shuffled() }) {
        self.shuffler = shuffler
        self.tracks = tracks
        self.isShuffled = shuffled
        self.order = shuffled ? shuffler(tracks) : tracks
        self.position = 0
    }

    public var current: URL? { order.indices.contains(position) ? order[position] : nil }
    public var isEmpty: Bool { order.isEmpty }
    public var count: Int { order.count }

    /// Switches shuffle on or off without interrupting the current track.
    public mutating func setShuffled(_ shuffled: Bool) {
        guard shuffled != isShuffled else { return }
        isShuffled = shuffled
        let playing = current
        if shuffled {
            order = (playing.map { [$0] } ?? []) + shuffler(tracks.filter { $0 != playing })
            position = 0
        } else {
            order = tracks
            position = playing.flatMap { tracks.firstIndex(of: $0) } ?? 0
        }
    }

    /// Advances and returns the next track. At the end of a round it starts a new
    /// one when `wrap` is true, otherwise it returns nil and stays on the last track.
    @discardableResult
    public mutating func next(wrap: Bool = true) -> URL? {
        guard !order.isEmpty else { return nil }
        if position + 1 < order.count {
            position += 1
        } else {
            guard wrap else { return nil }
            let last = order[position]
            var round = isShuffled ? shuffler(tracks) : tracks
            if isShuffled, round.count > 1, round[0] == last { round.swapAt(0, round.count - 1) }
            order = round
            position = 0
        }
        return current
    }

    /// Goes back one track; at the start of a round it stays on the first track.
    @discardableResult
    public mutating func previous() -> URL? {
        guard !order.isEmpty else { return nil }
        position = max(0, position - 1)
        return current
    }

    /// Goes back to the first track of the round.
    public mutating func rewind() { position = 0 }

    /// Syncs with the folder's current contents without interrupting the playing track.
    /// Returns false when the playing track no longer exists (caller should restart the queue).
    @discardableResult
    public mutating func update(tracks newTracks: [URL]) -> Bool {
        let available = Set(newTracks)
        guard let playing = current, available.contains(playing) else { return false }
        if isShuffled {
            let played = order[..<position].filter(available.contains)
            let known = Set(order)
            let upcoming = order[(position + 1)...].filter(available.contains)
            let added = newTracks.filter { !known.contains($0) }
            order = played + [playing] + shuffler(upcoming + added)
            position = played.count
        } else {
            order = newTracks
            position = newTracks.firstIndex(of: playing) ?? 0
        }
        tracks = newTracks
        return true
    }
}
