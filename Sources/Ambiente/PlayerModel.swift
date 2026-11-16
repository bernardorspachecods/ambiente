import AppKit
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

    private(set) var artwork: NSImage?
    /// Bumped whenever files change on disk, so views listing tracks refresh.
    private(set) var libraryVersion = 0

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

    func tracks(in folder: AmbienteFolder) -> [URL] {
        AudioLibrary.tracks(in: folder.url)
    }

    var currentTrack: URL? { queue.current }

    func refreshFolders() {
        libraryVersion += 1
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

    /// Plays one specific track of a folder; the rest of the folder follows the shuffle/repeat modes.
    func play(track: URL, in folder: AmbienteFolder) {
        if activeFolder != folder {
            UserDefaults.standard.set(folder.name, forKey: Keys.folder)
            activeFolder = folder
            let all = AudioLibrary.tracks(in: folder.url)
            trackCount = all.count
            queue = PlayQueue(tracks: all, shuffled: shuffle)
        }
        guard queue.select(track) else { return }
        playCurrent()
    }

    // MARK: Renaming

    enum RenameError: LocalizedError {
        case invalidName, alreadyExists, failed(String)
        var errorDescription: String? {
            switch self {
            case .invalidName: "That name isn't valid."
            case .alreadyExists: "Something with that name already exists."
            case .failed(let message): message
            }
        }
    }

    /// Renames a track's file (the extension is kept). Playback continues if it is the current track.
    func renameTrack(_ url: URL, to input: String) throws {
        guard var name = AudioLibrary.sanitizedFolderName(input) else { throw RenameError.invalidName }
        let ext = url.pathExtension
        if name.lowercased().hasSuffix("." + ext.lowercased()) { name = String(name.dropLast(ext.count + 1)) }
        guard !name.isEmpty else { throw RenameError.invalidName }
        let target = url.deletingLastPathComponent().appendingPathComponent(name).appendingPathExtension(ext)
        guard target != url else { return }
        guard !FileManager.default.fileExists(atPath: target.path) else { throw RenameError.alreadyExists }
        do { try FileManager.default.moveItem(at: url, to: target) } catch {
            throw RenameError.failed(error.localizedDescription)
        }
        let wasCurrent = queue.current == url
        queue.rename(from: url, to: target)
        if wasCurrent { reattach(to: target) }
        libraryVersion += 1
    }

    /// Renames an ambiente folder. If it is the active one, playback continues on the same track.
    func renameFolder(_ folder: AmbienteFolder, to input: String) throws {
        guard let name = AudioLibrary.sanitizedFolderName(input) else { throw RenameError.invalidName }
        let target = root.appendingPathComponent(name, isDirectory: true)
        guard target != folder.url else { return }
        let caseOnly = name.lowercased() == folder.name.lowercased()
        let fm = FileManager.default
        guard caseOnly || !fm.fileExists(atPath: target.path) else { throw RenameError.alreadyExists }
        do {
            if caseOnly {
                let temp = root.appendingPathComponent(".rename-\(UUID().uuidString)", isDirectory: true)
                try fm.moveItem(at: folder.url, to: temp)
                try fm.moveItem(at: temp, to: target)
            } else {
                try fm.moveItem(at: folder.url, to: target)
            }
        } catch {
            throw RenameError.failed(error.localizedDescription)
        }
        if activeFolder == folder {
            let currentName = queue.current?.lastPathComponent
            let renamed = AmbienteFolder(url: target)
            activeFolder = renamed
            UserDefaults.standard.set(renamed.name, forKey: Keys.folder)
            let all = AudioLibrary.tracks(in: target)
            trackCount = all.count
            queue = PlayQueue(tracks: all, shuffled: shuffle)
            if let currentName, let same = all.first(where: { $0.lastPathComponent == currentName }), queue.select(same) {
                reattach(to: same)
            }
        }
        refreshFolders()
    }

    /// Re-points the player at a renamed file, keeping position and play state.
    private func reattach(to url: URL) {
        let time = currentTime
        let wasPlaying = isPlaying
        load(url)
        player.seek(to: CMTime(seconds: time, preferredTimescale: 600))
        currentTime = time
        if wasPlaying { player.play() }
        isPlaying = wasPlaying
        updateNowPlaying()
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
        artwork = nil
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
            artwork = nil
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
        // The file name is the title, so renaming a file changes what is shown.
        trackTitle = url.deletingPathExtension().lastPathComponent
        trackArtist = nil
        artwork = nil
        metadataTask = Task { [weak self] in
            let asset = AVURLAsset(url: url)
            let length = (try? await asset.load(.duration).seconds) ?? 0
            let items = (try? await asset.load(.commonMetadata)) ?? []
            let artist = await Self.string(for: .commonIdentifierArtist, in: items)
            let image = await Self.artworkImage(in: items)
            guard !Task.isCancelled, let self, self.queue.current == url else { return }
            if length.isFinite { self.duration = length }
            self.trackArtist = artist
            self.artwork = image
            self.updateNowPlaying()
        }
        return true
    }

    private static func string(for identifier: AVMetadataIdentifier, in items: [AVMetadataItem]) async -> String? {
        guard let item = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: identifier).first else { return nil }
        return try? await item.load(.stringValue)
    }

    private static func artworkImage(in items: [AVMetadataItem]) async -> NSImage? {
        guard let item = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: .commonIdentifierArtwork).first,
              let data = try? await item.load(.dataValue) else { return nil }
        return NSImage(data: data)
    }

    /// Built outside the main actor: MediaPlayer calls the artwork handler on its own queue.
    private nonisolated static func nowPlayingArtwork(_ image: NSImage) -> MPMediaItemArtwork {
        nonisolated(unsafe) let image = image
        return MPMediaItemArtwork(boundsSize: image.size) { _ in image }
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
        if let artwork { info[MPMediaItemPropertyArtwork] = Self.nowPlayingArtwork(artwork) }
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
