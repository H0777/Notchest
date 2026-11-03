import Foundation
@preconcurrency import UserNotifications

/// App-local notifications through UNUserNotificationCenter: the documented,
/// free macOS path for the app's own events. Cross-app mirroring remains a
/// separate post-1.0 feasibility study and is intentionally not part of this.
@MainActor
final class NotchestNotifications: NSObject, ObservableObject {
    @Published var enabled: Bool {
        didSet {
            defaults.set(enabled, forKey: "notificationsEnabled")
            if enabled { requestAuthorization() }
        }
    }
    /// Set from the app's language choice; notification wording resolves through it.
    var arabicUI = true
    private let defaults: UserDefaults
    private var authorized = false

    var focusCompleteText: ServiceText { ServiceText("اكتملت جلسة التركيز", "Focus session complete") }
    var focusBodyText: ServiceText { ServiceText("وقت الاستراحة!", "Time for a break!") }
    var stockAlertText: ServiceText { ServiceText("تنبيه سعر السهم", "Stock price alert") }
    var downloadsTitleText: ServiceText { ServiceText("التنزيلات", "Downloads") }
    var volumesTitleText: ServiceText { ServiceText("الأقراص", "Drives") }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        enabled = defaults.object(forKey: "notificationsEnabled") as? Bool ?? false
        super.init()
        // UNUserNotificationCenter.current() is only touched from
        // requestAuthorization()/post(): a bare command-line binary (checks,
        // tests) has no bundle identifier and the center raises there. The
        // running app always reaches those paths through real user actions.
    }

    func requestAuthorization() {
        // Bare binaries (checks, XCTest runners) have no bundle identifier and
        // UNUserNotificationCenter raises there; the real app always has one.
        guard Bundle.main.bundleIdentifier != nil else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                guard let self else { return }
                if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                    self.authorized = true
                } else if settings.authorizationStatus == .notDetermined {
                    center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
                        Task { @MainActor in self?.authorized = granted }
                    }
                } else {
                    self.authorized = false
                }
            }
        }
    }

    /// Posts a user notification if the user enabled them and granted access.
    /// Everything else on the island (toasts, activity feed) keeps working
    /// regardless, so notifications are additive and opt-in.
    func post(title: String, body: String) {
        guard enabled, authorized, Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: "notchest.\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func post(_ title: ServiceText, _ body: ServiceText) {
        post(title: title.resolved(arabicUI: arabicUI), body: body.resolved(arabicUI: arabicUI))
    }

    /// Maps a monitor event (already resolved to the interface language) to a
    /// notification with a stable localized title.
    func postMonitorEvent(title: String, message: String, kind: String) {
        let localizedTitle: ServiceText
        switch kind {
        case "download": localizedTitle = downloadsTitleText
        case "volume": localizedTitle = volumesTitleText
        default: localizedTitle = ServiceText(title, title)
        }
        post(localizedTitle, ServiceText(message, message))
    }
}

extension NotchestNotifications: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // The island is a background-style app; show banners even while running.
        return await MainActor.run { [.banner, .sound] }
    }
}
