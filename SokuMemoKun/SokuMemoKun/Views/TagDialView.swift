import SwiftUI
import SwiftData

// 親子統合ルーレット: 1つのCanvasで親の内周=子の外周がぴったり接する
struct TagDialView: View {
    // 親オプション
    var parentOptions: [(id: String, name: String, color: Color)]
    @Binding var parentSelectedID: UUID?

    // 子オプション
    var childOptions: [(id: String, name: String, color: Color)]
    @Binding var childSelectedID: UUID?

    // 子ダイアル表示
    @Binding var showChild: Bool

    // 円の設定
    private let wheelRadius: CGFloat = 270      // 親の外周半径
    private let parentThickness: CGFloat = 82   // 親セクターの厚み
    private let childThickness: CGFloat = 82    // 子セクターの厚み（親と同じ）
    private let itemAngle: CGFloat = 10         // 各タグ間の角度（度）
    private let dialHeight: CGFloat = 192

    // 親の回転
    @State private var parentRotation: CGFloat = 0
    @State private var parentDragStart: CGFloat = 0
    @State private var parentIsDragging = false
    @State private var parentIsInternalChange = false

    // 子の回転
    @State private var childRotation: CGFloat = 0
    @State private var childDragStart: CGFloat = 0
    @State private var childIsDragging = false
    @State private var childIsInternalChange = false

    // 外部ドラッグ入力（子タブからの引き出し用）
    @Binding var childExternalDragY: CGFloat?

    // 計算プロパティ
    private var parentOuterR: CGFloat { wheelRadius }
    private var parentInnerR: CGFloat { wheelRadius - parentThickness }
    private var childOuterR: CGFloat { parentInnerR }  // 親の内周=子の外周
    private var childInnerR: CGFloat { parentInnerR - childThickness }

    // Canvas幅（親のみ or 親子）
    private var canvasWidth: CGFloat {
        // cx - 内側の最小半径がCanvas左端に来るように
        let cx = wheelRadius + 2
        let innermost = showChild ? childInnerR : parentInnerR
        // 左端に必要な幅 = cx - innermost（180°方向の最左端）
        // ただし弧は150°〜210°の範囲なので少し余裕を持たせる
        let needed = cx - innermost * CGFloat(cos(Double.pi * 30.0 / 180.0)) + 10
        return max(needed, 100)
    }

    private func snappedIndex(rotation: CGFloat, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let raw = Int(round(rotation / itemAngle))
        return max(0, min(raw, count - 1))
    }

    // 端でクランプ（ゴムバンド付き）
    private func clampedRotation(_ rotation: CGFloat, count: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        let maxRot = CGFloat(max(count - 1, 0)) * itemAngle
        if rotation < 0 {
            return rotation * 0.2 // ゴムバンド: 20%だけ動く
        } else if rotation > maxRot {
            return maxRot + (rotation - maxRot) * 0.2
        }
        return rotation
    }

    // スナップ時に端を超えないようにクランプ
    private func clampedSnap(_ rotation: CGFloat, count: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        let snapped = round(rotation / itemAngle) * itemAngle
        let maxRot = CGFloat(count - 1) * itemAngle
        return max(0, min(snapped, maxRot))
    }

    var body: some View {
        let pOpts = parentOptions
        let cOpts = childOptions
        let pRot = parentRotation
        let cRot = childRotation
        let pCount = pOpts.count
        let cCount = cOpts.count
        let sc = showChild

        Canvas { context, size in
            let cy = size.height / 2
            let cx = wheelRadius + 2

            // --- 親セクター描画 ---
            if pCount > 0 {
                drawSectors(
                    context: &context, cx: cx, cy: cy,
                    outerR: parentOuterR, innerR: parentInnerR,
                    options: pOpts, rotation: pRot, count: pCount,
                    maxChars: 5
                )
            }

            // --- 子セクター描画（showChild時のみ） ---
            if sc && cCount > 0 {
                drawSectors(
                    context: &context, cx: cx, cy: cy,
                    outerR: childOuterR, innerR: childInnerR,
                    options: cOpts, rotation: cRot, count: cCount,
                    maxChars: 3
                )
            }

            // --- 縁取り描画 ---
            // 親の外周
            drawEdge(context: &context, cx: cx, cy: cy, radius: parentOuterR, lineWidth: 2.5, brightness: (0.35, 0.5, 0.35))

            // 親の内周 / 子の外周（共有境界）
            drawEdge(context: &context, cx: cx, cy: cy, radius: parentInnerR, lineWidth: 1.5, brightness: (0.3, 0.45, 0.3))

            // 子の内周（showChild時のみ）
            if sc {
                drawEdge(context: &context, cx: cx, cy: cy, radius: childInnerR, lineWidth: 1.5, brightness: (0.3, 0.45, 0.3))
            }

            // --- 選択ポインター（赤い三角） ---
            drawPointer(context: &context, cy: cy)
        }
        .frame(width: canvasWidth, height: dialHeight)
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    // x座標で親/子を判定
                    // Canvas上: 右寄り=外周(親)、左寄り=内周(子)
                    let cx = wheelRadius + 2
                    let touchX = value.startLocation.x
                    // 親内周のCanvas上のx座標（180°方向の最左端）
                    let borderX = cx - parentInnerR  // ≈84pt
                    if showChild && touchX > borderX {
                        // 子エリア（内周より右＝内側）
                        childIsDragging = true
                        let rawRot = childDragStart + value.translation.height * -0.3
                        childRotation = clampedRotation(rawRot, count: cOpts.count)
                    } else {
                        // 親エリア（内周より左＝外側）
                        parentIsDragging = true
                        let rawRot = parentDragStart + value.translation.height * -0.3
                        parentRotation = clampedRotation(rawRot, count: pOpts.count)
                    }
                }
                .onEnded { value in
                    if parentIsDragging {
                        let snapped = clampedSnap(parentRotation, count: pOpts.count)
                        withAnimation(.spring(response: 0.3)) { parentRotation = snapped }
                        parentDragStart = snapped
                        parentIsInternalChange = true
                        updateParentSelection()
                        parentIsDragging = false
                    }
                    if childIsDragging {
                        let snapped = clampedSnap(childRotation, count: cOpts.count)
                        withAnimation(.spring(response: 0.3)) { childRotation = snapped }
                        childDragStart = snapped
                        childIsInternalChange = true
                        updateChildSelection()
                        childIsDragging = false
                    }
                }
        )
        .onAppear {
            syncParentRotation()
            syncChildRotation()
        }
        // 外部ドラッグ入力（子タブからの引き出し）
        .onChange(of: childExternalDragY) { _, newValue in
            if let dragY = newValue {
                childIsDragging = true
                let rawRot = childDragStart + dragY * -0.3
                childRotation = clampedRotation(rawRot, count: childOptions.count)
            } else if childIsDragging {
                let snapped = clampedSnap(childRotation, count: childOptions.count)
                withAnimation(.spring(response: 0.3)) { childRotation = snapped }
                childDragStart = snapped
                childIsInternalChange = true
                updateChildSelection()
                childIsDragging = false
            }
        }
        .onChange(of: parentSelectedID) { _, _ in
            if parentIsInternalChange {
                parentIsInternalChange = false
            } else {
                syncParentRotation()
            }
        }
        .onChange(of: childSelectedID) { _, _ in
            if childIsInternalChange {
                childIsInternalChange = false
            } else {
                syncChildRotation()
            }
        }
    }

    // MARK: - Canvas描画ヘルパー

    private func drawSectors(
        context: inout GraphicsContext, cx: CGFloat, cy: CGFloat,
        outerR: CGFloat, innerR: CGFloat,
        options: [(id: String, name: String, color: Color)],
        rotation: CGFloat, count: Int, maxChars: Int
    ) {
        let midR = (innerR + outerR) / 2

        for slotOffset in -10...10 {
            let baseIndex = Int(floor(rotation / itemAngle + 0.5))
            let rawIndex = baseIndex + slotOffset
            let hasTag = rawIndex >= 0 && rawIndex < count

            let displayAngle = CGFloat(rawIndex) * itemAngle - rotation
            let dist = abs(displayAngle)
            let maxDist = itemAngle * 8
            let fade = max(0.0, 1.0 - dist / maxDist)
            guard fade > 0 else { continue }

            let halfAngle = itemAngle / 2
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

            let isSelected = hasTag && dist < itemAngle / 2

            // セクター塗り
            context.opacity = fade
            context.fill(
                sector,
                with: .color(hasTag ? .white.opacity(isSelected ? 1.0 : 0.95) : Color(white: 0.92))
            )

            // タグがない範囲は薄いグレー塗りのみ（仕切り線・バッジなし）
            guard hasTag else { context.opacity = 1.0; continue }
            let index = rawIndex
            let option = options[index]

            // 選択ハイライト（薄いグレーで浮き上がり感）
            if isSelected {
                context.fill(
                    sector,
                    with: .color(Color.gray.opacity(0.05))
                )
            }

            // 仕切り線（上端）
            let divCG = Double(cgEnd) * .pi / 180
            var divLine = Path()
            divLine.move(to: CGPoint(
                x: cx + innerR * CGFloat(cos(divCG)),
                y: cy + innerR * CGFloat(sin(divCG))
            ))
            divLine.addLine(to: CGPoint(
                x: cx + outerR * CGFloat(cos(divCG)),
                y: cy + outerR * CGFloat(sin(divCG))
            ))
            context.stroke(
                divLine,
                with: .color(Color(white: 0.35).opacity(Double(fade) * 0.5)),
                lineWidth: 1.5
            )

            // 最後のセクターは下端にも仕切り線
            if index == count - 1 {
                let divStart = Double(cgStart) * .pi / 180
                var bottomLine = Path()
                bottomLine.move(to: CGPoint(
                    x: cx + innerR * CGFloat(cos(divStart)),
                    y: cy + innerR * CGFloat(sin(divStart))
                ))
                bottomLine.addLine(to: CGPoint(
                    x: cx + outerR * CGFloat(cos(divStart)),
                    y: cy + outerR * CGFloat(sin(divStart))
                ))
                context.stroke(
                    bottomLine,
                    with: .color(Color(white: 0.35).opacity(Double(fade) * 0.5)),
                    lineWidth: 1.5
                )
            }

            // カラーバッジ + テキスト
            let cgMid = (180.0 - Double(displayAngle)) * .pi / 180
            let textX = cx + midR * CGFloat(cos(cgMid))
            let textY = cy + midR * CGFloat(sin(cgMid))

            let displayName: String = {
                if option.name.count > maxChars {
                    return String(option.name.prefix(maxChars)) + "…"
                }
                return option.name
            }()
            let fontSize: CGFloat = isSelected ? 14 : 11
            let isNoneTag = option.id == "none"

            // テキスト色: タグなしは黒、それ以外は色の明るさで判定
            let textColor: Color = {
                if isNoneTag { return Color(white: isSelected ? 0.1 : 0.4) }
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
                UIColor(option.color).getRed(&r, green: &g, blue: &b, alpha: nil)
                let luminance = 0.299 * r + 0.587 * g + 0.114 * b
                return luminance < 0.6 ? .white : .black
            }()
            let resolved = context.resolve(
                Text(displayName)
                    .font(.system(
                        size: fontSize,
                        weight: isSelected ? .bold : .semibold,
                        design: .rounded
                    ))
                    .foregroundColor(textColor)
            )
            // バッジ+テキストをセクターの角度に合わせて回転描画
            let rotAngle = Angle.degrees(-Double(displayAngle))
            var rotCtx = context
            rotCtx.translateBy(x: textX, y: textY)
            rotCtx.rotate(by: rotAngle)

            // バッジ背景（「タグなし」「なし」はバッジなし）
            if !isNoneTag {
                let badgeW = resolved.measure(in: CGSize(width: 200, height: 50)).width + 12
                let badgeH = resolved.measure(in: CGSize(width: 200, height: 50)).height + 6
                let badgeRect = CGRect(
                    x: -badgeW / 2,
                    y: -badgeH / 2,
                    width: badgeW,
                    height: badgeH
                )
                let badgePath = Path(roundedRect: badgeRect, cornerRadius: 5)
                rotCtx.fill(badgePath, with: .color(option.color.opacity(isSelected ? 1.0 : 0.8)))
            }
            rotCtx.draw(resolved, at: .zero, anchor: .center)

            context.opacity = 1.0
        }
    }

    private func drawEdge(
        context: inout GraphicsContext, cx: CGFloat, cy: CGFloat,
        radius: CGFloat, lineWidth: CGFloat,
        brightness: (CGFloat, CGFloat, CGFloat)
    ) {
        // Canvas高さに収まる角度範囲を計算（はみ出し防止）
        let halfHeight = dialHeight / 2 - lineWidth
        let maxSinAngle = min(1.0, Double(halfHeight / radius))
        let maxAngle = asin(maxSinAngle) * 180.0 / .pi
        let startDeg = 180.0 - maxAngle
        let endDeg = 180.0 + maxAngle

        var edge = Path()
        edge.addArc(
            center: CGPoint(x: cx, y: cy),
            radius: radius,
            startAngle: .degrees(startDeg),
            endAngle: .degrees(endDeg),
            clockwise: false
        )
        context.stroke(
            edge,
            with: .linearGradient(
                Gradient(colors: [
                    Color(white: brightness.0),
                    Color(white: brightness.1),
                    Color(white: brightness.2)
                ]),
                startPoint: CGPoint(x: 0, y: cy - 80),
                endPoint: CGPoint(x: 0, y: cy + 80)
            ),
            lineWidth: lineWidth
        )
    }

    private func drawPointer(context: inout GraphicsContext, cy: CGFloat) {
        let pw: CGFloat = 10
        let ph: CGFloat = 16
        let pLeft: CGFloat = -2

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

    // MARK: - 同期・選択

    private func syncParentRotation() {
        let targetID: String = {
            if let id = parentSelectedID { return id.uuidString }
            return "none"
        }()
        if let index = parentOptions.firstIndex(where: { $0.id == targetID }) {
            let target = CGFloat(index) * itemAngle
            withAnimation(.easeOut(duration: 0.2)) { parentRotation = target }
            parentDragStart = target
        }
    }

    private func syncChildRotation() {
        let targetID: String = {
            if let id = childSelectedID { return id.uuidString }
            return "none"
        }()
        if let index = childOptions.firstIndex(where: { $0.id == targetID }) {
            let target = CGFloat(index) * itemAngle
            withAnimation(.easeOut(duration: 0.2)) { childRotation = target }
            childDragStart = target
        }
    }

    private func updateParentSelection() {
        let index = snappedIndex(rotation: parentRotation, count: parentOptions.count)
        if index < parentOptions.count {
            let option = parentOptions[index]
            let newID = option.id == "none" ? nil : UUID(uuidString: option.id)
            parentSelectedID = newID
        }
    }

    private func updateChildSelection() {
        let index = snappedIndex(rotation: childRotation, count: childOptions.count)
        if index < childOptions.count {
            let option = childOptions[index]
            childSelectedID = option.id == "none" ? nil : UUID(uuidString: option.id)
        }
    }
}
