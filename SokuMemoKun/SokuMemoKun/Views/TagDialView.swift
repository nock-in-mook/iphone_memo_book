import SwiftUI
import SwiftData

// カジノルーレット風タグ選択（巨大な円の右端の弧だけ見える）
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

    // 巨大な円の半径（画面外に中心がある）
    private let wheelRadius: CGFloat = 300
    // 各タグ間の角度（度）
    private let itemAngle: CGFloat = 12

    @State private var rotation: CGFloat = 0
    @State private var dragStart: CGFloat = 0

    private var currentIndex: Int {
        let count = options.count
        guard count > 0 else { return 0 }
        let raw = Int(round(rotation / itemAngle))
        return ((raw % count) + count) % count
    }

    var body: some View {
        let count = options.count

        GeometryReader { geo in
            ZStack {
                // 巨大な円（中心は左の画面外）
                // 弧の部分だけ描画
                ForEach(-3...3, id: \.self) { offset in
                    let index = ((currentIndex - offset) % count + count) % count
                    if index < options.count {
                        let option = options[index]
                        let angle = CGFloat(offset) * itemAngle
                            - (rotation - CGFloat(currentIndex) * itemAngle)
                        let rad = angle * .pi / 180
                        let x = wheelRadius * cos(rad) - wheelRadius + geo.size.width
                        let y = geo.size.height / 2 - wheelRadius * sin(rad)
                        let dist = abs(angle)
                        let maxDist = itemAngle * 3
                        let fade = max(0, 1 - dist / maxDist)
                        let scale = 0.6 + fade * 0.4

                        RoundedRectangle(cornerRadius: 4)
                            .fill(option.color.opacity(0.3 + fade * 0.5))
                            .frame(width: geo.size.width - 8, height: 22 * scale)
                            .overlay(alignment: .leading) {
                                HStack(spacing: 4) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(option.color)
                                        .frame(width: 4, height: 16 * scale)
                                    Text(option.name)
                                        .font(.system(
                                            size: 11 * scale,
                                            weight: dist < itemAngle / 2 ? .bold : .regular,
                                            design: .rounded
                                        ))
                                        .lineLimit(1)
                                }
                                .padding(.leading, 4)
                            }
                            .rotationEffect(.degrees(-angle * 0.3), anchor: .leading)
                            .position(x: x, y: y)
                            .opacity(Double(fade))
                    }
                }

                // 選択インジケータ
                HStack {
                    Image(systemName: "arrowtriangle.right.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(Color.accentColor)
                    Spacer()
                }
                .padding(.leading, 2)

                // 弧の縁（装飾）
                ArcEdge(radius: wheelRadius, viewWidth: geo.size.width)
                    .stroke(.gray.opacity(0.2), lineWidth: 1)
            }
        }
        .frame(width: 58)
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    rotation = dragStart - value.translation.height * 0.15
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
        let index = currentIndex
        if index < options.count {
            let option = options[index]
            selectedTagID = option.id == "none" ? nil : UUID(uuidString: option.id)
        }
    }
}

// 弧の縁線（装飾用）
struct ArcEdge: Shape {
    let radius: CGFloat
    let viewWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centerX = -radius + viewWidth
        let centerY = rect.midY
        path.addArc(
            center: CGPoint(x: centerX, y: centerY),
            radius: radius,
            startAngle: .degrees(-30),
            endAngle: .degrees(30),
            clockwise: false
        )
        return path
    }
}
