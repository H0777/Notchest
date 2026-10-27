#!/usr/bin/env swift
import AppKit
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let width = 1200, height = 630
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let context = NSGraphicsContext.current!.cgContext
NSColor(calibratedRed: 0.035, green: 0.043, blue: 0.075, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()
let colors = [NSColor(calibratedRed: 0.19, green: 0.41, blue: 0.51, alpha: 0.65).cgColor, NSColor.clear.cgColor] as CFArray
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0,1])!
context.drawRadialGradient(gradient, startCenter: CGPoint(x: 100,y: 580), startRadius: 0, endCenter: CGPoint(x: 100,y: 580), endRadius: 720, options: [])
let violet = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [NSColor(calibratedRed: 0.36, green: 0.22, blue: 0.56, alpha: 0.6).cgColor, NSColor.clear.cgColor] as CFArray, locations: [0,1])!
context.drawRadialGradient(violet, startCenter: CGPoint(x: 1140,y: 100), startRadius: 0, endCenter: CGPoint(x: 1140,y: 100), endRadius: 720, options: [])
func text(_ value: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat, _ weight: NSFont.Weight, _ color: NSColor) {
 value.draw(at: CGPoint(x: x,y: y), withAttributes: [.font:NSFont.systemFont(ofSize: size,weight: weight),.foregroundColor:color])
}
let icon = NSImage(contentsOf: root.appendingPathComponent("Brand/Notchest-AppIcon.png"))!
icon.draw(in: NSRect(x: 72,y: 300,width: 190,height: 190))
text("Notchest", 280, 365, 76, .semibold, .white)
text("Your tools. A little closer.", 95, 210, 42, .medium, NSColor(calibratedRed: 0.83,green: 0.88,blue: 1,alpha: 1))
text("Focus  /  Developer tools  /  AI usage  /  Everyday utilities", 98, 152, 21, .regular, NSColor(calibratedWhite: 0.70,alpha: 1))
text("NATIVE MAC APP", 98, 65, 13, .medium, NSColor(calibratedRed: 0.45,green: 0.85,blue: 1,alpha: 1))
text("SWIFTUI + APPKIT     ·     ENGLISH + العربية", 675, 65, 13, .medium, NSColor(calibratedWhite: 0.70,alpha: 1))
NSGraphicsContext.restoreGraphicsState()
let data = rep.representation(using: .png,properties: [:])!
try data.write(to: root.appendingPathComponent("site/assets/social-preview.png"))
try data.write(to: root.appendingPathComponent("Brand/Notchest-Banner.png"))
print("Generated repository banner and social preview.")
