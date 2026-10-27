import SwiftUI

struct CommandPalette: View {
    @ObservedObject var app: AppModel
    private struct Action: Identifiable { let id: String; let icon: String; let run: () -> Void }
    private var actions: [Action] {
        var list = NotchestTab.allCases.map { tab in Action(id: tab.title(app.arabic), icon: tab.icon, run: { app.select(tab) }) }
        list += [
            Action(id: app.text("إحصاءات Codex", "Codex usage"), icon: "chart.bar.xaxis", run: { app.developer.changeProvider(.codex); app.developer.section = .usage; app.select(.developer) }),
            Action(id: app.text("إحصاءات Claude Code", "Claude Code usage"), icon: "chart.bar.xaxis", run: { app.developer.changeProvider(.claude); app.developer.section = .usage; app.select(.developer) }),
            Action(id: app.text("تنسيق JSON وBase64 وSHA-256", "JSON, Base64 & SHA-256"), icon: "curlybraces", run: { app.developer.section = .text; app.select(.developer) }),
            Action(id: app.text("تشغيل أمر برمجي", "Run a command"), icon: "terminal", run: { app.developer.section = .command; app.select(.developer) }),
            Action(id: app.text("الطرفية التفاعلية", "Interactive terminal"), icon: "terminal.fill", run: { app.developer.section = .terminal; app.select(.developer) }),
            Action(id: app.text("حالة Git", "Git status"), icon: "arrow.triangle.branch", run: { app.developer.section = .git; app.select(.developer) }),
            Action(id: app.text("المقتطفات المحفوظة", "Saved snippets"), icon: "text.quote", run: { app.developer.section = .snippets; app.select(.developer) }),
            Action(id: app.text("الموسيقى وSpotify", "Music & Spotify"), icon: "music.note", run: { app.tools.section = "media"; app.select(.tools) }),
            Action(id: app.text("الصور ولقطات الشاشة وOCR", "Images, screen capture & OCR"), icon: "text.viewfinder", run: { app.tools.section = "files"; app.select(.tools) }),
            Action(id: app.text("الصوت والميكروفون والنظام", "Audio, microphone & system"), icon: "speaker.wave.2", run: { app.tools.section = "system"; app.select(.tools) }),
            Action(id: app.text("التقويم والتذكيرات والحاسبة", "Calendar, reminders & calculator"), icon: "calendar", run: { app.tools.section = "daily"; app.select(.tools) }),
            Action(id: app.text("ساعة الإيقاف", "Stopwatch"), icon: "stopwatch", run: { app.stopwatchMode = true; app.select(.focus) })
        ]
        return list.filter { app.paletteQuery.isEmpty || $0.id.localizedCaseInsensitiveContains(app.paletteQuery) }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(notchestAccent)
                TextField(app.text("ابحث عن أداة أو إجراء…", "Find a tool or action…"), text: $app.paletteQuery)
                    .textFieldStyle(.plain).font(.system(size: 14))
                    .onSubmit { actions.first?.run() }
                Text("⌃ ⌥ K").font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.3)).environment(\.layoutDirection, .leftToRight)
            }.padding(14).notchestPanel(cornerRadius: 13)
            ScrollView {
                LazyVStack(spacing: 5) {
                    ForEach(actions) { action in
                        Button(action: action.run) {
                            HStack(spacing: 12) {
                                Image(systemName: action.icon).frame(width: 24).foregroundStyle(notchestAccent.opacity(0.8))
                                Text(action.id).font(.system(size: 12)).foregroundStyle(.white.opacity(0.8))
                                Spacer()
                                Image(systemName: "return").font(.system(size: 9)).foregroundStyle(.white.opacity(0.2))
                            }.padding(11).notchestPanel(cornerRadius: 10)
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
