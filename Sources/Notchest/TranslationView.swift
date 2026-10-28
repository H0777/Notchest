import SwiftUI
import Translation

@available(macOS 15, *)
@MainActor
final class NotchestTranslationModel: ObservableObject {
    static let shared = NotchestTranslationModel()
    @Published var input = ""
    @Published var output = ""
    @Published var target = "ar"
    @Published var configuration: TranslationSession.Configuration?
    @Published var pending = ""
    @Published var loading = false
    @Published var error: String?
    /// Set from the app's language choice before each request.
    var arabicUI = true

    func request() {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { error = ServiceText("أدخل نصًا", "Enter text").resolved(arabicUI: arabicUI); return }
        guard value.count <= 10_000 else { error = ServiceText("النص طويل جدًا", "Text is too long").resolved(arabicUI: arabicUI); return }
        pending = value; loading = true; error = nil
        let language = Locale.Language(identifier: target)
        if var current = configuration {
            current.target = language
            current.invalidate()
            configuration = current
        } else { configuration = TranslationSession.Configuration(source: nil, target: language) }
    }
}

@available(macOS 15, *)
struct TranslationView: View {
    @ObservedObject var app: AppModel
    @ObservedObject private var translation = NotchestTranslationModel.shared
    var body: some View {
        VStack(spacing: 11) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.text("ترجمة داخل Notchest", "Translate in Notchest")).font(.system(size: 17, weight: .semibold, design: .rounded))
                    Text(app.text("ترجمة Apple على الجهاز؛ قد تُطلب حزمة لغة.", "Apple on-device translation; language downloads may be requested."))
                        .font(.system(size: 9)).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Picker(app.text("اللغة", "Language"), selection: $translation.target) {
                    Text("العربية").tag("ar"); Text("English").tag("en"); Text("Français").tag("fr")
                    Text("Türkçe").tag("tr"); Text("Español").tag("es")
                }.labelsHidden().frame(width: 130).controlSize(.small)
                Button(app.text("ترجمة", "Translate")) { translation.arabicUI = app.arabic; translation.request() }.buttonStyle(.plain).foregroundStyle(notchestAccent).font(.system(size: 11, weight: .semibold))
            }
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(app.text("النص", "Text")).font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
                    PlainTextEditor(text: $translation.input, arabic: false, label: app.text("النص للترجمة", "Text to translate"))
                }.padding(10).notchestPanel(cornerRadius: 12)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(app.text("الترجمة", "Translation")).font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        if translation.loading { ProgressView().controlSize(.mini) }
                        Button { app.copy(Clip(text: translation.output, source: "Notchest")) } label: { Image(systemName: "doc.on.doc") }.buttonStyle(.plain).help(app.text("نسخ الترجمة", "Copy translation"))
                    }
                    PlainTextEditor(text: $translation.output, arabic: translation.target == "ar", label: app.text("الترجمة", "Translation"))
                }.padding(10).notchestPanel(cornerRadius: 12)
            }.frame(minHeight: 130)
            if let error = translation.error { Text(error).font(.system(size: 10)).foregroundStyle(.orange).lineLimit(3) }
        }
        .translationTask(translation.configuration) { session in
            let input = await MainActor.run { translation.pending }
            do {
                let response = try await session.translate(input)
                guard !Task.isCancelled else { return }
                await MainActor.run { if translation.pending == input { translation.output = response.targetText; translation.loading = false } }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run { if translation.pending == input { translation.error = ServiceText.network(error).resolved(arabicUI: translation.arabicUI); translation.loading = false } }
            }
        }
    }
}
