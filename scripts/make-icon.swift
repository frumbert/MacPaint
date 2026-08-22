// Renders the Paint app icon (palette on a Fluent-style rounded card) and
// writes an .iconset directory. Run via scripts/build-app.sh.
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func draw(size: Int) -> NSBitmapImageRep {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    let g = ctx.cgContext

    // rounded card background, macOS-style inset
    let inset = s * 0.09
    let card = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let cardPath = CGPath(roundedRect: card, cornerWidth: s * 0.185, cornerHeight: s * 0.185, transform: nil)
    g.addPath(cardPath)
    g.clip()
    let colors = [
        CGColor(srgbRed: 0.16, green: 0.40, blue: 0.78, alpha: 1),
        CGColor(srgbRed: 0.36, green: 0.68, blue: 0.95, alpha: 1),
    ] as CFArray
    let grad = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1])!
    g.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: s), options: [])

    // palette board
    let cx = s * 0.5, cy = s * 0.47
    let rx = s * 0.30, ry = s * 0.27
    let palette = CGMutablePath()
    palette.addEllipse(in: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
    g.setFillColor(CGColor(srgbRed: 0.97, green: 0.96, blue: 0.94, alpha: 1))
    g.addPath(palette)
    g.fillPath()
    // thumb hole
    g.setBlendMode(.clear)
    g.fillEllipse(in: CGRect(x: cx + rx * 0.25, y: cy - ry * 0.35, width: rx * 0.55, height: ry * 0.5))
    g.setBlendMode(.normal)

    // paint dots
    let dots: [(CGFloat, CGFloat, CGColor)] = [
        (-0.45, 0.45, CGColor(srgbRed: 0.91, green: 0.31, blue: 0.31, alpha: 1)),
        (0.05, 0.62, CGColor(srgbRed: 0.97, green: 0.66, blue: 0.15, alpha: 1)),
        (0.5, 0.4, CGColor(srgbRed: 0.25, green: 0.73, blue: 0.31, alpha: 1)),
        (-0.62, -0.05, CGColor(srgbRed: 0.25, green: 0.55, blue: 0.88, alpha: 1)),
        (-0.4, -0.5, CGColor(srgbRed: 0.64, green: 0.29, blue: 0.64, alpha: 1)),
    ]
    for (dx, dy, c) in dots {
        g.setFillColor(c)
        let r = s * 0.055
        g.fillEllipse(in: CGRect(x: cx + dx * rx - r, y: cy + dy * ry - r, width: r * 2, height: r * 2))
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let entries: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in entries {
    let rep = draw(size: px)
    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
}
print("iconset written to \(outDir)")
