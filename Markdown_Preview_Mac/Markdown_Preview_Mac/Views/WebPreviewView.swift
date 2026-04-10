import SwiftUI
import WebKit

struct WebPreviewView: NSViewRepresentable {
    let markdown: String
    let bridge: WebViewBridge

    func makeCoordinator() -> Coordinator {
        Coordinator(bridge: bridge)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        let userController = WKUserContentController()
        userController.add(context.coordinator, name: "headingsHandler")
        userController.add(context.coordinator, name: "scrollHandler")
        config.userContentController = userController

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 100, height: 100), configuration: config)
        webView.navigationDelegate = context.coordinator

        bridge.webView = webView

        if let htmlURL = Bundle.main.url(forResource: "preview", withExtension: "html") {
            webView.loadFileURL(
                htmlURL,
                allowingReadAccessTo: htmlURL.deletingLastPathComponent()
            )
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.scheduleUpdate(markdown: markdown)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let bridge: WebViewBridge
        private var isPageLoaded = false
        private var pendingMarkdown: String?
        private var debounceTask: Task<Void, Never>?

        init(bridge: WebViewBridge) {
            self.bridge = bridge
        }

        nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            MainActor.assumeIsolated {
                isPageLoaded = true
                if let pending = pendingMarkdown {
                    performUpdate(markdown: pending, in: webView)
                    pendingMarkdown = nil
                }
            }
        }

        func scheduleUpdate(markdown: String) {
            guard isPageLoaded else {
                pendingMarkdown = markdown
                return
            }

            debounceTask?.cancel()
            debounceTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                guard let webView = bridge.webView else { return }
                performUpdate(markdown: markdown, in: webView)
            }
        }

        private func performUpdate(markdown: String, in webView: WKWebView) {
            Task { @MainActor in
                _ = try? await webView.callAsyncJavaScript(
                    "await updateContent(markdown)",
                    arguments: ["markdown": markdown],
                    contentWorld: .page
                )
            }
        }

        nonisolated func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            MainActor.assumeIsolated {
                switch message.name {
                case "headingsHandler":
                    handleHeadings(message.body)
                case "scrollHandler":
                    break
                default:
                    break
                }
            }
        }

        private func handleHeadings(_ body: Any) {
            guard let jsonString = body as? String,
                  let data = jsonString.data(using: .utf8),
                  let items = try? JSONDecoder().decode(
                      [HeadingDTO].self, from: data
                  )
            else { return }

            bridge.headings = items.map {
                HeadingItem(id: $0.id, level: $0.level, title: $0.title)
            }
        }
    }
}

private struct HeadingDTO: Decodable {
    let id: String
    let level: Int
    let title: String
}
