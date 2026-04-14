import Foundation
import Network

@Observable
class MCPBridge {
    var isRunning = false
    var connectedClients = 0

    // Command handlers (set by ContentView) — not observed for view updates
    @ObservationIgnored var onGetContent: (() -> String)?
    @ObservationIgnored var onSetContent: ((String) -> Void)?
    @ObservationIgnored var onGetSelection: (() -> (text: String, startLine: Int, endLine: Int)?)?
    @ObservationIgnored var onGetFileInfo: (() -> (path: String?, name: String))?
    @ObservationIgnored var onGetHeadings: (() -> [[String: Any]])?
    @ObservationIgnored var onGetChanges: ((String?) -> [[String: Any]])?
    @ObservationIgnored var onGetAnnotations: (() -> [[String: Any]])?
    @ObservationIgnored var onExportPDF: ((String) async throws -> Void)?
    @ObservationIgnored var onExportHTML: ((String) async throws -> Void)?

    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let port: UInt16 = 52698
    private let queue = DispatchQueue(label: "com.markdownpreview.mcpbridge")

    func start() {
        guard !isRunning else { return }

        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            print("[MCPBridge] Failed to create listener: \(error)")
            return
        }

        listener?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isRunning = true
                    print("[MCPBridge] Listening on localhost:\(self?.port ?? 0)")
                case .failed(let error):
                    print("[MCPBridge] Listener failed: \(error)")
                    self?.isRunning = false
                case .cancelled:
                    self?.isRunning = false
                default:
                    break
                }
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
        }

        listener?.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        for conn in connections {
            conn.cancel()
        }
        connections.removeAll()
        DispatchQueue.main.async {
            self.isRunning = false
            self.connectedClients = 0
        }
    }

    // MARK: - Connection Handling

    private func handleNewConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                DispatchQueue.main.async {
                    self.connections.append(connection)
                    self.connectedClients = self.connections.count
                    print("[MCPBridge] Client connected (\(self.connectedClients) total)")
                }
                self.receiveMessage(on: connection)
            case .failed, .cancelled:
                DispatchQueue.main.async {
                    self.connections.removeAll { $0 === connection }
                    self.connectedClients = self.connections.count
                    print("[MCPBridge] Client disconnected (\(self.connectedClients) total)")
                }
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    private func receiveMessage(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) {
            [weak self] data, _, isComplete, error in
            guard let self else { return }

            if let data, !data.isEmpty {
                self.processData(data, on: connection)
            }

            if isComplete || error != nil {
                connection.cancel()
                return
            }

            self.receiveMessage(on: connection)
        }
    }

    private func processData(_ data: Data, on connection: NWConnection) {
        guard let text = String(data: data, encoding: .utf8) else { return }

        // Handle multiple newline-delimited JSON messages
        let messages = text.components(separatedBy: "\n").filter { !$0.isEmpty }
        for message in messages {
            guard let msgData = message.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: msgData) as? [String: Any],
                  let method = json["method"] as? String,
                  let id = json["id"]
            else { continue }

            let params = json["params"] as? [String: Any] ?? [:]

            DispatchQueue.main.async {
                Task {
                    let result = await self.handleCommand(method: method, params: params)
                    self.sendResponse(id: id, result: result, on: connection)
                }
            }
        }
    }

    // MARK: - Command Dispatch

    private func handleCommand(method: String, params: [String: Any]) async -> Any {
        switch method {
        case "get_editor_content":
            let content = onGetContent?() ?? ""
            let info = onGetFileInfo?()
            return ["content": content, "filePath": info?.path ?? ""]

        case "set_editor_content":
            if let content = params["content"] as? String {
                onSetContent?(content)
                return ["success": true]
            }
            return ["success": false, "error": "Missing 'content' parameter"]

        case "get_selection":
            if let selection = onGetSelection?() {
                return [
                    "text": selection.text,
                    "startLine": selection.startLine,
                    "endLine": selection.endLine
                ]
            }
            return ["text": "", "startLine": 0, "endLine": 0]

        case "get_file_info":
            let info = onGetFileInfo?()
            return ["filePath": info?.path ?? "", "fileName": info?.name ?? "Untitled"]

        case "get_headings":
            return onGetHeadings?() ?? []

        case "get_changes":
            let author = params["author"] as? String
            return onGetChanges?(author) ?? []

        case "get_annotations":
            return onGetAnnotations?() ?? []

        case "export_pdf":
            guard let path = params["outputPath"] as? String else {
                return ["success": false, "error": "Missing 'outputPath'"]
            }
            do {
                try await onExportPDF?(path)
                return ["success": true, "path": path]
            } catch {
                return ["success": false, "error": error.localizedDescription]
            }

        case "export_html":
            guard let path = params["outputPath"] as? String else {
                return ["success": false, "error": "Missing 'outputPath'"]
            }
            do {
                try await onExportHTML?(path)
                return ["success": true, "path": path]
            } catch {
                return ["success": false, "error": error.localizedDescription]
            }

        default:
            return ["error": "Unknown method: \(method)"]
        }
    }

    // MARK: - Response

    private func sendResponse(id: Any, result: Any, on connection: NWConnection) {
        let response: [String: Any] = ["id": id, "result": result]
        guard let data = try? JSONSerialization.data(withJSONObject: response),
              var text = String(data: data, encoding: .utf8)
        else { return }

        text += "\n"
        connection.send(
            content: text.data(using: .utf8),
            completion: .contentProcessed { error in
                if let error {
                    print("[MCPBridge] Send error: \(error)")
                }
            }
        )
    }
}
