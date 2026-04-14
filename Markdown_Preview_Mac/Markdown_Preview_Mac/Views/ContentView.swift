import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var text = "# Hello\n\nType **markdown** here..."
    @State private var currentFileURL: URL?
    @State private var previewMode: PreviewMode = .split
    @State private var webViewBridge = WebViewBridge()
    @State private var editorProxy = EditorTextProxy()
    @State private var showTOC = false
    @State private var scrollSyncEnabled = true
    @State private var exportError: String?
    @State private var showExportError = false

    var body: some View {
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
                            text: $text,
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
                    markdown: text,
                    bridge: webViewBridge
                )
                .frame(minWidth: 300)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .focusedSceneValue(\.webViewBridge, webViewBridge)
        .navigationTitle(windowTitle)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
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
        .alert("Export Failed", isPresented: $showExportError) {
            Button("OK") {}
        } message: {
            Text(exportError ?? "An unknown error occurred.")
        }
        .onCommand(#selector(NSDocument.save(_:))) { handleSave() }
        .onCommand(#selector(AppCommands.saveAs(_:))) { handleSaveAs() }
        .onCommand(#selector(AppCommands.openDocument(_:))) { handleOpen() }
    }

    private var windowTitle: String {
        if let url = currentFileURL {
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
            text = try String(contentsOf: url, encoding: .utf8)
            currentFileURL = url
        } catch {
            exportError = "Failed to open file: \(error.localizedDescription)"
            showExportError = true
        }
    }

    private func handleSave() {
        guard let url = currentFileURL else {
            handleSaveAs()
            return
        }

        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            exportError = "Failed to save: \(error.localizedDescription)"
            showExportError = true
        }
    }

    private func handleSaveAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.markdownText]
        panel.nameFieldStringValue = currentFileURL?.lastPathComponent ?? "untitled.md"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            currentFileURL = url
        } catch {
            exportError = "Failed to save: \(error.localizedDescription)"
            showExportError = true
        }
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
            let html = HTMLExporter.exportStandaloneHTML(markdown: text)
            try html.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            exportError = error.localizedDescription
            showExportError = true
        }
    }

    private var baseFilename: String {
        if let url = currentFileURL {
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
