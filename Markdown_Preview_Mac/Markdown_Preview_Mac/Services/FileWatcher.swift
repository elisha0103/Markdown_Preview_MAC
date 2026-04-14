import Foundation

@Observable
class FileWatcher {
    var fileURL: URL? {
        didSet { setupWatcher() }
    }
    var onExternalChange: ((String) -> Void)?

    private var source: DispatchSourceFileSystemObject?
    private let watchQueue = DispatchQueue(label: "com.markdownpreview.filewatcher")
    private var isAppSaving = false
    private var lastContent: String?
    private var fileDescriptor: Int32 = -1

    func markAppSaving() {
        isAppSaving = true
    }

    func markFinished() {
        isAppSaving = false
        if let url = fileURL {
            lastContent = try? String(contentsOf: url, encoding: .utf8)
        }
    }

    private func setupWatcher() {
        stopWatcher()
        guard let url = fileURL else { return }

        lastContent = try? String(contentsOf: url, encoding: .utf8)

        fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor != -1 else {
            print("[FileWatcher] Failed to open: \(url.path)")
            return
        }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: watchQueue
        )

        src.setEventHandler { [weak self] in
            self?.handleFileEvent()
        }

        src.setCancelHandler { [weak self] in
            guard let self, self.fileDescriptor != -1 else { return }
            close(self.fileDescriptor)
            self.fileDescriptor = -1
        }

        src.resume()
        source = src
        print("[FileWatcher] Watching: \(url.lastPathComponent)")
    }

    private func handleFileEvent() {
        guard !isAppSaving, let url = fileURL else { return }

        // Small delay to let the write complete
        watchQueue.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            do {
                let newContent = try String(contentsOf: url, encoding: .utf8)
                if newContent != self.lastContent {
                    self.lastContent = newContent
                    DispatchQueue.main.async {
                        self.onExternalChange?(newContent)
                    }
                }
            } catch {
                print("[FileWatcher] Read error: \(error.localizedDescription)")
            }
        }
    }

    private func stopWatcher() {
        source?.cancel()
        source = nil
    }

    deinit {
        stopWatcher()
    }
}
