import SwiftUI

struct MarkdownToolbar: View {
    let proxy: EditorTextProxy

    var body: some View {
        HStack(spacing: 2) {
            Group {
                toolbarButton("Bold", icon: "bold", shortcut: "b") {
                    proxy.wrapSelection(prefix: "**", suffix: "**")
                }
                toolbarButton("Italic", icon: "italic", shortcut: "i") {
                    proxy.wrapSelection(prefix: "_", suffix: "_")
                }
                toolbarButton("Strikethrough", icon: "strikethrough") {
                    proxy.wrapSelection(prefix: "~~", suffix: "~~")
                }
                toolbarButton("Inline Code", icon: "chevron.left.forwardslash.chevron.right") {
                    proxy.wrapSelection(prefix: "`", suffix: "`")
                }
            }

            Divider().frame(height: 20).padding(.horizontal, 4)

            Group {
                toolbarButton("Heading 1", label: "H1") {
                    proxy.insertAtLineStart("# ")
                }
                toolbarButton("Heading 2", label: "H2") {
                    proxy.insertAtLineStart("## ")
                }
                toolbarButton("Heading 3", label: "H3") {
                    proxy.insertAtLineStart("### ")
                }
            }

            Divider().frame(height: 20).padding(.horizontal, 4)

            Group {
                toolbarButton("Bulleted List", icon: "list.bullet") {
                    proxy.insertAtLineStart("- ")
                }
                toolbarButton("Numbered List", icon: "list.number") {
                    proxy.insertAtLineStart("1. ")
                }
                toolbarButton("Checkbox", icon: "checkmark.square") {
                    proxy.insertAtLineStart("- [ ] ")
                }
                toolbarButton("Blockquote", icon: "text.quote") {
                    proxy.insertAtLineStart("> ")
                }
            }

            Divider().frame(height: 20).padding(.horizontal, 4)

            Group {
                toolbarButton("Link", icon: "link") {
                    proxy.wrapSelection(prefix: "[", suffix: "](url)")
                }
                toolbarButton("Image", icon: "photo") {
                    proxy.insertText("![alt text](image-url)")
                }
                toolbarButton("Code Block", icon: "terminal") {
                    proxy.insertBlock("```\n\n```")
                }
                toolbarButton("Table", icon: "tablecells") {
                    proxy.insertBlock("| Header | Header |\n| ------ | ------ |\n| Cell   | Cell   |")
                }
                toolbarButton("Divider", icon: "minus") {
                    proxy.insertBlock("\n---\n")
                }
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.bar)
    }

    private func toolbarButton(
        _ tooltip: String,
        icon: String,
        shortcut: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .frame(width: 28, height: 24)
        }
        .buttonStyle(.borderless)
        .help(tooltip)
    }

    private func toolbarButton(
        _ tooltip: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .frame(width: 28, height: 24)
        }
        .buttonStyle(.borderless)
        .help(tooltip)
    }
}
