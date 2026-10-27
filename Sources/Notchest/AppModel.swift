import AppKit
import Combine
import IOKit.ps
import IOKit.pwr_mgt
import ServiceManagement

struct NotchestDisplayOption: Identifiable, Equatable {
    let id: String
    let name: String
}

enum NotchestTab: String, CaseIterable, Identifiable {
    case home, developer, tools, focus, clipboard, shelf, notes, settings
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .home: return "square.grid.2x2"
        case .developer: return "chevron.left.forwardslash.chevron.right"
        case .tools: return "sparkles"
        case .focus: return "timer"
        case .clipboard: return "doc.on.clipboard"
        case .shelf: return "tray"
        case .notes: return "square.and.pencil"
        case .settings: return "slider.horizontal.3"
        }
    }
    func title(_ arabic: Bool) -> String {
        switch self {
        case .home: return arabic ? "الرئيسية" : "Overview"
        case .developer: return arabic ? "المطوّر" : "Developer"
        case .tools: return arabic ? "أدوات" : "Tools"
        case .focus: return arabic ? "التركيز" : "Focus"
        case .clipboard: return arabic ? "الحافظة" : "Clipboard"
        case .shelf: return arabic ? "الملفات" : "Shelf"
        case .notes: return arabic ? "ملاحظات" : "Notes"
        case .settings: return arabic ? "الإعدادات" : "Settings"
        }
    }
}

struct Clip: Identifiable {
    let id = UUID()
    let text: String
    let source: String
    let date = Date()
}

struct ShelfItem: Identifiable, Codable {
    let id: UUID
    let bookmark: Data
    let fallbackPath: String

    init(url: URL) throws {
        id = UUID()
        bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        fallbackPath = url.path
    }

    var url: URL {
        var stale = false
        return (try? URL(resolvingBookmarkData: bookmark, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale))
            ?? URL(fileURLWithPath: fallbackPath)
    }
}

@MainActor
final class AppModel: ObservableObject {
    let developer = DeveloperModel()
    let tools = NativeTools()
    let activity = ActivityCenter()
    let monitor = SystemMonitor()
    let weather = WeatherModel()
    let stocks = StocksModel()
    @Published var activityFlash: NotchestActivity?
    @Published var display = IslandDisplay()
    @Published var availableDisplays: [NotchestDisplayOption] = []
    @Published var selectedDisplayID: String {
        didSet { defaults.set(selectedDisplayID, forKey: "selectedDisplayID") }
    }
    @Published var accentTheme: String {
        didSet { defaults.set(accentTheme, forKey: "accentTheme") }
    }
    @Published var launchAtLogin: Bool
    @Published var islandPreferences: IslandPreferences {
        didSet {
            if let data = try? JSONEncoder().encode(islandPreferences.validated()) { defaults.set(data, forKey: "islandPreferences") }
        }
    }
    @Published var expanded = false
    @Published var pinned = false
    @Published var paletteVisible = false
    @Published var paletteQuery = ""
    @Published var stopwatchMode = false
    @Published var stopwatchStarted: Date?
    @Published var stopwatchElapsed: TimeInterval = 0
    @Published var tab: NotchestTab = .home
    @Published var now = Date()
    @Published var clock: FocusClock
    @Published var clips: [Clip] = []
    @Published var clipboardSearch = ""
    @Published var dropTargeted = false
    @Published var shelf: [ShelfItem] = []
    @Published var battery: Int?
    @Published var charging = false
    @Published var awakeUntil: Date?
    @Published var toast: String?
    @Published var sessions: Int {
        didSet { defaults.set(sessions, forKey: "sessions") }
    }
    @Published var arabic: Bool {
        didSet { defaults.set(arabic, forKey: "arabic") }
    }
    @Published var hoverEnabled: Bool {
        didSet { defaults.set(hoverEnabled, forKey: "hoverEnabled") }
    }
    @Published var clipboardEnabled: Bool {
        didSet {
            defaults.set(clipboardEnabled, forKey: "clipboardEnabled")
            configureClipboard()
        }
    }
    @Published var note: String {
        didSet { defaults.set(note, forKey: "note") }
    }

    private let defaults: UserDefaults
    private var ticker: Timer?
    private var clipboardTimer: Timer?
    private var pasteboardChange = 0
    private var assertion: IOPMAssertionID = 0
    private var toastTask: Task<Void, Never>?
    private var activityFlashTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard, startServices: Bool = true) {
        self.defaults = defaults
        selectedDisplayID = defaults.string(forKey: "selectedDisplayID") ?? "auto"
        accentTheme = defaults.string(forKey: "accentTheme") ?? "aurora"
        launchAtLogin = SMAppService.mainApp.status == .enabled
        islandPreferences = (defaults.data(forKey: "islandPreferences").flatMap { try? JSONDecoder().decode(IslandPreferences.self, from: $0) } ?? IslandPreferences()).validated()
        defaults.register(defaults: ["arabic": false, "hoverEnabled": true])
        arabic = defaults.bool(forKey: "arabic")
        hoverEnabled = defaults.bool(forKey: "hoverEnabled")
        clipboardEnabled = defaults.bool(forKey: "clipboardEnabled")
        note = defaults.string(forKey: "note") ?? ""
        sessions = defaults.integer(forKey: "sessions")
        clock = defaults.data(forKey: "focusClock").flatMap { try? JSONDecoder().decode(FocusClock.self, from: $0) } ?? FocusClock()
        shelf = defaults.data(forKey: "shelf").flatMap { try? JSONDecoder().decode([ShelfItem].self, from: $0) } ?? []
        if startServices {
            readBattery()
            configureClipboard()
            ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
            if let ticker { RunLoop.main.add(ticker, forMode: .common) }
        }
    }

    func text(_ arabic: String, _ english: String) -> String { self.arabic ? arabic : english }
    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            launchAtLogin = SMAppService.mainApp.status == .enabled
            if SMAppService.mainApp.status == .requiresApproval {
                showToast(text("اسمح بNotchest في إعدادات عناصر تسجيل الدخول", "Allow Notchest in Login Items settings"))
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            showToast(error.localizedDescription)
        }
    }
    var remaining: Int { Int(ceil(clock.remaining(at: now))) }
    var timeLabel: String { String(format: "%02d:%02d", remaining / 60, remaining % 60) }
    var progress: Double { 1 - min(1, clock.remaining(at: now) / max(1, clock.duration)) }
    var awake: Bool { awakeUntil != nil }
    var stopwatchSeconds: Int { Int(stopwatchElapsed + (stopwatchStarted.map { max(0, now.timeIntervalSince($0)) } ?? 0)) }
    var stopwatchLabel: String { String(format: "%02d:%02d:%02d", stopwatchSeconds / 3600, stopwatchSeconds / 60 % 60, stopwatchSeconds % 60) }
    var focusDisplayLabel: String { stopwatchMode ? stopwatchLabel : timeLabel }
    var focusIsRunning: Bool { stopwatchMode ? stopwatchStarted != nil : clock.isRunning }
    var focusProgress: Double { stopwatchMode ? Double(stopwatchSeconds % 60) / 60 : progress }

    func toggleStopwatch() {
        now = Date()
        if let started = stopwatchStarted { stopwatchElapsed += now.timeIntervalSince(started); stopwatchStarted = nil }
        else { stopwatchStarted = now }
    }
    func resetStopwatch() { stopwatchStarted = nil; stopwatchElapsed = 0 }

    func select(_ tab: NotchestTab) {
        self.tab = tab
        paletteVisible = false
        expanded = true
    }

    func toggleTimer() {
        now = Date()
        if clock.isRunning { clock.pause(at: now) } else { clock.start(at: now) }
        saveClock()
    }

    func resetTimer(minutes: Int? = nil) {
        clock.reset(minutes: minutes ?? Int(clock.duration / 60))
        now = Date()
        saveClock()
    }

    func tick(at date: Date = Date()) {
        now = date
        if clock.finishIfNeeded(at: date) {
            sessions += 1
            saveClock()
            NSSound(named: "Glass")?.play()
            showToast(text("اكتملت جلستك. وقت الاستراحة!", "Session complete. Take a breath."))
            tab = .focus
            expanded = true
        }
        if let awakeUntil, awakeUntil <= date { stopAwake() }
        if Int(date.timeIntervalSince1970) % 30 == 0 { readBattery() }
    }

    private func saveClock() {
        if let data = try? JSONEncoder().encode(clock) { defaults.set(data, forKey: "focusClock") }
    }

    func showToast(_ message: String) {
        toastTask?.cancel()
        toast = message
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    func flashActivity(_ item: NotchestActivity) {
        activityFlashTask?.cancel()
        activityFlash = item
        activityFlashTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled else { return }
            self?.activityFlash = nil
        }
    }

    private func configureClipboard() {
        clipboardTimer?.invalidate()
        clipboardTimer = nil
        pasteboardChange = NSPasteboard.general.changeCount
        if !clipboardEnabled { clips.removeAll(); return }
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollClipboard() }
        }
        if let clipboardTimer { RunLoop.main.add(clipboardTimer, forMode: .common) }
    }

    static func mayRecordClipboard(types: [String]) -> Bool {
        let excluded: Set<String> = [
            "org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType",
            "org.nspasteboard.AutoGeneratedType", "com.agilebits.onepassword",
            "de.petermaurer.TransientPasteboardType", "com.typeit4me.clipping"
        ]
        return excluded.isDisjoint(with: types)
    }

    private func pollClipboard() {
        let pb = NSPasteboard.general
        guard clipboardEnabled, pb.changeCount != pasteboardChange else { return }
        pasteboardChange = pb.changeCount
        guard Self.mayRecordClipboard(types: (pb.types ?? []).map(\.rawValue)),
              let value = pb.string(forType: .string), !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              value.utf8.count <= 32_768 else { return }
        clips.removeAll { $0.text == value }
        clips.insert(Clip(text: value, source: NSWorkspace.shared.frontmostApplication?.localizedName ?? ""), at: 0)
        clips = Array(clips.prefix(30))
    }

    func copy(_ clip: Clip) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(clip.text, forType: .string)
        pasteboardChange = pb.changeCount
        showToast(text("تم النسخ", "Copied to clipboard"))
    }

    func chooseFiles() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.prompt = text("إضافة إلى الرف", "Add to Shelf")
        if panel.runModal() == .OK { addFiles(panel.urls) }
    }

    func addFiles(_ urls: [URL]) {
        var failures = 0
        for url in urls where url.isFileURL {
            guard !shelf.contains(where: { $0.url.standardizedFileURL == url.standardizedFileURL }) else { continue }
            guard shelf.count < 24 else { showToast(text("الرف يتّسع لـ 24 ملفًا", "The shelf holds up to 24 items")); break }
            do { shelf.append(try ShelfItem(url: url)) } catch { failures += 1 }
        }
        saveShelf()
        if failures > 0 { showToast(text("تعذّرت إضافة بعض الملفات", "Some files could not be added")) }
    }

    func removeFile(_ item: ShelfItem) {
        shelf.removeAll { $0.id == item.id }
        saveShelf()
    }

    private func saveShelf() {
        if let data = try? JSONEncoder().encode(shelf) { defaults.set(data, forKey: "shelf") }
    }

    func openFile(_ item: ShelfItem) {
        if !NSWorkspace.shared.open(item.url) {
            showToast(text("الملف غير متاح. قد يكون نُقل أو حُذف.", "File unavailable. It may have moved or been removed."))
        }
    }

    func toggleAwake() {
        if awake { stopAwake(); return }
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn), "Notchest focus session" as CFString, &assertion)
        if result == kIOReturnSuccess { awakeUntil = Date().addingTimeInterval(3600) }
        else { showToast(text("تعذّر تفعيل إبقاء الجهاز مستيقظًا", "Could not keep the Mac awake")) }
    }

    private func stopAwake() {
        if assertion != 0 { IOPMAssertionRelease(assertion); assertion = 0 }
        awakeUntil = nil
    }

    private func readBattery() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else { return }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let capacity = description[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = description[kIOPSMaxCapacityKey] as? Int, maximum > 0 else { continue }
            battery = min(100, max(0, capacity * 100 / maximum))
            charging = description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
            return
        }
        battery = nil
        charging = true
    }

    func shutdown() {
        ticker?.invalidate()
        clipboardTimer?.invalidate()
        toastTask?.cancel()
        activityFlashTask?.cancel()
        saveClock()
        stopAwake()
    }
}
