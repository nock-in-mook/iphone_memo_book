import SwiftUI
import SwiftData

// ツリーをフラット化した表示用の行データ
private struct FlatRow: Identifiable {
    enum Kind {
        case item(TodoItem)
        case addButton(parentID: UUID?) // 「+ 項目を追加」行
    }
    let id: String
    let kind: Kind
    let depth: Int
}

struct TodoListView: View {
    let todoList: TodoList
    let onDismiss: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoItem.sortOrder) private var queryItems: [TodoItem]

    // このリストに属する項目のみ
    private var allItems: [TodoItem] {
        queryItems.filter { $0.listID == todoList.id }
    }

    // 展開中の項目（子を表示中）
    @State private var expandedItems: Set<UUID> = []

    // 編集中の項目
    @State private var editingItemID: UUID?
    @State private var editingText: String = ""
    @State private var isAddingNewItems = false  // 連続追加モード中か
    @FocusState private var isEditingFocused: Bool

    // スワイプ削除
    @State private var swipedItemID: UUID?
    @State private var swipeOffset: CGFloat = 0

    // ドラッグ並び替え（ForEachの順序は変えず、オフセットだけで表現）
    @State private var draggingItemID: UUID?
    @State private var dragTranslation: CGFloat = 0
    @State private var dragParentID: UUID?
    @State private var dragOriginalIndex: Int = 0
    private let estimatedRowHeight: CGFloat = 48

    // 進捗情報
    private var totalCount: Int { allItems.count }
    private var doneCount: Int { allItems.filter(\.isDone).count }
    private var progress: Double {
        totalCount == 0 ? 0 : Double(doneCount) / Double(totalCount)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // リッチヘッダー
                headerView

                Divider()
                    .padding(.horizontal, 16)

                if allItems.isEmpty {
                    // 空状態
                    emptyStateView
                } else {
                    // ToDoリスト（フラット化して表示）
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(flatRows) { row in
                                switch row.kind {
                                case .item(let item):
                                    todoRow(item: item, depth: row.depth)
                                        .zIndex(draggingItemID == item.id ? 10 : 0)
                                case .addButton(let parentID):
                                    addItemRow(parentID: parentID, depth: row.depth, rowID: row.id)
                                }
                            }
                            // ヒント
                            if allItems.count > 0 {
                                HStack(spacing: 5) {
                                    Image(systemName: "hand.tap")
                                        .font(.system(size: 12))
                                    Text("タップで編集 ・ 長押しで並び替え ・ 左スワイプで削除")
                                        .font(.system(size: 13))
                                }
                                .foregroundStyle(.secondary.opacity(0.4))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 4)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .onTapGesture {
                        if let editID = editingItemID,
                           let item = allItems.first(where: { $0.id == editID }) {
                            commitEdit(item: item)
                        }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            swipedItemID = nil
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("戻る") {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 5) {
                        Image(systemName: "checklist")
                            .font(.system(size: 14))
                            .foregroundStyle(.green)
                        Text("ToDoリスト")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                }
            }
        }
    }

    // MARK: - リッチヘッダー
    private var headerView: some View {
        HStack(spacing: 10) {
            // リストアイコン
            Image(systemName: "bookmark.fill")
                .font(.system(size: 24))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(todoList.title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))

                if totalCount > 0 {
                    Text("\(doneCount)/\(totalCount) 完了")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // 円グラフ（ドーナツ型）
            if totalCount > 0 {
                ZStack {
                    // 背景リング
                    Circle()
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 4)

                    // 進捗リング
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            progress >= 1.0 ? Color.green : Color.blue,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: progress)

                    // パーセント表示
                    VStack(spacing: -1) {
                        Text("\(Int(progress * 100))")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                        Text("%")
                            .font(.system(size: 7, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(progress >= 1.0 ? .green : .primary)
                }
                .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - 空状態
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "text.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(.secondary.opacity(0.3))

            Text("項目を追加してみましょう")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)

            Button {
                addEmptyItemAndEdit(parentID: nil)
            } label: {
                Label("最初の項目を追加", systemImage: "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    )
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - ツリーをフラット化
    private var flatRows: [FlatRow] {
        var rows: [FlatRow] = []
        let roots = allItems
            .filter { $0.parentID == nil }
            .sorted { $0.sortOrder < $1.sortOrder }

        for item in roots {
            appendRows(for: item, depth: 0, into: &rows)
        }

        // ルートレベルの追加ボタン
        rows.append(FlatRow(id: "add-root", kind: .addButton(parentID: nil), depth: 0))
        return rows
    }

    private func appendRows(for item: TodoItem, depth: Int, into rows: inout [FlatRow]) {
        rows.append(FlatRow(id: item.id.uuidString, kind: .item(item), depth: depth))

        let isExpanded = expandedItems.contains(item.id)
        if isExpanded {
            let kids = allItems
                .filter { $0.parentID == item.id }
                .sorted { $0.sortOrder < $1.sortOrder }
            for child in kids {
                appendRows(for: child, depth: depth + 1, into: &rows)
            }
            // 子の追加ボタン
            rows.append(FlatRow(id: "add-\(item.id.uuidString)", kind: .addButton(parentID: item.id), depth: depth + 1))
        }
    }

    // MARK: - 子を持っているか
    private func hasChildren(_ itemID: UUID) -> Bool {
        allItems.contains { $0.parentID == itemID }
    }

    // MARK: - 帯の左インデント量（ベース12ptでタイトルからインデント）
    private func indentLeading(_ depth: Int) -> CGFloat {
        12 + CGFloat(depth) * 24
    }

    // MARK: - ToDo行
    @ViewBuilder
    private func todoRow(item: TodoItem, depth: Int) -> some View {
        let isExpanded = expandedItems.contains(item.id)
        let hasKids = hasChildren(item.id)
        let isSwiped = swipedItemID == item.id
        let isEditing = editingItemID == item.id

        ZStack(alignment: .trailing) {
            // 削除ボタン（スワイプで露出）
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    deleteItem(item)
                    swipedItemID = nil
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .frame(width: 70)
                    .frame(maxHeight: .infinity)
            }
            .background(Color.red)

            // メインコンテンツ（帯スタイル）
            HStack(spacing: 8) {
                // チェックボックス（ここだけがチェックトグル）
                Button {
                    item.isDone.toggle()
                    item.updatedAt = Date()
                    try? modelContext.save()
                } label: {
                    Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(item.isDone ? .green : .secondary.opacity(0.5))
                        .animation(.easeInOut(duration: 0.2), value: item.isDone)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // タイトル（通常表示 or インライン編集）
                if isEditing {
                    TextField("項目を入力", text: $editingText)
                        .font(.system(size: 16))
                        .focused($isEditingFocused)
                        .onSubmit {
                            submitEdit(item: item)
                        }
                        .onAppear {
                            isEditingFocused = true
                        }
                } else {
                    Text(item.title)
                        .font(.system(size: 16))
                        .strikethrough(item.isDone, color: .secondary)
                        .foregroundStyle(item.isDone ? .secondary : .primary)
                        .animation(.easeInOut(duration: 0.2), value: item.isDone)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            startEditing(item: item)
                        }
                }

                // 展開/折りたたみ矢印
                if hasKids {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if isExpanded {
                                expandedItems.remove(item.id)
                            } else {
                                expandedItems.insert(item.id)
                            }
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary.opacity(0.5))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if isExpanded {
                                expandedItems.remove(item.id)
                            } else {
                                expandedItems.insert(item.id)
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary.opacity(0.2))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(item.isDone
                          ? Color.green.opacity(0.08)
                          : Color(UIColor.secondarySystemBackground))
            )
            .padding(.leading, 16 + indentLeading(depth))
            .padding(.trailing, 16)
            .background(Color(UIColor.systemBackground))
            .offset(x: isSwiped ? -70 : 0)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        guard draggingItemID == nil else { return }
                        if value.translation.width < 0 {
                            if swipedItemID != item.id {
                                swipedItemID = nil
                            }
                        }
                    }
                    .onEnded { value in
                        guard draggingItemID == nil else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if value.translation.width < -50 {
                                swipedItemID = item.id
                            } else {
                                swipedItemID = nil
                            }
                        }
                    }
            )
            // 長押し＋ドラッグで並び替え
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.4)
                    .sequenced(before: DragGesture())
                    .onChanged { value in
                        switch value {
                        case .second(true, let drag):
                            if draggingItemID == nil {
                                draggingItemID = item.id
                                dragParentID = item.parentID
                                dragTranslation = 0
                                let siblings = allItems
                                    .filter { $0.parentID == item.parentID }
                                    .sorted { $0.sortOrder < $1.sortOrder }
                                dragOriginalIndex = siblings.firstIndex(where: { $0.id == item.id }) ?? 0
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                // 編集中なら確定
                                if let editID = editingItemID,
                                   let editItem = allItems.first(where: { $0.id == editID }) {
                                    commitEdit(item: editItem)
                                }
                                swipedItemID = nil
                            }
                            if let drag {
                                dragTranslation = drag.translation.height
                            }
                        default: break
                        }
                    }
                    .onEnded { _ in
                        commitReorder()
                        draggingItemID = nil
                        dragTranslation = 0
                        dragParentID = nil
                    }
            )
        }
        .clipped()
        // ドラッグ中: ドラッグ行は指に追従、他の行はシフトして空きを作る
        .offset(y: dragYOffset(for: item))
        .opacity(draggingItemID == item.id ? 0.85 : 1.0)
        .scaleEffect(draggingItemID == item.id ? 1.04 : 1.0)
        .shadow(color: draggingItemID == item.id ? .black.opacity(0.2) : .clear, radius: 10, y: 4)
        .animation(.easeInOut(duration: 0.15), value: dragTargetIndex)
    }

    // MARK: - 追加ボタン
    @ViewBuilder
    private func addItemRow(parentID: UUID?, depth: Int, rowID: String) -> some View {
        Button {
            addEmptyItemAndEdit(parentID: parentID)
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.secondary.opacity(0.25))
        }
        .padding(.leading, 16 + indentLeading(depth) + 14)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 項目を削除（子も再帰的に削除）
    private func deleteItem(_ item: TodoItem) {
        // 子項目を再帰的に削除
        let children = allItems.filter { $0.parentID == item.id }
        for child in children {
            deleteItem(child)
        }
        modelContext.delete(item)
        try? modelContext.save()
    }

    // MARK: - ドラッグ並び替え（ForEach順序は不変、オフセットのみで表現）

    // ドラッグ先のインデックス（同階層内）
    private var dragTargetIndex: Int {
        guard draggingItemID != nil else { return -1 }
        let siblings = allItems
            .filter { $0.parentID == dragParentID }
            .sorted { $0.sortOrder < $1.sortOrder }
        let shift = Int(round(dragTranslation / estimatedRowHeight))
        return max(0, min(siblings.count - 1, dragOriginalIndex + shift))
    }

    // 各行のY方向オフセット
    private func dragYOffset(for item: TodoItem) -> CGFloat {
        guard let draggingID = draggingItemID else { return 0 }

        // ドラッグ中の行: 指に追従
        if item.id == draggingID {
            return dragTranslation
        }

        // 別階層の行: 動かさない
        guard item.parentID == dragParentID else { return 0 }

        let siblings = allItems
            .filter { $0.parentID == dragParentID }
            .sorted { $0.sortOrder < $1.sortOrder }

        guard let thisIndex = siblings.firstIndex(where: { $0.id == item.id }) else { return 0 }
        let target = dragTargetIndex

        // ドラッグ元より下にいて、ターゲットが自分以上の位置 → 上にずれる
        if dragOriginalIndex < thisIndex && target >= thisIndex {
            return -estimatedRowHeight
        }
        // ドラッグ元より上にいて、ターゲットが自分以下の位置 → 下にずれる
        if dragOriginalIndex > thisIndex && target <= thisIndex {
            return estimatedRowHeight
        }
        return 0
    }

    // ドロップ時: sortOrderを確定
    private func commitReorder() {
        guard let draggingID = draggingItemID else { return }
        var siblings = allItems
            .filter { $0.parentID == dragParentID }
            .sorted { $0.sortOrder < $1.sortOrder }

        guard let originalIndex = siblings.firstIndex(where: { $0.id == draggingID }) else { return }
        let target = dragTargetIndex

        if target != originalIndex {
            let item = siblings.remove(at: originalIndex)
            siblings.insert(item, at: target)
            for (i, sibling) in siblings.enumerated() {
                sibling.sortOrder = i
                sibling.updatedAt = Date()
            }
            try? modelContext.save()
        }
    }

    // MARK: - インライン編集開始（既存項目をタップ）
    private func startEditing(item: TodoItem) {
        // 連続追加モード中に別の項目をタップ → 空の新規項目を片付ける
        if isAddingNewItems, let editID = editingItemID,
           let editItem = allItems.first(where: { $0.id == editID }),
           editItem.title.isEmpty {
            deleteItem(editItem)
        }
        isAddingNewItems = false
        editingItemID = item.id
        editingText = item.title
    }

    // MARK: - Enter押下時（連続追加 or 通常確定）
    private func submitEdit(item: TodoItem) {
        let trimmed = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        let parentID = item.parentID

        if isAddingNewItems {
            if trimmed.isEmpty {
                // 空Enter → 空行を削除して連続追加終了
                deleteItem(item)
                editingItemID = nil
                editingText = ""
                isAddingNewItems = false
            } else {
                // 確定して次の空行へ
                item.title = trimmed
                item.updatedAt = Date()
                try? modelContext.save()
                editingItemID = nil
                editingText = ""
                addEmptyItemAndEdit(parentID: parentID)
            }
        } else {
            // 既存項目の編集確定
            commitEdit(item: item)
        }
    }

    // MARK: - 編集確定（タップで離脱時）
    private func commitEdit(item: TodoItem) {
        let trimmed = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if isAddingNewItems && trimmed.isEmpty {
            // 連続追加中に空のまま離脱 → 空項目を削除
            deleteItem(item)
        } else if !trimmed.isEmpty {
            item.title = trimmed
            item.updatedAt = Date()
            try? modelContext.save()
        }
        editingItemID = nil
        editingText = ""
        isAddingNewItems = false
    }

    // MARK: - 空の項目を作成して即編集開始
    private func addEmptyItemAndEdit(parentID: UUID?) {
        let siblings = allItems.filter { $0.parentID == parentID }
        let maxOrder = siblings.map(\.sortOrder).max() ?? -1

        let item = TodoItem(title: "", listID: todoList.id, parentID: parentID, sortOrder: maxOrder + 1)
        item.tags = [getOrCreateTodoTag()]
        modelContext.insert(item)
        try? modelContext.save()

        if let parentID = parentID {
            expandedItems.insert(parentID)
        }

        isAddingNewItems = true
        editingItemID = item.id
        editingText = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isEditingFocused = true
        }
    }

    // MARK: - TODOシステムタグの取得or作成
    private func getOrCreateTodoTag() -> Tag {
        // isSystemフラグで検索（名前衝突を回避）
        let descriptor = FetchDescriptor<Tag>(
            predicate: #Predicate { $0.isSystem == true }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        let tag = Tag(name: "TODO", colorIndex: 0, isSystem: true)
        modelContext.insert(tag)
        try? modelContext.save()
        return tag
    }

    // MARK: - 項目を追加
    private func addItem(title: String, parentID: UUID?) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // 同階層の最大sortOrderを取得
        let siblings = allItems.filter { $0.parentID == parentID }
        let maxOrder = siblings.map(\.sortOrder).max() ?? -1

        let item = TodoItem(title: trimmed, listID: todoList.id, parentID: parentID, sortOrder: maxOrder + 1)
        // 「TODO」システムタグを自動付与
        item.tags = [getOrCreateTodoTag()]
        modelContext.insert(item)
        try? modelContext.save()

        // 親がある場合は展開状態を維持
        if let parentID = parentID {
            expandedItems.insert(parentID)
        }
    }
}
