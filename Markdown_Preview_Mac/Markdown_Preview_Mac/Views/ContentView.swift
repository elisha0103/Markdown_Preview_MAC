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
    @State var doc = DocumentState()
    @State var previewMode: PreviewMode = .split
    @State var webViewBridge = WebViewBridge()
    @State var editorProxy = EditorTextProxy()
    @State var showTOC = false
    @State var scrollSyncEnabled = true
    @State var exportError: String?
    @State var showExportError = false

    // Claude Code 협업
    @State var fileWatcher = FileWatcher()
    @State var mcpBridge = MCPBridge()
    @State var diffTracker = DiffTracker()
    @State var annotationStore = AnnotationStore()
    @State var showAnnotationPopover = false
    @State var pendingAnnotation: AnnotationSelection?

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
        .focusedSceneValue(\.fileActions, FileActions(
            open: { handleOpen() },
            save: { handleSave() },
            saveAs: { handleSaveAs() }
        ))
        .task { setupIntegration() }
        .onChange(of: self.doc.text) { _, newText in
            handleTextChange(newText)
        }
        .onChange(of: self.doc.currentFileURL) { _, _ in
            fileWatcher.fileURL = self.doc.currentFileURL
            diffTracker.setBaseline(self.doc.text)
        }
    }
}

