import Foundation

enum HomeCard: String, Codable, CaseIterable, Identifiable {
    case usage, activity, code, focus, clipboard, shelf, notes, awake
    var id: String { rawValue }
    func title(_ ar: Bool) -> String {
        switch self {
        case .usage: return ar ? "استهلاك AI" : "AI usage"
        case .activity: return ar ? "المشروع والمهام" : "Project & tasks"
        case .code: return ar ? "أدوات الكود" : "Code tools"
        case .focus: return ar ? "التركيز" : "Focus"
        case .clipboard: return ar ? "الحافظة" : "Clipboard"
        case .shelf: return ar ? "الملفات" : "File shelf"
        case .notes: return ar ? "الملاحظات" : "Notes"
        case .awake: return ar ? "إبقاء الجهاز مستيقظاً" : "Keep awake"
        }
    }
}

enum WorkspacePreset: String, CaseIterable, Identifiable {
    case developer, focus, everyday
    var id: String { rawValue }
    var cards: [HomeCard] {
        switch self {
        case .developer: return [.usage, .activity, .code, .focus]
        case .focus: return [.focus, .notes, .awake, .shelf]
        case .everyday: return [.clipboard, .shelf, .focus, .notes]
        }
    }
    func title(_ ar: Bool) -> String {
        switch self {
        case .developer: return ar ? "البرمجة" : "Developer"
        case .focus: return ar ? "التركيز" : "Focus"
        case .everyday: return ar ? "الاستخدام اليومي" : "Everyday"
        }
    }
}

struct WorkspacePreferences: Codable, Equatable {
    var cards: [HomeCard] = WorkspacePreset.developer.cards
    /// The dark readability layer above the system's behind-window material.
    var backgroundOpacity = 0.42
    func validated() -> Self {
        var result = self
        var seen = Set<HomeCard>()
        result.cards = cards.filter { seen.insert($0).inserted }
        if result.cards.isEmpty { result.cards = [.usage] }
        result.backgroundOpacity = backgroundOpacity.isFinite ? min(0.75, max(0.08, backgroundOpacity)) : 0.42
        return result
    }
    mutating func setVisible(_ card: HomeCard, _ visible: Bool) {
        if visible && !cards.contains(card) { cards.append(card) }
        if !visible && cards.count > 1 { cards.removeAll { $0 == card } }
    }
    mutating func move(_ card: HomeCard, by offset: Int) {
        guard let index = cards.firstIndex(of: card), cards.indices.contains(index + offset) else { return }
        cards.swapAt(index, index + offset)
    }
}
