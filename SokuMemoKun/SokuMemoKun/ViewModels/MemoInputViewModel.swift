import SwiftUI
import SwiftData

@Observable
class MemoInputViewModel {
    // メモ本文の最大文字数
    static let maxCharacterCount = 50_000

    var inputText: String = ""
    var titleText: String = ""
    var selectedTagID: UUID?       // 親タグ
    var selectedChildTagID: UUID?  // 子タグ
    var isMarkdown: Bool = UserDefaults.standard.bool(forKey: AppStorageKeys.defaultMarkdown)
    // UI制御フラグ（MainViewとMemoInputViewの両方からアクセス）
    var showClearBodyAlert: Bool = false
    var showMarkdownPreview: Bool = false

    // 現在編集中のメモ（自動保存の対象）
    var editingMemo: Memo?
    // マークダウンメモ読み込み時にFullEditorを自動起動するフラグ
    var openFullEditor: Bool = false
    // loadMemo中フラグ（onChangeでの子タグリセットを防止）
    var isLoadingMemo: Bool = false
    // loadMemoが呼ばれた回数（Viewが閲覧モードに切り替えるトリガー）
    var loadMemoCounter: Int = 0

    // Undo/Redo（本文・タイトル・タグをまとめてスナップショット）
    private struct Snapshot: Equatable {
        var text: String
        var title: String
        var tagID: UUID?
        var childTagID: UUID?
    }
    private var undoStack: [Snapshot] = []
    private var redoStack: [Snapshot] = []
    private var lastSnapshot = Snapshot(text: "", title: "", tagID: nil, childTagID: nil)
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    private var currentSnapshot: Snapshot {
        Snapshot(text: inputText, title: titleText, tagID: selectedTagID, childTagID: selectedChildTagID)
    }

    // 変更時に呼ぶ（差分があればスナップショットを保存）
    func pushUndoIfNeeded() {
        let current = currentSnapshot
        if current != lastSnapshot {
            undoStack.append(lastSnapshot)
            redoStack.removeAll()
            lastSnapshot = current
            if undoStack.count > 50 { undoStack.removeFirst() }
        }
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(currentSnapshot)
        applySnapshot(previous)
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(currentSnapshot)
        applySnapshot(next)
    }

    private func applySnapshot(_ s: Snapshot) {
        inputText = s.text
        titleText = s.title
        selectedTagID = s.tagID
        selectedChildTagID = s.childTagID
        lastSnapshot = s
    }

    func resetUndoStack() {
        undoStack.removeAll()
        redoStack.removeAll()
        lastSnapshot = currentSnapshot
    }

    // テキストがあるか（確定ボタンの有効/無効）
    var hasText: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // 入力欄に内容があるか（ゴミ箱の有効/無効）— 本文・タイトル・タグのいずれかがあれば有効
    var canClear: Bool {
        hasText || selectedTagID != nil
    }

    // テキスト変更時の自動保存
    func onContentChanged(context: ModelContext, tags: [Tag]) {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let titleTrimmed = titleText.trimmingCharacters(in: .whitespacesAndNewlines)

        if let memo = editingMemo {
            if trimmed.isEmpty && titleTrimmed.isEmpty {
                // 本文もタイトルも空 → 白紙メモは削除
                context.delete(memo)
                editingMemo = nil
                UserDefaults.standard.removeObject(forKey: AppStorageKeys.lastEditingMemoID)
                return
            }
            // 既存メモを更新
            memo.content = trimmed
            memo.updatedAt = Date()
        } else if !trimmed.isEmpty {
            // 新規メモ自動生成
            let memo = Memo(content: trimmed, isMarkdown: isMarkdown)
            memo.title = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
            // ルーレットで選択中の親タグ＋子タグを付与
            if let tagID = selectedTagID, let tag = tags.first(where: { $0.id == tagID }) {
                memo.tags.append(tag)
            }
            if let childID = selectedChildTagID, let childTag = tags.first(where: { $0.id == childID }) {
                memo.tags.append(childTag)
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

    // タグ変更時の自動保存（親タグ＋子タグの両方を反映）
    func onTagChanged(tags: [Tag]) {
        guard let memo = editingMemo else { return }
        memo.tags.removeAll()
        // 親タグ
        if let tagID = selectedTagID, let tag = tags.first(where: { $0.id == tagID }) {
            memo.tags.append(tag)
        }
        // 子タグ
        if let childID = selectedChildTagID, let childTag = tags.first(where: { $0.id == childID }) {
            memo.tags.append(childTag)
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
        selectedChildTagID = nil
        isMarkdown = UserDefaults.standard.bool(forKey: AppStorageKeys.defaultMarkdown)
        UserDefaults.standard.removeObject(forKey: AppStorageKeys.lastEditingMemoID)
    }

    // 保存ボタン（入力欄をクリアして新規入力待ちに）
    func clearInput() {
        editingMemo = nil
        inputText = ""
        titleText = ""
        selectedTagID = nil
        selectedChildTagID = nil
        isMarkdown = UserDefaults.standard.bool(forKey: AppStorageKeys.defaultMarkdown)
        UserDefaults.standard.removeObject(forKey: AppStorageKeys.lastEditingMemoID)
        resetUndoStack()
    }

    // 既存メモを入力欄に読み込む
    func loadMemo(_ memo: Memo) {
        isLoadingMemo = true
        editingMemo = memo
        inputText = memo.content
        titleText = memo.title
        isMarkdown = memo.isMarkdown
        // 親タグ = parentTagIDがnilのタグ、子タグ = parentTagIDがあるタグ
        let parentTag = memo.tags.first(where: { $0.parentTagID == nil })
        let childTag = memo.tags.first(where: { $0.parentTagID != nil })
        selectedTagID = parentTag?.id
        selectedChildTagID = childTag?.id
        saveLastMemoID(memo.id)
        // 閲覧追跡
        memo.viewCount += 1
        memo.lastViewedAt = Date()
        isLoadingMemo = false
        loadMemoCounter += 1
        resetUndoStack()
    }

    // アプリ起動時は常に空の入力欄で開始（書きかけメモは自動保存済みでリストにある）
    func restoreLastMemo(context: ModelContext) {
        // 自動保存により前回のメモは既にリストに保存されているので、
        // 起動時は新規入力待ち状態にする
        clearInput()
    }

    private func saveLastMemoID(_ id: UUID) {
        UserDefaults.standard.set(id.uuidString, forKey: AppStorageKeys.lastEditingMemoID)
    }

}
