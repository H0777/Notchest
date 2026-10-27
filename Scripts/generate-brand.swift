#!/usr/bin/env swift
import AppKit

// Notchest's original, editable vector construction. No external fonts or image assets required.
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let brand = root.appendingPathComponent("Brand")
let iconset = root.appendingPathComponent(".brand-build/Notchest.iconset")
try FileManager.default.createDirectory(at: brand, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: red, green: green, blue: blue, alpha: alpha)
}
func gradient(_ colors: [CGColor], _ locations: [CGFloat]? = nil) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations)!
}
func drawIcon(_ pixels: Int) throws -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    let context = graphics.cgContext
    context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    context.setAllowsAntialiasing(true)
    let tile = CGPath(roundedRect: CGRect(x: 96, y: 96, width: 832, height: 832), cornerWidth: 190, cornerHeight: 190, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: color(0.07, 0.12, 0.25, 0.26))
    context.addPath(tile); context.setFillColor(color(0.69, 0.78, 0.95)); context.fillPath()
    context.restoreGState()
    context.saveGState()
    context.addPath(tile); context.clip()
    context.drawLinearGradient(gradient([color(0.96, 0.99, 1), color(0.76, 0.85, 1), color(0.37, 0.48, 0.83)]), start: CGPoint(x: 210, y: 960), end: CGPoint(x: 820, y: 80), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    context.drawRadialGradient(gradient([color(0.7, 0.59, 1, 0.5), color(0.65, 0.68, 1, 0)]), startCenter: CGPoint(x: 865, y: 760), startRadius: 0, endCenter: CGPoint(x: 865, y: 760), endRadius: 630, options: [])
    context.drawRadialGradient(gradient([color(1, 1, 1, 0.75), color(1, 1, 1, 0)]), startCenter: CGPoint(x: 250, y: 850), startRadius: 0, endCenter: CGPoint(x: 250, y: 850), endRadius: 700, options: [])
    context.restoreGState()
    context.addPath(tile); context.setStrokeColor(color(1, 1, 1, 0.8)); context.setLineWidth(3); context.strokePath()
    let innerTile = CGPath(roundedRect: CGRect(x: 105, y: 105, width: 814, height: 814), cornerWidth: 181, cornerHeight: 181, transform: nil)
    context.addPath(innerTile); context.setStrokeColor(color(1, 1, 1, 0.19)); context.setLineWidth(2); context.strokePath()

    // The tilted notchest is a single shape at every size, matching NotchestMark and the SVG logo.
    context.saveGState()
    context.translateBy(x: 512, y: 512)
    context.rotate(by: 32 * .pi / 180)
    let ellipse = CGRect(x: -290.5, y: -171.5, width: 581, height: 343)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 10, height: -24), blur: 24, color: color(0.15, 0.23, 0.56, 0.38))
    context.addEllipse(in: ellipse); context.setStrokeColor(color(0.56, 0.65, 0.87)); context.setLineWidth(62); context.strokePath()
    context.restoreGState()
    context.saveGState()
    context.addEllipse(in: ellipse); context.setLineWidth(60); context.replacePathWithStrokedPath(); context.clip()
    context.drawLinearGradient(gradient([color(0.44, 0.54, 0.8), color(0.85, 0.94, 1), color(1, 1, 1), color(0.67, 0.77, 0.98)], [0, 0.38, 0.72, 1]), start: CGPoint(x: 0, y: -210), end: CGPoint(x: 0, y: 210), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    context.restoreGState()
    context.addEllipse(in: ellipse.insetBy(dx: -22, dy: -22)); context.setLineWidth(2); context.setStrokeColor(color(1, 1, 1, 0.45)); context.strokePath()
    context.restoreGState()

    let orb = CGRect(x: 428, y: 428, width: 168, height: 168)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 5, height: -18), blur: 22, color: color(0.16, 0.28, 0.63, 0.4))
    context.addEllipse(in: orb); context.setFillColor(color(0.35, 0.6, 0.95)); context.fillPath()
    context.restoreGState()
    context.saveGState()
    context.addEllipse(in: orb); context.clip()
    context.drawLinearGradient(gradient([color(0.25, 0.33, 0.77), color(0.28, 0.61, 0.97), color(0.85, 0.98, 1)]), start: CGPoint(x: 555, y: 425), end: CGPoint(x: 470, y: 605), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    context.drawRadialGradient(gradient([color(1, 1, 1, 0.88), color(1, 1, 1, 0)]), startCenter: CGPoint(x: 477, y: 564), startRadius: 0, endCenter: CGPoint(x: 477, y: 564), endRadius: 88, options: [])
    context.restoreGState()
    context.addEllipse(in: orb); context.setLineWidth(1.8); context.setStrokeColor(color(1, 1, 1, 0.55)); context.strokePath()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

let sizes: [(String, Int)] = [("icon_16x16",16),("icon_16x16@2x",32),("icon_32x32",32),("icon_32x32@2x",64),("icon_128x128",128),("icon_128x128@2x",256),("icon_256x256",256),("icon_256x256@2x",512),("icon_512x512",512),("icon_512x512@2x",1024)]
for (name, pixels) in sizes { try drawIcon(pixels).write(to: iconset.appendingPathComponent(name + ".png")) }
try drawIcon(1024).write(to: brand.appendingPathComponent("Notchest-AppIcon.png"))
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/Notchest.icns").path]
try task.run(); task.waitUntilExit()
guard task.terminationStatus == 0 else { fatalError("iconutil could not create Notchest.icns") }
print("Generated Notchest icon and all macOS icon sizes.")
