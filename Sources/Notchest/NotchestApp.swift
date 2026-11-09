import AppKit
import SwiftUI
import Combine
import Carbon
import SwiftTerm

private final class ClearHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool { false }
}

final class IslandPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var panel: IslandPanel!
    private var backdrop: NotchestWindowBackdrop?
    private var statusItem: NSStatusItem!
    private var subscriptions = Set<AnyCancellable>()
    private let frameAnimator = IslandFrameAnimator()
    private var pointerPolicy = IslandPointerPolicy()
    private var pointerTimer: Timer?
    private var scheduledDeadline: TimeInterval?
    private var eventMonitor: Any?
    private var outsideClickMonitor: Any?
    private var presentedExpanded = false
    private var trackingMenus = Set<ObjectIdentifier>()
    private var hotKey: EventHotKeyRef?
    private var paletteHotKey: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?
    private var screen: NSScreen?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupPanel()
        setupMainMenu()
        setupMenu()
        setupHotKey()
        model.developer.start()
        model.developer.onUsageAlert = { [weak self] alert in
            guard let self else { return }
            self.model.activity.record(id: alert.id, title: "Codex", message: self.model.text("استهلكت \(alert.percent)% من حد النافذة (\(alert.minutes) دقيقة)", "\(alert.percent)% of the \(alert.minutes)-minute limit is used"), kind: "usage")
        }
        model.updates.start()
        model.project.onChanged = { [weak self] run in
            self?.model.activity.record(id: "github-run-\(run.id)", title: run.name, message: run.headBranch, state: run.activityState, url: run.url, kind: "build")
        }
        model.developer.$workingDirectory.removeDuplicates().sink { [weak self] directory in self?.model.project.select(directory) }.store(in: &subscriptions)
        model.project.start()
        model.activity.onRecord = { [weak self] item in self?.model.flashActivity(item) }
        model.monitor.onEvent = { [weak self] title, message, url, kind in
            self?.model.activity.record(title: title, message: message, url: url, kind: kind)
            self?.model.notifications.postMonitorEvent(title: title, message: message, kind: kind)
        }
        model.monitor.start()
        model.weather.start()
        model.stocks.onAlert = { [weak self] symbol, details in
            self?.model.activity.record(title: symbol, message: details, state: "info", kind: "stock")
            guard let self else { return }
            self.model.notifications.post(self.model.notifications.stockAlertText, ServiceText("\(symbol) · \(details)", "\(symbol) · \(details)"))
        }
        model.developer.onCommandFinished = { [weak self] code in
            guard let self else { return }
            self.model.showToast(self.model.text("انتهى الأمر • رمز الخروج \(code)", "Command finished • exit \(code)"))
            self.model.activity.record(id: "local-command", title: self.model.developer.workingDirectory.lastPathComponent, message: self.model.text("انتهى الأمر • رمز الخروج \(code)", "Command finished • exit \(code)"), state: code == 0 ? "success" : "failure", kind: "build")
        }
        model.developer.$commandRunning.removeDuplicates().sink { [weak self] running in
            guard let self, running else { return }
            self.model.activity.record(id: "local-command", title: self.model.developer.workingDirectory.lastPathComponent, message: self.model.text("الأمر قيد التنفيذ", "Command is running"), state: "running", kind: "build")
        }.store(in: &subscriptions)
        model.tools.notify = { [weak self] message in self?.model.showToast(message) }
        model.tools.collapse = { [weak self] in self?.model.expanded = false }
        model.tools.start()
        model.$expanded.removeDuplicates().dropFirst().sink { [weak self] expanded in
            // @Published emits before assignment. Geometry and hover callbacks must see
            // the same state, even if two shortcuts arrive on the same run-loop turn.
            DispatchQueue.main.async {
                guard let self, self.model.expanded == expanded, self.presentedExpanded != expanded else { return }
                self.presentedExpanded = expanded
                self.presentationChanged(expanded: expanded)
            }
        }.store(in: &subscriptions)
        // Recover missed tracking-area exits after resizes or modal interactions using the existing clock.
        model.$now.dropFirst().sink { [weak self] _ in
            guard let self, self.model.expanded || self.pointerPolicy.needsCompactTracking else { return }
            self.reconcilePointer()
        }.store(in: &subscriptions)
        model.$islandPreferences.removeDuplicates().dropFirst().sink { [weak self] _ in
            // Sliders track the pointer directly; animating every intermediate value adds lag.
            DispatchQueue.main.async { self?.resizePanel(animate: false) }
        }.store(in: &subscriptions)
        model.$selectedDisplayID.removeDuplicates().dropFirst().sink { [weak self] _ in
            DispatchQueue.main.async { self?.selectScreenAndResize() }
        }.store(in: &subscriptions)
        model.$arabic.removeDuplicates().dropFirst().sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.setupMenu()
                if let self { self.panel.title = self.model.text("Notchest · Notchest", "Notchest") }
            }
        }.store(in: &subscriptions)
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(menuBegan(_:)), name: NSMenu.didBeginTrackingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(menuEnded(_:)), name: NSMenu.didEndTrackingNotification, object: nil)
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            guard let self else { return event }
            if event.type != .keyDown {
                if event.window !== self.panel { self.dismissForOutsideClick() }
                return event
            }
            guard event.window === self.panel, !self.interactingWithDialogOrMenu else { return event }
            if self.model.expanded && !self.pointerInside(expanded: true) {
                self.pointerPolicy.transitioned(expanded: true, inside: false, now: ProcessInfo.processInfo.systemUptime)
                self.schedulePointerCheck()
            }
            // A real terminal owns its Escape and control sequences while it has focus.
            if self.model.tab == .developer, self.model.developer.section == .terminal,
               !self.model.paletteVisible, self.panel.firstResponder is SwiftTerm.TerminalView { return event }
            if event.modifierFlags.contains([.control, .option]) && !event.modifierFlags.contains(.command) {
                if event.keyCode == kVK_ANSI_K { self.openPalette(); return nil }
                if event.keyCode == kVK_Space { self.toggleIsland(); return nil }
            }
            if event.keyCode == 53 {
                if self.model.paletteVisible { self.model.paletteVisible = false }
                else { self.model.expanded = false }
                return nil
            }
            if event.modifierFlags.contains(.command), let digit = Int(event.charactersIgnoringModifiers ?? ""), (1...7).contains(digit) {
                self.model.select(NotchestTab.allCases[digit - 1]); return nil
            }
            return event
        }
        if !model.setupCompleted {
            model.showingSetup = true
            model.expanded = true
        }
        resizePanel(animate: false)
        panel.orderFrontRegardless()
        reconcilePointer()
    }

    private func setupPanel() {
        chooseScreen()
        measureScreen()
        panel = IslandPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = model.text("Notchest · Notchest", "Notchest")
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovable = false
        panel.animationBehavior = .none
        updateRootView()
        resizePanel(animate: false)
    }

    private func measureScreen() {
        guard let screen else { return }
        let safeTop = screen.safeAreaInsets.top
        let notchWidth: CGFloat
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea, safeTop > 0 {
            notchWidth = max(120, right.minX - left.maxX)
        } else { notchWidth = 120 }
        model.display = IslandDisplay(frame: screen.frame, visibleFrame: screen.visibleFrame, notchWidth: notchWidth, safeTop: safeTop)
    }

    private func screenID(_ screen: NSScreen) -> String {
        let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        return number?.stringValue ?? "unknown"
    }

    private func chooseScreen() {
        let screens = NSScreen.screens
        model.availableDisplays = screens.map { NotchestDisplayOption(id: screenID($0), name: $0.localizedName) }
        screen = screens.first(where: { screenID($0) == model.selectedDisplayID })
            ?? screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? screens.first
    }

    private func selectScreenAndResize() {
        chooseScreen()
        measureScreen()
        resizePanel(animate: false)
    }

    private func updateRootView() {
        let host = ClearHostingView(rootView: IslandView(model: model, onHover: { [weak self] _ in self?.reconcilePointer() }, activate: { [weak self] in self?.panel.makeKey() }))
        host.sizingOptions = []
        let background = NotchestWindowBackdrop(frame: panel.contentView?.bounds ?? .zero)
        host.wantsLayer = true
        host.layer?.isOpaque = false
        host.layer?.backgroundColor = NSColor.clear.cgColor
        host.translatesAutoresizingMaskIntoConstraints = false
        background.contentContainer.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: background.contentContainer.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: background.contentContainer.trailingAnchor),
            host.topAnchor.constraint(equalTo: background.contentContainer.topAnchor),
            host.bottomAnchor.constraint(equalTo: background.contentContainer.bottomAnchor)
        ])
        backdrop = background
        panel.contentView = background
    }

    private func resizePanel(animate: Bool = true, expanded newState: Bool? = nil) {
        guard screen != nil, let panel else { return }
        let expanded = newState ?? model.expanded
        let preferences = model.islandPreferences
        backdrop?.configureCornerRadii(compactHeight: model.display.size(preferences: preferences, expanded: false).height,
                                       expandedHeight: model.display.size(preferences: preferences, expanded: true).height)
        let frame = model.display.windowFrame(preferences: preferences, expanded: expanded)
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion || !model.islandPreferences.motionEnabled
        let duration = expanded ? preferences.motion.openDuration : preferences.motion.closeDuration
        frameAnimator.setFrame(frame, of: panel, duration: animate && !reduced ? duration : 0, expanded: expanded)
    }

    private func pointerInside(expanded: Bool) -> Bool {
        // While collapsing, only the final header can trigger another hover-open.
        let frame = expanded ? panel.frame : model.display.windowFrame(preferences: model.islandPreferences, expanded: false)
        return frame.contains(NSEvent.mouseLocation)
    }

    private func presentationChanged(expanded: Bool) {
        pointerPolicy.transitioned(expanded: expanded, inside: pointerInside(expanded: expanded), now: ProcessInfo.processInfo.systemUptime)
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor); self.outsideClickMonitor = nil }
        if expanded {
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
                self?.dismissForOutsideClick()
            }
        } else if panel.isKeyWindow {
            panel.makeFirstResponder(nil)
            panel.resignKey()
        }
        resizePanel(expanded: expanded)
        schedulePointerCheck()
    }

    private var interactingWithDialogOrMenu: Bool {
        NSApp.modalWindow != nil || panel.attachedSheet != nil || !trackingMenus.isEmpty
    }

    private var editing: Bool {
        guard panel.isKeyWindow else { return false }
        if let textView = panel.firstResponder as? NSTextView { return textView.isEditable }
        return panel.firstResponder is SwiftTerm.TerminalView
    }

    private func reconcilePointer() {
        guard let panel, panel.isVisible else { return }
        let expanded = model.expanded
        let hold = model.pinned || model.showingSetup || model.dropTargeted || interactingWithDialogOrMenu || editing || NSEvent.pressedMouseButtons != 0
        let action = pointerPolicy.evaluate(expanded: expanded, inside: pointerInside(expanded: expanded),
                                            hoverEnabled: model.hoverEnabled && !interactingWithDialogOrMenu && NSEvent.pressedMouseButtons == 0,
                                            holdOpen: hold, now: ProcessInfo.processInfo.systemUptime)
        if let action { model.expanded = action == .open }
        else { schedulePointerCheck() }
    }

    private func schedulePointerCheck() {
        let deadline = pointerPolicy.deadline
        guard scheduledDeadline != deadline else { return }
        pointerTimer?.invalidate()
        pointerTimer = nil
        scheduledDeadline = deadline
        if let deadline {
            let timer = Timer(timeInterval: max(0, deadline - ProcessInfo.processInfo.systemUptime), repeats: false) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.scheduledDeadline = nil
                    self?.reconcilePointer()
                }
            }
            pointerTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func dismissForOutsideClick() {
        guard model.expanded, !model.pinned, !interactingWithDialogOrMenu, !model.dropTargeted,
              !pointerInside(expanded: true) else { return }
        model.expanded = false
    }

    @objc private func menuBegan(_ notification: Notification) {
        if let menu = notification.object as? NSMenu { trackingMenus.insert(ObjectIdentifier(menu)) }
    }

    @objc private func menuEnded(_ notification: Notification) {
        if let menu = notification.object as? NSMenu { trackingMenus.remove(ObjectIdentifier(menu)) }
        reconcilePointer()
    }

    private func setupMenu() {
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            statusItem.button?.image = NotchestPalette.menuImage()
        }
        let menu = NSMenu()
        let open = menu.addItem(withTitle: model.text("فتح Notchest", "Open Notchest"), action: #selector(openIsland), keyEquivalent: "")
        open.target = self
        let settings = menu.addItem(withTitle: model.text("الإعدادات…", "Settings…"), action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: model.text("إنهاء Notchest", "Quit Notchest"), action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        statusItem.menu = menu
    }

    private func setupMainMenu() {
        let main = NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu(title: "Notchest")
        let quitItem = applicationMenu.addItem(withTitle: "Quit Notchest", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        applicationItem.submenu = applicationMenu
        main.addItem(applicationItem)
        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)
        NSApp.mainMenu = main
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openIsland()
        return false
    }

    private func setupHotKey() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context, let event else { return OSStatus(eventNotHandledErr) }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
            var pressed = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &pressed)
            let id = pressed.id
            Task { @MainActor in
                if id == 2 { delegate.openPalette() }
                else { delegate.toggleIsland() }
            }
            return noErr
        }, 1, &eventType, context, &hotKeyHandler)
        let keyID = EventHotKeyID(signature: OSType(0x48414C4F), id: 1)
        let result = RegisterEventHotKey(UInt32(kVK_Space), UInt32(controlKey | optionKey), keyID, GetApplicationEventTarget(), 0, &hotKey)
        let paletteID = EventHotKeyID(signature: OSType(0x48414C4F), id: 2)
        RegisterEventHotKey(UInt32(kVK_ANSI_K), UInt32(controlKey | optionKey), paletteID, GetApplicationEventTarget(), 0, &paletteHotKey)
        if result != noErr {
            model.showToast(model.text("الاختصار مستخدم. افتح Notchest من شريط القوائم.", "Shortcut is in use. Open Notchest from the menu bar."))
        }
    }

    func toggleIsland() {
        model.expanded.toggle()
        if model.expanded { panel.makeKeyAndOrderFront(nil) }
    }

    private func openPalette() {
        model.paletteQuery = ""
        model.paletteVisible = true
        model.expanded = true
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func screenChanged() {
        selectScreenAndResize()
    }

    @objc private func openIsland() { model.expanded = true; panel.makeKeyAndOrderFront(nil) }
    @objc private func openSettings() { model.select(.settings); panel.makeKeyAndOrderFront(nil) }
    @objc private func quit() { NSApp.terminate(nil) }

    func applicationWillTerminate(_ notification: Notification) {
        model.shutdown()
        model.setup.stop()
        model.updates.stop()
        model.project.stop()
        model.developer.stop()
        model.tools.stop()
        model.monitor.stop()
        model.weather.stop()
        model.stocks.stop()
        model.activity.stopAPI()
        TerminalSession.shared.stop()
        frameAnimator.stop()
        pointerTimer?.invalidate()
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let paletteHotKey { UnregisterEventHotKey(paletteHotKey) }
        if let hotKeyHandler { RemoveEventHandler(hotKeyHandler) }
        NotificationCenter.default.removeObserver(self)
    }
}

@main
struct NotchestApplication {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
        withExtendedLifetime(delegate) {}
    }
}
