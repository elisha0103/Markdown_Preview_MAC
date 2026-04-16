import SwiftUI

// MARK: - Claude Code Integration

extension ContentView {

    func setupIntegration() {
        let doc = self.doc
        let webViewBridge = self.webViewBridge
        let diffTracker = self.diffTracker
        let annotationStore = self.annotationStore
        let editorProxy = self.editorProxy
        let mcpBridge = self.mcpBridge
        let fileWatcher = self.fileWatcher

        mcpBridge.start()

        // 에디터 → 프리뷰 + diff 직접 경로 (SwiftUI 바인딩 우회)
        editorProxy.onTextChanged = { [self] newText in
            webViewBridge.schedulePreviewUpdate(newText)

            // Diff 계산도 여기서 직접 디바운스 (onChange 체인에 의존하지 않음)
            diffDebounceTask?.cancel()
            diffDebounceTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                diffTracker.recordChange(newContent: newText, author: .user)
                refreshOverlays()
            }
        }

        fileWatcher.onExternalChange = { newContent in
            doc.isExternalUpdate = true
            doc.text = newContent
            diffTracker.recordChange(newContent: newContent, author: .claude)
            webViewBridge.updateDiffHighlights(diffTracker.changeDicts(by: nil))
            webViewBridge.updateAnnotations(annotationStore.toDicts())
        }

        mcpBridge.onGetContent = {
            // 에디터의 최신 텍스트를 반환 (바인딩이 디바운스되어 doc.text가 stale할 수 있음)
            editorProxy.currentText() ?? doc.text
        }
        mcpBridge.onSetContent = { newContent in
            doc.isExternalUpdate = true
            doc.text = newContent
            diffTracker.recordChange(newContent: newContent, author: .claude)
            webViewBridge.updateDiffHighlights(diffTracker.changeDicts(by: nil))
            webViewBridge.updateAnnotations(annotationStore.toDicts())
        }
        mcpBridge.onGetSelection = { editorProxy.getSelection() }
        mcpBridge.onGetFileInfo = {
            (path: doc.currentFileURL?.path, name: doc.currentFileURL?.lastPathComponent ?? "Untitled")
        }
        mcpBridge.onGetHeadings = {
            webViewBridge.headings.map { h in
                ["id": h.id, "level": h.level, "title": h.title] as [String: Any]
            }
        }
        mcpBridge.onGetChanges = { author in
            diffTracker.changeDicts(by: author)
        }
        mcpBridge.onGetAnnotations = {
            annotationStore.toDicts()
        }
        mcpBridge.onExportPDF = { path in
            let pdfData = try await webViewBridge.exportPDF()
            try pdfData.write(to: URL(fileURLWithPath: path))
        }
        mcpBridge.onExportHTML = { path in
            let text = editorProxy.currentText() ?? doc.text
            let html = HTMLExporter.exportStandaloneHTML(markdown: text)
            try html.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
        }

        webViewBridge.afterContentUpdate = {
            webViewBridge.updateDiffHighlights(diffTracker.changeDicts(by: nil))
            webViewBridge.updateAnnotations(annotationStore.toDicts())
        }
    }

    func handleTextChange(_ newText: String) {
        if doc.isExternalUpdate {
            doc.isExternalUpdate = false
            return
        }
        // Diff는 editorProxy.onTextChanged에서 직접 처리 (바인딩 디바운스에 의존하지 않음)
    }

    /// 에디터의 최신 텍스트를 doc.text에 동기화 (저장/내보내기 전 호출)
    func syncTextFromEditor() {
        if let current = editorProxy.currentText() {
            doc.text = current
        }
    }

    func refreshOverlays() {
        webViewBridge.updateDiffHighlights(diffTracker.changeDicts(by: nil))
        webViewBridge.updateAnnotations(annotationStore.toDicts())
    }

    var windowTitle: String {
        if let url = doc.currentFileURL {
            return url.lastPathComponent
        }
        return "Untitled"
    }

    // MARK: - Annotation Sheet

    @ViewBuilder
    var annotationPopoverContent: some View {
        if let sel = pendingAnnotation {
            AnnotationPopover(
                selectedText: sel.text,
                startLine: sel.startLine,
                endLine: sel.endLine,
                onSubmit: { note in
                    annotationStore.add(
                        note: note,
                        selectedText: sel.text,
                        startLine: sel.startLine,
                        endLine: sel.endLine
                    )
                    refreshOverlays()
                }
            )
        } else {
            VStack(spacing: 12) {
                Text("텍스트를 먼저 선택하세요")
                    .foregroundStyle(.secondary)
                Button("닫기") {
                    showAnnotationPopover = false
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            .frame(width: 240)
        }
    }
}
