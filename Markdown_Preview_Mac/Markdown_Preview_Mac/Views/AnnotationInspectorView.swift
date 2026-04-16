import SwiftUI

struct AnnotationInspectorView: View {
    var annotationStore: AnnotationStore
    var onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            if annotationStore.annotations.isEmpty {
                emptyState
            } else {
                annotationList
            }
        }
        .frame(minWidth: 200, idealWidth: 260, maxWidth: 320)
        .background(.background)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Annotations")
                .font(.headline)

            if !annotationStore.annotations.isEmpty {
                Text("\(annotationStore.annotations.count)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(.secondary, in: Capsule())
            }

            Spacer()

            if !annotationStore.annotations.isEmpty {
                Button {
                    annotationStore.clearAll()
                    onRefresh()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("전체 삭제")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "note.text")
                .font(.title2)
                .foregroundStyle(.quaternary)
            Text("주석이 없습니다")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("텍스트를 선택하고 ⌥N으로 추가")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
    }

    // MARK: - Annotation List

    private var annotationList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(annotationStore.annotations) { annotation in
                    AnnotationRow(
                        annotation: annotation,
                        onUpdateNote: { newNote in
                            annotationStore.update(id: annotation.id, note: newNote)
                            onRefresh()
                        },
                        onDelete: {
                            annotationStore.remove(id: annotation.id)
                            onRefresh()
                        }
                    )
                    Divider()
                        .padding(.horizontal, 8)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Annotation Row

private struct AnnotationRow: View {
    let annotation: Annotation
    let onUpdateNote: (String) -> Void
    let onDelete: () -> Void

    @State private var editingNote: String = ""
    @State private var isEditing = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Selected text preview
            HStack(alignment: .top) {
                Text("L\(annotation.startLine)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .frame(width: 30, alignment: .trailing)

                Text(annotation.selectedText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)

                Spacer(minLength: 4)

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("삭제")
            }

            // Note (editable)
            if isEditing {
                TextField("메모", text: $editingNote, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                    .font(.callout)
                    .focused($isFocused)
                    .onSubmit {
                        commitEdit()
                    }
                    .onChange(of: isFocused) { _, focused in
                        if !focused {
                            commitEdit()
                        }
                    }
            } else {
                Text(annotation.note)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingNote = annotation.note
                        isEditing = true
                        isFocused = true
                    }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func commitEdit() {
        isEditing = false
        let trimmed = editingNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != annotation.note {
            onUpdateNote(trimmed)
        }
    }
}
