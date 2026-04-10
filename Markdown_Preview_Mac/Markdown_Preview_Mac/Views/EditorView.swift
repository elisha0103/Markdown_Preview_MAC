import AppKit
import SwiftUI

struct EditorView: NSViewRepresentable {
    @Binding var text: String
    var editorProxy: EditorTextProxy?
    var onScrollChanged: ((Double) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let monoFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)

        // Explicitly build TextKit 1 stack
        let textStorage = NSTextStorage(
            string: text,
            attributes: [
                .font: monoFont,
                .foregroundColor: NSColor.textColor
            ]
        )
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer()
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        textContainer.size = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )
        layoutManager.addTextContainer(textContainer)

        let textView = NSTextView(frame: .zero, textContainer: textContainer)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.font = monoFont
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.insertionPointColor = .textColor
        textView.textContainerInset = NSSize(width: 8, height: 12)
        textView.typingAttributes = [
            .font: monoFont,
            .foregroundColor: NSColor.textColor
        ]
        textView.delegate = context.coordinator

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let rulerView = LineNumberRulerView(textView: textView)
        scrollView.hasVerticalRuler = true
        scrollView.verticalRulerView = rulerView
        scrollView.rulersVisible = true

        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        editorProxy?.textView = textView

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.boundsDidChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        scrollView.contentView.postsBoundsChangedNotifications = true

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text && !context.coordinator.isUpdatingFromTextView {
            let monoFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            let selectedRanges = textView.selectedRanges
            textView.textStorage?.beginEditing()
            textView.textStorage?.replaceCharacters(
                in: NSRange(location: 0, length: textView.textStorage?.length ?? 0),
                with: NSAttributedString(
                    string: text,
                    attributes: [
                        .font: monoFont,
                        .foregroundColor: NSColor.textColor
                    ]
                )
            )
            textView.textStorage?.endEditing()
            textView.selectedRanges = selectedRanges
            nsView.verticalRulerView?.needsDisplay = true
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorView
        var isUpdatingFromTextView = false
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?

        init(parent: EditorView) {
            self.parent = parent
        }

        nonisolated func textDidChange(_ notification: Notification) {
            MainActor.assumeIsolated {
                guard let textView = notification.object as? NSTextView else { return }
                isUpdatingFromTextView = true
                parent.text = textView.string
                isUpdatingFromTextView = false
                scrollView?.verticalRulerView?.needsDisplay = true
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

class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?
    private let rulerWidth: CGFloat = 40

    init(textView: NSTextView) {
        self.textView = textView
        super.init(
            scrollView: textView.enclosingScrollView,
            orientation: .verticalRuler
        )
        self.ruleThickness = rulerWidth
        self.clientView = textView

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange(_:)),
            name: NSText.didChangeNotification,
            object: textView
        )
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func textDidChange(_ notification: Notification) {
        needsDisplay = true
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView,
              let layoutManager = textView.layoutManager
        else { return }

        let visibleRect = scrollView?.contentView.bounds ?? .zero
        let textInset = textView.textContainerInset

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        NSColor.textBackgroundColor.setFill()
        rect.fill()

        NSColor.separatorColor.setStroke()
        let borderPath = NSBezierPath()
        borderPath.move(to: NSPoint(x: ruleThickness - 0.5, y: rect.minY))
        borderPath.line(to: NSPoint(x: ruleThickness - 0.5, y: rect.maxY))
        borderPath.lineWidth = 1
        borderPath.stroke()

        let text = textView.string as NSString
        var lineNumber = 1
        var glyphIndex = 0
        let numberOfGlyphs = layoutManager.numberOfGlyphs

        while glyphIndex < numberOfGlyphs {
            var lineRange = NSRange()
            let lineRect = layoutManager.lineFragmentRect(
                forGlyphAt: glyphIndex,
                effectiveRange: &lineRange
            )

            let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
            let isFirstGlyphOfLine = charIndex == 0
                || text.character(at: charIndex - 1) == 0x0A

            if isFirstGlyphOfLine {
                let y = lineRect.origin.y + textInset.height - visibleRect.origin.y
                let lineString = "\(lineNumber)" as NSString
                let stringSize = lineString.size(withAttributes: attrs)
                let drawPoint = NSPoint(
                    x: ruleThickness - stringSize.width - 8,
                    y: y + (lineRect.height - stringSize.height) / 2
                )
                lineString.draw(at: drawPoint, withAttributes: attrs)
                lineNumber += 1
            }

            glyphIndex = NSMaxRange(lineRange)
        }

        if text.length == 0 || (text.length > 0 && text.character(at: text.length - 1) == 0x0A) {
            let y: CGFloat
            if numberOfGlyphs > 0 {
                var lastRange = NSRange()
                let lastRect = layoutManager.lineFragmentRect(
                    forGlyphAt: numberOfGlyphs - 1,
                    effectiveRange: &lastRange
                )
                y = text.length == 0
                    ? textInset.height - visibleRect.origin.y
                    : lastRect.maxY + textInset.height - visibleRect.origin.y
            } else {
                y = textInset.height - visibleRect.origin.y
            }
            let lineString = "\(lineNumber)" as NSString
            let stringSize = lineString.size(withAttributes: attrs)
            lineString.draw(
                at: NSPoint(
                    x: ruleThickness - stringSize.width - 8,
                    y: y
                ),
                withAttributes: attrs
            )
        }
    }
}
