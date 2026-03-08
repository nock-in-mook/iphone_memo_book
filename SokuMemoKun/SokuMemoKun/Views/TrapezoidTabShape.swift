import SwiftUI

// 角丸台形タブの形状（ファイルのインデックスタブ風）
struct TrapezoidTabShape: Shape {
    func path(in rect: CGRect) -> Path {
        let inset: CGFloat = 6   // 台形の傾き量
        let radius: CGFloat = 8  // 角丸の半径

        var path = Path()
        // 左下から時計回り
        path.move(to: CGPoint(x: 0, y: rect.maxY))
        // 左上（角丸）
        path.addLine(to: CGPoint(x: inset, y: radius))
        path.addQuadCurve(
            to: CGPoint(x: inset + radius, y: 0),
            control: CGPoint(x: inset, y: 0)
        )
        // 右上（角丸）
        path.addLine(to: CGPoint(x: rect.maxX - inset - radius, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - inset, y: radius),
            control: CGPoint(x: rect.maxX - inset, y: 0)
        )
        // 右下
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
