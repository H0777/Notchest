import Foundation
import Combine
import Darwin

struct SetupCheck: Identifiable {
    let id: String
    let name: String
    let available: Bool
    let detail: ServiceText
}

enum ToolProcess {
    static func executable(_ name: String, environment: [String: String] = ProcessInfo.processInfo.environment, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL? {
        let paths = (environment["PATH"] ?? "").split(separator: ":").map { String($0) + "/" + name }
            + [home.appendingPathComponent(".local/bin/" + name).path, "/opt/homebrew/bin/" + name, "/usr/local/bin/" + name, "/usr/bin/" + name]
        return paths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }).map { URL(fileURLWithPath: $0) }
    }
    static func read(_ executable: URL, _ arguments: [String], timeout: TimeInterval = 10, directory: URL? = nil) throws -> (status: Int32, data: Data) {
        let process = Process(), output = Pipe()
        process.executableURL = executable; process.arguments = arguments
        process.currentDirectoryURL = directory
        process.standardInput = FileHandle.nullDevice; process.standardOutput = output; process.standardError = FileHandle.nullDevice
        var environment = ProcessInfo.processInfo.environment
        environment["GH_PROMPT_DISABLED"] = "1"; environment["GIT_TERMINAL_PROMPT"] = "0"
        process.environment = environment
        try process.run()
        let deadline = DispatchWorkItem {
            if process.isRunning {
                process.terminate()
                DispatchQueue.global().asyncAfter(deadline: .now() + 1) { if process.isRunning { kill(process.processIdentifier, SIGKILL) } }
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: deadline)
        defer { deadline.cancel(); try? output.fileHandleForReading.close() }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, Data(data.prefix(1_000_000)))
    }
}

@MainActor final class SetupModel: ObservableObject {
    @Published private(set) var checks: [SetupCheck] = []
    @Published private(set) var checking = false
    private var task: Task<Void, Never>?
    func refresh(codexDirectory: URL, claudeDirectory: URL) {
        guard !checking else { return }
        checking = true
        task = Task { [weak self] in
            let checks = await Task.detached(priority: .utility) {
                let fm = FileManager.default
                let codex = CodexLiveReader.executable() != nil
                let claude = ToolProcess.executable("claude") != nil
                let gh = DeveloperModel.githubExecutable()
                let signedIn = gh.flatMap { try? ToolProcess.read($0, ["auth", "status"], timeout: 6).status } == 0
                func logDetail(_ url: URL) -> ServiceText {
                    fm.isReadableFile(atPath: url.path) ? ServiceText("مجلّد السجلات متاح؛ تتجدد الأرقام عند كتابة الاستخدام", "Log folder is readable; numbers update when usage is recorded") : ServiceText("اختر مجلّد السجلات أو استخدم الأداة لإنشائه", "Choose the log folder or use the tool to create it")
                }
                return [
                    SetupCheck(id: "codex", name: "Codex", available: codex, detail: codex ? ServiceText("الأداة متاحة؛ فعّل حدود الحساب لاختبار الاتصال", "CLI found; enable account limits to test your connection") : ServiceText("ثبّت Codex CLI أو استخدم نسخته المرفقة مع تطبيق Codex", "Install Codex CLI or use the copy bundled with the Codex app")),
                    SetupCheck(id: "codex-logs", name: "Codex · local logs", available: fm.isReadableFile(atPath: codexDirectory.path), detail: logDetail(codexDirectory)),
                    SetupCheck(id: "claude", name: "Claude Code", available: claude || fm.isReadableFile(atPath: claudeDirectory.path), detail: logDetail(claudeDirectory)),
                    SetupCheck(id: "github", name: "GitHub", available: signedIn, detail: gh == nil ? ServiceText("ثبّت GitHub CLI ثم سجّل الدخول", "Install GitHub CLI, then sign in") : signedIn ? ServiceText("الحساب جاهز لمتابعة مشاريعك", "Account is ready for your projects") : ServiceText("افتح Terminal ونفّذ gh auth login ثم أعد الفحص", "Run gh auth login in Terminal, then check again"))
                ]
            }.value
            guard let self, !Task.isCancelled else { return }
            self.checks = checks; self.checking = false
        }
    }
    func stop() { task?.cancel(); task = nil; checking = false }
}
