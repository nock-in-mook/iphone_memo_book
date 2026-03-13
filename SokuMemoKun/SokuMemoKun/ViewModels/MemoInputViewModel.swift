import SwiftUI
import SwiftData

@Observable
class MemoInputViewModel {
    var inputText: String = ""
    var titleText: String = ""
    var selectedTagID: UUID?
    var isMarkdown: Bool = UserDefaults.standard.bool(forKey: "defaultMarkdown")

    // 現在編集中のメモ（自動保存の対象）
    var editingMemo: Memo?
    // マークダウンメモ読み込み時にFullEditorを自動起動するフラグ
    var openFullEditor: Bool = false

    // 入力欄にテキストがあるか（保存=クリア ボタンの有効/無効）
    var canClear: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // テキスト変更時の自動保存
    func onContentChanged(context: ModelContext, tags: [Tag]) {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)

        if let memo = editingMemo {
            // 既存メモを更新
            memo.content = trimmed
            memo.updatedAt = Date()
        } else if !trimmed.isEmpty {
            // 新規メモ自動生成
            let memo = Memo(content: trimmed, isMarkdown: isMarkdown)
            memo.title = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
            // ルーレットで選択中のタグを付与
            if let tagID = selectedTagID, let tag = tags.first(where: { $0.id == tagID }) {
                memo.tags.append(tag)
            }
            context.insert(memo)
            editingMemo = memo
            saveLastMemoID(memo.id)
        }
    }

    // タイトル変更時の自動保存
    func onTitleChanged() {
        guard let memo = editingMemo else { return }
        memo.title = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        memo.updatedAt = Date()
    }

    // タグ変更時の自動保存（現状は単一タグ。将来マルチタグ対応時に要調整）
    func onTagChanged(tags: [Tag]) {
        guard let memo = editingMemo else { return }
        memo.tags.removeAll()
        if let tagID = selectedTagID, let tag = tags.first(where: { $0.id == tagID }) {
            memo.tags.append(tag)
        }
        memo.updatedAt = Date()
    }

    // メモを破棄（データベースから削除して入力欄をクリア）
    func discardMemo(context: ModelContext) {
        if let memo = editingMemo {
            context.delete(memo)
        }
        editingMemo = nil
        inputText = ""
        titleText = ""
        selectedTagID = nil
        isMarkdown = UserDefaults.standard.bool(forKey: "defaultMarkdown")
        UserDefaults.standard.removeObject(forKey: "lastEditingMemoID")
    }

    // 保存ボタン（入力欄をクリアして新規入力待ちに）
    func clearInput() {
        editingMemo = nil
        inputText = ""
        titleText = ""
        selectedTagID = nil
        isMarkdown = UserDefaults.standard.bool(forKey: "defaultMarkdown")
        UserDefaults.standard.removeObject(forKey: "lastEditingMemoID")
    }

    // 既存メモを入力欄に読み込む
    func loadMemo(_ memo: Memo) {
        editingMemo = memo
        inputText = memo.content
        titleText = memo.title
        isMarkdown = memo.isMarkdown
        selectedTagID = memo.tags.first?.id
        saveLastMemoID(memo.id)
    }

    // アプリ起動時に前回のメモを復元
    func restoreLastMemo(context: ModelContext) {
        guard UserDefaults.standard.bool(forKey: "restoreLastMemo") else { return }
        guard let idString = UserDefaults.standard.string(forKey: "lastEditingMemoID"),
              let id = UUID(uuidString: idString) else { return }
        let descriptor = FetchDescriptor<Memo>(predicate: #Predicate { memo in memo.id == id })
        if let memo = try? context.fetch(descriptor).first {
            loadMemo(memo)
        }
    }

    private func saveLastMemoID(_ id: UUID) {
        UserDefaults.standard.set(id.uuidString, forKey: "lastEditingMemoID")
    }
}
