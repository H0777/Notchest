import SwiftUI

struct IslandSettingsView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var compactSize: CGSize { model.display.size(preferences: model.islandPreferences, expanded: false) }
    private var expandedSize: CGSize { model.display.size(preferences: model.islandPreferences, expanded: true) }
    private var compactWidthRange: ClosedRange<Double> {
        min(600, max(200, Double(model.display.minimumCompactWidth)))...600
    }
    private var compactHeightRange: ClosedRange<Double> {
        min(100, max(34, Double(model.display.minimumCompactHeight)))...100
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.text("Notchest، على طريقتك.", "Make Notchest yours."))
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                        Text(model.text("غيّر الأبعاد وشاهد النتيجة فورًا.", "Adjust the dimensions and see them live."))
                            .font(.system(size: 10)).foregroundStyle(.white.opacity(0.62))
                    }
                    Spacer()
                    Button(model.text("استعادة الحجم", "Reset size")) {
                        var settings = model.islandPreferences
                        settings.resetDimensions()
                        model.islandPreferences = settings
                    }
                    .buttonStyle(.plain).font(.system(size: 10, weight: .medium))
                    .foregroundStyle(notchestAccent).help(model.text("استعادة أبعاد الجزيرة الافتراضية", "Restore the default island dimensions"))
                }

                languageRow

                HStack(alignment: .top, spacing: 10) {
                    dimensionCard(
                        title: model.text("الحجم المصغّر", "Collapsed size"),
                        detail: model.text("حول فتحة الكاميرا", "Around the camera"),
                        icon: "capsule", size: compactSize,
                        width: binding(\.compactWidth, in: compactWidthRange), widthRange: compactWidthRange,
                        height: binding(\.compactHeight, in: compactHeightRange), heightRange: compactHeightRange,
                        expanded: false
                    )
                    dimensionCard(
                        title: model.text("الحجم عند الفتح", "Expanded size"),
                        detail: model.text("مساحة الأدوات والمحتوى", "Room for your tools"),
                        icon: "rectangle.expand.vertical", size: expandedSize,
                        width: binding(\.expandedWidth, in: 660...1200), widthRange: 660...1200,
                        height: binding(\.expandedHeight, in: 440...900), heightRange: 440...900,
                        expanded: true
                    )
                }
                Text(model.text("يُضبط الحجم الفعلي تلقائيًا ليلائم الشاشة وفتحة الكاميرا.", "The actual size adjusts to fit your screen and camera housing."))
                    .font(.system(size: 9)).foregroundStyle(.white.opacity(0.58))

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "display").foregroundStyle(notchestAccent).frame(width: 20)
                        Text(model.text("الشاشة", "Display")).font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Picker(model.text("الشاشة", "Display"), selection: $model.selectedDisplayID) {
                            Text(model.text("تلقائي", "Automatic")).tag("auto")
                            ForEach(model.availableDisplays) { display in Text(display.name).tag(display.id) }
                            if model.selectedDisplayID != "auto" && !model.availableDisplays.contains(where: { $0.id == model.selectedDisplayID }) {
                                Text(model.text("الشاشة غير متصلة", "Display disconnected")).tag(model.selectedDisplayID)
                            }
                        }.labelsHidden().frame(maxWidth: 220)
                    }
                    HStack(spacing: 10) {
                        Image(systemName: "paintpalette").foregroundStyle(notchestAccent).frame(width: 20)
                        Text(model.text("لون الواجهة", "Accent color")).font(.system(size: 12, weight: .semibold))
                        Spacer()
                        ForEach(["aurora", "ice", "blue", "purple", "lime", "orange"], id: \.self) { theme in
                            Button { model.accentTheme = theme } label: {
                                Circle().fill(themeColor(theme)).frame(width: 21, height: 21)
                                    .overlay(Circle().strokeBorder(.white.opacity(model.accentTheme == theme ? 0.9 : 0), lineWidth: 2))
                            }.buttonStyle(.plain).accessibilityLabel(themeName(theme))
                        }
                    }
                }.padding(13).notchestPanel(cornerRadius: 14)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "sparkles").foregroundStyle(notchestAccent).frame(width: 20)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.text("الحركة والانتقالات", "Motion & transitions"))
                                .font(.system(size: 12, weight: .semibold))
                            Text(reduceMotion
                                 ? model.text("تقليل الحركة مفعّل في macOS.", "Reduce Motion is enabled in macOS.")
                                 : model.text("فتح وإغلاق وتنقّل أكثر سلاسة.", "Smoother opening, closing, and navigation."))
                                .font(.system(size: 9)).foregroundStyle(.white.opacity(0.6))
                        }
                        Spacer()
                        Toggle(model.text("تفعيل الحركة", "Enable motion"), isOn: $model.islandPreferences.motionEnabled)
                            .labelsHidden().toggleStyle(.switch).controlSize(.small).tint(notchestAccent)
                    }
                    Picker(model.text("سرعة الحركة", "Motion speed"), selection: $model.islandPreferences.motion) {
                        ForEach(IslandMotion.allCases) { style in Text(style.title(arabic: model.arabic)).tag(style) }
                    }
                    .pickerStyle(.segmented)
                    .disabled(reduceMotion || !model.islandPreferences.motionEnabled)
                }.padding(13).notchestPanel(cornerRadius: 14)

                VStack(spacing: 8) {
                    settingRow(icon: "cursorarrow", title: model.text("الفتح عند مرور المؤشّر", "Open on hover"), detail: model.text("اقترب من Notchest لتوسيعها", "Move over the island to expand it"), value: $model.hoverEnabled)
                    settingRow(icon: "doc.on.clipboard", title: model.text("سجلّ الحافظة", "Clipboard history"), detail: model.text("يُمسح عند الإغلاق أو التعطيل", "Cleared on quit or when disabled"), value: $model.clipboardEnabled)
                    settingRow(icon: "power", title: model.text("التشغيل عند تسجيل الدخول", "Launch at login"), detail: model.text("قد يطلب macOS الموافقة في إعدادات النظام", "macOS may ask for approval in System Settings"), value: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                }
                Text(model.text("تُحفظ الإعدادات على هذا الماك.", "Preferences are saved on this Mac."))
                    .font(.system(size: 9)).foregroundStyle(.white.opacity(0.55)).padding(.bottom, 3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
        }
    }

    private func binding(_ keyPath: WritableKeyPath<IslandPreferences, Double>, in range: ClosedRange<Double>) -> Binding<Double> {
        Binding(
            get: { min(range.upperBound, max(range.lowerBound, model.islandPreferences[keyPath: keyPath])) },
            set: { model.islandPreferences[keyPath: keyPath] = $0.rounded() }
        )
    }

    private func dimensionCard(title: String, detail: String, icon: String, size: CGSize,
                               width: Binding<Double>, widthRange: ClosedRange<Double>,
                               height: Binding<Double>, heightRange: ClosedRange<Double>, expanded: Bool) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: icon).font(.system(size: 15)).foregroundStyle(notchestAccent).frame(width: 23, height: 23)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 12, weight: .semibold))
                    Text(detail).font(.system(size: 9)).foregroundStyle(.white.opacity(0.58))
                }
                Spacer(minLength: 4)
                islandPreview(size: size, expanded: expanded).accessibilityHidden(true)
            }
            dimensionSlider(model.text("العرض", "Width"), value: width, range: widthRange, actual: size.width, expanded: expanded)
            dimensionSlider(model.text("الارتفاع", "Height"), value: height, range: heightRange, actual: size.height, expanded: expanded)
        }
        .padding(13).frame(maxWidth: .infinity, minHeight: 145, alignment: .topLeading)
        .notchestPanel(cornerRadius: 14)
    }

    private func islandPreview(size: CGSize, expanded: Bool) -> some View {
        let width = expanded ? min(70, max(35, size.width / 13)) : min(67, max(26, size.width / 7))
        let height = expanded ? min(31, max(16, size.height / 20)) : min(18, max(7, size.height / 4))
        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 5).fill(.white.opacity(0.065)).frame(width: 76, height: 36)
            IslandShape(radius: 5).fill(Color.black).frame(width: width, height: height)
                .overlay(alignment: .top) { Capsule().fill(notchestAccent.opacity(0.65)).frame(width: 4, height: 2).padding(.top, 3) }
        }.frame(width: 76, height: 36)
    }

    private func dimensionSlider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, actual: CGFloat, expanded: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text("\(Int(actual.rounded())) pt").font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.65))
                    .environment(\.layoutDirection, .leftToRight)
            }
            Slider(value: value, in: range).tint(notchestAccent).controlSize(.small)
                .accessibilityLabel((expanded ? model.text("اللوحة المفتوحة، ", "Expanded island, ") : model.text("الجزيرة المصغّرة، ", "Collapsed island, ")) + label)
        }
    }

    private func settingRow(icon: String, title: String, detail: String, value: Binding<Bool>) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon).font(.system(size: 15)).foregroundStyle(notchestAccent.opacity(0.75)).frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 12, weight: .medium))
                Text(detail).font(.system(size: 9)).foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            Toggle(title, isOn: value).labelsHidden().toggleStyle(.switch).controlSize(.small).tint(notchestAccent)
        }.padding(12).notchestPanel(cornerRadius: 12)
    }

    private var languageRow: some View {
        HStack(spacing: 11) {
            Image(systemName: "globe").foregroundStyle(notchestAccent).frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(model.text("اللغة", "Language")).font(.system(size: 12, weight: .medium))
                Text(model.text("الإنجليزية افتراضيًا، والعربية خيار إضافي", "English by default. Arabic is also available."))
                    .font(.system(size: 9)).foregroundStyle(NotchestPalette.secondary)
            }
            Spacer()
            Picker(model.text("لغة الواجهة", "Interface language"), selection: $model.arabic) {
                Text("English").tag(false)
                Text("العربية").tag(true)
            }.labelsHidden().pickerStyle(.menu).frame(width: 120)
        }.padding(12).notchestPanel(cornerRadius: 14, tint: NotchestPalette.cyan)
    }

    private func themeColor(_ theme: String) -> Color { NotchestPalette.accent(theme) }
    private func themeName(_ theme: String) -> String {
        switch theme {
        case "aurora": return model.text("الشفق", "Aurora")
        case "ice": return model.text("جليدي", "Ice")
        case "blue": return model.text("أزرق", "Blue")
        case "purple": return model.text("بنفسجي", "Purple")
        case "orange": return model.text("برتقالي", "Orange")
        default: return model.text("أخضر", "Green")
        }
    }
}
