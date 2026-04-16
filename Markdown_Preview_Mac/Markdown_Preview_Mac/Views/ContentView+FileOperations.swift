import SwiftUI
import UniformTypeIdentifiers

// MARK: - File Operations

extension ContentView {

    func handleOpen() {
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

    func handleSave() {
        syncTextFromEditor()

        guard let url = doc.currentFileURL else {
            handleSaveAs()
            return
        }

        fileWatcher.markAppSaving()
        do {
            try doc.text.write(to: url, atomically: true, encoding: .utf8)
            diffTracker.setBaseline(doc.text)
            refreshOverlays()
        } catch {
            exportError = "Failed to save: \(error.localizedDescription)"
            showExportError = true
        }
        fileWatcher.markFinished()
    }

    func handleSaveAs() {
        syncTextFromEditor()

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.markdownText]
        panel.nameFieldStringValue = doc.currentFileURL?.lastPathComponent ?? "untitled.md"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        fileWatcher.markAppSaving()
        do {
            try doc.text.write(to: url, atomically: true, encoding: .utf8)
            doc.currentFileURL = url
            diffTracker.setBaseline(doc.text)
            refreshOverlays()
        } catch {
            exportError = "Failed to save: \(error.localizedDescription)"
            showExportError = true
        }
        fileWatcher.markFinished()
    }
}

// MARK: - Export

extension ContentView {

    func handlePDFExport() async {
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

    func handleHTMLExport() async {
        syncTextFromEditor()

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

    var baseFilename: String {
        if let url = doc.currentFileURL {
            return url.deletingPathExtension().lastPathComponent
        }
        return "document"
    }
}
