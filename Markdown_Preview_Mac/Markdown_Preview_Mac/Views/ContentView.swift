import SwiftUI
import UniformTypeIdentifiers

@Observable
class DocumentState {
    var text = "# Hello\n\nType **markdown** here..."
    var currentFileURL: URL?
    var isExternalUpdate = false
}

struct AnnotationSelection {
    let text: String
    let startLine: Int
    let endLine: Int
}

struct ContentView: View {
    @State private var doc = DocumentState()
    @State private var previewMode: PreviewMode = .split
    @State private var webViewBridge = WebViewBridge()
    @State private var editorProxy = EditorTextProxy()
    @State private var showTOC = false
    @State private var scrollSyncEnabled = true
    @State private var exportError: String?
    @State private var showExportError = false

    // Claude Code 협업
    @State private var fileWatcher = FileWatcher()
    @State private var mcpBridge = MCPBridge()
    @State private var diffTracker = DiffTracker()
    @State private var annotationStore = AnnotationStore()
    @State private var showAnnotationPopover = false
    @State private var pendingAnnotation: AnnotationSelection?

    var body: some View {
        @Bindable var doc = doc

        HStack(spacing: 0) {
            if showTOC {
                TOCSidebarView(
                    headings: webViewBridge.headings,
                    onHeadingTap: { heading in
                        webViewBridge.scrollPreviewTo(headingId: heading.id)
                    }
                )
                Divider()
            }

            HSplitView {
                if previewMode == .split {
                    VStack(spacing: 0) {
                        MarkdownToolbar(proxy: editorProxy)
                        Divider()
                        EditorView(
                            text: $doc.text,
                            editorProxy: editorProxy,
                            onScrollChanged: { ratio in
                                guard scrollSyncEnabled else { return }
                                webViewBridge.syncPreviewScroll(ratio: ratio)
                            }
                        )
                    }
                    .frame(minWidth: 300)
                }

                WebPreviewView(
                    markdown: self.doc.text,
                    bridge: webViewBridge
                )
                .frame(minWidth: 300)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .focusedSceneValue(\.webViewBridge, webViewBridge)
        .navigationTitle(windowTitle)
        .toolbar { toolbarContent }
        .alert("Export Failed", isPresented: $showExportError) {
            Button("OK") {}
        } message: {
            Text(exportError ?? "An unknown error occurred.")
        }
        .sheet(isPresented: $showAnnotationPopover, onDismiss: {
            pendingAnnotation = nil
        }) {
            annotationPopoverContent
        }
        .onCommand(#selector(NSDocument.save(_:))) { handleSave() }
        .onCommand(#selector(AppCommands.saveAs(_:))) { handleSaveAs() }
        .onCommand(#selector(AppCommands.openDocument(_:))) { handleOpen() }
        .task { setupIntegration() }
        .onChange(of: self.doc.text) { _, newText in
            handleTextChange(newText)
        }
        .onChange(of: self.doc.currentFileURL) { _, _ in
            fileWatcher.fileURL = self.doc.currentFileURL
            diffTracker.setBaseline(self.doc.text)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                if mcpBridge.isRunning {
                    mcpBridge.stop()
                } else {
                    mcpBridge.start()
                }
            } label: {
                Image(systemName: mcpBridge.isRunning
                      ? "antenna.radiowaves.left.and.right"
                      : "antenna.radiowaves.left.and.right.slash")
                    .foregroundStyle(
                        mcpBridge.connectedClients > 0 ? .green :
                        mcpBridge.isRunning ? .orange : .secondary
                    )
            }
            .help(
                mcpBridge.connectedClients > 0
                    ? "Claude Code 연결됨 (\(mcpBridge.connectedClients)) — 클릭하여 끄기"
                    : mcpBridge.isRunning
                        ? "MCP 대기 중 (port 52698) — 클릭하여 끄기"
                        : "MCP 꺼짐 — 클릭하여 켜기"
            )

            Button {
                if let sel = editorProxy.getSelection() {
                    pendingAnnotation = AnnotationSelection(
                        text: sel.text,
                        startLine: sel.startLine,
                        endLine: sel.endLine
                    )
                    showAnnotationPopover = true
                }
            } label: {
                Image(systemName: "note.text.badge.plus")
            }
            .help("주석 추가 (⌘M)")
            .keyboardShortcut("m", modifiers: .command)

            Button {
                diffTracker.clearChanges()
                refreshOverlays()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .help("변경 하이라이트 초기화")

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showTOC.toggle()
                }
            } label: {
                Image(systemName: "list.bullet.indent")
            }
            .help("Toggle Table of Contents (⇧⌘T)")
            .keyboardShortcut("t", modifiers: [.command, .shift])

            Button {
                scrollSyncEnabled.toggle()
            } label: {
                Image(systemName: scrollSyncEnabled
                    ? "link" : "link.badge.plus")
            }
            .help(scrollSyncEnabled
                ? "Disable Scroll Sync" : "Enable Scroll Sync")

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    previewMode = previewMode == .split
                        ? .previewOnly : .split
                }
            } label: {
                Image(systemName: previewMode == .split
                    ? "eye" : "rectangle.split.2x1")
            }
            .help(previewMode == .split
                ? "Preview Only (⇧⌘P)" : "Show Editor (⇧⌘P)")
            .keyboardShortcut("p", modifiers: [.command, .shift])

            Button {
                Task { await handlePDFExport() }
            } label: {
                Image(systemName: "arrow.down.doc")
            }
            .help("Export as PDF (⇧⌘E)")
            .keyboardShortcut("e", modifiers: [.command, .shift])

            Button {
                Task { await handleHTMLExport() }
            } label: {
                Image(systemName: "globe")
            }
            .help("Export as HTML (⇧⌘H)")
            .keyboardShortcut("h", modifiers: [.command, .shift])
        }
    }

    // MARK: - Annotation Sheet

    @ViewBuilder
    private var annotationPopoverContent: some View {
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

    // MARK: - Claude Code Integration

    private func setupIntegration() {
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

    private func handleTextChange(_ newText: String) {
        if doc.isExternalUpdate {
            doc.isExternalUpdate = false
            return
        }
        diffTracker.recordChange(newContent: newText, author: .user)
        refreshOverlays()
    }

    private func refreshOverlays() {
        webViewBridge.updateDiffHighlights(diffTracker.changeDicts(by: nil))
        webViewBridge.updateAnnotations(annotationStore.toDicts())
    }

    private var windowTitle: String {
        if let url = doc.currentFileURL {
            return url.lastPathComponent
        }
        return "Untitled"
    }

    // MARK: - File Operations

    private func handleOpen() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.markdownText, .plainText]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            doc.text = try String(contentsOf: url, encoding: .utf8)
            doc.currentFileURL = url
        } catch {
            exportError = "Failed to open file: \(error.localizedDescription)"
            showExportError = true
        }
    }

    private func handleSave() {
        guard let url = doc.currentFileURL else {
            handleSaveAs()
            return
        }

        fileWatcher.markAppSaving()
        do {
            try doc.text.write(to: url, atomically: true, encoding: .utf8)
            diffTracker.setBaseline(doc.text)
        } catch {
            exportError = "Failed to save: \(error.localizedDescription)"
            showExportError = true
        }
        fileWatcher.markFinished()
    }

    private func handleSaveAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.markdownText]
        panel.nameFieldStringValue = doc.currentFileURL?.lastPathComponent ?? "untitled.md"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        fileWatcher.markAppSaving()
        do {
            try doc.text.write(to: url, atomically: true, encoding: .utf8)
            doc.currentFileURL = url
            diffTracker.setBaseline(doc.text)
        } catch {
            exportError = "Failed to save: \(error.localizedDescription)"
            showExportError = true
        }
        fileWatcher.markFinished()
    }

    // MARK: - Export

    private func handlePDFExport() async {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = baseFilename + ".pdf"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let pdfData = try await webViewBridge.exportPDF()
            try pdfData.write(to: url)
        } catch {
            exportError = error.localizedDescription
            showExportError = true
        }
    }

    private func handleHTMLExport() async {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = baseFilename + ".html"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let html = HTMLExporter.exportStandaloneHTML(markdown: doc.text)
            try html.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            exportError = error.localizedDescription
            showExportError = true
        }
    }

    private var baseFilename: String {
        if let url = doc.currentFileURL {
            return url.deletingPathExtension().lastPathComponent
        }
        return "document"
    }
}

// Helper for onCommand selectors
@objc private protocol AppCommands {
    func saveAs(_ sender: Any?)
    func openDocument(_ sender: Any?)
}
