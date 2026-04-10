import SwiftUI

struct TOCSidebarView: View {
    let headings: [HeadingItem]
    var onHeadingTap: (HeadingItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Table of Contents")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            if headings.isEmpty {
                Text("No headings found")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(12)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(headings) { heading in
                            Button {
                                onHeadingTap(heading)
                            } label: {
                                Text(heading.title)
                                    .font(fontForLevel(heading.level))
                                    .foregroundStyle(
                                        heading.level == 1 ? .primary : .secondary
                                    )
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, indentation(for: heading.level))
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 12)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(minWidth: 180, idealWidth: 220, maxWidth: 280)
        .background(.background)
    }

    private func indentation(for level: Int) -> CGFloat {
        CGFloat((level - 1) * 16)
    }

    private func fontForLevel(_ level: Int) -> Font {
        switch level {
        case 1: .system(size: 13, weight: .semibold)
        case 2: .system(size: 12, weight: .medium)
        default: .system(size: 11, weight: .regular)
        }
    }
}
