import SwiftUI
import SwiftData

// カジノルーレット風タグ選択（巨大な円の左端の弧だけ見える）
// Canvas1本で描画。rotation値から直接全て計算し、ワープを防ぐ。
// 親ダイアル・子ダイアル両方で再利用可能。
struct TagDialView: View {
    // 外部から渡されるオプションリスト（末尾に "add" を含められる）
    var options: [(id: String, name: String, color: Color)]
    @Binding var selectedID: UUID?
    // ダイアルの幅（親子並列表示時に狭める）
    var width: CGFloat = 100
    // 「＋タグ追加」がセンターに来た時のコールバック
    var onAddTap: (() -> Void)?
    // 外部ドラッグ入力（「子」タブからの引き出しドラッグ用）
    // nil=外部ドラッグなし、値あり=外部からの垂直移動量
    @Binding var externalDragY: CGFloat?

    // 円の半径
    private let wheelRadius: CGFloat = 300
    // セクターの厚み（右方向に広め）
    private let sectorThickness: CGFloat = 82
    // 各タグ間の角度（度）
    private let itemAngle: CGFloat = 8
    // ダイヤルの高さ
    private let dialHeight: CGFloat = 160

    // rotation: 上にスワイプ→正、下にスワイプ→負
    // rotation=0 → index 0 がセンター
    // rotation=itemAngle → index 1 がセンター
    @State private var rotation: CGFloat = 0
    @State private var dragStart: CGFloat = 0
    @State private var isDragging = false
    // 内部操作（ドラッグ/updateSelection）による変更を区別するフラグ
    @State private var isInternalChange = false

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
            let midR = (innerR + outerR) / 2

            guard count > 0 else { return }

            for slotOffset in -8...8 {
                let baseIndex = Int(floor(rot / itemAngle + 0.5))
                let rawIndex = baseIndex + slotOffset
                let index = ((rawIndex % count) + count) % count
                guard index < opts.count else { continue }

                let displayAngle = CGFloat(rawIndex) * itemAngle - rot

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

                // 仕切り線
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

                // テキスト
                let cgMid = (180.0 - Double(displayAngle)) * .pi / 180
                let textX = cx + midR * cos(cgMid)
                let textY = cy + midR * sin(cgMid)

                if option.id == "add" {
                    // 「＋タグ追加」特別描画
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
                    // 通常タグ描画
                    let maxChars = width < 80 ? 3 : 5
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
        .frame(width: width, height: dialHeight)
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    rotation = dragStart + value.translation.height * -0.3
                }
                .onEnded { _ in
                    let snapped = round(rotation / itemAngle) * itemAngle
                    withAnimation(.easeOut(duration: 0.15)) {
                        rotation = snapped
                    }
                    dragStart = snapped
                    isInternalChange = true
                    updateSelection()
                    isDragging = false
                }
        )
        .onAppear {
            syncRotationToSelection()
        }
        // 外部ドラッグ入力を回転に反映
        .onChange(of: externalDragY) { _, newValue in
            if let dragY = newValue {
                // ドラッグ中: 垂直移動量を回転に変換
                isDragging = true
                rotation = dragStart + dragY * -0.3
            } else if isDragging {
                // ドラッグ終了: スナップして選択更新
                let snapped = round(rotation / itemAngle) * itemAngle
                withAnimation(.easeOut(duration: 0.15)) {
                    rotation = snapped
                }
                dragStart = snapped
                isInternalChange = true
                updateSelection()
                isDragging = false
            }
        }
        // 外部からselectedIDが変わった時にルーレット位置を同期
        .onChange(of: selectedID) { _, _ in
            if isInternalChange {
                // ドラッグ操作による変更 → 同期不要
                isInternalChange = false
            } else {
                // 外部からの変更（新タグ追加等）→ ルーレット位置を同期
                syncRotationToSelection()
            }
        }
    }

    // selectedIDに対応するoptionsのインデックスにrotationを合わせる
    private func syncRotationToSelection() {
        let targetID: String = {
            if let id = selectedID { return id.uuidString }
            return "none"
        }()
        if let index = options.firstIndex(where: { $0.id == targetID }) {
            let target = CGFloat(index) * itemAngle
            withAnimation(.easeOut(duration: 0.2)) {
                rotation = target
            }
            dragStart = target
        }
    }

    private func updateSelection() {
        let index = snappedIndex
        if index < options.count {
            let option = options[index]
            if option.id == "add" {
                // 「＋タグ追加」→ そのままの位置を維持してコールバック
                onAddTap?()
            } else {
                selectedID = option.id == "none" ? nil : UUID(uuidString: option.id)
            }
        }
    }
}
