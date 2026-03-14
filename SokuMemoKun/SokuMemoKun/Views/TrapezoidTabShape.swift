import SwiftUI

// 角丸台形タブの形状（ファイルのインデックスタブ風）
// 上部: 丸い角、下部の付け根: 逆カーブ（肩のようなスムーズな凹み）
struct TrapezoidTabShape: Shape {
    func path(in rect: CGRect) -> Path {
        let inset: CGFloat = 6   // 台形の傾き量（小さめ→長方形寄り）
        let r: CGFloat = 7      // 上部の角丸半径
        let br: CGFloat = 9     // 付け根の逆カーブ半径

        // 台形の四隅
        let topLeft = CGPoint(x: inset, y: 0)
        let topRight = CGPoint(x: rect.maxX - inset, y: 0)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
        let bottomLeft = CGPoint(x: 0, y: rect.maxY)

        // 付け根のカーブ用の延長点（底辺の外側）
        let extLeft = CGPoint(x: -br, y: rect.maxY)
        let extRight = CGPoint(x: rect.maxX + br, y: rect.maxY)

        var path = Path()

        // 左の付け根: 外側から逆カーブで斜め線へ
        path.move(to: extLeft)
        path.addArc(tangent1End: bottomLeft, tangent2End: topLeft, radius: br)

        // 左上（角丸）
        path.addArc(tangent1End: topLeft, tangent2End: topRight, radius: r)

        // 右上（角丸）
        path.addArc(tangent1End: topRight, tangent2End: bottomRight, radius: r)

        // 右の付け根: 斜め線から逆カーブで外側へ
        path.addArc(tangent1End: bottomRight, tangent2End: extRight, radius: br)

        path.addLine(to: extRight)
        path.closeSubpath()

        return path
    }
}
