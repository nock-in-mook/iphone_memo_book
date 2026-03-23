import SwiftUI
import SwiftData

// ToDoリスト一覧画面
struct TodoListsView: View {
    let onDismiss: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoList.updatedAt, order: .reverse) private var todoLists: [TodoList]

    // 新規リスト作成ダイアログ
    @State private var showNewListDialog = false
    @State private var newListTitle = ""
    @FocusState private var isNewListTitleFocused: Bool

    // 選択中のリスト（編集画面へ遷移）
    @State private var selectedList: TodoList?

    var body: some View {
        ZStack {
            NavigationStack {
                Group {
                    if todoLists.isEmpty {
                        emptyView
                    } else {
                        listView
                    }
                }
                .navigationTitle("ToDoリスト")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("閉じる") {
                            onDismiss()
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showNewListDialog = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .fullScreenCover(item: $selectedList) { list in
                    TodoListView(todoList: list) {
                        selectedList = nil
                    }
                }
            }

            // ダイアログはNavigationStackの外（キーボードの影響を受けない）
            if showNewListDialog {
                newListDialogOverlay
            }
        }
    }

    // MARK: - 空のとき
    private var emptyView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.4))

            Text("ToDoリストはまだありません")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)

            Button {
                showNewListDialog = true
            } label: {
                Label("リストを作成", systemImage: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue)
                    )
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - リスト一覧
    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(todoLists) { list in
                    listCard(list)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }

    // MARK: - リストカード
    @ViewBuilder
    private func listCard(_ list: TodoList) -> some View {
        Button {
            selectedList = list
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "checklist")
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(list.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)

                    Text(itemSummary(for: list))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                deleteList(list)
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }

    // MARK: - リスト内の項目サマリ
    private func itemSummary(for list: TodoList) -> String {
        // @Queryでは動的フィルタできないので、modelContextで取得
        let listID = list.id
        let descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { $0.listID == listID }
        )
        let items = (try? modelContext.fetch(descriptor)) ?? []
        let total = items.count
        let done = items.filter(\.isDone).count
        if total == 0 {
            return "項目なし"
        }
        return "\(done)/\(total) 完了"
    }

    // MARK: - 新規リスト作成ダイアログ（リッチ版）
    private var newListDialogOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showNewListDialog = false
                        newListTitle = ""
                    }
                }

            VStack(spacing: 0) {
                // ヘッダー（アイコン＋タイトル＋説明）
                VStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .font(.system(size: 32))
                        .foregroundStyle(.blue)

                    Text("新しいリスト")
                        .font(.system(size: 17, weight: .bold, design: .rounded))

                    Text("リストのタイトルを入力してください")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)
                .padding(.bottom, 16)
                .padding(.horizontal, 20)

                // テキスト入力
                TextField("例: 買い物リスト", text: $newListTitle)
                    .font(.system(size: 16))
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(uiColor: .tertiarySystemFill))
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .focused($isNewListTitleFocused)
                    .onSubmit {
                        createList()
                    }
                    .onAppear {
                        isNewListTitleFocused = true
                    }

                Divider()

                // 作成ボタン
                Button {
                    createList()
                } label: {
                    Text("作成する")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(newListTitle.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .disabled(newListTitle.trimmingCharacters(in: .whitespaces).isEmpty)

                Divider()

                // キャンセルボタン
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showNewListDialog = false
                        newListTitle = ""
                    }
                } label: {
                    Text("キャンセル")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.2), radius: 16, y: 6)
            .padding(.horizontal, 40)
        }
        .ignoresSafeArea(.keyboard)
        .transition(.opacity)
    }

    // MARK: - リスト作成
    private func createList() {
        let trimmed = newListTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let list = TodoList(title: trimmed)
        modelContext.insert(list)
        try? modelContext.save()
        newListTitle = ""
        withAnimation(.easeInOut(duration: 0.2)) {
            showNewListDialog = false
        }
        // 作成後すぐに開く
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            selectedList = list
        }
    }

    // MARK: - リスト削除（中の項目も削除）
    private func deleteList(_ list: TodoList) {
        let listID = list.id
        let descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { $0.listID == listID }
        )
        if let items = try? modelContext.fetch(descriptor) {
            for item in items {
                modelContext.delete(item)
            }
        }
        modelContext.delete(list)
        try? modelContext.save()
    }
}
