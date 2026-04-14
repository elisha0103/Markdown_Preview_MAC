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

        fileWatcher.onExternalChange = { newContent in
            doc.isExternalUpdate = true
            doc.text = newContent
            diffTracker.recordChange(newContent: newContent, author: .claude)
            webViewBridge.updateDiffHighlights(diffTracker.changeDicts(by: nil))
            webViewBridge.updateAnnotations(annotationStore.toDicts())
        }

        mcpBridge.onGetContent = { doc.text }
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
            let html = HTMLExporter.exportStandaloneHTML(markdown: doc.text)
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
        diffTracker.recordChange(newContent: newText, author: .user)
        refreshOverlays()
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
        }
    }
}
