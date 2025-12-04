import AppKit
import SwiftUI

struct SyntaxOption {
    var word: String
    var color: NSColor
    var font: NSFont = .monospacedSystemFont(ofSize: 12, weight: .regular)
    static var `default`: [SyntaxOption] {
        return [
            // Keywords
            SyntaxOption(word: "struct", color: .systemBlue),
            SyntaxOption(word: "class", color: .systemBlue),
            SyntaxOption(word: "enum", color: .systemBlue),
            SyntaxOption(word: "static", color: .systemPink),
            SyntaxOption(word: "func", color: .systemPink),
            SyntaxOption(word: "case", color: .systemPink),
            SyntaxOption(word: "mutating", color: .systemPink),
            SyntaxOption(word: "nonmutating", color: .systemPink),
            SyntaxOption(word: "let", color: .systemPink),
            SyntaxOption(word: "var", color: .systemPink),
            SyntaxOption(word: "return", color: .systemPink),
            SyntaxOption(word: "protocol", color: .systemPink),
            SyntaxOption(word: "extension", color: .systemPink),
            SyntaxOption(word: "private", color: .systemPink),
            SyntaxOption(word: "public", color: .systemPink),
            SyntaxOption(word: "internal", color: .systemPink),

            // Types
            SyntaxOption(word: "Int", color: .systemPink),
            SyntaxOption(word: "String", color: .systemPink),
            SyntaxOption(word: "Bool", color: .systemPink),
            SyntaxOption(word: "Double", color: .systemPink),
            SyntaxOption(word: "Float", color: .systemPink),

            // Constants
            SyntaxOption(word: "true", color: .systemPink),
            SyntaxOption(word: "false", color: .systemPink),
            SyntaxOption(word: "nil", color: .systemPink),

            // Compiler Directives
            SyntaxOption(word: "#if", color: .systemOrange),
            SyntaxOption(word: "#else", color: .systemOrange),
            SyntaxOption(word: "#endif", color: .systemOrange),

            // Protocols
            SyntaxOption(word: "Identifiable", color: .systemPink),
            SyntaxOption(word: "Hashable", color: .systemPink),
            SyntaxOption(word: "Equatable", color: .systemPink),
            SyntaxOption(word: "Codable", color: .systemPink),
            SyntaxOption(word: "Encodable", color: .systemPink),
            SyntaxOption(word: "Decodable", color: .systemPink),
        ]
    }
}

protocol Themeable {
    var syntaxOptions: [SyntaxOption] { get }
    var backgroundColor: NSColor { get }
}

struct EditorTheme: Identifiable, Themeable {
    var id = UUID()
    var name: String
    var font: NSFont = .monospacedSystemFont(ofSize: 13.5, weight: .regular)

    var syntaxOptions: [SyntaxOption]
    var backgroundColor: NSColor = Color.overlaySecondaryBackground.nsColor

    static var `default`: EditorTheme {
        .init(name: "Default", syntaxOptions: SyntaxOption.default)
    }
}

struct CodeEditor: NSViewRepresentable {
    @Binding var text: String
    var theme: EditorTheme
    var padding: CGFloat = 10
    var onHeightChange: ((CGFloat) -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }

        textView.font = theme.font
        textView.isEditable = true
        textView.isRichText = false
        textView.backgroundColor = theme.backgroundColor
        textView.insertionPointColor = Color.overlaySecondaryPrimary.nsColor
        textView.string = text
        textView.delegate = context.coordinator
        
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true

        scrollView.contentInsets = .init(top: padding, left: padding, bottom: padding, right: padding)
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.hasVerticalScroller = false
        
        context.coordinator.textView = textView
        applySyntaxStyling(to: textView)
        
        DispatchQueue.main.async {
            updateHeight(textView: textView)
        }
        
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            let safeRange = NSRange(location: min(selectedRange.location, text.count), length: 0)
            textView.setSelectedRange(safeRange)
        }
        
        applySyntaxStyling(to: textView)
        
        DispatchQueue.main.async {
            updateHeight(textView: textView)
        }
    }
    
    private func updateHeight(textView: NSTextView) {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }
        
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        let contentHeight = usedRect.height + padding * 2
        onHeightChange?(contentHeight)
    }

    func applySyntaxStyling(to textView: NSTextView) {
        guard let textStorage = textView.textStorage, textStorage.length > 0 else { return }
        
        let selectedRange = textView.selectedRange()
        let fullRange = NSRange(location: 0, length: textStorage.length)
        
        textStorage.beginEditing()
        

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 3.5
        
        textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
        textStorage.addAttribute(.font, value: theme.font, range: fullRange)
        textStorage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)

        for option in theme.syntaxOptions {
            let regex = try? NSRegularExpression(pattern: "\\b\(NSRegularExpression.escapedPattern(for: option.word))\\b", options: .caseInsensitive)
            let matches = regex?.matches(in: textStorage.string, options: [], range: fullRange) ?? []
            for match in matches {
                textStorage.addAttribute(.foregroundColor, value: option.color, range: match.range)
                textStorage.addAttribute(.font, value: option.font, range: match.range)
            }
        }

        if let commentRegex = try? NSRegularExpression(pattern: "^\\s*#.*$", options: .anchorsMatchLines) {
            let commentMatches = commentRegex.matches(in: textStorage.string, options: [], range: fullRange)
            for match in commentMatches {
                textStorage.addAttribute(.foregroundColor, value: Color.overlaySecondaryPrimary.nsColor, range: match.range)
            }
        }

        textStorage.endEditing()
        textView.setSelectedRange(selectedRange)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}

extension CodeEditor {
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditor
        weak var textView: NSTextView?

        init(_ parent: CodeEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

