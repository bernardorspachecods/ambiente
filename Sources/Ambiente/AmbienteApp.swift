import AmbienteCore
import SwiftUI

@main
struct AmbienteApp: App {
    @State private var player = PlayerModel()
    @State private var downloads = DownloadModel()

    /// The local build (not in an Applications folder) is marked so it can be told from the installed one.
    private let isInstalled = AppLocation.isInstalled(
        bundlePath: Bundle.main.bundlePath, home: NSHomeDirectory())

    /// Lets `scripts/install.sh` ask the running copy to quit with a plain SIGTERM: this turns it
    /// into a normal quit, so the playback position is saved and downloads are terminated.
    private static let sigterm: DispatchSourceSignal = {
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler { NSApplication.shared.terminate(nil) }
        source.resume()
        return source
    }()

    init() { _ = Self.sigterm }

    var body: some Scene {
        MenuBarExtra {
            MenuView(player: player, downloads: downloads)
        } label: {
            HStack(spacing: 4) {
                if let icon = player.isPlaying ? MenuIcon.playing : MenuIcon.paused {
                    Image(nsImage: icon)
                } else {
                    Image(systemName: player.isPlaying ? "waveform" : "music.note")
                }
                if !isInstalled { Text("DEV") }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
