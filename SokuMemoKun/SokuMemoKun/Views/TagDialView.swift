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

    // 長押しコールバック（isChild: 子タグか, id: タグID）
    var onLongPress: ((_ isChild: Bool, _ id: String) -> Void)?

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

        ZStack {
            // --- 親セクターリング ---
            sectorRing(
                center: center, outerR: parentOuterR, innerR: parentInnerR,
                options: parentOptions, rotation: parentRotation,
                maxChars: 10, isChild: false
            )

            // --- 子セクターリング ---
            if showChild && !childOptions.isEmpty {
                sectorRing(
                    center: center, outerR: childOuterR, innerR: childInnerR,
                    options: childOptions, rotation: childRotation,
                    maxChars: 7, isChild: true
                )
            }

            // --- 縁取り ---
            edgeArcView(center: center, radius: parentOuterR,
                        lineWidth: 3, brightness: (0.35, 0.5, 0.35))
            edgeArcView(center: center, radius: parentInnerR,
                        lineWidth: 1.5, brightness: (0.3, 0.45, 0.3))
            if showChild {
                edgeArcView(center: center, radius: childInnerR,
                            lineWidth: 1.5, brightness: (0.3, 0.45, 0.3))
            }

            // --- 選択ポインター（赤い三角） ---
            pointerView(cy: cy)

            // --- インナーシャドウ ---
            innerShadowOverlay()
        }
        .frame(width: canvasWidth, height: dialHeight)
        .clipped()
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
                // 長押しでコンテキストメニュー（新機能: タグなし以外）
                .if(!isNone) { view in
                    view.contextMenu {
                        Button {
                            onLongPress?(isChild, option.id)
                        } label: {
                            Label("編集・削除", systemImage: "pencil")
                        }
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

    private func snapToTag(index: Int, isChild: Bool) {
        let target = CGFloat(index) * itemAngle
        if isChild {
            withAnimation(.spring(response: 0.3)) { childRotation = target }
            childDragStart = target
            childIsInternalChange = true
            updateChildSelection()
        } else {
            withAnimation(.spring(response: 0.3)) { parentRotation = target }
            parentDragStart = target
            parentIsInternalChange = true
            updateParentSelection()
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
