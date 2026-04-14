import Foundation

struct DiffChange: Identifiable, Codable {
    let id: UUID
    let type: ChangeType
    let lineStart: Int
    let lineEnd: Int
    let author: Author
    let text: String
    let timestamp: Date

    enum ChangeType: String, Codable {
        case added
        case modified
        case deleted
    }

    enum Author: String, Codable {
        case user
        case claude
    }
}
