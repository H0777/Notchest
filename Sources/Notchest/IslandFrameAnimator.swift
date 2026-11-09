import AppKit
import QuartzCore

struct IslandFrameTransition {
    let start: CGRect
    let target: CGRect
    let expanded: Bool

    func frame(at progress: CGFloat) -> CGRect {
        guard progress > 0 else { return start }
        guard progress < 1 else { return target }
        let t = progress
        let amount = expanded
            ? 1 - (1 - t) * (1 - t) * (1 - t)
            : t * t * (3 - 2 * t)
        func blend(_ from: CGFloat, _ to: CGFloat) -> CGFloat { from + (to - from) * amount }

        let width = blend(start.width, target.width)
        let height = blend(start.height, target.height)
        let centerX = blend(start.midX, target.midX)
        let top = blend(start.maxY, target.maxY)
        return CGRect(x: centerX - width / 2, y: top - height, width: width, height: height)
    }
}

@MainActor
final class IslandFrameAnimator: NSObject {
    private weak var panel: NSWindow?
    private var transition: IslandFrameTransition?
    private var startedAt: CFTimeInterval = 0
    private var runningDuration: TimeInterval = 0
    private var invalidateClock: (() -> Void)?

    func setFrame(_ target: CGRect, of panel: NSWindow, duration: TimeInterval, expanded: Bool) {
        if self.panel !== panel { stop() }
        let current = panel.frame
        guard duration.isFinite, duration > 0, current != target, panel.isVisible, panel.screen != nil else {
            stop()
            if current != target { panel.setFrame(target, display: true) }
            return
        }
        if transition?.target == target { return }

        runningDuration = duration
        if let previous = transition {
            // A reversal close to its destination should cover only the distance left.
            let fullTravel = hypot(target.width - previous.target.width, target.height - previous.target.height)
            let remaining = hypot(target.width - current.width, target.height - current.height)
            if fullTravel > 0, remaining > 0 {
                runningDuration *= sqrt(min(1, remaining / fullTravel))
            }
        }
        self.panel = panel
        transition = IslandFrameTransition(start: current, target: target, expanded: expanded)
        startedAt = CACurrentMediaTime()
        guard invalidateClock == nil else { return }
        if #available(macOS 14, *) {
            let link = panel.displayLink(target: self, selector: #selector(displayTick(_:)))
            link.add(to: .main, forMode: .common)
            invalidateClock = { link.invalidate() }
        } else {
            let timer = Timer(timeInterval: 1 / 60, target: self, selector: #selector(timerTick(_:)), userInfo: nil, repeats: true)
            RunLoop.main.add(timer, forMode: .common)
            invalidateClock = { timer.invalidate() }
        }
    }

    @available(macOS 14, *)
    @objc private func displayTick(_ link: CADisplayLink) {
        advance(at: link.targetTimestamp)
    }

    @objc private func timerTick(_ timer: Timer) {
        advance(at: CACurrentMediaTime())
    }

    private func advance(at time: CFTimeInterval) {
        guard let transition, let panel else { stop(); return }
        let progress = (time - startedAt) / runningDuration
        let frame = transition.frame(at: progress)
        if progress >= 1 { stop() }
        panel.setFrame(frame, display: true)
    }

    func stop() {
        invalidateClock?()
        invalidateClock = nil
        transition = nil
        panel = nil
    }
}
