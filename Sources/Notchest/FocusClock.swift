import Foundation

/// The deadline is the source of truth, so sleep and delayed UI ticks cannot drift.
struct FocusClock: Codable {
    var duration: TimeInterval = 25 * 60
    var pausedRemaining: TimeInterval = 25 * 60
    var deadline: Date?

    var isRunning: Bool { deadline != nil }

    func remaining(at now: Date) -> TimeInterval {
        max(0, deadline.map { $0.timeIntervalSince(now) } ?? pausedRemaining)
    }

    mutating func start(at now: Date) {
        guard deadline == nil else { return }
        if pausedRemaining <= 0 { pausedRemaining = duration }
        deadline = now.addingTimeInterval(pausedRemaining)
    }

    mutating func pause(at now: Date) {
        pausedRemaining = remaining(at: now)
        deadline = nil
    }

    mutating func reset(minutes: Int) {
        duration = TimeInterval(minutes * 60)
        pausedRemaining = duration
        deadline = nil
    }

    @discardableResult
    mutating func finishIfNeeded(at now: Date) -> Bool {
        guard let deadline, deadline <= now else { return false }
        self.deadline = nil
        pausedRemaining = 0
        return true
    }
}
