import SwiftUI
import SwiftData

// タグの色パレット（0=タグなし、1〜28=選択可能カラー）
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
]

func tagColor(for index: Int) -> Color {
    guard index >= 0 && index < tabColors.count else {
        return tabColors[0]
    }
    return tabColors[index]
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
    case small = 0   // 1×6
    case medium = 1  // 2×6
    case large = 2   // 3×8

    var columns: Int {
        switch self {
        case .small: return 1
        case .medium: return 2
        case .large: return 3
        }
    }

    var label: String {
        switch self {
        case .small: return "1×6枚"
        case .medium: return "2×6枚"
        case .large: return "3×8枚"
        }
    }
}

private let tabWidth: CGFloat = 76
private let borderColor = Color.primary.opacity(0.45)
private let borderWidth: CGFloat = 2.0

struct TabbedMemoListView: View {
    @Query(sort: \Tag.name) private var tags: [Tag]
    @Query(sort: \Memo.createdAt, order: .reverse) private var allMemos: [Memo]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTabIndex: Int = 0
    @State private var isSelectMode = false
    @State private var selectedMemoIDs: Set<UUID> = []
    // タグなし用のグリッドサイズ（UserDefaultsで保存）
    @AppStorage("noTagGridSize") private var noTagGridSize: Int = 2
    // 外部からタブ切替を指示するためのトリガー（UUID? + カウンター）
    @Binding var switchToTagID: UUID?
    @Binding var switchTrigger: Int
    // コールバック
    var onAddMemo: (() -> Void)?
    var onEditMemo: ((Memo) -> Void)?
    var onDeleteMemo: ((Memo) -> Void)?

    private var tabItems: [(label: String, tag: Tag?, colorIndex: Int)] {
        var items: [(String, Tag?, Int)] = [("タグなし", nil, 0)]
        // 親タグのみ表示（子タグはタブに出さない）
        for tag in tags where tag.parentTagID == nil {
            items.append((tag.name, tag, tag.colorIndex))
        }
        return items
    }

    // 現在のタブのグリッドサイズ
    private var currentGridSize: GridSizeOption {
        let item = tabItems[selectedTabIndex]
        if let tag = item.tag {
            return GridSizeOption(rawValue: tag.gridSize) ?? .large
        }
        return GridSizeOption(rawValue: noTagGridSize) ?? .large
    }

    private var currentColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: currentGridSize.columns)
    }

    private var filteredMemos: [Memo] {
        let item = tabItems[selectedTabIndex]
        if let tag = item.tag {
            return allMemos.filter { memo in
                memo.tags.contains { $0.id == tag.id }
            }
        } else {
            return allMemos.filter { $0.tags.isEmpty }
        }
    }

    private var currentColor: Color {
        tagColor(for: tabItems[selectedTabIndex].colorIndex)
    }

    var body: some View {
        VStack(spacing: 0) {
            // タブ行
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: -1) {
                        ForEach(Array(tabItems.enumerated()), id: \.offset) { index, item in
                            tabButton(label: item.label, index: index)
                                .id(index)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                }
                .onChange(of: selectedTabIndex) { _, newValue in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                    // タブ切替で選択モード解除
                    isSelectMode = false
                    selectedMemoIDs.removeAll()
                }
            }

            // メモ一覧（縁取り付き）
            GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
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
                                MemoCardView(memo: memo, gridSize: currentGridSize, availableHeight: geo.size.height)
                                    .overlay(alignment: .topLeading) {
                                        if isSelectMode {
                                            Image(systemName: selectedMemoIDs.contains(memo.id) ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 18))
                                                .foregroundStyle(selectedMemoIDs.contains(memo.id) ? .red : .gray)
                                                .padding(4)
                                        }
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
                        .padding(.top, 34)
                        .padding(.bottom, 20)
                    }
                }

                // ツールバー（右上）
                HStack(spacing: 8) {
                    // メモ追加ボタン
                    Button {
                        if isSelectMode { isSelectMode = false; selectedMemoIDs.removeAll() }
                        onAddMemo?()
                    } label: {
                        Label("メモ追加", systemImage: "plus")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color(uiColor: .systemBackground).opacity(0.85))
                            )
                    }
                    .buttonStyle(.plain)

                    // 選択削除ボタン
                    Button {
                        if isSelectMode {
                            // 削除実行
                            deleteSelectedMemos()
                        } else {
                            isSelectMode = true
                            selectedMemoIDs.removeAll()
                        }
                    } label: {
                        Label(isSelectMode ? "削除" : "選択削除", systemImage: "trash")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(isSelectMode && !selectedMemoIDs.isEmpty ? .red : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color(uiColor: .systemBackground).opacity(0.85))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSelectMode && selectedMemoIDs.isEmpty)

                    // 選択モード中はキャンセルボタン
                    if isSelectMode {
                        Button {
                            isSelectMode = false
                            selectedMemoIDs.removeAll()
                        } label: {
                            Text("取消")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color(uiColor: .systemBackground).opacity(0.85))
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    gridSizeButton
                }
                .padding(.trailing, 10)
                .padding(.top, 6)
            }
            // タブ切替は瞬時（アニメーションなし）
            .animation(.easeInOut(duration: 0.2), value: currentGridSize)
            } // GeometryReader
        }
        // メモの編集はonEditMemoコールバックで入力欄に読み込む
        // 外部からのタブ切替指示に反応（トリガーが変わった時だけ実行）
        .onChange(of: switchTrigger) { _, _ in
            if let tagID = switchToTagID {
                if let idx = tabItems.firstIndex(where: { $0.tag?.id == tagID }) {
                    selectedTabIndex = idx
                }
            } else {
                selectedTabIndex = 0  // タグなしタブ
            }
        }
    }

    // グリッドサイズ切替ボタン
    private var gridSizeButton: some View {
        Menu {
            ForEach(GridSizeOption.allCases, id: \.rawValue) { option in
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
            Text(currentGridSize.label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
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
        if let tag = item.tag {
            tag.gridSize = option.rawValue
        } else {
            noTagGridSize = option.rawValue
        }
    }

    private func tabButton(label: String, index: Int) -> some View {
        let isSelected = selectedTabIndex == index
        let color = tagColor(for: tabItems[index].colorIndex)

        return Button {
            selectedTabIndex = index
        } label: {
            Text(label)
                .font(.system(size: 12, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .frame(width: tabWidth)
                .padding(.vertical, 9)
                .background(
                    TrapezoidTabShape()
                        .fill(color)
                )
                .offset(y: isSelected ? 2 : 0)
        }
        .buttonStyle(.plain)
        .zIndex(isSelected ? 1 : 0)
    }
}

// メモカード（グリッドサイズ対応）
struct MemoCardView: View {
    let memo: Memo
    var gridSize: GridSizeOption = .large

    // グリッドサイズに応じたスタイル
    private var titleFont: CGFloat {
        switch gridSize {
        case .small: return 14
        case .medium: return 13
        case .large: return 12
        }
    }

    private var bodyFont: CGFloat {
        switch gridSize {
        case .small: return 12
        case .medium: return 11
        case .large: return 10
        }
    }

    private var bodyLines: Int {
        switch gridSize {
        case .small: return 2
        case .medium: return 3
        case .large: return 2
        }
    }

    private var cardPadding: CGFloat {
        switch gridSize {
        case .small: return 10
        case .medium: return 8
        case .large: return 6
        }
    }

    // GeometryReaderから渡される利用可能な高さで計算
    var availableHeight: CGFloat = 0

    private var cardHeight: CGFloat {
        guard availableHeight > 0 else {
            // フォールバック
            switch gridSize {
            case .small: return 80
            case .medium: return 72
            case .large: return 56
            }
        }
        let rows: CGFloat
        switch gridSize {
        case .small: rows = 6
        case .medium: rows = 6
        case .large: rows = 8
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
                Text(memo.title.isEmpty ? "無題" : memo.title)
                    .font(.system(size: titleFont, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(memo.content)
                    .font(.system(size: bodyFont))
                    .foregroundStyle(.secondary)
                    .lineLimit(bodyLines)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(cardPadding)

            // マークダウンマーク（右上）
            if memo.isMarkdown {
                Text("M↓")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
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
