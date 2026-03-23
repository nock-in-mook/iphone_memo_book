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
    let isLastChild: Bool  // 同階層の最後の子か
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
                    // ToDoリスト（Listベース: スワイプ・スクロール・リオーダー全対応）
                    ScrollViewReader { proxy in
                        List {
                            ForEach(flatRows) { row in
                                switch row.kind {
                                case .item(let item):
                                    todoRow(item: item, depth: row.depth, isLastChild: row.isLastChild)
                                        .id(item.id)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                withAnimation {
                                                    deleteItem(item)
                                                }
                                            } label: {
                                                Label("削除", systemImage: "trash")
                                            }
                                        }
                                case .addButton(let parentID):
                                    addItemRow(parentID: parentID, depth: row.depth, rowID: row.id)
                                        .id(row.id)
                                }
                            }
                            .onMove(perform: moveFlatRows)
                            // ヒント
                            if allItems.count > 0 {
                                HStack(spacing: 5) {
                                    Image(systemName: "hand.tap")
                                        .font(.system(size: 12))
                                    Text("タップで編集 ・ 長押しでメニュー ・ 左スワイプで削除")
                                        .font(.system(size: 13))
                                }
                                .foregroundStyle(.secondary.opacity(0.4))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 4)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets())
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .scrollDismissesKeyboard(.interactively)
                        .onChange(of: editingItemID) { _, newID in
                            if let id = newID {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        proxy.scrollTo(id, anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("戻る") {
                        cleanupEmptyItems()
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if editingItemID != nil {
                        Button("完了") {
                            if let editID = editingItemID,
                               let item = allItems.first(where: { $0.id == editID }) {
                                commitEdit(item: item)
                            }
                        }
                        .fontWeight(.semibold)
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
        .onAppear {
            cleanupEmptyItems()
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

        for (i, item) in roots.enumerated() {
            appendRows(for: item, depth: 0, isLast: i == roots.count - 1, into: &rows)
        }

        // ルートレベルの追加ボタン
        rows.append(FlatRow(id: "add-root", kind: .addButton(parentID: nil), depth: 0, isLastChild: true))
        return rows
    }

    private func appendRows(for item: TodoItem, depth: Int, isLast: Bool, into rows: inout [FlatRow]) {
        rows.append(FlatRow(id: item.id.uuidString, kind: .item(item), depth: depth, isLastChild: isLast))

        let isExpanded = expandedItems.contains(item.id)
        if isExpanded {
            let kids = allItems
                .filter { $0.parentID == item.id }
                .sorted { $0.sortOrder < $1.sortOrder }
            for (i, child) in kids.enumerated() {
                appendRows(for: child, depth: depth + 1, isLast: i == kids.count - 1, into: &rows)
            }
            // 子の追加ボタン
            rows.append(FlatRow(id: "add-\(item.id.uuidString)", kind: .addButton(parentID: item.id), depth: depth + 1, isLastChild: true))
        }
    }

    // MARK: - 子を持っているか
    private func hasChildren(_ itemID: UUID) -> Bool {
        allItems.contains { $0.parentID == itemID }
    }

    // MARK: - 帯の左インデント量
    private let indentBase: CGFloat = 12   // ルートのインデント
    private let indentStep: CGFloat = 28   // 階層ごとのインデント幅

    private func indentLeading(_ depth: Int) -> CGFloat {
        indentBase + CGFloat(depth) * indentStep
    }

    // MARK: - ToDo行
    @ViewBuilder
    private func todoRow(item: TodoItem, depth: Int, isLastChild: Bool = false) -> some View {
        let isExpanded = expandedItems.contains(item.id)
        let hasKids = hasChildren(item.id)
        let isEditing = editingItemID == item.id

        // メインコンテンツ（帯スタイル）
        HStack(spacing: 8) {
            // チェックボックス
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
        .padding(.leading, indentLeading(depth))
        // ツリーライン（子項目のみ）
        .overlay(alignment: .leading) {
            if depth > 0 {
                let lineX = indentLeading(depth) - indentStep / 2 + 16  // listRowInsetsのleading分を加算
                // 縦線（上から行の中央まで）+ 横線（行の中央へ）
                Canvas { context, size in
                    let midY = size.height / 2
                    var path = Path()
                    // 縦線: 上端から行中央まで（最後の子なら途中で止める）
                    path.move(to: CGPoint(x: lineX, y: 0))
                    path.addLine(to: CGPoint(x: lineX, y: midY))
                    // 横線: 左の縦線からカードの左端まで
                    path.move(to: CGPoint(x: lineX, y: midY))
                    path.addLine(to: CGPoint(x: lineX + indentStep / 2 - 4, y: midY))
                    context.stroke(path, with: .color(.secondary.opacity(0.2)), lineWidth: 1.5)

                    // 最後の子でなければ、縦線を下端まで延長
                    if !isLastChild {
                        var extPath = Path()
                        extPath.move(to: CGPoint(x: lineX, y: midY))
                        extPath.addLine(to: CGPoint(x: lineX, y: size.height))
                        context.stroke(extPath, with: .color(.secondary.opacity(0.2)), lineWidth: 1.5)
                    }
                }
                .allowsHitTesting(false)
            }
        }
        // List行スタイル除去
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
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
        .padding(.leading, indentLeading(depth) + 14)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
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

    // MARK: - ドラッグ並び替え（List .onMove）
    private func moveFlatRows(from source: IndexSet, to destination: Int) {
        // flatRowsからアイテム行だけ抽出（同階層のみ移動可能）
        var rows = flatRows
        rows.move(fromOffsets: source, toOffset: destination)

        // 移動されたアイテムの親を特定して、同階層のsortOrderを振り直す
        // ルートレベルのアイテムだけ抽出して順序更新
        let rootItems = rows.compactMap { row -> TodoItem? in
            if case .item(let item) = row.kind, item.parentID == nil {
                return item
            }
            return nil
        }
        for (i, item) in rootItems.enumerated() {
            item.sortOrder = i
            item.updatedAt = Date()
        }
        try? modelContext.save()
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

    // MARK: - 空の項目を作成して即編集開始（saveはしない＝確定まで永続化しない）
    private func addEmptyItemAndEdit(parentID: UUID?) {
        let siblings = allItems.filter { $0.parentID == parentID }
        let maxOrder = siblings.map(\.sortOrder).max() ?? -1

        let item = TodoItem(title: "", listID: todoList.id, parentID: parentID, sortOrder: maxOrder + 1)
        item.tags = [getOrCreateTodoTag()]
        modelContext.insert(item)
        // save()しない → 空のまま永続化されない

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

    // MARK: - 空タイトルの項目を一括削除
    private func cleanupEmptyItems() {
        let empties = allItems.filter { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        for item in empties {
            modelContext.delete(item)
        }
        if !empties.isEmpty {
            try? modelContext.save()
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
