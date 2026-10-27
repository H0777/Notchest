import Foundation
import CoreGraphics

enum IslandMotion: String, Codable, CaseIterable, Identifiable {
    case gentle, balanced, quick
    var id: String { rawValue }

    var openDuration: TimeInterval {
        switch self { case .gentle: return 0.55; case .balanced: return 0.42; case .quick: return 0.28 }
    }
    var closeDuration: TimeInterval {
        switch self { case .gentle: return 0.42; case .balanced: return 0.32; case .quick: return 0.22 }
    }
    var navigationDuration: TimeInterval {
        switch self { case .gentle: return 0.34; case .balanced: return 0.25; case .quick: return 0.17 }
    }
    func title(arabic: Bool) -> String {
        switch self {
        case .gentle: return arabic ? "هادئة" : "Gentle"
        case .balanced: return arabic ? "متوازنة" : "Balanced"
        case .quick: return arabic ? "سريعة" : "Quick"
        }
    }
}

struct IslandPreferences: Codable, Equatable {
    var compactWidth: Double = 300
    var compactHeight: Double = 34
    var expandedWidth: Double = 758
    var expandedHeight: Double = 544
    var motionEnabled = true
    var motion: IslandMotion = .balanced

    func validated() -> IslandPreferences {
        func valid(_ value: Double, _ range: ClosedRange<Double>, fallback: Double) -> Double {
            guard value.isFinite else { return fallback }
            return min(range.upperBound, max(range.lowerBound, value))
        }
        var result = self
        result.compactWidth = valid(compactWidth, 200...600, fallback: 300)
        result.compactHeight = valid(compactHeight, 34...100, fallback: 34)
        result.expandedWidth = valid(expandedWidth, 660...1200, fallback: 758)
        result.expandedHeight = valid(expandedHeight, 440...900, fallback: 544)
        return result
    }

    mutating func resetDimensions() {
        let defaults = IslandPreferences()
        compactWidth = defaults.compactWidth
        compactHeight = defaults.compactHeight
        expandedWidth = defaults.expandedWidth
        expandedHeight = defaults.expandedHeight
    }
}

struct IslandDisplay: Equatable {
    var frame: CGRect = CGRect(x: 0, y: 0, width: 1440, height: 900)
    var visibleFrame: CGRect = CGRect(x: 0, y: 0, width: 1440, height: 860)
    var notchWidth: CGFloat = 120
    var safeTop: CGFloat = 0

    var minimumCompactWidth: CGFloat { min(max(1, frame.width - 16), max(200, notchWidth + 84)) }
    var minimumCompactHeight: CGFloat { min(max(1, frame.height - 16), max(34, safeTop + 3)) }

    func size(preferences raw: IslandPreferences, expanded: Bool) -> CGSize {
        let prefs = raw.validated()
        let maximumWidth = max(1, frame.width - 16)
        let maximumHeight = max(1, min(frame.height - 12, visibleFrame.height + max(0, safeTop)))
        let compactWidth = min(maximumWidth, max(minimumCompactWidth, CGFloat(prefs.compactWidth)))
        let compactHeight = min(maximumHeight, max(minimumCompactHeight, CGFloat(prefs.compactHeight)))
        guard expanded else { return CGSize(width: compactWidth, height: compactHeight) }
        let width = min(maximumWidth, max(compactWidth, CGFloat(prefs.expandedWidth)))
        let height = min(maximumHeight, max(compactHeight + 280, CGFloat(prefs.expandedHeight)))
        return CGSize(width: width, height: height)
    }

    func windowFrame(preferences: IslandPreferences, expanded: Bool) -> CGRect {
        let size = size(preferences: preferences, expanded: expanded)
        return CGRect(x: frame.midX - size.width / 2, y: frame.maxY - size.height, width: size.width, height: size.height)
    }
}

/// Screen-attached shoulders and rounded lower corners, shared by SwiftUI and the AppKit backdrop.
enum IslandOutline {
    static func path(in bounds: CGRect, radius: CGFloat, inset: CGFloat = 0) -> CGPath {
        let rect = bounds.insetBy(dx: inset, dy: inset)
        let path = CGMutablePath()
        guard rect.width > 0, rect.height > 0 else { return path }
        let requested = radius.isFinite ? max(0, radius - inset) : 0
        let shoulder = min(requested * 0.6, rect.width / 6, rect.height * 0.3)
        let bottom = min(requested, (rect.width - 2 * shoulder) / 2, rect.height - shoulder)
        let left = rect.minX + shoulder, right = rect.maxX - shoulder
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addCurve(to: CGPoint(x: right, y: rect.minY + shoulder),
                      control1: CGPoint(x: rect.maxX - shoulder * 0.55, y: rect.minY),
                      control2: CGPoint(x: right, y: rect.minY + shoulder * 0.45))
        path.addLine(to: CGPoint(x: right, y: rect.maxY - bottom))
        path.addQuadCurve(to: CGPoint(x: right - bottom, y: rect.maxY), control: CGPoint(x: right, y: rect.maxY))
        path.addLine(to: CGPoint(x: left + bottom, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: left, y: rect.maxY - bottom), control: CGPoint(x: left, y: rect.maxY))
        path.addLine(to: CGPoint(x: left, y: rect.minY + shoulder))
        path.addCurve(to: CGPoint(x: rect.minX, y: rect.minY),
                      control1: CGPoint(x: left, y: rect.minY + shoulder * 0.45),
                      control2: CGPoint(x: rect.minX + shoulder * 0.55, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
