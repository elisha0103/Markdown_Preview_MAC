import AppKit
import SwiftUI

/// NSTextView-based editor with TextKit 1 for incremental layout performance.
/// Unlike NSTextField, NSTextView only lays out visible text — essential for large documents.
struct EditorView: NSViewRepresentable {
    @Binding var text: String
    var editorProxy: EditorTextProxy?
    var onScrollChanged: ((Double) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        // 캐시된 스크롤 뷰가 있으면 재사용 (모드 전환 시)
        if let cached = editorProxy?.cachedScrollView,
           let textView = cached.documentView as? NSTextView {
            textView.delegate = context.coordinator
            context.coordinator.textView = textView
            context.coordinator.scrollView = cached
            editorProxy?.textView = textView

            // 새 Coordinator에 대해 알림 재등록
            registerObservers(scrollView: cached, textView: textView, coordinator: context.coordinator)

            print("[Editor] Reusing cached NSScrollView")
            return cached
        }

        // TextKit 1으로 NSTextView 생성 (TextKit 2 버그 회피)
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        layoutManager.allowsNonContiguousLayout = true  // 보이는 영역만 레이아웃
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer()
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        layoutManager.addTextContainer(textContainer)

        let textView = NSTextView(frame: .zero, textContainer: textContainer)
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = .textBackgroundColor
        textView.drawsBackground = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.textContainerInset = NSSize(width: 8, height: 12)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 0)

        textView.string = text
        textView.delegate = context.coordinator

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.documentView = textView

        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        editorProxy?.textView = textView
        editorProxy?.cachedScrollView = scrollView

        registerObservers(scrollView: scrollView, textView: textView, coordinator: context.coordinator)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        // 유저 타이핑 중에는 건드리지 않음 (바인딩이 디바운스 됨)
        guard !context.coordinator.isUserTyping else { return }
        guard !context.coordinator.isUpdating else { return }
        if textView.string != text {
            textView.string = text
        }
    }

    private func registerObservers(scrollView: NSScrollView, textView: NSTextView, coordinator: Coordinator) {
        // Scroll sync
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            coordinator,
            selector: #selector(Coordinator.boundsDidChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )

        // Selection changes
        NotificationCenter.default.addObserver(
            coordinator,
            selector: #selector(Coordinator.selectionDidChange(_:)),
            name: NSTextView.didChangeSelectionNotification,
            object: textView
        )
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorView
        var isUpdating = false
        var isUserTyping = false
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
        private var textUpdateTask: Task<Void, Never>?

        init(parent: EditorView) {
            self.parent = parent
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
            textUpdateTask?.cancel()
        }

        // MARK: - Text Change

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            isUserTyping = true
            let currentText = textView.string

            // 1) 프리뷰 직접 업데이트 (SwiftUI 우회 — 150ms 디바운스는 WebViewBridge에서)
            parent.editorProxy?.onTextChanged?(currentText)

            // 2) SwiftUI 바인딩은 디바운스 (body 재평가 최소화)
            textUpdateTask?.cancel()
            textUpdateTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                self.isUpdating = true
                self.parent.text = self.textView?.string ?? ""
                self.isUpdating = false
                self.isUserTyping = false
            }
        }

        // MARK: - Selection

        @objc func selectionDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  textView === self.textView
            else { return }
            parent.editorProxy?.savedRange = textView.selectedRange()
        }

        // MARK: - Scroll Sync

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
