import Foundation

@Observable
class AnnotationStore {
    var annotations: [Annotation] = []

    func add(note: String, selectedText: String, startLine: Int, endLine: Int) {
        let annotation = Annotation(
            note: note,
            selectedText: selectedText,
            startLine: startLine,
            endLine: endLine
        )
        annotations.append(annotation)
    }

    func remove(id: UUID) {
        annotations.removeAll { $0.id == id }
    }

    func clearAll() {
        annotations.removeAll()
    }

    func toDicts() -> [[String: Any]] {
        annotations.map { a in
            [
                "id": a.id.uuidString,
                "note": a.note,
                "selectedText": a.selectedText,
                "startLine": a.startLine,
                "endLine": a.endLine,
                "timestamp": ISO8601DateFormatter().string(from: a.timestamp)
            ] as [String: Any]
        }
    }
}
