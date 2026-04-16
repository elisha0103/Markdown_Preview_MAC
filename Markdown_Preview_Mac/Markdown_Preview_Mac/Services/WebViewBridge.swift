import WebKit

@Observable
class WebViewBridge {
    weak var webView: WKWebView?
    var headings: [HeadingItem] = []
    @ObservationIgnored var afterContentUpdate: (() -> Void)?

    // MARK: - WKWebView 캐싱 (모드 전환 시 재사용)

    /// 강한 참조로 WKWebView 유지 — SwiftUI가 View를 재생성해도 WebView 재사용
    @ObservationIgnored var cachedWebView: WKWebView?

    /// Coordinator 재생성에도 유지되는 마지막 렌더링 마크다운
    @ObservationIgnored var lastRenderedMarkdown: String?

    func exportPDF() async throws -> Data {
        guard let webView else {
            throw ExportError.webViewUnavailable
        }
        let configuration = WKPDFConfiguration()
        return try await webView.pdf(configuration: configuration)
    }

    func exportHTML() async throws -> String {
        guard let webView else {
            throw ExportError.webViewUnavailable
        }
        let html = try await webView.callAsyncJavaScript(
            "return document.documentElement.outerHTML;",
            contentWorld: .page
        ) as? String ?? ""
        return html
    }

    func scrollPreviewTo(headingId: String) {
        guard let webView else { return }
        webView.evaluateJavaScript(
            "document.getElementById('\(headingId)')?.scrollIntoView({behavior:'smooth',block:'start'})"
        )
    }

    func syncPreviewScroll(ratio: Double) {
        guard let webView else { return }
        webView.evaluateJavaScript(
            "window.scrollTo({top: document.documentElement.scrollHeight * \(ratio), behavior: 'auto'})"
        )
    }

    // MARK: - 직접 프리뷰 업데이트 (SwiftUI 우회)

    @ObservationIgnored private var previewTask: Task<Void, Never>?

    /// EditorView에서 직접 호출 — SwiftUI body 재평가 없이 프리뷰 업데이트
    func schedulePreviewUpdate(_ markdown: String) {
        guard markdown != lastRenderedMarkdown else { return }
        previewTask?.cancel()
        previewTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            guard let webView else { return }
            do {
                let result = try await webView.callAsyncJavaScript(
                    "await updateContent(markdown)",
                    arguments: ["markdown": markdown],
                    contentWorld: .page
                )
                lastRenderedMarkdown = markdown
                print("[Preview] Direct update succeeded: \(String(describing: result))")
                afterContentUpdate?()
            } catch {
                print("[Preview] Direct update FAILED: \(error)")
            }
        }
    }

    // MARK: - Diff & Annotation Overlays

    func updateDiffHighlights(_ changes: [[String: Any]]) {
        guard let webView else { return }
        guard let data = try? JSONSerialization.data(withJSONObject: changes),
              let json = String(data: data, encoding: .utf8)
        else { return }
        webView.evaluateJavaScript("updateDiffHighlights(\(json))")
    }

    func updateAnnotations(_ annotations: [[String: Any]]) {
        guard let webView else { return }
        guard let data = try? JSONSerialization.data(withJSONObject: annotations),
              let json = String(data: data, encoding: .utf8)
        else { return }
        webView.evaluateJavaScript("updateAnnotations(\(json))")
    }
}

enum ExportError: LocalizedError {
    case webViewUnavailable

    var errorDescription: String? {
        switch self {
        case .webViewUnavailable:
            return "Preview is not available for export."
        }
    }
}
