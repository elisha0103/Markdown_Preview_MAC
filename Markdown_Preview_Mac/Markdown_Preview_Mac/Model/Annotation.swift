import Foundation

struct Annotation: Identifiable, Codable {
    let id: UUID
    let note: String
    let selectedText: String
    let startLine: Int
    let endLine: Int
    let timestamp: Date

    init(note: String, selectedText: String, startLine: Int, endLine: Int) {
        self.id = UUID()
        self.note = note
        self.selectedText = selectedText
        self.startLine = startLine
        self.endLine = endLine
        self.timestamp = Date()
    }
}
