import AVFoundation
import AmbienteCore
import MediaPlayer
import Observation

@MainActor
@Observable
final class PlayerModel {
    private(set) var folders: [AmbienteFolder] = []
    private(set) var activeFolder: AmbienteFolder?
    private(set) var trackTitle: String?
    private(set) var trackArtist: String?
    private(set) var isPlaying = false
    private(set) var trackCount = 0

    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0

    var shuffle: Bool {
        didSet {
            queue.setShuffled(shuffle)
            UserDefaults.standard.set(shuffle, forKey: Keys.shuffle)
        }
    }

    var repeatMode: RepeatMode {
        didSet { UserDefaults.standard.set(repeatMode.rawValue, forKey: Keys.repeatMode) }
    }

    var volume: Double {
        didSet {
            player.volume = Float(volume)
            UserDefaults.standard.set(volume, forKey: Keys.volume)
        }
    }

    let root: URL
    @ObservationIgnored private let player = AVPlayer()
    @ObservationIgnored private var queue = PlayQueue(tracks: [], shuffled: true)
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var metadataTask: Task<Void, Never>?

    private enum Keys {
        static let folder = "lastAmbiente"
        static let volume = "volume"
        static let shuffle = "shuffle"
        static let repeatMode = "repeatMode"
    }

    init(root: URL = AudioLibrary.defaultRoot) {
        self.root = root
        let stored = UserDefaults.standard.object(forKey: Keys.volume) as? Double
        self.volume = stored ?? 0.7
        self.shuffle = UserDefaults.standard.object(forKey: Keys.shuffle) as? Bool ?? true
        self.repeatMode = UserDefaults.standard.string(forKey: Keys.repeatMode).flatMap(RepeatMode.init) ?? .all
        player.volume = Float(volume)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        refreshFolders()
        // Restore the last ambiente (ready to play, not auto-playing).
        if let name = UserDefaults.standard.string(forKey: Keys.folder),
           let folder = folders.first(where: { $0.name == name }) {
            select(folder, autoplay: false)
        }
        setupRemoteCommands()
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                let seconds = time.seconds
                if seconds.isFinite { self.currentTime = seconds }
            }
        }
    }

    func seek(to seconds: Double) {
        currentTime = seconds
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        updateNowPlaying()
    }

    func cycleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    // MARK: Library

    func refreshFolders() {
        folders = AudioLibrary.folders(in: root)
        if let active = activeFolder {
            if folders.contains(active) {
                reloadActiveTracks()
            } else {
                stop()
            }
        }
    }

    /// Re-reads the active folder (after a download or when the menu opens)
    /// without interrupting the track that is playing.
    func reloadActiveTracks() {
        guard let folder = activeFolder else { return }
        let tracks = AudioLibrary.tracks(in: folder.url)
        trackCount = tracks.count
        if queue.isEmpty {
            queue = PlayQueue(tracks: tracks, shuffled: shuffle)
            if isPlaying { playCurrent() } else { prepareCurrent() }
        } else if !queue.update(tracks: tracks) {
            queue = PlayQueue(tracks: tracks, shuffled: shuffle)
            if isPlaying { playCurrent() } else { prepareCurrent() }
        }
    }

    // MARK: Playback

    func select(_ folder: AmbienteFolder, autoplay: Bool = true) {
        UserDefaults.standard.set(folder.name, forKey: Keys.folder)
        activeFolder = folder
        let tracks = AudioLibrary.tracks(in: folder.url)
        trackCount = tracks.count
        queue = PlayQueue(tracks: tracks, shuffled: shuffle)
        if autoplay { playCurrent() } else { prepareCurrent() }
    }

    func togglePlayPause() {
        if isPlaying {
            player.pause()
            isPlaying = false
            updateNowPlaying()
        } else if player.currentItem != nil {
            player.play()
            isPlaying = true
            updateNowPlaying()
        } else {
            playCurrent()
        }
    }

    func next() {
        guard queue.next() != nil else { return }
        playCurrent()
    }

    /// A track finished by itself: honour the repeat mode.
    private func trackEnded() {
        switch repeatMode {
        case .one:
            player.seek(to: .zero)
            player.play()
        case .all:
            next()
        case .off:
            if queue.next(wrap: false) != nil {
                playCurrent()
            } else {
                // End of the round: go back to the first track, paused.
                queue.rewind()
                prepareCurrent()
            }
        }
    }

    func previous() {
        // Past the first seconds, "previous" restarts the track, as in other players.
        if player.currentTime().seconds > 3 {
            player.seek(to: .zero)
            return
        }
        guard queue.previous() != nil else { return }
        playCurrent()
    }

    private func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        activeFolder = nil
        queue = PlayQueue(tracks: [], shuffled: true)
        trackCount = 0
        isPlaying = false
        trackTitle = nil
        trackArtist = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func playCurrent() {
        guard load(queue.current) else {
            isPlaying = false
            return
        }
        player.play()
        isPlaying = true
        updateNowPlaying()
    }

    private func prepareCurrent() {
        _ = load(queue.current)
        isPlaying = false
        updateNowPlaying()
    }

    @discardableResult
    private func load(_ url: URL?) -> Bool {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        metadataTask?.cancel()
        guard let url else {
            player.replaceCurrentItem(with: nil)
            trackTitle = nil
            trackArtist = nil
            return false
        }
        currentTime = 0
        duration = 0
        let item = AVPlayerItem(url: url)
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.trackEnded() }
        }
        player.replaceCurrentItem(with: item)
        trackTitle = url.deletingPathExtension().lastPathComponent
        trackArtist = nil
        metadataTask = Task { [weak self] in
            let asset = AVURLAsset(url: url)
            let length = (try? await asset.load(.duration).seconds) ?? 0
            let items = (try? await asset.load(.commonMetadata)) ?? []
            let title = await Self.string(for: .commonIdentifierTitle, in: items)
            let artist = await Self.string(for: .commonIdentifierArtist, in: items)
            guard !Task.isCancelled, let self, self.queue.current == url else { return }
            if length.isFinite { self.duration = length }
            if let title, !title.isEmpty { self.trackTitle = title }
            self.trackArtist = artist
            self.updateNowPlaying()
        }
        return true
    }

    private static func string(for identifier: AVMetadataIdentifier, in items: [AVMetadataItem]) async -> String? {
        guard let item = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: identifier).first else { return nil }
        return try? await item.load(.stringValue)
    }

    // MARK: Now Playing and media keys

    private func updateNowPlaying() {
        guard trackTitle != nil else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: trackTitle ?? "",
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPMediaItemPropertyPlaybackDuration: duration,
        ]
        if let trackArtist { info[MPMediaItemPropertyArtist] = trackArtist }
        if let activeFolder { info[MPMediaItemPropertyAlbumTitle] = activeFolder.name }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.isPlaying else { return .commandFailed }
                self.togglePlayPause()
                return .success
            }
        }
        center.pauseCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isPlaying else { return .commandFailed }
                self.togglePlayPause()
                return .success
            }
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return .commandFailed }
                self.togglePlayPause()
                return .success
            }
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.activeFolder != nil else { return .commandFailed }
                self.next()
                return .success
            }
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.activeFolder != nil else { return .commandFailed }
                self.previous()
                return .success
            }
        }
    }
}
