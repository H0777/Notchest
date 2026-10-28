#!/usr/bin/env swift
import AppKit

// Artwork contains only the background and instructions. Finder supplies the real, draggable icons.
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let destination = root.appendingPathComponent("Brand/Installer")
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
let width: CGFloat = 760, height: CGFloat = 500
func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
        green: CGFloat((hex >> 8) & 255) / 255,
        blue: CGFloat(hex & 255) / 255, alpha: alpha)
}
func gradient(_ colors: [NSColor]) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: colors.map(\.cgColor) as CFArray, locations: nil)!
}
func render(scale: Int) throws -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width) * scale,
        pixelsHigh: Int(height) * scale, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    // A 2× PNG retains its logical size, so tiffutil can combine both representations for Retina.
    bitmap.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.current = graphics
    let context = graphics.cgContext
    context.drawLinearGradient(gradient([color(0x101A31), color(0x151329), color(0x211431)]),
        start: CGPoint(x: 0, y: height), end: CGPoint(x: width, y: 0), options: [])
    func glow(_ hex: UInt32, _ alpha: CGFloat, _ x: CGFloat, _ y: CGFloat, _ radius: CGFloat) {
        context.drawRadialGradient(gradient([color(hex, alpha), color(hex, 0)]),
            startCenter: CGPoint(x: x, y: y), startRadius: 0,
            endCenter: CGPoint(x: x, y: y), endRadius: radius, options: [])
    }
    glow(0x05C9DA, 0.20, 40, 450, 490)
    glow(0x7750FF, 0.28, 740, 380, 430)
    glow(0xF7459D, 0.15, 480, -30, 350)
    func text(_ value: String, _ rect: CGRect, _ size: CGFloat, _ weight: NSFont.Weight,
              _ hex: UInt32, _ alignment: NSTextAlignment = .left, _ rtl: Bool = false) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.baseWritingDirection = rtl ? .rightToLeft : .leftToRight
        value.draw(in: CGRect(x: rect.minX, y: height - rect.maxY, width: rect.width, height: rect.height),
            withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight),
                .foregroundColor: color(hex), .paragraphStyle: paragraph])
    }
    let icon = NSImage(contentsOf: root.appendingPathComponent("Brand/Notchest-AppIcon.png"))!
    icon.draw(in: NSRect(x: 48, y: height - 66, width: 36, height: 36))
    text("Notchest", CGRect(x: 94, y: 37, width: 200, height: 26), 19, .semibold, 0xE4E9FA)
    text("INSTALL FOR MAC", CGRect(x: 530, y: 42, width: 180, height: 20), 10, .semibold, 0x8FA8C8, .right)
    text("Your tools. A little closer.", CGRect(x: 52, y: 94, width: 660, height: 48), 34, .semibold, 0xF5F7FF)
    text("Drag Notchest into Applications to get started.", CGRect(x: 54, y: 148, width: 650, height: 26), 16, .regular, 0xB6C6E0)

    // The two wells line up with icon_locations in Scripts/dmg-settings.py.
    for (x, accent) in [(CGFloat(100), UInt32(0x36DEEB)), (CGFloat(460), UInt32(0xAD8AFF))] {
        let rect = CGRect(x: x, y: height - 386, width: 200, height: 184)
        let card = CGPath(roundedRect: rect, cornerWidth: 28, cornerHeight: 28, transform: nil)
        context.saveGState()
        context.addPath(card); context.clip()
        context.drawLinearGradient(gradient([color(0xFFFFFF, 0.075), color(0xFFFFFF, 0.025)]),
            start: CGPoint(x: x, y: rect.maxY), end: CGPoint(x: x + 200, y: rect.minY), options: [])
        glow(accent, 0.10, x + 100, rect.maxY, 155)
        context.restoreGState()
        context.addPath(card); context.setLineWidth(1)
        context.setStrokeColor(color(0xFFFFFF, 0.13).cgColor); context.strokePath()
    }
    // Finder owns filename colors. Pale glass caption wells keep its native dark labels legible.
    for (x, tint) in [(CGFloat(116), UInt32(0xD4F5FA)), (CGFloat(476), UInt32(0xE7DBFF))] {
        let well = CGPath(roundedRect: CGRect(x: x, y: height - 373, width: 168, height: 32),
            cornerWidth: 16, cornerHeight: 16, transform: nil)
        context.addPath(well); context.setFillColor(color(tint, 0.94).cgColor); context.fillPath()
    }
    let arrow = CGMutablePath()
    arrow.move(to: CGPoint(x: 334, y: height - 278))
    arrow.addLine(to: CGPoint(x: 422, y: height - 278))
    arrow.move(to: CGPoint(x: 406, y: height - 264))
    arrow.addLine(to: CGPoint(x: 422, y: height - 278))
    arrow.addLine(to: CGPoint(x: 406, y: height - 292))
    context.saveGState()
    context.addPath(arrow); context.setLineWidth(4); context.setLineCap(.round); context.setLineJoin(.round)
    context.replacePathWithStrokedPath(); context.clip()
    context.drawLinearGradient(gradient([color(0x50E6F0), color(0xBDA5FF)]),
        start: CGPoint(x: 330, y: 222), end: CGPoint(x: 426, y: 222), options: [])
    context.restoreGState()
    text("DRAG", CGRect(x: 334, y: 304, width: 90, height: 20), 10, .semibold, 0x8EA4C8, .center)
    text("Once copied, open Notchest from Applications.", CGRect(x: 50, y: 417, width: 660, height: 22), 13, .medium, 0xB6C6E0, .center)
    text("اسحب Notchest إلى مجلد التطبيقات، ثم افتحه من هناك.", CGRect(x: 50, y: 446, width: 660, height: 24), 12, .regular, 0x91A0BF, .center, true)
    return bitmap.representation(using: .png, properties: [:])!
}
try render(scale: 1).write(to: destination.appendingPathComponent("background.png"))
try render(scale: 2).write(to: destination.appendingPathComponent("background@2x.png"))
print("Generated 760×500 installer artwork with a 2× Retina representation.")
