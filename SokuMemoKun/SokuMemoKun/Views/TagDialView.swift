import SwiftUI
import SwiftData

// 入力欄の右に張り付くカラフルなジョグダイヤル
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

    private let dialRadius: CGFloat = 60

    @State private var dragAngle: Double = 0
    @State private var baseAngle: Double = 0

    var body: some View {
        let optionCount = options.count
        let anglePerItem = 360.0 / Double(max(optionCount, 1))

        GeometryReader { geo in
            ZStack {
                // ダイヤル本体
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
                            .opacity(0.2)
                    )
                    .overlay(
                        ForEach(Array(options.enumerated()), id: \.offset) { i, option in
                            let angle = Double(i) * anglePerItem + dragAngle + baseAngle
                            let rad = angle * .pi / 180

                            // 文字は常に読める向き（回転させない）
                            Text(option.name)
                                .font(.system(size: 8, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                                .offset(
                                    x: cos(rad) * (dialRadius - 20),
                                    y: sin(rad) * (dialRadius - 20)
                                )

                            Circle()
                                .fill(option.color)
                                .frame(width: 8)
                                .overlay(Circle().stroke(.white, lineWidth: 1))
                                .offset(
                                    x: cos(rad) * (dialRadius - 6),
                                    y: sin(rad) * (dialRadius - 6)
                                )
                        }
                    )

                // 選択インジケータ
                Triangle()
                    .fill(.primary)
                    .frame(width: 6, height: 10)
                    .offset(x: -(dialRadius + 2))
            }
            // ちょうど半円が見える位置
            .position(x: geo.size.width + dialRadius - 45, y: geo.size.height / 2)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // 上スワイプ→上に回転（符号反転）
                        dragAngle = -value.translation.height * 0.6
                    }
                    .onEnded { value in
                        baseAngle += dragAngle
                        dragAngle = 0

                        let totalAngle = baseAngle.truncatingRemainder(dividingBy: 360)
                        let normalized = totalAngle < 0 ? totalAngle + 360 : totalAngle
                        let snappedIndex = Int(round(normalized / anglePerItem)) % optionCount
                        let actualIndex = (optionCount - snappedIndex) % optionCount

                        withAnimation(.easeOut(duration: 0.2)) {
                            baseAngle = -Double(snappedIndex) * anglePerItem
                        }

                        if actualIndex < options.count {
                            let option = options[actualIndex]
                            selectedTagID = option.id == "none" ? nil : UUID(uuidString: option.id)
                        }
                    }
            )
        }
    }
}

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
