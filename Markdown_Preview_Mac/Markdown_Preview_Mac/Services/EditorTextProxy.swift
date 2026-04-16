import AppKit

@Observable
class EditorTextProxy {
    weak var textView: NSTextView?
    var savedRange: NSRange?

    // MARK: - View 캐싱 (모드 전환 시 재사용)
    @ObservationIgnored var cachedScrollView: NSScrollView?

    // MARK: - 직접 프리뷰 업데이트 (SwiftUI 우회)
    @ObservationIgnored var onTextChanged: ((String) -> Void)?

    /// Restores focus to the text view if needed, then runs the action.
    private func withTextView(_ action: (NSTextView) -> Void) {
        guard let textView else { return }

        if textView.window?.firstResponder === textView {
            action(textView)
            return
        }

        // Restore focus
        textView.window?.makeFirstResponder(textView)

        // Restore the saved cursor/selection position
        if let range = savedRange,
           range.location + range.length <= (textView.string as NSString).length {
            textView.setSelectedRange(range)
        }

        action(textView)
    }

    func wrapSelection(prefix: String, suffix: String) {
        withTextView { editor in
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
        withTextView { editor in
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
        withTextView { editor in
            let range = editor.selectedRange()
            editor.insertText(text, replacementRange: range)
        }
    }

    func insertBlock(_ block: String) {
        withTextView { editor in
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
        guard let textView else { return nil }

        let range: NSRange
        let fullText: String

        if textView.window?.firstResponder === textView {
            range = textView.selectedRange()
            fullText = textView.string
        } else if let saved = savedRange {
            range = saved
            fullText = textView.string
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
        guard let textView else { return 1 }
        let location: Int
        if textView.window?.firstResponder === textView {
            location = textView.selectedRange().location
        } else if let saved = savedRange {
            location = saved.location
        } else {
            return 1
        }
        return lineNumber(at: location, in: textView.string)
    }

    /// 에디터에서 현재 최신 텍스트를 가져옴 (저장/MCP용)
    func currentText() -> String? {
        textView?.string
    }

    private func lineNumber(at offset: Int, in text: String) -> Int {
        let nsText = text as NSString
        let safeOffset = min(offset, nsText.length)
        let prefix = nsText.substring(to: safeOffset)
        return prefix.components(separatedBy: "\n").count
    }
}
