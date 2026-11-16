import AmbienteCore
import ServiceManagement
import SwiftUI

struct MenuView: View {
    @Bindable var player: PlayerModel
    var downloads: DownloadModel

    @State private var showSettings = false
    @State private var link = ""
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
        .onAppear {
            showSettings = false
            player.refreshFolders()
            if targetName != Self.newTag, !player.folders.contains(where: { $0.name == targetName }) {
                targetName = player.activeFolder?.name ?? player.folders.first?.name ?? Self.newTag
            }
            downloads.checkForUpdate()
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

            Divider()
            environmentList
            Divider()
            addByLink
            updateBanner
            Divider()
            HStack {
                Button { showSettings = true } label: { Image(systemName: "gearshape") }
                    .help("Settings")
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .buttonStyle(.link)
        }
    }

    private var nowPlaying: some View {
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
    }

    private var controls: some View {
        HStack(spacing: 20) {
            Spacer()
            Button(action: player.previous) { Image(systemName: "backward.fill") }
            Button(action: player.togglePlayPause) {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 20)
            }
            Button(action: player.next) { Image(systemName: "forward.fill") }
            Spacer()
        }
        .buttonStyle(.borderless)
        .imageScale(.large)
        .disabled(player.activeFolder == nil || player.trackCount == 0)
    }

    private var environmentList: some View {
        VStack(alignment: .leading, spacing: 4) {
            if player.folders.isEmpty {
                Text("Create subfolders in \(Self.display(player.root)): each one is an ambiente.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(player.folders) { folder in
                HStack {
                    Button {
                        player.select(folder)
                    } label: {
                        HStack {
                            Image(systemName: "checkmark")
                                .opacity(folder == player.activeFolder ? 1 : 0)
                            Text(folder.name)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Button {
                        NSWorkspace.shared.open(folder.url)
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .help("Open \(folder.name) in Finder")
                }
            }
        }
    }

    // MARK: Add by link

    private var addByLink: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Add by link").font(.subheadline).foregroundStyle(.secondary)
            TextField("Paste a YouTube link", text: $link)
                .textFieldStyle(.roundedBorder)
                .onSubmit(startDownload)
            HStack {
                Picker("Ambiente", selection: $targetName) {
                    ForEach(player.folders) { Text($0.name).tag($0.name) }
                    if !player.folders.isEmpty { Divider() }
                    Text("New ambiente…").tag(Self.newTag)
                }
                .labelsHidden()
                if case .downloading = downloads.state {
                    Button("Cancel", action: downloads.cancel)
                } else {
                    Button("Download", action: startDownload)
                        .disabled(link.isEmpty || resolvedTarget() == nil || downloads.isBusy)
                }
            }
            if targetName == Self.newTag {
                TextField("New ambiente name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(startDownload)
            }
            if let target = resolvedTarget(), downloads.state == .idle {
                Label("Saves to \(Self.display(target.url))", systemImage: "arrow.down.to.line")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            downloadStatus
        }
    }

    @ViewBuilder private var downloadStatus: some View {
        switch downloads.state {
        case .idle:
            EmptyView()
        case .downloading(let progress):
            if let progress {
                ProgressView(value: progress)
            } else {
                ProgressView().progressViewStyle(.linear)
            }
        case .done(let folder):
            HStack(alignment: .firstTextBaseline) {
                Label("Saved to \(Self.display(folder))", systemImage: "checkmark.circle")
                    .font(.callout)
                Spacer()
                Button("Show") { NSWorkspace.shared.open(folder) }
                    .buttonStyle(.link)
            }
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.callout)
                .foregroundStyle(.red)
                .textSelection(.enabled)
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
                    .buttonStyle(.borderless)
                Text("Settings").font(.headline)
            }
            Toggle("Open at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
            if let loginError {
                Text(loginError).font(.caption).foregroundStyle(.red)
            }
            Divider()
            HStack {
                Text("yt-dlp")
                Spacer()
                Text(downloads.installedVersion ?? "—").foregroundStyle(.secondary)
            }
            Button("Check for yt-dlp update") {
                downloads.checkForUpdate(force: true)
            }
            .disabled(downloads.isBusy)
            Button("Open library folder") { NSWorkspace.shared.open(player.root) }
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
        let isNew = targetName == Self.newTag
        if isNew {
            try? FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
        }
        downloads.download(link: link, into: folder) {
            link = ""
            player.refreshFolders()
            if isNew {
                newName = ""
                targetName = folder.name
            }
        }
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

    private static func display(_ url: URL) -> String {
        (url.path(percentEncoded: false) as NSString).abbreviatingWithTildeInPath
    }
}

private extension AmbienteFolder {
    func trackCountLabel(_ count: Int) -> String { count == 1 ? "1 track" : "\(count) tracks" }
}
