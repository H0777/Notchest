import AppKit
import Combine

@MainActor
final class SystemMonitor: ObservableObject {
    @Published var watchDownloads: Bool {
        didSet { defaults.set(watchDownloads, forKey: "watchDownloads"); if started { configureDownloads() } }
    }
    @Published var watchVolumes: Bool {
        didSet { defaults.set(watchVolumes, forKey: "watchVolumes"); if started { configureVolumes() } }
    }
    @Published var watchCapsLock: Bool {
        didSet { defaults.set(watchCapsLock, forKey: "watchCapsLock"); if started { configureCapsLock() } }
    }
    @Published var problem: String?
    /// Set from the app's language choice; all monitor wording resolves through it.
    var arabicUI = true
    var onEvent: ((String, String, URL?, String) -> Void)?
    private let defaults: UserDefaults
    private var downloadsSource: DispatchSourceFileSystemObject?
    private var volumeObserver: NSObjectProtocol?
    private var capsObserver: Any?
    private var localCapsObserver: Any?
    private var knownDownloads = Set<String>()
    private var pendingScan: DispatchWorkItem?
    private var capsLock = false
    private var started = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        watchDownloads = defaults.bool(forKey: "watchDownloads")
        watchVolumes = defaults.bool(forKey: "watchVolumes")
        watchCapsLock = defaults.bool(forKey: "watchCapsLock")
    }

    func start() {
        started = true
        configureDownloads(); configureVolumes(); configureCapsLock()
    }

    func stop() {
        started = false
        downloadsSource?.cancel(); downloadsSource = nil
        pendingScan?.cancel(); pendingScan = nil
        if let volumeObserver { NSWorkspace.shared.notificationCenter.removeObserver(volumeObserver) }
        volumeObserver = nil
        if let capsObserver { NSEvent.removeMonitor(capsObserver) }
        if let localCapsObserver { NSEvent.removeMonitor(localCapsObserver) }
        capsObserver = nil; localCapsObserver = nil
    }

    static func isFinishedName(_ name: String) -> Bool {
        let lower = name.lowercased()
        return !lower.hasPrefix(".") && ![".download", ".crdownload", ".part", ".partial", ".tmp"].contains(where: lower.hasSuffix)
    }

    private var downloadsURL: URL? { FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first }

    private func contents() -> Set<String> {
        guard let downloadsURL else { return [] }
        return Set((try? FileManager.default.contentsOfDirectory(atPath: downloadsURL.path)) ?? [])
    }

    private func configureDownloads() {
        downloadsSource?.cancel(); downloadsSource = nil
        pendingScan?.cancel(); pendingScan = nil
        guard watchDownloads, let url = downloadsURL else { return }
        knownDownloads = contents()
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { problem = ServiceText("تعذّرت مراقبة التنزيلات", "Cannot watch Downloads").resolved(arabicUI: arabicUI); return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .rename, .delete], queue: .main)
        source.setEventHandler { [weak self] in
            self?.pendingScan?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.scanDownloads() }
            self?.pendingScan = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
        }
        source.setCancelHandler { close(descriptor) }
        downloadsSource = source
        source.resume()
    }

    private func scanDownloads() {
        guard watchDownloads, let url = downloadsURL else { return }
        let current = contents()
        let added = current.subtracting(knownDownloads).filter(Self.isFinishedName).sorted()
        knownDownloads = current
        for name in added.prefix(10) {
            onEvent?(ServiceText("ملف جديد في التنزيلات", "New file in Downloads").resolved(arabicUI: arabicUI), name, url.appendingPathComponent(name), "download")
        }
    }

    private func configureVolumes() {
        if let volumeObserver { NSWorkspace.shared.notificationCenter.removeObserver(volumeObserver) }
        volumeObserver = nil
        guard watchVolumes else { return }
        volumeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didMountNotification, object: nil, queue: .main) { [weak self] notification in
            guard let url = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL,
                  let values = try? url.resourceValues(forKeys: [.volumeIsRemovableKey, .volumeIsEjectableKey]),
                  values.volumeIsRemovable == true || values.volumeIsEjectable == true else { return }
            Task { @MainActor in self?.onEvent?(ServiceText("قرص متصل", "Drive connected").resolved(arabicUI: self?.arabicUI ?? true), url.lastPathComponent, url, "volume") }
        }
    }

    private func configureCapsLock() {
        if let capsObserver { NSEvent.removeMonitor(capsObserver) }
        if let localCapsObserver { NSEvent.removeMonitor(localCapsObserver) }
        capsObserver = nil; localCapsObserver = nil
        guard watchCapsLock else { return }
        capsLock = NSEvent.modifierFlags.contains(.capsLock)
        capsObserver = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            let enabled = event.modifierFlags.contains(.capsLock)
            Task { @MainActor in self?.capsChanged(enabled) }
        }
        localCapsObserver = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            let enabled = event.modifierFlags.contains(.capsLock)
            Task { @MainActor in self?.capsChanged(enabled) }
            return event
        }
    }

    private func capsChanged(_ enabled: Bool) {
        guard watchCapsLock, enabled != capsLock else { return }
        capsLock = enabled
        onEvent?("Caps Lock", ServiceText(enabled ? "مفعّل" : "متوقف", enabled ? "On" : "Off").resolved(arabicUI: arabicUI), nil, "caps")
    }
}
