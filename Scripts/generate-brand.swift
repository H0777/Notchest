#!/usr/bin/env swift
import AppKit

// Original vector artwork. Render each macOS size directly, rather than resizing a bitmap.
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let brand = root.appendingPathComponent("Brand")
let iconset = root.appendingPathComponent(".brand-build/Notchest.iconset")
try FileManager.default.createDirectory(at: brand, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: alpha)
}
func gradient(_ colors: [CGColor], _ locations: [CGFloat]? = nil) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: locations)!
}
func glow(_ context: CGContext, _ hex: UInt32, _ alpha: CGFloat, _ center: CGPoint, _ radius: CGFloat) {
    context.drawRadialGradient(gradient([color(hex, alpha), color(hex, 0)]),
        startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
}
func drawIcon(_ pixels: Int) throws -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.current = graphics
    let context = graphics.cgContext
    let scale = CGFloat(pixels) / 1024
    context.scaleBy(x: scale, y: scale)
    context.setAllowsAntialiasing(true)
    let small = pixels <= 32
    let tile = CGPath(roundedRect: CGRect(x: 96, y: 96, width: 832, height: 832),
                      cornerWidth: 188, cornerHeight: 188, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -12 * scale), blur: 24 * scale, color: color(0x111033, 0.35))
    context.addPath(tile); context.setFillColor(color(0x191632)); context.fillPath()
    context.restoreGState()
    context.saveGState()
    context.addPath(tile); context.clip()
    context.drawLinearGradient(gradient([color(0x19384E), color(0x161C3F), color(0x28183F)]),
        start: CGPoint(x: 170, y: 960), end: CGPoint(x: 820, y: 96),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    glow(context, 0x00BDEB, 0.43, CGPoint(x: 170, y: 790), 600)
    glow(context, 0x6F35EF, 0.47, CGPoint(x: 850, y: 720), 580)
    glow(context, 0xF7379E, 0.32, CGPoint(x: 720, y: 120), 490)
    context.restoreGState()
    context.saveGState()
    context.addPath(tile); context.setLineWidth(3)
    context.replacePathWithStrokedPath(); context.clip()
    context.drawLinearGradient(gradient([color(0x66FFFF, 0.55), color(0xFFFFFF, 0.10), color(0xFF96E5, 0.35)]),
        start: CGPoint(x: 200, y: 940), end: CGPoint(x: 850, y: 100), options: [])
    context.restoreGState()

    // A broad dichroic glass orbit: cool turquoise at its head, violet and coral at its tail.
    context.saveGState()
    context.translateBy(x: 512, y: 512)
    context.rotate(by: 32 * .pi / 180)
    let ellipse = CGRect(x: -290, y: -172, width: 580, height: 344)
    let thickness: CGFloat = small ? 84 : 76
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -16 * scale), blur: 30 * scale, color: color(0x050820, 0.78))
    context.addEllipse(in: ellipse); context.setLineWidth(thickness + 5)
    context.setStrokeColor(color(0x19204C)); context.strokePath()
    context.restoreGState()
    context.saveGState()
    context.addEllipse(in: ellipse); context.setLineWidth(thickness)
    context.replacePathWithStrokedPath(); context.clip()
    context.drawLinearGradient(gradient([color(0x12E6D4), color(0x17CFFF), color(0x4568FF), color(0xA047FF), color(0xFF479E)], [0, 0.25, 0.50, 0.74, 1]),
        start: CGPoint(x: -300, y: 160), end: CGPoint(x: 300, y: -170),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    if !small {
        glow(context, 0xC6FFEF, 0.95, CGPoint(x: -220, y: 125), 235)
        glow(context, 0x53FFFF, 0.75, CGPoint(x: -100, y: 172), 145)
        glow(context, 0xFFB7F4, 0.85, CGPoint(x: 235, y: -100), 185)
        glow(context, 0x131573, 0.70, CGPoint(x: 20, y: -178), 170)
        glow(context, 0xFFFFFF, 0.34, CGPoint(x: 110, y: 170), 130)
    }
    context.restoreGState()
    if !small {
        // Fine highlights follow the outside edge; the center stays clean and legible.
        context.saveGState()
        context.addEllipse(in: ellipse.insetBy(dx: -30, dy: -30)); context.setLineWidth(2.5)
        context.replacePathWithStrokedPath(); context.clip()
        context.drawLinearGradient(gradient([color(0xE2FFF7, 0.90), color(0xD3CEFF, 0.1), color(0xFFD6EE, 0.65)]),
            start: CGPoint(x: -220, y: 210), end: CGPoint(x: 240, y: -200), options: [])
        context.restoreGState()
    }
    context.restoreGState()

    // Warm nucleus is a deliberate counterpoint to the cool orbit; no tiny decorative stars.
    let orb = CGRect(x: 421, y: 421, width: 182, height: 182)
    context.saveGState()
    context.setShadow(offset: .zero, blur: small ? 0 : 40 * scale, color: color(0xFF626D, 0.40))
    context.addEllipse(in: orb); context.setFillColor(color(0xFF8B6B)); context.fillPath()
    context.restoreGState()
    context.saveGState()
    context.addEllipse(in: orb); context.clip()
    context.drawLinearGradient(gradient([color(0xFFE3A3), color(0xFF9C69), color(0xFF4B81), color(0xB72DD2)], [0, 0.36, 0.75, 1]),
        start: CGPoint(x: 465, y: 601), end: CGPoint(x: 556, y: 421),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    if !small { glow(context, 0xFFF4D4, 0.85, CGPoint(x: 473, y: 562), 84) }
    context.restoreGState()
    if !small {
        context.addEllipse(in: orb); context.setLineWidth(2)
        context.setStrokeColor(color(0xFFE9C8, 0.42)); context.strokePath()
    }
    return bitmap.representation(using: .png, properties: [:])!
}

let sizes: [(String, Int)] = [("icon_16x16",16),("icon_16x16@2x",32),("icon_32x32",32),("icon_32x32@2x",64),("icon_128x128",128),("icon_128x128@2x",256),("icon_256x256",256),("icon_256x256@2x",512),("icon_512x512",512),("icon_512x512@2x",1024)]
for (name, pixels) in sizes { try drawIcon(pixels).write(to: iconset.appendingPathComponent(name + ".png")) }
try drawIcon(1024).write(to: brand.appendingPathComponent("Notchest-AppIcon.png"))
try drawIcon(256).write(to: root.appendingPathComponent("site/icon.png"))
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/Notchest.icns").path]
try task.run(); task.waitUntilExit()
guard task.terminationStatus == 0 else { fatalError("iconutil could not create Notchest.icns") }
print("Generated Aurora Orbit icon, website icon, and all macOS sizes (16–1024 px).")
