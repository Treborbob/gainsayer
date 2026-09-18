// Renders the app icon: a rounded gradient tile with the flex on it.
// Usage: swift scripts/make-icon.swift   (writes Support/AppIcon.icns and Support/icon.png)
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let support = root.appendingPathComponent("Support")
let iconset = support.appendingPathComponent("AppIcon.iconset")

func render(pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    let size = CGFloat(pixels)
    // Apple's icon grid leaves roughly a tenth of the canvas as transparent margin.
    let body = NSRect(x: 0, y: 0, width: size, height: size).insetBy(dx: size * 0.098, dy: size * 0.098)
    let tile = NSBezierPath(roundedRect: body, xRadius: body.width * 0.225, yRadius: body.height * 0.225)

    let gradient = NSGradient(
        starting: NSColor(calibratedRed: 0.17, green: 0.15, blue: 0.42, alpha: 1),
        ending: NSColor(calibratedRed: 0.36, green: 0.31, blue: 0.86, alpha: 1))!
    gradient.draw(in: tile, angle: -60)

    let glyph = "\u{1F4AA}" as NSString
    let font = NSFont.systemFont(ofSize: body.height * 0.58)
    let attributes: [NSAttributedString.Key: Any] = [.font: font]
    let bounds = glyph.size(withAttributes: attributes)
    let origin = NSPoint(x: body.midX - bounds.width / 2, y: body.midY - bounds.height / 2 + body.height * 0.02)
    glyph.draw(at: origin, withAttributes: attributes)
    return rep
}

func write(_ rep: NSBitmapImageRep, to url: URL) throws {
    try rep.representation(using: .png, properties: [:])!.write(to: url)
}

let fm = FileManager.default
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    try write(render(pixels: points), to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try write(render(pixels: points * 2), to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
try write(render(pixels: 256), to: support.appendingPathComponent("icon.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", support.appendingPathComponent("AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
try? fm.removeItem(at: iconset)
print(iconutil.terminationStatus == 0 ? "Wrote Support/AppIcon.icns and Support/icon.png" : "iconutil failed")
