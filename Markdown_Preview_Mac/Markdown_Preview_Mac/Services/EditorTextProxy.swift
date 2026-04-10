import AppKit

@Observable
class EditorTextProxy {
    weak var textView: NSTextView?

    func wrapSelection(prefix: String, suffix: String) {
        guard let textView else { return }
        let range = textView.selectedRange()
        let selected = (textView.string as NSString).substring(with: range)

        let replacement: String
        let newCursorOffset: Int

        if selected.isEmpty {
            replacement = prefix + suffix
            newCursorOffset = prefix.count
        } else {
            replacement = prefix + selected + suffix
            newCursorOffset = replacement.count
        }

        textView.insertText(replacement, replacementRange: range)

        if selected.isEmpty {
            let newPos = range.location + newCursorOffset
            textView.setSelectedRange(NSRange(location: newPos, length: 0))
        } else {
            let newPos = range.location + newCursorOffset
            textView.setSelectedRange(NSRange(location: newPos, length: 0))
        }
    }

    func insertAtLineStart(_ prefix: String) {
        guard let textView else { return }
        let range = textView.selectedRange()
        let text = textView.string as NSString
        let lineRange = text.lineRange(for: range)
        let lineStart = lineRange.location

        textView.insertText(prefix, replacementRange: NSRange(location: lineStart, length: 0))
        textView.setSelectedRange(NSRange(
            location: range.location + prefix.count,
            length: range.length
        ))
    }

    func insertText(_ text: String) {
        guard let textView else { return }
        let range = textView.selectedRange()
        textView.insertText(text, replacementRange: range)
    }

    func insertBlock(_ block: String) {
        guard let textView else { return }
        let range = textView.selectedRange()
        let text = textView.string as NSString

        var prefix = ""
        if range.location > 0 && text.character(at: range.location - 1) != 0x0A {
            prefix = "\n"
        }

        var suffix = ""
        if range.location + range.length < text.length
            && text.character(at: range.location + range.length) != 0x0A {
            suffix = "\n"
        }

        let insertion = prefix + block + suffix
        textView.insertText(insertion, replacementRange: range)
    }
}
