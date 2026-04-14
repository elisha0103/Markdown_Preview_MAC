import AppKit

@Observable
class EditorTextProxy {
    weak var textField: NSTextField?
    var savedRange: NSRange?

    /// Restores focus to the text field, gets the field editor, restores selection, then runs the action.
    private func withFieldEditor(_ action: (NSTextView) -> Void) {
        guard let textField else { return }

        // If the field editor is already active, use it directly
        if let editor = textField.currentEditor() as? NSTextView {
            action(editor)
            return
        }

        // Restore focus to the text field
        textField.window?.makeFirstResponder(textField)
        guard let editor = textField.currentEditor() as? NSTextView else { return }

        // Restore the saved cursor/selection position
        if let range = savedRange,
           range.location + range.length <= (editor.string as NSString).length {
            editor.setSelectedRange(range)
        }

        action(editor)
    }

    func wrapSelection(prefix: String, suffix: String) {
        withFieldEditor { editor in
            let range = editor.selectedRange()
            let selected = (editor.string as NSString).substring(with: range)

            let replacement: String
            if selected.isEmpty {
                replacement = prefix + suffix
            } else {
                replacement = prefix + selected + suffix
            }

            editor.insertText(replacement, replacementRange: range)

            if selected.isEmpty {
                let newPos = range.location + prefix.count
                editor.setSelectedRange(NSRange(location: newPos, length: 0))
            }
        }
    }

    func insertAtLineStart(_ prefix: String) {
        withFieldEditor { editor in
            let range = editor.selectedRange()
            let text = editor.string as NSString
            let lineRange = text.lineRange(for: range)
            let lineStart = lineRange.location

            editor.insertText(prefix, replacementRange: NSRange(location: lineStart, length: 0))
            editor.setSelectedRange(NSRange(
                location: range.location + prefix.count,
                length: range.length
            ))
        }
    }

    func insertText(_ text: String) {
        withFieldEditor { editor in
            let range = editor.selectedRange()
            editor.insertText(text, replacementRange: range)
        }
    }

    func insertBlock(_ block: String) {
        withFieldEditor { editor in
            let range = editor.selectedRange()
            let text = editor.string as NSString

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
            editor.insertText(insertion, replacementRange: range)
        }
    }

    // MARK: - Selection for MCP

    func getSelection() -> (text: String, startLine: Int, endLine: Int)? {
        guard let textField else { return nil }

        // Try active field editor first, fall back to savedRange
        let range: NSRange
        let fullText: String

        if let editor = textField.currentEditor() as? NSTextView {
            range = editor.selectedRange()
            fullText = editor.string
        } else if let saved = savedRange {
            range = saved
            fullText = textField.stringValue
        } else {
            return nil
        }

        guard range.length > 0 else { return nil }

        let nsText = fullText as NSString
        guard range.location + range.length <= nsText.length else { return nil }

        let selectedText = nsText.substring(with: range)
        let startLine = lineNumber(at: range.location, in: fullText)
        let endLine = lineNumber(at: range.location + range.length - 1, in: fullText)

        return (text: selectedText, startLine: startLine, endLine: endLine)
    }

    func getCaretLine() -> Int {
        let location: Int
        if let textField, let editor = textField.currentEditor() as? NSTextView {
            location = editor.selectedRange().location
            return lineNumber(at: location, in: editor.string)
        } else if let saved = savedRange {
            location = saved.location
            return lineNumber(at: location, in: textField?.stringValue ?? "")
        }
        return 1
    }

    private func lineNumber(at offset: Int, in text: String) -> Int {
        let nsText = text as NSString
        let safeOffset = min(offset, nsText.length)
        let prefix = nsText.substring(to: safeOffset)
        return prefix.components(separatedBy: "\n").count
    }
}
