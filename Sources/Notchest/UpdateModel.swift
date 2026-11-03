import Foundation
import Combine

struct ReleaseVersion: Comparable, Equatable {
    let parts: [Int]
    init?(_ text: String) {
        let cleaned = text.hasPrefix("v") ? String(text.dropFirst()) : text
        let pieces = cleaned.split(separator: ".", omittingEmptySubsequences: false)
        guard pieces.count == 3, pieces.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }), pieces.allSatisfy({ Int($0) != nil }) else { return nil }
        parts = pieces.map { Int($0)! }
    }
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.parts.lexicographicallyPrecedes(rhs.parts) }
}

struct AvailableRelease {
    let version: String
    let page: URL
    static func parse(_ data: Data) throws -> Self {
        struct Release: Decodable { let tag_name: String; let html_url: URL; let draft: Bool; let prerelease: Bool }
        let release = try JSONDecoder().decode(Release.self, from: data)
        guard !release.draft, !release.prerelease, ReleaseVersion(release.tag_name) != nil,
              release.html_url.scheme == "https", release.html_url.host == "github.com",
              release.html_url.path == "/H0777/Notchest/releases/tag/\(release.tag_name)", release.html_url.query == nil else { throw URLError(.badServerResponse) }
        return Self(version: release.tag_name.hasPrefix("v") ? String(release.tag_name.dropFirst()) : release.tag_name, page: release.html_url)
    }
}

@MainActor final class UpdateModel: ObservableObject {
    @Published private(set) var checking = false
    @Published private(set) var latest: AvailableRelease?
    @Published private(set) var lastChecked: Date?
    @Published private(set) var error: ServiceText?
    @Published var automaticChecks: Bool {
        didSet { defaults.set(automaticChecks, forKey: "automaticUpdateChecks"); if started { configureTimer() } }
    }
    let currentVersion: String
    private let defaults: UserDefaults
    private var timer: Timer?
    private var task: Task<Void, Never>?
    private var started = false
    private var generation = UUID()
    var updateAvailable: Bool {
        guard let latest, let current = ReleaseVersion(currentVersion), let next = ReleaseVersion(latest.version) else { return false }
        return next > current
    }
    init(defaults: UserDefaults = .standard, currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.6.0") {
        self.defaults = defaults; self.currentVersion = currentVersion
        automaticChecks = defaults.bool(forKey: "automaticUpdateChecks")
    }
    func start() { guard !started else { return }; started = true; configureTimer() }
    private func configureTimer() {
        timer?.invalidate(); timer = nil
        guard automaticChecks else { return }
        check()
        let timer = Timer(timeInterval: 6 * 3600, repeats: true) { [weak self] _ in Task { @MainActor in if self?.started == true { self?.check() } } }
        timer.tolerance = 300; RunLoop.main.add(timer, forMode: .common); self.timer = timer
    }
    func check() {
        guard !checking else { return }
        checking = true; error = nil
        let generation = UUID(); self.generation = generation
        task = Task { [weak self] in
            do {
                let config = URLSessionConfiguration.ephemeral
                config.timeoutIntervalForRequest = 15; config.timeoutIntervalForResource = 20
                let session = URLSession(configuration: config)
                defer { session.invalidateAndCancel() }
                var request = URLRequest(url: URL(string: "https://api.github.com/repos/H0777/Notchest/releases/latest")!)
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.setValue("Notchest", forHTTPHeaderField: "User-Agent")
                let (data, response) = try await session.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200, data.count <= 512_000 else { throw URLError(.badServerResponse) }
                let latest = try AvailableRelease.parse(data)
                guard let self, !Task.isCancelled, self.generation == generation else { return }
                self.latest = latest; self.lastChecked = Date(); self.checking = false
            } catch {
                guard let self, !Task.isCancelled, self.generation == generation else { return }
                self.error = ServiceText.network(error); self.checking = false
            }
        }
    }
    func stop() { started = false; generation = UUID(); task?.cancel(); task = nil; timer?.invalidate(); timer = nil; checking = false }
}
