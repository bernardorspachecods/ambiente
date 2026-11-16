import SwiftUI

@main
struct AmbienteApp: App {
    @State private var player = PlayerModel()
    @State private var downloads = DownloadModel()

    var body: some Scene {
        MenuBarExtra {
            MenuView(player: player, downloads: downloads)
        } label: {
            if let icon = player.isPlaying ? MenuIcon.playing : MenuIcon.paused {
                Image(nsImage: icon)
            } else {
                Image(systemName: player.isPlaying ? "waveform" : "music.note")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
