import AmbienteCore
import ServiceManagement
import SwiftUI

struct MenuView: View {
    @Bindable var player: PlayerModel
    var downloads: DownloadModel

    @State private var showSettings = false
    @State private var scrubTime: Double?
    @State private var showAddByLink = false
    @State private var expanded: Set<String> = []
    @State private var renaming: URL?
    @State private var renameText = ""
    @State private var renameError: String?
    @State private var pendingDelete: URL?
    @State private var link = ""
    @State private var linkError: String?
    @State private var targetName = ""
    @State private var newName = ""
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    private static let newTag = "\u{0}new"

    var body: some View {
        Group {
            if showSettings {
                settings
            } else {
                main
            }
        }
        .padding(12)
        .frame(width: 300)
        .focusEffectDisabled()
        .onAppear {
            showSettings = false
            renaming = nil
            if !downloads.isDownloading { showAddByLink = false }
            downloads.clearDone()
            downloads.onTrackAdded = { player.refreshFolders() }
            player.refreshFolders()
            if targetName != Self.newTag, !player.folders.contains(where: { $0.name == targetName }) {
                targetName = player.activeFolder?.name ?? player.folders.first?.name ?? Self.newTag
            }
            if let active = player.activeFolder { expanded.insert(active.id) }
            downloads.checkForUpdate()
        }
        .onChange(of: player.activeFolder) { _, active in
            if let active { expanded.insert(active.id) }
        }
    }

    // MARK: Main page

    private var main: some View {
        VStack(alignment: .leading, spacing: 12) {
            nowPlaying
            controls
            Slider(value: $player.volume, in: 0...1) {
                Text("Volume")
            } minimumValueLabel: {
                Image(systemName: "speaker.fill")
            } maximumValueLabel: {
                Image(systemName: "speaker.wave.3.fill")
            }
            .labelsHidden()
            .focusable(false)

            Divider()
            environmentList
            Divider()
            addByLink
            updateBanner
            Divider()
            HStack {
                Button { showSettings = true } label: { Image(systemName: "gearshape") }
                .focusable(false)
                    .help("Settings")
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                .focusable(false)
            }
            .buttonStyle(.link)
        }
    }

    private var nowPlaying: some View {
        HStack(spacing: 10) {
            artworkView
            VStack(alignment: .leading, spacing: 2) {
                Text(player.trackTitle ?? "Nothing playing")
                    .font(.headline)
                    .lineLimit(2)
                if let artist = player.trackArtist {
                    Text(artist).foregroundStyle(.secondary).lineLimit(1)
                }
                Text(player.activeFolder.map { "\($0.name) · \($0.trackCountLabel(player.trackCount))" } ?? "Choose an ambiente")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var artworkView: some View {
        Group {
            if let artwork = player.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "music.note")
                    .imageScale(.large)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.quaternary)
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var controls: some View {
        VStack(spacing: 6) {
            timeline
            HStack(spacing: 20) {
                Button { player.shuffle.toggle() } label: {
                    Image(systemName: "shuffle")
                        .foregroundStyle(player.shuffle ? Color.accentColor : Color.secondary)
                }
                .help(player.shuffle ? "Shuffle on" : "Shuffle off")
                .focusable(false)
                Button(action: player.previous) { Image(systemName: "backward.fill") }
                .focusable(false)
                Button(action: player.togglePlayPause) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .frame(width: 20)
                }
                .focusable(false)
                Button(action: player.next) { Image(systemName: "forward.fill") }
                .focusable(false)
                Button(action: player.cycleRepeat) {
                    Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                        .foregroundStyle(player.repeatMode == .off ? Color.secondary : Color.accentColor)
                }
                .help(Self.repeatHelp(player.repeatMode))
                .focusable(false)
            }
            .buttonStyle(.borderless)
            .imageScale(.large)
        }
        .disabled(player.activeFolder == nil || player.trackCount == 0)
    }

    private var timeline: some View {
        VStack(spacing: 0) {
            Slider(
                value: Binding(
                    get: { scrubTime ?? player.currentTime },
                    set: { scrubTime = $0 }
                ),
                in: 0...max(player.duration, 1)
            ) { editing in
                if !editing, let time = scrubTime {
                    player.seek(to: time)
                    scrubTime = nil
                }
            }
            .controlSize(.small)
            .labelsHidden()
            .disabled(player.duration <= 0)
            .focusable(false)
            HStack {
                Text(Self.format(scrubTime ?? player.currentTime))
                Spacer()
                Text("-" + Self.format(max(player.duration - (scrubTime ?? player.currentTime), 0)))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private var environmentList: some View {
        VStack(alignment: .leading, spacing: 4) {
            if player.folders.isEmpty {
                Text("Create subfolders in \(Self.display(player.root)): each one is an ambiente.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if let renameError {
                Label(renameError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            deleteConfirmation
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(player.folders) { folder in
                        folderRow(folder)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 240)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func chevron(open: Bool) -> some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .rotationEffect(.degrees(open ? 90 : 0))
            .frame(width: 12)
    }

    private func folderRow(_ folder: AmbienteFolder) -> some View {
        let isOpen = expanded.contains(folder.id)
        return VStack(alignment: .leading, spacing: 2) {
            if renaming == folder.url {
                renameField { try player.renameFolder(folder, to: $0) }
            } else {
                HStack(spacing: 6) {
                    Button {
                        toggleExpanded(folder)
                    } label: {
                        HStack(spacing: 6) {
                            chevron(open: isOpen)
                            Text(folder.name)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    Button {
                        player.select(folder)
                    } label: {
                        Image(systemName: "play.fill")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .help("Play \(folder.name)")
                    .focusable(false)
                    Button {
                        NSWorkspace.shared.open(folder.url)
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .help("Open \(folder.name) in Finder")
                    .focusable(false)
                }
                .contextMenu {
                    Button("Rename…") { beginRename(folder.url, text: folder.name) }
                    Button("Show in Finder") { NSWorkspace.shared.open(folder.url) }
                    Divider()
                    Button("Move to Trash…", role: .destructive) { pendingDelete = folder.url }
                }
            }
            if isOpen {
                let _ = player.libraryVersion
                let tracks = player.tracks(in: folder)
                VStack(alignment: .leading, spacing: 2) {
                    if tracks.isEmpty {
                        Text("No tracks yet").font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(tracks, id: \.self) { track in
                        trackRow(track, in: folder)
                    }
                }
                .padding(.leading, 18)
                .padding(.top, 2)
            }
        }
    }

    private func trackRow(_ track: URL, in folder: AmbienteFolder) -> some View {
        let name = track.deletingPathExtension().lastPathComponent
        let isCurrent = player.activeFolder == folder && player.currentTrack == track
        return Group {
            if renaming == track {
                renameField { try player.renameTrack(track, to: $0) }
            } else {
                Button {
                    player.play(track: track, in: folder)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isCurrent ? (player.isPlaying ? "speaker.wave.2.fill" : "speaker.fill") : "music.note")
                            .font(.caption)
                            .frame(width: 14)
                            .foregroundStyle(isCurrent ? Color.accentColor : Color.secondary)
                        Text(name)
                            .font(.callout)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Rename…") { beginRename(track, text: name) }
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([track]) }
                    Divider()
                    Button("Move to Trash…", role: .destructive) { pendingDelete = track }
                }
                .focusable(false)
            }
        }
    }

    private func toggleExpanded(_ folder: AmbienteFolder) {
        if expanded.contains(folder.id) { expanded.remove(folder.id) } else { expanded.insert(folder.id) }
    }

    @ViewBuilder private var deleteConfirmation: some View {
        if let url = pendingDelete {
            let isFolder = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            let name = isFolder ? url.lastPathComponent : url.deletingPathExtension().lastPathComponent
            VStack(alignment: .leading, spacing: 6) {
                Text(isFolder ? "Move “\(name)” and all its tracks to the Trash?" : "Move “\(name)” to the Trash?")
                    .font(.callout)
                HStack {
                    Button("Cancel") { pendingDelete = nil }
                    .focusable(false)
                    Button("Move to Trash", role: .destructive) {
                        do {
                            try player.moveToTrash(url)
                            renameError = nil
                        } catch {
                            renameError = error.localizedDescription
                        }
                        pendingDelete = nil
                    }
                    .focusable(false)
                }
            }
            .padding(8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private func beginRename(_ url: URL, text: String) {
        renameError = nil
        renameText = text
        renaming = url
    }

    /// Inline text field: Return saves, Esc cancels.
    private func renameField(commit: @escaping (String) throws -> Void) -> some View {
        TextField("Name", text: $renameText)
            .textFieldStyle(.roundedBorder)
            .focusEffectDisabled(false)
            .onSubmit {
                do {
                    try commit(renameText)
                    renameError = nil
                    renaming = nil
                } catch {
                    renameError = error.localizedDescription
                }
            }
            .onExitCommand { renaming = nil; renameError = nil }
    }

    // MARK: Add by link

    private var addByLink: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                showAddByLink.toggle()
            } label: {
                HStack(spacing: 6) {
                    chevron(open: showAddByLink)
                    Text("Add by link")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            if showAddByLink { addByLinkContent }
        }
    }

    private var addByLinkContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Paste one or more YouTube links", text: $link, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                .focusEffectDisabled(false)
                .onSubmit(startDownload)
                .onChange(of: link) { _, _ in linkError = nil }
            HStack {
                Picker("Ambiente", selection: $targetName) {
                    ForEach(player.folders) { Text($0.name).tag($0.name) }
                    if !player.folders.isEmpty { Divider() }
                    Text("New ambiente…").tag(Self.newTag)
                }
                .labelsHidden()
                .focusable(false)
                Button("Download", action: startDownload)
                .focusable(false)
                    .disabled(link.isEmpty || resolvedTarget() == nil)
            }
            if targetName == Self.newTag {
                TextField("New ambiente name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .focusEffectDisabled(false)
                    .onSubmit(startDownload)
            }
            if let linkError {
                Label(linkError, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.red)
            }
            ForEach(downloads.jobs) { job in
                jobRow(job)
            }
        }
    }

    private func jobRow(_ job: DownloadModel.Job) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(job.displayName)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button { downloads.remove(job.id) } label: { Image(systemName: "xmark") }
                .focusable(false)
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .help(job.isActive ? "Cancel" : "Dismiss")
            }
            switch job.status {
            case .queued:
                Text("Waiting…").font(.caption).foregroundStyle(.secondary)
            case .downloading(let progress):
                if let progress {
                    ProgressView(value: progress)
                } else {
                    ProgressView().progressViewStyle(.linear)
                }
            case .done:
                Label("Saved to \(Self.display(job.folder))", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .failed(let message):
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: yt-dlp update notice (only when there is something to say)

    @ViewBuilder private var updateBanner: some View {
        switch downloads.updateState {
        case .updating:
            HStack {
                ProgressView().controlSize(.small)
                Text("Updating yt-dlp…").font(.callout)
            }
        case .failed(let message):
            Label("Update failed: \(message)", systemImage: "exclamationmark.triangle")
                .font(.callout)
                .foregroundStyle(.red)
        case .idle:
            if downloads.updateAvailable, let latest = downloads.latestVersion {
                HStack {
                    Label("yt-dlp \(latest) available", systemImage: "arrow.down.circle")
                        .font(.callout)
                    Spacer()
                    Button("Update", action: downloads.updateYtDlp)
                    .focusable(false)
                        .disabled(downloads.isBusy)
                }
            }
        }
    }

    // MARK: Settings page

    private var settings: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { showSettings = false } label: { Image(systemName: "chevron.left") }
                .focusable(false)
                    .buttonStyle(.borderless)
                Text("Settings").font(.headline)
            }
            settingsSection("General") {
                Toggle("Open at login", isOn: $launchAtLogin)
                .focusable(false)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
            }
            settingsSection("Library") {
                Text(Self.display(player.root))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Button("Open in Finder") { NSWorkspace.shared.open(player.root) }
                .focusable(false)
            }
            settingsSection("Downloads") {
                HStack {
                    Text("yt-dlp")
                    Spacer()
                    Text(downloads.installedVersion ?? "—").foregroundStyle(.secondary)
                }
                Button("Check for update") { downloads.checkForUpdate(force: true) }
                .focusable(false)
                    .disabled(downloads.isBusy)
                if downloads.updateAvailable, let latest = downloads.latestVersion {
                    HStack {
                        Text("Version \(latest) available").font(.callout)
                        Spacer()
                        Button("Update", action: downloads.updateYtDlp)
                        .focusable(false)
                            .disabled(downloads.isBusy)
                    }
                }
            }
        }
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8, content: content)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: Helpers

    /// The chosen folder, or the one that would be created for a new name.
    private func resolvedTarget() -> AmbienteFolder? {
        if targetName == Self.newTag {
            guard let name = AudioLibrary.sanitizedFolderName(newName) else { return nil }
            return AmbienteFolder(url: player.root.appendingPathComponent(name, isDirectory: true))
        }
        return player.folders.first { $0.name == targetName }
    }

    private func startDownload() {
        guard let folder = resolvedTarget(), !link.isEmpty else { return }
        let urls = YouTubeDownload.links(from: link)
        guard !urls.isEmpty else {
            linkError = "No valid link found (http/https)."
            return
        }
        if targetName == Self.newTag {
            try? FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
            player.refreshFolders()
            newName = ""
            targetName = folder.name
        }
        downloads.enqueue(urls, into: folder.url)
        link = ""
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = error.localizedDescription
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private static func format(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private static func repeatHelp(_ mode: RepeatMode) -> String {
        switch mode {
        case .off: "Repeat off"
        case .all: "Repeat all"
        case .one: "Repeat one"
        }
    }

    private static func display(_ url: URL) -> String {
        (url.path(percentEncoded: false) as NSString).abbreviatingWithTildeInPath
    }
}

private extension AmbienteFolder {
    func trackCountLabel(_ count: Int) -> String { count == 1 ? "1 track" : "\(count) tracks" }
}
