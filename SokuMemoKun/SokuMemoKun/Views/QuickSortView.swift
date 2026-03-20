import SwiftUI
import SwiftData

// 爆速振り分けモード: メインカード画面
struct QuickSortView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var tags: [Tag]

    // 対象メモ（フィルタ済み）
    let targetMemos: [Memo]
    var onDismiss: () -> Void

    // タグサジェストエンジン
    @State private var suggestEngine = TagSuggestEngine()

    // 現在のインデックス
    @State private var currentIndex = 0

    // カードのドラッグ状態
    @State private var dragOffset: CGSize = .zero
    @State private var cardOpacity: Double = 1.0

    // ルーレット状態
    @State private var selectedParentTagID: UUID? = nil
    @State private var selectedChildTagID: UUID? = nil
    @State private var showChildDial = false
    @State private var childExternalDragY: CGFloat? = nil

    // 編集状態
    @State private var editingTitle = ""
    @State private var editingContent = ""
    @State private var isEditingTitle = false
    @State private var isEditingContent = false

    // サジェスト
    @State private var currentSuggestions: [TagSuggestEngine.Suggestion] = []
    // 先読みキャッシュ（インデックス→サジェスト）
    @State private var suggestCache: [Int: [TagSuggestEngine.Suggestion]] = [:]

    // 変更ログ
    @State private var taggedMemoIDs: Set<UUID> = []
    @State private var titledMemoIDs: Set<UUID> = []
    @State private var editedMemoIDs: Set<UUID> = []
    @State private var deletedMemos: [Memo] = []
    // 削除予定キュー（完了時に一括削除）
    @State private var deleteQueue: [Memo] = []
    // スキップ済みインデックス（削除済みのメモをスキップ）
    @State private var skippedIndices: Set<Int> = []

    // 戦績表示
    @State private var showResult = false
    // 削除確認リスト
    @State private var showDeleteReview = false

    // 現在のメモ
    private var currentMemo: Memo? {
        guard currentIndex >= 0 && currentIndex < targetMemos.count else { return nil }
        let memo = targetMemos[currentIndex]
        return skippedIndices.contains(currentIndex) ? nil : memo
    }

    // 実質的なカウント（削除されたものを除く）
    private var activeCount: Int {
        targetMemos.count - skippedIndices.count
    }

    // 現在の表示番号（スキップ済みを除いた番号）
    private var displayNumber: Int {
        var count = 0
        for i in 0...min(currentIndex, targetMemos.count - 1) {
            if !skippedIndices.contains(i) { count += 1 }
        }
        return count
    }

    var body: some View {
        VStack(spacing: 0) {
            // ナビゲーションバー
            navBar
                .padding(.horizontal, 16)
                .padding(.top, 8)

            if let memo = currentMemo {
                // メモカード
                cardView(memo: memo)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                Spacer(minLength: 8)

                // タグサジェスト（カード下）
                suggestPanel
                    .padding(.horizontal, 16)

                // ルーレット（下部）
                dialArea
                    .padding(.top, 4)
                    .padding(.bottom, 8)
            } else if targetMemos.isEmpty || activeCount == 0 {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("対象のメモがありません")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                // 現在位置がスキップ済み → 次に進む
                Spacer()
                    .onAppear { moveToNextActive() }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .overlay {
            if showResult {
                QuickSortResultView(
                    taggedCount: taggedMemoIDs.count,
                    titledCount: titledMemoIDs.count,
                    editedCount: editedMemoIDs.count,
                    deletedCount: deleteQueue.count,
                    deletedMemos: deleteQueue,
                    onReviewDeleted: {
                        showResult = false
                        showDeleteReview = true
                    },
                    onClose: {
                        // 削除キューを実行
                        for memo in deleteQueue {
                            modelContext.delete(memo)
                        }
                        try? modelContext.save()
                        onDismiss()
                    }
                )
            }
        }
        .sheet(isPresented: $showDeleteReview) {
            deleteReviewSheet
        }
        .onAppear {
            loadCurrentMemo()
            prefetchSuggestions()
        }
    }

    // MARK: - ナビゲーションバー

    private var navBar: some View {
        HStack {
            // 左矢印
            Button {
                saveCurrent()
                moveToPreviousActive()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(currentIndex > 0 ? .primary : .secondary.opacity(0.3))
            }
            .disabled(currentIndex <= 0)

            Spacer()

            // カウンター
            if activeCount > 0 {
                Text("\(displayNumber)/\(activeCount)枚目")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 右矢印
            Button {
                saveCurrent()
                moveToNextActive()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(currentIndex < targetMemos.count - 1 ? .primary : .secondary.opacity(0.3))
            }
            .disabled(currentIndex >= targetMemos.count - 1)

            Spacer().frame(width: 16)

            // 完了ボタン
            Button {
                saveCurrent()
                withAnimation(.easeOut(duration: 0.25)) {
                    showResult = true
                }
            } label: {
                Text("完了")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.orange))
            }
        }
    }

    // MARK: - カードビュー

    @ViewBuilder
    private func cardView(memo: Memo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 現在のタグ表示
            HStack(spacing: 6) {
                ForEach(memo.tags, id: \.id) { tag in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(tagColor(for: tag.colorIndex))
                            .frame(width: 8, height: 8)
                        Text(tag.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(tagColor(for: tag.colorIndex).opacity(0.15))
                    )
                }
                if memo.tags.isEmpty {
                    Text("タグなし")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.gray.opacity(0.1)))
                }
                Spacer()

                // 削除ボタン（上フリックの代替）
                Button {
                    deleteCurrentMemo()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(.red.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider().padding(.horizontal, 16)

            // タイトル（タップで編集）
            if isEditingTitle {
                TextField("タイトル", text: $editingTitle)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .onSubmit {
                        isEditingTitle = false
                        applyTitleEdit()
                    }
            } else {
                Text(editingTitle.isEmpty ? "タイトルなし" : editingTitle)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(editingTitle.isEmpty ? .secondary.opacity(0.5) : Color.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .onTapGesture {
                        isEditingTitle = true
                    }
            }

            // 本文（スクロール可能）
            if isEditingContent {
                TextEditor(text: $editingContent)
                    .font(.system(size: 15))
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .frame(maxHeight: .infinity)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("完了") {
                                isEditingContent = false
                                applyContentEdit()
                                UIApplication.shared.sendAction(
                                    #selector(UIResponder.resignFirstResponder),
                                    to: nil, from: nil, for: nil
                                )
                            }
                        }
                    }
            } else {
                ScrollView {
                    Text(editingContent.isEmpty ? "（本文なし）" : editingContent)
                        .font(.system(size: 15))
                        .foregroundColor(editingContent.isEmpty ? .secondary.opacity(0.5) : Color.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                }
                .frame(maxHeight: .infinity)
                .onTapGesture {
                    isEditingContent = true
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
        .offset(dragOffset)
        .opacity(cardOpacity)
        .gesture(
            DragGesture()
                .onChanged { value in
                    // 上方向のドラッグ → 削除予告
                    if value.translation.height < -30 {
                        dragOffset = CGSize(width: 0, height: value.translation.height)
                        cardOpacity = max(0.3, 1.0 + Double(value.translation.height) / 300.0)
                    }
                    // 左右ドラッグ → 前後移動予告
                    if abs(value.translation.width) > 30 && abs(value.translation.height) < 50 {
                        dragOffset = CGSize(width: value.translation.width, height: 0)
                    }
                }
                .onEnded { value in
                    if value.translation.height < -120 {
                        // 上フリック → 削除
                        withAnimation(.easeOut(duration: 0.2)) {
                            dragOffset = CGSize(width: 0, height: -500)
                            cardOpacity = 0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            deleteCurrentMemo()
                        }
                    } else if value.translation.width < -100 {
                        // 左フリック → 次へ
                        saveCurrent()
                        withAnimation(.easeOut(duration: 0.15)) {
                            dragOffset = .zero
                            cardOpacity = 1.0
                        }
                        moveToNextActive()
                    } else if value.translation.width > 100 {
                        // 右フリック → 前へ
                        saveCurrent()
                        withAnimation(.easeOut(duration: 0.15)) {
                            dragOffset = .zero
                            cardOpacity = 1.0
                        }
                        moveToPreviousActive()
                    } else {
                        // 戻す
                        withAnimation(.spring(response: 0.3)) {
                            dragOffset = .zero
                            cardOpacity = 1.0
                        }
                    }
                }
        )
    }

    // MARK: - タグサジェストパネル

    private var suggestPanel: some View {
        VStack(spacing: 4) {
            if !currentSuggestions.isEmpty {
                HStack {
                    Text("おすすめタグ")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(currentSuggestions) { suggestion in
                            Button {
                                applySuggestion(suggestion)
                            } label: {
                                HStack(spacing: 4) {
                                    if suggestion.kind == .newTag {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.green)
                                    } else if let parentTag = tags.first(where: { $0.id == suggestion.parentID }) {
                                        Circle()
                                            .fill(tagColor(for: parentTag.colorIndex))
                                            .frame(width: 8, height: 8)
                                    }
                                    Text(suggestion.parentName)
                                        .font(.system(size: 13, weight: .semibold))
                                    if let childName = suggestion.childName {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 8))
                                            .foregroundStyle(.tertiary)
                                        Text(childName)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    suggestion.kind == .newTag
                                        ? Color.green.opacity(0.1)
                                        : Color(uiColor: .secondarySystemBackground)
                                )
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .frame(minHeight: 30)
    }

    // MARK: - ルーレットエリア

    private var dialArea: some View {
        let parentTags = tags.filter { $0.parentTagID == nil }.sorted { $0.sortOrder < $1.sortOrder }
        let childTags: [Tag] = {
            guard let pid = selectedParentTagID else { return [] }
            return tags.filter { $0.parentTagID == pid }.sorted { $0.name < $1.name }
        }()

        let parentOptions: [(id: String, name: String, color: Color)] =
            [("none", "タグなし", Color(white: 0.82))] +
            parentTags.map { tag in
                (tag.id.uuidString, tag.name, tagColor(for: tag.colorIndex))
            }

        let childOptions: [(id: String, name: String, color: Color)] =
            childTags.isEmpty ? [] :
            [("none", "子タグなし", Color(white: 0.82))] +
            childTags.map { tag in
                (tag.id.uuidString, tag.name, tagColor(for: tag.colorIndex))
            }

        return HStack(spacing: 0) {
            Spacer(minLength: 0)

            TagDialView(
                parentOptions: parentOptions,
                parentSelectedID: $selectedParentTagID,
                childOptions: childOptions,
                childSelectedID: $selectedChildTagID,
                showChild: $showChildDial,
                isOpen: true,
                childExternalDragY: $childExternalDragY,
                onLongPress: nil
            )
            .frame(height: 211)

            // タグ適用ボタン
            VStack(spacing: 12) {
                Button {
                    applyTag()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "tag.fill")
                            .font(.system(size: 20))
                        Text("適用")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.orange)
                    )
                    .shadow(color: .orange.opacity(0.3), radius: 4, y: 2)
                }

                // 子タグ表示切り替え
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showChildDial.toggle()
                    }
                } label: {
                    Image(systemName: showChildDial ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color(uiColor: .secondarySystemBackground)))
                }
            }
            .padding(.leading, 8)
            .padding(.trailing, 16)
        }
    }

    // MARK: - 削除確認シート

    private var deleteReviewSheet: some View {
        NavigationStack {
            List {
                ForEach(deleteQueue, id: \.id) { memo in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(memo.title.isEmpty ? "（タイトルなし）" : memo.title)
                            .font(.system(size: 15, weight: .semibold))
                        Text(String(memo.content.prefix(100)))
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("復元") {
                            // 削除キューから取り出して復元
                            if let idx = deleteQueue.firstIndex(where: { $0.id == memo.id }) {
                                let restored = deleteQueue.remove(at: idx)
                                // skippedIndicesから外す
                                if let origIdx = targetMemos.firstIndex(where: { $0.id == restored.id }) {
                                    skippedIndices.remove(origIdx)
                                }
                            }
                        }
                        .tint(.green)
                    }
                }
            }
            .navigationTitle("削除予定のメモ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("戻る") {
                        showDeleteReview = false
                        showResult = true
                    }
                }
            }
        }
    }

    // MARK: - アクション

    // 現在のメモの編集内容を保存
    private func saveCurrent() {
        guard let memo = currentMemo else { return }
        let originalTitle = memo.title
        let originalContent = memo.content

        memo.title = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        memo.content = editingContent

        if memo.title != originalTitle && !memo.title.isEmpty {
            titledMemoIDs.insert(memo.id)
        }
        if memo.content != originalContent {
            editedMemoIDs.insert(memo.id)
        }

        memo.updatedAt = Date()
        isEditingTitle = false
        isEditingContent = false
    }

    // 現在のメモを削除キューに
    private func deleteCurrentMemo() {
        guard let memo = currentMemo else { return }
        deleteQueue.append(memo)
        skippedIndices.insert(currentIndex)

        // カードリセット
        dragOffset = .zero
        cardOpacity = 1.0

        // 次のアクティブなメモに移動
        if activeCount > 0 {
            moveToNextActive()
        } else {
            // 全部処理した → 戦績
            withAnimation(.easeOut(duration: 0.25)) {
                showResult = true
            }
        }
    }

    // タグを適用
    private func applyTag() {
        guard let memo = currentMemo else { return }
        let originalTags = Set(memo.tags.map { $0.id })

        // タグを全クリアして再設定
        memo.tags.removeAll()
        if let pid = selectedParentTagID, let tag = tags.first(where: { $0.id == pid }) {
            memo.tags.append(tag)
        }
        if let cid = selectedChildTagID, let tag = tags.first(where: { $0.id == cid }) {
            memo.tags.append(tag)
        }
        memo.updatedAt = Date()

        let newTags = Set(memo.tags.map { $0.id })
        if originalTags != newTags {
            taggedMemoIDs.insert(memo.id)

            // 学習
            let tagIDs = memo.tags.map { $0.id }
            suggestEngine.learn(title: memo.title, body: memo.content, tagIDs: tagIDs, context: modelContext)
        }

        // 次へ自動移動
        saveCurrent()
        moveToNextActive()
    }

    // サジェストを適用
    private func applySuggestion(_ suggestion: TagSuggestEngine.Suggestion) {
        guard let memo = currentMemo else { return }

        if suggestion.kind == .newTag {
            // 新規タグは爆速モードでは一旦スキップ（複雑になるため）
            return
        }

        selectedParentTagID = suggestion.parentID
        selectedChildTagID = suggestion.childID

        // 即適用
        applyTag()
    }

    // タイトル編集を適用
    private func applyTitleEdit() {
        guard let memo = currentMemo else { return }
        let newTitle = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if newTitle != memo.title {
            memo.title = newTitle
            memo.updatedAt = Date()
            if !newTitle.isEmpty { titledMemoIDs.insert(memo.id) }
        }
    }

    // 本文編集を適用
    private func applyContentEdit() {
        guard let memo = currentMemo else { return }
        if editingContent != memo.content {
            memo.content = editingContent
            memo.updatedAt = Date()
            editedMemoIDs.insert(memo.id)
        }
    }

    // MARK: - ナビゲーション

    private func loadCurrentMemo() {
        guard let memo = currentMemo else { return }
        editingTitle = memo.title
        editingContent = memo.content
        // 現在のタグをルーレットに反映
        let parentTag = memo.tags.first(where: { $0.parentTagID == nil })
        let childTag = memo.tags.first(where: { $0.parentTagID != nil })
        selectedParentTagID = parentTag?.id
        selectedChildTagID = childTag?.id
        showChildDial = childTag != nil

        // サジェスト更新
        updateSuggestions()
    }

    private func moveToNextActive() {
        var next = currentIndex + 1
        while next < targetMemos.count && skippedIndices.contains(next) {
            next += 1
        }
        if next < targetMemos.count {
            currentIndex = next
            loadCurrentMemo()
            prefetchSuggestions()
        } else {
            // 最後まで到達 → 巻き戻しチェック
            var first = 0
            while first < currentIndex && skippedIndices.contains(first) {
                first += 1
            }
            if first < currentIndex && !skippedIndices.contains(first) {
                // 先頭に戻る
                currentIndex = first
                loadCurrentMemo()
                prefetchSuggestions()
            }
            // それでもなければ何もしない（完了ボタンで終了）
        }
    }

    private func moveToPreviousActive() {
        var prev = currentIndex - 1
        while prev >= 0 && skippedIndices.contains(prev) {
            prev -= 1
        }
        if prev >= 0 {
            currentIndex = prev
            loadCurrentMemo()
        }
    }

    // MARK: - サジェスト

    private func updateSuggestions() {
        // キャッシュにあればそれを使う
        if let cached = suggestCache[currentIndex] {
            currentSuggestions = cached
            return
        }
        guard let memo = currentMemo else {
            currentSuggestions = []
            return
        }
        let result = suggestEngine.suggest(
            title: memo.title,
            body: memo.content,
            tags: tags,
            context: modelContext,
            limit: 3
        )
        currentSuggestions = result
        suggestCache[currentIndex] = result
    }

    // 前後のメモのサジェストを先読み
    private func prefetchSuggestions() {
        let prefetchRange = max(0, currentIndex - 1)...min(targetMemos.count - 1, currentIndex + 2)
        for i in prefetchRange {
            if suggestCache[i] == nil && !skippedIndices.contains(i) {
                let memo = targetMemos[i]
                let result = suggestEngine.suggest(
                    title: memo.title,
                    body: memo.content,
                    tags: tags,
                    context: modelContext,
                    limit: 3
                )
                suggestCache[i] = result
            }
        }
    }
}
