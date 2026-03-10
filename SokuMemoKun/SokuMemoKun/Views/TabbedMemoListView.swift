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
    case small = 0   // 2×4
    case medium = 1  // 3×6
    case large = 2   // 4×8

    var columns: Int {
        switch self {
        case .small: return 2
        case .medium: return 3
        case .large: return 4
        }
    }

    var label: String {
        switch self {
        case .small: return "2×4枚"
        case .medium: return "3×6枚"
        case .large: return "4×8枚"
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
    @State private var editingMemo: Memo?
    // タグなし用のグリッドサイズ（UserDefaultsで保存）
    @AppStorage("noTagGridSize") private var noTagGridSize: Int = 2

    private var tabItems: [(label: String, tag: Tag?, colorIndex: Int)] {
        var items: [(String, Tag?, Int)] = [("タグなし", nil, 0)]
        for tag in tags {
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
        Array(repeating: GridItem(.flexible(), spacing: 4), count: currentGridSize.columns)
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
                }
            }

            // メモ一覧（縁取り付き）
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
                        LazyVGrid(columns: currentColumns, spacing: 4) {
                            ForEach(filteredMemos) { memo in
                                MemoCardView(memo: memo, gridSize: currentGridSize)
                                    .onTapGesture {
                                        editingMemo = memo
                                    }
                                    .contextMenu {
                                        Button {
                                            UIPasteboard.general.string = memo.content
                                        } label: {
                                            Label("コピー", systemImage: "doc.on.doc")
                                        }
                                        Button(role: .destructive) {
                                            modelContext.delete(memo)
                                        } label: {
                                            Label("削除", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.top, 28)
                        .padding(.bottom, 20)
                    }
                }

                // グリッドサイズ切替ボタン（右上）
                gridSizeButton
                    .padding(.trailing, 10)
                    .padding(.top, 6)
            }
            .animation(.easeInOut(duration: 0.2), value: selectedTabIndex)
            .animation(.easeInOut(duration: 0.2), value: currentGridSize)
        }
        .sheet(item: $editingMemo) { memo in
            TagTitleSheetView(memo: memo)
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
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTabIndex = index
            }
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
        case .small: return 15
        case .medium: return 13
        case .large: return 12
        }
    }

    private var bodyFont: CGFloat {
        switch gridSize {
        case .small: return 13
        case .medium: return 11
        case .large: return 10
        }
    }

    private var bodyLines: Int {
        switch gridSize {
        case .small: return 5
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

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(memo.title.isEmpty ? "無題" : memo.title)
                .font(.system(size: titleFont, weight: .semibold, design: .rounded))
                .lineLimit(1)

            Text(memo.content)
                .font(.system(size: bodyFont))
                .foregroundStyle(.secondary)
                .lineLimit(bodyLines)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(cardPadding)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
