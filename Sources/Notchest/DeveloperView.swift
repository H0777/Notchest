import SwiftUI

struct DeveloperView: View {
    @ObservedObject var app: AppModel
    @ObservedObject var dev: DeveloperModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(app: AppModel) { self.app = app; self.dev = app.developer }

    var body: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 6) {
                ForEach(DeveloperSection.allCases) { section in
                    Button { dev.section = section } label: {
                        Text(section.title(app.arabic)).font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 13).padding(.vertical, 7)
                            .foregroundStyle(dev.section == section ? .white : .white.opacity(0.65))
                            .background { if dev.section == section { Capsule().fill(.clear).notchestGlass(selected: true, radius: 20) } }
                    }.buttonStyle(.plain)
                }
            } }
            Group {
                switch dev.section {
                case .usage: usage
                case .text: workbench
                case .terminal: EmbeddedTerminalPanel(app: app, developer: dev)
                case .command: commands
                case .git: git
                case .activity: ActivityView(app: app, activity: app.activity)
                case .snippets: snippets
                }
            }
            .id(dev.section)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .transition(reduceMotion || !app.islandPreferences.motionEnabled ? .identity : .opacity.combined(with: .offset(y: 5)))
            .animation(reduceMotion || !app.islandPreferences.motionEnabled ? nil : .easeInOut(duration: app.islandPreferences.motion.navigationDuration), value: dev.section)
        }
    }

    private var usage: some View {
        ScrollView {
            VStack(spacing: 9) {
                HStack(spacing: 8) {
                    ForEach(AIProvider.allCases) { provider in
                        Button { dev.changeProvider(provider) } label: {
                            HStack(spacing: 6) {
                                Circle().fill(dev.provider == provider ? notchestAccent : .white.opacity(0.2)).frame(width: 5, height: 5)
                                Text(provider.rawValue).font(.system(size: 12, weight: .semibold))
                            }.padding(.horizontal, 12).padding(.vertical, 8)
                                .background(dev.provider == provider ? .white.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 9))
                        }.buttonStyle(.plain)
                    }
                    Spacer()
                    if dev.refreshing { ProgressView().controlSize(.mini) }
                    if dev.provider == .codex {
                        Button(dev.liveCodexLoading ? app.text("جارٍ الاتصال…", "Connecting…") : app.text("حدود الحساب الحيّة", "Live account limits")) { dev.refreshLiveCodex() }
                            .buttonStyle(.plain).font(.system(size: 9)).foregroundStyle(notchestAccent).disabled(dev.liveCodexLoading)
                    }
                    Toggle(app.text("قراءة الإحصاءات المحلية", "Read local usage"), isOn: $dev.trackingEnabled).labelsHidden().toggleStyle(.switch).controlSize(.mini).tint(notchestAccent)
                    smallButton("arrow.clockwise", app.text("تحديث", "Refresh")) { dev.refreshUsage() }
                    smallButton("folder", app.text("مجلّد السجلّات", "Logs folder")) { dev.chooseUsageFolder() }
                }
                if dev.provider == .codex, dev.liveCodex != nil || dev.liveCodexError != nil {
                    liveLimits
                }
                if !dev.trackingEnabled {
                    VStack(spacing: 12) {
                        Text(app.text("قراءة الإحصاءات متوقّفة", "Usage tracking is paused"))
                        Button(app.text("تفعيل القراءة المحلية", "Enable local tracking")) { dev.trackingEnabled = true }.buttonStyle(.borderedProminent).tint(notchestAccent).foregroundStyle(.black)
                    }.padding(25)
                } else if dev.usage.missingDirectory || (dev.usage.fileCount == 0 && !dev.refreshing) {
                    VStack(spacing: 10) {
                        Image(systemName: "chart.bar.xaxis").font(.system(size: 27, weight: .light)).foregroundStyle(notchestAccent)
                        Text(app.text("لم نعثر على سجلّات \(dev.provider.rawValue)", "No \(dev.provider.rawValue) logs found" )).font(.system(size: 15, weight: .semibold))
                        Text(app.text("استخدم الأداة محليًا، أو اختر مجلّد سجلّاتها من الزر أعلاه.", "Use the tool locally, or select its log folder above."))
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
                    }.frame(maxWidth: .infinity).padding(.vertical, 32)
                } else {
                    HStack(spacing: 9) {
                        metric(app.text("رموز اليوم", "TOKENS TODAY"), value: short(dev.usage.today.total), detail: app.text("دخل + خرج، متضمّنًا الكاش", "Input + output, cache included"))
                        metric(app.text("آخر 7 أيام", "LAST 7 DAYS"), value: short(dev.usage.week.total), detail: app.text("من السجلّات المقروءة", "From scanned local logs"))
                        metric(app.text("إعادة استخدام الكاش اليوم", "INPUT CACHE TODAY"), value: dev.usage.today.input > 0 ? "\(Int(Double(dev.usage.today.cached) / Double(dev.usage.today.input) * 100))%" : "—", detail: app.text("\(short(dev.usage.today.output)) رموز خرج", "\(short(dev.usage.today.output)) output tokens"))
                    }
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 11) {
                            if let primary = dev.usage.primary { window(primary) }
                            if let secondary = dev.usage.secondary { window(secondary) }
                            if dev.usage.primary == nil && dev.usage.secondary == nil {
                                Text(app.text("حدود الحساب غير متاحة في هذه السجلّات", "Account limits are unavailable in these logs"))
                                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.6)).padding(.vertical, 18)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(app.text("النشاط الأسبوعي", "WEEKLY ACTIVITY")).font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                            HStack(alignment: .bottom, spacing: 10) {
                                ForEach(Array(dev.usage.daily.enumerated()), id: \.offset) { _, item in
                                    VStack(spacing: 4) {
                                        RoundedRectangle(cornerRadius: 3).fill(notchestAccent.opacity(Calendar.current.isDateInToday(item.date) ? 0.9 : 0.25))
                                            .frame(width: 17, height: max(3, 40 * Double(item.tokens) / Double(max(1, dev.usage.daily.map(\.tokens).max() ?? 1))))
                                        Text(item.date, format: .dateTime.weekday(.narrow)).font(.system(size: 8)).foregroundStyle(.white.opacity(0.55))
                                    }.help("\(item.tokens.formatted()) tokens")
                                }
                            }.frame(height: 56, alignment: .bottom).environment(\.locale, Locale(identifier: app.arabic ? "ar" : "en"))
                        }.frame(width: 195)
                    }.padding(11).notchestPanel(cornerRadius: 13)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(app.text("\(dev.usage.fileCount) سجلّات • تحديث كل 30 ثانية", "\(dev.usage.fileCount) logs • refreshes every 30 seconds"))
                            Spacer()
                            if let observed = dev.usage.observedAt {
                                Text(app.text("لقطة الحدود: ", "Limits snapshot: ")) + Text(observed, style: .relative)
                            }
                        }
                        Text(app.text("الرموز المحلية ليست فاتورة أو رصيد اشتراك. لا نستخرج نصوص المحادثات أو مفاتيح الدخول.", "Local tokens are not a bill or subscription balance. Conversation text and credentials are not extracted."))
                        if dev.usage.partial || dev.usage.unreadableFiles > 0 {
                            Text(app.text("القراءة جزئية؛ بعض السجلّات كبيرة أو غير قابلة للقراءة.", "Partial scan: some logs were too large or unreadable.")).foregroundStyle(.orange)
                        }
                    }.font(.system(size: 9)).foregroundStyle(.white.opacity(0.55)).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// Live account limits come from the Codex CLI connection and must stay
    /// visible whether or not local log reading is enabled or logs exist.
    private var liveLimits: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(app.text("حدود الحساب الحيّة", "Live account limits")).font(.system(size: 10, weight: .semibold)).foregroundStyle(notchestAccent)
                Spacer()
                if let live = dev.liveCodex {
                    (Text(app.text("حدود حيّة ", "Live ")) + Text(live.fetchedAt, style: .relative)).font(.system(size: 9)).foregroundStyle(.white.opacity(0.55))
                }
            }
            if let error = dev.liveCodexError { Text(error).font(.system(size: 10)).foregroundStyle(.orange) }
            if let live = dev.liveCodex {
                VStack(alignment: .leading, spacing: 11) {
                    if let primary = live.primary { window(primary) }
                    if let secondary = live.secondary { window(secondary) }
                    if let lifetime = live.lifetimeTokens {
                        Text(app.text("إجمالي رموز الحساب المسجّل: \(short(lifetime))", "Account lifetime tokens: \(short(lifetime))"))
                            .font(.system(size: 9)).foregroundStyle(.white.opacity(0.55))
                    }
                }
            }
        }.padding(11).notchestPanel(cornerRadius: 13)
    }

    private func metric(_ title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.6))
            Text(value).font(.system(size: 23, weight: .light, design: .rounded)).foregroundStyle(notchestAccent)
                .environment(\.layoutDirection, .leftToRight)
            Text(detail).font(.system(size: 8)).foregroundStyle(.white.opacity(0.3)).lineLimit(1)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(11).notchestPanel(cornerRadius: 13)
    }

    private func window(_ window: UsageWindow) -> some View {
        let remaining = max(0, 100 - window.usedPercent)
        let expired = window.resetsAt.map { $0 < Date() } ?? false
        return VStack(spacing: 6) {
            HStack {
                Text(window.minutes >= 1440 ? app.text("نافذة \(window.minutes / 1440) أيام", "\(window.minutes / 1440)-day window") : app.text("نافذة \(window.minutes / 60) ساعات", "\(window.minutes / 60)-hour window"))
                Spacer()
                Text(expired ? app.text("لقطة قديمة", "Stale snapshot") : app.text("\(Int(remaining))% متبقٍ", "\(Int(remaining))% remaining")).foregroundStyle(expired ? .orange : notchestAccent)
            }.font(.system(size: 10))
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.06))
                    Capsule().fill(remaining < 15 ? .orange : notchestAccent.opacity(0.7)).frame(width: proxy.size.width * remaining / 100)
                }
            }.frame(height: 4).environment(\.layoutDirection, .leftToRight)
            if let reset = window.resetsAt {
                HStack {
                    Text(app.text("موعد التجديد المسجّل", "Recorded reset"))
                    Spacer()
                    Text(reset, format: .dateTime.month(.abbreviated).day().hour().minute())
                }.font(.system(size: 8)).foregroundStyle(.white.opacity(0.3))
            }
        }
    }

    private var workbench: some View {
        VStack(spacing: 9) {
            HStack(spacing: 5) {
                ForEach(["JSON", "Minify", "Base64 ↑", "Base64 ↓", "URL ↑", "URL ↓", "SHA-256", "UUID", "Epoch", "Count"], id: \.self) { action in
                    Button(action) { dev.transform(action) }.buttonStyle(.plain).font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 7).padding(.vertical, 7).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
                }
            }.environment(\.layoutDirection, .leftToRight)
            HStack(spacing: 10) {
                codeEditor(text: $dev.workbenchInput, label: app.text("النص / الكود", "Input / code"))
                codeEditor(text: $dev.workbenchOutput, label: app.text("النتيجة", "Result"), error: dev.workbenchError)
            }
            HStack(spacing: 9) {
                TextField(app.text("تعبير Regex اختياري", "Optional Regex pattern"), text: $dev.regexPattern).textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced)).padding(8).notchestPanel(cornerRadius: 8)
                Button("Regex") { dev.transform("Regex") }.buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(notchestAccent)
                smallButton("arrow.left.arrow.right", app.text("استخدام النتيجة", "Use result")) { dev.workbenchInput = dev.workbenchOutput }
                smallButton("doc.on.doc", app.text("نسخ النتيجة", "Copy result")) { app.copy(Clip(text: dev.workbenchOutput, source: "Notchest")) }
            }.environment(\.layoutDirection, .leftToRight)
        }
    }

    private var commands: some View {
        VStack(spacing: 10) {
            directoryRow
            HStack(spacing: 10) {
                Text("$").foregroundStyle(notchestAccent)
                TextField(app.text("أمر zsh…", "A zsh command…"), text: $dev.command).textFieldStyle(.plain).font(.system(size: 12, design: .monospaced))
                    .onSubmit { dev.runCommand() }
                Button(dev.commandRunning ? app.text("إيقاف", "Stop") : app.text("تشغيل", "Run")) { if dev.commandRunning { dev.cancelCommand() } else { dev.runCommand() } }
                    .buttonStyle(.plain).font(.system(size: 11, weight: .semibold)).foregroundStyle(notchestAccent)
            }.padding(11).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10)).environment(\.layoutDirection, .leftToRight)
            ScrollView {
                Text(dev.commandOutput.isEmpty ? app.text("يظهر خرج الأمر هنا. الأوامر تُنفّذ بصلاحيات حسابك عند الضغط على تشغيل.", "Output appears here. Run executes the command with your account permissions.") : dev.commandOutput)
                    .font(.system(size: 11, design: .monospaced)).textSelection(.enabled).foregroundStyle(.white.opacity(dev.commandOutput.isEmpty ? 0.3 : 0.8))
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
            }.frame(maxWidth: .infinity, maxHeight: .infinity).background(.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 11)).environment(\.layoutDirection, .leftToRight)
            HStack {
                Text(dev.commandRunning ? app.text("جارٍ التنفيذ…", "Running…") : dev.commandExit.map { "Exit \($0)" } ?? app.text("أوامر غير تفاعلية • لا توجد جلسة طرفية كاملة", "Noninteractive commands • not a full terminal"))
                Spacer()
                smallButton("doc.on.doc", app.text("نسخ الخرج", "Copy output")) { app.copy(Clip(text: dev.commandOutput, source: "Notchest")) }
            }.font(.system(size: 9)).foregroundStyle(.white.opacity(0.6))
        }
    }

    private var git: some View {
        VStack(spacing: 10) {
            HStack {
                directoryRow
                Button("Git") { dev.showingPulls = false }.buttonStyle(.plain).font(.system(size: 10, weight: .medium)).foregroundStyle(dev.showingPulls ? .white.opacity(0.4) : notchestAccent)
                Button("GitHub PR") { dev.showingPulls = true }.buttonStyle(.plain).font(.system(size: 10, weight: .medium)).foregroundStyle(dev.showingPulls ? notchestAccent : .white.opacity(0.4))
                smallButton("arrow.clockwise", app.text("تحديث", "Refresh")) { if dev.showingPulls { dev.refreshPulls() } else { dev.refreshGit() } }
            }
            if dev.gitBusy { ProgressView().controlSize(.small) }
            if dev.showingPulls {
                ScrollView {
                    LazyVStack(spacing: 7) {
                        if let error = dev.pullError {
                            Text(error).font(.system(size: 10)).foregroundStyle(.orange).frame(maxWidth: .infinity, alignment: .leading).padding(12).textSelection(.enabled)
                        } else if dev.pulls.isEmpty {
                            Text(app.text("اختر مستودعًا، ثم اضغط تحديث. يتطلّب GitHub CLI وتسجيل الدخول.", "Choose a repository and refresh. Requires a signed-in GitHub CLI."))
                                .font(.system(size: 11)).foregroundStyle(.white.opacity(0.6)).padding(24)
                        }
                        ForEach(dev.pulls) { pull in
                            Button { NSWorkspace.shared.open(pull.url) } label: {
                                HStack {
                                    Image(systemName: "arrow.triangle.pull").foregroundStyle(notchestAccent)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(pull.title).font(.system(size: 11, weight: .medium)).lineLimit(2)
                                        Text("#\(pull.number) · \(pull.headRefName)\(pull.isDraft ? " · Draft" : "")")
                                            .font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.6))
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.right").font(.system(size: 9)).foregroundStyle(.white.opacity(0.3))
                                }.padding(11).frame(maxWidth: .infinity, alignment: .leading).notchestPanel(cornerRadius: 10)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            } else { ScrollView {
                Text(dev.gitOutput.isEmpty ? app.text("اختر مجلّد المشروع، ثم اقرأ الفرع والتغييرات وآخر الالتزامات.", "Choose a project folder to read its branch, changes and recent commits.") : dev.gitOutput)
                    .font(.system(size: 11, design: .monospaced)).textSelection(.enabled).foregroundStyle(.white.opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .leading).padding(13)
            }.frame(maxWidth: .infinity, maxHeight: .infinity).notchestPanel(cornerRadius: 12).environment(\.layoutDirection, .leftToRight) }
        }
    }

    private var directoryRow: some View {
        HStack {
            smallButton("folder", app.text("مجلّد المشروع", "Project folder")) { dev.chooseWorkingDirectory() }
            Text(dev.workingDirectory.lastPathComponent).font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
            Spacer(minLength: 0)
            smallButton("terminal", app.text("فتح Terminal في المجلّد", "Open Terminal in this folder")) {
                NSWorkspace.shared.open([dev.workingDirectory], withApplicationAt: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"), configuration: NSWorkspace.OpenConfiguration())
            }
        }
    }

    private var snippets: some View {
        VStack(spacing: 11) {
            HStack {
                Text(app.text("مقتطفاتك المتكررة، بنقرة.", "Your repeatable pieces, one click away.")).font(.system(size: 15, weight: .medium))
                Spacer()
                smallButton("plus", app.text("مقتطف جديد", "New snippet")) { dev.addSnippet(arabic: app.arabic) }
            }
            ScrollView {
                LazyVStack(spacing: 7) {
                    if dev.snippets.isEmpty { Text(app.text("أضف أمرًا أو عنوانًا أو قالب كود تستخدمه كثيرًا.", "Save commands, addresses or code you use often.")).font(.system(size: 12)).foregroundStyle(.white.opacity(0.3)).padding(35) }
                    ForEach(dev.snippets) { snippet in
                        HStack {
                            Button { app.copy(Clip(text: snippet.text, source: "Notchest")) } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(snippet.name).font(.system(size: 12, weight: .medium))
                                    Text(snippet.text).font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.6)).lineLimit(2)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }.buttonStyle(.plain)
                            smallButton("trash", app.text("إزالة المقتطف", "Remove snippet")) { dev.deleteSnippet(snippet) }
                        }.padding(12).notchestPanel(cornerRadius: 11)
                    }
                }
            }
        }
    }

    private func codeEditor(text: Binding<String>, label: String, error: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
            PlainTextEditor(text: text, code: true, label: label)
                .foregroundStyle(error ? .orange : .white.opacity(0.85))
                .environment(\.layoutDirection, .leftToRight)
        }.padding(11).notchestPanel(cornerRadius: 12)
    }

    private func smallButton(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon).font(.system(size: 12)).foregroundStyle(.white.opacity(0.6)).frame(minWidth: 24, minHeight: 24) }
            .buttonStyle(.plain).help(title).accessibilityLabel(title)
    }
    private func short(_ number: Int) -> String { number.formatted(.number.notation(.compactName).locale(Locale(identifier: "en_US"))) }
}
