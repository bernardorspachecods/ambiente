import Foundation

/// Endless shuffled playback order over a set of tracks.
/// Plays every track once per round; a new round is reshuffled and never
/// starts with the track that just played (when there is more than one).
public struct ShuffleQueue: Sendable {
    public typealias Shuffler = @Sendable ([URL]) -> [URL]

    private let shuffler: Shuffler
    private var order: [URL]
    private var position: Int

    public init(tracks: [URL], shuffler: @escaping Shuffler = { $0.shuffled() }) {
        self.shuffler = shuffler
        self.order = shuffler(tracks)
        self.position = 0
    }

    public var current: URL? { order.indices.contains(position) ? order[position] : nil }
    public var isEmpty: Bool { order.isEmpty }
    public var count: Int { order.count }

    /// Advances and returns the next track, starting a new round at the end.
    @discardableResult
    public mutating func next() -> URL? {
        guard !order.isEmpty else { return nil }
        if position + 1 < order.count {
            position += 1
        } else {
            let last = order[position]
            var round = shuffler(order)
            if round.count > 1, round[0] == last { round.swapAt(0, round.count - 1) }
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

    /// Syncs with the folder's current contents without interrupting the playing track.
    /// Returns false when the playing track no longer exists (caller should restart the queue).
    @discardableResult
    public mutating func update(tracks: [URL]) -> Bool {
        let available = Set(tracks)
        guard let playing = current, available.contains(playing) else { return false }
        let played = order[..<position].filter(available.contains)
        let known = Set(order)
        let upcoming = order[(position + 1)...].filter(available.contains)
        let added = tracks.filter { !known.contains($0) }
        let tail = shuffler(upcoming + added)
        order = played + [playing] + tail
        position = played.count
        return true
    }
}
