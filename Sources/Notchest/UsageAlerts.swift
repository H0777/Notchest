import Foundation

struct UsageLimitAlert {
    let id: String
    let percent: Int
    let minutes: Int
}
struct UsageAlertPolicy {
    private var emitted = Set<String>()
    mutating func evaluate(_ windows: [UsageWindow], at now: Date = Date()) -> [UsageLimitAlert] {
        var alerts: [UsageLimitAlert] = []
        for window in windows {
            guard (window.resetsAt ?? .distantFuture) > now else { continue }
            let reset = window.resetsAt?.timeIntervalSince1970 ?? Calendar.current.startOfDay(for: now).timeIntervalSince1970
            let key = "\(window.minutes):\(Int(reset))"
            let threshold = window.usedPercent >= 95 ? 95 : window.usedPercent >= 80 ? 80 : nil
            guard let threshold, !emitted.contains("\(key):\(threshold)") else { continue }
            emitted.insert("\(key):80")
            if threshold == 95 { emitted.insert("\(key):95") }
            alerts.append(UsageLimitAlert(id: "limit:\(key):\(threshold)", percent: Int(window.usedPercent), minutes: window.minutes))
        }
        if emitted.count > 256 { emitted = Set(emitted.sorted().suffix(128)) }
        return alerts
    }
}
