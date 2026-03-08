import SwiftUI
import SwiftData

// タブの色パレット
private let tabColors: [Color] = [
    Color(red: 0.82, green: 0.80, blue: 0.76),  // タグ無し（ベージュグレー・画用紙風）
    Color(red: 0.55, green: 0.80, blue: 0.95),  // 水色
    Color(red: 0.95, green: 0.70, blue: 0.55),  // オレンジ
    Color(red: 0.70, green: 0.90, blue: 0.70),  // 緑
    Color(red: 0.90, green: 0.70, blue: 0.90),  // 紫
    Color(red: 0.95, green: 0.85, blue: 0.55),  // 黄色
    Color(red: 0.95, green: 0.60, blue: 0.60),  // 赤
    Color(red: 0.60, green: 0.75, blue: 0.95),  // 青
]

func tagColor(for index: Int) -> Color {
    tabColors[index % tabColors.count]
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

private let tabWidth: CGFloat = 76
private let borderColor = Color.primary.opacity(0.45)
private let borderWidth: CGFloat = 2.0

struct TabbedMemoListView: View {
    @Query(sort: \Tag.name) private var tags: [Tag]
    @Query(sort: \Memo.createdAt, order: .reverse) private var allMemos: [Memo]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTabIndex: Int = 0
    @State private var editingMemo: Memo?

    private var tabItems: [(label: String, tag: Tag?)] {
        var items: [(String, Tag?)] = [("タグ無し", nil)]
        for tag in tags {
            items.append((tag.name, tag))
        }
        return items
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
        tagColor(for: selectedTabIndex)
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 4)

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
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(filteredMemos) { memo in
                                MemoCardView(memo: memo)
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
                        .padding(.horizontal, 6)
                        .padding(.top, 6)
                        .padding(.bottom, 20)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedTabIndex)
        }
        .sheet(item: $editingMemo) { memo in
            TagTitleSheetView(memo: memo)
        }
    }

    private func tabButton(label: String, index: Int) -> some View {
        let isSelected = selectedTabIndex == index
        let color = tagColor(for: index)

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
        .zIndex(isSelected ? 1 : 0)
    }
}

// 超コンパクトなメモカード（4列グリッド用）
struct MemoCardView: View {
    let memo: Memo

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(memo.title.isEmpty ? "無題" : memo.title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .lineLimit(1)

            Text(memo.content)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(6)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
