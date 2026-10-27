import AppKit
import Combine
import CoreAudio
import Vision
import UniformTypeIdentifiers
import ImageIO
import EventKit
@preconcurrency import AVFoundation
import ApplicationServices

struct AudioOutput: Identifiable { let id: AudioDeviceID; let name: String }

@MainActor
final class NativeTools: ObservableObject {
    @Published var section = "system"
    @Published var volume: Double?
    @Published var micMuted: Bool?
    @Published var outputs: [AudioOutput] = []
    @Published var selectedOutput: AudioDeviceID = 0
    @Published var cpuPercent: Double = 0
    @Published var memoryPercent: Double = 0
    @Published var freeDiskGB: Double = 0
    @Published var result = ""
    @Published var busy = false
    @Published var searchQuery = ""
    @Published var calculatorInput = ""
    @Published var calculatorResult = ""
    @Published var calendarLines: [String] = []
    @Published var musicTitle = ""
    @Published var musicArtist = ""
    @Published var musicAlbum = ""
    @Published var musicApp = "Music" { didSet { if oldValue != musicApp { stopMusic() } } }
    @Published var musicArtwork: NSImage?
    @Published var musicDuration: TimeInterval = 0
    @Published var musicPosition: TimeInterval = 0
    @Published var musicPlaying = false
    @Published var musicReadAt = Date()
    @Published var musicConnected = false
    @Published var lyrics: [LyricLine] = []
    @Published var plainLyrics = ""
    @Published var lyricsLoading = false
    @Published var lyricsError: String?
    @Published var showLyrics = false
    @Published var shortcutNames: [String] = []
    @Published var selectedShortcut = ""
    var notify: ((String) -> Void)?
    var collapse: (() -> Void)?
    private var timer: Timer?
    private var musicTimer: Timer?
    private var musicReading = false
    private var musicTask: Task<Void, Never>?
    private var lyricsTask: Task<Void, Never>?
    private var previousTicks: (UInt32, UInt32, UInt32, UInt32)?
    private let eventStore = EKEventStore()
    private var mirror: MirrorController?
    private var lastExternalApp: NSRunningApplication?
    private var workspaceObserver: NSObjectProtocol?

    func start() {
        refreshSystem()
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
            Task { @MainActor in self?.lastExternalApp = app }
        }
        lastExternalApp = NSWorkspace.shared.frontmostApplication
        timer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in Task { @MainActor in self?.refreshSystem() } }
    }

    func stop() {
        timer?.invalidate()
        stopMusic()
        if let workspaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver) }
        mirror?.stop()
    }

    func refreshSystem() {
        selectedOutput = defaultDevice(kAudioHardwarePropertyDefaultOutputDevice)
        volume = readVolume(selectedOutput)
        let input = defaultDevice(kAudioHardwarePropertyDefaultInputDevice)
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        micMuted = AudioObjectGetPropertyData(input, &address, 0, nil, &size, &muted) == noErr ? muted != 0 : nil
        outputs = audioOutputs()
        readCPUAndMemory()
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: FileManager.default.homeDirectoryForCurrentUser.path), let free = attrs[.systemFreeSize] as? NSNumber { freeDiskGB = free.doubleValue / 1_000_000_000 }
    }

    private func defaultDevice(_ selector: AudioObjectPropertySelector) -> AudioDeviceID {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        return device
    }

    private func readVolume(_ device: AudioDeviceID) -> Double? {
        for channel: UInt32 in [0, 1, 2] {
            var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar, mScope: kAudioDevicePropertyScopeOutput, mElement: channel)
            var value: Float32 = 0
            var size = UInt32(MemoryLayout<Float32>.size)
            if AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr { return Double(value) }
        }
        return nil
    }

    func setVolume(_ value: Double) {
        var didSet = false
        for channel: UInt32 in [0, 1, 2] {
            var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar, mScope: kAudioDevicePropertyScopeOutput, mElement: channel)
            var settable = DarwinBoolean(false)
            guard AudioObjectIsPropertySettable(selectedOutput, &address, &settable) == noErr, settable.boolValue else { continue }
            var scalar = Float32(min(1, max(0, value)))
            if AudioObjectSetPropertyData(selectedOutput, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &scalar) == noErr { didSet = true }
        }
        if didSet { volume = value }
    }

    func toggleMic() {
        guard let micMuted else { notify?("Microphone mute unavailable / كتم الميكروفون غير متاح"); return }
        let input = defaultDevice(kAudioHardwarePropertyDefaultInputDevice)
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
        var value: UInt32 = micMuted ? 0 : 1
        if AudioObjectSetPropertyData(input, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value) == noErr { self.micMuted = !micMuted }
        else { notify?("This input does not support mute / جهاز الإدخال لا يدعم الكتم") }
    }

    func changeOutput(_ id: AudioDeviceID) {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var value = id
        if AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &value) == noErr { refreshSystem() }
        else { notify?("Could not switch output / تعذّر تبديل مخرج الصوت") }
    }

    private func audioOutputs() -> [AudioOutput] {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var devices = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        let status = devices.withUnsafeMutableBytes { AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, $0.baseAddress!) }
        guard status == noErr else { return [] }
        return devices.compactMap { device in
            var streams = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
            var streamSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(device, &streams, 0, nil, &streamSize) == noErr, streamSize > 0 else { return nil }
            var nameAddress = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            var name: Unmanaged<CFString>?
            var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            let nameStatus = withUnsafeMutablePointer(to: &name) { pointer in
                AudioObjectGetPropertyData(device, &nameAddress, 0, nil, &nameSize, UnsafeMutableRawPointer(pointer))
            }
            guard nameStatus == noErr, let name else { return nil }
            return AudioOutput(id: device, name: name.takeRetainedValue() as String)
        }
    }

    private func readCPUAndMemory() {
        var cpu = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &cpu) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count) }
        }
        if status == KERN_SUCCESS {
            let ticks = cpu.cpu_ticks
            if let previous = previousTicks {
                let user = Double(ticks.0 &- previous.0)
                let system = Double(ticks.1 &- previous.1)
                let idle = Double(ticks.2 &- previous.2)
                let nice = Double(ticks.3 &- previous.3)
                let total = user + system + idle + nice
                if total > 0 { cpuPercent = (user + system + nice) / total * 100 }
            }
            previousTicks = ticks
        }
        var vm = vm_statistics64_data_t()
        var vmCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let memoryStatus = withUnsafeMutablePointer(to: &vm) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(vmCount)) { host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &vmCount) }
        }
        if memoryStatus == KERN_SUCCESS {
            let pages = Double(vm.active_count) + Double(vm.wire_count) + Double(vm.compressor_page_count)
            memoryPercent = min(100, pages * Double(vm_kernel_page_size) / Double(ProcessInfo.processInfo.physicalMemory) * 100)
        }
    }

    func sampleColor() {
        collapse?()
        NSColorSampler().show { [weak self] color in
            guard let rgb = color?.usingColorSpace(.sRGB) else { return }
            let hex = String(format: "#%02X%02X%02X", Int(round(rgb.redComponent * 255)), Int(round(rgb.greenComponent * 255)), Int(round(rgb.blueComponent * 255)))
            Task { @MainActor in self?.copyResult(hex) }
        }
    }

    func copyResult(_ text: String) {
        result = text
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        notify?("Copied / تم النسخ")
    }

    func recognizeClipboardImage() {
        guard let image = NSImage(pasteboard: .general), let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            notify?("Copy an image first / انسخ صورة أولًا"); return
        }
        busy = true
        Task { [weak self] in
            let output: String = await Task.detached(priority: .userInitiated) {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.automaticallyDetectsLanguage = true
                do {
                    try VNImageRequestHandler(cgImage: cg).perform([request])
                    return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                } catch { return "OCR: \(error.localizedDescription)" }
            }.value
            self?.busy = false
            if output.isEmpty { self?.notify?("No text detected / لم يُعثر على نص") }
            else { self?.copyResult(output) }
        }
    }

    func screenshot(addToShelf: @escaping (URL) -> Void) {
        collapse?()
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Notchest/Captures")
        do { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
        catch { notify?(error.localizedDescription); return }
        let url = folder.appendingPathComponent("Capture-\(UUID().uuidString.prefix(8)).png")
        Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            let success = await Task.detached {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                task.arguments = ["-i", url.path]
                do { try task.run(); task.waitUntilExit(); return task.terminationStatus == 0 && FileManager.default.fileExists(atPath: url.path) }
                catch { return false }
            }.value
            if success { addToShelf(url) }
        }
    }

    func convertImage(to type: UTType, addToShelf: @escaping (URL) -> Void) {
        NSApp.activate(ignoringOtherApps: true)
        let open = NSOpenPanel()
        open.allowedContentTypes = [.image]
        guard open.runModal() == .OK, let sourceURL = open.url else { return }
        let save = NSSavePanel()
        save.allowedContentTypes = [type]
        save.nameFieldStringValue = sourceURL.deletingPathExtension().lastPathComponent + "." + (type.preferredFilenameExtension ?? "png")
        guard save.runModal() == .OK, let destinationURL = save.url else { return }
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, type.identifier as CFString, 1, nil) else { notify?("Unsupported image / الصورة غير مدعومة"); return }
        CGImageDestinationAddImage(destination, image, nil)
        if CGImageDestinationFinalize(destination) { addToShelf(destinationURL); notify?("Image converted / تم تحويل الصورة") }
        else { notify?("Conversion failed / تعذّر التحويل") }
    }

    func archive(unzip: Bool, addToShelf: @escaping (URL) -> Void) {
        NSApp.activate(ignoringOtherApps: true)
        let open = NSOpenPanel()
        open.canChooseDirectories = !unzip
        if unzip { open.allowedContentTypes = [.zip] }
        guard open.runModal() == .OK, let source = open.url else { return }
        let destination: URL
        if unzip {
            let folder = NSOpenPanel()
            folder.canChooseFiles = false; folder.canChooseDirectories = true; folder.canCreateDirectories = true
            guard folder.runModal() == .OK, let parent = folder.url else { return }
            destination = parent.appendingPathComponent(source.deletingPathExtension().lastPathComponent + "-" + UUID().uuidString.prefix(6))
        } else {
            let save = NSSavePanel()
            save.allowedContentTypes = [.zip]
            save.nameFieldStringValue = source.lastPathComponent + ".zip"
            guard save.runModal() == .OK, let url = save.url else { return }
            destination = url
        }
        busy = true
        Task { [weak self] in
            let success = await Task.detached {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                process.arguments = unzip ? ["-x", "-k", source.path, destination.path] : ["-c", "-k", "--sequesterRsrc", "--keepParent", source.path, destination.path]
                do { try process.run(); process.waitUntilExit(); return process.terminationStatus == 0 } catch { return false }
            }.value
            self?.busy = false
            if success { addToShelf(destination); self?.notify?("Done / تم") }
            else { self?.notify?("Archive operation failed / تعذّرت العملية") }
        }
    }

    func tileWindow(_ side: String) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else { notify?("Allow Accessibility in System Settings / فعّل تسهيلات الاستخدام من إعدادات النظام"); return }
        let current = NSWorkspace.shared.frontmostApplication
        let target = current?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? lastExternalApp : current
        guard let target, target.processIdentifier != ProcessInfo.processInfo.processIdentifier else { notify?("Select an app window first / اختر نافذة تطبيق أولًا"); return }
        let app = AXUIElementCreateApplication(target.processIdentifier)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &focused) == .success, let focused else { notify?("No resizable window / لا توجد نافذة قابلة للتنظيم"); return }
        let window = unsafeBitCast(focused, to: AXUIElement.self)
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let visible = screen.visibleFrame
        let height = NSScreen.screens.map { $0.frame.maxY }.max() ?? screen.frame.maxY
        var size = CGSize(width: side == "full" ? visible.width : visible.width / 2, height: visible.height)
        var point = CGPoint(x: side == "right" ? visible.midX : visible.minX, y: height - visible.maxY)
        guard let position = AXValueCreate(.cgPoint, &point), let dimensions = AXValueCreate(.cgSize, &size) else { return }
        let moved = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, position)
        let resized = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, dimensions)
        if moved != .success || resized != .success { notify?("This window did not accept tiling / النافذة لم تقبل التنظيم") }
    }

    func loadCalendar() {
        requestEventAccess(reminders: false) { [weak self] allowed in
            guard let self else { return }
            guard allowed else { self.notify?("Calendar access not granted / لم تُمنح صلاحية التقويم"); return }
            let start = Date()
            let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
            let events = self.eventStore.events(matching: self.eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)).sorted { $0.startDate < $1.startDate }.prefix(8)
            let formatter = DateFormatter(); formatter.timeStyle = .short
            self.calendarLines = events.map { "\(formatter.string(from: $0.startDate)) · \($0.title ?? "Event")" }
            if events.isEmpty { self.notify?("No events in the next 24 hours / لا توجد أحداث في الساعات الـ24 المقبلة") }
        }
    }

    func addReminder(arabic: Bool) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = arabic ? "تذكير جديد" : "New reminder"
        alert.addButton(withTitle: arabic ? "إضافة" : "Add"); alert.addButton(withTitle: arabic ? "إلغاء" : "Cancel")
        let title = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 25))
        alert.accessoryView = title; alert.window.initialFirstResponder = title
        guard alert.runModal() == .alertFirstButtonReturn, !title.stringValue.isEmpty else { return }
        let value = title.stringValue
        requestEventAccess(reminders: true) { [weak self] allowed in
            guard let self else { return }
            guard allowed, let calendar = self.eventStore.defaultCalendarForNewReminders() else { self.notify?("Reminders access not granted / لم تُمنح صلاحية التذكيرات"); return }
            let reminder = EKReminder(eventStore: self.eventStore)
            reminder.title = value; reminder.calendar = calendar
            do { try self.eventStore.save(reminder, commit: true); self.notify?("Reminder added / أُضيف التذكير") }
            catch { self.notify?(error.localizedDescription) }
        }
    }

    private func requestEventAccess(reminders: Bool, completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        let callback: @Sendable (Bool, Error?) -> Void = { allowed, _ in Task { @MainActor in completion(allowed) } }
        if #available(macOS 14, *) {
            if reminders { eventStore.requestFullAccessToReminders(completion: callback) }
            else { eventStore.requestFullAccessToEvents(completion: callback) }
        } else { eventStore.requestAccess(to: reminders ? .reminder : .event, completion: callback) }
    }

    func refreshMusic() { pollMusic(manual: true) }

    private func pollMusic(manual: Bool) {
        guard !musicReading else { return }
        musicReading = true
        let player = musicApp
        musicTask = Task { [weak self] in
            let result = await Task.detached(priority: .utility) { MusicService.read(player) }.value
            guard let self else { return }
            guard !Task.isCancelled, self.musicApp == player else { return }
            self.musicReading = false
            guard let metadata = result.0 else {
                if manual { self.notify?(result.1 ?? "Open your music app and play a track / افتح تطبيق الموسيقى وشغّل مقطعًا") }
                if self.musicConnected { self.stopMusic() }
                return
            }
            let changed = self.musicTitle != metadata.title || self.musicArtist != metadata.artist || self.musicAlbum != metadata.album
            self.musicTitle = metadata.title; self.musicArtist = metadata.artist; self.musicAlbum = metadata.album
            self.musicDuration = metadata.duration; self.musicPosition = metadata.position; self.musicPlaying = metadata.playing; self.musicReadAt = Date()
            self.musicConnected = true
            if changed {
                self.lyricsTask?.cancel(); self.lyricsLoading = false; self.lyricsError = nil
                self.musicArtwork = nil; self.lyrics = []; self.plainLyrics = ""; self.showLyrics = false
                self.loadArtwork(player: player, expectedTitle: metadata.title, expectedArtist: metadata.artist)
            }
            if self.musicTimer == nil {
                self.musicTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in Task { @MainActor in self?.pollMusic(manual: false) } }
            }
        }
    }

    private func loadArtwork(player: String, expectedTitle: String, expectedArtist: String) {
        Task { [weak self] in
            let data: Data?
            if player == "Music" { data = await Task.detached(priority: .utility) { MusicService.appleArtwork() }.value }
            else if let url = await Task.detached(priority: .utility, operation: { MusicService.spotifyArtworkURL() }).value {
                data = (try? await URLSession.shared.data(from: url).0).flatMap { $0.count <= 3_000_000 ? $0 : nil }
            } else { data = nil }
            guard let self, self.musicApp == player, self.musicTitle == expectedTitle, self.musicArtist == expectedArtist, let data else { return }
            self.musicArtwork = NSImage(data: data)
        }
    }

    func loadLyrics() {
        guard !musicTitle.isEmpty, !musicArtist.isEmpty else { notify?("Connect music first / اربط الموسيقى أولًا"); return }
        lyricsTask?.cancel(); lyricsLoading = true; lyricsError = nil; showLyrics = true
        let title = musicTitle, artist = musicArtist
        lyricsTask = Task { [weak self] in
            do {
                let record = try await LyricsService.search(track: title, artist: artist)
                guard !Task.isCancelled, let self, self.musicTitle == title, self.musicArtist == artist else { return }
                self.lyrics = LyricsParser.parse(record?.syncedLyrics ?? "")
                self.plainLyrics = record?.plainLyrics ?? ""
                self.lyricsLoading = false
                if self.lyrics.isEmpty && self.plainLyrics.isEmpty { self.lyricsError = "Lyrics not found / لم تُعثر على كلمات مطابقة" }
            } catch {
                guard !Task.isCancelled else { return }
                self?.lyricsLoading = false; self?.lyricsError = error.localizedDescription
            }
        }
    }

    func stopMusic() {
        musicTimer?.invalidate(); musicTimer = nil
        musicTask?.cancel(); musicTask = nil; musicReading = false
        lyricsTask?.cancel(); lyricsTask = nil
        musicConnected = false; musicArtwork = nil; musicTitle = ""; musicArtist = ""; musicAlbum = ""
        musicPosition = 0; musicDuration = 0; musicPlaying = false; lyrics = []; plainLyrics = ""; showLyrics = false; lyricsLoading = false
    }

    func displayedMusicPosition(at date: Date) -> TimeInterval {
        let elapsed = musicPlaying ? max(0, date.timeIntervalSince(musicReadAt)) : 0
        return min(musicDuration > 0 ? musicDuration : .greatestFiniteMagnitude, musicPosition + elapsed)
    }

    func controlMusic(_ action: String) {
        guard ["playpause", "next track", "previous track"].contains(action) else { return }
        let player = musicApp == "Spotify" ? "Spotify" : "Music"
        var error: NSDictionary?
        NSAppleScript(source: "tell application \"\(player)\" to \(action)")?.executeAndReturnError(&error)
        if let error { notify?(error[NSAppleScript.errorMessage] as? String ?? "Automation unavailable") }
        else { refreshMusic() }
    }

    func showMirror() {
        if mirror == nil { mirror = MirrorController() }
        mirror?.show()
    }

    func loadShortcuts() {
        busy = true
        Task { [weak self] in
            let output = await Task.detached { DeveloperModel.capture(executable: "/usr/bin/shortcuts", arguments: ["list"]) }.value
            self?.shortcutNames = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
            self?.selectedShortcut = self?.shortcutNames.first ?? ""
            self?.busy = false
        }
    }

    func runShortcut() {
        guard !selectedShortcut.isEmpty else { return }
        busy = true
        let name = selectedShortcut
        Task { [weak self] in
            let output = await Task.detached { DeveloperModel.capture(executable: "/usr/bin/shortcuts", arguments: ["run", name]) }.value
            self?.result = output.isEmpty ? "Shortcut finished / اكتمل الاختصار" : output
            self?.busy = false
        }
    }

    func webSearch(translate: Bool = false) {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var components = URLComponents(string: translate ? "https://translate.google.com/" : "https://www.google.com/search")!
        components.queryItems = translate ? [URLQueryItem(name: "sl", value: "auto"), URLQueryItem(name: "tl", value: "ar"), URLQueryItem(name: "text", value: searchQuery), URLQueryItem(name: "op", value: "translate")] : [URLQueryItem(name: "q", value: searchQuery)]
        if let url = components.url { NSWorkspace.shared.open(url) }
    }

    func calculate() {
        do { calculatorResult = try Arithmetic.evaluate(calculatorInput).formatted(.number.precision(.fractionLength(0...8))) }
        catch { calculatorResult = "Invalid expression / صيغة غير صالحة" }
    }
}

enum Arithmetic {
    static func evaluate(_ input: String) throws -> Double {
        struct Parser {
            var chars: [Character]
            var index = 0
            enum Failure: Error { case invalid }
            mutating func expression() throws -> Double {
                var value = try product()
                while index < chars.count, chars[index] == "+" || chars[index] == "-" {
                    let op = chars[index]; index += 1
                    let rhs = try product(); value = op == "+" ? value + rhs : value - rhs
                }
                return value
            }
            mutating func product() throws -> Double {
                var value = try atom()
                while index < chars.count, ["*", "/", "%"].contains(chars[index]) {
                    let op = chars[index]; index += 1
                    let rhs = try atom()
                    if op == "*" { value *= rhs }
                    else if op == "/" { guard rhs != 0 else { throw Failure.invalid }; value /= rhs }
                    else { guard rhs != 0 else { throw Failure.invalid }; value = value.truncatingRemainder(dividingBy: rhs) }
                }
                return value
            }
            mutating func atom() throws -> Double {
                guard index < chars.count else { throw Failure.invalid }
                if chars[index] == "-" { index += 1; return try -atom() }
                if chars[index] == "+" { index += 1; return try atom() }
                if chars[index] == "(" {
                    index += 1; let value = try expression()
                    guard index < chars.count, chars[index] == ")" else { throw Failure.invalid }
                    index += 1; return value
                }
                let start = index
                while index < chars.count, chars[index].isNumber || chars[index] == "." { index += 1 }
                guard start != index, let value = Double(String(chars[start..<index])), value.isFinite else { throw Failure.invalid }
                return value
            }
        }
        guard input.count <= 512 else { throw Parser.Failure.invalid }
        var parser = Parser(chars: input.filter { !$0.isWhitespace }.map { $0 == "×" ? "*" : $0 == "÷" ? "/" : $0 })
        let value = try parser.expression()
        guard parser.index == parser.chars.count, value.isFinite else { throw Parser.Failure.invalid }
        return value
    }
}

@MainActor
private final class MirrorController: NSObject, NSWindowDelegate {
    private let captureQueue = DispatchQueue(label: "dev.notchest.camera", qos: .userInitiated)
    private var window: NSWindow?
    private var session: AVCaptureSession?
    func show() {
        if let window { window.makeKeyAndOrderFront(nil); return }
        AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in
            Task { @MainActor in
                guard allowed, let self, let device = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: device) else { return }
                let session = AVCaptureSession()
                session.sessionPreset = .high
                guard session.canAddInput(input) else { return }
                session.addInput(input)
                let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 400), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
                window.title = "Notchest · Camera mirror"
                window.isReleasedWhenClosed = false; window.delegate = self
                let view = NSView(frame: window.contentLayoutRect)
                view.wantsLayer = true
                let preview = AVCaptureVideoPreviewLayer(session: session)
                preview.videoGravity = .resizeAspectFill
                preview.frame = view.bounds; preview.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
                view.layer?.addSublayer(preview)
                window.contentView = view
                self.window = window; self.session = session
                window.center(); window.makeKeyAndOrderFront(nil)
                self.captureQueue.async { session.startRunning() }
            }
        }
    }
    func windowWillClose(_ notification: Notification) { stop() }
    func stop() {
        if let session { captureQueue.async { session.stopRunning() } }
        session = nil; window = nil
    }
}
