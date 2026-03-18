import SwiftUI

// 共通カード（影パラメータ付き）
private struct ShadowCard<Overlay: View>: View {
    let label: String
    var colorIndex: Int = 5
    // タブシェイプ影
    var tabShadowOpacity: Double = 0.4
    var tabShadowRadius: CGFloat = 5
    var tabShadowX: CGFloat = -3
    var tabShadowY: CGFloat = 3
    // テキスト影
    var textShadowOpacity: Double = 0.35
    var textShadowRadius: CGFloat = 1.5
    var textShadowX: CGFloat = -1
    var textShadowY: CGFloat = 1
    // メモカード インナーシャドウ
    var innerShadowOpacity: Double = 0
    var innerShadowRadius: CGFloat = 3
    var innerShadowX: CGFloat = -2
    var innerShadowY: CGFloat = 2
    // メモカード ドロップシャドウ
    var cardDropOpacity: Double = 0
    var cardDropRadius: CGFloat = 3
    var cardDropX: CGFloat = -2
    var cardDropY: CGFloat = 2
    @ViewBuilder var overlay: Overlay

    init(label: String, colorIndex: Int = 5,
         tabSO: Double = 0.4, tabSR: CGFloat = 5, tabSX: CGFloat = -3, tabSY: CGFloat = 3,
         textSO: Double = 0.35, textSR: CGFloat = 1.5, textSX: CGFloat = -1, textSY: CGFloat = 1,
         innerSO: Double = 0, innerSR: CGFloat = 3, innerSX: CGFloat = -2, innerSY: CGFloat = 2,
         cardDO: Double = 0, cardDR: CGFloat = 3, cardDX: CGFloat = -2, cardDY: CGFloat = 2,
         @ViewBuilder overlay: () -> Overlay = { Color.clear }) {
        self.label = label; self.colorIndex = colorIndex
        self.tabShadowOpacity = tabSO; self.tabShadowRadius = tabSR; self.tabShadowX = tabSX; self.tabShadowY = tabSY
        self.textShadowOpacity = textSO; self.textShadowRadius = textSR; self.textShadowX = textSX; self.textShadowY = textSY
        self.innerShadowOpacity = innerSO; self.innerShadowRadius = innerSR; self.innerShadowX = innerSX; self.innerShadowY = innerSY
        self.cardDropOpacity = cardDO; self.cardDropRadius = cardDR; self.cardDropX = cardDX; self.cardDropY = cardDY
        self.overlay = overlay()
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(label).font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 2)
            VStack(spacing: 0) {
                // タブ行
                HStack(spacing: -1) {
                    pill("すべて", .gray.opacity(0.3), false)
                    pill("仕事", tagColor(for: colorIndex), true)
                    pill("アイデア", tagColor(for: 12), false)
                    pill("買い物", tagColor(for: 8), false)
                    Spacer()
                }.padding(.horizontal, 6).padding(.top, 3)

                // メモカード
                HStack(spacing: 8) {
                    memoCard("キャンプ\n- [ ] やること")
                    memoCard("ランチ\n23時就寝→6時起床")
                }
                .padding(.horizontal, 8).padding(.vertical, 8)
            }
            .background(ZStack {
                VStack(spacing: 0) { Color.clear.frame(height: 28); tagColor(for: colorIndex) }
                overlay
            })
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    func memoCard(_ text: String) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                innerShadowOpacity > 0
                    ? AnyShapeStyle(Color.white
                        .shadow(.inner(color: .black.opacity(innerShadowOpacity), radius: innerShadowRadius, x: innerShadowX, y: innerShadowY)))
                    : AnyShapeStyle(Color.white)
            )
            .frame(height: 55)
            .overlay(
                Text(text).font(.system(size: 9)).foregroundStyle(.secondary).padding(6),
                alignment: .topLeading
            )
            .shadow(color: .black.opacity(cardDropOpacity), radius: cardDropRadius, x: cardDropX, y: cardDropY)
    }

    func pill(_ t: String, _ c: Color, _ s: Bool) -> some View {
        Text(t).font(.system(size: 10, weight: s ? .bold : .medium, design: .rounded))
            .foregroundStyle(s ? .primary : .secondary)
            .shadow(color: s ? .black.opacity(textShadowOpacity) : .clear, radius: textShadowRadius, x: textShadowX, y: textShadowY)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 5)
                    .fill(c)
                    .shadow(color: s ? .black.opacity(tabShadowOpacity) : .clear, radius: tabShadowRadius, x: tabShadowX, y: tabShadowY)
            )
            .offset(y: s ? 1 : 0)
    }
}

// ダミートップ
struct TextureLabView: View { var body: some View { Text("ラボ") } }

// ===== Stage1: タブシェイプ影 =====
struct TextureLab1: View {
    var body: some View {
        ScrollView { VStack(spacing: 16) {
            Text("タブシェイプ影").font(.headline)
            ShadowCard(label: "なし", tabSO: 0)
            ShadowCard(label: "弱 op=0.2 r=3 x=-2 y=2", tabSO: 0.2, tabSR: 3, tabSX: -2, tabSY: 2)
            ShadowCard(label: "中 op=0.4 r=5 x=-3 y=3（現在）", tabSO: 0.4, tabSR: 5, tabSX: -3, tabSY: 3)
            ShadowCard(label: "強 op=0.5 r=8 x=-4 y=4", tabSO: 0.5, tabSR: 8, tabSX: -4, tabSY: 4)
            ShadowCard(label: "極強 op=0.6 r=10 x=-5 y=5", tabSO: 0.6, tabSR: 10, tabSX: -5, tabSY: 5)
            ShadowCard(label: "タイト op=0.5 r=2 x=-2 y=2", tabSO: 0.5, tabSR: 2, tabSX: -2, tabSY: 2)
            ShadowCard(label: "ぼかし大 op=0.3 r=12 x=-3 y=5", tabSO: 0.3, tabSR: 12, tabSX: -3, tabSY: 5)
        }.padding(10) }
    }
}

// ===== Stage2: テキスト影 =====
struct TextureLab2: View {
    var body: some View {
        ScrollView { VStack(spacing: 16) {
            Text("テキスト影").font(.headline)
            ShadowCard(label: "なし", textSO: 0)
            ShadowCard(label: "弱 op=0.2 r=0.5 x=-0.5 y=0.5", textSO: 0.2, textSR: 0.5, textSX: -0.5, textSY: 0.5)
            ShadowCard(label: "中 op=0.35 r=1.5 x=-1 y=1（現在）", textSO: 0.35, textSR: 1.5, textSX: -1, textSY: 1)
            ShadowCard(label: "強 op=0.5 r=2 x=-1.5 y=1.5", textSO: 0.5, textSR: 2, textSX: -1.5, textSY: 1.5)
            ShadowCard(label: "極タイト op=0.6 r=0.5 x=-1 y=1", textSO: 0.6, textSR: 0.5, textSX: -1, textSY: 1)
            ShadowCard(label: "ぼかし大 op=0.3 r=4 x=-2 y=2", textSO: 0.3, textSR: 4, textSX: -2, textSY: 2)
            ShadowCard(label: "白影（彫刻風）op=0.5 r=1 x=1 y=1", textSO: 0, textSR: 0) // 別途実装必要
        }.padding(10) }
    }
}

// ===== Stage3: メモカード インナーシャドウ =====
struct TextureLab3: View {
    var body: some View {
        ScrollView { VStack(spacing: 16) {
            Text("カード インナーシャドウ").font(.headline)
            ShadowCard(label: "なし", innerSO: 0)
            ShadowCard(label: "極弱 op=0.08 r=2 x=-1 y=1", innerSO: 0.08, innerSR: 2, innerSX: -1, innerSY: 1)
            ShadowCard(label: "弱 op=0.12 r=3 x=-2 y=2", innerSO: 0.12, innerSR: 3, innerSX: -2, innerSY: 2)
            ShadowCard(label: "中 op=0.2 r=4 x=-2 y=2", innerSO: 0.2, innerSR: 4, innerSX: -2, innerSY: 2)
            ShadowCard(label: "強 op=0.3 r=5 x=-3 y=3", innerSO: 0.3, innerSR: 5, innerSX: -3, innerSY: 3)
            ShadowCard(label: "極強 op=0.4 r=8 x=-3 y=3", innerSO: 0.4, innerSR: 8, innerSX: -3, innerSY: 3)
            ShadowCard(label: "タイト op=0.25 r=2 x=-1 y=1", innerSO: 0.25, innerSR: 2, innerSX: -1, innerSY: 1)
            ShadowCard(label: "ぼかし大 op=0.15 r=10 x=-2 y=3", innerSO: 0.15, innerSR: 10, innerSX: -2, innerSY: 3)
            ShadowCard(label: "下だけ op=0.2 r=4 x=0 y=3", innerSO: 0.2, innerSR: 4, innerSX: 0, innerSY: 3)
            ShadowCard(label: "右下 op=0.2 r=4 x=2 y=2", innerSO: 0.2, innerSR: 4, innerSX: 2, innerSY: 2)
        }.padding(10) }
    }
}

// ===== Stage4: メモカード ドロップシャドウ =====
struct TextureLab4: View {
    var body: some View {
        ScrollView { VStack(spacing: 16) {
            Text("カード ドロップシャドウ").font(.headline)
            ShadowCard(label: "なし", cardDO: 0)
            ShadowCard(label: "弱 op=0.1 r=2 x=-1 y=1", cardDO: 0.1, cardDR: 2, cardDX: -1, cardDY: 1)
            ShadowCard(label: "中 op=0.15 r=4 x=-2 y=2", cardDO: 0.15, cardDR: 4, cardDX: -2, cardDY: 2)
            ShadowCard(label: "強 op=0.25 r=6 x=-3 y=3", cardDO: 0.25, cardDR: 6, cardDX: -3, cardDY: 3)
            ShadowCard(label: "極強 op=0.35 r=8 x=-4 y=4", cardDO: 0.35, cardDR: 8, cardDX: -4, cardDY: 4)
            ShadowCard(label: "タイト op=0.2 r=1.5 x=-1 y=1", cardDO: 0.2, cardDR: 1.5, cardDX: -1, cardDY: 1)
        }.padding(10) }
    }
}

// ===== Stage5: インナー + ドロップ併用 =====
struct TextureLab5: View {
    var body: some View {
        ScrollView { VStack(spacing: 16) {
            Text("インナー + ドロップ併用").font(.headline)
            ShadowCard(label: "インナー弱 + ドロップ弱", innerSO: 0.1, innerSR: 2, innerSX: -1, innerSY: 1, cardDO: 0.1, cardDR: 2, cardDX: -1, cardDY: 1)
            ShadowCard(label: "インナー中 + ドロップ弱", innerSO: 0.2, innerSR: 4, innerSX: -2, innerSY: 2, cardDO: 0.1, cardDR: 2, cardDX: -1, cardDY: 1)
            ShadowCard(label: "インナー弱 + ドロップ中", innerSO: 0.1, innerSR: 2, innerSX: -1, innerSY: 1, cardDO: 0.2, cardDR: 4, cardDX: -2, cardDY: 2)
            ShadowCard(label: "インナー中 + ドロップ中", innerSO: 0.2, innerSR: 3, innerSX: -2, innerSY: 2, cardDO: 0.15, cardDR: 4, cardDX: -2, cardDY: 2)
            ShadowCard(label: "インナー強 + ドロップ強", innerSO: 0.3, innerSR: 5, innerSX: -3, innerSY: 3, cardDO: 0.25, cardDR: 6, cardDX: -3, cardDY: 3)
        }.padding(10) }
    }
}

// ===== Stage6: 全部盛り組み合わせ =====
struct TextureLab6: View {
    var body: some View {
        ScrollView { VStack(spacing: 16) {
            Text("全部盛り 組み合わせ").font(.headline)
            ShadowCard(label: "A: 控えめ統一",
                       tabSO: 0.3, tabSR: 4, tabSX: -2, tabSY: 2,
                       textSO: 0.25, textSR: 1, textSX: -0.5, textSY: 0.5,
                       innerSO: 0.1, innerSR: 3, innerSX: -2, innerSY: 2,
                       cardDO: 0.08, cardDR: 2, cardDX: -1, cardDY: 1)
            ShadowCard(label: "B: バランス型",
                       tabSO: 0.4, tabSR: 5, tabSX: -3, tabSY: 3,
                       textSO: 0.35, textSR: 1.5, textSX: -1, textSY: 1,
                       innerSO: 0.15, innerSR: 3, innerSX: -2, innerSY: 2,
                       cardDO: 0.1, cardDR: 3, cardDX: -2, cardDY: 2)
            ShadowCard(label: "C: 存在感あり",
                       tabSO: 0.5, tabSR: 6, tabSX: -3, tabSY: 3,
                       textSO: 0.4, textSR: 1.5, textSX: -1, textSY: 1,
                       innerSO: 0.2, innerSR: 4, innerSX: -2, innerSY: 2,
                       cardDO: 0.15, cardDR: 4, cardDX: -2, cardDY: 2)
            ShadowCard(label: "D: がっつり立体",
                       tabSO: 0.5, tabSR: 8, tabSX: -4, tabSY: 4,
                       textSO: 0.5, textSR: 2, textSX: -1.5, textSY: 1.5,
                       innerSO: 0.3, innerSR: 5, innerSX: -3, innerSY: 3,
                       cardDO: 0.2, cardDR: 5, cardDX: -3, cardDY: 3)
            ShadowCard(label: "E: タイト＆シャープ",
                       tabSO: 0.5, tabSR: 2, tabSX: -2, tabSY: 2,
                       textSO: 0.5, textSR: 0.5, textSX: -0.5, textSY: 0.5,
                       innerSO: 0.25, innerSR: 2, innerSX: -1, innerSY: 1,
                       cardDO: 0.2, cardDR: 1.5, cardDX: -1, cardDY: 1)
            ShadowCard(label: "F: ソフト＆ふんわり",
                       tabSO: 0.25, tabSR: 10, tabSX: -3, tabSY: 5,
                       textSO: 0.2, textSR: 3, textSX: -1, textSY: 1,
                       innerSO: 0.1, innerSR: 8, innerSX: -2, innerSY: 3,
                       cardDO: 0.08, cardDR: 8, cardDX: -2, cardDY: 3)
            ShadowCard(label: "G: インナーのみ（ドロップなし）",
                       tabSO: 0.4, tabSR: 5, tabSX: -3, tabSY: 3,
                       textSO: 0.35, textSR: 1.5, textSX: -1, textSY: 1,
                       innerSO: 0.25, innerSR: 4, innerSX: -2, innerSY: 2,
                       cardDO: 0)
            ShadowCard(label: "H: ドロップのみ（インナーなし）",
                       tabSO: 0.4, tabSR: 5, tabSX: -3, tabSY: 3,
                       textSO: 0.35, textSR: 1.5, textSX: -1, textSY: 1,
                       innerSO: 0,
                       cardDO: 0.2, cardDR: 4, cardDX: -2, cardDY: 2)
        }.padding(10) }
    }
}

// ===== Stage7: 色違いで確認 =====
struct TextureLab7: View {
    var body: some View {
        ScrollView { VStack(spacing: 16) {
            Text("色違いで確認（バランス型）").font(.headline)
            ForEach([5, 12, 8, 18, 24, 30, 0], id: \.self) { ci in
                ShadowCard(label: "colorIndex=\(ci)", colorIndex: ci,
                           tabSO: 0.4, tabSR: 5, tabSX: -3, tabSY: 3,
                           textSO: 0.35, textSR: 1.5, textSX: -1, textSY: 1,
                           innerSO: 0.15, innerSR: 3, innerSX: -2, innerSY: 2,
                           cardDO: 0.1, cardDR: 3, cardDX: -2, cardDY: 2)
            }
        }.padding(10) }
    }
}
