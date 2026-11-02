import Foundation
import Combine

struct ProjectRun: Decodable, Identifiable {
    let databaseId: Int
    let name: String
    let displayTitle: String
    let status: String
    let conclusion: String
    let headBranch: String
    let url: URL
    var id: Int { databaseId }
    var activityState: String {
        if status != "completed" { return status == "waiting" || status == "pending" ? "waiting" : "running" }
        if conclusion == "success" { return "success" }
        if ["failure", "timed_out", "action_required", "startup_failure"].contains(conclusion) { return "failure" }
        return "info"
    }
    static func parse(_ data: Data) throws -> [Self] {
        try JSONDecoder().decode([Self].self, from: data).filter {
            $0.url.scheme == "https" && $0.url.host == "github.com" && $0.url.path.contains("/actions/runs/") && $0.url.query == nil
        }
    }
}

extension ProjectRun {
    private enum CodingKeys: String, CodingKey { case databaseId, name, displayTitle, status, conclusion, headBranch, url }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        databaseId = try values.decode(Int.self, forKey: .databaseId)
        name = try values.decode(String.self, forKey: .name)
        displayTitle = try values.decodeIfPresent(String.self, forKey: .displayTitle) ?? name
        status = try values.decode(String.self, forKey: .status)
        conclusion = try values.decodeIfPresent(String.self, forKey: .conclusion) ?? ""
        headBranch = try values.decodeIfPresent(String.self, forKey: .headBranch) ?? ""
        url = try values.decode(URL.self, forKey: .url)
    }
}

@MainActor final class ProjectMonitor: ObservableObject {
    @Published private(set) var directory: URL
    @Published private(set) var runs: [ProjectRun] = []
    @Published private(set) var loading = false
    @Published private(set) var error: ServiceText?
    @Published private(set) var checkedAt: Date?
    @Published var enabled: Bool {
        didSet { defaults.set(enabled, forKey: "watchProjectActions"); if started { schedule() } }
    }
    var onChanged: ((ProjectRun) -> Void)?
    private var previous: [Int: String] = [:]
    private let defaults: UserDefaults
    private var timer: Timer?
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private var started = false
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        directory = defaults.string(forKey: "workingDirectory").map { URL(fileURLWithPath: $0) } ?? FileManager.default.homeDirectoryForCurrentUser
        enabled = defaults.bool(forKey: "watchProjectActions")
    }
    func select(_ directory: URL) {
        guard directory != self.directory else { return }
        cancel(); self.directory = directory; runs = []; previous = [:]; error = nil; checkedAt = nil
        if enabled && started { refresh() }
    }
    func start() { guard !started else { return }; started = true; schedule() }
    private func schedule() {
        timer?.invalidate(); timer = nil
        guard enabled else { cancel(); return }
        refresh()
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in Task { @MainActor in if self?.started == true { self?.refresh() } } }
        timer.tolerance = 5; RunLoop.main.add(timer, forMode: .common); self.timer = timer
    }
    func refresh() {
        guard enabled, !loading else { return }
        loading = true; error = nil
        let directory = directory, generation = UUID(); self.generation = generation
        task = Task { [weak self] in
            let result = await Task.detached(priority: .utility) { Result { () throws -> [ProjectRun] in
                guard let gh = DeveloperModel.githubExecutable() else { throw CocoaError(.executableNotLoadable) }
                let reply = try ToolProcess.read(gh, ["run", "list", "--limit", "8", "--json", "databaseId,name,displayTitle,status,conclusion,headBranch,url"], timeout: 12, directory: directory)
                guard reply.status == 0 else { throw CocoaError(.fileReadNoPermission) }
                return try ProjectRun.parse(reply.data)
            } }.value
            guard let self, !Task.isCancelled, self.generation == generation else { return }
            self.loading = false
            switch result {
            case .success(let runs):
                for run in runs {
                    let state = run.status + ":" + run.conclusion
                    if let prior = self.previous[run.id], prior != state { self.onChanged?(run) }
                    else if self.previous[run.id] == nil && run.status != "completed" { self.onChanged?(run) }
                }
                self.previous = Dictionary(uniqueKeysWithValues: runs.map { ($0.id, $0.status + ":" + $0.conclusion) })
                self.runs = runs; self.checkedAt = Date()
            case .failure:
                self.error = ServiceText("تعذّرت قراءة GitHub Actions. تحقّق من مجلّد المستودع وتسجيل الدخول في gh واتصال الإنترنت.", "Could not read GitHub Actions. Check the repository folder, gh sign-in and internet connection.")
            }
        }
    }
    private func cancel() { generation = UUID(); task?.cancel(); task = nil; loading = false }
    func stop() { started = false; timer?.invalidate(); timer = nil; cancel() }
}
