import SwiftUI
import SwiftData

// カジノルーレット風タグ選択（巨大な円の左端の弧だけ見える）
// Canvas1本で描画。rotation値から直接全て計算し、ワープを防ぐ。
struct TagDialView: View {
    @Query(sort: \Tag.name) private var tags: [Tag]
    @Binding var selectedTagID: UUID?

    private var options: [(id: String, name: String, color: Color)] {
        var list: [(String, String, Color)] = [("none", "なし", tagColor(for: 0))]
        for (i, tag) in tags.enumerated() {
            list.append((tag.id.uuidString, tag.name, tagColor(for: i + 1)))
        }
        return list
    }

    // 円の半径
    private let wheelRadius: CGFloat = 300
    // セクターの厚み（右方向に広め）
    private let sectorThickness: CGFloat = 82
    // 各タグ間の角度（度）
    private let itemAngle: CGFloat = 8
    // ダイヤルのサイズ
    private let dialHeight: CGFloat = 160
    private let dialWidth: CGFloat = 100

    // rotation: 上にスワイプ→正、下にスワイプ→負
    // rotation=0 → index 0 がセンター
    // rotation=itemAngle → index 1 がセンター
    @State private var rotation: CGFloat = 0
    @State private var dragStart: CGFloat = 0

    // スナップ後のセンターインデックス
    private var snappedIndex: Int {
        let count = options.count
        guard count > 0 else { return 0 }
        let raw = Int(round(rotation / itemAngle))
        return ((raw % count) + count) % count
    }

    var body: some View {
        let count = options.count
        let opts = options
        let rot = rotation

        Canvas { context, size in
            let cy = size.height / 2
            let cx = wheelRadius + 2
            let outerR = wheelRadius
            let innerR = wheelRadius - sectorThickness
            let textR = wheelRadius - sectorThickness / 2

            guard count > 0 else { return }

            // rotation から「センターからの端数角度」を求める
            // 例: rotation=5, itemAngle=8 → 基準index=0, 端数=5度
            // 例: rotation=12, itemAngle=8 → 基準index=2(≒round(12/8)), 端数=12-16=-4度
            // 各アイテムi の表示角度 = (i * itemAngle - rotation) 度
            // angle=0が中央、正が下、負が上

            for slotOffset in -8...8 {
                // このスロットに表示するアイテムのindex
                // rotation=0のとき: slotOffset=0 → index 0, slotOffset=1 → index 1
                // rotation=itemAngleのとき: 全体が1つ上にずれるので slotOffset=0 → index 1
                let baseIndex = Int(floor(rot / itemAngle + 0.5))
                let rawIndex = baseIndex + slotOffset
                let index = ((rawIndex % count) + count) % count
                guard index < opts.count else { continue }

                // このアイテムの表示角度（度）
                // rawIndex * itemAngle が「このアイテムのホーム角度」
                // rotation がスクロール量
                // 画面上の角度 = rawIndex * itemAngle - rotation
                let displayAngle = CGFloat(rawIndex) * itemAngle - rot

                let dist = abs(displayAngle)
                let maxDist = itemAngle * 6
                let fade = max(0.0, 1.0 - dist / maxDist)
                guard fade > 0 else { continue }

                let halfAngle = itemAngle / 2
                // CG座標: 180°=左。displayAngle正=下だがCGは反時計回りなので符号反転
                let cgStart = 180.0 - Double(displayAngle + halfAngle)
                let cgEnd = 180.0 - Double(displayAngle - halfAngle)

                // 扇形パス
                var sector = Path()
                sector.addArc(
                    center: CGPoint(x: cx, y: cy),
                    radius: innerR,
                    startAngle: .degrees(cgStart),
                    endAngle: .degrees(cgEnd),
                    clockwise: false
                )
                sector.addArc(
                    center: CGPoint(x: cx, y: cy),
                    radius: outerR,
                    startAngle: .degrees(cgEnd),
                    endAngle: .degrees(cgStart),
                    clockwise: true
                )
                sector.closeSubpath()

                let option = opts[index]
                let isSelected = dist < itemAngle / 2

                // セクター塗り
                context.opacity = fade
                context.fill(
                    sector,
                    with: .color(option.color.opacity(isSelected ? 0.9 : 0.6))
                )

                // 選択ハイライト
                if isSelected {
                    context.fill(
                        sector,
                        with: .linearGradient(
                            Gradient(colors: [
                                .white.opacity(0.3),
                                .white.opacity(0.05),
                                .white.opacity(0.15)
                            ]),
                            startPoint: CGPoint(x: 0, y: cy - 20),
                            endPoint: CGPoint(x: 0, y: cy + 20)
                        )
                    )
                }

                // 仕切り線（セクターの上辺 = cgEnd側）
                let divCG = cgEnd * .pi / 180
                var divLine = Path()
                divLine.move(to: CGPoint(
                    x: cx + innerR * cos(divCG),
                    y: cy + innerR * sin(divCG)
                ))
                divLine.addLine(to: CGPoint(
                    x: cx + outerR * cos(divCG),
                    y: cy + outerR * sin(divCG)
                ))
                context.stroke(
                    divLine,
                    with: .color(.white.opacity(0.5 * fade)),
                    lineWidth: 0.8
                )

                // テキスト（セクターの中央に配置）
                let rad = displayAngle * .pi / 180
                // セクター中央の半径位置
                let midR = (innerR + outerR) / 2
                // CG座標でのセクター中央点
                let cgMid = (180.0 - Double(displayAngle)) * .pi / 180
                let textX = cx + midR * cos(cgMid)
                let textY = cy + midR * sin(cgMid)

                // 5文字を超えたら省略
                let displayName: String = {
                    if option.name.count > 5 {
                        return String(option.name.prefix(5)) + "…"
                    }
                    return option.name
                }()

                // センター: 黒太字で拡大、それ以外: 小さく控えめ
                let fontSize: CGFloat = isSelected ? 13 : 9
                let resolved = context.resolve(
                    Text(displayName)
                        .font(.system(
                            size: fontSize,
                            weight: isSelected ? .bold : .medium,
                            design: .rounded
                        ))
                        .foregroundColor(Color(white: isSelected ? 0.1 : 0.3))
                )
                context.draw(
                    resolved,
                    at: CGPoint(x: textX, y: textY),
                    anchor: .center
                )

                context.opacity = 1.0
            }

            // 外周の縁取り（金属風）
            var outerEdge = Path()
            outerEdge.addArc(
                center: CGPoint(x: cx, y: cy),
                radius: outerR,
                startAngle: .degrees(150),
                endAngle: .degrees(210),
                clockwise: false
            )
            context.stroke(
                outerEdge,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(white: 0.55),
                        Color(white: 0.9),
                        Color(white: 0.55)
                    ]),
                    startPoint: CGPoint(x: 0, y: cy - 80),
                    endPoint: CGPoint(x: 0, y: cy + 80)
                ),
                lineWidth: 2.5
            )

            // 内周の縁取り
            var innerEdge = Path()
            innerEdge.addArc(
                center: CGPoint(x: cx, y: cy),
                radius: innerR,
                startAngle: .degrees(150),
                endAngle: .degrees(210),
                clockwise: false
            )
            context.stroke(
                innerEdge,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(white: 0.4),
                        Color(white: 0.7),
                        Color(white: 0.4)
                    ]),
                    startPoint: CGPoint(x: 0, y: cy - 80),
                    endPoint: CGPoint(x: 0, y: cy + 80)
                ),
                lineWidth: 1.5
            )

            // 選択ポインター（赤い三角、左端に配置）
            let pw: CGFloat = 10
            let ph: CGFloat = 16
            let pLeft: CGFloat = -2  // 左端からの位置
            var shadow = Path()
            shadow.move(to: CGPoint(x: pLeft + 1, y: cy - ph / 2 + 1))
            shadow.addLine(to: CGPoint(x: pLeft + pw + 1, y: cy + 1))
            shadow.addLine(to: CGPoint(x: pLeft + 1, y: cy + ph / 2 + 1))
            shadow.closeSubpath()
            context.fill(shadow, with: .color(.black.opacity(0.3)))

            var pointer = Path()
            pointer.move(to: CGPoint(x: pLeft, y: cy - ph / 2))
            pointer.addLine(to: CGPoint(x: pLeft + pw, y: cy))
            pointer.addLine(to: CGPoint(x: pLeft, y: cy + ph / 2))
            pointer.closeSubpath()
            context.fill(
                pointer,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.9, green: 0.15, blue: 0.1),
                        Color(red: 0.7, green: 0.1, blue: 0.08)
                    ]),
                    startPoint: CGPoint(x: 0, y: cy - ph / 2),
                    endPoint: CGPoint(x: 0, y: cy + ph / 2)
                )
            )
            var hl = Path()
            hl.move(to: CGPoint(x: pLeft + 1, y: cy - ph / 2 + 2))
            hl.addLine(to: CGPoint(x: pLeft + pw - 3, y: cy))
            context.stroke(hl, with: .color(.white.opacity(0.5)), lineWidth: 1)
        }
        .frame(width: dialWidth, height: dialHeight)
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    // 上にスワイプ(translation.height < 0) → rotation増加 → 次のアイテムへ
                    rotation = dragStart + value.translation.height * -0.3
                }
                .onEnded { _ in
                    let snapped = round(rotation / itemAngle) * itemAngle
                    withAnimation(.easeOut(duration: 0.15)) {
                        rotation = snapped
                    }
                    dragStart = snapped
                    updateSelection()
                }
        )
        .onAppear {
            dragStart = rotation
        }
    }

    private func updateSelection() {
        let index = snappedIndex
        if index < options.count {
            let option = options[index]
            selectedTagID = option.id == "none" ? nil : UUID(uuidString: option.id)
        }
    }
}
