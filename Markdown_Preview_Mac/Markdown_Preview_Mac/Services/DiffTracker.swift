import Foundation

@Observable
class DiffTracker {
    var changes: [DiffChange] = []
    private var baseLines: [String] = []

    func setBaseline(_ content: String) {
        baseLines = content.components(separatedBy: "\n")
        changes.removeAll()
    }

    func recordChange(newContent: String, author: DiffChange.Author) {
        let newLines = newContent.components(separatedBy: "\n")
        let diff = newLines.difference(from: baseLines)

        var newChanges: [DiffChange] = []

        for change in diff {
            switch change {
            case .insert(let offset, let element, _):
                newChanges.append(DiffChange(
                    id: UUID(),
                    type: .added,
                    lineStart: offset + 1,
                    lineEnd: offset + 1,
                    author: author,
                    text: element,
                    timestamp: Date()
                ))
            case .remove(let offset, let element, _):
                newChanges.append(DiffChange(
                    id: UUID(),
                    type: .deleted,
                    lineStart: offset + 1,
                    lineEnd: offset + 1,
                    author: author,
                    text: element,
                    timestamp: Date()
                ))
            }
        }

        // Merge adjacent inserts/deletes at same position into "modified"
        changes = mergeChanges(newChanges, author: author)
        baseLines = newLines
    }

    func clearChanges() {
        changes.removeAll()
    }

    func changes(by author: DiffChange.Author?) -> [DiffChange] {
        guard let author else { return changes }
        return changes.filter { $0.author == author }
    }

    func changeDicts(by authorFilter: String?) -> [[String: Any]] {
        let filtered: [DiffChange]
        if let filter = authorFilter {
            let author = DiffChange.Author(rawValue: filter)
            filtered = author.map { changes(by: $0) } ?? changes
        } else {
            filtered = changes
        }

        return filtered.map { change in
            [
                "type": change.type.rawValue,
                "lineStart": change.lineStart,
                "lineEnd": change.lineEnd,
                "author": change.author.rawValue,
                "text": change.text
            ] as [String: Any]
        }
    }

    private func mergeChanges(_ raw: [DiffChange], author: DiffChange.Author) -> [DiffChange] {
        guard !raw.isEmpty else { return [] }

        var merged: [DiffChange] = []
        var i = 0

        while i < raw.count {
            let current = raw[i]

            // Look for adjacent delete+insert pair (= modification)
            if current.type == .deleted,
               i + 1 < raw.count,
               raw[i + 1].type == .added,
               raw[i + 1].lineStart == current.lineStart {
                merged.append(DiffChange(
                    id: UUID(),
                    type: .modified,
                    lineStart: current.lineStart,
                    lineEnd: current.lineEnd,
                    author: author,
                    text: raw[i + 1].text,
                    timestamp: Date()
                ))
                i += 2
            } else {
                merged.append(current)
                i += 1
            }
        }

        return merged
    }
}
