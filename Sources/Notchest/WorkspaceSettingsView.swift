import SwiftUI

struct WorkspaceSettingsView: View {
    @ObservedObject var app: AppModel
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(app.text("الزجاج والشفافية", "Glass & transparency"), systemImage: "drop.halffull").font(.system(size: 12, weight: .semibold))
            Slider(value: Binding(get: { 1 - app.workspace.backgroundOpacity }, set: { app.workspace.backgroundOpacity = 1 - $0 }), in: 0.25...0.92) {
                Text(app.text("شفافية الخلفية", "Background transparency"))
            }.tint(notchestAccent).disabled(reduceTransparency || contrast == .increased)
            HStack { Text(app.text("أكثر تعتيماً", "More solid")); Spacer(); Text(app.text("أكثر شفافية", "More transparent")) }.font(.system(size: 9)).foregroundStyle(.white.opacity(0.65))
            if reduceTransparency || contrast == .increased {
                Text(app.text("إعدادات تسهيلات الاستخدام في macOS تمنح الوضوح الأولوية.", "macOS accessibility settings take priority for readability.")).font(.system(size: 10)).foregroundStyle(.orange)
            }
        }.padding(13).notchestPanel(cornerRadius: 14)
        VStack(alignment: .leading, spacing: 12) {
            Label(app.text("صفحتك الرئيسية", "Your overview"), systemImage: "square.grid.2x2").font(.system(size: 12, weight: .semibold))
            HStack {
                ForEach(WorkspacePreset.allCases) { preset in
                    Button(preset.title(app.arabic)) { app.workspace.cards = preset.cards }
                        .buttonStyle(.plain).font(.system(size: 11, weight: .medium)).padding(.horizontal, 12).padding(.vertical, 8)
                        .notchestGlass(selected: app.workspace.cards == preset.cards, radius: 12)
                }
            }
            ForEach(app.workspace.cards + HomeCard.allCases.filter { !app.workspace.cards.contains($0) }) { card in
                HStack {
                    Toggle(card.title(app.arabic), isOn: Binding(get: { app.workspace.cards.contains(card) }, set: { app.workspace.setVisible(card, $0) }))
                        .toggleStyle(.checkbox).font(.system(size: 11))
                        .disabled(app.workspace.cards.count == 1 && app.workspace.cards.contains(card))
                    Spacer()
                    Button { app.workspace.move(card, by: -1) } label: { Image(systemName: "arrow.up") }
                        .disabled(app.workspace.cards.firstIndex(of: card).map { $0 == 0 } ?? true)
                        .help(app.text("تحريك لأعلى", "Move up"))
                    Button { app.workspace.move(card, by: 1) } label: { Image(systemName: "arrow.down") }
                        .disabled(app.workspace.cards.firstIndex(of: card).map { $0 == app.workspace.cards.count - 1 } ?? true)
                        .help(app.text("تحريك لأسفل", "Move down"))
                }.buttonStyle(.plain).foregroundStyle(.white.opacity(0.8))
            }
        }.padding(13).notchestPanel(cornerRadius: 14)
    }
}

struct UpdateSettingsView: View {
    @ObservedObject var app: AppModel
    @ObservedObject private var updates: UpdateModel
    init(app: AppModel) { self.app = app; self.updates = app.updates }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(app.text("التحديثات", "Updates"), systemImage: "arrow.down.circle").font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("v\(updates.currentVersion)").font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.6))
                Button(app.text("تحقق الآن", "Check now")) { updates.check() }.disabled(updates.checking).buttonStyle(.plain).foregroundStyle(notchestAccent)
            }
            Toggle(app.text("التحقق التلقائي كل 6 ساعات", "Check automatically every 6 hours"), isOn: $updates.automaticChecks).font(.system(size: 11)).toggleStyle(.switch).controlSize(.mini)
            if updates.checking { ProgressView().controlSize(.small) }
            if let error = updates.error { Text(error.resolved(arabicUI: app.arabic)).foregroundStyle(.orange).font(.system(size: 10)) }
            if let latest = updates.latest {
                HStack {
                    Text(updates.updateAvailable ? app.text("الإصدار \(latest.version) متاح", "Version \(latest.version) is available") : app.text("أنت تستخدم أحدث إصدار متاح أو نسخة تطوير أحدث", "You have the latest release or a newer development build"))
                        .font(.system(size: 10))
                    Spacer()
                    Button(app.text("صفحة التنزيل", "Download page")) { NSWorkspace.shared.open(latest.page) }.buttonStyle(.plain).foregroundStyle(notchestAccent)
                }
            }
            Text(app.text("توقيع Developer ID وتصديق Apple مؤجّلان. يتم تثبيت التحديثات يدوياً من صفحة الإصدار حالياً.", "Developer ID signing and Apple notarization are deferred. Updates are currently installed manually from the release page."))
                .font(.system(size: 9)).foregroundStyle(.white.opacity(0.65))
        }.padding(13).notchestPanel(cornerRadius: 14)
    }
}
