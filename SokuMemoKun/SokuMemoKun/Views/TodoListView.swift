import SwiftUI
import SwiftData

// L字罫線（シンプルモードの子タスク追加行用）
private struct LShapeLine: View {
    let color: Color
    var body: some View {
        Canvas { context, size in
            let lineWidth: CGFloat = 1.5
            let radius: CGFloat = 4
            var path = Path()
            // 上端中央から下へ、角丸で右へ
            let startX = size.width * 0.15
            let endX = size.width
            let midY = size.height * 0.5
            path.move(to: CGPoint(x: startX, y: 0))
            path.addLine(to: CGPoint(x: startX, y: midY - radius))
            path.addQuadCurve(
                to: CGPoint(x: startX + radius, y: midY),
                control: CGPoint(x: startX, y: midY)
            )
            path.addLine(to: CGPoint(x: endX, y: midY))
            context.stroke(path, with: .color(color), lineWidth: lineWidth)
        }
    }
}

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
    // 最大階層数（depth 0〜5 = 6階層、色帯2周分）
    private let maxDepth = 5
    // 全展開ダイアログ
    @State private var showExpandDialog = false
    // 全チェッククリアダイアログ
    @State private var showResetDialog = false
    // 全タスク削除ダイアログ（2段階）
    @State private var showClearAllDialog = false
    @State private var showClearAllConfirm = false

    // 編集中の項目
    @State private var editingItemID: UUID?
    @State private var editingText: String = ""
    @FocusState private var isEditingFocused: Bool

    // メモ表示・編集
    @State private var memoOpenItems: Set<UUID> = []      // メモ展開中（閲覧モード）
    @State private var memoEditingItemID: UUID?            // メモ編集中
    @State private var memoEditingText: String = ""
    @FocusState private var isMemoFocused: Bool

    // 表示モード（シンプル/詳細）
    @State private var isSimpleMode: Bool = false



    // 進捗情報（ルート項目のみ）
    private var rootItems_: [TodoItem] { allItems.filter { $0.parentID == nil } }
    private var totalCount: Int { rootItems_.count }
    private var doneCount: Int { rootItems_.filter(\.isDone).count }
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
                                        .moveDisabled(true)
                                }
                            }
                            .onMove(perform: moveFlatRows)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .scrollDismissesKeyboard(.interactively)
                        .environment(\.defaultMinListRowHeight, 1)
                        .onChange(of: editingItemID) { _, newID in
                            if let id = newID {
                                scrollToItem(id, proxy: proxy)
                            } else {
                                // 編集完了後、+ボタンが見えるようにスクロール
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        proxy.scrollTo("add-root", anchor: .bottom)
                                    }
                                }
                            }
                        }
                        .onChange(of: memoEditingItemID) { _, newID in
                            if let id = newID {
                                scrollToItem(id, proxy: proxy)
                            }
                        }
                        .onChange(of: isEditingFocused) { _, focused in
                            if focused, let id = editingItemID {
                                scrollToItem(id, proxy: proxy)
                            } else if !focused, let editID = editingItemID,
                                      let item = allItems.first(where: { $0.id == editID }) {
                                // フォーカスが外れたら完了と同じ扱い
                                commitEdit(item: item)
                            }
                        }
                        .onChange(of: isMemoFocused) { _, focused in
                            if focused, let id = memoEditingItemID {
                                scrollToItem(id, proxy: proxy)
                            } else if !focused && memoEditingItemID != nil {
                                // メモもフォーカス外れたら保存
                                commitMemo()
                            }
                        }
                    }
                }

                // ヒント（編集中は非表示）
                if allItems.count > 0 && editingItemID == nil && memoEditingItemID == nil {
                    HStack(spacing: 5) {
                        Image(systemName: "hand.tap")
                            .font(.system(size: 12))
                        Text("タップで編集 ・ 長押しで並び替え ・ 左スワイプで削除")
                            .font(.system(size: 13))
                    }
                    .foregroundStyle(.secondary.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 24)
                    .padding(.bottom, 50)
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
                    } else if memoEditingItemID != nil {
                        Button("完了") {
                            commitMemo()
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                        .fontWeight(.semibold)
                    } else if allItems.contains(where: { hasChildren($0.id) }) {
                        // 全展開/全収納トグル（子項目がある場合のみ表示）
                        Button {
                            if isAllExpanded {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    expandedItems.removeAll()
                                    memoOpenItems.removeAll()
                                    commitMemo()
                                }
                            } else {
                                let hasAnyMemo = allItems.contains { ($0.memo ?? "").isEmpty == false }
                                if hasAnyMemo {
                                    showExpandDialog = true
                                } else {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        expandedItems = Set(allItems.filter { hasChildren($0.id) }.map(\.id))
                                    }
                                }
                            }
                        } label: {
                            Text(isAllExpanded ? "全収納" : "全展開")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.blue)
                        }
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
        .onTapGesture {
            // 枠外タップで編集終了+キーボード閉じる
            if let editID = editingItemID,
               let item = allItems.first(where: { $0.id == editID }) {
                commitEdit(item: item)
            }
            // メモ編集中なら保存（閲覧モードに戻るだけ、閉じない）
            commitMemo()
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        // フロートボタン（下端: 左=表示切替、右=削除）
        .overlay(alignment: .bottom) {
            if allItems.count > 0 && editingItemID == nil && memoEditingItemID == nil {
                HStack {
                    // 表示切替ボタン（左下）
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSimpleMode.toggle()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: isSimpleMode ? "list.bullet" : "list.bullet.indent")
                                .font(.system(size: 14, weight: .medium))
                            Text(isSimpleMode ? "シンプル" : "詳細")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(.secondary.opacity(0.7))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 0.5)
                        )
                    }

                    Spacer()

                    // 全タスク削除ボタン（右下）
                    Button {
                        showClearAllDialog = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 14, weight: .medium))
                            Text("削除")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(.red.opacity(0.6))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.red.opacity(0.15), lineWidth: 0.5)
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        // 全展開ダイアログ（カスタムリッチUI）
        .overlay {
            if showExpandDialog {
                ZStack {
                    // 半透明背景
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                showExpandDialog = false
                            }
                        }
                    // ダイアログ本体
                    VStack(spacing: 16) {
                        Text("メモを含む項目があります")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .padding(.top, 4)

                        VStack(spacing: 10) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    expandedItems = Set(allItems.filter { hasChildren($0.id) }.map(\.id))
                                    showExpandDialog = false
                                }
                            } label: {
                                Text("リストのみ展開")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundStyle(.blue)
                                    .cornerRadius(8)
                            }

                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    expandedItems = Set(allItems.filter { hasChildren($0.id) }.map(\.id))
                                    memoOpenItems = Set(allItems.filter { ($0.memo ?? "").isEmpty == false }.map(\.id))
                                    showExpandDialog = false
                                }
                            } label: {
                                Text("メモも全展開")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.purple.opacity(0.1))
                                    .foregroundStyle(.purple)
                                    .cornerRadius(8)
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
        // 全チェッククリアダイアログ
        .overlay {
            if showResetDialog {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                showResetDialog = false
                            }
                        }

                    VStack(spacing: 16) {
                        Text("チェックをリセット")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .padding(.top, 4)

                        Text("\(doneCount)件の完了チェックを外します")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.secondary)

                        VStack(spacing: 10) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    resetAllChecks()
                                    showResetDialog = false
                                }
                            } label: {
                                Text("リセットする")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.red.opacity(0.1))
                                    .foregroundStyle(.red)
                                    .cornerRadius(8)
                            }

                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    showResetDialog = false
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
        // 全タスク削除ダイアログ
        .overlay {
            if showClearAllDialog {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                showClearAllDialog = false
                            }
                        }
                    VStack(spacing: 16) {
                        Text("全タスクを削除")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .padding(.top, 4)
                        Text("\(allItems.count)件のタスクを全て削除します\nリスト自体は残ります")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        VStack(spacing: 10) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    showClearAllDialog = false
                                    showClearAllConfirm = true
                                }
                            } label: {
                                Text("全て削除する")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.red.opacity(0.1))
                                    .foregroundStyle(.red)
                                    .cornerRadius(8)
                            }
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    showClearAllDialog = false
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
        // 全タスク削除 2段階目（最終確認）
        .overlay {
            if showClearAllConfirm {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                showClearAllConfirm = false
                            }
                        }
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.red)
                        Text("本当によろしいですか？")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                        Text("全タスクを削除します。この操作は取り消せません。")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        VStack(spacing: 10) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    clearAllItems()
                                    showClearAllConfirm = false
                                }
                            } label: {
                                Text("削除する")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.red)
                                    .foregroundStyle(.white)
                                    .cornerRadius(8)
                            }
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    showClearAllConfirm = false
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
            .contextMenu {
                if allItems.count > 0 {
                    Button(role: .destructive) {
                        showClearAllDialog = true
                    } label: {
                        Label("全タスクを削除", systemImage: "trash")
                    }
                }
            }

            Spacer()

            // 円グラフ（ドーナツ型）+ タップでリセット
            if totalCount > 0 {
                VStack(spacing: 3) {
                    ZStack {
                        // 背景リング
                        Circle()
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 4)

                        // 進捗リング
                        if progress >= 1.0 {
                            // 全完了：レインボー
                            Circle()
                                .stroke(
                                    AngularGradient(
                                        colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                                        center: .center
                                    ),
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                )
                        } else {
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(
                                    Color.blue,
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 0.3), value: progress)
                        }

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
                    .contentShape(Circle())
                    .onTapGesture {
                        if doneCount > 0 {
                            showResetDialog = true
                        }
                    }

                    // ヒント（完了が1件以上ある場合のみ）
                    if doneCount > 0 {
                        Text("リセット")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary.opacity(0.4))
                    }
                }
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

        // ルートレベルの追加ボタン（編集中は非表示）
        if editingItemID == nil {
            rows.append(FlatRow(id: "add-root", kind: .addButton(parentID: nil), depth: 0, isLastChild: true))
        }
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
            // 子の追加ボタン（最大階層では表示しない、編集中も非表示）
            if depth + 1 <= maxDepth && editingItemID == nil {
                rows.append(FlatRow(id: "add-\(item.id.uuidString)", kind: .addButton(parentID: item.id), depth: depth + 1, isLastChild: true))
            }
        }
    }

    // MARK: - 子を持っているか
    private func hasChildren(_ itemID: UUID) -> Bool {
        allItems.contains { $0.parentID == itemID }
    }

    // 全展開中かどうか
    private var isAllExpanded: Bool {
        let parents = Set(allItems.filter { hasChildren($0.id) }.map(\.id))
        return !parents.isEmpty && parents.isSubset(of: expandedItems)
    }

    // MARK: - 帯の左インデント量
    private let indentBase: CGFloat = 12   // ルートのインデント
    private let indentStep: CGFloat = 28   // 階層ごとのインデント幅（緑帯と統一）

    // 階層ごとのインデント色（紫→オレンジ→緑…ループ）
    private func depthColor(_ depth: Int) -> Color {
        let colors: [Color] = [
            .purple.opacity(0.10),    // 子階層1: 紫
            .orange.opacity(0.10),    // 子階層2: オレンジ
            .green.opacity(0.12),     // 子階層3: 緑（ルートと同じ）
        ]
        return colors[depth % colors.count]
    }

    // シンプルモード用：階層ごとのアクセント色（濃いめ）
    private func depthAccentColor(_ depth: Int) -> Color {
        let colors: [Color] = [
            .green.opacity(0.5),      // ルート（depth 0）: 緑
            .purple.opacity(0.5),     // 子階層1: 紫
            .orange.opacity(0.5),     // 子階層2: オレンジ
        ]
        return colors[depth % colors.count]
    }

    private func indentLeading(_ depth: Int) -> CGFloat {
        indentBase + CGFloat(depth) * indentStep
    }

    // MARK: - ToDo行
    @ViewBuilder
    private func todoRow(item: TodoItem, depth: Int, isLastChild: Bool = false) -> some View {
        let isExpanded = expandedItems.contains(item.id)
        let hasKids = hasChildren(item.id)
        let isEditing = editingItemID == item.id
        let isAnythingEditing = editingItemID != nil || memoEditingItemID != nil

        // メインコンテンツ（帯スタイル）
        HStack(spacing: 0) { // 外側HStack（インデント用）
        // インデント領域（タップでフォーカス解除、チェックボックスには伝播しない）
        Color.white.opacity(0.001)
            .frame(width: indentLeading(depth))
            .contentShape(Rectangle())
            .onTapGesture {
                if let editID = editingItemID,
                   let item = allItems.first(where: { $0.id == editID }) {
                    commitEdit(item: item)
                }
                commitMemo()
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        VStack(spacing: 0) {
        HStack(spacing: 8) {
            // チェックボックス（タップ領域をアイコンに限定）
            Image(systemName: item.isDone ? "checkmark.square.fill" : "square")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(item.isDone ? .green : .secondary.opacity(0.35))
                .animation(.easeInOut(duration: 0.2), value: item.isDone)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !isAnythingEditing else { return }
                    item.isDone.toggle()
                    item.updatedAt = Date()
                    try? modelContext.save()
                }

            // タイトル（通常表示 or インライン編集）
            if isEditing {
                TextField("項目を入力", text: $editingText)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .focused($isEditingFocused)
                    .onSubmit {
                        submitEdit(item: item)
                    }
                    .onAppear {
                        isEditingFocused = true
                    }
            } else {
                Text(item.title)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .strikethrough(item.isDone, color: .secondary)
                    .foregroundStyle(item.isDone ? .secondary : .primary)
                    .animation(.easeInOut(duration: 0.2), value: item.isDone)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        startEditing(item: item)
                    }
            }

            // メモアイコン
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    let hasMemo = !(item.memo ?? "").isEmpty
                    if memoEditingItemID == item.id {
                        // 編集中→保存して閲覧モードに
                        commitMemo(item: item)
                        if hasMemo || !memoEditingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            memoOpenItems.insert(item.id)
                        }
                    } else if memoOpenItems.contains(item.id) {
                        // 閲覧中→閉じる
                        commitMemo()
                        memoOpenItems.remove(item.id)
                    } else if hasMemo {
                        // メモあり→閲覧モードで開く
                        commitMemo()
                        memoOpenItems.insert(item.id)
                    } else {
                        // メモなし→新規作成、即編集モード
                        commitMemo()
                        memoOpenItems.insert(item.id)
                        memoEditingItemID = item.id
                        memoEditingText = ""
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            isMemoFocused = true
                        }
                    }
                }
            } label: {
                Image(systemName: (item.memo ?? "").isEmpty ? "doc" : "doc.fill")
                    .rotationEffect(.degrees(90))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isAnythingEditing ? Color.secondary.opacity(0.2) : ((item.memo ?? "").isEmpty ? Color.secondary.opacity(0.2) : Color.purple.opacity(0.5)))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(isAnythingEditing)

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
                        .foregroundStyle(isAnythingEditing ? Color.secondary.opacity(0.2) : (isExpanded ? Color.orange : Color.blue))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .disabled(isAnythingEditing)
            } else if depth < maxDepth {
                // 子がない＆まだ階層追加可能 → 展開ボタン
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
                        .foregroundStyle(isAnythingEditing ? Color.secondary.opacity(0.2) : (isExpanded ? Color.orange : Color.secondary.opacity(0.2)))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .disabled(isAnythingEditing)
            } else {
                // 最深階層：展開ボタンなし、同じ幅のスペース確保
                Color.clear.frame(width: 30, height: 30)
            }
        }

        // インラインメモ欄
        if memoOpenItems.contains(item.id) {
            VStack(alignment: .leading, spacing: 4) {
                if memoEditingItemID == item.id {
                    // 編集モード（付箋アイコン＋入力欄）
                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "doc")
                            .rotationEffect(.degrees(90))
                            .font(.system(size: 11))
                            .foregroundStyle(Color.purple.opacity(0.5))
                            .padding(.top, 2)
                        TextField("メモを入力", text: $memoEditingText, axis: .vertical)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(Color.purple.opacity(0.6))
                            .lineLimit(1...10)
                            .focused($isMemoFocused)
                    }
                } else {
                    // 閲覧モード（付箋アイコン＋テキスト、タップで編集へ）
                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "doc")
                            .rotationEffect(.degrees(90))
                            .font(.system(size: 11))
                            .foregroundStyle(Color.purple.opacity(0.5))
                            .padding(.top, 2)
                        Text((item.memo ?? "").isEmpty ? "メモを入力" : item.memo!)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle((item.memo ?? "").isEmpty ? Color.secondary.opacity(0.4) : Color.purple.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        memoEditingItemID = item.id
                        memoEditingText = item.memo ?? ""
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            isMemoFocused = true
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.purple.opacity(0.04))
            .cornerRadius(6)
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        } else if let memo = item.memo, !memo.isEmpty {
            // 閉じ状態：付箋アイコン＋1行プレビュー
            HStack(spacing: 3) {
                Image(systemName: "doc")
                    .rotationEffect(.degrees(90))
                    .font(.system(size: 10))
                Text(memo)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(.purple.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.bottom, 2)
            .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        commitMemo()
                        memoOpenItems.insert(item.id)
                    }
                }
        }
        } // VStack
        .padding(.horizontal, 12)
        .padding(.vertical, 0)
        } // 外側HStack（インデント用）
        // 階層ごとの色付きインデントバー
        .background(alignment: .leading) {
            HStack(spacing: 0) {
                // ルートレベルのインデント（常に緑）
                Rectangle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: indentBase + 12)  // listRowInsetsのleading分を加算（チェックボックスにかぶらないよう調整）
                // 各階層のインデント帯
                ForEach(0..<depth, id: \.self) { d in
                    Rectangle()
                        .fill(depthColor(d))
                        .frame(width: indentStep)
                }
            }
        }
        // 下の区切り線
        .background(alignment: .bottom) {
            Rectangle()
                .fill(Color.secondary.opacity(0.15))
                .frame(height: 0.5)
                .padding(.leading, indentLeading(depth) + 12)
        }
        // List行スタイル除去
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
    }

    // MARK: - 追加ボタン
    @ViewBuilder
    private func addItemRow(parentID: UUID?, depth: Int, rowID: String) -> some View {
        if let parentID = parentID,
           let parent = allItems.first(where: { $0.id == parentID }) {
            // 子タスク追加
            let isDisabled = editingItemID != nil || memoEditingItemID != nil
            let accentColor = depthAccentColor(depth)

            Group {
                if isSimpleMode {
                    // シンプルモード: L字罫線＋色付き＋ボタン（左端）
                    let lineColor = isDisabled ? accentColor.opacity(0.3) : accentColor
                    Button {
                        addEmptyItemAndEdit(parentID: parentID)
                    } label: {
                        HStack(spacing: 0) {
                            // L字: 縦線＋角丸＋横線＋＋ボタン
                            LShapeLine(color: lineColor)
                                .frame(width: 14, height: 20)
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(lineColor)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isDisabled)
                    .padding(.trailing, 12)
                    .padding(.vertical, 0)
                    .padding(.leading, indentLeading(depth) + 16)
                } else {
                    // 詳細モード: 点線枠スタイル
                    Button {
                        addEmptyItemAndEdit(parentID: parentID)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .medium))
                            Text("\"\(parent.title)\"  の子タスクを追加")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .lineLimit(1)
                        }
                        .foregroundStyle(.secondary.opacity(isDisabled ? 0.15 : 0.4))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                .foregroundStyle(.secondary.opacity(isDisabled ? 0.08 : 0.2))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isDisabled)
                    .padding(.trailing, 12)
                    .padding(.vertical, 2)
                    .padding(.leading, indentLeading(depth) + 16)
                }
            }
            // 親階層の帯を継続表示（自分の階層は除く）
            .background(alignment: .leading) {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.green.opacity(0.12))
                        .frame(width: indentBase + 12)
                    ForEach(0..<max(0, depth - 1), id: \.self) { d in
                        Rectangle()
                            .fill(depthColor(d))
                            .frame(width: indentStep)
                    }
                }
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        } else {
            // ルート追加（プラスボタン）
            Button {
                addEmptyItemAndEdit(parentID: nil)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary.opacity(0.25))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .center)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        }
    }

    // MARK: - スクロールヘルパー（キーボード対応）
    private func scrollToItem(_ id: UUID, proxy: ScrollViewProxy) {
        // 即座に1回、キーボード表示後にもう1回
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeInOut(duration: 0.15)) {
                proxy.scrollTo(id, anchor: .bottom)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeInOut(duration: 0.15)) {
                proxy.scrollTo(id, anchor: .bottom)
            }
        }
    }

    // MARK: - 全タスク削除（リスト自体は残す）
    private func clearAllItems() {
        for item in allItems {
            modelContext.delete(item)
        }
        try? modelContext.save()
        expandedItems.removeAll()
        memoOpenItems.removeAll()
    }

    // MARK: - 全チェッククリア
    private func resetAllChecks() {
        for item in allItems where item.isDone {
            item.isDone = false
            item.updatedAt = Date()
        }
        try? modelContext.save()
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
        // メモ編集中なら保存して抜けるだけ（項目編集には入らない）
        if memoEditingItemID != nil {
            commitMemo()
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            return
        }
        // 編集中の項目があれば先に確定
        if let editID = editingItemID,
           let editItem = allItems.first(where: { $0.id == editID }) {
            commitEdit(item: editItem)
        }
        editingItemID = item.id
        editingText = item.title
    }

    // MARK: - メモ保存
    private func commitMemo(item: TodoItem? = nil) {
        // 指定アイテム or 現在編集中のアイテムのメモを保存
        let targetItem: TodoItem?
        if let item = item {
            targetItem = item
        } else if let editID = memoEditingItemID {
            targetItem = allItems.first { $0.id == editID }
        } else {
            return
        }
        guard let target = targetItem else { return }
        let trimmed = memoEditingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            // 空メモは保存しない、展開も閉じる
            target.memo = nil
            memoOpenItems.remove(target.id)
        } else {
            target.memo = trimmed
            target.updatedAt = Date()
            try? modelContext.save()
        }
        memoEditingItemID = nil
        memoEditingText = ""
    }

    // MARK: - Enter押下時
    private func submitEdit(item: TodoItem) {
        commitEdit(item: item)
    }

    // MARK: - 編集確定
    private func commitEdit(item: TodoItem) {
        let trimmed = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            // 空タイトル → 削除
            deleteItem(item)
        } else {
            item.title = trimmed
            item.updatedAt = Date()
            try? modelContext.save()
        }
        editingItemID = nil
        editingText = ""
    }

    // MARK: - 空の項目を作成して即編集開始（saveはしない＝確定まで永続化しない）
    private func addEmptyItemAndEdit(parentID: UUID?) {
        let siblings = allItems.filter { $0.parentID == parentID }
        let maxOrder = siblings.map(\.sortOrder).max() ?? -1

        let item = TodoItem(title: "", listID: todoList.id, parentID: parentID, sortOrder: maxOrder + 1)
        item.tags = [getOrCreateTodoTag()]
        modelContext.insert(item)
        // save()はsubmitEdit側で行う（ここでsave()すると@Query再フェッチで前の編集が消える）

        if let parentID = parentID {
            expandedItems.insert(parentID)
        }

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
