import SwiftUI
import SwiftData

// 親子統合ルーレット: 1つのCanvasで親の内周=子の外周がぴったり接する
struct TagDialView: View {
    // 親オプション
    var parentOptions: [(id: String, name: String, color: Color)]
    @Binding var parentSelectedID: UUID?
    var onParentAddTap: (() -> Void)?

    // 子オプション
    var childOptions: [(id: String, name: String, color: Color)]
    @Binding var childSelectedID: UUID?
    var onChildAddTap: (() -> Void)?

    // 子ダイアル表示
    @Binding var showChild: Bool

    // 円の設定
    private let wheelRadius: CGFloat = 300      // 親の外周半径
    private let parentThickness: CGFloat = 82   // 親セクターの厚み
    private let childThickness: CGFloat = 70    // 子セクターの厚み
    private let itemAngle: CGFloat = 8          // 各タグ間の角度（度）
    private let dialHeight: CGFloat = 160

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
        return ((raw % count) + count) % count
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
            drawEdge(context: &context, cx: cx, cy: cy, radius: parentOuterR, lineWidth: 2.5, brightness: (0.55, 0.9, 0.55))

            // 親の内周 / 子の外周（共有境界）
            drawEdge(context: &context, cx: cx, cy: cy, radius: parentInnerR, lineWidth: 1.5, brightness: (0.4, 0.7, 0.4))

            // 子の内周（showChild時のみ）
            if sc {
                drawEdge(context: &context, cx: cx, cy: cy, radius: childInnerR, lineWidth: 1.5, brightness: (0.4, 0.7, 0.4))
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
                        childRotation = childDragStart + value.translation.height * -0.3
                    } else {
                        // 親エリア（内周より左＝外側）
                        parentIsDragging = true
                        parentRotation = parentDragStart + value.translation.height * -0.3
                    }
                }
                .onEnded { value in
                    if parentIsDragging {
                        let snapped = round(parentRotation / itemAngle) * itemAngle
                        withAnimation(.easeOut(duration: 0.15)) { parentRotation = snapped }
                        parentDragStart = snapped
                        parentIsInternalChange = true
                        updateParentSelection()
                        parentIsDragging = false
                    }
                    if childIsDragging {
                        let snapped = round(childRotation / itemAngle) * itemAngle
                        withAnimation(.easeOut(duration: 0.15)) { childRotation = snapped }
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
                childRotation = childDragStart + dragY * -0.3
            } else if childIsDragging {
                let snapped = round(childRotation / itemAngle) * itemAngle
                withAnimation(.easeOut(duration: 0.15)) { childRotation = snapped }
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

        for slotOffset in -8...8 {
            let baseIndex = Int(floor(rotation / itemAngle + 0.5))
            let rawIndex = baseIndex + slotOffset
            let index = ((rawIndex % count) + count) % count
            guard index < options.count else { continue }

            let displayAngle = CGFloat(rawIndex) * itemAngle - rotation
            let dist = abs(displayAngle)
            let maxDist = itemAngle * 6
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

            let option = options[index]
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

            // 仕切り線
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
                with: .color(.white.opacity(0.5 * fade)),
                lineWidth: 0.8
            )

            // テキスト
            let cgMid = (180.0 - Double(displayAngle)) * .pi / 180
            let textX = cx + midR * CGFloat(cos(cgMid))
            let textY = cy + midR * CGFloat(sin(cgMid))

            if option.id == "add" {
                let plusIcon = context.resolve(
                    Text("＋")
                        .font(.system(size: isSelected ? 20 : 14, weight: .bold, design: .rounded))
                        .foregroundColor(isSelected ? .blue : Color(white: 0.45))
                )
                context.draw(plusIcon, at: CGPoint(x: textX, y: textY - 5), anchor: .center)
                let label = context.resolve(
                    Text("追加")
                        .font(.system(size: isSelected ? 10 : 8, weight: .medium, design: .rounded))
                        .foregroundColor(isSelected ? .blue.opacity(0.7) : Color(white: 0.5))
                )
                context.draw(label, at: CGPoint(x: textX, y: textY + 8), anchor: .center)
            } else {
                let displayName: String = {
                    if option.name.count > maxChars {
                        return String(option.name.prefix(maxChars)) + "…"
                    }
                    return option.name
                }()
                let fontSize: CGFloat = isSelected ? 16 : 12
                let resolved = context.resolve(
                    Text(displayName)
                        .font(.system(
                            size: fontSize,
                            weight: isSelected ? .bold : .medium,
                            design: .rounded
                        ))
                        .foregroundColor(Color(white: isSelected ? 0.1 : 0.3))
                )
                context.draw(resolved, at: CGPoint(x: textX, y: textY), anchor: .center)
            }

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
            if option.id == "add" {
                onParentAddTap?()
            } else {
                parentSelectedID = option.id == "none" ? nil : UUID(uuidString: option.id)
            }
        }
    }

    private func updateChildSelection() {
        let index = snappedIndex(rotation: childRotation, count: childOptions.count)
        if index < childOptions.count {
            let option = childOptions[index]
            if option.id == "add" {
                onChildAddTap?()
            } else {
                childSelectedID = option.id == "none" ? nil : UUID(uuidString: option.id)
            }
        }
    }
}
