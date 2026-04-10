import SwiftUI

struct WebViewBridgeKey: FocusedValueKey {
    typealias Value = WebViewBridge
}

extension FocusedValues {
    var webViewBridge: WebViewBridge? {
        get { self[WebViewBridgeKey.self] }
        set { self[WebViewBridgeKey.self] = newValue }
    }
}
