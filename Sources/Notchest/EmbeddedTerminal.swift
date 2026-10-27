import AppKit
import SwiftUI
import SwiftTerm

@MainActor
final class TerminalSession: NSObject, ObservableObject, LocalProcessTerminalViewDelegate {
    static let shared = TerminalSession()
    @Published var running = false
    @Published var title = "zsh"
    @Published var exitCode: Int32?
    let terminal: LocalProcessTerminalView

    private override init() {
        terminal = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 600, height: 240))
        super.init()
        terminal.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        terminal.nativeForegroundColor = NSColor(calibratedWhite: 0.88, alpha: 1)
        terminal.nativeBackgroundColor = NSColor(calibratedWhite: 0.045, alpha: 1)
        terminal.processDelegate = self
        terminal.setAccessibilityLabel("Notchest terminal")
    }

    func start(directory: URL) {
        guard !running else { return }
        var environment = ProcessInfo.processInfo.environment
        environment["TERM"] = "xterm-256color"
        environment["COLORTERM"] = "truecolor"
        if environment["PATH"] == nil { environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" }
        let shell = environment["SHELL"].flatMap { FileManager.default.isExecutableFile(atPath: $0) ? $0 : nil } ?? "/bin/zsh"
        exitCode = nil
        terminal.startProcess(executable: shell, args: ["-l"], environment: environment.map { "\($0.key)=\($0.value)" }, currentDirectory: directory.path)
        running = terminal.process.running
        if running { terminal.window?.makeFirstResponder(terminal) }
    }

    func stop() {
        guard running else { return }
        terminal.terminate()
        running = false
    }

    nonisolated func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    nonisolated func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        let safeTitle = String(title.prefix(100))
        Task { @MainActor [weak self] in self?.title = safeTitle }
    }
    nonisolated func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {}
    nonisolated func processTerminated(source: SwiftTerm.TerminalView, exitCode: Int32?) {
        Task { @MainActor [weak self] in
            self?.running = false
            self?.exitCode = exitCode
        }
    }
}

struct TerminalSurface: NSViewRepresentable {
    @ObservedObject var session: TerminalSession
    func makeNSView(context: Context) -> LocalProcessTerminalView {
        session.terminal.removeFromSuperview()
        return session.terminal
    }
    func updateNSView(_ view: LocalProcessTerminalView, context: Context) {}
}

struct EmbeddedTerminalPanel: View {
    @ObservedObject var app: AppModel
    @ObservedObject var developer: DeveloperModel
    @ObservedObject private var session = TerminalSession.shared

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(session.running ? notchestAccent : .white.opacity(0.25)).frame(width: 6, height: 6)
                Text(session.running ? session.title : app.text("طرفية تفاعلية", "Interactive terminal"))
                    .font(.system(size: 11, weight: .medium)).lineLimit(1)
                Text(developer.workingDirectory.lastPathComponent).font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.6))
                Spacer()
                if session.running {
                    Button(app.text("إنهاء الجلسة", "End session")) { session.stop() }
                        .buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
                } else {
                    Button(app.text("بدء الطرفية", "Start terminal")) { session.start(directory: developer.workingDirectory) }
                        .buttonStyle(.plain).font(.system(size: 11, weight: .semibold)).foregroundStyle(notchestAccent)
                }
            }
            ZStack {
                TerminalSurface(session: session)
                if !session.running {
                    VStack(spacing: 8) {
                        Image(systemName: "terminal").font(.system(size: 25, weight: .light)).foregroundStyle(notchestAccent)
                        Text(app.text("جلسة طرفية حقيقية داخل Notchest", "A real terminal inside Notchest"))
                            .font(.system(size: 13, weight: .medium))
                        Text(app.text("تبدأ في مجلّد المشروع، وتبقى مفتوحة عند تبديل التبويب.", "Starts in your project folder and stays open when you switch tabs."))
                            .font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
                        if let code = session.exitCode { Text("Exit \(code)").font(.system(size: 10, design: .monospaced)) }
                    }.allowsHitTesting(false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environment(\.layoutDirection, .leftToRight)
            Text(app.text("تعمل الأوامر بصلاحيات حسابك، كما في Terminal.", "Commands run with your account permissions, like Terminal."))
                .font(.system(size: 9)).foregroundStyle(.white.opacity(0.55))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
