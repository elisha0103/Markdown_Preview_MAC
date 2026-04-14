import AppKit
import SwiftUI

/// NSTextField-based editor (NSTextView has a rendering bug on macOS 26).
/// Uses `control(_:textView:doCommandBy:)` to make Enter insert newlines.
struct EditorView: NSViewRepresentable {
    @Binding var text: String
    var editorProxy: EditorTextProxy?
    var onScrollChanged: ((Double) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor

        let textField = NSTextField(wrappingLabelWithString: "")
        textField.isEditable = true
        textField.isSelectable = true
        textField.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textField.textColor = .labelColor
        textField.backgroundColor = .textBackgroundColor
        textField.drawsBackground = true
        textField.isBezeled = false
        textField.focusRingType = .none
        textField.maximumNumberOfLines = 0
        textField.lineBreakMode = .byWordWrapping
        textField.cell?.wraps = true
        textField.cell?.isScrollable = false
        textField.usesSingleLineMode = false
        textField.stringValue = text
        textField.delegate = context.coordinator

        scrollView.documentView = textField
        context.coordinator.textField = textField
        context.coordinator.scrollView = scrollView

        // Connect the proxy to the text field
        editorProxy?.textField = textField

        // Auto Layout: pin textField edges to scroll view's clip view
        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textField.topAnchor.constraint(
                equalTo: scrollView.contentView.topAnchor, constant: 12),
            textField.leadingAnchor.constraint(
                equalTo: scrollView.contentView.leadingAnchor, constant: 12),
            textField.trailingAnchor.constraint(
                equalTo: scrollView.contentView.trailingAnchor, constant: -8),
        ])

        // Scroll sync
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.boundsDidChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )

        // Track selection changes in the field editor
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.selectionDidChange(_:)),
            name: NSTextView.didChangeSelectionNotification,
            object: nil
        )

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textField = nsView.documentView as? NSTextField else { return }
        if textField.stringValue != text && !context.coordinator.isUpdating {
            textField.stringValue = text
        }
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: EditorView
        var isUpdating = false
        weak var textField: NSTextField?
        weak var scrollView: NSScrollView?

        init(parent: EditorView) {
            self.parent = parent
        }

        // Track cursor/selection position for toolbar operations
        @objc func selectionDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView,
                  let textField,
                  editor == textField.currentEditor()
            else { return }
            parent.editorProxy?.savedRange = editor.selectedRange()
        }

        // Make Enter insert a newline instead of ending editing
        nonisolated func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            MainActor.assumeIsolated {
                if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                    textView.insertNewlineIgnoringFieldEditor(nil)
                    return true
                }
                if commandSelector == #selector(NSResponder.insertTab(_:)) {
                    textView.insertText("    ", replacementRange: textView.selectedRange())
                    return true
                }
                return false
            }
        }

        nonisolated func controlTextDidChange(_ obj: Notification) {
            MainActor.assumeIsolated {
                guard let textField = obj.object as? NSTextField else { return }
                isUpdating = true
                parent.text = textField.stringValue
                isUpdating = false
            }
        }

        @objc func boundsDidChange(_ notification: Notification) {
            guard let scrollView,
                  let documentView = scrollView.documentView
            else { return }
            let contentHeight = documentView.frame.height - scrollView.contentView.bounds.height
            guard contentHeight > 0 else { return }
            let ratio = scrollView.contentView.bounds.origin.y / contentHeight
            parent.onScrollChanged?(min(max(ratio, 0), 1))
        }
    }
}
