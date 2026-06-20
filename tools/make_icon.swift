import AppKit
import Foundation

let outputDir = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")
let iconsetURL = outputDir.appendingPathComponent("LidAwake.iconset", isDirectory: true)

try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

struct IconSize {
    let filename: String
    let pixels: Int
}

let sizes: [IconSize] = [
    .init(filename: "icon_16x16.png", pixels: 16),
    .init(filename: "icon_16x16@2x.png", pixels: 32),
    .init(filename: "icon_32x32.png", pixels: 32),
    .init(filename: "icon_32x32@2x.png", pixels: 64),
    .init(filename: "icon_128x128.png", pixels: 128),
    .init(filename: "icon_128x128@2x.png", pixels: 256),
    .init(filename: "icon_256x256.png", pixels: 256),
    .init(filename: "icon_256x256@2x.png", pixels: 512),
    .init(filename: "icon_512x512.png", pixels: 512),
    .init(filename: "icon_512x512@2x.png", pixels: 1024)
]

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    let r = CGFloat((hex >> 16) & 0xff) / 255
    let g = CGFloat((hex >> 8) & 0xff) / 255
    let b = CGFloat(hex & 0xff) / 255
    return NSColor(calibratedRed: r, green: g, blue: b, alpha: alpha)
}

func roundedRect(_ rect: CGRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func drawIcon(size: Int) -> NSBitmapImageRep {
    let side = CGFloat(size)
    let scale = side / 1024

    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let graphicsContext = NSGraphicsContext(bitmapImageRep: rep) else {
        fatalError("Could not create bitmap context")
    }

    rep.size = NSSize(width: side, height: side)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext
    defer { NSGraphicsContext.restoreGraphicsState() }

    let context = graphicsContext.cgContext
    context.setShouldAntialias(true)
    context.setAllowsAntialiasing(true)

    let bounds = CGRect(x: 0, y: 0, width: side, height: side)
    NSColor.clear.setFill()
    bounds.fill()

    let corner = 220 * scale
    let body = bounds.insetBy(dx: 44 * scale, dy: 44 * scale)
    let bodyPath = roundedRect(body, radius: corner)
    bodyPath.addClip()

    let bg = NSGradient(colors: [
        color(0x15201d),
        color(0x273832),
        color(0xf2b35e)
    ])!
    bg.draw(in: body, angle: -50)

    color(0x0b0f12, alpha: 0.16).setFill()
    roundedRect(
        CGRect(x: 96 * scale, y: 96 * scale, width: 832 * scale, height: 832 * scale),
        radius: 184 * scale
    ).fill()

    let sunCenter = CGPoint(x: 594 * scale, y: 648 * scale)
    let sunRadius = 178 * scale
    color(0xffd37a, alpha: 0.22).setFill()
    NSBezierPath(ovalIn: CGRect(
        x: sunCenter.x - sunRadius * 1.38,
        y: sunCenter.y - sunRadius * 1.38,
        width: sunRadius * 2.76,
        height: sunRadius * 2.76
    )).fill()

    color(0xffcc67).setFill()
    NSBezierPath(ovalIn: CGRect(
        x: sunCenter.x - sunRadius,
        y: sunCenter.y - sunRadius,
        width: sunRadius * 2,
        height: sunRadius * 2
    )).fill()

    color(0xfff1c2, alpha: 0.95).setStroke()
    let rayWidth = max(10 * scale, 1)
    let rayPath = NSBezierPath()
    rayPath.lineCapStyle = .round
    rayPath.lineWidth = rayWidth
    for angle in stride(from: 18.0, through: 162.0, by: 24.0) {
        let radians = CGFloat(angle * .pi / 180)
        let start = CGPoint(
            x: sunCenter.x + cos(radians) * 224 * scale,
            y: sunCenter.y + sin(radians) * 224 * scale
        )
        let end = CGPoint(
            x: sunCenter.x + cos(radians) * 274 * scale,
            y: sunCenter.y + sin(radians) * 274 * scale
        )
        rayPath.move(to: start)
        rayPath.line(to: end)
    }
    rayPath.stroke()

    color(0x101819).setFill()
    roundedRect(
        CGRect(x: 224 * scale, y: 260 * scale, width: 576 * scale, height: 86 * scale),
        radius: 43 * scale
    ).fill()

    let baseHighlight = NSGradient(colors: [
        color(0xf7f4de),
        color(0x95ded1)
    ])!
    baseHighlight.draw(
        in: roundedRect(
            CGRect(x: 254 * scale, y: 296 * scale, width: 516 * scale, height: 24 * scale),
            radius: 12 * scale
        ),
        angle: 0
    )

    let lidRect = CGRect(x: 274 * scale, y: 352 * scale, width: 476 * scale, height: 302 * scale)
    let lidPath = roundedRect(lidRect, radius: 42 * scale)
    color(0xf7f4de).setFill()
    lidPath.fill()

    let screenRect = lidRect.insetBy(dx: 38 * scale, dy: 38 * scale)
    let screenPath = roundedRect(screenRect, radius: 26 * scale)
    let screenGradient = NSGradient(colors: [
        color(0x172320),
        color(0x2c4741)
    ])!
    screenGradient.draw(in: screenPath, angle: -35)

    color(0x95ded1, alpha: 0.95).setFill()
    roundedRect(
        CGRect(x: 336 * scale, y: 398 * scale, width: 130 * scale, height: 18 * scale),
        radius: 9 * scale
    ).fill()

    color(0xffffff, alpha: 0.22).setStroke()
    let shine = NSBezierPath()
    shine.lineWidth = max(18 * scale, 1)
    shine.lineCapStyle = .round
    shine.move(to: CGPoint(x: 390 * scale, y: 604 * scale))
    shine.line(to: CGPoint(x: 520 * scale, y: 604 * scale))
    shine.stroke()

    bodyPath.setClip()
    color(0xffffff, alpha: 0.18).setStroke()
    let border = roundedRect(body.insetBy(dx: 8 * scale, dy: 8 * scale), radius: corner - 8 * scale)
    border.lineWidth = max(8 * scale, 1)
    border.stroke()

    return rep
}

func writePNG(_ rep: NSBitmapImageRep, to url: URL) throws {
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "LidAwakeIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not create PNG"])
    }

    try data.write(to: url)
}

for size in sizes {
    let image = drawIcon(size: size.pixels)
    try writePNG(image, to: iconsetURL.appendingPathComponent(size.filename))
}

let preview = drawIcon(size: 1024)
try writePNG(preview, to: outputDir.appendingPathComponent("LidAwakeIcon.png"))

print(iconsetURL.path)
