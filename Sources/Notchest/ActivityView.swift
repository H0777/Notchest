import SwiftUI

struct ActivityView: View {
    @ObservedObject var app: AppModel
    @ObservedObject var activity: ActivityCenter
    @ObservedObject private var monitor: SystemMonitor
    init(app: AppModel, activity: ActivityCenter) { self.app = app; self.activity = activity; self.monitor = app.monitor }
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.text("نشاط أدواتك", "Your activity"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text(app.text("إشعارات محلية من البرامج والمهام.", "Local updates from scripts and tasks."))
                        .font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                if !activity.activities.isEmpty {
                    Button(app.text("مسح", "Clear")) { activity.activities.removeAll() }
                        .buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                }
            }
            HStack(spacing: 10) {
                Image(systemName: "network").foregroundStyle(notchestAccent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.text("واجهة محلية للمطوّر", "Local developer API")).font(.system(size: 11, weight: .medium))
                    Text(activity.apiEnabled ? app.text("تعمل على 127.0.0.1 فقط • الرمز يتغيّر عند الإيقاف", "127.0.0.1 only • token rotates when stopped") : app.text("متوقفة افتراضيًا؛ تتيح للسكربت إرسال نشاط", "Off by default; lets scripts post an activity"))
                        .font(.system(size: 9)).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                if activity.apiEnabled {
                    Button(app.text("نسخ مثال", "Copy example")) { activity.copyExample(); app.showToast(app.text("نُسخ المثال والرمز", "Example and token copied")) }
                        .buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(notchestAccent)
                }
                Toggle(app.text("واجهة المطوّر", "Developer API"), isOn: Binding(get: { activity.apiEnabled }, set: { $0 ? activity.startAPI() : activity.stopAPI() }))
                    .labelsHidden().toggleStyle(.switch).controlSize(.small).tint(notchestAccent)
            }.padding(12).notchestPanel(cornerRadius: 12)
            if let error = activity.apiError { Text(error).font(.system(size: 10)).foregroundStyle(.orange).frame(maxWidth: .infinity, alignment: .leading) }
            HStack(spacing: 12) {
                Toggle(app.text("التنزيلات", "Downloads"), isOn: $monitor.watchDownloads)
                Toggle(app.text("الأقراص", "Drives"), isOn: $monitor.watchVolumes)
                Toggle("Caps Lock", isOn: $monitor.watchCapsLock)
            }.font(.system(size: 10)).toggleStyle(.checkbox)
            if let problem = monitor.problem { Text(problem).font(.system(size: 9)).foregroundStyle(.orange) }
            ScrollView {
                LazyVStack(spacing: 7) {
                    if activity.activities.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "waveform.path").font(.system(size: 23, weight: .light)).foregroundStyle(notchestAccent.opacity(0.7))
                            Text(app.text("ستظهر الأنشطة الجديدة هنا.", "New activities will appear here."))
                                .font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
                        }.frame(maxWidth: .infinity).padding(25)
                    }
                    ForEach(activity.activities) { item in
                        HStack(spacing: 10) {
                            Image(systemName: icon(item.state)).foregroundStyle(color(item.state)).frame(width: 23)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title).font(.system(size: 11, weight: .medium))
                                if !item.message.isEmpty { Text(item.message).font(.system(size: 10)).foregroundStyle(.white.opacity(0.65)).lineLimit(2) }
                                if let progress = item.progress { ProgressView(value: progress).tint(notchestAccent) }
                            }
                            Spacer()
                            if let url = item.url {
                                if item.kind == "volume" {
                                    Button {
                                        do { try NSWorkspace.shared.unmountAndEjectDevice(at: url); app.showToast(app.text("يمكن فصل القرص", "Safe to disconnect")) }
                                        catch { app.showToast(error.localizedDescription) }
                                    } label: { Image(systemName: "eject") }
                                    .buttonStyle(.plain).help(app.text("إخراج القرص", "Eject drive"))
                                }
                                Button { NSWorkspace.shared.activateFileViewerSelecting([url]) } label: { Image(systemName: "folder") }
                                    .buttonStyle(.plain).help(app.text("إظهار في Finder", "Reveal in Finder"))
                            }
                            Text(item.updated, style: .time).font(.system(size: 9)).foregroundStyle(.white.opacity(0.3))
                        }.padding(11).notchestPanel(cornerRadius: 10)
                    }
                }
            }
        }
    }
    private func icon(_ state: String) -> String {
        switch state { case "running": return "hourglass"; case "success": return "checkmark.circle.fill"; case "failure": return "exclamationmark.circle.fill"; default: return "bell.badge" }
    }
    private func color(_ state: String) -> Color { state == "failure" ? .orange : notchestAccent.opacity(0.8) }
}
