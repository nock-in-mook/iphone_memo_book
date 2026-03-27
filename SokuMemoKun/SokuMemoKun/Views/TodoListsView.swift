import SwiftUI
import SwiftData

// ToDoリスト一覧画面
struct TodoListsView: View {
    let onDismiss: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoList.updatedAt, order: .reverse) private var todoLists: [TodoList]

    // ソート済みリスト（固定→通常、manualSortOrder→更新日）
    private var sortedLists: [TodoList] {
        todoLists.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            if a.manualSortOrder != b.manualSortOrder { return a.manualSortOrder < b.manualSortOrder }
            return a.updatedAt > b.updatedAt
        }
    }

    // 新規リスト作成ダイアログ
    @State private var showNewListDialog = false
    @State private var newListTitle = ""
    @FocusState private var isNewListTitleFocused: Bool

    // 選択中のリスト（編集画面へ遷移）
    @State private var selectedList: TodoList?

    // 削除確認ダイアログ
    @State private var pendingDeleteList: TodoList?
    @State private var showDeleteConfirm = false

    // TODOタブの緑色
    private let todoTabColor = Color(red: 0.55, green: 0.82, blue: 0.55)

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // ツールバー
                HStack {
                    Button("閉じる") {
                        onDismiss()
                    }
                    .font(.system(size: 16))
                    Spacer()
                    Button {
                        showNewListDialog = true
                    } label: {
                        Label("新規", systemImage: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.accentColor, lineWidth: 1.5)
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

                // TODOタブ
                HStack(spacing: 0) {
                    HStack(spacing: 6) {
                        Image(systemName: "checklist")
                            .font(.system(size: 14, weight: .bold))
                        Text("TODO")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        TrapezoidTabShape()
                            .fill(todoTabColor)
                            .shadow(color: .black.opacity(0.4), radius: 5, x: -3, y: 3)
                    )
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.top, 6)

                // コンテンツエリア（緑背景）
                ZStack {
                    todoTabColor.ignoresSafeArea(edges: .bottom)

                    if todoLists.isEmpty {
                        emptyView
                    } else {
                        listView
                    }
                }
            }
            .fullScreenCover(item: $selectedList) { list in
                TodoListView(todoList: list) {
                    selectedList = nil
                }
            }

            // ダイアログ
            if showNewListDialog {
                newListDialogOverlay
            }

            // 削除確認ダイアログ
            if showDeleteConfirm, let list = pendingDeleteList {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation { showDeleteConfirm = false }
                        }
                    VStack(spacing: 16) {
                        Text("「\(list.title)」を削除します")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .padding(.top, 4)
                        Text("リスト内の全タスクも削除されます")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.secondary)
                        VStack(spacing: 10) {
                            Button {
                                withAnimation {
                                    deleteList(list)
                                    pendingDeleteList = nil
                                    showDeleteConfirm = false
                                }
                            } label: {
                                Text("削除する")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.red.opacity(0.1))
                                    .foregroundStyle(.red)
                                    .cornerRadius(8)
                            }
                            Button {
                                withAnimation {
                                    pendingDeleteList = nil
                                    showDeleteConfirm = false
                                }
                            } label: {
                                Text("キャンセル")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(20)
                    .background(.regularMaterial)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                    .padding(.horizontal, 40)
                }
                .transition(.opacity)
            }
        }
    }

    // MARK: - 空のとき
    private var emptyView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.5))

            Text("ToDoリストはまだありません")
                .font(.system(size: 17, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))

            Button {
                showNewListDialog = true
            } label: {
                Label("リストを作成", systemImage: "plus")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(todoTabColor)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.white)
                            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                    )
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - リスト一覧（2列・高さバラバラ）
    private var listView: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 8) {
                // 左列（偶数インデックス）
                LazyVStack(spacing: 8) {
                    ForEach(Array(sortedLists.enumerated()).filter { $0.offset % 2 == 0 }, id: \.element.id) { _, list in
                        listCard(list)
                    }
                }
                // 右列（奇数インデックス）
                LazyVStack(spacing: 8) {
                    ForEach(Array(sortedLists.enumerated()).filter { $0.offset % 2 == 1 }, id: \.element.id) { _, list in
                        listCard(list)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
        }
    }

    // MARK: - リストカード（縦型・プレビュー付き）
    @ViewBuilder
    private func listCard(_ list: TodoList) -> some View {
        let rootItems = fetchRootItems(for: list)

        Button {
            selectedList = list
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                // ヘッダー（アイコン＋タイトル＋ドーナツ）
                HStack(spacing: 6) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.orange)

                    Text(list.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    // ミニドーナツ
                    let summary = fetchSummary(for: list)
                    if summary.total > 0 {
                        let prog = Double(summary.done) / Double(summary.total)
                        ZStack {
                            Circle()
                                .stroke(Color.secondary.opacity(0.15), lineWidth: 3)
                            if prog >= 1.0 {
                                // 全完了：レインボー
                                Circle()
                                    .stroke(
                                        AngularGradient(
                                            colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                                            center: .center
                                        ),
                                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                    )
                            } else {
                                Circle()
                                    .trim(from: 0, to: prog)
                                    .stroke(
                                        Color.blue,
                                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                    )
                                    .rotationEffect(.degrees(-90))
                            }
                            HStack(spacing: 0) {
                                Text("\(Int(prog * 100))")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                Text("%")
                                    .font(.system(size: 7, weight: .medium, design: .rounded))
                            }
                            .foregroundStyle(prog >= 1.0 ? .green : .primary)
                        }
                        .frame(width: 30, height: 30)
                    }
                }

                // ルート項目プレビュー（子項目は表示しない）
                if !rootItems.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(rootItems.prefix(5)) { item in
                            HStack(spacing: 4) {
                                Image(systemName: item.isDone ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(item.isDone ? .green : .secondary.opacity(0.35))

                                Text(item.title)
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                    .foregroundStyle(item.isDone ? .secondary : .primary)
                                    .strikethrough(item.isDone, color: .secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.leading, 4)
                }

                // 右下に件数表示
                let summary2 = fetchSummary(for: list)
                if summary2.total > 0 {
                    HStack {
                        Spacer()
                        if summary2.done == summary2.total {
                            Text("全完了")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary.opacity(0.5))
                        } else {
                            Text("\(summary2.done)/\(summary2.total) 完了")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary.opacity(0.5))
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
            )
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topLeading) {
            if list.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
                    .offset(x: 4, y: 4)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if list.isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                    .offset(x: 4, y: -4)
            }
        }
        .contextMenu {
            Button {
                moveListToTop(list)
            } label: {
                Label("トップに移動", systemImage: "arrow.up.to.line")
            }
            Button {
                list.isPinned.toggle()
                try? modelContext.save()
            } label: {
                Label(list.isPinned ? "固定を解除" : "トップに常時固定", systemImage: list.isPinned ? "pin.slash" : "pin")
            }
            Button {
                list.isLocked.toggle()
                try? modelContext.save()
            } label: {
                Label(list.isLocked ? "ロックを解除" : "削除防止ロック", systemImage: list.isLocked ? "lock.open" : "lock")
            }
            if list.isLocked {
                Button(role: .destructive) {} label: {
                    Label("削除ロック中", systemImage: "lock.fill")
                }
                .disabled(true)
            } else {
                Button(role: .destructive) {
                    pendingDeleteList = list
                    showDeleteConfirm = true
                } label: {
                    Label("削除", systemImage: "trash")
                }
            }
        }
    }

    // 達成サマリ取得（ルート項目のみ）
    private func fetchSummary(for list: TodoList) -> (total: Int, done: Int) {
        let listID = list.id
        let descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { $0.listID == listID && $0.parentID == nil }
        )
        let items = (try? modelContext.fetch(descriptor)) ?? []
        return (items.count, items.filter(\.isDone).count)
    }

    // ルート項目のみ取得（sortOrder順）
    private func fetchRootItems(for list: TodoList) -> [TodoItem] {
        let listID = list.id
        let descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { $0.listID == listID && $0.parentID == nil },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
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

    // MARK: - トップに移動
    private func moveListToTop(_ list: TodoList) {
        let minOrder = todoLists.map(\.manualSortOrder).min() ?? 0
        list.manualSortOrder = minOrder - 1
        list.updatedAt = Date()
        try? modelContext.save()
    }

}
