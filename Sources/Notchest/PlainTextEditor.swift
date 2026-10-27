import AppKit
import SwiftUI

private final class IslandTextView: NSTextView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
}

struct PlainTextEditor: NSViewRepresentable {
    @Binding var text: String
    var arabic: Bool = false
    var code: Bool = false
    var label: String

    func makeCoordinator() -> Coordinator { Coordinator(binding: $text) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        let editor = IslandTextView()
        editor.isRichText = false
        editor.isEditable = true
        editor.isSelectable = true
        editor.allowsUndo = true
        editor.drawsBackground = false
        editor.textColor = .white.withAlphaComponent(0.88)
        editor.insertionPointColor = NSColor(notchestAccent)
        editor.textContainerInset = NSSize(width: 5, height: 8)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.minSize = .zero
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.textContainer?.widthTracksTextView = true
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.isContinuousSpellCheckingEnabled = !code
        editor.delegate = context.coordinator
        scroll.documentView = editor
        configure(editor)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.binding = $text
        guard let editor = scroll.documentView as? NSTextView else { return }
        if editor.string != text {
            let selection = editor.selectedRange()
            editor.string = text
            editor.setSelectedRange(NSRange(location: min(selection.location, editor.string.utf16.count), length: 0))
        }
        configure(editor)
    }

    private func configure(_ editor: NSTextView) {
        let font: NSFont = code ? .monospacedSystemFont(ofSize: 11, weight: .regular) : .systemFont(ofSize: 13)
        let alignment: NSTextAlignment = arabic && !code ? .right : .left
        let direction: NSWritingDirection = arabic && !code ? .rightToLeft : .leftToRight
        if editor.font != font { editor.font = font }
        if editor.alignment != alignment { editor.alignment = alignment }
        if editor.baseWritingDirection != direction { editor.baseWritingDirection = direction }
        editor.insertionPointColor = NSColor(notchestAccent)
        editor.setAccessibilityLabel(label)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var binding: Binding<String>
        init(binding: Binding<String>) { self.binding = binding }
        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            binding.wrappedValue = editor.string
        }
    }
}
