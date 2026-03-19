import SwiftUI

// ベース色からRGB/HSB成分を取得するヘルパー
private extension Color {
    var components: (r: CGFloat, g: CGFloat, b: CGFloat) {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }

    var hsb: (h: CGFloat, s: CGFloat, b: CGFloat) {
        let uiColor = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (h, s, b)
    }

    // 明度に基づいてテキスト色を決める
    var isLight: Bool {
        let c = components
        let luminance = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
        return luminance > 0.6
    }
}

// 配色パターン定義
struct ColorPattern: Identifiable {
    let id: String
    let name: String
    let description: String
    let generate: (Color) -> (left: Color, right: Color)
}

// 配色パターン一覧（全て不透明ベース）
private let colorPatterns: [ColorPattern] = [
    // 1. 濃淡（左を少し暗く、右はそのまま）
    ColorPattern(
        id: "dark_light",
        name: "濃淡",
        description: "左を濃く、右はベースそのまま",
        generate: { base in
            let c = base.components
            let left = Color(red: c.r * 0.78, green: c.g * 0.78, blue: c.b * 0.78)
            let right = Color(red: c.r * 0.92, green: c.g * 0.92, blue: c.b * 0.92)
            return (left, right)
        }
    ),
    // 2. 濃淡（逆）
    ColorPattern(
        id: "light_dark",
        name: "濃淡（逆）",
        description: "左が明るく、右が濃い",
        generate: { base in
            let c = base.components
            let left = Color(red: c.r * 0.92, green: c.g * 0.92, blue: c.b * 0.92)
            let right = Color(red: c.r * 0.78, green: c.g * 0.78, blue: c.b * 0.78)
            return (left, right)
        }
    ),
    // 3. 彩度差（左が鮮やか、右がくすみ）
    ColorPattern(
        id: "vivid_muted",
        name: "鮮やか↔くすみ",
        description: "左が鮮やか、右はグレー寄り",
        generate: { base in
            let hsb = base.hsb
            let left = Color(hue: hsb.h, saturation: min(hsb.s * 1.3, 1), brightness: hsb.b * 0.88)
            let right = Color(hue: hsb.h, saturation: hsb.s * 0.4, brightness: hsb.b * 0.95)
            return (left, right)
        }
    ),
    // 4. 白ミックス（左にベース色、右に白を混ぜる）
    ColorPattern(
        id: "base_white",
        name: "ベース＋ホワイト",
        description: "左はベース色、右は白を混ぜて明るく",
        generate: { base in
            let c = base.components
            let left = Color(red: c.r * 0.82, green: c.g * 0.82, blue: c.b * 0.82)
            let right = Color(red: c.r * 0.5 + 0.5, green: c.g * 0.5 + 0.5, blue: c.b * 0.5 + 0.5)
            return (left, right)
        }
    ),
    // 5. 色相ずらし+15°
    ColorPattern(
        id: "hue_15",
        name: "色相+15°",
        description: "左はベース、右を色相15°ずらし",
        generate: { base in
            let hsb = base.hsb
            let left = Color(hue: hsb.h, saturation: hsb.s * 0.8, brightness: hsb.b * 0.88)
            let rightH = (hsb.h + 0.042).truncatingRemainder(dividingBy: 1.0)
            let right = Color(hue: rightH, saturation: hsb.s * 0.8, brightness: hsb.b * 0.88)
            return (left, right)
        }
    ),
    // 6. 色相ずらし-15°
    ColorPattern(
        id: "hue_minus15",
        name: "色相-15°",
        description: "左はベース、右を色相-15°ずらし",
        generate: { base in
            let hsb = base.hsb
            let left = Color(hue: hsb.h, saturation: hsb.s * 0.8, brightness: hsb.b * 0.88)
            let rightH = (hsb.h - 0.042 + 1.0).truncatingRemainder(dividingBy: 1.0)
            let right = Color(hue: rightH, saturation: hsb.s * 0.8, brightness: hsb.b * 0.88)
            return (left, right)
        }
    ),
    // 7. 暖寒（不透明版）
    ColorPattern(
        id: "warm_cool_solid",
        name: "暖↔寒",
        description: "左に暖色、右に寒色を加える",
        generate: { base in
            let c = base.components
            let left = Color(red: min(c.r * 0.9 + 0.1, 1), green: c.g * 0.85, blue: c.b * 0.75)
            let right = Color(red: c.r * 0.75, green: c.g * 0.85, blue: min(c.b * 0.9 + 0.1, 1))
            return (left, right)
        }
    ),
    // 8. 明度段差（大きめの差）
    ColorPattern(
        id: "brightness_step",
        name: "明度段差",
        description: "左を暗め、右を明るめ（大きな差）",
        generate: { base in
            let hsb = base.hsb
            let left = Color(hue: hsb.h, saturation: hsb.s * 0.9, brightness: hsb.b * 0.72)
            let right = Color(hue: hsb.h, saturation: hsb.s * 0.6, brightness: min(hsb.b * 1.05, 1))
            return (left, right)
        }
    ),
    // 9. 同色＋枠だけ差（背景は同じ、枠線色で差をつけるイメージ）
    ColorPattern(
        id: "same_border",
        name: "同色（枠で差）",
        description: "背景は同色、境界線で左右を区別",
        generate: { base in
            let c = base.components
            let color = Color(red: c.r * 0.88, green: c.g * 0.88, blue: c.b * 0.88)
            return (color, color)
        }
    ),
    // 10. テクスチャ差（彩度の微差）
    ColorPattern(
        id: "subtle_sat",
        name: "微彩度差",
        description: "左の彩度をやや上げ、右をやや下げ",
        generate: { base in
            let hsb = base.hsb
            let left = Color(hue: hsb.h, saturation: min(hsb.s * 1.1, 1), brightness: hsb.b * 0.87)
            let right = Color(hue: hsb.h, saturation: hsb.s * 0.7, brightness: hsb.b * 0.9)
            return (left, right)
        }
    ),
    // 11. パステル＋ダーク
    ColorPattern(
        id: "pastel_dark",
        name: "パステル＋ダーク",
        description: "左をパステル、右をダークトーンに",
        generate: { base in
            let hsb = base.hsb
            let left = Color(hue: hsb.h, saturation: hsb.s * 0.5, brightness: min(hsb.b * 1.05, 1))
            let right = Color(hue: hsb.h, saturation: hsb.s * 0.9, brightness: hsb.b * 0.7)
            return (left, right)
        }
    ),
    // 12. 補色ミックス
    ColorPattern(
        id: "complement_mix",
        name: "補色ミックス",
        description: "右に補色を少しだけ混ぜる",
        generate: { base in
            let c = base.components
            let left = Color(red: c.r * 0.85, green: c.g * 0.85, blue: c.b * 0.85)
            // 補色成分を20%だけ混ぜる
            let compR = 1.0 - c.r, compG = 1.0 - c.g, compB = 1.0 - c.b
            let right = Color(
                red: (c.r * 0.8 + compR * 0.2) * 0.88,
                green: (c.g * 0.8 + compG * 0.2) * 0.88,
                blue: (c.b * 0.8 + compB * 0.2) * 0.88
            )
            return (left, right)
        }
    ),
]

// サンプルに使うベース色
private let sampleBaseColors: [(name: String, color: Color)] = [
    ("水色", Color(red: 0.55, green: 0.80, blue: 0.95)),
    ("オレンジ", Color(red: 0.95, green: 0.70, blue: 0.55)),
    ("緑", Color(red: 0.70, green: 0.90, blue: 0.70)),
    ("紫", Color(red: 0.90, green: 0.70, blue: 0.90)),
    ("赤", Color(red: 0.95, green: 0.60, blue: 0.60)),
    ("ティール", Color(red: 0.35, green: 0.65, blue: 0.80)),
    ("ゴールド", Color(red: 0.90, green: 0.80, blue: 0.50)),
    ("ローズ", Color(red: 0.85, green: 0.45, blue: 0.55)),
    ("ネイビー", Color(red: 0.28, green: 0.45, blue: 0.60)),
    ("ダークフォレスト", Color(red: 0.30, green: 0.50, blue: 0.38)),
]

// MARK: - カラーラボ メイン画面

struct ColorLabView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("「よく見る」タブの左右列配色パターン\n全て不透明・ベース色自動計算")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                ForEach(colorPatterns) { pattern in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(pattern.name)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                            Spacer()
                            Text(pattern.description)
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(sampleBaseColors, id: \.name) { sample in
                                    colorSampleCard(
                                        baseName: sample.name,
                                        baseColor: sample.color,
                                        pattern: pattern
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
            }
            .padding(.bottom, 30)
        }
        .navigationTitle("カラーラボ")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func colorSampleCard(baseName: String, baseColor: Color, pattern: ColorPattern) -> some View {
        let colors = pattern.generate(baseColor)
        return VStack(spacing: 4) {
            // タブ（ベース色）
            Text(baseName)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(baseColor.isLight ? Color.primary : Color.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(baseColor)
                )

            // 左右分割プレビュー（背景色付き）
            HStack(spacing: 2) {
                // 左列
                VStack(spacing: 3) {
                    Text("よく見る")
                        .font(.system(size: 7, weight: .semibold, design: .rounded))
                        .foregroundColor(colors.left.isLight ? .secondary : Color.white.opacity(0.8))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(uiColor: .systemBackground))
                        .frame(height: 16)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(uiColor: .systemBackground))
                        .frame(height: 16)
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(colors.left)
                )

                // 右列
                VStack(spacing: 3) {
                    Text("最近見た")
                        .font(.system(size: 7, weight: .semibold, design: .rounded))
                        .foregroundColor(colors.right.isLight ? .secondary : Color.white.opacity(0.8))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(uiColor: .systemBackground))
                        .frame(height: 16)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(uiColor: .systemBackground))
                        .frame(height: 16)
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(colors.right)
                )
            }
            .frame(width: 110, height: 65)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(baseColor)
            )
        }
    }
}
