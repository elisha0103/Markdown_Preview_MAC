import SwiftUI

struct AnnotationPopover: View {
    let selectedText: String
    let startLine: Int
    let endLine: Int
    let onSubmit: (String) -> Void

    @State private var note = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Claude에게 메모")
                .font(.headline)

            Text("선택: \"\(selectedText.prefix(60))\(selectedText.count > 60 ? "..." : "")\"")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            TextField("메모 입력...", text: $note, axis: .vertical)
                .lineLimit(3...5)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("취소") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("추가") {
                    guard !note.isEmpty else { return }
                    onSubmit(note)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(note.isEmpty)
            }
        }
        .padding()
        .frame(width: 320)
    }
}
