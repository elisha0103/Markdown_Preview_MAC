import WebKit

@Observable
class WebViewBridge {
    weak var webView: WKWebView?
    var headings: [HeadingItem] = []

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
