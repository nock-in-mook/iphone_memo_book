import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.sokumemokun.app", category: "QuickSort")

// 爆速振り分けモード: メインカード画面（カルーセル方式）
struct QuickSortView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var tags: [Tag]

    let targetMemos: [Memo]
    var onDismiss: () -> Void

    @State private var suggestEngine = TagSuggestEngine()

    // カルーセル: scrollPosition で現在のカードを追跡
    @State private var scrolledMemoID: UUID?

    // 上フリック削除用
    @State private var deletingMemoID: UUID? = nil
    @State private var deleteOffset: CGFloat = 0

    // ルーレット（子タグ表示デフォ）
    @State private var selectedParentTagID: UUID? = nil
    @State private var selectedChildTagID: UUID? = nil
    @State private var showChildDial = true
    @State private var childExternalDragY: CGFloat? = nil
    @State private var isInternalTagChange = false

    // 編集
    @State private var editingTitle = ""
    @State private var editingContent = ""
    @State private var isEditingTitle = false

    // 本文閲覧/編集モード
    @State private var showContentEditor = false

    // サジェスト
    @State private var currentSuggestions: [TagSuggestEngine.Suggestion] = []
    @State private var suggestCache: [Int: [TagSuggestEngine.Suggestion]] = [:]

    // 変更ログ
    @State private var taggedMemoIDs: Set<UUID> = []
    @State private var titledMemoIDs: Set<UUID> = []
    @State private var editedMemoIDs: Set<UUID> = []
    @State private var deleteQueue: [Memo] = []
    @State private var skippedIndices: Set<Int> = []

    // 戦績
    @State private var showResult = false
    @State private var showDeleteReview = false

    // アクティブなメモ（削除キューを除外した配列）
    private var activeMemos: [Memo] {
        let skippedIDs = Set(deleteQueue.map { $0.id })
        return targetMemos.filter { !skippedIDs.contains($0.id) }
    }

    private var currentMemo: Memo? {
        guard let id = scrolledMemoID else { return activeMemos.first }
        return activeMemos.first(where: { $0.id == id })
    }

    private var currentIndexInActive: Int {
        guard let memo = currentMemo else { return 0 }
        return activeMemos.firstIndex(where: { $0.id == memo.id }) ?? 0
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

                if !activeMemos.isEmpty {
                    mainContent(geo: geo)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                        Text("対象のメモがありません")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                if showResult {
                    QuickSortResultView(
                        taggedCount: taggedMemoIDs.count,
                        titledCount: titledMemoIDs.count,
                        editedCount: editedMemoIDs.count,
                        deletedCount: deleteQueue.count,
                        deletedMemos: deleteQueue,
                        onReviewDeleted: { showResult = false; showDeleteReview = true },
                        onClose: {
                            for m in deleteQueue { modelContext.delete(m) }
                            try? modelContext.save()
                            onDismiss()
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showDeleteReview) { deleteReviewSheet }
        .fullScreenCover(isPresented: $showContentEditor) { contentEditorView }
        .onAppear {
            logger.warning("onAppear: targetMemos.count = \(self.targetMemos.count)")
            if let first = activeMemos.first {
                scrolledMemoID = first.id
                syncEditingState(for: first)
            }
            prefetchSuggestions()
        }
        .onChange(of: scrolledMemoID) { _, newID in
            if let id = newID, let memo = activeMemos.first(where: { $0.id == id }) {
                // 前のメモを保存
                saveCurrent()
                syncEditingState(for: memo)
            }
        }
        .onChange(of: selectedParentTagID) { _, _ in
            if !isInternalTagChange { applyTagFromDial() }
        }
        .onChange(of: selectedChildTagID) { _, _ in
            if !isInternalTagChange { applyTagFromDial() }
        }
    }

    // MARK: - メインコンテンツ

    @ViewBuilder
    private func mainContent(geo: GeometryProxy) -> some View {
        let cardWidth = geo.size.width * 0.78

        VStack(spacing: 0) {
            // ナビバー
            navBar
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

            // 削除ゾーン
            deleteZone
                .frame(height: 36)

            // タイトル（枠付き）
            titleArea
                .padding(.horizontal, 16)
                .padding(.top, 4)

            // カルーセル（横スクロール・スナップ付き）
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(activeMemos, id: \.id) { memo in
                        cardItem(memo: memo, width: cardWidth, height: geo.size.height * 0.25)
                            .id(memo.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, (geo.size.width - cardWidth) / 2)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrolledMemoID)
            .padding(.top, 4)

            // カウンター
            if !activeMemos.isEmpty {
                Text("\(currentIndexInActive + 1) / \(activeMemos.count)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .padding(.top, 2)
            }

            // タグ表示
            if let memo = currentMemo {
                currentTagsBar(memo: memo)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            }

            // 下部: サジェスト(左) + ルーレット(右)
            HStack(alignment: .top, spacing: 0) {
                suggestPanel
                    .frame(maxWidth: .infinity, alignment: .leading)
                dialArea
            }
            .padding(.top, 2)

            Spacer(minLength: 0)
        }
    }

    // MARK: - カルーセルのカード1枚

    @ViewBuilder
    private func cardItem(memo: Memo, width: CGFloat, height: CGFloat) -> some View {
        let isDeleting = deletingMemoID == memo.id

        ZStack(alignment: .bottomLeading) {
            // カード本体
            VStack(alignment: .leading, spacing: 0) {
                Text(memo.content.isEmpty ? "（本文なし）" : memo.content)
                    .font(.system(size: 13))
                    .foregroundColor(memo.content.isEmpty ? Color.secondary.opacity(0.4) : Color.primary)
                    .lineLimit(nil)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(12)
            }
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)

            // 「本文を確認」ボタン
            Button {
                // まず現在のメモに同期
                if scrolledMemoID != memo.id {
                    scrolledMemoID = memo.id
                }
                showContentEditor = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text.magnifyingglass").font(.system(size: 10))
                    Text("本文を確認").font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.secondary.opacity(0.6))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color(uiColor: .secondarySystemBackground).opacity(0.8)))
            }
            .buttonStyle(.plain)
            .padding(8)
        }
        .frame(width: width, height: height)
        .offset(y: isDeleting ? deleteOffset : 0)
        .opacity(isDeleting ? max(0.0, 1.0 + Double(deleteOffset) / 300.0) : 1.0)
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    // 縦方向が支配的で上方向のときだけ反応
                    let t = value.translation
                    if t.height < -15 && abs(t.height) > abs(t.width) * 1.5 {
                        deletingMemoID = memo.id
                        deleteOffset = t.height
                    }
                }
                .onEnded { value in
                    guard deletingMemoID == memo.id else { return }
                    if value.translation.height < -100 {
                        withAnimation(.easeOut(duration: 0.2)) { deleteOffset = -500 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            deleteMemo(memo)
                            deletingMemoID = nil
                            deleteOffset = 0
                        }
                    } else {
                        withAnimation(.spring(response: 0.3)) { deleteOffset = 0 }
                        deletingMemoID = nil
                    }
                }
        )
    }

    // MARK: - ナビバー

    private var navBar: some View {
        HStack {
            Button { saveCurrent(); onDismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                saveCurrent()
                withAnimation(.easeOut(duration: 0.25)) { showResult = true }
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

    // MARK: - 削除ゾーン

    private var deleteZone: some View {
        let isActive = deletingMemoID != nil && deleteOffset < -30
        return ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(isActive ? Color.red.opacity(0.2) : Color.red.opacity(0.04))
                .animation(.easeOut(duration: 0.15), value: isActive)
            HStack(spacing: 6) {
                Image(systemName: "arrow.up")
                    .font(.system(size: isActive ? 22 : 14, weight: .bold))
                Text("削除")
                    .font(.system(size: isActive ? 18 : 13, weight: .bold, design: .rounded))
            }
            .foregroundStyle(isActive ? .red : .red.opacity(0.25))
            .animation(.easeOut(duration: 0.15), value: isActive)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - タイトル（枠付き）

    private var titleArea: some View {
        HStack {
            if isEditingTitle {
                TextField("タイトルを入力", text: $editingTitle)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .onSubmit { isEditingTitle = false; applyTitleEdit() }
            } else {
                Text(editingTitle.isEmpty ? "タイトルなし" : editingTitle)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(editingTitle.isEmpty ? Color.secondary.opacity(0.4) : Color.primary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary.opacity(0.4))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(uiColor: .systemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.15), lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { if !isEditingTitle { isEditingTitle = true } }
    }

    // MARK: - 本文閲覧/編集（全画面モーダル）

    private var contentEditorView: some View {
        NavigationStack {
            TextEditor(text: $editingContent)
                .font(.system(size: 15))
                .padding(.horizontal, 8)
                .navigationTitle(editingTitle.isEmpty ? "本文" : editingTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("戻る") { showContentEditor = false }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("確定") { applyContentEdit(); showContentEditor = false }
                            .font(.system(size: 15, weight: .bold))
                    }
                }
        }
    }

    // MARK: - タグ表示

    @ViewBuilder
    private func currentTagsBar(memo: Memo) -> some View {
        HStack(spacing: 6) {
            ForEach(memo.tags, id: \.id) { tag in
                HStack(spacing: 4) {
                    Circle().fill(tagColor(for: tag.colorIndex)).frame(width: 8, height: 8)
                    Text(tag.name).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(tagColor(for: tag.colorIndex).opacity(0.15)))
            }
            if memo.tags.isEmpty {
                Text("タグなし")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.gray.opacity(0.1)))
            }
            Spacer()
        }
    }

    // MARK: - サジェストパネル（枠付き）

    private var suggestPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !currentSuggestions.isEmpty {
                let dictSugs = currentSuggestions.filter { $0.kind == .dictMatch }
                let newSugs = currentSuggestions.filter { $0.kind == .newTag }
                let histSugs = currentSuggestions.filter { $0.kind == .history }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("タグの提案")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 6)

                    if !dictSugs.isEmpty { suggestSection(title: "おすすめ", icon: "tag.fill", items: dictSugs) }
                    if !newSugs.isEmpty { suggestSection(title: "新規タグ", icon: "plus.circle.fill", items: newSugs) }
                    if !histSugs.isEmpty { suggestSection(title: "履歴", icon: "clock.fill", items: histSugs) }
                }
                .padding(.bottom, 6)
                .background(Color(uiColor: .secondarySystemBackground).opacity(0.9))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
    }

    @ViewBuilder
    private func suggestSection(title: String, icon: String, items: [TagSuggestEngine.Suggestion]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 9)).foregroundStyle(.secondary)
                Text(title).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)

            ForEach(items) { suggestion in
                Button { applySuggestion(suggestion) } label: {
                    HStack(spacing: 4) {
                        if suggestion.kind == .newTag {
                            Image(systemName: "plus.circle.fill").font(.system(size: 12)).foregroundStyle(.green)
                        } else if let pt = tags.first(where: { $0.id == suggestion.parentID }) {
                            Circle().fill(tagColor(for: pt.colorIndex)).frame(width: 8, height: 8)
                        }
                        Text(suggestion.parentName).font(.system(size: 13, weight: .semibold)).foregroundStyle(.primary)
                        if let cn = suggestion.childName {
                            Image(systemName: "chevron.right").font(.system(size: 8)).foregroundStyle(.tertiary)
                            Text(cn).font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(suggestion.kind == .newTag ? Color.green.opacity(0.08) : Color(uiColor: .systemBackground).opacity(0.95))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - ルーレット（右下）

    private var dialArea: some View {
        let parentTags = tags.filter { $0.parentTagID == nil }.sorted { $0.sortOrder < $1.sortOrder }
        let childTags: [Tag] = {
            guard let pid = selectedParentTagID else { return [] }
            return tags.filter { $0.parentTagID == pid }.sorted { $0.name < $1.name }
        }()
        let parentOptions: [(id: String, name: String, color: Color)] =
            [("none", "タグなし", Color(white: 0.82))] +
            parentTags.map { ($0.id.uuidString, $0.name, tagColor(for: $0.colorIndex)) }
        let childOptions: [(id: String, name: String, color: Color)] =
            childTags.isEmpty ? [] :
            [("none", "子タグなし", Color(white: 0.82))] +
            childTags.map { ($0.id.uuidString, $0.name, tagColor(for: $0.colorIndex)) }

        return TagDialView(
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
        .onChange(of: childOptions.count) { _, newCount in
            if newCount > 0 { showChildDial = true }
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
                            .font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(2)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("復元") {
                            if let idx = deleteQueue.firstIndex(where: { $0.id == memo.id }) {
                                deleteQueue.remove(at: idx)
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
                    Button("戻る") { showDeleteReview = false; showResult = true }
                }
            }
        }
    }

    // MARK: - アクション

    // 現在のメモ情報をローカル編集状態に同期
    private func syncEditingState(for memo: Memo) {
        editingTitle = memo.title
        editingContent = memo.content
        isEditingTitle = false

        isInternalTagChange = true
        let parentTag = memo.tags.first(where: { $0.parentTagID == nil })
        let childTag = memo.tags.first(where: { $0.parentTagID != nil })
        selectedParentTagID = parentTag?.id
        selectedChildTagID = childTag?.id
        if parentTag != nil {
            let hasChildren = tags.contains(where: { $0.parentTagID == parentTag?.id })
            if hasChildren { showChildDial = true }
        }
        isInternalTagChange = false

        updateSuggestions()
        prefetchSuggestions()
    }

    private func saveCurrent() {
        guard let memo = currentMemo else { return }
        let origTitle = memo.title
        let origContent = memo.content
        memo.title = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        memo.content = editingContent
        if memo.title != origTitle && !memo.title.isEmpty { titledMemoIDs.insert(memo.id) }
        if memo.content != origContent { editedMemoIDs.insert(memo.id) }
        memo.updatedAt = Date()
        isEditingTitle = false
    }

    private func deleteMemo(_ memo: Memo) {
        // 前のメモを保存してから
        saveCurrent()
        deleteQueue.append(memo)
        // カルーセルが自動で隣のカードを表示する
        // scrolledMemoIDが削除されたカードを指していたら次のに移る
        if scrolledMemoID == memo.id {
            let remaining = activeMemos
            if let first = remaining.first {
                scrolledMemoID = first.id
                syncEditingState(for: first)
            }
        }
        if activeMemos.isEmpty {
            withAnimation(.easeOut(duration: 0.25)) { showResult = true }
        }
    }

    private func applyTagFromDial() {
        guard let memo = currentMemo else { return }
        let originalTags = Set(memo.tags.map { $0.id })
        memo.tags.removeAll()
        if let pid = selectedParentTagID, let tag = tags.first(where: { $0.id == pid }) { memo.tags.append(tag) }
        if let cid = selectedChildTagID, let tag = tags.first(where: { $0.id == cid }) { memo.tags.append(tag) }
        memo.updatedAt = Date()
        let newTags = Set(memo.tags.map { $0.id })
        if originalTags != newTags {
            taggedMemoIDs.insert(memo.id)
            suggestEngine.learn(title: memo.title, body: memo.content, tagIDs: memo.tags.map { $0.id }, context: modelContext)
        }
    }

    private func applySuggestion(_ suggestion: TagSuggestEngine.Suggestion) {
        if suggestion.kind == .newTag { return }
        isInternalTagChange = true
        selectedParentTagID = suggestion.parentID
        selectedChildTagID = suggestion.childID
        isInternalTagChange = false
        applyTagFromDial()
    }

    private func applyTitleEdit() {
        guard let memo = currentMemo else { return }
        let newTitle = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if newTitle != memo.title {
            memo.title = newTitle
            memo.updatedAt = Date()
            if !newTitle.isEmpty { titledMemoIDs.insert(memo.id) }
        }
    }

    private func applyContentEdit() {
        guard let memo = currentMemo else { return }
        if editingContent != memo.content {
            memo.content = editingContent
            memo.updatedAt = Date()
            editedMemoIDs.insert(memo.id)
        }
    }

    // MARK: - サジェスト

    private func updateSuggestions() {
        guard let memo = currentMemo else { currentSuggestions = []; return }
        let idx = targetMemos.firstIndex(where: { $0.id == memo.id }) ?? 0
        if let cached = suggestCache[idx] { currentSuggestions = cached; return }
        let result = suggestEngine.suggest(title: memo.title, body: memo.content, tags: tags, context: modelContext, limit: 3)
        currentSuggestions = result
        suggestCache[idx] = result
    }

    private func prefetchSuggestions() {
        guard let memo = currentMemo else { return }
        let idx = targetMemos.firstIndex(where: { $0.id == memo.id }) ?? 0
        let lo = max(0, idx - 2)
        let hi = min(targetMemos.count - 1, idx + 3)
        guard lo <= hi else { return }
        for i in lo...hi where suggestCache[i] == nil {
            let m = targetMemos[i]
            if !deleteQueue.contains(where: { $0.id == m.id }) {
                suggestCache[i] = suggestEngine.suggest(title: m.title, body: m.content, tags: tags, context: modelContext, limit: 3)
            }
        }
    }
}
