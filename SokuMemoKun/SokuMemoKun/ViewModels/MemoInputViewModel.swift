import SwiftUI
import SwiftData

@Observable
class MemoInputViewModel {
    var inputText: String = ""
    var showTagTitleSheet: Bool = false
    var savedMemo: Memo?
    var selectedTagID: UUID?  // リールで選択中のタグ

    var canSave: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func save(context: ModelContext, tags: [Tag]) {
        guard canSave else { return }
        let memo = Memo(content: inputText.trimmingCharacters(in: .whitespacesAndNewlines))
        // リールで選択されたタグを自動付与
        if let tagID = selectedTagID, let tag = tags.first(where: { $0.id == tagID }) {
            memo.tags.append(tag)
        }
        context.insert(memo)
        savedMemo = memo
        showTagTitleSheet = true
        inputText = ""
    }
}
