import AppKit

/// The menu bar icon: a blobatar (blobatar.dev, MIT) with a happy face while playing and a
/// dimmed sleepy one while paused. Falls back to SF Symbols if the images are not in the bundle.
enum MenuIcon {
    static let size = NSSize(width: 18, height: 18)

    static let playing = load("playing", alpha: 1)
    static let paused = load("paused", alpha: 0.55)

    private static func load(_ name: String, alpha: CGFloat) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "MenuIcon"),
              let source = NSImage(contentsOf: url) else { return nil }
        let image = NSImage(size: size, flipped: false) { rect in
            source.draw(in: rect, from: .zero, operation: .sourceOver, fraction: alpha)
            return true
        }
        image.isTemplate = false
        return image
    }
}
