import SwiftUI
import SwiftData
import UIKit

// MARK: - 扇形シェイプ（1セクターの形状）

struct SectorArc: Shape {
    var center: CGPoint
    var innerRadius: CGFloat
    var outerRadius: CGFloat
    var startAngle: Angle
    var endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: center, radius: innerRadius,
                 startAngle: startAngle, endAngle: endAngle, clockwise: false)
        p.addArc(center: center, radius: outerRadius,
                 startAngle: endAngle, endAngle: startAngle, clockwise: true)
        p.closeSubpath()
        return p
    }
}

// MARK: - 親子統合ルーレット（SwiftUIビューベース）

struct TagDialView: View {
    // 親オプション
    var parentOptions: [(id: String, name: String, color: Color)]
    @Binding var parentSelectedID: UUID?

    // 子オプション
    var childOptions: [(id: String, name: String, color: Color)]
    @Binding var childSelectedID: UUID?

    // 子ダイアル表示
    @Binding var showChild: Bool

    // トレーが開いているか（カラー表示の切り替えに使用）
    var isOpen: Bool = false

    // 外部ドラッグ入力（子タブからの引き出し用）
    @Binding var childExternalDragY: CGFloat?

    // タグ操作コールバック（isChild: 子タグか）
    var onEditTag: ((_ id: String, _ isChild: Bool) -> Void)?
    var onDeleteTag: ((_ id: String) -> Void)?

    // ジオメトリ定数
    private let wheelRadius: CGFloat = 350
    private let parentThickness: CGFloat = 110
    private let childThickness: CGFloat = 110
    private let itemAngle: CGFloat = 8
    private let dialHeight: CGFloat = 211

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

    // 長押しメニュー用
    @State private var longPressedSectorID: String?
    @State private var longPressedSectorIsChild = false
    @State private var showSectorMenu = false

    // 計算プロパティ
    private var parentOuterR: CGFloat { wheelRadius }
    private var parentInnerR: CGFloat { wheelRadius - parentThickness }
    private var childOuterR: CGFloat { parentInnerR }
    private var childInnerR: CGFloat { parentInnerR - childThickness }

    private var canvasWidth: CGFloat {
        let cx = wheelRadius + 2
        let innermost = showChild ? childInnerR : parentInnerR
        let needed = cx - innermost * CGFloat(cos(Double.pi * 30.0 / 180.0)) + 14
        return max(needed, 100)
    }

    // MARK: - Body

    var body: some View {
        let cx = wheelRadius + 2
        let cy = dialHeight / 2
        let center = CGPoint(x: cx, y: cy)

        // 常にCanvas描画（チラ見せ・アニメーション切り替え問題を回避）
        canvasDialContent(cx: cx, cy: cy)
            .frame(width: canvasWidth, height: dialHeight)
            .clipped()
            // 開いてる時だけタップ・長押しオーバーレイを重ねる
            .overlay {
                if isOpen {
                    sectorGestureOverlay(center: center)
                }
            }
            .contentShape(Rectangle())
        // ドラッグ: simultaneousでセクターのタップと共存
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    let touchCX = wheelRadius + 2
                    let touchX = value.startLocation.x
                    let borderX = touchCX - parentInnerR

                    if showChild && touchX > borderX {
                        // 子エリア（内周より右＝内側）
                        childIsDragging = true
                        let rawRot = childDragStart + value.translation.height * -0.3
                        childRotation = clampedRotation(rawRot, count: childOptions.count)
                    } else {
                        // 親エリア（内周より左＝外側）
                        parentIsDragging = true
                        let rawRot = parentDragStart + value.translation.height * -0.3
                        parentRotation = clampedRotation(rawRot, count: parentOptions.count)
                    }
                }
                .onEnded { _ in
                    if parentIsDragging {
                        let snapped = clampedSnap(parentRotation, count: parentOptions.count)
                        withAnimation(.spring(response: 0.3)) { parentRotation = snapped }
                        parentDragStart = snapped
                        parentIsInternalChange = true
                        updateParentSelection()
                        parentIsDragging = false
                    }
                    if childIsDragging {
                        let snapped = clampedSnap(childRotation, count: childOptions.count)
                        withAnimation(.spring(response: 0.3)) { childRotation = snapped }
                        childDragStart = snapped
                        childIsInternalChange = true
                        updateChildSelection()
                        childIsDragging = false
                    }
                }
        )
        // タップ消費（親ビューのトレー閉じジェスチャーに伝播させない）
        .onTapGesture { }
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
            if parentIsInternalChange { parentIsInternalChange = false }
            else { syncParentRotation() }
        }
        .onChange(of: childSelectedID) { _, _ in
            if childIsInternalChange { childIsInternalChange = false }
            else { syncChildRotation() }
        }
        // 長押しメニュー（四角いプレビューが出ないconfirmationDialog方式）
        .confirmationDialog(
            "",
            isPresented: $showSectorMenu,
            titleVisibility: .hidden
        ) {
            Button("タグ名・色を編集") {
                if let id = longPressedSectorID {
                    onEditTag?(id, longPressedSectorIsChild)
                }
            }
            Button("削除", role: .destructive) {
                if let id = longPressedSectorID {
                    onDeleteTag?(id)
                }
            }
            Button("キャンセル", role: .cancel) {}
        }
    }

    // MARK: - ジェスチャーオーバーレイ（開いてる時のみ）

    // 透明なジェスチャーオーバーレイ（タップ・長押しエリア、描画なし）
    @ViewBuilder
    private func sectorGestureOverlay(center: CGPoint) -> some View {
        ZStack {
            // 親セクターのタップ/長押しエリア
            gestureRing(
                center: center, outerR: parentOuterR, innerR: parentInnerR,
                options: parentOptions, rotation: parentRotation,
                isChild: false
            )
            // 子セクターのタップ/長押しエリア
            if showChild && !childOptions.isEmpty {
                gestureRing(
                    center: center, outerR: childOuterR, innerR: childInnerR,
                    options: childOptions, rotation: childRotation,
                    isChild: true
                )
            }
        }
    }

    // 各セクターの透明タップ/長押しエリア
    @ViewBuilder
    private func gestureRing(
        center: CGPoint, outerR: CGFloat, innerR: CGFloat,
        options: [(id: String, name: String, color: Color)],
        rotation: CGFloat, isChild: Bool
    ) -> some View {
        let baseIndex = Int(floor(rotation / itemAngle + 0.5))

        ForEach(-10...10, id: \.self) { offset in
            let rawIndex = baseIndex + offset
            let hasTag = rawIndex >= 0 && rawIndex < options.count
            let displayAngle = CGFloat(rawIndex) * itemAngle - rotation
            let dist = abs(displayAngle)

            if hasTag && dist < itemAngle * 8 {
                let halfAngle = itemAngle / 2
                let cgStart = Angle.degrees(180.0 - Double(displayAngle + halfAngle))
                let cgEnd = Angle.degrees(180.0 - Double(displayAngle - halfAngle))
                let arc = SectorArc(
                    center: center, innerRadius: innerR, outerRadius: outerR,
                    startAngle: cgStart, endAngle: cgEnd
                )
                let option = options[rawIndex]
                let isNone = option.id == "none"

                // 透明な塗りでタップ領域を定義
                arc.fill(Color.clear)
                    .contentShape(arc)
                    .onTapGesture {
                        snapToTag(index: rawIndex, isChild: isChild)
                    }
                    .if(!isNone) { view in
                        view.onLongPressGesture {
                            longPressedSectorID = option.id
                            longPressedSectorIsChild = isChild
                            showSectorMenu = true
                        }
                    }
            }
        }
    }

    // MARK: - 閉じてる時: Canvas描画（チラ見せ確実表示）

    @ViewBuilder
    private func canvasDialContent(cx: CGFloat, cy: CGFloat) -> some View {
        let pOpts = parentOptions
        let cOpts = childOptions
        let pRot = parentRotation
        let cRot = childRotation
        let pCount = pOpts.count
        let cCount = cOpts.count
        let sc = showChild
        let open = isOpen

        Canvas { context, size in
            // 親セクター
            if pCount > 0 {
                drawCanvasSectors(
                    context: &context, cx: cx, cy: cy,
                    outerR: parentOuterR, innerR: parentInnerR,
                    options: pOpts, rotation: pRot, count: pCount, maxChars: 10,
                    isOpen: open
                )
            }
            // 子セクター
            if sc && cCount > 0 {
                drawCanvasSectors(
                    context: &context, cx: cx, cy: cy,
                    outerR: childOuterR, innerR: childInnerR,
                    options: cOpts, rotation: cRot, count: cCount, maxChars: 7,
                    isOpen: open
                )
            }
            // 縁取り
            drawCanvasEdge(context: &context, cx: cx, cy: cy, radius: parentOuterR, lineWidth: 3, brightness: (0.35, 0.5, 0.35))
            drawCanvasEdge(context: &context, cx: cx, cy: cy, radius: parentInnerR, lineWidth: 1.5, brightness: (0.3, 0.45, 0.3))
            if sc {
                drawCanvasEdge(context: &context, cx: cx, cy: cy, radius: childInnerR, lineWidth: 1.5, brightness: (0.3, 0.45, 0.3))
            }
            // ポインター
            drawCanvasPointer(context: &context, cy: cy)
            // インナーシャドウ
            let shadowSize: CGFloat = 8
            let shadowColor = Color.black.opacity(0.2)
            let clear = Color.clear
            let shadowLeft: CGFloat = 20
            let topGrad = Gradient(colors: [shadowColor, clear])
            context.fill(
                Path(CGRect(x: shadowLeft, y: 0, width: size.width - shadowLeft, height: shadowSize)),
                with: .linearGradient(topGrad, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: shadowSize))
            )
            context.fill(
                Path(CGRect(x: shadowLeft, y: size.height - shadowSize, width: size.width - shadowLeft, height: shadowSize)),
                with: .linearGradient(topGrad, startPoint: CGPoint(x: 0, y: size.height), endPoint: CGPoint(x: 0, y: size.height - shadowSize))
            )
            context.fill(
                Path(CGRect(x: size.width - shadowSize, y: 0, width: shadowSize, height: size.height)),
                with: .linearGradient(topGrad, startPoint: CGPoint(x: size.width, y: 0), endPoint: CGPoint(x: size.width - shadowSize, y: 0))
            )
        }
    }

    // MARK: - Canvas描画ヘルパー（閉じてる時用）

    private func drawCanvasSectors(
        context: inout GraphicsContext, cx: CGFloat, cy: CGFloat,
        outerR: CGFloat, innerR: CGFloat,
        options: [(id: String, name: String, color: Color)],
        rotation: CGFloat, count: Int, maxChars: Int,
        isOpen: Bool
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

            var sector = Path()
            sector.addArc(center: CGPoint(x: cx, y: cy), radius: innerR,
                          startAngle: .degrees(cgStart), endAngle: .degrees(cgEnd), clockwise: false)
            sector.addArc(center: CGPoint(x: cx, y: cy), radius: outerR,
                          startAngle: .degrees(cgEnd), endAngle: .degrees(cgStart), clockwise: true)
            sector.closeSubpath()

            let isSelected = hasTag && dist < itemAngle / 2
            context.opacity = fade
            // セクター塗り
            if hasTag && isOpen {
                let option = options[rawIndex]
                let isNone = option.id == "none"
                context.fill(sector, with: .color(isNone ? .white.opacity(isSelected ? 1.0 : 0.95) : option.color.opacity(isSelected ? 1.0 : 0.85)))
            } else {
                context.fill(sector, with: .color(hasTag ? .white.opacity(isSelected ? 1.0 : 0.95) : Color(white: 0.92)))
            }

            // 仕切り線
            if !isOpen || hasTag {
                let divCG = Double(cgEnd) * .pi / 180
                var divLine = Path()
                divLine.move(to: CGPoint(x: cx + innerR * CGFloat(cos(divCG)), y: cy + innerR * CGFloat(sin(divCG))))
                divLine.addLine(to: CGPoint(x: cx + outerR * CGFloat(cos(divCG)), y: cy + outerR * CGFloat(sin(divCG))))
                context.stroke(divLine, with: .color(Color(white: 0.35).opacity(Double(fade) * 0.5)), lineWidth: 1.5)
            }

            guard hasTag else { context.opacity = 1.0; continue }
            let option = options[rawIndex]

            // 選択ハイライト
            if isSelected {
                context.fill(sector, with: .color(Color.gray.opacity(0.05)))
            }
            // 最後のセクターの下端仕切り線
            if rawIndex == count - 1 {
                let divStart = Double(cgStart) * .pi / 180
                var bottomLine = Path()
                bottomLine.move(to: CGPoint(x: cx + innerR * CGFloat(cos(divStart)), y: cy + innerR * CGFloat(sin(divStart))))
                bottomLine.addLine(to: CGPoint(x: cx + outerR * CGFloat(cos(divStart)), y: cy + outerR * CGFloat(sin(divStart))))
                context.stroke(bottomLine, with: .color(Color(white: 0.35).opacity(Double(fade) * 0.5)), lineWidth: 1.5)
            }

            // テキスト
            let cgMid = (180.0 - Double(displayAngle)) * .pi / 180
            let textX = cx + midR * CGFloat(cos(cgMid))
            let textY = cy + midR * CGFloat(sin(cgMid))
            let displayName = option.name.count > maxChars ? String(option.name.prefix(maxChars)) + "…" : option.name
            let nameLen = displayName.count
            let isParent = maxChars >= 10
            let baseFontSize: CGFloat = {
                if isParent {
                    if nameLen <= 2 { return 24 }; if nameLen <= 3 { return 21 }
                    if nameLen <= 4 { return 18 }; if nameLen <= 6 { return 15 }
                    if nameLen <= 8 { return 13 }; return 11
                } else {
                    if nameLen <= 2 { return 16 }; if nameLen <= 3 { return 14 }
                    if nameLen <= 5 { return 12 }; return 10
                }
            }()
            let isNoneTag = option.id == "none"
            let fontSize: CGFloat = isNoneTag ? (isParent ? 16 : 14) : (isSelected ? baseFontSize : max(baseFontSize - 2, 9))
            let textColor: Color = {
                if isNoneTag { return Color(white: 0.55) }
                if !isOpen { return .black }
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
                UIColor(option.color).getRed(&r, green: &g, blue: &b, alpha: nil)
                let luminance = 0.299 * r + 0.587 * g + 0.114 * b
                return luminance < 0.6 ? .white : .black
            }()

            let resolved = context.resolve(
                Text(displayName)
                    .font(.system(size: fontSize, weight: isSelected ? .bold : .semibold, design: .rounded))
                    .foregroundColor(textColor)
            )
            var rotCtx = context
            rotCtx.translateBy(x: textX, y: textY)
            rotCtx.rotate(by: Angle.degrees(-Double(displayAngle)))
            rotCtx.draw(resolved, at: .zero, anchor: .center)
            context.opacity = 1.0
        }
    }

    private func drawCanvasEdge(
        context: inout GraphicsContext, cx: CGFloat, cy: CGFloat,
        radius: CGFloat, lineWidth: CGFloat, brightness: (CGFloat, CGFloat, CGFloat)
    ) {
        let halfHeight = dialHeight / 2
        let maxSinAngle = min(1.0, Double(halfHeight / radius))
        let maxAngle = asin(maxSinAngle) * 180.0 / .pi
        var edge = Path()
        edge.addArc(center: CGPoint(x: cx, y: cy), radius: radius,
                     startAngle: .degrees(180.0 - maxAngle), endAngle: .degrees(180.0 + maxAngle), clockwise: false)
        context.stroke(edge, with: .linearGradient(
            Gradient(colors: [Color(white: brightness.0), Color(white: brightness.1), Color(white: brightness.2)]),
            startPoint: CGPoint(x: 0, y: cy - 80), endPoint: CGPoint(x: 0, y: cy + 80)
        ), lineWidth: lineWidth)
    }

    private func drawCanvasPointer(context: inout GraphicsContext, cy: CGFloat) {
        let pw: CGFloat = 10, ph: CGFloat = 16, pLeft: CGFloat = -2
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
        context.fill(pointer, with: .linearGradient(
            Gradient(colors: [Color(red: 0.9, green: 0.15, blue: 0.1), Color(red: 0.7, green: 0.1, blue: 0.08)]),
            startPoint: CGPoint(x: 0, y: cy - ph / 2), endPoint: CGPoint(x: 0, y: cy + ph / 2)
        ))
        var hl = Path()
        hl.move(to: CGPoint(x: pLeft + 1, y: cy - ph / 2 + 2))
        hl.addLine(to: CGPoint(x: pLeft + pw - 3, y: cy))
        context.stroke(hl, with: .color(.white.opacity(0.5)), lineWidth: 1)
    }

    // MARK: - セクターリング（ForEachで個別ビュー生成）

    @ViewBuilder
    private func sectorRing(
        center: CGPoint, outerR: CGFloat, innerR: CGFloat,
        options: [(id: String, name: String, color: Color)],
        rotation: CGFloat, maxChars: Int, isChild: Bool
    ) -> some View {
        let baseIndex = Int(floor(rotation / itemAngle + 0.5))

        ForEach(-10...10, id: \.self) { offset in
            let rawIndex = baseIndex + offset
            let hasTag = rawIndex >= 0 && rawIndex < options.count
            let displayAngle = CGFloat(rawIndex) * itemAngle - rotation
            let dist = abs(displayAngle)
            let maxDist = itemAngle * 8
            let fade = max(0.0, 1.0 - dist / maxDist)

            if fade > 0 {
                sectorSlotView(
                    center: center, outerR: outerR, innerR: innerR,
                    options: options, rawIndex: rawIndex, hasTag: hasTag,
                    displayAngle: displayAngle, fade: fade,
                    isSelected: hasTag && dist < itemAngle / 2,
                    maxChars: maxChars, isChild: isChild
                )
            }
        }
    }

    // MARK: - 個別セクタービュー

    @ViewBuilder
    private func sectorSlotView(
        center: CGPoint, outerR: CGFloat, innerR: CGFloat,
        options: [(id: String, name: String, color: Color)],
        rawIndex: Int, hasTag: Bool,
        displayAngle: CGFloat, fade: CGFloat, isSelected: Bool,
        maxChars: Int, isChild: Bool
    ) -> some View {
        let halfAngle = itemAngle / 2
        let cgStart = Angle.degrees(180.0 - Double(displayAngle + halfAngle))
        let cgEnd = Angle.degrees(180.0 - Double(displayAngle - halfAngle))

        let arc = SectorArc(
            center: center, innerRadius: innerR, outerRadius: outerR,
            startAngle: cgStart, endAngle: cgEnd
        )

        if hasTag {
            let option = options[rawIndex]
            let isNone = option.id == "none"
            let fillColor = sectorFillColor(option: option, isSelected: isSelected)

            arc.fill(fillColor)
                .overlay {
                    // 選択ハイライト（閉じている時のみ）
                    if isSelected && !isOpen {
                        arc.fill(Color.gray.opacity(0.05))
                    }

                    // 仕切り線（上端）
                    dividerLine(center: center, angle: cgEnd,
                                innerR: innerR, outerR: outerR, fade: fade)

                    // 最後のセクターは下端にも仕切り線
                    if rawIndex == options.count - 1 {
                        dividerLine(center: center, angle: cgStart,
                                    innerR: innerR, outerR: outerR, fade: fade)
                    }

                    // テキスト
                    sectorTextView(
                        option: option, center: center,
                        midR: (innerR + outerR) / 2,
                        displayAngle: displayAngle, isSelected: isSelected,
                        maxChars: maxChars
                    )
                }
                .opacity(fade)
                .contentShape(arc)
                // タップでそのタグにスナップ回転（新機能）
                .onTapGesture {
                    snapToTag(index: rawIndex, isChild: isChild)
                }
                // 長押しで編集・削除メニュー（タグなし以外）
                .if(!isNone) { view in
                    view.onLongPressGesture {
                        longPressedSectorID = option.id
                        longPressedSectorIsChild = isChild
                        showSectorMenu = true
                    }
                }
        } else {
            // タグなし範囲（灰色背景のみ）
            arc.fill(Color(white: 0.92))
                .overlay {
                    if !isOpen {
                        dividerLine(center: center, angle: cgEnd,
                                    innerR: innerR, outerR: outerR, fade: fade)
                    }
                }
                .opacity(fade)
                .allowsHitTesting(false)
        }
    }

    // MARK: - セクター塗り色

    private func sectorFillColor(
        option: (id: String, name: String, color: Color),
        isSelected: Bool
    ) -> Color {
        if isOpen {
            if option.id == "none" {
                return .white.opacity(isSelected ? 1.0 : 0.95)
            }
            return option.color.opacity(isSelected ? 1.0 : 0.85)
        } else {
            return .white.opacity(isSelected ? 1.0 : 0.95)
        }
    }

    // MARK: - テキスト描画

    @ViewBuilder
    private func sectorTextView(
        option: (id: String, name: String, color: Color),
        center: CGPoint, midR: CGFloat,
        displayAngle: CGFloat, isSelected: Bool,
        maxChars: Int
    ) -> some View {
        let displayName = option.name.count > maxChars
            ? String(option.name.prefix(maxChars)) + "…"
            : option.name
        let nameLen = displayName.count
        let isNoneTag = option.id == "none"
        let isParent = maxChars >= 10

        // フォントサイズ: セクター幅と文字数に応じて可変
        let baseFontSize: CGFloat = {
            if isParent {
                if nameLen <= 2 { return 24 }
                if nameLen <= 3 { return 21 }
                if nameLen <= 4 { return 18 }
                if nameLen <= 6 { return 15 }
                if nameLen <= 8 { return 13 }
                return 11
            } else {
                if nameLen <= 2 { return 16 }
                if nameLen <= 3 { return 14 }
                if nameLen <= 5 { return 12 }
                return 10
            }
        }()
        let fontSize: CGFloat = isNoneTag
            ? (isParent ? 16 : 14)
            : (isSelected ? baseFontSize : max(baseFontSize - 2, 9))

        // テキスト色
        let textColor = textColorFor(option: option)

        // テキスト位置: セクター中央（弧の中点）
        let cgMid = (180.0 - Double(displayAngle)) * .pi / 180
        let textX = center.x + midR * CGFloat(cos(cgMid))
        let textY = center.y + midR * CGFloat(sin(cgMid))

        Text(displayName)
            .font(.system(
                size: fontSize,
                weight: isSelected ? .bold : .semibold,
                design: .rounded
            ))
            .foregroundColor(textColor)
            .rotationEffect(.degrees(-Double(displayAngle)))
            .position(x: textX, y: textY)
    }

    // テキスト色: タグなしは薄グレー、それ以外は背景色の明度で判定
    private func textColorFor(
        option: (id: String, name: String, color: Color)
    ) -> Color {
        if option.id == "none" { return Color(white: 0.55) }
        // 閉じている時は白背景なので黒
        if !isOpen { return .black }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        UIColor(option.color).getRed(&r, green: &g, blue: &b, alpha: nil)
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance < 0.6 ? .white : .black
    }

    // MARK: - 仕切り線

    @ViewBuilder
    private func dividerLine(
        center: CGPoint, angle: Angle,
        innerR: CGFloat, outerR: CGFloat, fade: CGFloat
    ) -> some View {
        let rad = angle.radians
        Path { p in
            p.move(to: CGPoint(
                x: center.x + innerR * cos(rad),
                y: center.y + innerR * sin(rad)
            ))
            p.addLine(to: CGPoint(
                x: center.x + outerR * cos(rad),
                y: center.y + outerR * sin(rad)
            ))
        }
        .stroke(Color(white: 0.35).opacity(Double(fade) * 0.5), lineWidth: 1.5)
    }

    // MARK: - 縁取りアーク

    @ViewBuilder
    private func edgeArcView(
        center: CGPoint, radius: CGFloat, lineWidth: CGFloat,
        brightness: (CGFloat, CGFloat, CGFloat)
    ) -> some View {
        let halfHeight = dialHeight / 2
        let maxSinAngle = min(1.0, Double(halfHeight / radius))
        let maxAngle = asin(maxSinAngle) * 180.0 / .pi
        let startDeg = 180.0 - maxAngle
        let endDeg = 180.0 + maxAngle

        Path { p in
            p.addArc(center: center, radius: radius,
                     startAngle: .degrees(startDeg),
                     endAngle: .degrees(endDeg),
                     clockwise: false)
        }
        .stroke(
            LinearGradient(
                colors: [
                    Color(white: brightness.0),
                    Color(white: brightness.1),
                    Color(white: brightness.2)
                ],
                startPoint: UnitPoint(x: 0, y: (halfHeight - 80) / dialHeight),
                endPoint: UnitPoint(x: 0, y: (halfHeight + 80) / dialHeight)
            ),
            lineWidth: lineWidth
        )
        .allowsHitTesting(false)
    }

    // MARK: - ポインター（赤い三角）

    @ViewBuilder
    private func pointerView(cy: CGFloat) -> some View {
        let pw: CGFloat = 10
        let ph: CGFloat = 16
        let pLeft: CGFloat = -2

        // シャドウ
        Path { p in
            p.move(to: CGPoint(x: pLeft + 1, y: cy - ph / 2 + 1))
            p.addLine(to: CGPoint(x: pLeft + pw + 1, y: cy + 1))
            p.addLine(to: CGPoint(x: pLeft + 1, y: cy + ph / 2 + 1))
            p.closeSubpath()
        }
        .fill(Color.black.opacity(0.3))

        // ポインター本体
        Path { p in
            p.move(to: CGPoint(x: pLeft, y: cy - ph / 2))
            p.addLine(to: CGPoint(x: pLeft + pw, y: cy))
            p.addLine(to: CGPoint(x: pLeft, y: cy + ph / 2))
            p.closeSubpath()
        }
        .fill(
            LinearGradient(
                colors: [
                    Color(red: 0.9, green: 0.15, blue: 0.1),
                    Color(red: 0.7, green: 0.1, blue: 0.08)
                ],
                startPoint: UnitPoint(x: 0, y: (cy - ph / 2) / dialHeight),
                endPoint: UnitPoint(x: 0, y: (cy + ph / 2) / dialHeight)
            )
        )

        // ハイライト線
        Path { p in
            p.move(to: CGPoint(x: pLeft + 1, y: cy - ph / 2 + 2))
            p.addLine(to: CGPoint(x: pLeft + pw - 3, y: cy))
        }
        .stroke(Color.white.opacity(0.5), lineWidth: 1)
    }

    // MARK: - インナーシャドウ（トレーの縁の影）

    @ViewBuilder
    private func innerShadowOverlay() -> some View {
        let shadowSize: CGFloat = 8
        let shadowLeft: CGFloat = 20

        // 上辺
        VStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(0.2), .clear],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: shadowSize)
                .padding(.leading, shadowLeft)
            Spacer(minLength: 0)
        }

        // 下辺
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            LinearGradient(colors: [.black.opacity(0.2), .clear],
                           startPoint: .bottom, endPoint: .top)
                .frame(height: shadowSize)
                .padding(.leading, shadowLeft)
        }

        // 右辺
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            LinearGradient(colors: [.black.opacity(0.2), .clear],
                           startPoint: .trailing, endPoint: .leading)
                .frame(width: shadowSize)
        }
    }

    // MARK: - タップでタグにスナップ回転（新機能）

    // タップ回転アニメーション用タイマー
    @State private var snapTimer: Timer?

    private func snapToTag(index: Int, isChild: Bool) {
        let target = CGFloat(index) * itemAngle
        let current = isChild ? childRotation : parentRotation
        let totalDelta = target - current
        guard abs(totalDelta) > 0.1 else { return }

        // 既存のタイマーがあればキャンセル
        snapTimer?.invalidate()

        // 細かいステップに分割して送り込む（ドラッグ風コマ送り）
        let totalSteps = max(8, Int(abs(totalDelta) / itemAngle) * 6)  // 1タグあたり6コマ
        let interval: TimeInterval = 0.012  // ~83fps
        var step = 0

        snapTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            step += 1
            // easeInOut カーブ: 最初ゆっくり → 中盤加速 → 最後ゆっくり
            let t = Double(step) / Double(totalSteps)
            let eased = t < 0.5
                ? 4 * t * t * t
                : 1 - pow(-2 * t + 2, 3) / 2

            let newRot = current + CGFloat(eased) * totalDelta

            if isChild {
                childRotation = newRot
            } else {
                parentRotation = newRot
            }

            if step >= totalSteps {
                timer.invalidate()
                // ピタッと止まる
                if isChild {
                    childRotation = target
                } else {
                    parentRotation = target
                }
                if isChild {
                    childDragStart = target
                    childIsInternalChange = true
                    updateChildSelection()
                } else {
                    parentDragStart = target
                    parentIsInternalChange = true
                    updateParentSelection()
                }
                snapTimer = nil
            }
        }
    }

    // MARK: - ヘルパー関数

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

    // MARK: - 同期・選択

    private func syncParentRotation() {
        let targetID = parentSelectedID?.uuidString ?? "none"
        if let index = parentOptions.firstIndex(where: { $0.id == targetID }) {
            let target = CGFloat(index) * itemAngle
            withAnimation(.easeOut(duration: 0.2)) { parentRotation = target }
            parentDragStart = target
        }
    }

    private func syncChildRotation() {
        let targetID = childSelectedID?.uuidString ?? "none"
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
            parentSelectedID = option.id == "none" ? nil : UUID(uuidString: option.id)
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

// MARK: - 条件付きモディファイア

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
