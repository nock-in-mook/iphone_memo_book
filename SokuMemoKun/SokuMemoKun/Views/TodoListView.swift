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
    let onDismiss: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoItem.sortOrder) private var allItems: [TodoItem]

    // リストタイトル
    @State private var listTitle = ""
    @FocusState private var isTitleFocused: Bool

    // 新規項目入力用（ルートレベル）
    @State private var newItemText = ""
    @FocusState private var isNewItemFocused: Bool
    // 子項目入力用
    @State private var newChildTexts: [UUID: String] = [:]
    @FocusState private var focusedAddField: String?

    // 展開中の項目（子を表示中）
    @State private var expandedItems: Set<UUID> = []

    // 編集中の項目
    @State private var editingItemID: UUID?
    @State private var editingText: String = ""
    @FocusState private var isEditingFocused: Bool

    // スワイプ削除
    @State private var swipedItemID: UUID?
    @State private var swipeOffset: CGFloat = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // タイトル入力
                TextField("リストのタイトル", text: $listTitle)
                    .font(.system(size: 22, weight: .bold))
                    .focused($isTitleFocused)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                Divider()
                    .padding(.horizontal, 16)

                // ToDoリスト（フラット化して表示）
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(flatRows) { row in
                            switch row.kind {
                            case .item(let item):
                                todoRow(item: item, depth: row.depth)
                            case .addButton(let parentID):
                                addItemRow(parentID: parentID, depth: row.depth, rowID: row.id)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                .onTapGesture {
                    // 編集中なら確定、スワイプ状態ならリセット
                    if let editID = editingItemID,
                       let item = allItems.first(where: { $0.id == editID }) {
                        commitEdit(item: item)
                    }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        swipedItemID = nil
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") {
                        onDismiss()
                    }
                }
            }
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

        // ルートレベルの追加行
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
            // 子の追加行
            rows.append(FlatRow(id: "add-\(item.id.uuidString)", kind: .addButton(parentID: item.id), depth: depth + 1))
        }
    }

    // MARK: - 子を持っているか
    private func hasChildren(_ itemID: UUID) -> Bool {
        allItems.contains { $0.parentID == itemID }
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
                    .frame(width: 70, height: .infinity)
                    .frame(maxHeight: .infinity)
            }
            .background(Color.red)

            // メインコンテンツ
            HStack(spacing: 8) {
                // ツリーライン（インデント）
                if depth > 0 {
                    HStack(spacing: 0) {
                        ForEach(0..<depth, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.secondary.opacity(0.15))
                                .frame(width: 1)
                                .padding(.horizontal, 10)
                        }
                    }
                    .frame(width: CGFloat(depth) * 22)
                }

                // チェックボックス
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        item.isDone.toggle()
                        item.updatedAt = Date()
                        try? modelContext.save()
                    }
                } label: {
                    Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(item.isDone ? .green : .secondary.opacity(0.5))
                }
                .buttonStyle(.plain)

                // タイトル（通常表示 or インライン編集）
                if isEditing {
                    TextField("", text: $editingText)
                        .font(.system(size: 16))
                        .focused($isEditingFocused)
                        .onSubmit {
                            commitEdit(item: item)
                        }
                        .onAppear {
                            isEditingFocused = true
                        }
                } else {
                    Text(item.title)
                        .font(.system(size: 16))
                        .strikethrough(item.isDone, color: .secondary)
                        .foregroundStyle(item.isDone ? .secondary : .primary)
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
                                focusedAddField = "add-\(item.id.uuidString)"
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
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color(UIColor.systemBackground))
            .offset(x: isSwiped ? -70 : 0)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        // 左スワイプのみ
                        if value.translation.width < 0 {
                            // 他の項目のスワイプをリセット
                            if swipedItemID != item.id {
                                swipedItemID = nil
                            }
                        }
                    }
                    .onEnded { value in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if value.translation.width < -50 {
                                swipedItemID = item.id
                            } else {
                                swipedItemID = nil
                            }
                        }
                    }
            )
        }
        .clipped()
        .contextMenu {
            Button {
                startEditing(item: item)
            } label: {
                Label("編集", systemImage: "pencil")
            }
            Button {
                moveItem(item, direction: .up)
            } label: {
                Label("上へ移動", systemImage: "arrow.up")
            }
            Button {
                moveItem(item, direction: .down)
            } label: {
                Label("下へ移動", systemImage: "arrow.down")
            }
            Divider()
            Button(role: .destructive) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    deleteItem(item)
                }
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }

    // MARK: - 追加行（「+ 項目を追加」）
    @ViewBuilder
    private func addItemRow(parentID: UUID?, depth: Int, rowID: String) -> some View {
        HStack(spacing: 8) {
            // ツリーライン（インデント）
            if depth > 0 {
                HStack(spacing: 0) {
                    ForEach(0..<depth, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(width: 1)
                            .padding(.horizontal, 10)
                    }
                }
                .frame(width: CGFloat(depth) * 22)
            }

            Image(systemName: "plus")
                .font(.system(size: 14))
                .foregroundStyle(.secondary.opacity(0.4))

            if parentID == nil {
                // ルートレベルの入力
                TextField("項目を追加", text: $newItemText)
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .focused($isNewItemFocused)
                    .onSubmit {
                        addItem(title: newItemText, parentID: nil)
                        newItemText = ""
                        isNewItemFocused = true
                    }
            } else {
                // 子レベルの入力
                let binding = Binding<String>(
                    get: { newChildTexts[parentID!] ?? "" },
                    set: { newChildTexts[parentID!] = $0 }
                )
                TextField("項目を追加", text: binding)
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .focused($focusedAddField, equals: rowID)
                    .onSubmit {
                        addItem(title: binding.wrappedValue, parentID: parentID)
                        newChildTexts[parentID!] = ""
                        focusedAddField = rowID
                    }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
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

    // MARK: - 項目の並び替え
    private enum MoveDirection { case up, down }

    private func moveItem(_ item: TodoItem, direction: MoveDirection) {
        // 同階層の兄弟を取得（sortOrder順）
        var siblings = allItems
            .filter { $0.parentID == item.parentID }
            .sorted { $0.sortOrder < $1.sortOrder }

        guard let index = siblings.firstIndex(where: { $0.id == item.id }) else { return }

        let targetIndex: Int
        switch direction {
        case .up:
            guard index > 0 else { return }
            targetIndex = index - 1
        case .down:
            guard index < siblings.count - 1 else { return }
            targetIndex = index + 1
        }

        // スワップ
        siblings.swapAt(index, targetIndex)

        // sortOrderを振り直し
        withAnimation(.easeInOut(duration: 0.2)) {
            for (i, sibling) in siblings.enumerated() {
                sibling.sortOrder = i
                sibling.updatedAt = Date()
            }
            try? modelContext.save()
        }
    }

    // MARK: - インライン編集開始
    private func startEditing(item: TodoItem) {
        editingItemID = item.id
        editingText = item.title
    }

    // MARK: - 編集確定
    private func commitEdit(item: TodoItem) {
        let trimmed = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            item.title = trimmed
            item.updatedAt = Date()
            try? modelContext.save()
        }
        editingItemID = nil
        editingText = ""
    }

    // MARK: - 項目を追加
    private func addItem(title: String, parentID: UUID?) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // 同階層の最大sortOrderを取得
        let siblings = allItems.filter { $0.parentID == parentID }
        let maxOrder = siblings.map(\.sortOrder).max() ?? -1

        let item = TodoItem(title: trimmed, parentID: parentID, sortOrder: maxOrder + 1)
        modelContext.insert(item)
        try? modelContext.save()

        // 親がある場合は展開状態を維持
        if let parentID = parentID {
            expandedItems.insert(parentID)
        }
    }
}
