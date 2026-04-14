import SwiftUI

@main
struct Markdown_Preview_MacApp: App {
    @FocusedValue(\.fileActions) var fileActions

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(after: .newItem) {
                Divider()

                Button("Open...") {
                    fileActions?.open()
                }
                .keyboardShortcut("o")
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    fileActions?.save()
                }
                .keyboardShortcut("s")

                Button("Save As...") {
                    fileActions?.saveAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
        }
    }
}
