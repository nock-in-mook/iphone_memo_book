import SwiftUI
import SwiftData

// タグの色パレット（0=タグなし、1〜56=選択可能カラー）
private let tabColors: [Color] = [
    // 0: タグなし
    Color(red: 0.82, green: 0.80, blue: 0.76),
    // 1〜7: 基本色（明るめ）
    Color(red: 0.55, green: 0.80, blue: 0.95),  // 水色
    Color(red: 0.95, green: 0.70, blue: 0.55),  // オレンジ
    Color(red: 0.70, green: 0.90, blue: 0.70),  // 緑
    Color(red: 0.90, green: 0.70, blue: 0.90),  // 紫
    Color(red: 0.95, green: 0.85, blue: 0.55),  // 黄色
    Color(red: 0.95, green: 0.60, blue: 0.60),  // 赤
    Color(red: 0.60, green: 0.75, blue: 0.95),  // 青
    // 8〜14: パステル系
    Color(red: 0.80, green: 0.92, blue: 0.98),  // ベビーブルー
    Color(red: 0.98, green: 0.85, blue: 0.80),  // ピーチ
    Color(red: 0.85, green: 0.95, blue: 0.85),  // ミント
    Color(red: 0.95, green: 0.85, blue: 0.95),  // ラベンダー
    Color(red: 0.98, green: 0.95, blue: 0.80),  // クリーム
    Color(red: 0.98, green: 0.82, blue: 0.82),  // サーモンピンク
    Color(red: 0.82, green: 0.88, blue: 0.98),  // ペリウィンクル
    // 15〜21: 深め
    Color(red: 0.35, green: 0.65, blue: 0.80),  // ティール
    Color(red: 0.80, green: 0.50, blue: 0.35),  // テラコッタ
    Color(red: 0.40, green: 0.70, blue: 0.50),  // フォレスト
    Color(red: 0.65, green: 0.45, blue: 0.70),  // プラム
    Color(red: 0.80, green: 0.70, blue: 0.40),  // マスタード
    Color(red: 0.75, green: 0.40, blue: 0.40),  // ワインレッド
    Color(red: 0.40, green: 0.55, blue: 0.80),  // インディゴ
    // 22〜28: アクセント
    Color(red: 0.50, green: 0.85, blue: 0.80),  // ターコイズ
    Color(red: 0.95, green: 0.55, blue: 0.40),  // コーラル
    Color(red: 0.60, green: 0.82, blue: 0.55),  // ライム
    Color(red: 0.75, green: 0.55, blue: 0.85),  // アメジスト
    Color(red: 0.90, green: 0.80, blue: 0.50),  // ゴールド
    Color(red: 0.85, green: 0.45, blue: 0.55),  // ローズ
    Color(red: 0.50, green: 0.65, blue: 0.85),  // スレートブルー
    // 29〜35: ナチュラル系
    Color(red: 0.85, green: 0.78, blue: 0.68),  // サンド
    Color(red: 0.72, green: 0.82, blue: 0.75),  // セージ
    Color(red: 0.78, green: 0.72, blue: 0.65),  // モカ
    Color(red: 0.88, green: 0.85, blue: 0.78),  // アイボリー
    Color(red: 0.68, green: 0.75, blue: 0.70),  // オリーブグレー
    Color(red: 0.82, green: 0.70, blue: 0.62),  // キャメル
    Color(red: 0.75, green: 0.80, blue: 0.82),  // ブルーグレー
    // 36〜42: ビビッド系
    Color(red: 0.98, green: 0.45, blue: 0.52),  // ホットピンク
    Color(red: 0.30, green: 0.75, blue: 0.93),  // スカイブルー
    Color(red: 0.55, green: 0.88, blue: 0.45),  // ブライトグリーン
    Color(red: 0.98, green: 0.75, blue: 0.30),  // マンゴー
    Color(red: 0.60, green: 0.40, blue: 0.90),  // バイオレット
    Color(red: 0.98, green: 0.42, blue: 0.30),  // トマト
    Color(red: 0.25, green: 0.82, blue: 0.75),  // エメラルド
    // 43〜49: くすみ系（ニュアンスカラー）
    Color(red: 0.75, green: 0.68, blue: 0.72),  // モーヴ
    Color(red: 0.68, green: 0.78, blue: 0.75),  // ダスティミント
    Color(red: 0.82, green: 0.75, blue: 0.72),  // ダスティローズ
    Color(red: 0.72, green: 0.72, blue: 0.80),  // ダスティブルー
    Color(red: 0.78, green: 0.80, blue: 0.68),  // カーキ
    Color(red: 0.80, green: 0.68, blue: 0.68),  // ベージュピンク
    Color(red: 0.68, green: 0.75, blue: 0.82),  // ストーンブルー
    // 50〜56: ダーク系
    Color(red: 0.28, green: 0.45, blue: 0.60),  // ネイビー
    Color(red: 0.55, green: 0.30, blue: 0.30),  // マルーン
    Color(red: 0.30, green: 0.50, blue: 0.38),  // ダークフォレスト
    Color(red: 0.45, green: 0.35, blue: 0.55),  // ダークパープル
    Color(red: 0.55, green: 0.48, blue: 0.30),  // ダークゴールド
    Color(red: 0.40, green: 0.45, blue: 0.50),  // チャコール
    Color(red: 0.50, green: 0.35, blue: 0.45),  // ダークローズ
]

// 「すべて」タブ用の色（薄い黄色）
private let allTabColor = Color(red: 0.98, green: 0.96, blue: 0.82)

func tagColor(for index: Int) -> Color {
    if index == -1 { return allTabColor }
    guard index >= 0 && index < tabColors.count else {
        return tabColors[0]
    }
    return tabColors[index]
}

// 背景色の明るさに応じてテキスト色を白/黒に自動切替
func tagTextColor(for colorIndex: Int) -> Color {
    let bg = tagColor(for: colorIndex)
    let uiColor = UIColor(bg)
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
    // 相対輝度（W3C基準）
    let luminance = 0.299 * r + 0.587 * g + 0.114 * b
    return luminance > 0.55 ? .primary : .white
}

// 紙の質感を表現するオーバーレイ
struct PaperTextureOverlay: View {
    var body: some View {
        Canvas { context, size in
            for _ in 0..<800 {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let opacity = Double.random(in: 0.02...0.08)
                let dotSize = CGFloat.random(in: 0.5...1.5)
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: dotSize, height: dotSize)),
                    with: .color(.black.opacity(opacity))
                )
            }
        }
        .allowsHitTesting(false)
    }
}

// グリッドサイズ定義（列数×行数）
enum GridSizeOption: Int, CaseIterable {
    case grid3x8 = 0   // 3×8
    case grid2x6 = 1   // 2×6
    case grid2x3 = 2   // 2×3
    case grid1x2 = 3   // 1×2
    case full = 4       // 1列・全文表示

    var columns: Int {
        switch self {
        case .grid3x8: return 3
        case .grid2x6: return 2
        case .grid2x3: return 2
        case .grid1x2: return 1
        case .full: return 1
        }
    }

    var label: String {
        switch self {
        case .grid3x8: return "3×8"
        case .grid2x6: return "2×6"
        case .grid2x3: return "2×3"
        case .grid1x2: return "1×2"
        case .full: return "1(全文)"
        }
    }
}

private let borderColor = Color.primary.opacity(0.45)
private let borderWidth: CGFloat = 2.0

struct TabbedMemoListView: View {
    @Query(sort: \Tag.name) private var tags: [Tag]
    @Query(sort: \Memo.createdAt, order: .reverse) private var allMemos: [Memo]
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedTabIndex: Int
    @Binding var searchText: String
    enum SelectMode { case none, delete, moveToTop }
    @State private var selectMode: SelectMode = .none
    @State private var selectedMemoIDs: Set<UUID> = []
    // 後方互換用
    private var isSelectMode: Bool { selectMode != .none }
    // 選択削除確認ダイアログ
    @State private var showDeleteConfirm = false
    // 長押し単体削除確認ダイアログ
    @State private var showSingleDeleteConfirm = false
    @State private var pendingDeleteMemo: Memo? = nil
    // スワイプ方向追跡（トランジション用）
    @State private var swipeDirection: SwipeDirection = .none
    enum SwipeDirection { case none, left, right }
    // タグなし用のグリッドサイズ（UserDefaultsで保存）
    @AppStorage("noTagGridSize") private var noTagGridSize: Int = 2
    // すべて用のグリッドサイズ
    @AppStorage("allTagGridSize") private var allTagGridSize: Int = 2
    // コールバック
    var onAddMemo: ((UUID?) -> Void)?
    var onEditMemo: ((Memo) -> Void)?
    var onDeleteMemo: ((Memo) -> Void)?
    // 入力欄展開時はコンパクト表示（選択削除等を非表示）
    var isCompact = false
    // 「記入中のメモをここに保存」コールバック
    var onAddToCurrentTab: ((UUID?) -> Void)?
    // フラッシュ対象のメモID（保存直後にハイライト）
    @State private var flashMemoID: UUID?
    // タブフラッシュ
    @State private var flashTabIndex: Int?

    // 並び替えシート表示
    @State private var showReorderSheet = false
    // タグ追加シート
    @State private var showAddTagSheet = false
    // 子タグ引き出しドロワー
    @State private var drawerReveal: CGFloat = 0       // 引き出し量（0=閉、maxで全開）
    @State private var drawerDragOffset: CGFloat = 0   // ドラッグ中の一時オフセット
    @State private var selectedChildFilterID: UUID? = nil
    @State private var showAddChildTagSheet = false
    private let drawerHandleWidth: CGFloat = 28         // 「子タグ」タブの幅

    // colorIndex == -1 は「すべて」タブを示す特別な値
    private let allTabColorIndex = -1

    // タブの並び順（sortOrder順、すべて=-1、タグなし=sortOrder）
    @AppStorage("allTagSortOrder") private var allTagSortOrder: Int = -1
    @AppStorage("noTagSortOrder") private var noTagSortOrder: Int = 9999

    private var tabItems: [(label: String, tag: Tag?, colorIndex: Int)] {
        var items: [(label: String, tag: Tag?, colorIndex: Int, order: Int)] = []
        items.append(("すべて", nil, allTabColorIndex, allTagSortOrder))
        items.append(("タグなし", nil, 0, noTagSortOrder))
        for tag in tags where tag.parentTagID == nil {
            items.append((tag.name, tag, tag.colorIndex, tag.sortOrder))
        }
        items.sort { $0.order < $1.order }
        return items.map { ($0.label, $0.tag, $0.colorIndex) }
    }

    // 「すべて」タブかどうか
    private var isAllTab: Bool {
        tabItems[selectedTabIndex].colorIndex == allTabColorIndex
    }

    // 「タグなし」タブかどうか
    private var isNoTagTab: Bool {
        let item = tabItems[selectedTabIndex]
        return item.tag == nil && item.colorIndex != allTabColorIndex
    }

    // 現在の親タグ（あれば）
    private var currentParentTag: Tag? {
        tabItems[selectedTabIndex].tag
    }

    // 現在の親タグの子タグ一覧（sortOrder順）
    private var childTags: [Tag] {
        guard let parentTag = currentParentTag else { return [] }
        return tags
            .filter { $0.parentTagID == parentTag.id }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    // 子タグパネルを表示すべきか（親タグタブのときのみ）
    private var canShowChildTagPanel: Bool {
        !isAllTab && !isNoTagTab && currentParentTag != nil
    }

    // 現在のタブのグリッドサイズ
    private var currentGridSize: GridSizeOption {
        let item = tabItems[selectedTabIndex]
        if item.colorIndex == allTabColorIndex {
            return GridSizeOption(rawValue: allTagGridSize) ?? .grid3x8
        }
        if let tag = item.tag {
            return GridSizeOption(rawValue: tag.gridSize) ?? .grid3x8
        }
        return GridSizeOption(rawValue: noTagGridSize) ?? .grid3x8
    }

    private var currentColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: currentGridSize.columns)
    }

    // 検索クエリ
    private var searchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // 検索中かどうか
    private var isSearchActive: Bool {
        !searchQuery.isEmpty
    }

    // 通常タブ用フィルタ
    // ソート: 固定メモ→通常メモ、それぞれmanualSortOrder昇順→作成日降順
    private func sortedMemos(_ memos: [Memo]) -> [Memo] {
        memos.sorted { a, b in
            // 固定メモを先に
            if a.isPinned != b.isPinned { return a.isPinned }
            // manualSortOrderが0以外なら手動順を優先
            if a.manualSortOrder != b.manualSortOrder {
                return a.manualSortOrder > b.manualSortOrder
            }
            // 同じなら作成日降順
            return a.createdAt > b.createdAt
        }
    }

    private var filteredMemos: [Memo] {
        let item = tabItems[selectedTabIndex]
        // 「すべて」タブ
        if item.colorIndex == allTabColorIndex {
            return sortedMemos(Array(allMemos))
        }
        if let tag = item.tag {
            let parentFiltered = allMemos.filter { memo in
                memo.tags.contains { $0.id == tag.id }
            }
            // 子タグフィルター適用
            if let childID = selectedChildFilterID {
                return sortedMemos(parentFiltered.filter { memo in
                    memo.tags.contains { $0.id == childID }
                })
            }
            return sortedMemos(parentFiltered)
        } else {
            return sortedMemos(allMemos.filter { $0.tags.isEmpty })
        }
    }

    // 検索結果の全メモ
    private var searchResultMemos: [Memo] {
        guard !searchQuery.isEmpty else { return [] }
        return allMemos.filter { memo in
            memo.title.lowercased().contains(searchQuery) ||
            memo.content.lowercased().contains(searchQuery)
        }
    }

    // 検索結果をタグ別にグループ化
    // 返り値: [(タグ名, タグ色Index, メモ配列)]
    private var searchResultsByTag: [(name: String, colorIndex: Int, memos: [Memo])] {
        let hits = searchResultMemos
        guard !hits.isEmpty else { return [] }

        var sections: [(name: String, colorIndex: Int, memos: [Memo])] = []

        // タグなしメモ
        let noTag = hits.filter { $0.tags.isEmpty }
        if !noTag.isEmpty {
            sections.append(("タグなし", 0, noTag))
        }

        // 親タグごと
        for tag in tags where tag.parentTagID == nil {
            let matched = hits.filter { memo in
                memo.tags.contains { $0.id == tag.id }
            }
            if !matched.isEmpty {
                sections.append((tag.name, tag.colorIndex, matched))
            }
        }

        return sections
    }

    private var currentColor: Color {
        tagColor(for: tabItems[selectedTabIndex].colorIndex)
    }

    // 背景色を暗くした色（メモ枚数表示用）
    private var darkenedColor: Color {
        let uiColor = UIColor(currentColor)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: Double(h), saturation: Double(min(s * 1.3, 1.0)), brightness: Double(b * 0.55))
    }

    var body: some View {
        VStack(spacing: 0) {
            if isSearchActive {
                // ── 検索結果モード ──
                searchResultTabBar
                searchResultContent
            } else {
                // ── 通常モード: タブ行 ──
                TabBarView(
                    tabItems: tabItems,
                    selectedTabIndex: $selectedTabIndex,
                    flashTabIndex: flashTabIndex,
                    onSelectModeReset: {
                        selectMode = .none
                        selectedMemoIDs.removeAll()
                        // タブ切替時に子タグフィルターリセット
                        selectedChildFilterID = nil
                        drawerReveal = 0
                        drawerDragOffset = 0
                    },
                    onShowReorderSheet: {
                        showReorderSheet = true
                    },
                    onAddTag: {
                        showAddTagSheet = true
                    }
                )

                // ── 通常モード: メモ一覧 ──
                normalMemoContent
            }
        }
        .alert("\(selectedMemoIDs.count)件のメモを削除します。よろしいですか？", isPresented: $showDeleteConfirm) {
            Button("削除", role: .destructive) {
                deleteSelectedMemos()
            }
            Button("キャンセル", role: .cancel) {}
        }
        .alert("このメモを削除します。よろしいですか？", isPresented: $showSingleDeleteConfirm) {
            Button("削除", role: .destructive) {
                if let memo = pendingDeleteMemo {
                    onDeleteMemo?(memo)
                    modelContext.delete(memo)
                    pendingDeleteMemo = nil
                }
            }
            Button("キャンセル", role: .cancel) {
                pendingDeleteMemo = nil
            }
        }
        .sheet(isPresented: $showReorderSheet) {
            TabReorderSheet(
                tabItems: tabItems,
                allTabColorIndex: allTabColorIndex,
                onReorder: { newOrder in
                    applyTabOrder(newOrder)
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showAddTagSheet) {
            NewTagSheetView(onTagCreated: { newTagID in
                // 新タグのsortOrderを既存タグの最大+1に設定（タグなしの前に入る）
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let newTag = tags.first(where: { $0.id == newTagID }) {
                        let maxTagOrder = tags
                            .filter { $0.parentTagID == nil && $0.id != newTagID }
                            .map { $0.sortOrder }
                            .max() ?? 0
                        newTag.sortOrder = maxTagOrder + 1
                        // noTagSortOrderが新タグより小さければ押し出す
                        if noTagSortOrder <= maxTagOrder + 1 {
                            noTagSortOrder = maxTagOrder + 2
                        }
                    }
                    // 作成したタグのタブを選択
                    if let newIndex = tabItems.firstIndex(where: { $0.tag?.id == newTagID }) {
                        selectedTabIndex = newIndex
                    }
                }
            })
        }
        .onReceive(NotificationCenter.default.publisher(for: .memoSavedFlash)) { notification in
            guard let memoID = notification.userInfo?["memoID"] as? UUID else { return }
            // タブフラッシュ
            flashTabIndex = selectedTabIndex
            // メモカードフラッシュ
            flashMemoID = memoID
            // フラッシュを一定時間後にリセット
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.5)) {
                    flashTabIndex = nil
                    flashMemoID = nil
                }
            }
        }
    }

    // MARK: - 検索結果タブバー

    private var searchResultTabBar: some View {
        HStack(spacing: 0) {
            Text("\"\(searchText)\" の検索結果")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .padding(.vertical, 9)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(
                    TrapezoidTabShape()
                        .fill(Color(red: 0.85, green: 0.90, blue: 0.95))
                )
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    // MARK: - 検索結果コンテンツ

    private var searchResultContent: some View {
        let searchColor = Color(red: 0.88, green: 0.91, blue: 0.95)
        let resultSections = searchResultsByTag
        let totalHits = searchResultMemos.count
        let searchColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)

        return GeometryReader { geo in
            ZStack {
                // 背景
                searchColor.ignoresSafeArea(edges: .bottom)
                PaperTextureOverlay().ignoresSafeArea(edges: .bottom)

                if resultSections.isEmpty {
                    // ヒットなし
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("見つかりませんでした")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            // ヒット件数
                            Text("\(totalHits)件ヒット")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.top, 4)

                            // タグ別セクション
                            ForEach(resultSections, id: \.name) { section in
                                let sectionColor = tagColor(for: section.colorIndex)
                                VStack(alignment: .leading, spacing: 8) {
                                    // セクションヘッダー（タグバッジ + 件数）
                                    HStack(spacing: 8) {
                                        Text(section.name)
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(sectionColor)
                                            )
                                        Text("\(section.memos.count)件")
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.top, 10)

                                    // メモグリッド（2列）
                                    LazyVGrid(columns: searchColumns, spacing: 8) {
                                        ForEach(section.memos) { memo in
                                            SearchMemoCardView(memo: memo, query: searchQuery)
                                                .onTapGesture {
                                                    onEditMemo?(memo)
                                                }
                                                .contextMenu {
                                                    Button {
                                                        UIPasteboard.general.string = memo.content
                                                    } label: {
                                                        Label("コピー", systemImage: "doc.on.doc")
                                                    }
                                                    Button(role: .destructive) {
                                                        onDeleteMemo?(memo)
                                                        modelContext.delete(memo)
                                                    } label: {
                                                        Label("削除", systemImage: "trash")
                                                    }
                                                }
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.bottom, 8)
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(sectionColor.opacity(0.25))
                                )
                                .padding(.horizontal, 6)
                            }
                        }
                        .padding(.top, 6)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
    }

    // MARK: - 通常メモコンテンツ

    private var normalMemoContent: some View {
        GeometryReader { geo in
            ZStack {
                // メモコンテンツ（タブごとにトランジション）
                ZStack {
                    currentColor
                        .ignoresSafeArea(edges: .bottom)

                    PaperTextureOverlay()
                        .ignoresSafeArea(edges: .bottom)

                    if filteredMemos.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "note.text")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("メモがありません")
                                .font(.system(size: 14, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollViewReader { scrollProxy in
                        ScrollView {
                            VStack(spacing: 0) {
                                // 上部スペーサー（ツールバー分、タップ不可）
                                Color.clear
                                    .frame(height: (drawerReveal > 0 && canShowChildTagPanel) ? 50 + drawerBandHeight : 50)
                                    .allowsHitTesting(false)

                                LazyVGrid(columns: currentColumns, spacing: 8) {
                                    ForEach(filteredMemos) { memo in
                                        memoGridItem(memo: memo, availableHeight: geo.size.height)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.bottom, 40)
                            }
                            .id("memoGrid")
                        }
                        .onChange(of: flashMemoID) { _, newValue in
                            if newValue != nil {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    scrollProxy.scrollTo("memoGrid", anchor: .top)
                                }
                            }
                        }
                        }
                    }
                }
                .id(selectedTabIndex)
                .transition(.asymmetric(
                    insertion: .move(edge: swipeDirection == .left ? .trailing : .leading),
                    removal: .move(edge: swipeDirection == .left ? .leading : .trailing)
                ))
                // メモグリッド部分だけフォルダ移動スワイプに反応
                .simultaneousGesture(
                    DragGesture(minimumDistance: 50)
                        .onEnded { value in
                            let horizontal = abs(value.translation.width)
                            let vertical = abs(value.translation.height)
                            guard horizontal > vertical * 1.5 else { return }

                            let count = tabItems.count
                            if value.translation.width < -50 {
                                swipeDirection = .left
                                withAnimation(.easeOut(duration: 0.25)) {
                                    selectedTabIndex = (selectedTabIndex + 1) % count
                                }
                            } else if value.translation.width > 50 {
                                swipeDirection = .right
                                withAnimation(.easeOut(duration: 0.25)) {
                                    selectedTabIndex = (selectedTabIndex - 1 + count) % count
                                }
                            }
                        }
                )

                // 上部ツールバー
                if isCompact {
                    // コンパクト時（入力欄展開）: 「記入中のメモをここに保存」
                    HStack {
                        Spacer()
                        Button {
                            let currentTag = tabItems[selectedTabIndex].tag
                            onAddToCurrentTab?(currentTag?.id)
                        } label: {
                            Label("記入中のメモをここに保存", systemImage: "arrow.down.doc")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color(uiColor: .systemBackground).opacity(0.85))
                                )
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                } else {
                ZStack(alignment: .top) {
                    VStack(spacing: 0) {
                        // 子タグドロワー表示スペース（＋下余白6pt）
                        if canShowChildTagPanel && drawerReveal > 0 {
                            Color.clear.frame(height: drawerBandHeight + 6)
                        }

                        // メモ枚数 + 保存ボタン行（ZStackでセンタリング）
                        ZStack {
                            if isSelectMode {
                                // 選択モード中のガイドテキスト
                                Text(selectMode == .delete
                                     ? "削除するメモを選択してください"
                                     : "トップに移動するメモを選択してください")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                            } else {
                                HStack {
                                    Text("\(filteredMemos.count)枚のメモ")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundStyle(darkenedColor)
                                    Spacer()
                                }
                                Button {
                                    let currentTag = tabItems[selectedTabIndex].tag
                                    onAddMemo?(currentTag?.id)
                                } label: {
                                    Label("このタグにメモ作成", systemImage: "plus.circle")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 2)
                                        .padding(.vertical, 0)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color(uiColor: .systemBackground).opacity(0.85))
                                )
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                    }
                    .background(currentColor)

                    // 子タグ引き出しドロワー
                    if !isCompact && canShowChildTagPanel {
                        childTagDrawer
                            .animation(.spring(response: 0.3), value: drawerReveal)
                    }

                    // 左下: ゴミ箱ボタン
                    if !isCompact {
                    VStack {
                        Spacer()
                        HStack {
                        if isSelectMode {
                            // 取消ボタン
                            Button {
                                selectMode = .none
                                selectedMemoIDs.removeAll()
                            } label: {
                                Text("取消")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(Color.blue.opacity(0.7))
                                            .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            // 実行ボタン（モードに応じて変わる）
                            if selectMode == .delete {
                                Button {
                                    showDeleteConfirm = true
                                } label: {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 17))
                                        .foregroundStyle(selectedMemoIDs.isEmpty ? Color.secondary : Color.red)
                                        .padding(10)
                                        .background(
                                            Capsule()
                                                .fill(Color(uiColor: .systemGray6))
                                                .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.gray.opacity(0.4), lineWidth: 1.0)
                                        )
                                }
                                .buttonStyle(.plain)
                                .disabled(selectedMemoIDs.isEmpty)
                            } else if selectMode == .moveToTop {
                                Button {
                                    if !selectedMemoIDs.isEmpty {
                                        moveSelectedToTop()
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        MoveToTopIcon()
                                            .frame(width: 18, height: 18)
                                        Text("トップに移動")
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    }
                                    .foregroundStyle(selectedMemoIDs.isEmpty ? .secondary : .primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(Color(uiColor: .systemGray6))
                                            .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.gray.opacity(0.4), lineWidth: 1.0)
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(selectedMemoIDs.isEmpty)
                            }
                        } else {
                            // 通常時: ゴミ箱ボタン
                            Button {
                                selectMode = .delete
                                selectedMemoIDs.removeAll()
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 17))
                                    .foregroundStyle(.secondary)
                                    .padding(10)
                                    .background(
                                        Capsule()
                                            .fill(Color(uiColor: .systemGray6))
                                            .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.gray.opacity(0.4), lineWidth: 1.0)
                                    )
                            }
                            .buttonStyle(.plain)
                            // 通常時: トップに移動ボタン
                            Button {
                                selectMode = .moveToTop
                                selectedMemoIDs.removeAll()
                            } label: {
                                MoveToTopIcon()
                                    .frame(width: 20, height: 20)
                                    .foregroundStyle(.secondary)
                                    .padding(10)
                                    .background(
                                        Capsule()
                                            .fill(Color(uiColor: .systemGray6))
                                            .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.gray.opacity(0.4), lineWidth: 1.0)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                            Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                    }
                    }

                    // 右下: グリッドサイズボタン
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            gridSizeButton
                                .padding(.horizontal, 10)
                                .padding(.bottom, 8)
                        }
                    }
                }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: currentGridSize)
        }
    }

    // MARK: - 子タグ引き出しドロワー

    /// ドロワー全体の現在の引き出し幅（確定値 + ドラッグ中オフセット）
    private var effectiveDrawerReveal: CGFloat {
        max(0, drawerReveal + drawerDragOffset)
    }

    private let drawerBandHeight: CGFloat = 36  // トレーの高さ
    private let drawerHandleHeight: CGFloat = 23  // 取っ手の高さ
    private let drawerHandleTextWidth: CGFloat = 52  // 「◁子タグ」横書き幅

    /// 子タグのコンテンツ幅を計算（+ボタン + 全チップ + パディング）
    private var drawerContentWidth: CGFloat {
        let children = childTags
        let chipPadding: CGFloat = 20  // 各チップの左右padding合計
        let chipSpacing: CGFloat = 6
        let plusButtonWidth: CGFloat = 32  // +ボタン + 余白
        let edgePadding: CGFloat = 20    // leading/trailing余白

        if children.isEmpty {
            // 「子タグなし」テキスト分
            return plusButtonWidth + 120 + edgePadding
        }

        // 「すべて」チップ
        var total: CGFloat = plusButtonWidth + edgePadding
        let allLabel = "すべて"
        let allWidth = CGFloat(allLabel.count) * 13 + chipPadding
        total += allWidth + chipSpacing

        // 各子タグチップ
        for child in children {
            let labelWidth = CGFloat(child.name.count) * 13 + chipPadding
            total += labelWidth + chipSpacing
        }

        return total
    }

    private var childTagDrawer: some View {
        GeometryReader { geo in
            let screenMaxReveal = geo.size.width - 10 - 30  // 取っ手幅（30pt）を確保
            // コンテンツ幅 or 画面幅の小さい方が最大引き出し量
            let contentMax = min(drawerContentWidth, screenMaxReveal)
            let reveal = min(max(0, effectiveDrawerReveal), contentMax)
            let children = childTags
            let parentName = currentParentTag?.name ?? ""
            let handleWidth: CGFloat = reveal > 0 ? 30 : drawerHandleTextWidth
            let totalWidth = handleWidth + reveal

            HStack(spacing: 0) {
                // 左端: 「◁ 子タグ」取っ手（帯と一体化）
                Group {
                    if reveal > 0 {
                        Image(systemName: "arrowtriangle.right.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.leading, 4)
                    } else {
                        HStack(spacing: 2) {
                            Image(systemName: "arrowtriangle.left.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.white.opacity(0.8))
                            Text("子タグ")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .fixedSize()
                        }
                    }
                }
                .frame(width: reveal > 0 ? 30 : drawerHandleTextWidth, height: reveal > 0 ? drawerBandHeight : drawerHandleHeight)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        if drawerReveal > 0 {
                            drawerReveal = 0
                        } else {
                            drawerReveal = contentMax
                        }
                    }
                }

                // トレー内容（子タグチップ群）— 帯の続き
                if reveal > 0 {
                    ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        if children.isEmpty {
                            Text("\(parentName)の子タグなし")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.white.opacity(0.8))
                                .lineLimit(1)
                        } else {
                            // 子タグ横並び
                            HStack(spacing: 6) {
                                // 「すべて」オプション
                                childTagChip(label: "すべて", colorIndex: currentParentTag?.colorIndex ?? 0, isSelected: selectedChildFilterID == nil, id: "childTag_all")
                                    .onTapGesture {
                                        selectedChildFilterID = nil
                                    }

                                // 子タグ群
                                ForEach(children, id: \.id) { child in
                                    childTagChip(label: child.name, colorIndex: child.colorIndex, isSelected: selectedChildFilterID == child.id, id: "childTag_\(child.id)")
                                        .onTapGesture {
                                            selectedChildFilterID = child.id
                                        }
                                }
                            }
                        }

                        // 追加ボタン（一番右）
                        Button {
                            showAddChildTagSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.3))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.leading, 4)
                    .padding(.trailing, 8)
                    }
                    .frame(height: drawerBandHeight)
                }
            }
            // 帯全体の背景（不透明グレー）
            .frame(width: totalWidth, height: reveal > 0 ? drawerBandHeight : drawerHandleHeight)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 8,
                    bottomLeadingRadius: 8,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0
                )
                .fill(Color.gray)
                .shadow(color: .black.opacity(0.2), radius: 3, x: -2, y: 2)
            )
            .contentShape(Rectangle())  // タップ・ドラッグ領域を帯だけに限定
            .clipped()
            // 右端に配置
            .position(x: geo.size.width - totalWidth / 2, y: (reveal > 0 ? drawerBandHeight : drawerHandleHeight) / 2 + 6)
            // ドラッグジェスチャー（帯のみ反応）
            .gesture(
                DragGesture()
                    .onChanged { value in
                        drawerDragOffset = -value.translation.width
                    }
                    .onEnded { value in
                        let totalReveal = drawerReveal + drawerDragOffset
                        let velocity = -value.predictedEndTranslation.width
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            if velocity > 200 {
                                drawerReveal = contentMax
                            } else if velocity < -200 {
                                drawerReveal = 0
                            } else if totalReveal > contentMax * 0.3 {
                                drawerReveal = contentMax
                            } else {
                                drawerReveal = 0
                            }
                            drawerDragOffset = 0
                        }
                    }
            )
            .sheet(isPresented: $showAddChildTagSheet) {
                NewTagSheetView(parentTagID: currentParentTag?.id, onTagCreated: { newTagID in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        selectedChildFilterID = newTagID
                    }
                })
            }
        }
        .frame(height: drawerBandHeight + 8)
    }

    // 子タグチップ（個別の子タグカード）
    private func childTagChip(label: String, colorIndex: Int, isSelected: Bool, id: String) -> some View {
        Text(label)
            .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
            .foregroundStyle(tagTextColor(for: colorIndex))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(tagColor(for: colorIndex))
                    .opacity(isSelected ? 1.0 : 0.6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.white, lineWidth: isSelected ? 2.0 : 0)
            )
            .id(id)
    }

    // グリッドサイズ切替ボタン
    private var gridSizeButton: some View {
        Menu {
            ForEach(GridSizeOption.allCases.reversed(), id: \.rawValue) { option in
                Button {
                    setGridSize(option)
                } label: {
                    HStack {
                        Text(option.label)
                        if currentGridSize == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 15))
                Text(currentGridSize.label)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color(uiColor: .systemGray6))
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
            )
            .overlay(
                Capsule()
                    .stroke(Color.gray.opacity(0.4), lineWidth: 1.0)
            )
        }
    }

    // メモをトップに移動（manualSortOrderを現在の最大+1に）
    private func moveToTop(_ memo: Memo) {
        let maxOrder = allMemos.map(\.manualSortOrder).max() ?? 0
        memo.manualSortOrder = maxOrder + 1
    }

    // 選択中のメモをトップに移動
    private func moveSelectedToTop() {
        let maxOrder = allMemos.map(\.manualSortOrder).max() ?? 0
        var offset = 1
        for memo in allMemos where selectedMemoIDs.contains(memo.id) {
            memo.manualSortOrder = maxOrder + offset
            offset += 1
        }
        selectedMemoIDs.removeAll()
        selectMode = .none
    }

    private func deleteSelectedMemos() {
        for memo in allMemos where selectedMemoIDs.contains(memo.id) {
            onDeleteMemo?(memo)
            modelContext.delete(memo)
        }
        selectedMemoIDs.removeAll()
        selectMode = .none
    }

    private func setGridSize(_ option: GridSizeOption) {
        let item = tabItems[selectedTabIndex]
        if item.colorIndex == allTabColorIndex {
            allTagGridSize = option.rawValue
        } else if let tag = item.tag {
            tag.gridSize = option.rawValue
        } else {
            noTagGridSize = option.rawValue
        }
    }

    // メモグリッドの1アイテム（型推論負荷軽減のため分離）
    @ViewBuilder
    private func memoGridItem(memo: Memo, availableHeight: CGFloat) -> some View {
        HStack(spacing: 4) {
            if isSelectMode {
                Image(systemName: selectedMemoIDs.contains(memo.id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(selectedMemoIDs.contains(memo.id) ? .red : .gray.opacity(0.6))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        handleMemoTap(memo)
                    }
            }
            MemoCardView(memo: memo, gridSize: currentGridSize, availableHeight: availableHeight, onTap: {
                handleMemoTap(memo)
            })
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue, lineWidth: flashMemoID == memo.id ? 3 : 0)
                        .opacity(flashMemoID == memo.id ? 1 : 0)
                        .animation(.easeInOut(duration: 0.3).repeatCount(3, autoreverses: true), value: flashMemoID)
                )
        }
        .draggable(memo.id.uuidString) {
            MemoCardView(memo: memo, gridSize: currentGridSize, availableHeight: availableHeight)
                .frame(width: 120, height: 60)
                .opacity(0.8)
        }
        .contextMenu {
            if !isSelectMode {
                Button {
                    moveToTop(memo)
                } label: {
                    Label("トップに移動", systemImage: "arrow.up.to.line")
                }
                Button {
                    memo.isPinned.toggle()
                } label: {
                    Label(memo.isPinned ? "固定を解除" : "トップに常時固定", systemImage: memo.isPinned ? "pin.slash" : "pin")
                }
                Button {
                    UIPasteboard.general.string = memo.content
                } label: {
                    Label("コピー", systemImage: "doc.on.doc")
                }
                Button(role: .destructive) {
                    pendingDeleteMemo = memo
                    showSingleDeleteConfirm = true
                } label: {
                    Label("削除", systemImage: "trash")
                }
            }
        }
    }

    // メモカードタップ処理
    private func handleMemoTap(_ memo: Memo) {
        if isSelectMode {
            if selectedMemoIDs.contains(memo.id) {
                selectedMemoIDs.remove(memo.id)
            } else {
                selectedMemoIDs.insert(memo.id)
            }
        } else {
            onEditMemo?(memo)
        }
    }

    // 並び替えシートからの新しい順序を適用（全タブ対象）
    private func applyTabOrder(_ newOrder: [(label: String, tag: Tag?, colorIndex: Int)]) {
        let currentItem = tabItems[selectedTabIndex]

        for (i, item) in newOrder.enumerated() {
            if item.colorIndex == allTabColorIndex {
                allTagSortOrder = i
            } else if let tag = item.tag {
                tag.sortOrder = i
            } else {
                noTagSortOrder = i
            }
        }

        // 選択タブを追従
        if let newIndex = newOrder.firstIndex(where: { item in
            if currentItem.colorIndex == allTabColorIndex {
                return item.colorIndex == allTabColorIndex
            } else if let currentTag = currentItem.tag {
                return item.tag?.id == currentTag.id
            } else {
                return item.tag == nil && item.colorIndex != allTabColorIndex
            }
        }) {
            selectedTabIndex = newIndex
        }
    }

}

// 検索結果用メモカード（ハイライト＋マッチ行中心表示）
struct SearchMemoCardView: View {
    let memo: Memo
    let query: String

    // マッチした文字列をハイライトしたAttributedStringを生成
    private func highlighted(_ text: String, fontSize: CGFloat, weight: Font.Weight = .regular) -> AttributedString {
        var result = AttributedString(text)
        result.font = .system(size: fontSize, design: .rounded)
        result.foregroundColor = .secondary

        let lowerText = text.lowercased()
        let lowerQuery = query.lowercased()
        var searchStart = lowerText.startIndex

        while let range = lowerText.range(of: lowerQuery, range: searchStart..<lowerText.endIndex) {
            let attrStart = AttributedString.Index(range.lowerBound, within: result)!
            let attrEnd = AttributedString.Index(range.upperBound, within: result)!
            result[attrStart..<attrEnd].backgroundColor = .yellow.opacity(0.5)
            result[attrStart..<attrEnd].foregroundColor = .primary
            result[attrStart..<attrEnd].font = .system(size: fontSize, weight: .semibold, design: .rounded)
            searchStart = range.upperBound
        }

        return result
    }

    // 本文からマッチ行の前後を抜き出す（マッチ行が中心になるように）
    private var contextSnippet: String {
        let lines = memo.content.components(separatedBy: .newlines)
        let lowerQuery = query.lowercased()

        // マッチする最初の行を見つける
        if let matchIndex = lines.firstIndex(where: { $0.lowercased().contains(lowerQuery) }) {
            // マッチ行の前後1行を含めて最大3行
            let start = max(0, matchIndex - 1)
            let end = min(lines.count - 1, matchIndex + 1)
            return lines[start...end].joined(separator: "\n")
        }

        // タイトルにだけマッチした場合は先頭3行
        return lines.prefix(3).joined(separator: "\n")
    }

    // タイトルにマッチがあるか
    private var titleHasMatch: Bool {
        !memo.title.isEmpty && memo.title.lowercased().contains(query.lowercased())
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 2) {
                // タイトル
                if !memo.title.isEmpty {
                    if titleHasMatch {
                        Text(highlighted(memo.title, fontSize: 15, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    } else {
                        Text(memo.title)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }

                // 本文（マッチ行中心のスニペット + ハイライト）
                Text(highlighted(contextSnippet, fontSize: 13))
                    .lineLimit(4)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(8)

            // 右上マーク（ピン・マークダウン）
            VStack(spacing: 2) {
                if memo.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.orange.opacity(0.6))
                }
                if memo.isMarkdown {
                    Text("M↓")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.gray.opacity(0.5))
                }
            }
            .padding(3)
        }
        .frame(height: 90)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
    }
}

// メモカード（グリッドサイズ対応）
struct MemoCardView: View {
    let memo: Memo
    var gridSize: GridSizeOption = .grid3x8
    var availableHeight: CGFloat = 0
    var onTap: (() -> Void)? = nil

    // グリッドサイズに応じたスタイル
    private var titleFont: CGFloat {
        switch gridSize {
        case .grid3x8: return 13
        case .grid2x6: return 15
        case .grid2x3: return 16
        case .grid1x2: return 17
        case .full: return 18
        }
    }

    private var bodyFont: CGFloat {
        switch gridSize {
        case .grid3x8: return 11
        case .grid2x6: return 13
        case .grid2x3: return 14
        case .grid1x2: return 15
        case .full: return 16
        }
    }

    private var bodyLines: Int {
        switch gridSize {
        case .grid3x8: return 1
        case .grid2x6: return 3
        case .grid2x3: return 5
        case .grid1x2: return 4
        case .full: return 0  // 0 = 無制限
        }
    }

    private var cardPadding: CGFloat {
        switch gridSize {
        case .grid3x8: return 4
        case .grid2x6: return 8
        case .grid2x3: return 10
        case .grid1x2: return 12
        case .full: return 12
        }
    }

    // availableHeightはプロパティ宣言で定義済み

    // 全文モードでは高さ固定しない
    private var isFullMode: Bool { gridSize == .full }

    private var cardHeight: CGFloat? {
        if isFullMode { return nil }  // 全文モードは高さ自動
        guard availableHeight > 0 else {
            switch gridSize {
            case .grid3x8: return 40
            case .grid2x6: return 72
            case .grid2x3: return 120
            case .grid1x2: return 180
            case .full: return nil
            }
        }
        let rows: CGFloat
        switch gridSize {
        case .grid3x8: rows = 8
        case .grid2x6: rows = 6
        case .grid2x3: rows = 3
        case .grid1x2: rows = 2
        case .full: return nil
        }
        let spacing: CGFloat = 8
        let topPadding: CGFloat = 58
        let bottomPadding: CGFloat = 70
        let usable = availableHeight - topPadding - bottomPadding - (spacing * (rows - 1))
        return max(40, usable / rows)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 2) {
                // タイトルがあれば表示、なければスキップ
                if !memo.title.isEmpty {
                    Text(memo.title)
                        .font(.system(size: titleFont, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Text(memo.content)
                    .font(.system(size: bodyFont))
                    .foregroundStyle(.secondary)
                    .lineLimit(bodyLines == 0 ? nil : bodyLines)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(cardPadding)

            // 右上マーク（ピン・マークダウン）
            VStack(spacing: 2) {
                if memo.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.orange.opacity(0.6))
                }
                if memo.isMarkdown {
                    Text("M↓")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.gray.opacity(0.5))
                }
            }
            .padding(3)
        }
        .frame(height: gridSize == .grid3x8 ? 36 : gridSize == .grid2x6 ? 48 : gridSize == .grid2x3 ? 104 : gridSize == .grid1x2 ? 160 : cardHeight)
        .background(Color(uiColor: .systemBackground))
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture { onTap?() }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
    }
}

// フォルダ並び替えシート（全タブ対象）
struct TabReorderSheet: View {
    let tabItems: [(label: String, tag: Tag?, colorIndex: Int)]
    let allTabColorIndex: Int
    let onReorder: ([(label: String, tag: Tag?, colorIndex: Int)]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var orderedItems: [(label: String, tag: Tag?, colorIndex: Int)] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ヒントテキスト
                VStack(spacing: 2) {
                    Text("長押しで移動できます")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("（タグ付けルーレットの並び順にも反映されます）")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 8)
                .padding(.bottom, 4)

                List {
                    ForEach(Array(orderedItems.enumerated()), id: \.offset) { index, item in
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(tagColor(for: item.colorIndex))
                                .frame(width: 22, height: 22)
                            Text(item.label)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                        }
                        .padding(.vertical, 2)
                    }
                    .onMove { from, to in
                        orderedItems.move(fromOffsets: from, toOffset: to)
                    }
                }
                .environment(\.editMode, .constant(.active))
            }
            .navigationTitle("フォルダの並び替え")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") {
                        onReorder(orderedItems)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .onAppear {
            orderedItems = tabItems
        }
    }
}

// タブバー（長押しメニュー＋右端に＋ボタン）
// 画面内のタブをタップしてもスクロール位置は変わらない
// 画面外（一部だけ見えている）タブをタップした場合のみ、タブ全体が見える位置まで最小限スクロール
struct TabBarView: View {
    let tabItems: [(label: String, tag: Tag?, colorIndex: Int)]
    @Binding var selectedTabIndex: Int
    var flashTabIndex: Int?
    var onSelectModeReset: () -> Void
    var onShowReorderSheet: () -> Void
    var onAddTag: () -> Void

    // 各タブのスクロール内での位置を記録
    @State private var tabFrames: [Int: CGRect] = [:]
    // スクロールビューの可視領域
    @State private var scrollViewFrame: CGRect = .zero
    // プログラム的なスクロールオフセット
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        let count = tabItems.count
        guard count > 0 else { return AnyView(EmptyView()) }

        return AnyView(
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: -1) {
                        ForEach(0..<count, id: \.self) { i in
                            tabButton(index: i)
                        }
                        // 右端の「＋」タブ
                        Button {
                            onAddTag()
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 40)
                                .padding(.vertical, 9)
                                .background(
                                    TrapezoidTabShape()
                                        .fill(Color(uiColor: .secondarySystemBackground))
                                )
                        }
                        .buttonStyle(.plain)
                        .id("addTab")
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                }
                .onChange(of: selectedTabIndex) { oldValue, newValue in
                    onSelectModeReset()
                    // 画面外のタブの場合のみ、端が見える位置までスクロール
                    // ScrollViewReaderでは細かい制御が難しいので、
                    // 左端寄せ/右端寄せ/スクロールなしを判定
                    if let frame = tabFrames[newValue] {
                        let visibleMin = scrollViewFrame.minX
                        let visibleMax = scrollViewFrame.maxX
                        let tabMin = frame.minX
                        let tabMax = frame.maxX

                        if tabMin >= visibleMin && tabMax <= visibleMax {
                            // タブ全体が画面内 → スクロールしない
                        } else if tabMin < visibleMin {
                            // 左にはみ出し → 左端寄せ
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo("tab_\(newValue)", anchor: .leading)
                            }
                        } else {
                            // 右にはみ出し → 右端寄せ
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo("tab_\(newValue)", anchor: .trailing)
                            }
                        }
                    }
                }
            }
            .frame(height: 36)
            .background(
                GeometryReader { geo in
                    Color.clear.onAppear {
                        scrollViewFrame = geo.frame(in: .global)
                    }
                    .onChange(of: geo.frame(in: .global)) { _, newFrame in
                        scrollViewFrame = newFrame
                    }
                }
            )
        )
    }

    private func tabButton(index: Int) -> some View {
        let isSelected = selectedTabIndex == index
        let color = tagColor(for: tabItems[index].colorIndex)

        return Button {
            selectedTabIndex = index
        } label: {
            Text(tabItems[index].label)
                .font(.system(size: 14, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .frame(minWidth: 52, maxWidth: 150)
                .background(
                    TrapezoidTabShape()
                        .fill(color)
                )
                .overlay(
                    TrapezoidTabShape()
                        .fill(Color.white.opacity(flashTabIndex == index ? 0.7 : 0))
                        .animation(.easeInOut(duration: 0.3).repeatCount(3, autoreverses: true), value: flashTabIndex)
                )
                .offset(y: isSelected ? 2 : 0)
        }
        .buttonStyle(.plain)
        .zIndex(isSelected ? 1 : 0)
        .id("tab_\(index)")
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { tabFrames[index] = geo.frame(in: .global) }
                    .onChange(of: geo.frame(in: .global)) { _, newFrame in
                        tabFrames[index] = newFrame
                    }
            }
        )
        .contextMenu {
            Button {
                onShowReorderSheet()
            } label: {
                Label("フォルダの並び替え", systemImage: "arrow.up.arrow.down")
            }
        }
    }
}

// 「トップに移動」オリジナルアイコン（カード横並び＋上矢印）
struct MoveToTopIcon: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            // カード3枚横並び
            let c1 = Path(roundedRect: CGRect(x: w*0.02, y: h*0.5, width: w*0.28, height: h*0.4), cornerRadius: 2)
            let c2 = Path(roundedRect: CGRect(x: w*0.35, y: h*0.5, width: w*0.28, height: h*0.4), cornerRadius: 2)
            let c3 = Path(roundedRect: CGRect(x: w*0.68, y: h*0.5, width: w*0.28, height: h*0.4), cornerRadius: 2)
            context.fill(c1, with: .color(.primary.opacity(0.35)))
            context.fill(c2, with: .color(.primary.opacity(0.45)))
            context.fill(c3, with: .color(.primary.opacity(0.25)))
            // 上矢印
            var arrow = Path()
            let ax = w*0.5; let ay = h*0.02
            arrow.move(to: CGPoint(x: ax, y: ay))
            arrow.addLine(to: CGPoint(x: ax - w*0.2, y: ay + h*0.25))
            arrow.addLine(to: CGPoint(x: ax + w*0.2, y: ay + h*0.25))
            arrow.closeSubpath()
            context.fill(arrow, with: .color(.primary.opacity(0.45)))
            let shaft = Path(CGRect(x: ax - w*0.06, y: ay + h*0.22, width: w*0.12, height: h*0.2))
            context.fill(shaft, with: .color(.primary.opacity(0.45)))
        }
    }
}
