import SwiftUI
import SwiftData

// L字の角部分（縦線＋横線をRectangleで描画、重なりなし）
private struct LShapeCorner: View {
    let color: Color
    private let lineWidth: CGFloat = 1.5
    var body: some View {
        GeometryReader { geo in
            // 縦線（上端から下端まで）
            Rectangle()
                .fill(color)
                .frame(width: lineWidth, height: geo.size.height)
            // 横線（縦線の右端から右端まで、重なり防止）
            Rectangle()
                .fill(color)
                .frame(width: geo.size.width - lineWidth, height: lineWidth)
                .offset(x: lineWidth, y: geo.size.height - lineWidth)
        }
    }
}

// ツリーをフラット化した表示用の行データ
private struct FlatRow: Identifiable {
    enum Kind {
        case item(TodoItem)
        case addButton(parentID: UUID?) // 「+ 項目を追加」行
        case bottomSpacer               // 最下端のスクロールバッファ
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
    @Query(sort: \Tag.name) private var allTags: [Tag]

    // このリストに属する項目のみ
    private var allItems: [TodoItem] {
        queryItems.filter { $0.listID == todoList.id }
    }

    // 展開中の項目（子を表示中）
    @State private var expandedItems: Set<UUID> = []
    // 最大階層数（depth 0〜5 = 6階層、色帯2周分）
    private let maxDepth = 4  // 5階層まで（depth 0〜4）
    // 全展開ダイアログ
    @State private var showExpandDialog = false
    // 全チェッククリアダイアログ
    @State private var showResetDialog = false
    // 削除メニューダイアログ（選択削除 or 全件削除）
    @State private var showDeleteMenu = false
    // 全項目削除ダイアログ（2段階）
    @State private var showClearAllDialog = false
    @State private var showClearAllConfirm = false
    // 選択削除モード
    @State private var isSelectMode = false
    @State private var selectedItems: Set<UUID> = []
    // 親チェック前の子孫選択状態を記憶（親ID → チェック前の子孫選択セット）
    @State private var selectionSnapshot: [UUID: Set<UUID>] = [:]
    // メモ削除確認ダイアログ
    @State private var showMemoDeleteDialog = false
    @State private var memoDeleteTargetID: UUID?

    // 編集中の項目
    @State private var editingItemID: UUID?
    @State private var editingText: String = ""
    @FocusState private var isEditingFocused: Bool
    // 連続入力中フラグ（onChangeのcommitEdit競合防止）
    @State private var isChainEditing = false

    // メモ表示・編集
    @State private var memoOpenItems: Set<UUID> = []      // メモ展開中（閲覧モード）
    @State private var memoEditingItemID: UUID?            // メモ編集中
    @State private var memoEditingText: String = ""
    @FocusState private var isMemoFocused: Bool
    // メモ展開時のスクロール用（IDが変わるとスクロール発火）
    @State private var scrollToMemoItemID: UUID?

    // タグ選択ルーレット
    @State private var showParentDial = false
    @State private var showNewTagSheet = false
    @State private var newTagIsChild = false
    @State private var showTagHistory = false
    @State private var tagHistoryItems: [TagHistory] = []
    @State private var headerBottomY: CGFloat = 0
    @State private var overlayTopY: CGFloat = 0
    @State private var dialParentID: UUID? = nil
    @State private var dialChildID: UUID? = nil
    @State private var showChildDial = true
    @State private var childExternalDragY: CGFloat? = nil





    // 進捗情報（ルート項目のみ）
    private var rootItems_: [TodoItem] { allItems.filter { $0.parentID == nil } }
    private var totalCount: Int { rootItems_.count }
    private var doneCount: Int { rootItems_.filter(\.isDone).count }
    private var progress: Double {
        totalCount == 0 ? 0 : Double(doneCount) / Double(totalCount)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
        NavigationStack {
            VStack(spacing: 0) {
                // リッチヘッダー
                headerView

                Divider()
                    .background(
                        GeometryReader { geo in
                            Color.clear.onAppear {
                                headerBottomY = geo.frame(in: .global).maxY
                            }
                            .onChange(of: geo.frame(in: .global).maxY) { _, v in
                                headerBottomY = v
                            }
                        }
                    )
                    .padding(.horizontal, 16)

                // ToDoリスト（Listベース: スワイプ・スクロール・リオーダー全対応）
                    ScrollViewReader { proxy in
                        List {
                            ForEach(flatRows) { row in
                                switch row.kind {
                                case .item(let item):
                                    todoRow(item: item, depth: row.depth, isLastChild: row.isLastChild)
                                        .id(item.id)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: !isSelectMode) {
                                            if !isSelectMode {
                                                Button(role: .destructive) {
                                                    withAnimation {
                                                        deleteItem(item)
                                                    }
                                                } label: {
                                                    Label("削除", systemImage: "trash")
                                                }
                                            }
                                        }
                                case .addButton(let parentID):
                                    addItemRow(parentID: parentID, depth: row.depth, rowID: row.id)
                                        .id(row.id)
                                        .moveDisabled(true)
                                case .bottomSpacer:
                                    Color.clear
                                        .frame(height: 300)
                                        .listRowSeparator(.hidden)
                                        .listRowBackground(Color.clear)
                                        .listRowInsets(EdgeInsets())
                                        .moveDisabled(true)
                                }
                            }
                            .onMove(perform: moveFlatRows)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .scrollDismissesKeyboard(.never)
                        .environment(\.defaultMinListRowHeight, 1)
                        .animation(nil, value: allItems.count)
                        // 編集中は完了バーの高さ分だけ下に余白
                        .safeAreaInset(edge: .bottom) {
                            if editingItemID != nil || memoEditingItemID != nil {
                                Color.clear.frame(height: 44)
                            }
                        }
                        .onChange(of: editingItemID) { oldID, newID in
                            if let id = newID,
                               let item = allItems.first(where: { $0.id == id }) {
                                // 編集開始: 入力行の下の＋ボタンが見えるようにスクロール
                                let addRowID = item.parentID.map { "add-\($0.uuidString)" } ?? "add-root"
                                scrollToRow(addRowID, proxy: proxy)
                            } else if !isChainEditing, let oldID = oldID,
                                      let item = allItems.first(where: { $0.id == oldID }) {
                                // 編集完了後、最後の項目だった場合のみ＋ボタンにスクロール（連続入力中は除く）
                                let siblings = allItems
                                    .filter { $0.parentID == item.parentID && $0.listID == item.listID }
                                    .sorted { $0.sortOrder < $1.sortOrder }
                                if siblings.last?.id == oldID {
                                    let addRowID = item.parentID.map { "add-\($0.uuidString)" } ?? "add-root"
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            proxy.scrollTo(addRowID, anchor: .bottom)
                                        }
                                    }
                                }
                            }
                        }
                        .onChange(of: memoEditingItemID) { _, newID in
                            if let id = newID {
                                scrollToItem(id, proxy: proxy)
                            }
                        }
                        .onChange(of: scrollToMemoItemID) { _, newID in
                            if let id = newID {
                                scrollToItem(id, proxy: proxy)
                                scrollToMemoItemID = nil
                            }
                        }
                        .onChange(of: isEditingFocused) { _, focused in
                            if focused, let id = editingItemID,
                               let item = allItems.first(where: { $0.id == id }) {
                                let addRowID = item.parentID.map { "add-\($0.uuidString)" } ?? "add-root"
                                scrollToRow(addRowID, proxy: proxy)
                            } else if !focused {
                                // フォーカスが外れたら少し待ってからcommitEdit
                                // （submitEditのisChainEditing=trueが先に実行される猶予）
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                                    guard !isChainEditing else { return }
                                    if let editID = editingItemID,
                                       let item = allItems.first(where: { $0.id == editID }) {
                                        commitEdit(item: item)
                                    }
                                }
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
                    if allItems.contains(where: { hasChildren($0.id) }) {
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
        // 編集中: キーボード直上に「完了」バー
        if editingItemID != nil || memoEditingItemID != nil {
            HStack {
                Spacer()
                Button {
                    if let editID = editingItemID,
                       let item = allItems.first(where: { $0.id == editID }) {
                        commitEdit(item: item)
                    }
                    commitMemo()
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                } label: {
                    Text("完了")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .background(.bar)
        }
        } // ZStack
        .onAppear {
            cleanupEmptyItems()
            // 初期表示時にツリーを全展開（メモは省略のまま）
            expandedItems = Set(allItems.filter { hasChildren($0.id) }.map(\.id))
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
        // 削除フロートボタン（下端中央）
        .overlay(alignment: .bottom) {
            if allItems.count > 0 && editingItemID == nil && memoEditingItemID == nil {
                if isSelectMode {
                    // 選択モード中: 削除実行 + キャンセル
                    HStack(spacing: 12) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                isSelectMode = false
                                selectedItems.removeAll()
                            }
                        } label: {
                            Text("キャンセル")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 9)
                                .background(Capsule().fill(.ultraThinMaterial))
                        }
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                deleteSelectedItems()
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .medium))
                                Text("\(selectedItems.count)件削除")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(selectedItems.isEmpty ? Color.gray : Color.red))
                        }
                        .disabled(selectedItems.isEmpty)
                    }
                    .padding(.bottom, 8)
                } else {
                    // 通常: 削除メニューを開く
                    Button {
                        showDeleteMenu = true
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
                    .padding(.bottom, 8)
                }
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
        // 削除メニューダイアログ（選択削除 or 全件削除）
        .overlay {
            if showDeleteMenu {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                showDeleteMenu = false
                            }
                        }
                    VStack(spacing: 16) {
                        Text("項目を削除")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .padding(.top, 4)
                        VStack(spacing: 10) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    showDeleteMenu = false
                                    isSelectMode = true
                                    selectedItems.removeAll()
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle")
                                        .font(.system(size: 14))
                                    Text("選択して削除")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.blue.opacity(0.1))
                                .foregroundStyle(.blue)
                                .cornerRadius(8)
                            }
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    showDeleteMenu = false
                                    showClearAllDialog = true
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14))
                                    Text("全件削除")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.red.opacity(0.1))
                                .foregroundStyle(.red)
                                .cornerRadius(8)
                            }
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    showDeleteMenu = false
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
        // 全項目削除ダイアログ
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
                        Text("全項目を削除")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .padding(.top, 4)
                        Text("\(allItems.count)件の項目を全て削除します\nリスト自体は残ります")
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
        // 全項目削除 2段階目（最終確認）
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
                        Text("全項目を削除します。この操作は取り消せません。")
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

            // メモ削除確認ダイアログ
            if showMemoDeleteDialog {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                showMemoDeleteDialog = false
                            }
                        }

                    VStack(spacing: 16) {
                        Text("メモを削除")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .padding(.top, 4)

                        Text("このメモを削除しますか？")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.secondary)

                        VStack(spacing: 10) {
                            Button {
                                if let targetID = memoDeleteTargetID,
                                   let item = allItems.first(where: { $0.id == targetID }) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        item.memo = nil
                                        item.updatedAt = Date()
                                        memoOpenItems.remove(item.id)
                                        try? modelContext.save()
                                        showMemoDeleteDialog = false
                                    }
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
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    showMemoDeleteDialog = false
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
        // タグ選択ルーレット（overlayで右からスライドイン、中央やや上に配置）
        .overlay {
            ZStack {
                if showParentDial {
                    // グレーアウト背景
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            saveDialTags()
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showParentDial = false; showChildDial = false
                            }
                        }
                        .transition(.opacity)
                }
                // ルーレットパネル（QuickSortCellViewと同じ配置方法）
                VStack(spacing: 0) {
                    // ヘッダー下端 - overlay上端 = 1項目目の上端に一致
                    let topOffset = max(0, headerBottomY - overlayTopY)
                    Spacer().frame(height: topOffset)

                    if showParentDial {
                        dialPanel
                            // 履歴ボタン（トレーの外、MemoInputViewと同じ配置）
                            .overlay(alignment: .bottomTrailing) {
                                Button {
                                    if showTagHistory {
                                        showTagHistory = false
                                    } else {
                                        tagHistoryItems = TagHistory.recentHistory(context: modelContext)
                                        showTagHistory = true
                                    }
                                } label: {
                                    HStack(spacing: 3) {
                                        Image(systemName: showTagHistory ? "chevron.down" : "chevron.right")
                                            .font(.system(size: 9, weight: .semibold))
                                        Text("履歴")
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    .foregroundStyle(.white.opacity(0.7))
                                }
                                .padding(.trailing, 8)
                                .offset(y: 21)
                            }
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }

                    Spacer()
                }
            }
            .background(
                GeometryReader { geo in
                    Color.clear.onAppear {
                        overlayTopY = geo.frame(in: .global).minY
                    }
                    .onChange(of: geo.frame(in: .global).minY) { _, v in
                        overlayTopY = v
                    }
                }
            )
            .animation(.easeInOut(duration: 0.25), value: showParentDial)
        }
        // ルーレット操作をリアルタイムでタグに反映
        .onChange(of: dialParentID) { _, _ in
            if showParentDial { saveDialTags() }
        }
        .onChange(of: dialChildID) { _, _ in
            if showParentDial { saveDialTags() }
        }
        // 新規タグ作成シート
        .sheet(isPresented: $showNewTagSheet) {
            NewTagSheetView(
                parentTagID: newTagIsChild ? dialParentID : nil,
                onTagCreated: { newTagID in
                    if newTagIsChild {
                        dialChildID = newTagID
                    } else {
                        dialParentID = newTagID
                        dialChildID = nil
                    }
                }
            )
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

                HStack(spacing: 0) {
                    if totalCount > 0 {
                        Text("\(doneCount)/\(totalCount) 完了")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    // タグバッジ（右端固定、左に伸びる）
                    tagRowInHeader
                }
            }
            .contextMenu {
                if allItems.count > 0 {
                    Button(role: .destructive) {
                        showClearAllDialog = true
                    } label: {
                        Label("全項目を削除", systemImage: "trash")
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

                    // ヒント（常に同じ高さを確保、完了なしの場合は透明）
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark.square.fill")
                            .font(.system(size: 9))
                        Text("リセット")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(.secondary.opacity(doneCount > 0 ? 0.4 : 0))
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

        // ルートレベルの追加ボタン（選択モード中は非表示）
        if !isSelectMode {
            rows.append(FlatRow(id: "add-root", kind: .addButton(parentID: nil), depth: 0, isLastChild: true))
        }

        // 編集中はスクロールバッファ（キーボード閉じ時の引き戻し防止）
        if editingItemID != nil || memoEditingItemID != nil {
            rows.append(FlatRow(id: "bottom-spacer", kind: .bottomSpacer, depth: 0, isLastChild: true))
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
            // 子の追加ボタン（最大階層では表示しない、選択モード中は非表示）
            if depth + 1 <= maxDepth && !isSelectMode {
                rows.append(FlatRow(id: "add-\(item.id.uuidString)", kind: .addButton(parentID: item.id), depth: depth + 1, isLastChild: true))
            }
        }
    }

    // メモテキストが1行に収まるか判定（UIKitのサイズ計算）
    private func isMemoTruncated(_ text: String, font: UIFont, maxWidth: CGFloat) -> Bool {
        let size = (text as NSString).boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: [.font: font],
            context: nil
        ).size
        return size.width > maxWidth
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
    // 階層ごとの背景色（薄め）— depth 0=緑, 1=紫, 2=オレンジ, 3=青, 4=茶
    private func depthColor(_ depth: Int) -> Color {
        let colors: [Color] = [
            .green.opacity(0.10),     // 階層0: 緑
            .purple.opacity(0.10),    // 階層1: 紫
            .orange.opacity(0.10),    // 階層2: オレンジ
            .blue.opacity(0.10),      // 階層3: 青
            .brown.opacity(0.10),     // 階層4: 茶色
        ]
        return colors[depth % colors.count]
    }

    // 階層ごとのアクセント色（濃いめ、罫線・＋ボタン・メモ用）
    private func depthAccentColor(_ depth: Int) -> Color {
        let colors: [Color] = [
            .green.opacity(0.5),      // 階層0: 緑
            .purple.opacity(0.5),     // 階層1: 紫
            .orange.opacity(0.5),     // 階層2: オレンジ
            .blue.opacity(0.5),       // 階層3: 青
            .brown.opacity(0.5),      // 階層4: 茶色
        ]
        return colors[depth % colors.count]
    }

    private func indentLeading(_ depth: Int) -> CGFloat {
        // depth 0 はインデントなし、以降は均等にindentStepずつ
        return CGFloat(depth) * indentStep
    }

    // MARK: - ToDo行
    @ViewBuilder
    private func todoRow(item: TodoItem, depth: Int, isLastChild: Bool = false) -> some View {
        let isExpanded = expandedItems.contains(item.id)
        let hasKids = hasChildren(item.id)
        let isEditing = editingItemID == item.id
        let memoColor = depthAccentColor(depth)  // メモの色（階層色）
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
            // チェックボックス / 選択モード（タップ領域をアイコンに限定）
            if isSelectMode {
                Image(systemName: selectedItems.contains(item.id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(selectedItems.contains(item.id) ? .red : .secondary.opacity(0.35))
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedItems.contains(item.id) {
                            // 外す: 自分+子孫全部
                            removeFromSelection(item.id)
                        } else {
                            // 入れる: 自分+子孫全部
                            addToSelection(item.id)
                        }
                    }
            } else {
                Image(systemName: item.isDone ? "checkmark.square.fill" : "square")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(item.isDone ? .green : .secondary.opacity(0.35))
                    .animation(nil, value: item.isDone)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !isAnythingEditing else { return }
                        item.isDone.toggle()
                        item.updatedAt = Date()
                        try? modelContext.save()
                    }
            }

            // タイトル（通常表示 or インライン編集）
            if isSelectMode {
                // 選択モード: タップで選択トグル
                Text(item.title)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .strikethrough(item.isDone, color: .secondary)
                    .foregroundStyle(item.isDone ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedItems.contains(item.id) {
                            removeFromSelection(item.id)
                        } else {
                            addToSelection(item.id)
                        }
                    }
            } else if isEditing {
                TextField("項目名を入力", text: $editingText)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .focused($isEditingFocused)
                    .onSubmit {
                        submitEdit(item: item)
                    }
                    .onAppear {
                        isEditingFocused = true
                    }
            } else {
                Text(item.title)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .strikethrough(item.isDone, color: .secondary)
                    .foregroundStyle(item.isDone ? .secondary : .primary)
                    .animation(nil, value: item.isDone)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        startEditing(item: item)
                    }
            }

            if !isSelectMode {
            // メモアイコン
            Button {
                // アイテム編集中からのタップ → 確定してメモ展開
                let wasEditing = editingItemID != nil
                commitCurrentEditIfNeeded()
                withAnimation(.easeInOut(duration: 0.15)) {
                    let hasMemo = !(item.memo ?? "").isEmpty
                    if memoEditingItemID == item.id {
                        // メモ編集中→保存して閲覧モードに
                        commitMemo(item: item)
                        if hasMemo || !memoEditingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            memoOpenItems.insert(item.id)
                        }
                    } else if wasEditing {
                        // アイテム編集から来た → メモ展開（閲覧モード）
                        commitMemo()
                        memoOpenItems.insert(item.id)
                        scrollToMemoItemID = item.id
                    } else if memoOpenItems.contains(item.id) {
                        // 閲覧中→閉じる
                        commitMemo()
                        memoOpenItems.remove(item.id)
                    } else if hasMemo {
                        // メモあり→閲覧モードで開く
                        commitMemo()
                        memoOpenItems.insert(item.id)
                        scrollToMemoItemID = item.id
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
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(memoEditingItemID != nil ? Color.secondary.opacity(0.2) : ((item.memo ?? "").isEmpty ? Color.secondary.opacity(0.35) : memoColor))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .disabled(memoEditingItemID != nil)
            } // if !isSelectMode（メモボタンここまで）

            // 展開/折りたたみ矢印
            if hasKids {
                Button {
                    commitCurrentEditIfNeeded()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if isExpanded {
                            expandedItems.remove(item.id)
                        } else {
                            expandedItems.insert(item.id)
                        }
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(memoEditingItemID != nil ? Color.secondary.opacity(0.2) : (isExpanded ? Color.orange : Color.blue))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .disabled(memoEditingItemID != nil)
            } else if depth < maxDepth {
                // 子がない＆まだ階層追加可能 → 展開ボタン
                Button {
                    commitCurrentEditIfNeeded()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if isExpanded {
                            expandedItems.remove(item.id)
                        } else {
                            expandedItems.insert(item.id)
                        }
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(memoEditingItemID != nil ? Color.secondary.opacity(0.2) : (isExpanded ? Color.orange : Color.secondary.opacity(0.35)))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .disabled(memoEditingItemID != nil)
            } else {
                // 最深階層：展開ボタンなし、同じ幅のスペース確保
                Color.clear.frame(width: 40, height: 40)
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
                            .foregroundStyle(memoColor)
                            .padding(.top, 2)
                        TextField("\"\(item.title)\"  にメモを追加", text: $memoEditingText, axis: .vertical)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(memoColor)
                            .lineLimit(1...10)
                            .focused($isMemoFocused)
                    }
                } else {
                    // 閲覧モード（付箋アイコン＋テキスト＋ゴミ箱、タップで編集へ）
                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "doc")
                            .rotationEffect(.degrees(90))
                            .font(.system(size: 11))
                            .foregroundStyle(memoColor)
                            .padding(.top, 2)
                        Text((item.memo ?? "").isEmpty ? "\"\(item.title)\"  にメモを追加" : item.memo!)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle((item.memo ?? "").isEmpty ? Color.secondary.opacity(0.4) : memoColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        // メモ削除ボタン（メモがある時のみ）
                        if !(item.memo ?? "").isEmpty {
                            Button {
                                memoDeleteTargetID = item.id
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    showMemoDeleteDialog = true
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.secondary.opacity(0.5))
                                    .padding(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // アイテム編集中→確定してからメモ編集開始
                        if editingItemID != nil {
                            commitCurrentEditIfNeeded()
                        }
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
            .background(memoColor.opacity(0.08))
            .cornerRadius(6)
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        } else if let memo = item.memo, !memo.isEmpty {
            // 閉じ状態：付箋アイコン＋1行プレビュー（展開時と同じフォント・位置）
            let isTruncated = isMemoTruncated(memo, font: .systemFont(ofSize: 13, weight: .regular), maxWidth: UIScreen.main.bounds.width - indentLeading(depth) - 80)
            HStack(alignment: .top, spacing: 4) {
                Image(systemName: "doc")
                    .rotationEffect(.degrees(90))
                    .font(.system(size: 11))
                    .foregroundStyle(memoColor)
                    .padding(.top, 2)
                Text(memo)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(memoColor)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(memoColor.opacity(0.08))
            .cornerRadius(6)
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
            .contentShape(Rectangle())
                .onTapGesture {
                    // アイテム編集中→確定してメモ展開
                    if editingItemID != nil {
                        commitCurrentEditIfNeeded()
                    }
                    // メモ編集中はメモを確定して抜けるだけ
                    if memoEditingItemID != nil {
                        commitMemo()
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        return
                    }
                    // 閲覧モードで全文展開＋ゴミ箱表示
                    withAnimation(.easeInOut(duration: 0.15)) {
                        memoOpenItems.insert(item.id)
                    }
                }
        }
        } // VStack
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        } // 外側HStack（インデント用）
        // 縦線の位置から右を階層色で塗りつぶし
        .background(alignment: .trailing) {
            let fillColor: Color = depthColor(depth).opacity(0.8)
            // 塗りの左端 = 縦線の位置（depth 0 は行全体）
            let paintLeft: CGFloat = depth == 0
                ? 0
                : 16 + CGFloat(depth - 1) * indentStep + indentStep / 2
            GeometryReader { geo in
                fillColor
                    .frame(width: geo.size.width - paintLeft)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        // 子階層以降の縦線（帯の中央、編集中・メモ編集中は非表示）
        .overlay(alignment: .leading) {
            if depth > 0 && editingItemID == nil && memoEditingItemID == nil {
                ZStack(alignment: .leading) {
                    ForEach(0..<depth, id: \.self) { d in
                        Rectangle()
                            .fill(depthAccentColor(d + 1))
                            .frame(width: 1.5)
                            .padding(.leading, 16 + CGFloat(d) * indentStep + indentStep / 2 - 0.75)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        // 下の区切り線
        .background(alignment: .bottom) {
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 0.5)
                .padding(.leading, indentLeading(depth) + 12)
        }
        // List行スタイル除去
        .listRowSeparator(.hidden)
        .listRowBackground(Color(uiColor: .systemBackground))
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
    }

    // MARK: - 追加ボタン
    @ViewBuilder
    private func addItemRow(parentID: UUID?, depth: Int, rowID: String) -> some View {
        if let parentID = parentID,
           let parent = allItems.first(where: { $0.id == parentID }) {
            // 子項目追加
            let accentColor = depthAccentColor(depth)

            Group {
                    Button {
                        // 編集中・メモ編集中なら先に確定してから追加
                        commitCurrentEditIfNeeded()
                        addEmptyItemAndEdit(parentID: parentID)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(accentColor)
                            // リスト内に子項目が1つもない時のみガイドテキスト（depth 1 = 紫のみ）
                            if depth == 1 && !allItems.contains(where: { $0.parentID != nil }) {
                                Text("子項目を追加できます")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(accentColor)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 12)
                    .padding(.vertical, 2)
                    // チェックボックス中心に合わせる: indentLeading(depth) + 12(padding) + 17(34/2) - 7.5(15/2) = depth*28 + 21.5
                    .padding(.leading, CGFloat(depth) * indentStep + 21.5)
                    // L字罫線：角丸＋横線のみCanvasで描画（編集中・メモ編集中は非表示）
                    .overlay(alignment: .topLeading) {
                        if editingItemID == nil && memoEditingItemID == nil {
                            let lineX: CGFloat = 16 + CGFloat(depth - 1) * indentStep + indentStep / 2 - 0.75
                            LShapeCorner(color: accentColor)
                                .frame(width: 14, height: 12)
                                .padding(.leading, lineX)
                        }
                    }
                    // 縦線（上半分のみ、編集中・メモ編集中は非表示）
                    .overlay(alignment: .topLeading) {
                        if editingItemID == nil && memoEditingItemID == nil {
                            let lineX: CGFloat = 16 + CGFloat(depth - 1) * indentStep + indentStep / 2 - 0.75
                            GeometryReader { geo in
                                Rectangle()
                                    .fill(accentColor)
                                    .frame(width: 1.5, height: geo.size.height * 0.5 - 12)
                                    .padding(.leading, lineX)
                            }
                        }
                    }
            }
            // 縦線の位置から右をこの階層の色で塗りつぶし
            .background(alignment: .trailing) {
                let fillColor: Color = depthColor(depth).opacity(0.8)
                let paintLeft: CGFloat = depth == 0
                    ? 0
                    : 16 + CGFloat(depth - 1) * indentStep + indentStep / 2
                GeometryReader { geo in
                    fillColor
                        .frame(width: geo.size.width - paintLeft)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            // シンプルモード: 上位祖先の縦線（編集中・メモ編集中は非表示）
            .overlay(alignment: .leading) {
                if depth > 1 && editingItemID == nil && memoEditingItemID == nil {
                    ZStack(alignment: .leading) {
                        ForEach(0..<(depth - 1), id: \.self) { d in
                            Rectangle()
                                .fill(depthAccentColor(d + 1))
                                .frame(width: 1.5)
                                .padding(.leading, 16 + CGFloat(d) * indentStep + indentStep / 2 - 0.75)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color(uiColor: .systemBackground))
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        } else {
            // ルート追加（チェックボックスの中心に緑＋ボタン）
            // チェックボックスと同じレイアウト構造で自動センター合わせ
            Button {
                commitCurrentEditIfNeeded()
                addEmptyItemAndEdit(parentID: nil)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.green.opacity(0.5))
                        .frame(width: 34, height: 34)
                    if allItems.isEmpty {
                        Text("最初の項目を追加しましょう")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.green.opacity(0.6))
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12) // 通常行と同じpadding
            .padding(.vertical, 4)
            .listRowSeparator(.hidden)
            .listRowBackground(Color(uiColor: .systemBackground))
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

    // 文字列IDでスクロール（+ボタン行など）
    private func scrollToRow(_ rowID: String, proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeInOut(duration: 0.15)) {
                proxy.scrollTo(rowID, anchor: .bottom)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeInOut(duration: 0.15)) {
                proxy.scrollTo(rowID, anchor: .bottom)
            }
        }
    }

    // MARK: - 選択項目を削除（子も再帰的に削除）
    private func deleteSelectedItems() {
        for id in selectedItems {
            if let item = allItems.first(where: { $0.id == id }) {
                deleteItem(item)
            }
        }
        selectedItems.removeAll()
        isSelectMode = false
    }

    // MARK: - 選択の追加/削除（子孫も再帰的に、状態記憶付き）
    private func addToSelection(_ id: UUID) {
        // 子孫の現在の選択状態をスナップショットに保存
        let descendantIDs = allDescendantIDs(of: id)
        let currentSelection = selectedItems.intersection(descendantIDs)
        selectionSnapshot[id] = currentSelection

        // 自分+子孫を全選択
        selectedItems.insert(id)
        for did in descendantIDs {
            selectedItems.insert(did)
        }
    }

    private func removeFromSelection(_ id: UUID) {
        // 自分を外す
        selectedItems.remove(id)

        // スナップショットがあれば復元、なければ子孫も全解除
        if let snapshot = selectionSnapshot.removeValue(forKey: id) {
            let descendantIDs = allDescendantIDs(of: id)
            for did in descendantIDs {
                if snapshot.contains(did) {
                    selectedItems.insert(did)
                } else {
                    selectedItems.remove(did)
                }
            }
        } else {
            for child in allItems where child.parentID == id {
                removeFromSelection(child.id)
            }
        }
    }

    // 全子孫IDを再帰的に取得
    private func allDescendantIDs(of id: UUID) -> Set<UUID> {
        var result = Set<UUID>()
        for child in allItems where child.parentID == id {
            result.insert(child.id)
            result.formUnion(allDescendantIDs(of: child.id))
        }
        return result
    }

    // MARK: - 全項目削除（リスト自体は残す）
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
        let rows = flatRows

        // 移動元のアイテムを特定
        guard let sourceIndex = source.first,
              case .item(let movedItem) = rows[sourceIndex].kind else { return }

        let movedParentID = movedItem.parentID

        // 移動先の隣接アイテムの親を確認
        // destination は「挿入先のインデックス」なので、その前後を確認
        let checkIndex = destination > sourceIndex
            ? min(destination, rows.count - 1)      // 下に移動: 挿入先の位置
            : max(destination, 0)                     // 上に移動: 挿入先の位置

        // 移動先が同じ親でなければ元に戻す
        var isValidMove = false
        if checkIndex >= 0 && checkIndex < rows.count {
            switch rows[checkIndex].kind {
            case .item(let destItem):
                isValidMove = destItem.parentID == movedParentID
            case .addButton(let parentID):
                // ＋ボタン行は、その親の子として扱う
                isValidMove = parentID == movedParentID
            case .bottomSpacer:
                isValidMove = false
            }
        }

        // 不正な移動 → sortOrderを振り直して元の順序を強制復元
        if !isValidMove {
            let siblings = allItems
                .filter { $0.parentID == movedParentID }
                .sorted { $0.sortOrder < $1.sortOrder }
            for (i, item) in siblings.enumerated() {
                item.sortOrder = i
            }
            try? modelContext.save()
            return
        }

        // 正当な移動 → flatRows上で移動してsortOrder更新
        var mutableRows = rows
        mutableRows.move(fromOffsets: source, toOffset: destination)

        let siblings = mutableRows.compactMap { row -> TodoItem? in
            if case .item(let item) = row.kind, item.parentID == movedParentID {
                return item
            }
            return nil
        }
        for (i, item) in siblings.enumerated() {
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
        // 編集中の項目があれば先に確定するだけ（新しい編集には入らない）
        if let editID = editingItemID,
           let editItem = allItems.first(where: { $0.id == editID }) {
            commitEdit(item: editItem)
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            return
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
            // 編集確定後は省略表示に戻す
            memoOpenItems.remove(target.id)
        }
        memoEditingItemID = nil
        memoEditingText = ""
    }

    // MARK: - Enter押下時（連続入力: 確定→同じ親に次のアイテム作成）
    private func submitEdit(item: TodoItem) {
        let trimmed = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            // 空のままEnter → 削除して編集終了（連続入力の抜け口）
            deleteItem(item)
            editingItemID = nil
            editingText = ""
        } else {
            // テキストあり → 確定して次の行を自動生成
            // 1. キーボード維持フラグON（隠しTextFieldがフォーカスを取る）
            isChainEditing = true
            item.title = trimmed
            item.updatedAt = Date()
            try? modelContext.save()
            // 2. 次のUIサイクルで新アイテム作成（キーボード維持中に）
            DispatchQueue.main.async {
                addEmptyItemAndEdit(parentID: item.parentID)
                // 3. 新TextFieldにフォーカスが移ったらフラグ解除
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isChainEditing = false
                }
            }
        }
    }

    // MARK: - 編集確定（フォーカス外れ時など、連続入力しない）
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

    // MARK: - 現在の編集を確定（+ボタンタップ時に使う）
    private func commitCurrentEditIfNeeded() {
        if let editID = editingItemID,
           let item = allItems.first(where: { $0.id == editID }) {
            commitEdit(item: item)
        }
        commitMemo()
    }

    // MARK: - 空の項目を作成して即編集開始（saveはしない＝確定まで永続化しない）
    private func addEmptyItemAndEdit(parentID: UUID?) {
        let siblings = allItems.filter { $0.parentID == parentID }
        let maxOrder = siblings.map(\.sortOrder).max() ?? -1

        let item = TodoItem(title: "", listID: todoList.id, parentID: parentID, sortOrder: maxOrder + 1)
        item.tags = [getOrCreateTodoTag()]

        // アニメーションなしで挿入（depth 0で一瞬描画されるチラつき防止）
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            modelContext.insert(item)
            // 親を展開済みにする（ルートの場合は仮想親）
            if let parentID = parentID {
                expandedItems.insert(parentID)
            }
            editingItemID = item.id
            editingText = ""
        }

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

    // MARK: - タグ選択ルーレット

    // 現在のリストの親タグ
    private var currentParentTag: Tag? {
        todoList.tags.first(where: { $0.parentTagID == nil && !$0.isSystem })
    }

    // 現在のリストの子タグ
    private var currentChildTag: Tag? {
        guard let parent = currentParentTag else { return nil }
        return todoList.tags.first(where: { $0.parentTagID == parent.id })
    }

    // ルーレットの親タグオプション
    private var parentOptions: [(id: String, name: String, color: Color)] {
        var list: [(String, String, Color)] = [("none", "タグなし", tagColor(for: 0))]
        for tag in allTags where tag.parentTagID == nil && !tag.isSystem {
            list.append((tag.id.uuidString, tag.name, tagColor(for: tag.colorIndex)))
        }
        return list
    }

    // ルーレットの子タグオプション
    private var childOptions: [(id: String, name: String, color: Color)] {
        var list: [(String, String, Color)] = [("none", "子タグなし", tagColor(for: 0))]
        if let parentID = dialParentID {
            for tag in allTags where tag.parentTagID == parentID {
                list.append((tag.id.uuidString, tag.name, tagColor(for: tag.colorIndex)))
            }
        }
        return list
    }

    // ヘッダー内のタグ行
    // 全角8文字に制限
    private func truncTagName(_ name: String) -> String {
        var width: Double = 0
        var result = ""
        for char in name {
            let w: Double = char.isASCII ? 0.5 : 1.0
            if width + w > 8 { return result + "…" }
            width += w
            result.append(char)
        }
        return result
    }

    private var tagRowInHeader: some View {
        HStack(spacing: 3) {
            if let parent = currentParentTag {
                Text(parent.name.prefix(8) + (parent.name.count > 8 ? "…" : ""))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 6).fill(tagColor(for: parent.colorIndex)))
                if let child = currentChildTag {
                    Text(child.name.prefix(6) + (child.name.count > 6 ? "…" : ""))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 5).fill(tagColor(for: child.colorIndex)))
                }
            } else {
                Text("タグなし")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1))
            }
        }
        .onTapGesture {
            dialParentID = currentParentTag?.id
            dialChildID = currentChildTag?.id
            withAnimation(.spring(response: 0.3)) {
                showParentDial = true
            }
        }
    }

    // MARK: - ルーレットパネル（QuickSortCellViewのdialAreaと同じ構造）
    private let trayColor = Color.gray
    private let trayCornerRadius: CGFloat = 10
    private let dialTabWidth: CGFloat = 38
    private let dialTabHeight: CGFloat = 22
    private let dialTabRadius: CGFloat = 6
    private let dialFixedHeight: CGFloat = 211

    private var dialPanel: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                TagDialView(
                    parentOptions: parentOptions,
                    parentSelectedID: $dialParentID,
                    childOptions: childOptions,
                    childSelectedID: $dialChildID,
                    showChild: $showChildDial,
                    isOpen: true,
                    childExternalDragY: $childExternalDragY,
                    onLongPress: nil
                )
                .background {
                    DialEdgeArcShape(radius: 350, dialHeight: 211)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.5), radius: 3, x: -2, y: 0)
                        .allowsHitTesting(false)
                }
                .offset(x: -27, y: -10)

                // 「しまう」ボタン
                Image(systemName: "chevron.right")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxHeight: .infinity)
                    .frame(width: 36)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        saveDialTags()
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showParentDial = false; showChildDial = false
                        }
                    }
            }
            .frame(height: dialFixedHeight)

            // 親タグ追加・子タグ追加ボタン
            ZStack(alignment: .trailing) {
                Button {
                    newTagIsChild = false
                    showNewTagSheet = true
                } label: {
                    Label("親タグ追加", systemImage: "plus.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.trailing, 196)
                if showChildDial {
                    Button {
                        if dialParentID != nil {
                            newTagIsChild = true
                            showNewTagSheet = true
                        }
                    } label: {
                        Label("子タグ追加", systemImage: "plus.circle")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.trailing, 86)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.vertical, 4)
            .offset(y: -13)
        }
        .padding(.top, dialTabHeight + 10)
        .padding(.bottom, 6)
        .padding(.leading, dialTabWidth + 12)
        .padding(.trailing, 12)
        .background(
            TrayWithTabShape(
                tabWidth: dialTabWidth,
                tabHeight: dialTabHeight,
                tabRadius: dialTabRadius,
                bodyRadius: trayCornerRadius,
                bodyPeek: 0
            )
            .fill(trayColor)
            .shadow(color: .black.opacity(0.2), radius: 3, x: -2, y: 0)
        )
        // ルーレットラベル
        .overlay(alignment: .topTrailing) {
            ZStack(alignment: .trailing) {
                Text("親タグ")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(height: dialTabHeight)
                    .padding(.trailing, 236)
                if showChildDial {
                    Text("子タグ")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(height: dialTabHeight)
                        .padding(.trailing, 119)
                }
            }
        }
        // タブ「しまう」ラベル
        .overlay(alignment: .topLeading) {
            Text("しまう")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: dialTabWidth, height: dialTabHeight, alignment: .leading)
                .padding(.leading, 3)
                .contentShape(Rectangle())
                .onTapGesture {
                    saveDialTags()
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showParentDial = false; showChildDial = false
                    }
                }
        }
    }

    // タグ保存
    private func saveDialTags() {
        // システムタグ以外を除去
        todoList.tags.removeAll { !$0.isSystem }

        if let parentID = dialParentID,
           let parentTag = allTags.first(where: { $0.id == parentID }) {
            todoList.tags.append(parentTag)

            if let childID = dialChildID,
               let childTag = allTags.first(where: { $0.id == childID && $0.parentTagID == parentID }) {
                todoList.tags.append(childTag)
            }
        }

        todoList.updatedAt = Date()
        try? modelContext.save()
    }
}

