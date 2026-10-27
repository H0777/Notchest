import AppKit
import SwiftUI
import Combine
import Carbon
import QuartzCore
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
    private var closeTask: Task<Void, Never>?
    private var hoverTask: Task<Void, Never>?
    private var eventMonitor: Any?
    private var hotKey: EventHotKeyRef?
    private var paletteHotKey: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?
    private var screen: NSScreen?
    private var hovered = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupPanel()
        setupMainMenu()
        setupMenu()
        setupHotKey()
        model.developer.start()
        model.activity.onRecord = { [weak self] item in self?.model.flashActivity(item) }
        model.monitor.onEvent = { [weak self] title, message, url, kind in
            self?.model.activity.record(title: title, message: message, url: url, kind: kind)
        }
        model.monitor.start()
        model.weather.start()
        model.stocks.onAlert = { [weak self] symbol, details in
            self?.model.activity.record(title: symbol, message: details, state: "info", kind: "stock")
        }
        model.developer.onCommandFinished = { [weak self] code in
            guard let self else { return }
            self.model.showToast(self.model.text("انتهى الأمر • رمز الخروج \(code)", "Command finished • exit \(code)"))
            self.model.developer.section = .command
            self.model.select(.developer)
        }
        model.tools.notify = { [weak self] message in self?.model.showToast(message) }
        model.tools.collapse = { [weak self] in self?.model.expanded = false }
        model.tools.start()
        model.$expanded.removeDuplicates().dropFirst().sink { [weak self] _ in
            DispatchQueue.main.async { self?.resizePanel() }
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
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
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
        model.select(.developer)
        resizePanel(animate: false)
        panel.orderFrontRegardless()
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
        let host = ClearHostingView(rootView: IslandView(model: model, onHover: { [weak self] in self?.handleHover($0) }, activate: { [weak self] in self?.panel.makeKey() }))
        let background = NotchestWindowBackdrop(frame: panel.contentView?.bounds ?? .zero)
        host.wantsLayer = true
        host.layer?.isOpaque = false
        host.layer?.backgroundColor = NSColor.clear.cgColor
        host.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            host.topAnchor.constraint(equalTo: background.topAnchor),
            host.bottomAnchor.constraint(equalTo: background.bottomAnchor)
        ])
        backdrop = background
        panel.contentView = background
    }

    private func resizePanel(animate: Bool = true) {
        guard screen != nil, let panel else { return }
        backdrop?.islandRadius = model.expanded ? 30 : 17
        let frame = model.display.windowFrame(preferences: model.islandPreferences, expanded: model.expanded)
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion || !model.islandPreferences.motionEnabled
        if animate && !reduced {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = model.expanded ? model.islandPreferences.motion.openDuration : model.islandPreferences.motion.closeDuration
                context.timingFunction = model.expanded
                    ? CAMediaTimingFunction(controlPoints: 0.18, 0.80, 0.25, 1.0)
                    : CAMediaTimingFunction(controlPoints: 0.40, 0.0, 0.75, 0.35)
                panel.animator().setFrame(frame, display: true)
            }
        } else { panel.setFrame(frame, display: true) }
        if !model.expanded { panel.resignKey() }
    }

    private func handleHover(_ inside: Bool) {
        hovered = inside
        closeTask?.cancel()
        hoverTask?.cancel()
        if inside {
            if model.hoverEnabled && !model.expanded {
                hoverTask = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 180_000_000)
                    guard !Task.isCancelled, let self, self.hovered else { return }
                    self.model.expanded = true
                }
            }
        } else if !model.pinned {
            closeTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 850_000_000)
                guard !Task.isCancelled, let self, !self.hovered, !self.model.pinned, NSApp.modalWindow == nil else { return }
                // Never collapse while the user is entering a note or a clipboard query.
                if self.panel.isKeyWindow && (self.model.tab == .notes || self.model.tab == .clipboard || self.model.tab == .settings) { return }
                self.model.expanded = false
            }
        }
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
        model.developer.stop()
        model.tools.stop()
        model.monitor.stop()
        model.weather.stop()
        model.stocks.stop()
        model.activity.stopAPI()
        TerminalSession.shared.stop()
        closeTask?.cancel()
        hoverTask?.cancel()
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
