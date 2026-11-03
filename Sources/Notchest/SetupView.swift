import SwiftUI

struct SetupView: View {
    @ObservedObject var app: AppModel
    @ObservedObject private var setup: SetupModel
    @ObservedObject private var dev: DeveloperModel
    init(app: AppModel) { self.app = app; setup = app.setup; dev = app.developer }
    private func refresh() { setup.refresh(codexDirectory: dev.directory(for: .codex), claudeDirectory: dev.directory(for: .claude)) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(app.text("لنجهّز مساحتك.", "Make room for your day.")).font(.system(size: 23, weight: .semibold, design: .rounded))
                        Text(app.text("اختر أدواتك؛ يمكنك تغيير كل شيء من الإعدادات.", "Choose your tools. Everything can be changed in Settings.")).font(.system(size: 11)).foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                    Picker(app.text("اللغة", "Language"), selection: $app.arabic) { Text("English").tag(false); Text("العربية").tag(true) }.labelsHidden().frame(width: 115)
                }
                HStack {
                    ForEach(WorkspacePreset.allCases) { preset in
                        Button(preset.title(app.arabic)) { app.workspace.cards = preset.cards }
                            .buttonStyle(.plain).font(.system(size: 12, weight: .medium)).padding(12)
                            .frame(maxWidth: .infinity).notchestGlass(selected: app.workspace.cards == preset.cards, radius: 15)
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(app.text("اتصالاتك", "Your connections")).font(.system(size: 12, weight: .semibold))
                        Spacer()
                        if setup.checking { ProgressView().controlSize(.mini) }
                        Button(app.text("إعادة الفحص", "Check again"), action: refresh).buttonStyle(.plain).foregroundStyle(notchestAccent).disabled(setup.checking)
                    }
                    ForEach(setup.checks) { check in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: check.available ? "checkmark.circle.fill" : "circle.dashed").foregroundStyle(check.available ? NotchestPalette.mint : NotchestPalette.amber)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(check.id == "codex-logs" ? app.text("Codex · السجلات المحلية", "Codex · local logs") : check.name).font(.system(size: 11, weight: .semibold))
                                Text(check.detail.resolved(arabicUI: app.arabic)).font(.system(size: 10)).foregroundStyle(.white.opacity(0.7))
                            }
                            Spacer()
                            if check.id == "codex-logs" || check.id == "claude" {
                                Button(app.text("المجلّد", "Folder")) { dev.changeProvider(check.id == "claude" ? .claude : .codex); dev.chooseUsageFolder(); refresh() }
                                    .buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(notchestAccent)
                            }
                        }
                    }
                    Toggle(app.text("قراءة إحصاءات AI المحلية", "Read local AI statistics"), isOn: $dev.trackingEnabled)
                    Toggle(app.text("تحديث حدود حساب Codex كل دقيقة", "Refresh Codex account limits every minute"), isOn: $dev.liveAutoRefreshEnabled)
                    Toggle(app.text("تنبيه عند اقتراب حد Codex", "Alert when approaching a Codex limit"), isOn: $dev.usageAlertsEnabled)
                    Text(app.text("الأرقام المحلية من هذا الجهاز؛ الاتصال الحي يتطلب حساب Codex متاحاً.", "Local statistics come from this Mac; live limits require an available Codex account.")).font(.system(size: 9)).foregroundStyle(.white.opacity(0.6))
                }.toggleStyle(.checkbox).font(.system(size: 11)).padding(14).notchestPanel(cornerRadius: 16)
                HStack {
                    Button(app.text("اختر مجلّد المشروع", "Choose project folder")) { dev.chooseWorkingDirectory() }.buttonStyle(.bordered)
                    Text(dev.workingDirectory.lastPathComponent).font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.65))
                    Spacer()
                    Button(app.text("ابدأ الاستخدام", "Start using Notchest")) { app.finishSetup() }.buttonStyle(.borderedProminent).tint(notchestAccent).foregroundStyle(.black)
                }
                Text(app.text("الحافظة والتكاملات الإضافية متاحة عند اختيارها. لا نطلب أذونات الكاميرا أو التقويم أثناء الإعداد.", "Clipboard and other integrations are available when you choose them. Setup does not request camera or calendar access."))
                    .font(.system(size: 9)).foregroundStyle(.white.opacity(0.65))
            }.padding(.horizontal, 5).padding(.bottom, 8)
        }.onAppear(perform: refresh)
    }
}
