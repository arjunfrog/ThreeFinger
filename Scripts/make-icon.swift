// Draws the app icon (a grey tile with the hand.tap symbol) and writes it as an .icns file.
// Usage: swift Scripts/make-icon.swift Resources/AppIcon.icns
import AppKit

let output = CommandLine.arguments[1]
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let scale = CGFloat(pixels) / 1024
    NSGraphicsContext.current!.cgContext.scaleBy(x: scale, y: scale)

    // Tile on the standard macOS icon grid: 824pt square, 100pt margin.
    let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
    let shape = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    NSColor(white: 0.93, alpha: 1).setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(starting: NSColor(white: 0.96, alpha: 1), ending: NSColor(white: 0.86, alpha: 1))!
        .draw(in: shape, angle: -90)

    let config = NSImage.SymbolConfiguration(pointSize: 440, weight: .regular)
        .applying(.init(paletteColors: [NSColor(white: 0.38, alpha: 1)]))
    let symbol = NSImage(systemSymbolName: "hand.tap", accessibilityDescription: nil)!
        .withSymbolConfiguration(config)!
    symbol.draw(in: NSRect(
        x: tile.midX - symbol.size.width / 2, y: tile.midY - symbol.size.height / 2,
        width: symbol.size.width, height: symbol.size.height
    ))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for points in [16, 32, 128, 256, 512] {
    for factor in [1, 2] {
        let name = factor == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        try render(pixels: points * factor).write(to: iconset.appendingPathComponent(name))
    }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output]
try iconutil.run()
iconutil.waitUntilExit()
exit(iconutil.terminationStatus)
