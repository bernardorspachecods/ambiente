// Draws the app icon (the blue blobatar on a soft rounded square) and writes an .iconset folder.
// Usage: swift scripts/make-icon.swift <blob.svg> <out.iconset>   (scripts/make-icon.sh wraps it)
import AppKit

let args = CommandLine.arguments
guard args.count == 3, let blob = NSImage(contentsOfFile: args[1]) else {
    FileHandle.standardError.write(Data("usage: make-icon.swift <blob.svg> <out.iconset>\n".utf8))
    exit(1)
}
let out = URL(fileURLWithPath: args[2], isDirectory: true)
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(pixels)
    // macOS icon grid: the shape fills ~80% of the canvas, corner radius ~22% of the shape.
    let shape = NSRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)
    let path = NSBezierPath(roundedRect: shape, xRadius: shape.width * 0.225, yRadius: shape.width * 0.225)
    NSGradient(colors: [NSColor(srgbRed: 0.96, green: 0.97, blue: 1.0, alpha: 1),
                        NSColor(srgbRed: 0.84, green: 0.88, blue: 0.97, alpha: 1)])!
        .draw(in: path, angle: -90)
    let side = shape.width * 0.62
    blob.draw(in: NSRect(x: shape.midX - side / 2, y: shape.midY - side / 2, width: side, height: side))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try render(pixels: base).write(to: out.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(pixels: base * 2).write(to: out.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
