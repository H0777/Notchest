import SwiftUI
import UniformTypeIdentifiers

var notchestAccent: Color { NotchestPalette.accent(UserDefaults.standard.string(forKey: "accentTheme")) }
private let notchestMuted = NotchestPalette.secondary
private let notchestCard = Color.white.opacity(0.055)

struct IslandView: View {
    @ObservedObject var model: AppModel
    let onHover: (Bool) -> Void
    let activate: () -> Void
    private var search: String { model.clipboardSearch }
    private var targeted: Bool { model.dropTargeted }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var tabIndicator
    private var motionAllowed: Bool { !reduceMotion && model.islandPreferences.motionEnabled }
    private var expansionAnimation: Animation? {
        guard motionAllowed else { return nil }
        return .spring(response: model.expanded ? model.islandPreferences.motion.openDuration : model.islandPreferences.motion.closeDuration, dampingFraction: 0.88)
    }
    private var navigationAnimation: Animation? {
        guard motionAllowed else { return nil }
        return .easeInOut(duration: model.islandPreferences.motion.navigationDuration)
    }
    private var contentIdentity: String { model.paletteVisible ? "palette" : model.tab.rawValue }

    var body: some View {
        VStack(spacing: 0) {
            Button { model.expanded.toggle(); activate() } label: {
                compactHeader
                    .frame(height: model.display.size(preferences: model.islandPreferences, expanded: false).height)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.expanded ? model.text("طيّ Notchest", "Collapse Notchest") : model.text("فتح Notchest", "Open Notchest"))
            .help(model.text("انقر لفتح Notchest أو طيّها", "Click to open or collapse Notchest"))
            if model.expanded {
                VStack(spacing: 17) {
                    header
                    tabs
                    ZStack(alignment: .top) {
                        content
                            .id(contentIdentity)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .transition(motionAllowed ? .asymmetric(insertion: .opacity.combined(with: .offset(y: 7)), removal: .opacity.combined(with: .offset(y: -4))) : .identity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .animation(navigationAnimation, value: contentIdentity)
                    footer
                }
                .padding(.horizontal, 41)
                .padding(.top, 11)
                .padding(.bottom, 19)
                .environment(\.layoutDirection, model.arabic ? .rightToLeft : .leftToRight)
                .environment(\.locale, Locale(identifier: model.arabic ? "ar" : "en_US"))
                .transition(motionAllowed ? .asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.97, anchor: .top)), removal: .opacity.combined(with: .offset(y: -8))) : .identity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background { NotchestIslandSurface(expanded: model.expanded) }
        .clipShape(IslandShape(radius: model.expanded ? 30 : 17))
        .overlay {
            if targeted {
                IslandShape(radius: model.expanded ? 30 : 17).strokeBorder(notchestAccent.opacity(0.65), lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
        .animation(expansionAnimation, value: model.expanded)
        .preferredColorScheme(.dark)
        .tint(notchestAccent)
        .environment(\.notchestMotionEnabled, model.islandPreferences.motionEnabled)
        .onHover(perform: onHover)
        .onTapGesture { activate() }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $model.dropTargeted, perform: receiveDrop)
        .onChange(of: targeted) { active in
            if active { model.select(.shelf) }
        }
    }

    private var compactHeader: some View {
        HStack(spacing: 8) {
            if model.clock.isRunning {
                Image(systemName: "timer").font(.system(size: 13, weight: .medium)).foregroundStyle(notchestAccent)
            } else {
                NotchestMark(monochrome: true).frame(width: 19, height: 19)
            }
            Spacer(minLength: model.display.notchWidth)
            if let activity = model.activityFlash {
                HStack(spacing: 3) {
                    Image(systemName: activity.kind == "download" ? "arrow.down.circle.fill" : activity.kind == "volume" ? "externaldrive.fill" : "bell.badge.fill")
                    Text(String(activity.title.prefix(8))).lineLimit(1)
                }.font(.system(size: 9, weight: .medium)).foregroundStyle(notchestAccent)
            } else if model.clock.isRunning {
                Text(model.timeLabel).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(notchestAccent)
            } else if model.stopwatchStarted != nil {
                Text(model.stopwatchLabel).font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundStyle(notchestAccent)
            } else if let window = model.developer.usage.primary, (window.resetsAt ?? .distantFuture) > model.now {
                Text("\(Int(100 - window.usedPercent))% AI").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(notchestAccent)
            } else if model.awake {
                Image(systemName: "cup.and.saucer.fill").font(.system(size: 12)).foregroundStyle(notchestAccent)
            } else {
                Image(systemName: model.charging ? "battery.100percent.bolt" : "battery.75percent")
                    .font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, model.expanded ? 29 : 17)
        .environment(\.layoutDirection, .leftToRight)
    }

    private var header: some View {
        HStack(spacing: 10) {
            NotchestMark().frame(width: 29, height: 29)
                .frame(width: 43, height: 43)
                .notchestGlass(radius: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.text("Notchest", "Notchest")).font(.system(size: 19, weight: .semibold, design: .rounded)).tracking(-0.35)
                Text(model.text("مساحتك. بانسياب.", "Your space. In flow.")).font(.system(size: 10)).foregroundStyle(notchestMuted)
            }
            Spacer()
            if let battery = model.battery {
                HStack(spacing: 5) {
                    Image(systemName: model.charging ? "battery.100percent.bolt" : "battery.75percent")
                    Text("\(battery)%").monospacedDigit()
                }.font(.system(size: 11)).foregroundStyle(notchestMuted)
                    .environment(\.layoutDirection, .leftToRight)
                    .padding(.trailing, 6)
            }
            iconButton(model.pinned ? "pin.fill" : "pin", label: model.text("تثبيت اللوحة", "Pin island"), selected: model.pinned) {
                model.pinned.toggle()
            }
            iconButton("magnifyingglass", label: model.text("لوحة الأوامر", "Command palette"), selected: model.paletteVisible) { model.paletteVisible.toggle(); activate() }
            iconButton("slider.horizontal.3", label: model.text("الإعدادات", "Settings"), selected: model.tab == .settings) { model.select(.settings) }
        }
    }

    private var tabs: some View {
        HStack(spacing: 5) {
            ForEach(NotchestTab.allCases.filter { $0 != .settings }) { tab in
                Button { model.select(tab) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon).font(.system(size: 12))
                        Text(tab.title(model.arabic)).font(.system(size: 12, weight: model.tab == tab ? .semibold : .regular))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .foregroundStyle(model.tab == tab ? .white : .white.opacity(0.7))
                    .background {
                        if model.tab == tab {
                            RoundedRectangle(cornerRadius: 17).fill(.clear).notchestGlass(selected: true, radius: 17, tint: NotchestPalette.tabColor(tab))
                                .matchedGeometryEffect(id: "selected-tab", in: tabIndicator)
                        }
                    }
                    .contentShape(Rectangle())
                }.buttonStyle(NotchestPressStyle()).accessibilityLabel(tab.title(model.arabic))
                    .accessibilityAddTraits(model.tab == tab ? .isSelected : [])
            }
        }.padding(5).notchestPanel(cornerRadius: 22)
            .animation(motionAllowed ? .spring(response: model.islandPreferences.motion.openDuration, dampingFraction: 0.84) : nil, value: model.tab)
    }

    @ViewBuilder private var content: some View {
        if model.paletteVisible { CommandPalette(app: model) }
        else {
        switch model.tab {
        case .home: ScrollView { home }
        case .developer: DeveloperView(app: model)
        case .tools: ToolsView(app: model)
        case .focus: focus
        case .clipboard: clipboard
        case .shelf: shelf
        case .notes: notes
        case .settings: IslandSettingsView(model: model)
        }
        }
    }

    private var home: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.text("مرحبًا بك في Notchest.", "Welcome to your space."))
                        .font(.system(size: 25, weight: .semibold, design: .rounded)).tracking(-0.5)
                    Text(model.text("التركيز، الأدوات، ومشاريعك في مكان واحد.", "Focus, tools, and projects. Together."))
                        .font(.system(size: 12)).foregroundStyle(notchestMuted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(model.now, format: .dateTime.hour().minute())
                        .font(.system(size: 27, weight: .light, design: .rounded)).monospacedDigit()
                    Text(model.now, format: .dateTime.weekday(.wide).day().month(.abbreviated))
                        .font(.system(size: 10)).foregroundStyle(notchestMuted)
                }.environment(\.locale, Locale(identifier: model.arabic ? "ar" : "en"))
            }.padding(.top, 2).padding(.bottom, 3)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                dashboardCard(icon: "chart.bar.xaxis", title: model.text("استهلاك الذكاء الاصطناعي", "AI usage at a glance"), value: "Codex · Claude Code", color: NotchestPalette.cyan) { model.tab = .developer; model.developer.section = .usage }
                dashboardCard(icon: "chevron.left.forwardslash.chevron.right", title: model.text("مساحة المطوّر", "Developer workspace"), value: model.text("JSON، الأوامر، Git والمقتطفات", "JSON, commands, Git & snippets"), color: NotchestPalette.violet) { model.tab = .developer; model.developer.section = .text }
                dashboardCard(icon: "timer", title: model.text("وقت للتركيز", "Make room for focus"), value: model.clock.isRunning ? model.timeLabel : model.text("ابدأ جلستك الأولى", "Find your flow"), color: NotchestPalette.coral) { model.tab = .focus }
                dashboardCard(icon: "doc.on.clipboard", title: model.text("الحافظة", "Clipboard"), value: model.clipboardEnabled ? model.text("\(model.clips.count) عناصر هذا التشغيل", "\(model.clips.count) items this launch") : model.text("فعّلها عندما تحتاجها", "Ready when you are"), color: NotchestPalette.mint) { model.tab = .clipboard }
                dashboardCard(icon: "tray", title: model.text("رفّ الملفات", "A place for your files"), value: model.text("\(model.shelf.count) ملفات في متناولك", "\(model.shelf.count) items within reach"), color: NotchestPalette.amber) { model.tab = .shelf }
                dashboardCard(icon: "cup.and.saucer", title: model.text("إبقاء الجهاز مستيقظًا", "Keep Mac awake"), value: model.awake ? model.text("مفعّل لمدة ساعة", "On for one hour") : model.text("جاهز لجلسة طويلة", "For the longer sessions"), color: NotchestPalette.rose) { model.toggleAwake() }
            }
        }
    }

    private func dashboardCard(icon: String, title: String, value: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 19, weight: .regular)).foregroundStyle(color)
                    .frame(width: 37, height: 40)
                    .background(LinearGradient(colors: [color.opacity(0.34), color.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(color.opacity(0.28), lineWidth: 0.7))
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.90))
                    Text(value).font(.system(size: 10)).foregroundStyle(notchestMuted).lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: model.arabic ? "chevron.left" : "chevron.right").font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.2))
            }.padding(16).frame(height: 76).notchestPanel(cornerRadius: 20, tint: color).notchestHover(radius: 20)
        }.buttonStyle(NotchestPressStyle())
    }

    private var focus: some View {
        HStack(spacing: 28) {
            ZStack {
                Circle().stroke(notchestAccent.opacity(0.09), lineWidth: 6)
                Circle().trim(from: 0, to: max(0.01, model.focusProgress)).stroke(notchestAccent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 9) {
                    Text(model.text("تنفّس. ثم ابدأ.", "Breathe. Then begin."))
                        .font(.system(size: 10)).foregroundStyle(notchestMuted)
                    Text(model.focusDisplayLabel).font(.system(size: model.stopwatchMode ? 31 : 46, weight: .light, design: .rounded)).monospacedDigit()
                        .environment(\.layoutDirection, .leftToRight)
                    HStack(spacing: 5) {
                        Circle().fill(model.focusIsRunning ? notchestAccent : notchestMuted).frame(width: 4, height: 4)
                        Text(model.focusIsRunning ? model.text("جارٍ التركيز", "IN THE FLOW") : model.text("على مهلِك", "AT YOUR PACE"))
                    }.font(.system(size: 9, weight: .medium)).foregroundStyle(notchestMuted)
                }
            }.frame(width: 205, height: 205)
            VStack(alignment: .leading, spacing: 15) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.text("شيء واحد في كل مرة.", "One thing at a time."))
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                    Text(model.text("اختر وقتًا، ودع الباقي ينتظر.", "Pick a time. Let the rest wait."))
                        .font(.system(size: 11)).foregroundStyle(notchestMuted)
                }
                Button(model.stopwatchMode ? model.text("العودة للمؤقّت", "Switch to countdown") : model.text("استخدام ساعة الإيقاف", "Switch to stopwatch")) { model.stopwatchMode.toggle() }
                    .buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(notchestAccent.opacity(0.7))
                if !model.stopwatchMode {
                HStack(spacing: 6) {
                    ForEach([5, 25, 50], id: \.self) { minutes in
                        Button { model.resetTimer(minutes: minutes) } label: {
                            Text("\(minutes) \(model.text("د", "min"))").font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 12).padding(.vertical, 9)
                                .foregroundStyle(Int(model.clock.duration / 60) == minutes ? notchestAccent : notchestMuted)
                                .background(Int(model.clock.duration / 60) == minutes ? notchestAccent.opacity(0.1) : notchestCard, in: Capsule())
                        }.buttonStyle(.plain)
                    }
                }
                }
                HStack(spacing: 9) {
                    accentButton(model.focusIsRunning ? model.text("إيقاف مؤقّت", "Pause session") : model.text("ابدأ الجلسة", "Start session"), icon: model.focusIsRunning ? "pause.fill" : "play.fill") { if model.stopwatchMode { model.toggleStopwatch() } else { model.toggleTimer() } }
                    iconButton("arrow.counterclockwise", label: model.text("إعادة ضبط المؤقّت", "Reset timer")) { if model.stopwatchMode { model.resetStopwatch() } else { model.resetTimer() } }
                }
                Text(model.text("\(model.sessions) جلسات مكتملة", "\(model.sessions) sessions completed"))
                    .font(.system(size: 10)).foregroundStyle(notchestMuted)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.frame(maxHeight: .infinity).padding(.horizontal, 8)
    }

    private var clipboard: some View {
        VStack(spacing: 11) {
            if !model.clipboardEnabled {
                emptyState(icon: "doc.on.clipboard", title: model.text("ما تنسخه، يبقى قريبًا.", "Good ideas deserve a second copy."), detail: model.text("سجلّ نصوص اختياري، محفوظ في الذاكرة حتى إغلاق التطبيق.\nنتجاهل المحتوى الذي تميّزه التطبيقات بأنه سرّي.", "An optional text history kept in memory until you quit.\nContent marked confidential by its app is skipped.")) {
                    accentButton(model.text("تفعيل سجلّ الحافظة", "Enable clipboard history"), icon: "checkmark") { model.clipboardEnabled = true }
                }
            } else {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(notchestMuted)
                    TextField(model.text("ابحث في المنسوخات…", "Search your clipboard…"), text: $model.clipboardSearch).textFieldStyle(.plain)
                    Button { model.clips.removeAll() } label: { Image(systemName: "trash").foregroundStyle(notchestMuted) }
                        .buttonStyle(.plain).help(model.text("مسح السجلّ", "Clear history"))
                }.font(.system(size: 12)).padding(11).notchestPanel(cornerRadius: 11)
                if model.clips.isEmpty {
                    emptyState(icon: "sparkles", title: model.text("جاهزة لأول نسخة.", "Ready for your first copy."), detail: model.text("انسخ نصًا في أي تطبيق وسيظهر هنا.", "Copy text in any app and it will appear here.")) { EmptyView() }
                } else {
                    let results = model.clips.filter { search.isEmpty || $0.text.localizedCaseInsensitiveContains(search) }
                    if results.isEmpty {
                        emptyState(icon: "magnifyingglass", title: model.text("لا توجد نتائج", "No matches"), detail: model.text("جرّب كلمات أخرى.", "Try another search.")) { EmptyView() }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 6) {
                                ForEach(results) { clip in
                                    Button { model.copy(clip) } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: "text.alignleft").foregroundStyle(notchestAccent.opacity(0.7))
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(clip.text).font(.system(size: 12)).foregroundStyle(.white.opacity(0.9)).lineLimit(2).multilineTextAlignment(.leading)
                                                Text(clip.source).font(.system(size: 9)).foregroundStyle(notchestMuted)
                                            }
                                            Spacer()
                                            Image(systemName: "doc.on.doc").foregroundStyle(notchestMuted)
                                        }.padding(11).frame(maxWidth: .infinity, alignment: .leading).notchestPanel(cornerRadius: 11)
                                    }.buttonStyle(.plain).help(model.text("نسخ النص", "Copy text"))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var shelf: some View {
        VStack(spacing: 11) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.text("محطّة صغيرة لملفاتك.", "A small stop for your files."))
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                    Text(model.text("اسحب ملفًا إلى Notchest، ثم اسحبه إلى أي مكان.", "Drop files onto Notchest. Drag them out anywhere."))
                        .font(.system(size: 10)).foregroundStyle(notchestMuted)
                }
                Spacer()
                iconButton("plus", label: model.text("إضافة ملفات", "Add files")) { model.chooseFiles() }
            }
            if model.shelf.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray.and.arrow.down").font(.system(size: 32, weight: .ultraLight)).foregroundStyle(notchestAccent.opacity(0.7))
                    Text(model.text("أفلت ملفاتك هنا", "Drop something here" )).font(.system(size: 13, weight: .medium))
                    Button(model.text("أو اختر ملفات", "or choose files")) { model.chooseFiles() }
                        .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(notchestMuted)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RoundedRectangle(cornerRadius: 18).strokeBorder(notchestAccent.opacity(0.19), style: StrokeStyle(lineWidth: 1, dash: [5, 5])))
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                        ForEach(model.shelf) { item in
                            VStack(spacing: 6) {
                                HStack {
                                    Spacer()
                                    Button { NSWorkspace.shared.activateFileViewerSelecting([item.url]) } label: { Image(systemName: "folder").font(.system(size: 10)) }
                                        .buttonStyle(.plain).help(model.text("إظهار في Finder", "Reveal in Finder"))
                                    Button { NSSharingService(named: .sendViaAirDrop)?.perform(withItems: [item.url]) } label: { Image(systemName: "paperplane").font(.system(size: 10)) }
                                        .buttonStyle(.plain).help(model.text("إرسال عبر AirDrop", "Send via AirDrop"))
                                    Button { model.removeFile(item) } label: { Image(systemName: "xmark").font(.system(size: 9)) }
                                        .buttonStyle(.plain).help(model.text("إزالة من الرفّ", "Remove from shelf"))
                                }.foregroundStyle(notchestMuted)
                                Button { model.openFile(item) } label: {
                                    VStack(spacing: 6) {
                                        Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path)).resizable().frame(width: 37, height: 37)
                                        Text(item.url.lastPathComponent).font(.system(size: 10)).lineLimit(1).truncationMode(.middle)
                                    }.frame(maxWidth: .infinity)
                                }.buttonStyle(.plain)
                            }.padding(10).notchestPanel(cornerRadius: 13)
                                .onDrag { NSItemProvider(object: item.url as NSURL) }
                        }
                    }
                }
            }
        }
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.text("قبل أن تطير الفكرة.", "Before the thought flies away."))
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                    Text(model.text("مساحة لك. تُحفظ تلقائيًا على هذا الماك.", "A space for you. Saved automatically on this Mac."))
                        .font(.system(size: 10)).foregroundStyle(notchestMuted)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill").foregroundStyle(notchestAccent.opacity(0.7)).font(.system(size: 12))
            }
            ZStack(alignment: .topLeading) {
                if model.note.isEmpty {
                    Text(model.text("فكرة، مهمّة، أو بداية شيء جميل…", "An idea, a to-do, the start of something good…"))
                        .font(.system(size: 13)).foregroundStyle(.white.opacity(0.23)).padding(.horizontal, 5).padding(.top, 8)
                        .allowsHitTesting(false)
                }
                PlainTextEditor(text: $model.note, arabic: model.arabic, label: model.text("ملاحظاتك", "Your notes"))
            }.padding(12).notchestPanel(cornerRadius: 15)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Circle().fill(notchestAccent.opacity(0.75)).frame(width: 4, height: 4)
            Text(model.toast ?? model.text("مساحتك الهادئة أعلى الشاشة", "Your quiet corner, at the top"))
                .font(.system(size: 9)).foregroundStyle(model.toast == nil ? notchestMuted : notchestAccent).lineLimit(1)
            Spacer()
            Text("⌃ ⌥ Space").font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.3))
                .environment(\.layoutDirection, .leftToRight)
            Button { model.expanded = false } label: { Image(systemName: "chevron.up").font(.system(size: 9)).foregroundStyle(notchestMuted) }
                .buttonStyle(.plain).padding(.leading, 7).help(model.text("طيّ Notchest", "Collapse Notchest"))
        }.padding(.top, 7).overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.065)).frame(height: 1) }
    }

    private func emptyState<Actions: View>(icon: String, title: String, detail: String, @ViewBuilder actions: () -> Actions) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 28, weight: .light)).foregroundStyle(notchestAccent.opacity(0.8))
            Text(title).font(.system(size: 17, weight: .semibold, design: .rounded))
            Text(detail).font(.system(size: 11)).foregroundStyle(notchestMuted).multilineTextAlignment(.center).lineSpacing(4)
            actions().padding(.top, 3)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func iconButton(_ icon: String, label: String, selected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 12, weight: .medium)).foregroundStyle(selected ? notchestAccent : .white.opacity(0.8))
                .frame(width: 32, height: 32).notchestGlass(selected: selected, radius: 12)
        }.buttonStyle(NotchestPressStyle()).help(label).accessibilityLabel(label)
    }

    private func accentButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) { Image(systemName: icon).font(.system(size: 10)); Text(title).font(.system(size: 11, weight: .semibold)) }
                .padding(.horizontal, 16).padding(.vertical, 11).foregroundStyle(Color.black.opacity(0.9))
                .background(LinearGradient(colors: [.white, notchestAccent], startPoint: .topLeading, endPoint: .bottomTrailing), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.6), lineWidth: 0.7))
        }.buttonStyle(NotchestPressStyle())
    }

    private func receiveDrop(_ providers: [NSItemProvider]) -> Bool {
        let valid = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !valid.isEmpty else { return false }
        model.select(.shelf)
        for provider in valid {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { value, _ in
                let url: URL?
                if let data = value as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
                else if let value = value as? URL { url = value }
                else if let string = value as? String { url = URL(string: string) }
                else { url = nil }
                if let url { Task { @MainActor in model.addFiles([url]) } }
            }
        }
        return true
    }
}

struct IslandShape: InsettableShape {
    var radius: CGFloat
    var insetAmount: CGFloat = 0
    var animatableData: CGFloat {
        get { radius }
        set { radius = newValue }
    }
    func path(in rect: CGRect) -> Path {
        Path(IslandOutline.path(in: rect, radius: radius, inset: insetAmount))
    }

    func inset(by amount: CGFloat) -> IslandShape { var copy = self; copy.insetAmount += amount; return copy }
}
