// Renders the app icon (a parchment badge with a leaf and star) to an .iconset and .icns.
import AppKit

func render(size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let inset = rect.insetBy(dx: size * 0.06, dy: size * 0.06)
    let path = NSBezierPath(roundedRect: inset, xRadius: size * 0.22, yRadius: size * 0.22)
    // sky-to-grass gradient background
    NSGradient(colors: [NSColor(hex: 0x8fb4f2), NSColor(hex: 0xc9f3f3), NSColor(hex: 0x6fcb6f)])!
        .draw(in: path, angle: -90)
    NSColor(hex: 0x8a4a10).setStroke()
    path.lineWidth = size * 0.035
    path.stroke()
    // parchment medallion
    let medal = NSBezierPath(ovalIn: inset.insetBy(dx: size * 0.17, dy: size * 0.17))
    NSColor(hex: 0xfff1d8).setFill(); medal.fill()
    NSColor(hex: 0x8a4a10).setStroke(); medal.lineWidth = size * 0.03; medal.stroke()
    // symbols
    func draw(_ name: String, _ color: NSColor, _ frame: NSRect, weight: NSFont.Weight = .bold) {
        let cfg = NSImage.SymbolConfiguration(pointSize: frame.height * 0.8, weight: weight)
        guard let sym = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(cfg) else { return }
        let tinted = NSImage(size: sym.size, flipped: false) { r in
            sym.draw(in: r); color.set(); r.fill(using: .sourceAtop); return true
        }
        let ar = sym.size.width / sym.size.height
        let h = frame.height, w = h * ar
        tinted.draw(in: NSRect(x: frame.midX - w / 2, y: frame.midY - h / 2, width: w, height: h))
    }
    draw("checkmark.seal.fill", NSColor(hex: 0x2a7a2a), NSRect(x: size * 0.30, y: size * 0.30, width: size * 0.40, height: size * 0.40))
    draw("star.fill", NSColor(hex: 0xe08a2a), NSRect(x: size * 0.60, y: size * 0.60, width: size * 0.18, height: size * 0.18))
    img.unlockFocus()
    return img
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: 1)
    }
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
for (px, name) in [(16, "16x16"), (32, "16x16@2x"), (32, "32x32"), (64, "32x32@2x"), (128, "128x128"), (256, "128x128@2x"), (256, "256x256"), (512, "256x256@2x"), (512, "512x512"), (1024, "512x512@2x")] {
    // Render into an exact-pixel bitmap (NSImage.lockFocus would use the screen's 2x scale).
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                                     hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { continue }
    rep.size = NSSize(width: px, height: px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    render(size: CGFloat(px)).draw(in: NSRect(x: 0, y: 0, width: px, height: px), from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: "\(out)/icon_\(name).png"))
}
print("wrote \(out)")
