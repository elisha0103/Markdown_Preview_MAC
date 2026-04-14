import SwiftUI

struct FileActions {
    let open: () -> Void
    let save: () -> Void
    let saveAs: () -> Void
}

private struct FileActionsKey: FocusedValueKey {
    typealias Value = FileActions
}

extension FocusedValues {
    var fileActions: FileActions? {
        get { self[FileActionsKey.self] }
        set { self[FileActionsKey.self] = newValue }
    }
}
