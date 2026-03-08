import SwiftUI
import SwiftData

@Observable
class MemoInputViewModel {
    var inputText: String = ""
    var titleText: String = ""
    var selectedTagID: UUID?

    var canSave: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func save(context: ModelContext, tags: [Tag]) {
        guard canSave else { return }
        let memo = Memo(content: inputText.trimmingCharacters(in: .whitespacesAndNewlines))
        memo.title = titleText.trimmingCharacters(in: .whitespacesAndNewlines)

        // ルーレットで選択されたタグを自動付与
        if let tagID = selectedTagID, let tag = tags.first(where: { $0.id == tagID }) {
            memo.tags.append(tag)
        }

        context.insert(memo)
        inputText = ""
        titleText = ""
    }
}
