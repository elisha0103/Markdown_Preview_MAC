import SwiftUI
import WebKit

struct WebPreviewView: NSViewRepresentable {
    let markdown: String
    let bridge: WebViewBridge

    func makeCoordinator() -> Coordinator {
        Coordinator(bridge: bridge)
    }

    func makeNSView(context: Context) -> WKWebView {
        // 캐시된 WebView가 있으면 재사용 (모드 전환 시)
        if let cached = bridge.cachedWebView {
            // Coordinator 참조 업데이트
            cached.navigationDelegate = context.coordinator

            // 스크립트 메시지 핸들러를 새 Coordinator로 교체
            let userController = cached.configuration.userContentController
            userController.removeAllScriptMessageHandlers()
            userController.add(context.coordinator, name: "headingsHandler")
            userController.add(context.coordinator, name: "scrollHandler")

            // 이미 로드된 페이지이므로 바로 사용 가능
            context.coordinator.markAsLoaded()
            bridge.webView = cached
            print("[Preview] Reusing cached WKWebView")
            return cached
        }

        // 새 WebView 생성
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let userController = WKUserContentController()
        userController.add(context.coordinator, name: "headingsHandler")
        userController.add(context.coordinator, name: "scrollHandler")
        config.userContentController = userController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator

        bridge.webView = webView
        bridge.cachedWebView = webView

        // Load preview.html from bundle
        if let htmlURL = Bundle.main.url(forResource: "preview", withExtension: "html") {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
            print("[Preview] Loading preview.html from: \(htmlURL.path)")
        } else {
            print("[Preview] ERROR: preview.html not found in bundle!")
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

        /// 캐시된 WebView 재사용 시 호출 — 이미 페이지가 로드된 상태로 표시
        func markAsLoaded() {
            isPageLoaded = true
        }

        nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            MainActor.assumeIsolated {
                print("[Preview] Page loaded successfully")
                isPageLoaded = true
                if let pending = pendingMarkdown {
                    performUpdate(markdown: pending, in: webView)
                    pendingMarkdown = nil
                }
            }
        }

        nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
            MainActor.assumeIsolated {
                print("[Preview] Navigation failed: \(error.localizedDescription)")
            }
        }

        nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
            MainActor.assumeIsolated {
                print("[Preview] Provisional navigation failed: \(error.localizedDescription)")
            }
        }

        func scheduleUpdate(markdown: String) {
            guard isPageLoaded else {
                pendingMarkdown = markdown
                return
            }

            // Bridge에 저장된 마지막 렌더링 내용과 비교 (리사이즈/모드 전환 시 불필요한 재렌더링 방지)
            guard markdown != bridge.lastRenderedMarkdown else { return }

            debounceTask?.cancel()
            debounceTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                guard let webView = bridge.webView else { return }
                performUpdate(markdown: markdown, in: webView)
            }
        }

        private func performUpdate(markdown: String, in webView: WKWebView) {
            Task { @MainActor in
                do {
                    let result = try await webView.callAsyncJavaScript(
                        "await updateContent(markdown)",
                        arguments: ["markdown": markdown],
                        contentWorld: .page
                    )
                    bridge.lastRenderedMarkdown = markdown
                    print("[Preview] updateContent succeeded: \(String(describing: result))")

                    // Re-apply diff highlights and annotations after content render
                    bridge.afterContentUpdate?()
                } catch {
                    print("[Preview] updateContent FAILED: \(error)")
                }
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
