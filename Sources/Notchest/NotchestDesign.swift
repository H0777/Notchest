import AppKit
import SwiftUI

// Name the property-wrapper type explicitly, avoiding the newer SDK's same-named macro.
private typealias NotchestViewState<Value> = SwiftUI.State<Value>
private struct NotchestMotionKey: EnvironmentKey { static let defaultValue = true }
extension EnvironmentValues {
    var notchestMotionEnabled: Bool {
        get { self[NotchestMotionKey.self] }
        set { self[NotchestMotionKey.self] = newValue }
    }
}

/// Shared identity and surfaces. Glass belongs to navigation; content uses quieter inset panels.
enum NotchestPalette {
    static func accent(_ theme: String?) -> Color {
        switch theme {
        case "aurora": return Color(red: 0.34, green: 0.85, blue: 1)
        case "ice": return Color(red: 0.72, green: 0.88, blue: 1)
        case "lime": return Color(red: 0.77, green: 0.95, blue: 0.46)
        case "blue": return Color(red: 0.43, green: 0.73, blue: 1)
        case "purple": return Color(red: 0.77, green: 0.70, blue: 1)
        case "orange": return Color(red: 1, green: 0.76, blue: 0.54)
        default: return Color(red: 0.34, green: 0.85, blue: 1)
        }
    }
    static let cyan = Color(red: 0.30, green: 0.84, blue: 1)
    static let violet = Color(red: 0.72, green: 0.55, blue: 1)
    static let mint = Color(red: 0.34, green: 0.91, blue: 0.72)
    static let coral = Color(red: 1, green: 0.57, blue: 0.46)
    static let amber = Color(red: 1, green: 0.76, blue: 0.36)
    static let rose = Color(red: 1, green: 0.49, blue: 0.73)
    static func tabColor(_ tab: NotchestTab) -> Color {
        switch tab {
        case .home: return cyan
        case .developer: return violet
        case .tools: return mint
        case .focus: return coral
        case .clipboard: return mint
        case .shelf: return amber
        case .notes: return rose
        case .settings: return notchestAccent
        }
    }
    static let ink = Color(red: 0.045, green: 0.065, blue: 0.105)
    static let secondary = Color.white.opacity(0.66)

    static func menuImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 20), flipped: false) { rect in
            NSColor.black.setStroke()
            let ring = NSBezierPath(ovalIn: NSRect(x: 2, y: 5, width: 16, height: 10))
            let transform = AffineTransform(translationByX: -10, byY: -10)
            ring.transform(using: transform)
            ring.transform(using: AffineTransform(rotationByDegrees: 32))
            ring.transform(using: AffineTransform(translationByX: 10, byY: 10))
            ring.lineWidth = 1.8
            ring.stroke()
            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: 7.8, y: 7.8, width: 4.4, height: 4.4)).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Notchest"
        return image
    }
}

struct NotchestMark: View {
    var monochrome = false
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            ZStack {
                Ellipse()
                    .stroke(monochrome ? LinearGradient(colors: [notchestAccent, notchestAccent], startPoint: .top, endPoint: .bottom) : LinearGradient(colors: [.white, Color(red: 0.69, green: 0.83, blue: 1), Color(red: 0.48, green: 0.55, blue: 0.9)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: size * 0.085)
                    .frame(width: size * 0.83, height: size * 0.49)
                    .rotationEffect(.degrees(-32))
                Circle()
                    .fill(LinearGradient(colors: monochrome ? [notchestAccent, notchestAccent] : [.white, Color(red: 0.47, green: 0.76, blue: 1), Color(red: 0.27, green: 0.40, blue: 0.93)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: size * 0.24, height: size * 0.24)
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }
        .accessibilityHidden(true)
        .environment(\.layoutDirection, .leftToRight)
    }
}

/// The material is a sibling below the SwiftUI host, keeping all content above AppKit's backdrop layer.
final class NotchestWindowBackdrop: NSVisualEffectView {
    var islandRadius: CGFloat = 30 { didSet { needsLayout = true } }
    override init(frame: NSRect) {
        super.init(frame: frame)
        material = .hudWindow
        blendingMode = .behindWindow
        state = .active
        appearance = NSAppearance(named: .darkAqua)
        wantsLayer = true
        layer?.masksToBounds = true
        let tint = NSView(frame: bounds)
        tint.wantsLayer = true
        tint.layer?.backgroundColor = NSColor(calibratedRed: 0.035, green: 0.055, blue: 0.095, alpha: 0.48).cgColor
        tint.autoresizingMask = [.width, .height]
        addSubview(tint)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() {
        super.layout()
        var flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: bounds.height)
        let mask = CAShapeLayer()
        guard let outline = IslandOutline.path(in: bounds, radius: islandRadius).copy(using: &flip) else { return }
        mask.path = outline
        layer?.mask = mask
        // Clip the system backdrop itself as well as the content layer; otherwise blur can leak as a rectangular frame.
        if bounds.width > 0, bounds.height > 0 {
            maskImage = NSImage(size: bounds.size, flipped: false) { _ in
                guard let context = NSGraphicsContext.current?.cgContext else { return false }
                context.addPath(outline)
                context.setFillColor(NSColor.black.cgColor)
                context.fillPath()
                return true
            }
        }
    }
}

struct NotchestIslandSurface: View {
    let expanded: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        ZStack {
            if !expanded {
                Color.black
            } else if reduceTransparency || contrast == .increased {
                NotchestPalette.ink
            } else {
                NotchestPalette.ink.opacity(0.62)
                GeometryReader { geometry in
                    ZStack {
                        RadialGradient(colors: [NotchestPalette.cyan.opacity(0.28), .clear], center: UnitPoint(x: 0, y: 0.15), startRadius: 0, endRadius: geometry.size.width * 0.7)
                        RadialGradient(colors: [NotchestPalette.violet.opacity(0.35), .clear], center: UnitPoint(x: 1, y: 0.35), startRadius: 0, endRadius: geometry.size.width * 0.72)
                        RadialGradient(colors: [NotchestPalette.rose.opacity(0.19), .clear], center: UnitPoint(x: 0.45, y: 1.1), startRadius: 0, endRadius: geometry.size.width * 0.6)
                        LinearGradient(colors: [.black.opacity(0.5), .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.17))
                    }
                }
            }
        }.allowsHitTesting(false)
    }
}

private struct NotchestInsetSurface: View {
    var radius: CGFloat
    var tint: Color?
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(reduceTransparency ? NotchestPalette.ink : Color.white.opacity(0.045))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(colors: [(tint ?? .white).opacity(tint == nil ? 0.035 : 0.20), (tint ?? .white).opacity(tint == nil ? 0 : 0.035)], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder((tint ?? .white).opacity(contrast == .increased ? 0.5 : tint == nil ? 0.085 : 0.25), lineWidth: 0.7)
            }
    }
}

private struct NotchestGlassControl: ViewModifier {
    var selected: Bool
    var radius: CGFloat
    var tint: Color?
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.notchestMotionEnabled) private var motionEnabled
    @Environment(\.colorSchemeContrast) private var contrast

    @ViewBuilder func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let color = tint ?? notchestAccent
        if reduceTransparency || contrast == .increased {
            content.background(selected ? color.opacity(0.25) : Color(white: 0.15), in: shape)
                .overlay(shape.strokeBorder(.white.opacity(contrast == .increased ? 0.5 : 0.16), lineWidth: 0.8))
        } else if #available(macOS 26, *) {
            content.glassEffect(.regular.tint(selected ? color.opacity(0.26) : nil).interactive(!reduceMotion && motionEnabled), in: shape)
        } else {
            content.background(.ultraThinMaterial, in: shape)
                .background(selected ? color.opacity(0.23) : .clear, in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.16), lineWidth: 0.7))
        }
    }
}

struct NotchestPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.notchestMotionEnabled) private var motionEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(reduceMotion || !motionEnabled ? 1 : configuration.isPressed ? 0.975 : 1)
            .animation(reduceMotion || !motionEnabled ? nil : .spring(response: 0.26, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

private struct NotchestHover: ViewModifier {
    @NotchestViewState private var hovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.notchestMotionEnabled) private var motionEnabled
    let radius: CGFloat
    func body(content: Content) -> some View {
        content
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(.white.opacity(hovered ? 0.045 : 0)).allowsHitTesting(false))
            .onHover { hovered = $0 }
            .animation(reduceMotion || !motionEnabled ? nil : .easeOut(duration: 0.18), value: hovered)
    }
}

extension View {
    func notchestPanel(cornerRadius: CGFloat = 14, tint: Color? = nil) -> some View {
        background { NotchestInsetSurface(radius: cornerRadius, tint: tint) }
    }
    func notchestGlass(selected: Bool = false, radius: CGFloat = 14, tint: Color? = nil) -> some View {
        modifier(NotchestGlassControl(selected: selected, radius: radius, tint: tint))
    }
    func notchestHover(radius: CGFloat = 14) -> some View {
        modifier(NotchestHover(radius: radius))
    }
}
