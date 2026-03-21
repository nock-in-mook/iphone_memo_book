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
    // 長押しメニュー表示コールバック（親ビューでダイアログ表示）
    var onLongPress: ((_ id: String, _ name: String, _ color: Color, _ isChild: Bool) -> Void)?

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

    // sync抑制タイマー（onEnded後にsyncが暴発するのを防止）
    @State private var parentSettling = false
    @State private var childSettling = false

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
                .onEnded { value in
                    if parentIsDragging {
                        // snapTimerが走っていたらキャンセル
                        snapTimer?.invalidate()
                        snapTimer = nil
                        let snapped = clampedSnap(parentRotation, count: parentOptions.count)
                        // 移動量が小さければアニメーションなしで即スナップ
                        let delta = abs(parentRotation - snapped)
                        if delta < itemAngle * 0.3 {
                            parentRotation = snapped
                        } else {
                            withAnimation(.easeOut(duration: 0.15)) { parentRotation = snapped }
                        }
                        parentDragStart = snapped
                        parentIsInternalChange = true
                        parentSettling = true
                        updateParentSelection()
                        parentIsDragging = false
                        // 0.5秒後にsettling解除
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            parentSettling = false
                        }
                    }
                    if childIsDragging {
                        snapTimer?.invalidate()
                        snapTimer = nil
                        let snapped = clampedSnap(childRotation, count: childOptions.count)
                        let delta = abs(childRotation - snapped)
                        if delta < itemAngle * 0.3 {
                            childRotation = snapped
                        } else {
                            withAnimation(.easeOut(duration: 0.15)) { childRotation = snapped }
                        }
                        childDragStart = snapped
                        childIsInternalChange = true
                        childSettling = true
                        updateChildSelection()
                        childIsDragging = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            childSettling = false
                        }
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
                withAnimation(.easeOut(duration: 0.15)) { childRotation = snapped }
                childDragStart = snapped
                childIsInternalChange = true
                childSettling = true
                updateChildSelection()
                childIsDragging = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    childSettling = false
                }
            }
        }
        .onChange(of: parentSelectedID) { old, new in
            if parentIsInternalChange {
                parentIsInternalChange = false
            } else {
                syncParentRotation()
            }
        }
        .onChange(of: childSelectedID) { old, new in
            if childIsInternalChange {
                childIsInternalChange = false
            } else {
                syncChildRotation()
            }
        }
        // 子オプションが変わった時（親タグ切替時）もセンター同期
        // settlingガードがあるのでドラッグ直後の暴発は防止される
        .onChange(of: childOptions.map(\.id)) { _, _ in
            syncChildRotation()
        }
        // 長押しメニューはMemoInputView側で表示（onLongPressコールバック経由）
    }

    // MARK: - 長押しカスタムダイアログ

    @ViewBuilder
    private func sectorActionDialog(name: String, color: Color, isChild: Bool, id: String) -> some View {
        // 画面全体を覆うために固定サイズで表示
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.3)
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) { showSectorMenu = false }
                    }

                VStack(spacing: 0) {
                    // ヘッダー
                    VStack(spacing: 8) {
                        Circle()
                            .fill(color)
                            .frame(width: 32, height: 32)
                            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)

                        Text(name)
                            .font(.system(size: 17, weight: .bold, design: .rounded))

                        Text(isChild ? "子タグ" : "親タグ")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                    Divider()

                    // 編集
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { showSectorMenu = false }
                        onEditTag?(id, isChild)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "pencil")
                                .font(.system(size: 16))
                                .foregroundStyle(.blue)
                            Text("タグ名・色を編集")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading, 50)

                    // 削除
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { showSectorMenu = false }
                        onDeleteTag?(id)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "trash")
                                .font(.system(size: 16))
                                .foregroundStyle(.red)
                            Text("削除")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.red)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)

                    Divider()

                    // 閉じる
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { showSectorMenu = false }
                    } label: {
                        Text("閉じる")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: min(geo.size.width - 60, 300))
                .background(Color(uiColor: .systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .transition(.opacity)
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
                            let opts = isChild ? childOptions : parentOptions
                            let info = opts.first(where: { $0.id == option.id })
                            onLongPress?(option.id, info?.name ?? "", info?.color ?? .gray, isChild)
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
            // インナーシャドウ（弧の左端位置を計算して、弧の外にはみ出さないようにする）
            let shadowSize: CGFloat = 7
            let shadowColor = Color.black.opacity(0.3)
            let clear = Color.clear
            let sinAngle = min(1.0, cy / parentOuterR)
            let cosAngle = sqrt(1.0 - sinAngle * sinAngle)
            let shadowLeft = cx - (parentOuterR + 2) * cosAngle
            let topGrad = Gradient(colors: [shadowColor, clear])
            context.fill(Path(CGRect(x: shadowLeft, y: 0, width: size.width - shadowLeft, height: shadowSize)),
                with: .linearGradient(topGrad, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: shadowSize)))
            context.fill(Path(CGRect(x: shadowLeft, y: size.height - shadowSize, width: size.width - shadowLeft, height: shadowSize)),
                with: .linearGradient(topGrad, startPoint: CGPoint(x: 0, y: size.height), endPoint: CGPoint(x: 0, y: size.height - shadowSize)))
            context.fill(Path(CGRect(x: size.width - shadowSize, y: 0, width: shadowSize, height: size.height)),
                with: .linearGradient(topGrad, startPoint: CGPoint(x: size.width, y: 0), endPoint: CGPoint(x: size.width - shadowSize, y: 0)))
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
            // セクターは常に不透明で描画
            context.opacity = 1.0
            // セクター塗り
            if hasTag && isOpen {
                let option = options[rawIndex]
                let isNone = option.id == "none"
                context.fill(sector, with: .color(isNone ? .white : option.color))
            } else {
                context.fill(sector, with: .color(hasTag ? .white : Color(white: 0.92)))
            }

            // テキスト・仕切り線にはfadeを適用
            context.opacity = fade
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
            let isParent = maxChars >= 10
            let isNoneTag = option.id == "none"
            let textColor: Color = isNoneTag ? Color(white: 0.55) : (isSelected ? .black : Color(white: 0.25))
            let fontWeight: Font.Weight = isSelected ? .bold : .semibold

            // 表示文字数を制限（半角幅換算: 親10、子7）
            let maxHalfWidthUnits: CGFloat = isParent ? 12 : 10
            let displayName: String = {
                var width: CGFloat = 0
                var result = ""
                for ch in option.name {
                    let w: CGFloat = ch.isASCII ? 1.0 : 2.0
                    if width + w > maxHalfWidthUnits {
                        return result + "…"
                    }
                    width += w
                    result.append(ch)
                }
                return result
            }()

            // セクターの弧の長さ
            let sectorWidth = (outerR - innerR) * 0.9  // セクターの放射方向の幅の90%

            // 最大フォントサイズからresolveで実測して収まる最大を探す
            let maxFont: CGFloat = isNoneTag ? (isParent ? 16 : 14) : (isParent ? 22 : 16)
            let minFont: CGFloat = isParent ? 13 : 11
            var finalResolved: GraphicsContext.ResolvedText!

            for fs in stride(from: maxFont, through: minFont, by: -0.5) {
                let resolved = context.resolve(
                    Text(displayName)
                        .font(.system(size: fs, weight: fontWeight, design: .rounded))
                        .foregroundColor(textColor)
                )
                let measuredWidth = resolved.measure(in: CGSize(width: 9999, height: 9999)).width
                if measuredWidth <= sectorWidth {
                    finalResolved = resolved
                    break
                }
                if fs <= minFont {
                    finalResolved = resolved
                }
            }

            var rotCtx = context
            rotCtx.translateBy(x: textX, y: textY)
            rotCtx.rotate(by: Angle.degrees(-Double(displayAngle)))
            if isSelected && !isNoneTag {
                rotCtx.addFilter(.shadow(color: .black.opacity(0.4), radius: 1.5, x: -1, y: 1))
            }
            rotCtx.draw(finalResolved, at: .zero, anchor: .center)
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

                    // 仕切り線・テキストにはfade適用
                    Group {
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
                }
                .contentShape(arc)
                // タップでそのタグにスナップ回転（新機能）
                .onTapGesture {
                    snapToTag(index: rawIndex, isChild: isChild)
                }
                // 長押しで編集・削除メニュー（タグなし以外）
                .if(!isNone) { view in
                    view.onLongPressGesture {
                        let opts = isChild ? childOptions : parentOptions
                        let info = opts.first(where: { $0.id == option.id })
                        onLongPress?(option.id, info?.name ?? "", info?.color ?? .gray, isChild)
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
            if option.id == "none" { return .white }
            return option.color
        } else {
            return .white
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
        let isNoneTag = option.id == "none"
        let isParent = maxChars >= 10
        let maxFontSize: CGFloat = isNoneTag ? (isParent ? 16 : 14) : (isParent ? 22 : 16)
        let textColor: Color = isNoneTag ? Color(white: 0.55) : (isSelected ? .black : Color(white: 0.25))

        // 文字数制限（半角幅換算）
        let maxHalfWidthUnits: CGFloat = isParent ? 10 : 7
        let displayName: String = {
            var width: CGFloat = 0
            var result = ""
            for ch in option.name {
                let w: CGFloat = ch.isASCII ? 1.0 : 2.0
                if width + w > maxHalfWidthUnits {
                    return result + "…"
                }
                width += w
                result.append(ch)
            }
            return result
        }()

        // セクターの放射方向幅（midRから近似）
        let sectorWidth = midR * (isParent ? 0.55 : 0.4)

        // テキスト位置
        let cgMid = (180.0 - Double(displayAngle)) * .pi / 180
        let textX = center.x + midR * CGFloat(cos(cgMid))
        let textY = center.y + midR * CGFloat(sin(cgMid))

        Text(displayName)
            .font(.system(
                size: maxFontSize,
                weight: isSelected ? .bold : .semibold,
                design: .rounded
            ))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: sectorWidth)
            .foregroundColor(textColor)
            .shadow(color: isSelected && !isNoneTag ? .black.opacity(0.4) : .clear, radius: 1.5, x: -1, y: 1)
            .rotationEffect(.degrees(-Double(displayAngle)))
            .position(x: textX, y: textY)
    }

    // テキスト色: タグなしは薄グレー、それ以外は背景色の明度で判定
    private func textColorFor(
        option: (id: String, name: String, color: Color)
    ) -> Color {
        if option.id == "none" { return Color(white: 0.55) }
        return .black
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
        // ドラッグ中・settling中はタップスナップを無視
        if parentIsDragging || childIsDragging { return }
        if isChild && childSettling { return }
        if !isChild && parentSettling { return }
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
        // ドラッグ中・snapTimer動作中・settling中は外部syncを拒否
        guard !parentIsDragging, !parentSettling, snapTimer == nil else {
            return
        }
        let targetID = parentSelectedID?.uuidString ?? "none"
        if let index = parentOptions.firstIndex(where: { $0.id == targetID }) {
            let target = CGFloat(index) * itemAngle
            // 既に正しい回転角度にいるなら何もしない
            guard abs(parentRotation - target) > 0.5 else { return }
            withAnimation(.easeOut(duration: 0.2)) { parentRotation = target }
            parentDragStart = target
        }
    }

    private func syncChildRotation() {
        // ドラッグ中・snapTimer動作中・settling中は外部syncを拒否
        guard !childIsDragging, !childSettling, snapTimer == nil else {
            return
        }
        let targetID = childSelectedID?.uuidString ?? "none"
        if let index = childOptions.firstIndex(where: { $0.id == targetID }) {
            let target = CGFloat(index) * itemAngle
            // 既に正しい回転角度にいるなら何もしない
            guard abs(childRotation - target) > 0.5 else { return }
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
