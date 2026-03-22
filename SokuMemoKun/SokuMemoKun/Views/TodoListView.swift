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

            // タイトル
            Text(item.title)
                .font(.system(size: 16))
                .strikethrough(item.isDone, color: .secondary)
                .foregroundStyle(item.isDone ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 展開/折りたたみ矢印
            if hasKids {
                // 子がある → 展開/折りたたみ
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
                // 子がない → タップで展開して子追加モードに
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
