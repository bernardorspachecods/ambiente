import AmbienteCore
import ServiceManagement
import SwiftUI

struct MenuView: View {
    @Bindable var player: PlayerModel
    var downloads: DownloadModel

    @State private var link = ""
    @State private var targetName = ""
    @State private var newName = ""
    private static let newTag = "\u{0}new"
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
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
            Divider()
            footer
        }
        .padding(12)
        .frame(width: 300)
        .onAppear {
            player.refreshFolders()
            if targetName != Self.newTag, !player.folders.contains(where: { $0.name == targetName }) {
                targetName = player.activeFolder?.name ?? player.folders.first?.name ?? Self.newTag
            }
        }
    }

    private var nowPlaying: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(player.trackTitle ?? "Nada a tocar")
                .font(.headline)
                .lineLimit(2)
            if let artist = player.trackArtist {
                Text(artist).foregroundStyle(.secondary).lineLimit(1)
            }
            Text(player.activeFolder.map { "\($0.name) · \(player.trackCount) faixas" } ?? "Escolhe um ambiente")
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
        VStack(alignment: .leading, spacing: 2) {
            if player.folders.isEmpty {
                Text("Cria subpastas em \(player.root.path(percentEncoded: false)) — cada uma é um ambiente.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(player.folders) { folder in
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
            }
        }
    }

    private var addByLink: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Adicionar por link").font(.subheadline).foregroundStyle(.secondary)
            TextField("Colar link do YouTube", text: $link)
                .textFieldStyle(.roundedBorder)
                .onSubmit(startDownload)
            HStack {
                Picker("Ambiente", selection: $targetName) {
                    ForEach(player.folders) { Text($0.name).tag($0.name) }
                    if !player.folders.isEmpty { Divider() }
                    Text("Novo ambiente…").tag(Self.newTag)
                }
                .labelsHidden()
                if case .downloading = downloads.state {
                    Button("Cancelar", action: downloads.cancel)
                } else {
                    Button("Descarregar", action: startDownload)
                        .disabled(link.isEmpty || resolvedTarget() == nil || downloads.isBusy)
                }
            }
            if targetName == Self.newTag {
                TextField("Nome do novo ambiente", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(startDownload)
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
        case .done(let message):
            Label(message, systemImage: "checkmark.circle").font(.callout)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.callout)
                .foregroundStyle(.red)
                .textSelection(.enabled)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Abrir no arranque", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
            if let loginError {
                Text(loginError).font(.caption).foregroundStyle(.red)
            }
            HStack {
                Button("Atualizar yt-dlp", action: downloads.updateYtDlp)
                    .disabled(downloads.isBusy)
                updateStatus
                Spacer()
                Button("Abrir pasta") { NSWorkspace.shared.open(player.root) }
                Button("Sair") { NSApplication.shared.terminate(nil) }
            }
            .buttonStyle(.link)
        }
    }

    @ViewBuilder private var updateStatus: some View {
        switch downloads.updateState {
        case .idle: EmptyView()
        case .updating: ProgressView().controlSize(.small)
        case .updated(let text): Text(text).font(.caption).foregroundStyle(.secondary)
        case .failed(let text): Text(text).font(.caption).foregroundStyle(.red)
        }
    }

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
}
