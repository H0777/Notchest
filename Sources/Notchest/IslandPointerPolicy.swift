import Foundation

/// One pending action at a time. Callers supply monotonic time and the actual pointer position.
struct IslandPointerPolicy {
    enum Action { case open, close }

    private(set) var deadline: TimeInterval?
    private var waitingForExit = false
    var needsCompactTracking: Bool { waitingForExit || deadline != nil }

    mutating func transitioned(expanded: Bool, inside: Bool, now: TimeInterval) {
        // A click or Escape can collapse the island with the pointer still on the header.
        waitingForExit = !expanded && inside
        deadline = expanded && !inside ? now + 3 : nil
    }

    mutating func evaluate(expanded: Bool, inside: Bool, hoverEnabled: Bool, holdOpen: Bool, now: TimeInterval) -> Action? {
        if !inside { waitingForExit = false }
        let pending: Action
        if expanded && !inside && !holdOpen {
            pending = .close
        } else if !expanded && inside && hoverEnabled && !waitingForExit {
            pending = .open
        } else {
            deadline = nil
            return nil
        }
        let due = deadline ?? now + (pending == .open ? 0.18 : 0.60)
        guard now >= due else { deadline = due; return nil }
        deadline = nil
        return pending
    }
}
