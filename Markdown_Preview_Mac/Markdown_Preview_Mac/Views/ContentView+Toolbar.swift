import SwiftUI

// MARK: - Toolbar

extension ContentView {

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
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
                }
                showAnnotationPopover = true
            } label: {
                Image(systemName: "note.text.badge.plus")
            }
            .help("주석 추가 (⌥N)")
            .keyboardShortcut("n", modifiers: .option)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showAnnotationInspector.toggle()
                }
            } label: {
                Image(systemName: "list.bullet.rectangle.portrait")
            }
            .help("주석 목록 (⌥A)")
            .keyboardShortcut("a", modifiers: .option)

            Button {
                diffTracker.clearChanges()
                refreshOverlays()
            } label: {
                Image(systemName: "eraser.line.dashed")
            }
            .help("Diff 초기화")

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
}
