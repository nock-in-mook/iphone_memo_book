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

// カード用タイトルタブ形状
// 左端は直角（カードの左辺と一直線）、右端だけ斜め＋角丸カーブ
struct CardTitleTabShape: Shape {
    func path(in rect: CGRect) -> Path {
        let inset: CGFloat = 10  // 右側の斜め量
        let r: CGFloat = 7      // 右上の角丸半径
        let br: CGFloat = 9     // 右下の付け根の逆カーブ半径
        let tlr: CGFloat = 5    // 左上の角丸半径

        // 四隅の座標
        let topLeft = CGPoint(x: 0, y: 0)
        let topRight = CGPoint(x: rect.maxX - inset, y: 0)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
        let bottomLeft = CGPoint(x: 0, y: rect.maxY)

        // 右側の付け根カーブ用延長点
        let extRight = CGPoint(x: rect.maxX + br, y: rect.maxY)

        var path = Path()

        // 左下から開始（直角）
        path.move(to: bottomLeft)

        // 左辺を上に（直線）
        path.addLine(to: CGPoint(x: 0, y: tlr))

        // 左上（小さい角丸）
        path.addArc(tangent1End: topLeft, tangent2End: topRight, radius: tlr)

        // 上辺を右へ → 右上（角丸）
        path.addArc(tangent1End: topRight, tangent2End: bottomRight, radius: r)

        // 右の斜め線 → 付け根の逆カーブで外側へ
        path.addArc(tangent1End: bottomRight, tangent2End: extRight, radius: br)

        path.addLine(to: extRight)

        // 底辺を左へ戻る
        path.addLine(to: bottomLeft)
        path.closeSubpath()

        return path
    }
}

// タブ＋カード本体を1つの連続パスで描く形状
// タブとカードの縁取りが途切れず完璧に繋がる
struct CardWithTabShape: Shape {
    var tabRatio: CGFloat = 0.68
    var tabHeight: CGFloat = 34
    var cornerRadius: CGFloat = 14
    var tabInset: CGFloat = 10   // タブ右端の斜め量
    var tabCornerRadius: CGFloat = 7  // タブ右上の角丸
    var tabCurveRadius: CGFloat = 9   // タブ右下の付け根カーブ
    var tabTopCornerRadius: CGFloat = 5 // タブ左上の角丸

    func path(in rect: CGRect) -> Path {
        let r = cornerRadius
        let tabW = rect.width * tabRatio
        let tabTop: CGFloat = 0
        let tabBottom = tabHeight - 2  // タブとカード本体の接合ライン

        // タブの右側の座標
        let tabTopRight = CGPoint(x: tabW - tabInset, y: tabTop)
        let tabBottomRight = CGPoint(x: tabW, y: tabBottom)
        let tabCurveEnd = CGPoint(x: tabW + tabCurveRadius, y: tabBottom)

        var path = Path()

        // ① 左下（角丸）から開始
        path.move(to: CGPoint(x: 0, y: rect.maxY - r))

        // 左辺を上へ → タブ左上まで直線
        path.addLine(to: CGPoint(x: 0, y: tabTop + tabTopCornerRadius))

        // ② タブ左上（小さい角丸）
        path.addArc(tangent1End: CGPoint(x: 0, y: tabTop),
                     tangent2End: CGPoint(x: tabTopCornerRadius, y: tabTop),
                     radius: tabTopCornerRadius)

        // ③ タブ上辺 → タブ右上（角丸）
        path.addArc(tangent1End: tabTopRight,
                     tangent2End: tabBottomRight,
                     radius: tabCornerRadius)

        // ④ タブ右の斜め線 → 付け根の逆カーブ
        path.addArc(tangent1End: tabBottomRight,
                     tangent2End: tabCurveEnd,
                     radius: tabCurveRadius)

        // ⑤ カード上辺を右へ → 右上角丸
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: tabBottom),
                     tangent2End: CGPoint(x: rect.maxX, y: tabBottom + r),
                     radius: r)

        // ⑥ 右辺を下へ → 右下角丸
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
                     tangent2End: CGPoint(x: rect.maxX - r, y: rect.maxY),
                     radius: r)

        // ⑦ 底辺を左へ → 左下角丸
        path.addArc(tangent1End: CGPoint(x: 0, y: rect.maxY),
                     tangent2End: CGPoint(x: 0, y: rect.maxY - r),
                     radius: r)

        path.closeSubpath()
        return path
    }
}
