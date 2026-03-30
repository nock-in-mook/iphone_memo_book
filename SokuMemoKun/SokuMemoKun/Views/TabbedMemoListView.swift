import SwiftUI
import SwiftData

// 条件付きクリップ（並び替え中のオーバーフロー許可用）
extension View {
    @ViewBuilder
    func conditionalClipped(_ shouldClip: Bool) -> some View {
        if shouldClip {
            self.clipped()
        } else {
            self
        }
    }
}

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
    Color(red: 0.85, green: 0.60, blue: 0.45),  // テラコッタ
    Color(red: 0.40, green: 0.70, blue: 0.50),  // フォレスト
    Color(red: 0.75, green: 0.58, blue: 0.78),  // プラム
    Color(red: 0.80, green: 0.70, blue: 0.40),  // マスタード
    Color(red: 0.82, green: 0.52, blue: 0.52),  // ワインレッド
    Color(red: 0.52, green: 0.62, blue: 0.85),  // インディゴ
    // 22〜28: アクセント
    Color(red: 0.50, green: 0.85, blue: 0.80),  // ターコイズ
    Color(red: 0.95, green: 0.55, blue: 0.40),  // コーラル
    Color(red: 0.60, green: 0.82, blue: 0.55),  // ライム
    Color(red: 0.75, green: 0.55, blue: 0.85),  // アメジスト
    Color(red: 0.90, green: 0.80, blue: 0.50),  // ゴールド
    Color(red: 0.88, green: 0.55, blue: 0.62),  // ローズ
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
    Color(red: 0.68, green: 0.52, blue: 0.92),  // バイオレット
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
    // 50〜56: レトロ・クラシック系
    Color(red: 0.88, green: 0.62, blue: 0.48),  // テラコッタライト
    Color(red: 0.58, green: 0.72, blue: 0.68),  // ヴィンテージグリーン
    Color(red: 0.72, green: 0.58, blue: 0.52),  // ココア
    Color(red: 0.62, green: 0.68, blue: 0.82),  // ウェッジウッド
    Color(red: 0.85, green: 0.72, blue: 0.52),  // ハニー
    Color(red: 0.78, green: 0.60, blue: 0.65),  // ボルドー
    Color(red: 0.52, green: 0.72, blue: 0.78),  // ナイルブルー
    // 57〜63: ポップ系
    Color(red: 0.98, green: 0.60, blue: 0.75),  // フラミンゴ
    Color(red: 0.45, green: 0.82, blue: 0.95),  // アクアマリン
    Color(red: 0.75, green: 0.92, blue: 0.45),  // キウイ
    Color(red: 0.95, green: 0.82, blue: 0.40),  // サンフラワー
    Color(red: 0.82, green: 0.55, blue: 0.92),  // オーキッド
    Color(red: 0.92, green: 0.52, blue: 0.45),  // パプリカ
    Color(red: 0.40, green: 0.88, blue: 0.82),  // ミントソーダ
    // 64〜70: スモーキー系
    Color(red: 0.62, green: 0.58, blue: 0.65),  // ラベンダーグレー
    Color(red: 0.65, green: 0.70, blue: 0.62),  // モスグレー
    Color(red: 0.72, green: 0.62, blue: 0.58),  // クレイ
    Color(red: 0.58, green: 0.65, blue: 0.72),  // フォグブルー
    Color(red: 0.75, green: 0.72, blue: 0.58),  // サンドストーン
    Color(red: 0.70, green: 0.58, blue: 0.62),  // プラムグレー
    Color(red: 0.58, green: 0.70, blue: 0.72),  // アイスブルー
    // 71〜72: 特別色
    Color(red: 0.92, green: 0.88, blue: 0.72),  // シャンパン
    Color(red: 0.55, green: 0.62, blue: 0.55),  // フォレストミスト
]

// 色の名前（インデックス対応）
let tabColorNames: [String] = [
    "ノーカラー",         // 0
    "アクア",             // 1
    "みかん",            // 2
    "ピスタチオ",         // 3
    "すみれ",            // 4
    "レモン",            // 5
    "ストロベリー",       // 6
    "コバルト",           // 7
    "シャボン",           // 8
    "ピーチ",            // 9
    "ミント",            // 10
    "ラベンダー",         // 11
    "バニラ",            // 12
    "サーモン",           // 13
    "あじさい",           // 14
    "ティール",           // 15
    "テラコッタ",         // 16
    "フォレスト",         // 17
    "プラム",            // 18
    "マスタード",         // 19
    "ガーネット",         // 20
    "インディゴ",         // 21
    "ターコイズ",         // 22
    "コーラル",           // 23
    "ライム",            // 24
    "アメジスト",         // 25
    "ゴールド",           // 26
    "ローズ",            // 27
    "ブルーベリー",       // 28
    "サンド",            // 29
    "セージ",            // 30
    "モカ",              // 31
    "アイボリー",         // 32
    "オリーブ",           // 33
    "キャメル",           // 34
    "シルバーレイク",      // 35
    "チェリー",           // 36
    "ソーダ",            // 37
    "メロン",            // 38
    "マンゴー",           // 39
    "グレープ",           // 40
    "トマト",            // 41
    "エメラルド",         // 42
    "モーヴ",            // 43
    "ユーカリ",           // 44
    "さくら",            // 45
    "フォグ",            // 46
    "カーキ",            // 47
    "カメオ",            // 48
    "しずく",            // 49
    "シナモン",           // 50
    "ヒスイ",            // 51
    "ココア",            // 52
    "ウェッジウッド",      // 53
    "ハニー",            // 54
    "ボルドー",           // 55
    "ナイル",            // 56
    "フラミンゴ",         // 57
    "アクアマリン",       // 58
    "キウイ",            // 59
    "サンフラワー",       // 60
    "オーキッド",         // 61
    "パプリカ",           // 62
    "ラムネ",            // 63
    "トワイライト",       // 64
    "モス",              // 65
    "クレイ",            // 66
    "ミスト",            // 67
    "サンドストーン",      // 68
    "カシス",            // 69
    "アイス",            // 70
    "シャンパン",         // 71
    "フォレストミスト",    // 72
]

// 色名取得関数
func tagColorName(for index: Int) -> String {
    guard index >= 0 && index < tabColorNames.count else { return "ノーカラー" }
    return tabColorNames[index]
}

// 「すべて」タブ用の色（薄い黄色）
private let allTabColor = Color(red: 0.98, green: 0.96, blue: 0.82)
// 「よく見る」タブ用の色（薄い水色）
private let frequentTabColor = Color(red: 0.85, green: 0.93, blue: 0.98)

func tagColor(for index: Int) -> Color {
    if index == -1 { return allTabColor }
    if index == -2 { return frequentTabColor }
    guard index >= 0 && index < tabColors.count else {
        return tabColors[0]
    }
    return tabColors[index]
}

// 紙の質感を表現するオーバーレイ
// グリッドサイズ定義（列数×行数）
enum GridSizeOption: Int, CaseIterable {
    case grid3x8 = 0   // 3×8
    case grid2x6 = 1   // 2×6
    case grid2x3 = 2   // 2×3
    case grid1x2 = 3   // 1×2
    case full = 4       // 1列・全文表示
    case titleOnly = 5  // タイトルのみ

    var columns: Int {
        switch self {
        case .grid3x8: return 3
        case .grid2x6: return 2
        case .grid2x3: return 2
        case .grid1x2: return 1
        case .full: return 1
        case .titleOnly: return 2
        }
    }

    var label: String {
        switch self {
        case .grid3x8: return "3×8"
        case .grid2x6: return "2×6"
        case .grid2x3: return "2×3"
        case .grid1x2: return "1×2"
        case .full: return "1(全文)"
        case .titleOnly: return "タイトルのみ"
        }
    }

    // 通常フォルダ用の選択肢
    static var normalOptions: [GridSizeOption] {
        [.grid3x8, .grid2x6, .grid2x3, .grid1x2, .full, .titleOnly]
    }

    // 「よく見る」フォルダ用の選択肢（2列固定ベース）
    static var frequentOptions: [GridSizeOption] {
        [.grid2x6, .grid2x3, .grid1x2, .full, .titleOnly]
    }
}

// 「よく見る」フォルダ専用グリッドオプション
enum FrequentGridOption: Int, CaseIterable {
    case grid2x8 = 0   // 2×8（各列8件）
    case grid2x6 = 1   // 2×6（各列6件）
    case grid2x3 = 2   // 2×3（各列3件）
    case full = 3       // 2×1（全文）
    case titleOnly = 4  // タイトルのみ（1列）

    var itemsPerColumn: Int {
        switch self {
        case .grid2x8: return 8
        case .grid2x6: return 6
        case .grid2x3: return 3
        case .full: return 6
        case .titleOnly: return 20
        }
    }

    var label: String {
        switch self {
        case .grid2x8: return "2×8"
        case .grid2x6: return "2×6"
        case .grid2x3: return "2×3"
        case .full: return "2×1(全文)"
        case .titleOnly: return "タイトルのみ"
        }
    }

    // 対応するGridSizeOption（カード描画用）
    var cardGridSize: GridSizeOption {
        switch self {
        case .grid2x8: return .grid3x8
        case .grid2x6: return .grid2x6
        case .grid2x3: return .grid2x3
        case .full: return .full
        case .titleOnly: return .titleOnly
        }
    }
}

private let borderColor = Color.primary.opacity(0.45)
private let borderWidth: CGFloat = 2.0

// 特殊タブ色変更シート用アイテム
struct SpecialColorSheetItem: Identifiable {
    let id = UUID()
    let tabColorIndex: Int  // -1=すべて, -2=よく見る
    let initialColor: Int   // 現在のcolorIndex
}

// 特殊タブの色変更シート（独立View）
struct SpecialColorEditSheet: View {
    let tabLabel: String
    let initialColor: Int
    let onSave: (Int) -> Void
    let onCancel: () -> Void
    @State private var selectedColor: Int

    init(tabLabel: String, initialColor: Int, onSave: @escaping (Int) -> Void, onCancel: @escaping () -> Void) {
        self.tabLabel = tabLabel
        self.initialColor = initialColor
        self.onSave = onSave
        self.onCancel = onCancel
        self._selectedColor = State(initialValue: initialColor)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // プレビュー（実際のタブと同じデザイン）
                Text(tabLabel)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .shadow(color: .black.opacity(0.2), radius: 0.5, x: -0.5, y: 0.5)
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .frame(minWidth: 52)
                    .background(
                        TrapezoidTabShape()
                            .fill(tagColor(for: selectedColor))
                            .shadow(color: .black.opacity(0.4), radius: 5, x: -3, y: 3)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text("カラー")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    ColorPaletteGrid(selectedIndex: $selectedColor)
                }
                Spacer()
            }
            .padding(20)
            .navigationTitle("色の変更")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { onSave(selectedColor) }
                        .bold()
                }
            }
        }
        .presentationDetents([.medium])
    }
}

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
    // ロック中メモ移動通知
    @State private var showLockedMemoMovedAlert = false
    @State private var lockedMemoMovedMessage = ""
    // 汎用トースト
    @State private var toastMessage = ""
    @State private var toastIcon = "lock.fill"
    @State private var showToast = false
    @State private var pendingDeleteCompleteToast = false
    // スワイプ方向追跡（トランジション用）
    @State private var swipeDirection: SwipeDirection = .none
    enum SwipeDirection { case none, left, right }
    // タグなし用のグリッドサイズ（UserDefaultsで保存）
    @AppStorage("noTagGridSize") private var noTagGridSize: Int = 2
    // すべて用のグリッドサイズ
    @AppStorage("allTagGridSize") private var allTagGridSize: Int = 2
    // よく見る用のグリッドサイズ
    @AppStorage("frequentTabGridSize") private var frequentTabGridSize: Int = 1
    // コールバック
    var onAddMemo: ((UUID?, UUID?) -> Void)?  // (親タグID, 子タグID)
    var onEditMemo: ((Memo) -> Void)?
    var onDeleteMemo: ((Memo) -> Void)?
    // 入力欄展開時はコンパクト表示（選択削除等を非表示）
    var isCompact = false
    // 「記入中のメモをここに保存」コールバック
    var onAddToCurrentTab: ((UUID?) -> Void)?
    // 並び替えモード状態を親（MainView）に伝える
    @Binding var isInReorderMode: Bool
    // ドラッグ中のタブの色（背景色変更用）
    @State private var draggingTabColor: Color? = nil
    // フラッシュ対象のメモID（保存直後にハイライト）
    @State private var flashMemoID: UUID?
    // タブフラッシュ
    @State private var flashTabIndex: Int?
    // 最後に開いたメモID（戻ってきた時のハイライト用）
    @State private var lastOpenedMemoID: UUID?

    // 並び替えシート表示
    @State private var showReorderSheet = false
    // タグ追加シート
    @State private var showAddTagSheet = false
    // 特殊タブの色変更シート
    @State private var specialColorSheetItem: SpecialColorSheetItem? = nil
    @State private var editingColorValue: Int = 1
    @State private var editingTagForDetail: Tag? = nil
    // 子タグ引き出しドロワー
    @State private var drawerReveal: CGFloat = 0       // 引き出し量（0=閉、maxで全開）
    @State private var drawerDragOffset: CGFloat = 0   // ドラッグ中の一時オフセット
    @State private var selectedChildFilterID: UUID? = nil
    @State private var showAddChildTagSheet = false
    private let drawerHandleWidth: CGFloat = 28         // 「子タグ」タブの幅

    // colorIndex == -1 は「すべて」タブを示す特別な値
    private let allTabColorIndex = -1
    // colorIndex == -2 は「よく見る」タブを示す特別な値
    private let frequentTabColorIndex = -2

    // タブの並び順（sortOrder順、すべて=-1、タグなし=sortOrder）
    @AppStorage("allTagSortOrder") private var allTagSortOrder: Int = -1
    @AppStorage("noTagSortOrder") private var noTagSortOrder: Int = 9999
    @AppStorage("frequentTagSortOrder") private var frequentTagSortOrder: Int = -2
    // 「すべて」「よく見る」のカスタムカラーインデックス（-1=デフォルト色）
    @AppStorage("allTabCustomColor") private var allTabCustomColor: Int = 5
    @AppStorage("frequentTabCustomColor") private var frequentTabCustomColor: Int = 8

    private var tabItems: [(label: String, tag: Tag?, colorIndex: Int)] {
        var items: [(label: String, tag: Tag?, colorIndex: Int, order: Int)] = []
        items.append(("すべて", nil, allTabColorIndex, allTagSortOrder))
        items.append(("よく見る", nil, frequentTabColorIndex, frequentTagSortOrder))
        items.append(("タグなし", nil, 0, noTagSortOrder))
        for tag in tags where tag.parentTagID == nil && !tag.isSystem {
            items.append((truncateTabName(tag.name), tag, tag.colorIndex, tag.sortOrder))
        }
        items.sort { $0.order < $1.order }
        return items.map { ($0.label, $0.tag, $0.colorIndex) }
    }

    // タブ名を半角幅換算で10文字（全角5文字）に切り詰める
    private func truncateTabName(_ text: String) -> String {
        var width: CGFloat = 0
        var result = ""
        let maxWidth: CGFloat = 10 // 全角5文字 = 半角10文字
        for ch in text {
            let w: CGFloat = ch.isASCII ? 1.0 : 2.0
            if width + w > maxWidth {
                return result + "…"
            }
            width += w
            result.append(ch)
        }
        return result
    }

    // 「すべて」タブかどうか
    private var isAllTab: Bool {
        tabItems[selectedTabIndex].colorIndex == allTabColorIndex
    }

    // 「タグなし」タブかどうか
    private var isNoTagTab: Bool {
        let item = tabItems[selectedTabIndex]
        return item.tag == nil && item.colorIndex != allTabColorIndex && item.colorIndex != frequentTabColorIndex
    }

    // 「よく見る」タブかどうか
    private var isFrequentTab: Bool {
        tabItems[selectedTabIndex].colorIndex == frequentTabColorIndex
    }

    // よく見るメモ（閲覧回数順、件数はグリッド設定に応じて可変）
    private var frequentMemos: [Memo] {
        let limit = currentFrequentGridOption.itemsPerColumn
        return Array(allMemos.filter { $0.viewCount > 0 }.sorted { $0.viewCount > $1.viewCount }.prefix(limit))
    }

    // 最近見たメモ（最終閲覧日時順、件数はグリッド設定に応じて可変）
    private var recentMemos: [Memo] {
        let limit = currentFrequentGridOption.itemsPerColumn
        return Array(allMemos.filter { $0.lastViewedAt != nil }.sorted { ($0.lastViewedAt ?? .distantPast) > ($1.lastViewedAt ?? .distantPast) }.prefix(limit))
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
        if item.colorIndex == frequentTabColorIndex {
            return currentFrequentGridOption.cardGridSize
        }
        if item.colorIndex == allTabColorIndex {
            return GridSizeOption(rawValue: allTagGridSize) ?? .grid3x8
        }
        if let tag = item.tag {
            return GridSizeOption(rawValue: tag.gridSize) ?? .grid3x8
        }
        return GridSizeOption(rawValue: noTagGridSize) ?? .grid3x8
    }

    // 「よく見る」フォルダ専用のグリッドオプション
    private var currentFrequentGridOption: FrequentGridOption {
        FrequentGridOption(rawValue: frequentTabGridSize) ?? .grid2x6
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
        // 「よく見る」タブ（左右分割表示なので空を返す）
        if item.colorIndex == frequentTabColorIndex {
            return []
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
        let ci = tabItems[selectedTabIndex].colorIndex
        if ci == allTabColorIndex && allTabCustomColor >= 0 {
            return tabColors[allTabCustomColor % tabColors.count]
        }
        if ci == frequentTabColorIndex && frequentTabCustomColor >= 0 {
            return tabColors[frequentTabCustomColor % tabColors.count]
        }
        return tagColor(for: ci)
    }

    // 「よく見る」タブの左右列の配色（同色グラデ）
    private var frequentColumnColors: (left: Color, right: Color) {
        let base = currentColor
        let uiColor = UIColor(base)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let color = Color(red: r * 0.92, green: g * 0.92, blue: b * 0.92)
        let left = color
        let right = color
        return (left, right)
    }

    // 選択中の子タグ名（フィルター中のみ）
    private var selectedChildTagName: String? {
        guard let childID = selectedChildFilterID else { return nil }
        return tags.first { $0.id == childID }?.name
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
                        // タブ切替時に子タグフィルターリセット（ドロワーは開いたまま）
                        selectedChildFilterID = nil
                    },
                    onShowReorderSheet: { },
                    onAddTag: {
                        showAddTagSheet = true
                    },
                    onEditTag: { tag in
                        editingTagForDetail = tag
                    },
                    onDeleteTag: { tag, withMemos in
                        deleteTag(tag, withMemos: withMemos)
                    },
                    onChangeSpecialTabColor: { tabColorIndex, newColor in
                        if tabColorIndex == -1 {
                            allTabCustomColor = newColor
                        } else if tabColorIndex == -2 {
                            frequentTabCustomColor = newColor
                        }
                    },
                    getSpecialTabColor: { tabColorIndex in
                        if tabColorIndex == -1 { return allTabCustomColor }
                        if tabColorIndex == -2 { return frequentTabCustomColor }
                        return 1
                    },
                    onOpenColorSheet: { tabColorIndex in
                        let color = tabColorIndex == -1 ? allTabCustomColor : frequentTabCustomColor
                        specialColorSheetItem = SpecialColorSheetItem(tabColorIndex: tabColorIndex, initialColor: color)
                    },
                    onReorder: { newOrder in
                        applyTabOrder(newOrder)
                    },
                    isInReorderMode: $isInReorderMode,
                    draggingTabColor: $draggingTabColor
                )

                // ── メモ一覧（並び替え中は非表示） ──
                if !isInReorderMode {
                    normalMemoContent
                }
            }
        }
        // ★ 全体背景（タブ行〜メモ一覧まで一体で管理）
        .background(
            ZStack {
                // タグ色はnormalMemoContent領域だけ（タブ行は透明）
                VStack(spacing: 0) {
                    Color.clear.frame(height: 44)
                    // 並び替え中はドラッグ中タブの色、通常時はフォルダ色
                    if isInReorderMode, let dragColor = draggingTabColor {
                        dragColor
                            .animation(.easeInOut(duration: 0.3), value: draggingTabColor)
                    } else {
                        currentColor
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)
        )
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
        .alert(lockedMemoMovedMessage, isPresented: $showLockedMemoMovedAlert) {
            Button("OK") {
                if pendingDeleteCompleteToast {
                    pendingDeleteCompleteToast = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showToastMessage("削除が完了しました", icon: "checkmark.circle")
                    }
                }
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
        .sheet(item: $editingTagForDetail) { tag in
            TagDetailEditView(tag: tag)
        }
        .sheet(item: $specialColorSheetItem) { item in
            SpecialColorEditSheet(
                tabLabel: item.tabColorIndex == -1 ? "すべて" : "よく見る",
                initialColor: item.initialColor,
                onSave: { newColor in
                    if item.tabColorIndex == -1 {
                        allTabCustomColor = newColor
                    } else {
                        frequentTabCustomColor = newColor
                    }
                    specialColorSheetItem = nil
                },
                onCancel: {
                    specialColorSheetItem = nil
                }
            )
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
        // 汎用トースト
        .overlay(alignment: .center) {
            if showToast {
                HStack(spacing: 6) {
                    Image(systemName: toastIcon)
                        .font(.system(size: 14))
                    Text(toastMessage)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.75))
                )
                .transition(.opacity)
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
                                                    Button {
                                                        memo.isLocked.toggle()
                                                    } label: {
                                                        Label(memo.isLocked ? "ロックを解除" : "削除防止ロック", systemImage: memo.isLocked ? "lock.open" : "lock")
                                                    }
                                                    if memo.isLocked {
                                                        Button(role: .destructive) {} label: {
                                                            Label("削除ロック中", systemImage: "lock.fill")
                                                        }
                                                        .disabled(true)
                                                    } else {
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

                    if isCompact {
                        // 最大化時: メモ一覧を非表示
                        Color.clear
                    } else if isFrequentTab {
                        // 「よく見る」特殊レイアウト: 左右分割
                        frequentTabContent(geo: geo)
                    } else if filteredMemos.isEmpty {
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
                                // 上部スペーサー（メモ枚数行＋子タグドロワー分、タップ不可）
                                Color.clear
                                    .frame(height: (drawerReveal > 0 && canShowChildTagPanel) ? drawerBandHeight + 6 + drawerBandHeight : drawerBandHeight)
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
                    let canSaveHere = !isAllTab && !isFrequentTab && !isNoTagTab
                    HStack {
                        Spacer()
                        Button {
                            let currentTag = tabItems[selectedTabIndex].tag
                            onAddToCurrentTab?(currentTag?.id)
                        } label: {
                            Label("記入中のメモをここに保存", systemImage: "arrow.down.doc")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(canSaveHere ? .blue : .secondary.opacity(0.3))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color(uiColor: .systemGray6))
                                        .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color.gray.opacity(canSaveHere ? 0.4 : 0.15), lineWidth: 1.0)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSaveHere)
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
                            } else if isFrequentTab {
                                Text("よく見るメモと最近見たメモ")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(darkenedColor)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            } else {
                                HStack(spacing: 6) {
                                    Text("\(filteredMemos.count)枚のメモ")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundStyle(darkenedColor)
                                    // 親タグ-子タグバッジ（子タグフィルター中のみ）
                                    if let childName = selectedChildTagName,
                                       let parentName = tabItems[selectedTabIndex].tag?.name {
                                        Text("\(parentName)-\(childName)")
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(
                                                Capsule().fill(darkenedColor.opacity(0.7))
                                            )
                                    }
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .frame(height: drawerBandHeight)
                    }
                    // スクロールしたメモが後ろに隠れるよう不透明背景（ドロワースペース含む）
                    .background(currentColor)
                    .zIndex(1)

                    // 子タグ引き出しドロワー
                    if !isCompact && canShowChildTagPanel {
                        childTagDrawer
                            .animation(.spring(response: 0.3), value: drawerReveal)
                            .animation(.spring(response: 0.3), value: drawerContentWidth)
                            .zIndex(2)
                    }

                    // 下部ボタンバー（1つのHStackで均等配置）
                    if !isCompact {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                        if isSelectMode {
                            // 選択モード: 取消 + 実行ボタン
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
                            Spacer()
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
                            // 通常時: ゴミ箱 | トップ移動 | (メモ作成) | グリッド
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

                            if !isFrequentTab {
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

                            // メモ作成ボタン（「すべて」「よく見る」タブでは非表示）
                            if !isAllTab && !isFrequentTab {
                                Button {
                                    let currentTag = tabItems[selectedTabIndex].tag
                                    onAddMemo?(currentTag?.id, selectedChildFilterID)
                                } label: {
                                    VStack(spacing: 2) {
                                        HStack(spacing: 5) {
                                            Image(systemName: "plus.circle")
                                                .font(.system(size: 15))
                                            Text("このフォルダに")
                                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        }
                                        Text("メモ作成")
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    }
                                    .foregroundStyle(.blue)
                                    .multilineTextAlignment(.center)
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
                            }

                            Spacer()

                            gridSizeButton
                        }
                        }
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

    // MARK: - 「よく見る」タブ特殊レイアウト

    private func frequentTabContent(geo: GeometryProxy) -> some View {
        let hasFrequent = !frequentMemos.isEmpty
        let hasRecent = !recentMemos.isEmpty
        let isTitleMode = currentFrequentGridOption == .titleOnly

        return ScrollView {
            VStack(spacing: 0) {
                // 上部スペーサー（枚数行分）
                Color.clear
                    .frame(height: drawerBandHeight)
                    .allowsHitTesting(false)

                if !hasFrequent && !hasRecent {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("使い始めると\n表示されるようになります")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else if isTitleMode {
                    // タイトルのみモード（左右2列維持）
                    HStack(alignment: .top, spacing: 8) {
                        frequentTitleSection(title: "よく見る", memos: frequentMemos, color: frequentColumnColors.left)
                            .frame(maxWidth: .infinity)
                        frequentTitleSection(title: "最近見た", memos: recentMemos, color: frequentColumnColors.right)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 6)
                } else {
                    // 左右分割: よく見る | 最近
                    HStack(alignment: .top, spacing: 8) {
                        // 左列: よく見る
                        VStack(spacing: 8) {
                            Text("よく見る")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            LazyVGrid(columns: [GridItem(.flexible())], spacing: 8) {
                                ForEach(frequentMemos) { memo in
                                    memoGridItem(memo: memo, availableHeight: geo.size.height)
                                }
                            }
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(frequentColumnColors.left)
                                .shadow(color: .black.opacity(0.3), radius: 0.5, x: -0.5, y: 0.5)
                        )
                        .frame(maxWidth: .infinity)

                        // 右列: 最近
                        VStack(spacing: 8) {
                            Text("最近見た")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            LazyVGrid(columns: [GridItem(.flexible())], spacing: 8) {
                                ForEach(recentMemos) { memo in
                                    memoGridItem(memo: memo, availableHeight: geo.size.height)
                                }
                            }
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(frequentColumnColors.right)
                                .shadow(color: .black.opacity(0.3), radius: 0.5, x: -0.5, y: 0.5)
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 6)
                }
            }
            .padding(.bottom, 40)
        }
        .animation(.easeInOut(duration: 0.2), value: frequentTabGridSize)
    }

    // 「よく見る」タイトルのみモード用セクション
    private func frequentTitleSection(title: String, memos: [Memo], color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
            VStack(spacing: 2) {
                ForEach(memos) { memo in
                    memoGridItem(memo: memo, availableHeight: 0)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color)
                .shadow(color: .black.opacity(0.3), radius: 0.5, x: -0.5, y: 0.5)
        )
    }

    // MARK: - 子タグ引き出しドロワー

    /// ドロワー全体の現在の引き出し幅（確定値 + ドラッグ中オフセット）
    private var effectiveDrawerReveal: CGFloat {
        max(0, drawerReveal + drawerDragOffset)
    }

    private let drawerBandHeight: CGFloat = 37  // トレーの高さ
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
                            Text("\"\(parentName)\"の子タグなし")
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
                                            print("🟡 子タグタップ: \(child.name) id=\(child.id), 旧selectedChildFilterID=\(String(describing: selectedChildFilterID))")
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
            )
            .contentShape(Rectangle())  // タップ・ドラッグ領域を帯だけに限定
            .clipped()
            // 右端に配置
            .position(x: geo.size.width - totalWidth / 2, y: (reveal > 0 ? drawerBandHeight : drawerHandleHeight) / 2 + 7)
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
            .foregroundStyle(.primary)
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
        let isFrequent = tabItems[selectedTabIndex].colorIndex == frequentTabColorIndex
        let displayLabel = isFrequent ? currentFrequentGridOption.label : currentGridSize.label

        return Menu {
            if isFrequent {
                // 「よく見る」フォルダ専用メニュー
                Section("表示形式") {
                    ForEach(FrequentGridOption.allCases.reversed(), id: \.rawValue) { option in
                        Button {
                            frequentTabGridSize = option.rawValue
                        } label: {
                            HStack {
                                Text(option.label)
                                if currentFrequentGridOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            } else {
                // 通常フォルダ用メニュー
                Section("メモの表示数") {
                    ForEach(GridSizeOption.normalOptions.reversed(), id: \.rawValue) { option in
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
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 15))
                Text(displayLabel)
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
        .tint(.secondary)
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

    // タグ削除（メモも削除 or タグなしに移動）
    private func deleteTag(_ tag: Tag, withMemos: Bool) {
        // このタグに属するメモを取得
        let taggedMemos = allMemos.filter { $0.tags.contains(where: { $0.id == tag.id }) }
        // 子タグも取得
        let childTags = tags.filter { $0.parentTagID == tag.id }

        if withMemos {
            // ロック中メモはタグなしに移動、それ以外は削除
            let lockedMemos = taggedMemos.filter { $0.isLocked }
            let unlocked = taggedMemos.filter { !$0.isLocked }
            for memo in unlocked {
                modelContext.delete(memo)
            }
            // ロック中メモはタグを外す（タグなしに移動）
            for memo in lockedMemos {
                memo.tags.removeAll { $0.id == tag.id || $0.parentTagID == tag.id }
            }
            if !lockedMemos.isEmpty {
                lockedMemoMovedMessage = "削除ロック中のメモ\(lockedMemos.count)件は「タグなし」に移動しました"
                showLockedMemoMovedAlert = true
            }
        } else {
            // メモからこのタグと子タグを全て外す（タグなしに移動）
            for memo in taggedMemos {
                memo.tags.removeAll { $0.id == tag.id || $0.parentTagID == tag.id }
            }
        }

        // 子タグを先に削除
        for child in childTags {
            modelContext.delete(child)
        }
        // 親タグを削除
        modelContext.delete(tag)

        // 選択タブを「すべて」に戻す
        selectedTabIndex = 0

        // 削除完了トースト（ロック中アラートがある場合は遅延表示）
        if showLockedMemoMovedAlert {
            pendingDeleteCompleteToast = true
        } else {
            showToastMessage("削除が完了しました", icon: "checkmark.circle")
        }
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
                if memo.isLocked {
                    // ロック中: 鍵マーク（選択不可）
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.gray.opacity(0.4))
                } else {
                    Image(systemName: selectedMemoIDs.contains(memo.id) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(selectedMemoIDs.contains(memo.id) ? .blue : .gray.opacity(0.6))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            handleMemoTap(memo)
                        }
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
                // 最後に開いたメモのハイライト
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.cyan.opacity(lastOpenedMemoID == memo.id ? 0.08 : 0))
                        .allowsHitTesting(false)
                )
                // 選択モード中のロック中カードはグレーアウト
                .opacity(isSelectMode && memo.isLocked ? 0.4 : 1.0)
        }
        .draggable(memo.id.uuidString) {
            MemoCardView(memo: memo, gridSize: currentGridSize, availableHeight: availableHeight)
                .frame(width: 120, height: 60)
                .opacity(0.8)
        }
        .contextMenu {
            if !isSelectMode {
                if !isFrequentTab {
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
                }
                Button {
                    UIPasteboard.general.string = memo.content
                } label: {
                    Label("コピー", systemImage: "doc.on.doc")
                }
                Button {
                    let wasLocked = memo.isLocked
                    memo.isLocked.toggle()
                    if !wasLocked {
                        showToastMessage("メモをロックしました", icon: "lock.fill")
                    } else {
                        showToastMessage("ロックを解除しました", icon: "lock.open")
                    }
                } label: {
                    Label(memo.isLocked ? "ロックを解除" : "削除防止ロック", systemImage: memo.isLocked ? "lock.open" : "lock")
                }
                if memo.isLocked {
                    Button(role: .destructive) {} label: {
                        Label("削除ロック中", systemImage: "lock.fill")
                    }
                    .disabled(true)
                } else {
                    Button(role: .destructive) {
                        pendingDeleteMemo = memo
                        showSingleDeleteConfirm = true
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
            }
        }
    }

    // メモカードタップ処理
    // 汎用トースト表示
    private func showToastMessage(_ message: String, icon: String = "lock.fill", duration: TimeInterval = 1.5) {
        toastMessage = message
        toastIcon = icon
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            withAnimation { showToast = false }
        }
    }

    private func handleMemoTap(_ memo: Memo) {
        if isSelectMode {
            // ロック中メモは選択不可、トースト表示
            guard !memo.isLocked else {
                showToastMessage("このメモはロック中です")
                return
            }
            if selectedMemoIDs.contains(memo.id) {
                selectedMemoIDs.remove(memo.id)
            } else {
                selectedMemoIDs.insert(memo.id)
            }
        } else {
            lastOpenedMemoID = memo.id
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

            // 右上マーク（ロック・ピン・マークダウン）
            VStack(spacing: 2) {
                if memo.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.blue.opacity(0.6))
                }
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
        case .titleOnly: return 14
        }
    }

    private var bodyFont: CGFloat {
        switch gridSize {
        case .grid3x8: return 11
        case .grid2x6: return 13
        case .grid2x3: return 14
        case .grid1x2: return 15
        case .full: return 16
        case .titleOnly: return 12
        }
    }

    private var bodyLines: Int {
        switch gridSize {
        case .grid3x8: return 1
        case .grid2x6: return 3
        case .grid2x3: return 5
        case .grid1x2: return 4
        case .full: return 0  // 0 = 無制限
        case .titleOnly: return 0
        }
    }

    private var cardPadding: CGFloat {
        switch gridSize {
        case .grid3x8: return 4
        case .grid2x6: return 8
        case .grid2x3: return 10
        case .grid1x2: return 12
        case .full: return 12
        case .titleOnly: return 6
        }
    }

    // availableHeightはプロパティ宣言で定義済み

    // 全文モードでは高さ固定しない
    private var isFullMode: Bool { gridSize == .full }
    private var isTitleOnly: Bool { gridSize == .titleOnly }

    private var cardHeight: CGFloat? {
        if isFullMode || isTitleOnly { return nil }
        guard availableHeight > 0 else {
            switch gridSize {
            case .grid3x8: return 40
            case .grid2x6: return 72
            case .grid2x3: return 120
            case .grid1x2: return 180
            case .full: return nil
            case .titleOnly: return nil
            }
        }
        let rows: CGFloat
        switch gridSize {
        case .grid3x8: rows = 8
        case .grid2x6: rows = 6
        case .grid2x3: rows = 3
        case .grid1x2: rows = 2
        case .full: return nil
        case .titleOnly: return nil
        }
        let spacing: CGFloat = 8
        let topPadding: CGFloat = 58
        let bottomPadding: CGFloat = 70
        let usable = availableHeight - topPadding - bottomPadding - (spacing * (rows - 1))
        return max(40, usable / rows)
    }

    var body: some View {
        if isTitleOnly {
            // タイトルのみモード
            HStack(spacing: 2) {
                Text(memo.title.isEmpty ? "無題" : memo.title)
                    .font(.system(size: titleFont, weight: memo.title.isEmpty ? .regular : .semibold, design: .rounded))
                    .foregroundStyle(memo.title.isEmpty ? .gray.opacity(0.5) : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                // 右端マーク（アイコンがある時だけスペースを使う）
                if memo.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.blue.opacity(0.6))
                }
                if memo.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.orange.opacity(0.6))
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(Color(uiColor: .systemBackground))
            .contentShape(RoundedRectangle(cornerRadius: 4))
            .onTapGesture { onTap?() }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .shadow(color: .black.opacity(0.06), radius: 1, x: 0, y: 1)
        } else {
            // 通常カードモード
            VStack(alignment: .leading, spacing: 2) {
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
            .overlay(alignment: .topTrailing) {
                // 右上マーク（overlayでテキスト幅に影響させない）
                VStack(spacing: 2) {
                    if memo.isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.blue.opacity(0.6))
                    }
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
            .frame(height: gridSize == .grid3x8 ? 36 : gridSize == .grid2x6 ? 48 : gridSize == .grid2x3 ? 104 : gridSize == .grid1x2 ? 160 : cardHeight, alignment: .topLeading)
            .background(Color(uiColor: .systemBackground))
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .onTapGesture { onTap?() }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.1), radius: 2, x: -1, y: 1)
            .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
        }
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

// タブバー（長押しメニュー＋右端に＋ボタン＋ドラッグ並び替え）
struct TabBarView: View {
    let tabItems: [(label: String, tag: Tag?, colorIndex: Int)]
    @Binding var selectedTabIndex: Int
    var flashTabIndex: Int?
    var onSelectModeReset: () -> Void
    var onShowReorderSheet: () -> Void
    var onAddTag: () -> Void
    var onEditTag: ((Tag) -> Void)? = nil
    var onDeleteTag: ((Tag, Bool) -> Void)? = nil
    var onChangeSpecialTabColor: ((Int, Int) -> Void)? = nil
    var getSpecialTabColor: ((Int) -> Int)? = nil
    var onOpenColorSheet: ((Int) -> Void)? = nil
    var onReorder: ([(label: String, tag: Tag?, colorIndex: Int)]) -> Void = { _ in }
    // 並び替えモード状態を親に伝える
    @Binding var isInReorderMode: Bool
    // ドラッグ中のタブの色を親に伝える
    @Binding var draggingTabColor: Color?
    private let allTabColorIndex = -1
    private let frequentTabColorIndex = -2

    // 削除ダイアログ管理
    @State private var pendingDeleteTag: Tag? = nil
    @State private var showDeleteChoiceAlert = false
    @State private var showDeleteConfirmAlert = false
    @State private var deleteWithMemos = false

    // 各タブのスクロール内での位置を記録
    @State private var tabFrames: [Int: CGRect] = [:]
    @State private var scrollViewFrame: CGRect = .zero
    @State private var scrollOffset: CGFloat = 0

    // 並び替えモード
    @State private var isReorderMode = false
    @State private var reorderItems: [(label: String, tag: Tag?, colorIndex: Int)] = []
    // ドラッグ中のタブのID（安定したID）
    @State private var draggingID: String? = nil
    @State private var dragTranslation: CGFloat = 0
    // 浮遊タブの画面上X座標
    @State private var dragFloatingX: CGFloat = 0
    // ぷるぷるアニメーション用タイマー
    @State private var wiggleTimer: Timer? = nil
    @State private var wiggleTick: Int = 0
    // ドラッグ開始判定用
    @State private var dragStarted = false
    // 最後にドラッグしたタブID（完了時のフォーカス用）
    @State private var lastDraggedID: String? = nil
    // 各タブの中心X（並び替え用）
    @State private var reorderCenters: [String: CGFloat] = [:]
    // 自動スクロール用
    @State private var autoScrollTimer: Timer? = nil
    @State private var reorderScrollOffset: CGFloat = 0
    @State private var reorderContentWidth: CGFloat = 0
    @State private var reorderViewWidth: CGFloat = 0

    // タブの安定ID生成
    private func stableID(for item: (label: String, tag: Tag?, colorIndex: Int)) -> String {
        if let tag = item.tag { return tag.id.uuidString }
        return "special_\(item.colorIndex)"
    }

    var body: some View {
        let items = isReorderMode ? reorderItems : tabItems
        let count = items.count
        guard count > 0 else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(spacing: 0) {
                // タブバー本体
                ZStack(alignment: .topLeading) {
                    if isReorderMode {
                        // 並び替えモード: 自前スクロール（offset方式）
                        HStack(spacing: -1) {
                            let indexed = reorderItems.enumerated().map { (i, item) in
                                (index: i, item: item, sid: stableID(for: item))
                            }
                            ForEach(indexed, id: \.sid) { entry in
                                reorderSlot(index: entry.index, item: entry.item)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 10)
                        .fixedSize(horizontal: true, vertical: false)
                        .background(
                            GeometryReader { contentGeo in
                                Color.clear
                                    .onAppear {
                                        reorderContentWidth = contentGeo.size.width
                                        reorderViewWidth = UIScreen.main.bounds.width
                                    }
                                    .onChange(of: contentGeo.size.width) { _, w in
                                        reorderContentWidth = w
                                    }
                            }
                        )
                        .offset(x: reorderScrollOffset)
                        .frame(width: UIScreen.main.bounds.width, alignment: .leading)
                        .clipped()
                    } else {
                        // 通常モード: ScrollView
                        ScrollViewReader { proxy in
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: -1) {
                                    ForEach(0..<count, id: \.self) { i in
                                        tabButton(index: i)
                                    }
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
                                .padding(.top, 10)
                            }
                            .onChange(of: selectedTabIndex) { oldValue, newValue in
                                onSelectModeReset()
                                if let frame = tabFrames[newValue] {
                                    let visibleMin = scrollViewFrame.minX
                                    let visibleMax = scrollViewFrame.maxX
                                    let tabMin = frame.minX
                                    let tabMax = frame.maxX
                                    if tabMin >= visibleMin && tabMax <= visibleMax {
                                    } else if tabMin < visibleMin {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            proxy.scrollTo("tab_\(newValue)", anchor: .leading)
                                        }
                                    } else {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            proxy.scrollTo("tab_\(newValue)", anchor: .trailing)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ドラッグ中のタブ（HStackの外に浮かせる）
                    if let did = draggingID,
                       let item = reorderItems.first(where: { stableID(for: $0) == did }) {
                        let color = reorderResolvedColor(item: item)
                        let wiggle = (wiggleTick % 2 == 0 ? 1.0 : -1.0)
                        Text(item.label)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .frame(minWidth: 52, maxWidth: 150)
                            .fixedSize()
                            .background(
                                TrapezoidTabShape()
                                    .fill(color)
                                    .shadow(color: .black.opacity(0.5), radius: 4, x: -3, y: 4)
                            )
                            .overlay(
                                TrapezoidTabShape()
                                    .stroke(Color.white.opacity(0.9), lineWidth: 2.5)
                            )
                            .scaleEffect(1.3)
                            .rotationEffect(.degrees(wiggle))
                            .opacity(0.95)
                            .fixedSize()
                            .position(x: dragFloatingX, y: 15)
                            .allowsHitTesting(false)
                    }
                }
                .frame(height: 44)
                // 通常時はクリップ、並び替え中は上にはみ出せるようクリップ解除
                .conditionalClipped(!isReorderMode)
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

                // 並び替えモード: 説明＋ボタン
                if isReorderMode {
                    Spacer()

                    // 中央の説明
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(.secondary.opacity(0.6))
                        Text("ドラッグで並び替え")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary.opacity(0.7))
                    }

                    Spacer()

                    // ボタン行
                    HStack(spacing: 16) {
                        Button {
                            cancelReorder()
                        } label: {
                            Text("キャンセル")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.7))
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(Color(uiColor: .systemGray5))
                                )
                        }

                        Button {
                            finishReorder()
                        } label: {
                            Text("完了")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(Color.blue)
                                )
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        )
    }

    // MARK: - 並び替えモード開始/終了

    private func cancelReorder() {
        wiggleTimer?.invalidate()
        wiggleTimer = nil
        stopAutoScroll()
        isReorderMode = false
        isInReorderMode = false
        draggingID = nil
        dragTranslation = 0
        dragFloatingX = 0
        reorderScrollOffset = 0
    }

    private func startReorder() {
        reorderItems = tabItems
        isReorderMode = true
        isInReorderMode = true
        wiggleTick = 0
        wiggleTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                wiggleTick += 1
            }
        }
    }

    private func finishReorder() {
        wiggleTimer?.invalidate()
        wiggleTimer = nil
        stopAutoScroll()

        // 最後にドラッグしたタブのインデックスを記録
        let lastDraggedIndex: Int? = {
            guard let did = draggingID ?? lastDraggedID else { return nil }
            return reorderItems.firstIndex(where: { stableID(for: $0) == did })
        }()

        // 並び替え結果を適用
        onReorder(reorderItems)

        // 最後にドラッグしたタブを選択状態にする
        if let idx = lastDraggedIndex {
            selectedTabIndex = idx
        }

        // アニメーション付きでモード解除
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isReorderMode = false
            isInReorderMode = false
        }

        draggingID = nil
        lastDraggedID = nil
        dragTranslation = 0
        dragFloatingX = 0
        reorderScrollOffset = 0
    }

    // MARK: - 自動スクロール（端にドラッグすると自動でスクロール）

    private func startAutoScroll() {
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            guard draggingID != nil else { return }
            let edgeZone: CGFloat = 50  // 画面端から50pt以内で自動スクロール
            let scrollSpeed: CGFloat = 3  // 1フレームあたりのスクロール量
            let maxScroll = max(0, reorderContentWidth - reorderViewWidth + 16)

            if dragFloatingX < edgeZone {
                // 左端 → 右にスクロール（offsetを正に）
                reorderScrollOffset = min(0, reorderScrollOffset + scrollSpeed)
            } else if dragFloatingX > reorderViewWidth - edgeZone {
                // 右端 → 左にスクロール（offsetを負に）
                reorderScrollOffset = max(-maxScroll, reorderScrollOffset - scrollSpeed)
            }
        }
    }

    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }

    // MARK: - 並び替えモードのタブ表示

    // HStack内のスロット（ドラッグ中は透明、それ以外はタブ表示）
    private func reorderSlot(index: Int, item: (label: String, tag: Tag?, colorIndex: Int)) -> some View {
        let myID = stableID(for: item)
        let isDragging = draggingID == myID
        let color = reorderResolvedColor(item: item)
        let wiggleAngle: Double = (wiggleTick % 2 == 0 ? 2.0 : -2.0) * (index % 2 == 0 ? 1.0 : -1.0)

        return Text(item.label)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(minWidth: 52, maxWidth: 150)
            .background(
                GeometryReader { geo in
                    TrapezoidTabShape()
                        .fill(color)
                        .shadow(color: .black.opacity(0.2), radius: 3, x: -2, y: 3)
                        .onAppear {
                            reorderCenters[myID] = geo.frame(in: .global).midX
                        }
                        .onChange(of: geo.frame(in: .global).midX) { _, newX in
                            if !isDragging {
                                reorderCenters[myID] = newX
                            }
                        }
                }
            )
            .rotationEffect(.degrees(isDragging ? 0 : wiggleAngle))
            .opacity(isDragging ? 0 : 1.0) // ドラッグ中は非表示（浮遊タブが代わりに表示）
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: reorderItems.map { stableID(for: $0) })
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        if draggingID == nil {
                            // タッチした瞬間にホールド＋フィードバック
                            draggingID = myID
                            dragStarted = false
                            dragFloatingX = value.startLocation.x
                            // ドラッグ中のタブ色を親に伝える
                            draggingTabColor = reorderResolvedColor(item: item)
                            let generator = UIImpactFeedbackGenerator(style: .heavy)
                            generator.impactOccurred()
                            startAutoScroll()
                        }
                        guard draggingID == myID else { return }

                        // 5pt以上動いたらドラッグ開始
                        let dist = abs(value.translation.width)
                        if !dragStarted && dist > 5 {
                            dragStarted = true
                        }

                        // ドラッグ開始前でも浮遊タブは指に追従
                        dragFloatingX = value.location.x

                        guard dragStarted else { return }

                        let fingerX = value.location.x
                        guard let ci = reorderItems.firstIndex(where: { stableID(for: $0) == myID }) else { return }

                        // 右隣チェック
                        if ci < reorderItems.count - 1 {
                            let rightID = stableID(for: reorderItems[ci + 1])
                            if let rightCenter = reorderCenters[rightID], fingerX > rightCenter {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    reorderItems.swapAt(ci, ci + 1)
                                }
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                            }
                        }
                        // 左隣チェック（swapAt後のインデックスを再取得）
                        if let ci2 = reorderItems.firstIndex(where: { stableID(for: $0) == myID }), ci2 > 0 {
                            let leftID = stableID(for: reorderItems[ci2 - 1])
                            if let leftCenter = reorderCenters[leftID], fingerX < leftCenter {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    reorderItems.swapAt(ci2, ci2 - 1)
                                }
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                            }
                        }
                    }
                    .onEnded { _ in
                        stopAutoScroll()
                        lastDraggedID = draggingID
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            draggingID = nil
                            dragStarted = false
                        }
                    }
            )
    }

    private func reorderResolvedColor(item: (label: String, tag: Tag?, colorIndex: Int)) -> Color {
        let ci = item.colorIndex
        if ci == allTabColorIndex || ci == frequentTabColorIndex,
           let colorIdx = getSpecialTabColor?(ci), colorIdx >= 0 {
            return tabColors[colorIdx % tabColors.count]
        }
        return tagColor(for: ci)
    }

    // MARK: - 通常モードのタブ

    private func resolvedTabColor(index: Int) -> Color {
        let ci = tabItems[index].colorIndex
        if ci == allTabColorIndex || ci == frequentTabColorIndex,
           let colorIdx = getSpecialTabColor?(ci), colorIdx >= 0 {
            return tabColors[colorIdx % tabColors.count]
        }
        return tagColor(for: ci)
    }

    private func tabButton(index: Int) -> some View {
        let isSelected = selectedTabIndex == index
        let color = resolvedTabColor(index: index)

        return Button {
            selectedTabIndex = index
        } label: {
            Text(tabItems[index].label)
                .font(.system(size: 14, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .shadow(color: isSelected ? .black.opacity(0.2) : .clear, radius: 0.5, x: -0.5, y: 0.5)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .frame(minWidth: 52, maxWidth: 150)
                .background(
                    TrapezoidTabShape()
                        .fill(color)
                        .shadow(color: isSelected ? .black.opacity(0.3) : .clear, radius: 4, x: -3, y: 3)
                )
                .overlay(
                    TrapezoidTabShape()
                        .fill(Color.white.opacity(flashTabIndex == index ? 0.7 : 0))
                        .animation(.easeInOut(duration: 0.3).repeatCount(3, autoreverses: true), value: flashTabIndex)
                )
                .scaleEffect(isSelected ? 1.08 : 1.0, anchor: .bottom)
                .animation(nil, value: selectedTabIndex)
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
            let ci = tabItems[index].colorIndex
            Button {
                // contextMenu閉じた後に並び替えモード開始
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    startReorder()
                }
            } label: {
                Label("フォルダの並び替え", systemImage: "arrow.left.arrow.right")
            }
            if ci == allTabColorIndex || ci == frequentTabColorIndex {
                Button {
                    onOpenColorSheet?(ci)
                } label: {
                    Label("色の変更", systemImage: "paintpalette")
                }
            }
            if let tag = tabItems[index].tag {
                Button {
                    onEditTag?(tag)
                } label: {
                    Label("このタグを編集", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    pendingDeleteTag = tag
                    showDeleteChoiceAlert = true
                } label: {
                    Label("このタグを削除", systemImage: "trash")
                }
            }
        }
        .alert("「\(pendingDeleteTag?.name ?? "")」を削除します", isPresented: $showDeleteChoiceAlert) {
            Button("メモも一緒に削除", role: .destructive) {
                deleteWithMemos = true
                showDeleteConfirmAlert = true
            }
            Button("メモは残す（タグなしに移動）") {
                deleteWithMemos = false
                showDeleteConfirmAlert = true
            }
            Button("キャンセル", role: .cancel) {
                pendingDeleteTag = nil
            }
        } message: {
            Text("このタグに含まれるメモの扱いを選んでください")
        }
        .alert("本当に削除しますか？", isPresented: $showDeleteConfirmAlert) {
            Button("削除する", role: .destructive) {
                if let tag = pendingDeleteTag {
                    onDeleteTag?(tag, deleteWithMemos)
                }
                pendingDeleteTag = nil
            }
            Button("キャンセル", role: .cancel) {
                pendingDeleteTag = nil
            }
        } message: {
            if deleteWithMemos {
                Text("「\(pendingDeleteTag?.name ?? "")」とそのメモが全て削除されます。この操作は取り消せません。")
            } else {
                Text("タグ「\(pendingDeleteTag?.name ?? "")」が削除されます。メモは全て「タグなし」に移動されます。")
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
