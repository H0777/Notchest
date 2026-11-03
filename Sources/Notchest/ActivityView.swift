import SwiftUI

struct ActivityView: View {
    @ObservedObject var app: AppModel
    @ObservedObject var activity: ActivityCenter
    @ObservedObject private var monitor: SystemMonitor
    init(app: AppModel, activity: ActivityCenter) { self.app = app; self.activity = activity; self.monitor = app.monitor }
    var body: some View {
        ScrollView {
            VStack(spacing: 11) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.text("نشاط مشاريعك", "Your projects, in motion")).font(.system(size: 17, weight: .semibold, design: .rounded))
                        Text(app.text("المهام والنتائج في مكان واحد.", "Tasks and results, together.")).font(.system(size: 10)).foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                    if !activity.activities.isEmpty { Button(app.text("مسح السجل", "Clear history")) { activity.activities.removeAll() }.buttonStyle(.plain).font(.system(size: 10)) }
                }
                ProjectActivityCard(app: app)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label(app.text("ربط مهام AI محلياً", "Connect AI tasks locally"), systemImage: "waveform.path").font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Toggle(app.text("الواجهة المحلية", "Local API"), isOn: Binding(get: { activity.apiEnabled }, set: { $0 ? activity.startAPI() : activity.stopAPI() })).font(.system(size: 10)).toggleStyle(.switch).controlSize(.mini)
                    }
                    Text(app.text("الربط اختياري؛ يعرض حالة المهمة واسم المشروع. عند طلب موافقة، ارجع إلى أداة البرمجة.", "Optional hooks show task state and project name. Return to your coding tool for approvals.")).font(.system(size: 10)).foregroundStyle(.white.opacity(0.7))
                    HStack(spacing: 10) {
                        ForEach(AgentIntegration.allCases) { provider in
                            Menu(provider.title) {
                                Button(app.text("تثبيت الربط…", "Install integration…")) { activity.configureHooks(provider, arabic: app.arabic) }
                                Button(app.text("إزالة الربط…", "Remove integration…")) { activity.configureHooks(provider, remove: true, arabic: app.arabic) }
                            }.font(.system(size: 11))
                        }
                        Spacer()
                        if activity.apiEnabled {
                            Button(app.text("نسخ مثال للسكربتات", "Copy script example")) { activity.copyExample(); app.showToast(app.text("نُسخ المثال والرمز", "Example and token copied")) }.font(.system(size: 10)).buttonStyle(.plain).foregroundStyle(notchestAccent)
                        }
                    }
                    if let message = activity.hookMessage { Text(message.resolved(arabicUI: app.arabic)).font(.system(size: 10)).foregroundStyle(notchestAccent) }
                    if let error = activity.apiError { Text(error).font(.system(size: 10)).foregroundStyle(.orange) }
                }.padding(13).notchestPanel(cornerRadius: 14)
                HStack(spacing: 12) {
                    Toggle(app.text("التنزيلات", "Downloads"), isOn: $monitor.watchDownloads)
                    Toggle(app.text("الأقراص", "Drives"), isOn: $monitor.watchVolumes)
                    Toggle("Caps Lock", isOn: $monitor.watchCapsLock)
                    Spacer()
                }.font(.system(size: 10)).toggleStyle(.checkbox)
                if let problem = monitor.problem { Text(problem).font(.system(size: 9)).foregroundStyle(.orange) }
                if activity.activities.isEmpty {
                    Text(app.text("ستظهر حالات المهام هنا بعد ربط أدواتك.", "Task updates appear here after connecting your tools.")).font(.system(size: 11)).foregroundStyle(.white.opacity(0.65)).padding(20)
                }
                LazyVStack(spacing: 7) {
                    ForEach(activity.activities) { item in
                        HStack(spacing: 10) {
                            Image(systemName: icon(item.state)).foregroundStyle(item.state == "failure" || item.state == "waiting" ? .orange : notchestAccent).frame(width: 23)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title).font(.system(size: 11, weight: .medium))
                                if item.kind == "agent" { Text(stateTitle(item.state, app: app)).font(.system(size: 10)).foregroundStyle(.white.opacity(0.75)) }
                                if !item.message.isEmpty { Text(item.message).font(.system(size: 10)).foregroundStyle(.white.opacity(0.7)).lineLimit(2) }
                                if let progress = item.progress { ProgressView(value: progress).tint(notchestAccent) }
                            }
                            Spacer()
                            if let url = item.url {
                                if item.kind == "volume" {
                                    Button { do { try NSWorkspace.shared.unmountAndEjectDevice(at: url); app.showToast(app.text("يمكن فصل القرص", "Safe to disconnect")) } catch { app.showToast(error.localizedDescription) } } label: { Image(systemName: "eject") }.buttonStyle(.plain)
                                }
                                Button { if url.scheme == "https" { NSWorkspace.shared.open(url) } else { NSWorkspace.shared.activateFileViewerSelecting([url]) } } label: { Image(systemName: url.scheme == "https" ? "arrow.up.right" : "folder") }.buttonStyle(.plain).help(app.text("فتح النتيجة", "Open result"))
                            }
                            Text(item.updated, style: .relative).font(.system(size: 9)).foregroundStyle(.white.opacity(0.55))
                        }.padding(11).notchestPanel(cornerRadius: 12)
                    }
                }
            }.padding(.horizontal, 3).padding(.bottom, 8)
        }
    }
    private func icon(_ state: String) -> String {
        switch state { case "running": return "hourglass"; case "waiting": return "hand.raised.fill"; case "success": return "checkmark.circle.fill"; case "failure": return "exclamationmark.circle.fill"; default: return "bell.badge" }
    }
}

@MainActor private func stateTitle(_ state: String, app: AppModel) -> String {
    switch state {
    case "running": return app.text("قيد العمل", "Working")
    case "waiting": return app.text("بانتظار تدخّلك في الأداة", "Needs your attention in the tool")
    case "success": return app.text("اكتملت الجولة", "Turn completed")
    case "failure": return app.text("تعذّر التنفيذ", "Failed")
    default: return app.text("متوقف أو منتهٍ", "Stopped or finished")
    }
}

private struct ProjectActivityCard: View {
    @ObservedObject var app: AppModel
    @ObservedObject private var project: ProjectMonitor
    @ObservedObject private var dev: DeveloperModel
    init(app: AppModel) { self.app = app; project = app.project; dev = app.developer }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "folder").foregroundStyle(notchestAccent)
                Button(dev.workingDirectory.lastPathComponent) { dev.chooseWorkingDirectory() }.font(.system(size: 12, weight: .semibold)).buttonStyle(.plain).help(app.text("اختر المشروع", "Choose project"))
                Spacer()
                if project.loading { ProgressView().controlSize(.mini) }
                Button { project.refresh() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain).disabled(!project.enabled || project.loading).help(app.text("تحديث", "Refresh"))
                Toggle("GitHub Actions", isOn: $project.enabled).font(.system(size: 10)).toggleStyle(.switch).controlSize(.mini)
            }
            if let error = project.error { Text(error.resolved(arabicUI: app.arabic)).font(.system(size: 10)).foregroundStyle(.orange) }
            if project.enabled {
                ForEach(project.runs.prefix(4)) { run in
                    Button { NSWorkspace.shared.open(run.url) } label: {
                        HStack {
                            Image(systemName: run.activityState == "success" ? "checkmark.circle.fill" : run.activityState == "failure" ? "xmark.circle.fill" : "circle.dotted").foregroundStyle(run.activityState == "failure" ? .orange : notchestAccent)
                            Text(run.displayTitle.isEmpty ? run.name : run.displayTitle).lineLimit(1)
                            Spacer()
                            Text(run.headBranch).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
                            Image(systemName: "arrow.up.right")
                        }.font(.system(size: 10))
                    }.buttonStyle(.plain)
                }
                if project.runs.isEmpty && !project.loading && project.error == nil { Text(app.text("لم نجد عمليات في هذا المستودع.", "No workflow runs found for this repository.")).font(.system(size: 10)).foregroundStyle(.white.opacity(0.65)) }
                HStack { Text(app.text("تحديث كل دقيقة", "Refreshes every minute")); Spacer(); if let checked = project.checkedAt { Text(checked, style: .relative) } }.font(.system(size: 9)).foregroundStyle(.white.opacity(0.6))
            } else {
                Text(app.text("اختر مستودعاً وفعّل المتابعة لعرض نتائج البناء والاختبارات من GitHub.", "Choose a repository and enable tracking to see GitHub build and test results.")).font(.system(size: 10)).foregroundStyle(.white.opacity(0.7))
            }
        }.padding(13).notchestPanel(cornerRadius: 14)
    }
}
