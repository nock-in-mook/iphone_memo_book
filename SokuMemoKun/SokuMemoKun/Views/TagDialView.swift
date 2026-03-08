import SwiftUI
import SwiftData

// 画面右端に張り付くカラフルなジョグダイヤル
struct TagDialView: View {
    @Query(sort: \Tag.name) private var tags: [Tag]
    @Binding var selectedTagID: UUID?

    // 「タグ無し」+ 全タグ
    private var options: [(id: String, name: String, color: Color)] {
        var list: [(String, String, Color)] = [("none", "なし", tagColor(for: 0))]
        for (i, tag) in tags.enumerated() {
            list.append((tag.id.uuidString, tag.name, tagColor(for: i + 1)))
        }
        return list
    }

    private var selectedIndex: Int {
        if let id = selectedTagID {
            return options.firstIndex(where: { $0.id == id.uuidString }) ?? 0
        }
        return 0
    }

    // ダイヤルの設定
    private let dialRadius: CGFloat = 80
    private let itemCount = 360.0 // ドラッグ感度用

    @State private var dragAngle: Double = 0
    @State private var baseAngle: Double = 0

    var body: some View {
        let optionCount = options.count
        let anglePerItem = 360.0 / Double(max(optionCount, 1))

        GeometryReader { geo in
            ZStack {
                // 半円ダイヤル本体（画面右端にはみ出す）
                Circle()
                    .fill(
                        AngularGradient(
                            colors: options.map { $0.color } + [options.first?.color ?? .gray],
                            center: .center
                        )
                    )
                    .frame(width: dialRadius * 2, height: dialRadius * 2)
                    .overlay(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .opacity(0.3)
                    )
                    .overlay(
                        // 目盛り線と色セグメント
                        ForEach(Array(options.enumerated()), id: \.offset) { i, option in
                            let angle = Double(i) * anglePerItem + dragAngle + baseAngle
                            let rad = angle * .pi / 180

                            // タグ名ラベル（左側に表示される部分だけ）
                            Text(option.name)
                                .font(.system(size: 9, weight: i == selectedIndex ? .bold : .regular, design: .rounded))
                                .foregroundStyle(i == selectedIndex ? .primary : .secondary)
                                .offset(
                                    x: cos(rad) * (dialRadius - 22),
                                    y: sin(rad) * (dialRadius - 22)
                                )
                                .rotationEffect(.degrees(angle + 90))

                            // 色付きドット
                            Circle()
                                .fill(option.color)
                                .frame(width: i == selectedIndex ? 10 : 6)
                                .overlay(
                                    Circle()
                                        .stroke(.white, lineWidth: 1)
                                )
                                .offset(
                                    x: cos(rad) * (dialRadius - 8),
                                    y: sin(rad) * (dialRadius - 8)
                                )
                        }
                    )
                    .rotationEffect(.degrees(0))

                // 選択インジケータ（左端中央の三角矢印）
                Triangle()
                    .fill(.primary)
                    .frame(width: 8, height: 12)
                    .offset(x: -(dialRadius + 4))
            }
            .position(x: geo.size.width + dialRadius - 30, y: geo.size.height / 2)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // 上下ドラッグで回転
                        let delta = value.translation.height
                        dragAngle = delta * 0.5
                    }
                    .onEnded { value in
                        baseAngle += dragAngle
                        dragAngle = 0

                        // 最も近いアイテムにスナップ
                        let totalAngle = baseAngle.truncatingRemainder(dividingBy: 360)
                        let normalized = totalAngle < 0 ? totalAngle + 360 : totalAngle
                        let snappedIndex = Int(round(normalized / anglePerItem)) % optionCount
                        let actualIndex = (optionCount - snappedIndex) % optionCount

                        withAnimation(.easeOut(duration: 0.2)) {
                            baseAngle = -Double(snappedIndex) * anglePerItem
                        }

                        if actualIndex < options.count {
                            let option = options[actualIndex]
                            if option.id == "none" {
                                selectedTagID = nil
                            } else {
                                selectedTagID = UUID(uuidString: option.id)
                            }
                        }
                    }
            )
        }
        .frame(width: 60)
    }
}

// 三角形（選択インジケータ用）
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
