import AppKit
import Combine
import CryptoKit

enum DeveloperSection: String, CaseIterable, Identifiable {
    case usage, text, terminal, command, git, activity, snippets
    var id: String { rawValue }
    func title(_ ar: Bool) -> String {
        switch self {
        case .usage: return ar ? "استهلاك AI" : "AI usage"
        case .text: return ar ? "أدوات الكود" : "Code tools"
        case .terminal: return ar ? "الطرفية" : "Terminal"
        case .command: return ar ? "الأوامر" : "Commands"
        case .git: return "Git"
        case .activity: return ar ? "النشاط" : "Activity"
        case .snippets: return ar ? "المقتطفات" : "Snippets"
        }
    }
}

struct Snippet: Codable, Identifiable {
    var id = UUID()
    var name: String
    var text: String
}

struct GitHubPull: Decodable, Identifiable {
    let number: Int
    let title: String
    let url: URL
    let isDraft: Bool
    let headRefName: String
    var id: Int { number }
}

struct PullResult {
    var pulls: [GitHubPull] = []
    var error: String?
}

@MainActor
final class DeveloperModel: ObservableObject {
    var onCommandFinished: ((Int32) -> Void)?
    @Published var section: DeveloperSection = .usage
    @Published var provider: AIProvider = .codex
    @Published var usage = UsageSnapshot()
    @Published var refreshing = false
    @Published var liveCodex: CodexLiveSnapshot?
    @Published var liveCodexLoading = false
    @Published var liveCodexError: String?
    @Published var trackingEnabled = UserDefaults.standard.object(forKey: "aiTracking") as? Bool ?? true {
        didSet { UserDefaults.standard.set(trackingEnabled, forKey: "aiTracking"); if trackingEnabled { refreshUsage() } else { usage = UsageSnapshot() } }
    }
    @Published var workbenchInput = ""
    @Published var workbenchOutput = ""
    @Published var workbenchError = false
    @Published var command = ""
    @Published var commandOutput = ""
    @Published var commandRunning = false
    @Published var commandExit: Int32?
    @Published var workingDirectory = FileManager.default.homeDirectoryForCurrentUser
    @Published var gitOutput = ""
    @Published var gitBusy = false
    @Published var showingPulls = false
    @Published var pulls: [GitHubPull] = []
    @Published var pullError: String?
    @Published var regexPattern = ""
    @Published var snippets: [Snippet] = []
    /// Set from the app's language choice; developer-tool wording resolves through it.
    var arabicUI = true
    private var process: Process?
    private var outputPipe: Pipe?
    private var timer: Timer?
    private var usageTask: Task<Void, Never>?
    private var usageGeneration = UUID()

    init() {
        snippets = UserDefaults.standard.data(forKey: "snippets").flatMap { try? JSONDecoder().decode([Snippet].self, from: $0) } ?? []
    }

    var usageDirectory: URL {
        if let path = UserDefaults.standard.string(forKey: "usageDirectory.\(provider.rawValue)") { return URL(fileURLWithPath: path) }
        return provider.defaultDirectory
    }

    func start() {
        refreshUsage()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshUsage() }
        }
    }

    func stop() {
        timer?.invalidate()
        usageTask?.cancel()
        cancelCommand()
    }

    func refreshUsage() {
        guard trackingEnabled, !refreshing else { return }
        refreshing = true
        let generation = UUID()
        usageGeneration = generation
        let provider = provider
        let directory = usageDirectory
        usageTask = Task { [weak self] in
            let snapshot = await Task.detached(priority: .utility) { UsageReader.scan(provider: provider, directory: directory) }.value
            guard let self else { return }
            guard self.usageGeneration == generation else { return }
            defer { self.refreshing = false }
            guard !Task.isCancelled, self.provider == provider, self.trackingEnabled else { return }
            self.usage = snapshot
        }
    }

    func changeProvider(_ provider: AIProvider) {
        usageTask?.cancel()
        refreshing = false
        self.provider = provider
        usage = UsageSnapshot()
        refreshUsage()
    }

    func refreshLiveCodex() {
        guard !liveCodexLoading else { return }
        liveCodexLoading = true; liveCodexError = nil
        Task { [weak self] in
            let result = await Task.detached(priority: .utility) { Result { try CodexLiveReader.fetch() } }.value
            guard let self else { return }
            self.liveCodexLoading = false
            switch result {
            case .success(let snapshot): self.liveCodex = snapshot
            case .failure(let error): self.liveCodexError = (error as? CodexLiveError)?.message(arabicUI: self.arabicUI) ?? error.localizedDescription
            }
        }
    }

    func chooseUsageFolder() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = usageDirectory
        if panel.runModal() == .OK, let url = panel.url {
            UserDefaults.standard.set(url.path, forKey: "usageDirectory.\(provider.rawValue)")
            refreshUsage()
        }
    }

    func transform(_ operation: String) {
        workbenchError = false
        do { workbenchOutput = try Self.transform(operation, text: workbenchInput, pattern: regexPattern, arabicUI: arabicUI) }
        catch { workbenchError = true; workbenchOutput = error.localizedDescription }
    }

    static func transform(_ operation: String, text: String, pattern: String = "", arabicUI: Bool = true) throws -> String {
        func invalid(_ arabic: String, _ english: String) -> NSError { NSError(domain: "Notchest", code: 1, userInfo: [NSLocalizedDescriptionKey: ServiceText(arabic, english).resolved(arabicUI: arabicUI)]) }
        switch operation {
        case "JSON":
            let object = try JSONSerialization.jsonObject(with: Data(text.utf8), options: [.fragmentsAllowed])
            let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed])
            return String(decoding: data, as: UTF8.self)
        case "Minify":
            let object = try JSONSerialization.jsonObject(with: Data(text.utf8), options: [.fragmentsAllowed])
            return String(decoding: try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .fragmentsAllowed]), as: UTF8.self)
        case "Base64 ↑": return Data(text.utf8).base64EncodedString()
        case "Base64 ↓":
            guard let data = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)), let value = String(data: data, encoding: .utf8) else { throw invalid("ليست بيانات Base64 نصية صالحة", "Invalid Base64") }
            return value
        case "URL ↑": return text.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? text
        case "URL ↓":
            guard let value = text.removingPercentEncoding else { throw invalid("ترميز رابط غير صالح", "Invalid URL encoding") }
            return value
        case "SHA-256": return SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
        case "UUID": return UUID().uuidString.lowercased()
        case "Epoch":
            if let seconds = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: seconds > 10_000_000_000 ? seconds / 1000 : seconds))
            }
            if let date = ISO8601DateFormatter().date(from: text.trimmingCharacters(in: .whitespacesAndNewlines)) { return String(Int(date.timeIntervalSince1970)) }
            throw invalid("أدخل وقت Unix أو تاريخ ISO 8601", "Use Unix seconds, milliseconds, or an ISO 8601 date")
        case "Regex":
            guard !pattern.isEmpty else { throw invalid("أدخل التعبير النمطي", "Enter a regular expression") }
            let expression = try NSRegularExpression(pattern: pattern)
            let matches = expression.matches(in: text, range: NSRange(text.startIndex..., in: text))
            return matches.compactMap { Range($0.range, in: text).map { String(text[$0]) } }.joined(separator: "\n") + "\n\n\(matches.count) matches"
        case "Count": return "Characters: \(text.count)\nWords: \(text.split(whereSeparator: \.isWhitespace).count)\nUTF-8 bytes: \(text.utf8.count)\nLines: \(text.components(separatedBy: .newlines).count)"
        default: return text
        }
    }

    func chooseWorkingDirectory() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = workingDirectory
        if panel.runModal() == .OK, let url = panel.url { workingDirectory = url; gitOutput = ""; pulls = []; pullError = nil }
    }

    func runCommand() {
        guard !commandRunning, !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        commandRunning = true
        commandOutput = ""
        commandExit = nil
        let task = Process()
        let pipe = Pipe()
        let input = Pipe()
        let helper = Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("NotchestCommand")
        if let helper, FileManager.default.isExecutableFile(atPath: helper.path) {
            task.executableURL = helper
            task.arguments = [command]
        } else {
            task.executableURL = URL(fileURLWithPath: "/bin/zsh")
            task.arguments = ["-c", command]
        }
        task.currentDirectoryURL = workingDirectory
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        environment["TERM"] = "dumb"
        environment["NO_COLOR"] = "1"
        task.environment = environment
        task.standardOutput = pipe
        task.standardError = pipe
        task.standardInput = input
        outputPipe = pipe
        process = task
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { handle.readabilityHandler = nil; return }
            let string = String(decoding: data, as: UTF8.self)
            Task { @MainActor in
                guard let self, self.process === task else { return }
                self.commandOutput = String((self.commandOutput + string).suffix(120_000))
            }
        }
        task.terminationHandler = { [weak self] finished in
            Task { @MainActor in
                guard let self, self.process === finished else { return }
                self.commandExit = finished.terminationStatus
                self.commandRunning = false
                self.onCommandFinished?(finished.terminationStatus)
            }
        }
        do { try task.run(); input.fileHandleForWriting.closeFile() }
        catch {
            commandOutput = error.localizedDescription
            commandRunning = false
            pipe.fileHandleForReading.readabilityHandler = nil
            process = nil
        }
    }

    func cancelCommand() {
        if let process, process.isRunning {
            // A command is a noninteractive zsh job. Interrupt its process group where possible.
            let pid = process.processIdentifier
            if getpgid(pid) == pid { kill(-pid, SIGINT) } else { process.interrupt() }
            Task { [weak self, weak process] in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard let self, let process, self.process === process, process.isRunning else { return }
                if getpgid(pid) == pid { kill(-pid, SIGTERM) } else { process.terminate() }
            }
        }
    }

    func refreshGit() {
        guard !gitBusy else { return }
        gitBusy = true
        let directory = workingDirectory
        Task { [weak self] in
            let output = await Task.detached(priority: .utility) {
                [(["status", "--short", "--branch"], "STATUS"), (["diff", "--stat"], "DIFF"), (["log", "-5", "--oneline"], "RECENT COMMITS")].map { args, title in
                    "\(title)\n" + Self.capture(executable: "/usr/bin/git", arguments: ["-C", directory.path] + args)
                }.joined(separator: "\n\n")
            }.value
            self?.gitOutput = output
            self?.gitBusy = false
        }
    }

    func refreshPulls() {
        guard !gitBusy else { return }
        gitBusy = true
        pullError = nil
        let directory = workingDirectory
        let arabicUI = self.arabicUI
        Task { [weak self] in
            let result = await Task.detached(priority: .utility) { Self.fetchPulls(directory: directory, arabicUI: arabicUI) }.value
            self?.pulls = result.pulls
            self?.pullError = result.error
            self?.gitBusy = false
        }
    }

    nonisolated static func fetchPulls(directory: URL, arabicUI: Bool) -> PullResult {
        let paths = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map { String($0) + "/gh" }
            + ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
        guard let executable = paths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return PullResult(error: ServiceText("ثبّت GitHub CLI وسجّل الدخول إليه", "Install GitHub CLI (gh) and sign in").resolved(arabicUI: arabicUI))
        }
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.currentDirectoryURL = directory
        process.arguments = ["pr", "list", "--limit", "30", "--json", "number,title,url,isDraft,headRefName"]
        var environment = ProcessInfo.processInfo.environment
        environment["GH_PROMPT_DISABLED"] = "1"
        environment["GIT_TERMINAL_PROMPT"] = "0"
        process.environment = environment
        process.standardOutput = pipe
        process.standardError = pipe
        let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
        do {
            try process.run()
            DispatchQueue.global().asyncAfter(deadline: .now() + 20, execute: timeout)
            let output = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit(); timeout.cancel()
            guard process.terminationStatus == 0 else { return PullResult(error: String(decoding: output.prefix(3000), as: UTF8.self)) }
            return PullResult(pulls: try parsePulls(output))
        } catch { timeout.cancel(); return PullResult(error: error.localizedDescription) }
    }

    nonisolated static func parsePulls(_ data: Data) throws -> [GitHubPull] {
        try JSONDecoder().decode([GitHubPull].self, from: data).filter { $0.url.scheme?.lowercased() == "https" && $0.url.host != nil }
    }

    nonisolated static func capture(executable: String, arguments: [String]) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return String(decoding: data.prefix(100_000), as: UTF8.self)
        } catch { return error.localizedDescription }
    }

    func addSnippet(arabic: Bool) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = arabic ? "مقتطف جديد" : "New snippet"
        alert.addButton(withTitle: arabic ? "حفظ" : "Save")
        alert.addButton(withTitle: arabic ? "إلغاء" : "Cancel")
        let name = NSTextField(frame: NSRect(x: 0, y: 95, width: 360, height: 24))
        name.placeholderString = arabic ? "اسم المقتطف" : "Snippet name"
        let text = NSTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 85))
        text.placeholderString = arabic ? "النص أو الكود" : "Text or code"
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 120))
        container.addSubview(name); container.addSubview(text)
        alert.accessoryView = container
        alert.window.initialFirstResponder = name
        if alert.runModal() == .alertFirstButtonReturn, !name.stringValue.isEmpty, !text.stringValue.isEmpty {
            snippets.append(Snippet(name: name.stringValue, text: text.stringValue))
            saveSnippets()
        }
    }

    func deleteSnippet(_ snippet: Snippet) { snippets.removeAll { $0.id == snippet.id }; saveSnippets() }
    private func saveSnippets() { if let data = try? JSONEncoder().encode(snippets) { UserDefaults.standard.set(data, forKey: "snippets") } }
}
