import SwiftUI

struct ToolsView: View {
    @ObservedObject var app: AppModel
    @ObservedObject var tools: NativeTools
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    init(app: AppModel) { self.app = app; self.tools = app.tools }

    var body: some View {
        VStack(spacing: 11) {
            HStack(spacing: 7) {
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 7) {
                ForEach(["system", "media", "files", "daily", "weather", "translate", "stocks"], id: \.self) { section in
                    Button { tools.section = section } label: {
                        Text(title(section)).font(.system(size: 11, weight: .medium)).padding(.horizontal, 16).padding(.vertical, 7)
                            .foregroundStyle(tools.section == section ? .white : .white.opacity(0.65))
                            .background { if tools.section == section { Capsule().fill(.clear).notchestGlass(selected: true, radius: 20) } }
                    }.buttonStyle(.plain)
                } }
                }
                if tools.busy { ProgressView().controlSize(.mini) }
            }
            ScrollView {
                VStack(spacing: 12) {
                    Group {
                    switch tools.section {
                    case "system": system
                    case "media": media
                    case "files": files
                    case "weather": WeatherView(app: app, weather: app.weather)
                    case "translate":
                        if #available(macOS 15, *) { TranslationView(app: app) }
                        else { Text(app.text("الترجمة داخل التطبيق تحتاج macOS 15 أو أحدث.", "In-app translation requires macOS 15 or later.")).font(.system(size: 11)).foregroundStyle(.white.opacity(0.5)).padding() }
                    case "stocks": StocksView(app: app, stocks: app.stocks)
                    default: daily
                    }
                    }
                    .id(tools.section)
                    .transition(reduceMotion || !app.islandPreferences.motionEnabled ? .identity : .opacity.combined(with: .offset(y: 5)))
                    .animation(reduceMotion || !app.islandPreferences.motionEnabled ? nil : .easeInOut(duration: app.islandPreferences.motion.navigationDuration), value: tools.section)
                    if !tools.result.isEmpty {
                        HStack(alignment: .top) {
                            Text(tools.result).font(.system(size: 11, design: .monospaced)).textSelection(.enabled).lineLimit(6).frame(maxWidth: .infinity, alignment: .leading)
                            Button { tools.result = "" } label: { Image(systemName: "xmark").font(.system(size: 9)) }.buttonStyle(.plain)
                        }.padding(12).foregroundStyle(.white.opacity(0.6)).notchestPanel(cornerRadius: 11)
                            .environment(\.layoutDirection, .leftToRight)
                    }
                }
            }
        }
    }

    private var system: some View {
        VStack(spacing: 12) {
            HStack(spacing: 9) {
                stat("CPU", value: "\(Int(tools.cpuPercent))%", icon: "cpu")
                stat(app.text("الذاكرة", "MEMORY"), value: "\(Int(tools.memoryPercent))%", icon: "memorychip")
                stat(app.text("مساحة فارغة", "DISK FREE"), value: "\(Int(tools.freeDiskGB)) GB", icon: "internaldrive")
            }
            HStack(spacing: 14) {
                Image(systemName: "speaker.wave.2").foregroundStyle(notchestAccent)
                Slider(value: Binding(get: { tools.volume ?? 0 }, set: tools.setVolume), in: 0...1)
                    .tint(notchestAccent).disabled(tools.volume == nil).accessibilityLabel(app.text("مستوى الصوت", "Output volume"))
                Text(tools.volume.map { "\(Int($0 * 100))%" } ?? "—").font(.system(size: 11, design: .monospaced)).foregroundStyle(.white.opacity(0.65)).frame(width: 38)
                Picker(app.text("مخرج الصوت", "Output"), selection: Binding(get: { tools.selectedOutput }, set: tools.changeOutput)) {
                    ForEach(tools.outputs) { output in Text(output.name).tag(output.id) }
                }.labelsHidden().frame(maxWidth: 170).controlSize(.small)
            }.padding(13).notchestPanel(cornerRadius: 13)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                tool("mic.slash", app.text("كتم الميكروفون", "Microphone mute"), detail: tools.micMuted == nil ? app.text("غير مدعوم بالجهاز الحالي", "Unavailable on this input") : tools.micMuted == true ? app.text("مكتوم", "Muted") : app.text("قيد التشغيل", "Live")) { tools.toggleMic() }
                tool("cup.and.saucer", app.text("إبقاء الماك مستيقظًا", "Keep Mac awake"), detail: app.awake ? app.text("مفعّل لمدة ساعة", "On for one hour") : app.text("ساعة واحدة", "For one hour")) { app.toggleAwake() }
                tool("arrow.up.left.and.arrow.down.right", app.text("ملء مساحة العمل", "Fill workspace"), detail: app.text("يتطلّب تسهيلات الاستخدام", "Accessibility permission")) { tools.tileWindow("full") }
                tool("rectangle.lefthalf.filled", app.text("نافذة إلى اليسار", "Tile window left"), detail: app.text("نصف الشاشة", "Half the screen")) { tools.tileWindow("left") }
                tool("rectangle.righthalf.filled", app.text("نافذة إلى اليمين", "Tile window right"), detail: app.text("نصف الشاشة", "Half the screen")) { tools.tileWindow("right") }
                tool("arrow.clockwise", app.text("تحديث القراءات", "Refresh readings"), detail: app.text("تتحدّث كل 4 ثوانٍ", "Updates every 4 seconds")) { tools.refreshSystem() }
            }
        }
    }

    private var media: some View {
        VStack(spacing: 14) {
            HStack(spacing: 15) {
                ZStack {
                    RoundedRectangle(cornerRadius: 17).fill(notchestAccent.opacity(0.08)).frame(width: 73, height: 73)
                    if let artwork = tools.musicArtwork {
                        Image(nsImage: artwork).resizable().scaledToFill().frame(width: 73, height: 73).clipShape(RoundedRectangle(cornerRadius: 17))
                    } else {
                        Image(systemName: "music.note").font(.system(size: 27, weight: .light)).foregroundStyle(notchestAccent)
                    }
                }
                VStack(alignment: .leading, spacing: 7) {
                    Text(tools.musicTitle.isEmpty ? app.text("موسيقاك، أقرب.", "Your music, closer.") : tools.musicTitle).font(.system(size: 18, weight: .medium)).lineLimit(1)
                    Text(tools.musicArtist.isEmpty ? app.text("اربط التطبيق لعرض المقطع الحالي", "Connect a player to read the current track") : tools.musicArtist).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
                    Text(app.text("قد يطلب macOS إذن الأتمتة عند الربط.", "macOS may ask for Automation permission on connect.")).font(.system(size: 9)).foregroundStyle(.white.opacity(0.3))
                    if tools.musicConnected {
                        Text("\(musicTime(tools.displayedMusicPosition(at: app.now))) / \(musicTime(tools.musicDuration))")
                            .font(.system(size: 9, design: .monospaced)).foregroundStyle(notchestAccent.opacity(0.8)).environment(\.layoutDirection, .leftToRight)
                    }
                }
                Spacer()
                VStack(spacing: 8) {
                    Picker("Player", selection: $tools.musicApp) { Text("Apple Music").tag("Music"); Text("Spotify").tag("Spotify") }.labelsHidden().frame(width: 120).controlSize(.small)
                    Button(app.text("ربط / تحديث", "Connect / refresh")) { tools.refreshMusic() }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(notchestAccent)
                }
            }.padding(16).notchestPanel(cornerRadius: 16)
            HStack(spacing: 30) {
                transport("backward.end.fill", app.text("السابق", "Previous")) { tools.controlMusic("previous track") }
                transport("playpause.fill", app.text("تشغيل / إيقاف", "Play / pause")) { tools.controlMusic("playpause") }
                transport("forward.end.fill", app.text("التالي", "Next")) { tools.controlMusic("next track") }
            }.frame(maxWidth: .infinity).padding(12).environment(\.layoutDirection, .leftToRight)
            if tools.musicConnected {
                HStack {
                    Text(app.text("كلمات الأغنية", "Lyrics")).font(.system(size: 11, weight: .medium))
                    Spacer()
                    if tools.lyricsLoading { ProgressView().controlSize(.mini) }
                    Button(tools.showLyrics ? app.text("إخفاء", "Hide") : app.text("جلب من LRCLIB", "Fetch from LRCLIB")) {
                        if tools.showLyrics { tools.showLyrics = false } else { tools.loadLyrics() }
                    }.buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(notchestAccent)
                        .help(app.text("يُرسل اسم المقطع والفنان إلى LRCLIB", "Sends the track and artist to LRCLIB"))
                }
                if tools.showLyrics {
                    if let error = tools.lyricsError { Text(error).font(.system(size: 10)).foregroundStyle(.orange) }
                    else if !tools.lyrics.isEmpty {
                        let current = LyricsParser.currentIndex(tools.lyrics, position: tools.displayedMusicPosition(at: app.now))
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 9) {
                                    ForEach(tools.lyrics) { line in
                                        Text(line.text.isEmpty ? "♪" : line.text)
                                            .font(.system(size: 12, weight: current == line.id ? .semibold : .regular))
                                            .foregroundStyle(current == line.id ? notchestAccent : .white.opacity(0.4)).id(line.id)
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
                            }.frame(height: 115).notchestPanel(cornerRadius: 10)
                                .onChange(of: current) { id in
                                    guard let id else { return }
                                    if reduceMotion || !app.islandPreferences.motionEnabled { proxy.scrollTo(id, anchor: .center) }
                                    else { withAnimation { proxy.scrollTo(id, anchor: .center) } }
                                }
                        }
                    } else if !tools.plainLyrics.isEmpty {
                        ScrollView { Text(tools.plainLyrics).font(.system(size: 11)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(12) }
                            .frame(height: 115).notchestPanel(cornerRadius: 10)
                    }
                }
            }
            HStack(spacing: 9) {
                tool("camera", app.text("مرآة الكاميرا", "Camera mirror"), detail: app.text("معاينة محلية بإذن الكاميرا", "Local preview • camera permission")) { tools.showMirror() }
                tool("headphones", app.text("مخرج الصوت", "Audio output"), detail: tools.outputs.first(where: { $0.id == tools.selectedOutput })?.name ?? "—") { tools.section = "system" }
            }
        }
    }

    private var files: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
            tool("camera.viewfinder", app.text("لقطة شاشة", "Screen capture"), detail: app.text("تحديد منطقة ثم إضافتها للرف", "Select region → file shelf")) { tools.screenshot { app.addFiles([$0]); app.select(.shelf) } }
            tool("text.viewfinder", app.text("استخراج نص صورة", "Clipboard OCR"), detail: app.text("انسخ صورة، ثم استخرج نصّها", "Copy an image, extract its text")) { tools.recognizeClipboardImage() }
            tool("eyedropper", app.text("التقاط لون", "Pick a color"), detail: app.text("نسخ رمز HEX", "Copy its HEX value")) { tools.sampleColor() }
            tool("photo", app.text("تحويل إلى PNG", "Convert to PNG"), detail: app.text("تحويل محلي للصور", "Convert images locally")) { tools.convertImage(to: .png) { app.addFiles([$0]) } }
            tool("photo.on.rectangle", app.text("تحويل إلى JPEG", "Convert to JPEG"), detail: app.text("اختيار مكان الحفظ", "Choose where to save")) { tools.convertImage(to: .jpeg) { app.addFiles([$0]) } }
            tool("photo.stack", app.text("تحويل إلى HEIC", "Convert to HEIC"), detail: app.text("عند دعم الجهاز للصيغة", "When the format is supported")) { tools.convertImage(to: .heic) { app.addFiles([$0]) } }
            tool("archivebox", app.text("ضغط ZIP", "Create ZIP"), detail: app.text("ملف أو مجلّد", "One file or folder")) { tools.archive(unzip: false) { app.addFiles([$0]) } }
            tool("archivebox.fill", app.text("فكّ ZIP", "Extract ZIP"), detail: app.text("إلى مجلّد جديد", "Into a new folder")) { tools.archive(unzip: true) { app.addFiles([$0]) } }
            tool("app.badge", app.text("تثبيت تطبيق في الرف", "Pin an app in the shelf"), detail: app.text("أضف ملف .app من Applications", "Add an .app from Applications")) { app.select(.shelf); app.chooseFiles() }
        }.disabled(tools.busy)
    }

    private var daily: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "equal").foregroundStyle(notchestAccent)
                TextField(app.text("حساب، مثل (12 + 8) × 3", "Calculate, e.g. (12 + 8) * 3"), text: $tools.calculatorInput).textFieldStyle(.plain).font(.system(size: 12, design: .monospaced)).onSubmit { tools.calculate() }
                Button(app.text("احسب", "Calculate")) { tools.calculate() }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(notchestAccent)
                Text(tools.calculatorResult).font(.system(size: 13, design: .monospaced)).textSelection(.enabled)
            }.padding(13).notchestPanel(cornerRadius: 12).environment(\.layoutDirection, .leftToRight)
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass").foregroundStyle(notchestAccent)
                TextField(app.text("ابحث أو ترجم عبر المتصفّح…", "Search or translate in your browser…"), text: $tools.searchQuery).textFieldStyle(.plain).font(.system(size: 12)).onSubmit { tools.webSearch() }
                Button(app.text("بحث", "Search")) { tools.webSearch() }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(notchestAccent)
                Button(app.text("ترجمة", "Translate")) { tools.webSearch(translate: true) }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(notchestAccent)
            }.padding(13).notchestPanel(cornerRadius: 12)
            HStack(spacing: 9) {
                tool("calendar", app.text("أحداث 24 ساعة", "Next 24 hours"), detail: app.text("ربط تقويم Apple بإذنك", "Connect Apple Calendar")) { tools.loadCalendar() }
                tool("checklist", app.text("إضافة تذكير", "Add a reminder"), detail: app.text("إلى تطبيق التذكيرات", "To Apple Reminders")) { tools.addReminder(arabic: app.arabic) }
                tool("square.stack.3d.up", app.text("اختصارات Apple", "Apple Shortcuts"), detail: app.text("تحميل اختصاراتك المحلية", "Load your local shortcuts")) { tools.loadShortcuts() }
            }
            if !tools.shortcutNames.isEmpty {
                HStack {
                    Picker(app.text("الاختصار", "Shortcut"), selection: $tools.selectedShortcut) { ForEach(tools.shortcutNames, id: \.self) { Text($0).tag($0) } }.controlSize(.small)
                    Button(app.text("تشغيل", "Run")) { tools.runShortcut() }.buttonStyle(.plain).foregroundStyle(notchestAccent).font(.system(size: 11))
                }
            }
            ForEach(Array(tools.calendarLines.enumerated()), id: \.offset) { _, line in
                HStack { Image(systemName: "circle.fill").font(.system(size: 4)).foregroundStyle(notchestAccent); Text(line).font(.system(size: 11)); Spacer() }
                    .padding(9).notchestPanel(cornerRadius: 8)
            }
        }
    }

    private func stat(_ label: String, value: String, icon: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon).font(.system(size: 20, weight: .light)).foregroundStyle(notchestAccent.opacity(0.7))
            VStack(alignment: .leading, spacing: 5) {
                Text(label).font(.system(size: 9)).foregroundStyle(.white.opacity(0.55))
                Text(value).font(.system(size: 22, weight: .light, design: .rounded))
            }
            Spacer()
        }.padding(13).notchestPanel(cornerRadius: 13)
    }

    private func tool(_ icon: String, _ title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: icon).font(.system(size: 18, weight: .light)).foregroundStyle(notchestAccent.opacity(0.8)).frame(width: 25)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.9)).lineLimit(1)
                    Text(detail).font(.system(size: 8)).foregroundStyle(.white.opacity(0.55)).lineLimit(2)
                }
                Spacer(minLength: 0)
            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(12)
                .notchestPanel(cornerRadius: 13)
        }.buttonStyle(.plain)
    }

    private func transport(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon).font(.system(size: 20)).foregroundStyle(notchestAccent).frame(width: 45, height: 35) }
            .buttonStyle(.plain).help(title).accessibilityLabel(title)
    }
    private func title(_ section: String) -> String {
        switch section {
        case "system": return app.text("النظام والصوت", "System & audio")
        case "media": return app.text("الوسائط", "Media")
        case "files": return app.text("الصور والملفات", "Images & files")
        case "weather": return app.text("الطقس", "Weather")
        case "translate": return app.text("الترجمة", "Translate")
        case "stocks": return app.text("الأسهم", "Stocks")
        default: return app.text("كلّ يوم", "Everyday")
        }
    }
    private func musicTime(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(seconds.isFinite ? seconds : 0))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}
