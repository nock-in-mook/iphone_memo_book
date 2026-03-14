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
    @State private var isSelectMode = false
    @State private var selectedMemoIDs: Set<UUID> = []
    // 選択削除確認ダイアログ
    @State private var showDeleteConfirm = false
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

    // 並び替えシート表示
    @State private var showReorderSheet = false
    // タグ追加シート
    @State private var showAddTagSheet = false

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
    private var filteredMemos: [Memo] {
        let item = tabItems[selectedTabIndex]
        // 「すべて」タブ
        if item.colorIndex == allTabColorIndex {
            return allMemos
        }
        if let tag = item.tag {
            return allMemos.filter { memo in
                memo.tags.contains { $0.id == tag.id }
            }
        } else {
            return allMemos.filter { $0.tags.isEmpty }
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
                    onSelectModeReset: {
                        isSelectMode = false
                        selectedMemoIDs.removeAll()
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
                        ScrollView {
                            LazyVGrid(columns: currentColumns, spacing: 8) {
                                ForEach(filteredMemos) { memo in
                                    HStack(spacing: 4) {
                                        if isSelectMode {
                                            Image(systemName: selectedMemoIDs.contains(memo.id) ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 20))
                                                .foregroundStyle(selectedMemoIDs.contains(memo.id) ? .red : .gray.opacity(0.6))
                                        }
                                        MemoCardView(memo: memo, gridSize: currentGridSize, availableHeight: geo.size.height)
                                    }
                                    .onTapGesture {
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
                                    .draggable(memo.id.uuidString) {
                                        MemoCardView(memo: memo, gridSize: currentGridSize, availableHeight: geo.size.height)
                                            .frame(width: 120, height: 60)
                                            .opacity(0.8)
                                    }
                                    .contextMenu {
                                        if !isSelectMode {
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
                            }
                            .padding(.horizontal, 10)
                            .padding(.top, 50)
                            .padding(.bottom, 40)
                        }
                    }
                }
                .id(selectedTabIndex)
                .transition(.asymmetric(
                    insertion: .move(edge: swipeDirection == .left ? .trailing : .leading),
                    removal: .move(edge: swipeDirection == .left ? .leading : .trailing)
                ))

                // 上部ツールバー（メモ枚数・メモ追加・グリッドサイズ）
                VStack {
                    HStack(spacing: 8) {
                        Text("\(filteredMemos.count)枚のメモ")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(darkenedColor)

                        Spacer()

                        // メモ追加ボタン
                        Button {
                            if isSelectMode { isSelectMode = false; selectedMemoIDs.removeAll() }
                            let currentTag = tabItems[selectedTabIndex].tag
                            onAddMemo?(currentTag?.id)
                        } label: {
                            Label("フォルダにメモ追加", systemImage: "plus")
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

                        gridSizeButton
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [currentColor, currentColor, currentColor.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .padding(.bottom, -8)
                    )

                    Spacer()

                    // 右下: 選択削除ボタン
                    HStack {
                        Spacer()
                        if isSelectMode {
                            Button {
                                isSelectMode = false
                                selectedMemoIDs.removeAll()
                            } label: {
                                Text("取消")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(Color(uiColor: .systemBackground).opacity(0.9))
                                            .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        Button {
                            if isSelectMode {
                                showDeleteConfirm = true
                            } else {
                                isSelectMode = true
                                selectedMemoIDs.removeAll()
                            }
                        } label: {
                            Label(isSelectMode ? "削除" : "選択削除", systemImage: "trash")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(isSelectMode && !selectedMemoIDs.isEmpty ? .red : .secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color(uiColor: .systemBackground).opacity(0.9))
                                        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(isSelectMode && selectedMemoIDs.isEmpty)
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: currentGridSize)
            .simultaneousGesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        let horizontal = abs(value.translation.width)
                        let vertical = abs(value.translation.height)
                        guard horizontal > vertical * 1.5 else { return }

                        let count = tabItems.count
                        if value.translation.width < -50 {
                            // 左スワイプ → 次のタブ（末尾→先頭にループ）
                            swipeDirection = .left
                            withAnimation(.easeOut(duration: 0.25)) {
                                selectedTabIndex = (selectedTabIndex + 1) % count
                            }
                        } else if value.translation.width > 50 {
                            // 右スワイプ → 前のタブ（先頭→末尾にループ）
                            swipeDirection = .right
                            withAnimation(.easeOut(duration: 0.25)) {
                                selectedTabIndex = (selectedTabIndex - 1 + count) % count
                            }
                        }
                    }
            )
        }
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
            HStack(spacing: 4) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 12))
                Text(currentGridSize.label)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color(uiColor: .systemBackground).opacity(0.85))
            )
        }
    }

    private func deleteSelectedMemos() {
        for memo in allMemos where selectedMemoIDs.contains(memo.id) {
            onDeleteMemo?(memo)
            modelContext.delete(memo)
        }
        selectedMemoIDs.removeAll()
        isSelectMode = false
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

            // マークダウンマーク（右上）
            if memo.isMarkdown {
                Text("M↓")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.gray.opacity(0.5))
                    .padding(3)
            }
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

    // グリッドサイズに応じたスタイル
    private var titleFont: CGFloat {
        switch gridSize {
        case .grid3x8: return 14
        case .grid2x6: return 15
        case .grid2x3: return 16
        case .grid1x2: return 17
        case .full: return 18
        }
    }

    private var bodyFont: CGFloat {
        switch gridSize {
        case .grid3x8: return 12
        case .grid2x6: return 13
        case .grid2x3: return 14
        case .grid1x2: return 15
        case .full: return 16
        }
    }

    private var bodyLines: Int {
        switch gridSize {
        case .grid3x8: return 2
        case .grid2x6: return 3
        case .grid2x3: return 5
        case .grid1x2: return 4
        case .full: return 0  // 0 = 無制限
        }
    }

    private var cardPadding: CGFloat {
        switch gridSize {
        case .grid3x8: return 6
        case .grid2x6: return 8
        case .grid2x3: return 10
        case .grid1x2: return 12
        case .full: return 12
        }
    }

    // GeometryReaderから渡される利用可能な高さで計算
    var availableHeight: CGFloat = 0

    // 全文モードでは高さ固定しない
    private var isFullMode: Bool { gridSize == .full }

    private var cardHeight: CGFloat? {
        if isFullMode { return nil }  // 全文モードは高さ自動
        guard availableHeight > 0 else {
            switch gridSize {
            case .grid3x8: return 56
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
        let topPadding: CGFloat = 34
        let bottomPadding: CGFloat = 20
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
            .frame(maxWidth: .infinity, maxHeight: isFullMode ? nil : .infinity, alignment: .topLeading)
            .padding(cardPadding)

            // マークダウンマーク（右上）
            if memo.isMarkdown {
                Text("M↓")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.gray.opacity(0.5))
                    .padding(3)
            }
        }
        .frame(height: cardHeight)
        .background(Color(uiColor: .systemBackground))
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
                Text("長押しで移動できます")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
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
                Label("並び替え", systemImage: "arrow.up.arrow.down")
            }
        }
    }
}
