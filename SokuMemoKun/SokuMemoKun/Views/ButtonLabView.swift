import SwiftUI

// 押せるボタン用のButtonStyle（長押し対応）
struct PressableButtonStyle: ButtonStyle {
    let shadowHeight: CGFloat
    let shadowColor: Color
    let radius: CGFloat

    init(shadowHeight: CGFloat = 5, shadowColor: Color = .black.opacity(0.25), radius: CGFloat = 1) {
        self.shadowHeight = shadowHeight
        self.shadowColor = shadowColor
        self.radius = radius
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? shadowHeight : 0)
            .shadow(
                color: configuration.isPressed ? .clear : shadowColor,
                radius: radius,
                y: configuration.isPressed ? 0 : shadowHeight
            )
            .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
    }
}

// タップでもカチッと動くボタン（沈む→待つ→戻る）
struct TapPressableView<Label: View>: View {
    let shadowHeight: CGFloat
    let shadowColor: Color
    let radius: CGFloat
    let action: () -> Void
    let label: () -> Label

    @State private var isPressed = false

    init(
        shadowHeight: CGFloat = 5,
        shadowColor: Color = .black.opacity(0.25),
        radius: CGFloat = 1,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.shadowHeight = shadowHeight
        self.shadowColor = shadowColor
        self.radius = radius
        self.action = action
        self.label = label
    }

    var body: some View {
        label()
            .offset(y: isPressed ? shadowHeight : 0)
            .shadow(
                color: isPressed ? .clear : shadowColor,
                radius: radius,
                y: isPressed ? 0 : shadowHeight
            )
            .onTapGesture {
                // カチッと沈む
                withAnimation(.easeIn(duration: 0.035)) { isPressed = true }
                // 少し待ってから戻る
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                    withAnimation(.easeOut(duration: 0.05)) { isPressed = false }
                    action()
                }
            }
            // 長押し対応
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.15)
                    .onChanged { _ in
                        withAnimation(.easeIn(duration: 0.06)) { isPressed = true }
                    }
                    .onEnded { _ in
                        withAnimation(.easeOut(duration: 0.08)) { isPressed = false }
                        action()
                    }
            )
    }
}

// ボタンデザインラボ: 爆速モード用ボタンの候補一覧
struct ButtonLabView: View {
    var body: some View {
        ScrollView {
            // ── 押せるボタン（インタラクティブ）──
            VStack(spacing: 8) {
                Text("押せるボタン")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("実際にタップして押し心地を確認！")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 24) {
                ForEach(0..<pressableButtons.count, id: \.self) { i in
                    VStack(spacing: 6) {
                        Text("P\(i + 1)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                        pressableButtons[i]
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)

            Divider().padding(.horizontal, 16)

            // ── 静的パターン ──
            VStack(spacing: 8) {
                Text("静的デザイン")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                ForEach(0..<buttonStyles.count, id: \.self) { i in
                    VStack(spacing: 6) {
                        Text("#\(i + 1)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                        buttonStyles[i]
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("ボタンデザインラボ")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 押せるボタンパターン

    private var pressableButtons: [AnyView] {
        [
            // P1: シンプル + 底影
            AnyView(
                Button {} label: {
                    Text("本文編集")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .padding(.horizontal, 18).padding(.vertical, 8)
                        .background(Capsule().fill(Color(white: 0.93)))
                }
                .buttonStyle(PressableButtonStyle(shadowHeight: 4))
            ),
            // P2: 底影 + グラデ
            AnyView(
                Button {} label: {
                    Text("本文編集")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .padding(.horizontal, 18).padding(.vertical, 8)
                        .background(
                            Capsule().fill(
                                LinearGradient(colors: [Color(white: 0.98), Color(white: 0.88)],
                                               startPoint: .top, endPoint: .bottom)
                            )
                        )
                }
                .buttonStyle(PressableButtonStyle(shadowHeight: 5))
            ),
            // P3: 底影 + ベベル
            AnyView(
                Button {} label: {
                    Text("本文編集")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .padding(.horizontal, 18).padding(.vertical, 8)
                        .background(
                            Capsule().fill(Color(white: 0.93))
                                .overlay(
                                    Capsule().strokeBorder(
                                        LinearGradient(colors: [.white.opacity(0.9), .black.opacity(0.15)],
                                                       startPoint: .top, endPoint: .bottom),
                                        lineWidth: 1.5
                                    )
                                )
                        )
                }
                .buttonStyle(PressableButtonStyle(shadowHeight: 5))
            ),
            // P4: 底バー + グラデ（記事風）
            AnyView(
                Button {} label: {
                    Text("本文編集")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .padding(.horizontal, 18).padding(.vertical, 8)
                        .background(
                            ZStack {
                                Capsule().fill(Color(white: 0.72))
                                    .offset(y: 4)
                                Capsule().fill(
                                    LinearGradient(colors: [Color(white: 0.98), Color(white: 0.90)],
                                                   startPoint: .top, endPoint: .bottom)
                                )
                            }
                        )
                }
                .buttonStyle(PressableButtonStyle(shadowHeight: 4, shadowColor: .clear))
            ),
            // P5: グロス + 押せる
            AnyView(
                Button {} label: {
                    Text("本文編集")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .padding(.horizontal, 18).padding(.vertical, 8)
                        .background(
                            ZStack {
                                Capsule().fill(Color(white: 0.86))
                                Capsule().fill(
                                    LinearGradient(colors: [.white.opacity(0.5), .clear],
                                                   startPoint: .top, endPoint: .center)
                                )
                            }
                        )
                }
                .buttonStyle(PressableButtonStyle(shadowHeight: 5, shadowColor: .black.opacity(0.3)))
            ),
            // P6: ゲームボタン（全部盛り + 押せる）
            AnyView(
                Button {} label: {
                    Text("本文編集")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .padding(.horizontal, 18).padding(.vertical, 8)
                        .background(
                            ZStack {
                                Capsule().fill(
                                    LinearGradient(colors: [Color(white: 0.97), Color(white: 0.83)],
                                                   startPoint: .top, endPoint: .bottom)
                                )
                                Capsule().fill(
                                    LinearGradient(colors: [.white.opacity(0.4), .clear],
                                                   startPoint: .top, endPoint: .center)
                                ).padding(2)
                            }
                        )
                        .overlay(
                            Capsule().strokeBorder(
                                LinearGradient(colors: [.white.opacity(0.7), Color(white: 0.6)],
                                               startPoint: .top, endPoint: .bottom),
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(PressableButtonStyle(shadowHeight: 5, shadowColor: .black.opacity(0.35)))
            ),
            // P7: 緑 押せる
            AnyView(
                Button {} label: {
                    Text("タイトル編集")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(
                            ZStack {
                                Capsule().fill(
                                    LinearGradient(colors: [Color.green.opacity(0.12), Color.green.opacity(0.28)],
                                                   startPoint: .top, endPoint: .bottom)
                                )
                                Capsule().fill(
                                    LinearGradient(colors: [.white.opacity(0.35), .clear],
                                                   startPoint: .top, endPoint: .center)
                                ).padding(2)
                            }
                        )
                        .overlay(
                            Capsule().strokeBorder(
                                LinearGradient(colors: [.white.opacity(0.6), Color.green.opacity(0.3)],
                                               startPoint: .top, endPoint: .bottom),
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(PressableButtonStyle(shadowHeight: 5, shadowColor: Color.green.opacity(0.35)))
            ),
            // P8: 青 押せる
            AnyView(
                Button {} label: {
                    Text("タグ編集")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .padding(.horizontal, 18).padding(.vertical, 8)
                        .background(
                            ZStack {
                                Capsule().fill(
                                    LinearGradient(colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.25)],
                                                   startPoint: .top, endPoint: .bottom)
                                )
                                Capsule().fill(
                                    LinearGradient(colors: [.white.opacity(0.35), .clear],
                                                   startPoint: .top, endPoint: .center)
                                ).padding(2)
                            }
                        )
                        .overlay(
                            Capsule().strokeBorder(
                                LinearGradient(colors: [.white.opacity(0.6), Color.blue.opacity(0.3)],
                                               startPoint: .top, endPoint: .bottom),
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(PressableButtonStyle(shadowHeight: 5, shadowColor: Color.blue.opacity(0.35)))
            ),
            // P9: 底バー色付き + 押せる（緑）
            AnyView(
                Button {} label: {
                    Text("タイトル編集")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(
                            ZStack {
                                Capsule().fill(Color.green.opacity(0.45)).offset(y: 4)
                                Capsule().fill(
                                    LinearGradient(colors: [Color.green.opacity(0.1), Color.green.opacity(0.25)],
                                                   startPoint: .top, endPoint: .bottom)
                                )
                            }
                        )
                }
                .buttonStyle(PressableButtonStyle(shadowHeight: 4, shadowColor: .clear))
            ),
            // P10: 底バー色付き + 押せる（青）
            AnyView(
                Button {} label: {
                    Text("タグ編集")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .padding(.horizontal, 18).padding(.vertical, 8)
                        .background(
                            ZStack {
                                Capsule().fill(Color.blue.opacity(0.4)).offset(y: 4)
                                Capsule().fill(
                                    LinearGradient(colors: [Color.blue.opacity(0.08), Color.blue.opacity(0.22)],
                                                   startPoint: .top, endPoint: .bottom)
                                )
                            }
                        )
                }
                .buttonStyle(PressableButtonStyle(shadowHeight: 4, shadowColor: .clear))
            ),
            // P11: 厚み強め（影8px）
            AnyView(
                Button {} label: {
                    Text("本文編集")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .padding(.horizontal, 18).padding(.vertical, 8)
                        .background(
                            Capsule().fill(
                                LinearGradient(colors: [Color(white: 0.98), Color(white: 0.86)],
                                               startPoint: .top, endPoint: .bottom)
                            )
                        )
                        .overlay(
                            Capsule().strokeBorder(
                                LinearGradient(colors: [.white.opacity(0.8), .black.opacity(0.1)],
                                               startPoint: .top, endPoint: .bottom),
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(PressableButtonStyle(shadowHeight: 8, shadowColor: .black.opacity(0.3)))
            ),
            // P12: 底バー厚め + グロス
            AnyView(
                Button {} label: {
                    Text("本文編集")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .padding(.horizontal, 18).padding(.vertical, 8)
                        .background(
                            ZStack {
                                Capsule().fill(Color(white: 0.65)).offset(y: 6)
                                Capsule().fill(
                                    LinearGradient(colors: [Color(white: 0.98), Color(white: 0.87)],
                                                   startPoint: .top, endPoint: .bottom)
                                )
                                Capsule().fill(
                                    LinearGradient(colors: [.white.opacity(0.5), .clear],
                                                   startPoint: .top, endPoint: .center)
                                ).padding(2)
                            }
                        )
                }
                .buttonStyle(PressableButtonStyle(shadowHeight: 6, shadowColor: .clear))
            ),
        ]
    }

    // 全パターン
    private var buttonStyles: [AnyView] {
        [
            // 1: フラット + ドロップシャドウ
            AnyView(
                Text("本文編集")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(Capsule().fill(Color(white: 0.93)))
                    .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
            ),
            // 2: 濃い影 + 大きめオフセット
            AnyView(
                Text("本文編集")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(Capsule().fill(Color(white: 0.95)))
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 3)
            ),
            // 3: ダブルシャドウ（ニューモフィズム風・白背景）
            AnyView(
                Text("本文編集")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(Capsule().fill(Color(white: 0.94)))
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 2, y: 2)
                    .shadow(color: .white.opacity(0.8), radius: 4, x: -2, y: -2)
            ),
            // 4: ニューモフィズム凸（濃いめ）
            AnyView(
                Text("本文編集")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(Capsule().fill(Color(white: 0.92)))
                    .shadow(color: .black.opacity(0.25), radius: 5, x: 3, y: 3)
                    .shadow(color: .white.opacity(0.9), radius: 5, x: -3, y: -3)
            ),
            // 5: 上ハイライト + 下シャドウ（出っ張りボタン）
            AnyView(
                Text("本文編集")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(
                        Capsule().fill(
                            LinearGradient(colors: [Color(white: 0.98), Color(white: 0.88)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
            ),
            // 6: 強めグラデーション + シャドウ
            AnyView(
                Text("本文編集")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(
                        Capsule().fill(
                            LinearGradient(colors: [Color(white: 1.0), Color(white: 0.82)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 3)
            ),
            // 7: 枠線 + グラデーション + シャドウ
            AnyView(
                Text("本文編集")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(
                        Capsule().fill(
                            LinearGradient(colors: [Color(white: 0.97), Color(white: 0.87)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                    )
                    .overlay(Capsule().stroke(Color(white: 0.75), lineWidth: 1))
                    .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
            ),
            // 8: インナーシャドウ風（overlay暗め上端）
            AnyView(
                Text("本文編集")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(
                        Capsule().fill(Color(white: 0.93))
                            .overlay(
                                Capsule().fill(
                                    LinearGradient(colors: [.black.opacity(0.08), .clear],
                                                   startPoint: .bottom, endPoint: .top)
                                )
                            )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
            ),
            // 9: ぷっくりグラデ（中央が明るい）
            AnyView(
                Text("本文編集")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(
                        Capsule().fill(
                            LinearGradient(colors: [Color(white: 0.90), Color(white: 0.97), Color(white: 0.88)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                    )
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 3)
            ),
            // 10: ぷっくり + 枠 + ハイライト
            AnyView(
                Text("本文編集")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(
                        Capsule().fill(
                            LinearGradient(colors: [Color(white: 0.88), Color(white: 0.98), Color(white: 0.86)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                    )
                    .overlay(Capsule().stroke(Color(white: 0.7), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 3)
            ),
            // 11: 3Dベベル風（上が白、下が暗い枠）
            AnyView(
                Text("本文編集")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(
                        Capsule().fill(Color(white: 0.93))
                            .overlay(
                                Capsule().strokeBorder(
                                    LinearGradient(colors: [.white.opacity(0.8), .black.opacity(0.15)],
                                                   startPoint: .top, endPoint: .bottom),
                                    lineWidth: 1.5
                                )
                            )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
            ),
            // 12: 太ベベル
            AnyView(
                Text("本文編集")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(
                        Capsule().fill(Color(white: 0.91))
                            .overlay(
                                Capsule().strokeBorder(
                                    LinearGradient(colors: [.white.opacity(0.9), .black.opacity(0.2)],
                                                   startPoint: .top, endPoint: .bottom),
                                    lineWidth: 2.5
                                )
                            )
                    )
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 3)
            ),
            // 13: グロス（上半分に光沢）
            AnyView(
                Text("本文編集")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(
                        ZStack {
                            Capsule().fill(Color(white: 0.88))
                            Capsule().fill(
                                LinearGradient(colors: [.white.opacity(0.5), .clear],
                                               startPoint: .top, endPoint: .center)
                            )
                        }
                    )
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 3)
            ),
            // 14: グロス + 枠
            AnyView(
                Text("本文編集")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(
                        ZStack {
                            Capsule().fill(Color(white: 0.86))
                            Capsule().fill(
                                LinearGradient(colors: [.white.opacity(0.6), .clear],
                                               startPoint: .top, endPoint: .center)
                            )
                        }
                    )
                    .overlay(Capsule().stroke(Color(white: 0.65), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 3)
            ),
            // 15: ゲームボタン風（丸め + 濃い影 + グラデ）
            AnyView(
                Text("本文編集")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(
                        Capsule().fill(
                            LinearGradient(colors: [Color(white: 0.97), Color(white: 0.83)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                    )
                    .overlay(
                        Capsule().strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.7), .black.opacity(0.1)],
                                           startPoint: .top, endPoint: .bottom),
                            lineWidth: 1.5
                        )
                    )
                    .shadow(color: .black.opacity(0.35), radius: 5, y: 4)
            ),
            // 16: ゲームボタン + インナーグロー
            AnyView(
                Text("本文編集")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(
                        ZStack {
                            Capsule().fill(
                                LinearGradient(colors: [Color(white: 0.95), Color(white: 0.80)],
                                               startPoint: .top, endPoint: .bottom)
                            )
                            Capsule().fill(
                                LinearGradient(colors: [.white.opacity(0.4), .clear],
                                               startPoint: .top, endPoint: .center)
                            ).padding(2)
                        }
                    )
                    .overlay(
                        Capsule().strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.6), Color(white: 0.6)],
                                           startPoint: .top, endPoint: .bottom),
                            lineWidth: 1
                        )
                    )
                    .shadow(color: .black.opacity(0.35), radius: 5, y: 4)
            ),
            // 17: 底上げ立体（下に太い影バー）
            AnyView(
                Text("本文編集")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(
                        ZStack {
                            Capsule().fill(Color(white: 0.75)).offset(y: 3)
                            Capsule().fill(
                                LinearGradient(colors: [Color(white: 0.97), Color(white: 0.90)],
                                               startPoint: .top, endPoint: .bottom)
                            )
                        }
                    )
            ),
            // 18: 底上げ + ベベル
            AnyView(
                Text("本文編集")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(
                        ZStack {
                            Capsule().fill(Color(white: 0.70)).offset(y: 3)
                            Capsule().fill(
                                LinearGradient(colors: [Color(white: 0.98), Color(white: 0.88)],
                                               startPoint: .top, endPoint: .bottom)
                            )
                            .overlay(
                                Capsule().strokeBorder(
                                    LinearGradient(colors: [.white.opacity(0.8), .black.opacity(0.1)],
                                                   startPoint: .top, endPoint: .bottom),
                                    lineWidth: 1
                                )
                            )
                        }
                    )
            ),
            // 19: 底上げ厚め
            AnyView(
                Text("本文編集")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(
                        ZStack {
                            Capsule().fill(Color(white: 0.68)).offset(y: 4)
                            Capsule().fill(
                                LinearGradient(colors: [Color(white: 1.0), Color(white: 0.88)],
                                               startPoint: .top, endPoint: .bottom)
                            )
                        }
                    )
            ),
            // 20: グロス + 底上げ + ベベル（全部盛り）
            AnyView(
                Text("本文編集")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(
                        ZStack {
                            Capsule().fill(Color(white: 0.65)).offset(y: 4)
                            Capsule().fill(
                                LinearGradient(colors: [Color(white: 0.97), Color(white: 0.85)],
                                               startPoint: .top, endPoint: .bottom)
                            )
                            Capsule().fill(
                                LinearGradient(colors: [.white.opacity(0.5), .clear],
                                               startPoint: .top, endPoint: .center)
                            ).padding(2)
                        }
                    )
                    .overlay(
                        Capsule().strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.7), Color(white: 0.6)],
                                           startPoint: .top, endPoint: .bottom),
                            lineWidth: 1
                        )
                    )
            ),
            // 21: 緑バージョン（フラット影）
            AnyView(
                Text("タイトル編集")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(Color.green.opacity(0.2)))
                    .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
            ),
            // 22: 緑グラデ + 影
            AnyView(
                Text("タイトル編集")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(
                        Capsule().fill(
                            LinearGradient(colors: [Color.green.opacity(0.15), Color.green.opacity(0.3)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
            ),
            // 23: 緑ベベル
            AnyView(
                Text("タイトル編集")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(
                        Capsule().fill(Color.green.opacity(0.2))
                            .overlay(
                                Capsule().strokeBorder(
                                    LinearGradient(colors: [.white.opacity(0.8), Color.green.opacity(0.3)],
                                                   startPoint: .top, endPoint: .bottom),
                                    lineWidth: 1.5
                                )
                            )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
            ),
            // 24: 緑底上げ
            AnyView(
                Text("タイトル編集")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(
                        ZStack {
                            Capsule().fill(Color.green.opacity(0.4)).offset(y: 3)
                            Capsule().fill(
                                LinearGradient(colors: [Color.green.opacity(0.1), Color.green.opacity(0.25)],
                                               startPoint: .top, endPoint: .bottom)
                            )
                        }
                    )
            ),
            // 25: 青バージョン（フラット影）
            AnyView(
                Text("タグ編集")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(Capsule().fill(Color.blue.opacity(0.15)))
                    .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
            ),
            // 26: 青グラデ + 影
            AnyView(
                Text("タグ編集")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(
                        Capsule().fill(
                            LinearGradient(colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.25)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
            ),
            // 27: 青ベベル
            AnyView(
                Text("タグ編集")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(
                        Capsule().fill(Color.blue.opacity(0.15))
                            .overlay(
                                Capsule().strokeBorder(
                                    LinearGradient(colors: [.white.opacity(0.8), Color.blue.opacity(0.3)],
                                                   startPoint: .top, endPoint: .bottom),
                                    lineWidth: 1.5
                                )
                            )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
            ),
            // 28: 青底上げ
            AnyView(
                Text("タグ編集")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(
                        ZStack {
                            Capsule().fill(Color.blue.opacity(0.35)).offset(y: 3)
                            Capsule().fill(
                                LinearGradient(colors: [Color.blue.opacity(0.08), Color.blue.opacity(0.2)],
                                               startPoint: .top, endPoint: .bottom)
                            )
                        }
                    )
            ),
            // 29: 全部盛り緑
            AnyView(
                Text("タイトル編集")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(
                        ZStack {
                            Capsule().fill(Color.green.opacity(0.45)).offset(y: 4)
                            Capsule().fill(
                                LinearGradient(colors: [Color.green.opacity(0.1), Color.green.opacity(0.28)],
                                               startPoint: .top, endPoint: .bottom)
                            )
                            Capsule().fill(
                                LinearGradient(colors: [.white.opacity(0.4), .clear],
                                               startPoint: .top, endPoint: .center)
                            ).padding(2)
                        }
                    )
                    .overlay(
                        Capsule().strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.6), Color.green.opacity(0.3)],
                                           startPoint: .top, endPoint: .bottom),
                            lineWidth: 1
                        )
                    )
            ),
            // 30: 全部盛り青
            AnyView(
                Text("タグ編集")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(
                        ZStack {
                            Capsule().fill(Color.blue.opacity(0.4)).offset(y: 4)
                            Capsule().fill(
                                LinearGradient(colors: [Color.blue.opacity(0.08), Color.blue.opacity(0.22)],
                                               startPoint: .top, endPoint: .bottom)
                            )
                            Capsule().fill(
                                LinearGradient(colors: [.white.opacity(0.4), .clear],
                                               startPoint: .top, endPoint: .center)
                            ).padding(2)
                        }
                    )
                    .overlay(
                        Capsule().strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.6), Color.blue.opacity(0.3)],
                                           startPoint: .top, endPoint: .bottom),
                            lineWidth: 1
                        )
                    )
            ),
        ]
    }
}
