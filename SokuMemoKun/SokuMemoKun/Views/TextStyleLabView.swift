import SwiftUI

// テキストスタイルラボ: ボタン上のテキスト表現パターン一覧
struct TextStyleLabView: View {
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(0..<styles.count, id: \.self) { i in
                    VStack(spacing: 4) {
                        Text("T\(i + 1)")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                        styles[i]
                    }
                }
            }
            .padding(12)
        }
        .navigationTitle("テキストスタイルラボ")
        .navigationBarTitleDisplayMode(.inline)
    }

    // ボタンを生成するヘルパー
    private func btn(_ text: String, bg: Color, bgGrad: [Color]? = nil, textMod: @escaping (Text) -> AnyView) -> some View {
        textMod(Text(text).font(.system(size: 11, weight: .bold, design: .rounded)))
            .padding(.horizontal, 10)
            .padding(.top, 4).padding(.bottom, 7)
            .background(
                Capsule().fill(
                    bgGrad != nil
                        ? LinearGradient(colors: bgGrad!, startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [bg, bg], startPoint: .top, endPoint: .bottom)
                )
            )
            .shadow(color: .black.opacity(0.35), radius: 1, y: 5)
    }

    // オレンジボタン
    private func orange(_ textMod: @escaping (Text) -> AnyView) -> some View {
        btn("タイトル", bg: .clear, bgGrad: [
            Color(white: 0.95).opacity(1), Color(white: 0.95).opacity(1)
        ]) { t in textMod(t) }
        .background(
            Capsule().fill(Color(white: 0.95))
                .overlay(Capsule().fill(
                    LinearGradient(colors: [Color.orange.opacity(0.3), Color.orange.opacity(0.5)],
                                   startPoint: .top, endPoint: .bottom)
                ))
                .shadow(color: .black.opacity(0.35), radius: 1, y: 5)
        )
    }

    private var styles: [AnyView] {
        [
            // T1: プレーン黒
            AnyView(sampleButton { $0.foregroundStyle(.primary) }),
            // T2: 白テキスト
            AnyView(sampleButton { $0.foregroundStyle(.white) }),
            // T3: ダークグレー
            AnyView(sampleButton { $0.foregroundStyle(Color(white: 0.25)) }),
            // T4: 黒 + 白ドロップシャドウ
            AnyView(sampleButton { $0.foregroundStyle(.primary).shadow(color: .white.opacity(0.8), radius: 0, y: 1) }),
            // T5: 黒 + 黒ドロップシャドウ
            AnyView(sampleButton { $0.foregroundStyle(.primary).shadow(color: .black.opacity(0.3), radius: 0, y: 1) }),
            // T6: 黒 + 濃い黒シャドウ
            AnyView(sampleButton { $0.foregroundStyle(.primary).shadow(color: .black.opacity(0.5), radius: 0, y: 1.5) }),
            // T7: 白 + 黒ドロップシャドウ
            AnyView(sampleButton { $0.foregroundStyle(.white).shadow(color: .black.opacity(0.4), radius: 0, y: 1) }),
            // T8: 白 + ぼかしシャドウ
            AnyView(sampleButton { $0.foregroundStyle(.white).shadow(color: .black.opacity(0.3), radius: 2, y: 1) }),
            // T9: ダークグレー + 白シャドウ（エンボス風）
            AnyView(sampleButton { $0.foregroundStyle(Color(white: 0.3)).shadow(color: .white.opacity(0.9), radius: 0, y: 1) }),
            // T10: エンボス（白シャドウ上 + 黒シャドウ下）
            AnyView(sampleButton { $0.foregroundStyle(Color(white: 0.35)).shadow(color: .white.opacity(0.8), radius: 0, y: 1).shadow(color: .black.opacity(0.15), radius: 0, y: -0.5) }),
            // T11: 黒 + 白シャドウ上（インセット風）
            AnyView(sampleButton { $0.foregroundStyle(.primary).shadow(color: .white.opacity(0.9), radius: 0, y: -1) }),
            // T12: 黒 + ぼかし白グロー
            AnyView(sampleButton { $0.foregroundStyle(.primary).shadow(color: .white.opacity(0.7), radius: 2, y: 0) }),
            // T13: 濃いグレー + 薄いぼかし
            AnyView(sampleButton { $0.foregroundStyle(Color(white: 0.2)).shadow(color: .white.opacity(0.6), radius: 1, y: 1) }),
            // T14: オレンジテキスト
            AnyView(sampleButton { $0.foregroundStyle(.orange) }),
            // T15: 濃いオレンジ + 白シャドウ
            AnyView(sampleButton { $0.foregroundStyle(Color.orange.opacity(0.8)).shadow(color: .white.opacity(0.9), radius: 0, y: 1) }),
            // T16: ブラウン
            AnyView(sampleButton { $0.foregroundStyle(.brown) }),
            // T17: ブラウン + 白シャドウ
            AnyView(sampleButton { $0.foregroundStyle(.brown).shadow(color: .white.opacity(0.8), radius: 0, y: 1) }),
            // T18: 白テキスト + オレンジシャドウ
            AnyView(sampleButton { $0.foregroundStyle(.white).shadow(color: .orange.opacity(0.5), radius: 1, y: 1) }),
            // T19: 黒 + オレンジグロー
            AnyView(sampleButton { $0.foregroundStyle(.primary).shadow(color: .orange.opacity(0.4), radius: 3, y: 0) }),
            // T20: ダブルシャドウ（白上 + 黒下）強め
            AnyView(sampleButton { $0.foregroundStyle(Color(white: 0.25)).shadow(color: .white, radius: 0, y: 1).shadow(color: .black.opacity(0.2), radius: 0, y: -1) }),
            // T21: レタープレス（凹み文字）
            AnyView(sampleButton { $0.foregroundStyle(Color(white: 0.4)).shadow(color: .white.opacity(0.7), radius: 0, x: 0, y: -1).shadow(color: .black.opacity(0.1), radius: 0, x: 0, y: 1) }),
            // T22: 太黒シャドウ（刻印風）
            AnyView(sampleButton { $0.foregroundStyle(.primary).shadow(color: .black.opacity(0.4), radius: 0, y: 2) }),
            // T23: 白アウトライン風
            AnyView(sampleButton { $0.foregroundStyle(.primary).shadow(color: .white, radius: 1, y: 0).shadow(color: .white, radius: 1, y: 0) }),
            // T24: ぼかし黒シャドウ（浮き文字）
            AnyView(sampleButton { $0.foregroundStyle(.primary).shadow(color: .black.opacity(0.25), radius: 2, y: 2) }),
        ]
    }

    // オレンジ・グレー・シアンの3ボタンセット
    @ViewBuilder
    private func sampleButton(_ textMod: @escaping (Text) -> some View) -> some View {
        HStack(spacing: 3) {
            // オレンジ
            textMod(Text("タイトル").font(.system(size: 10, weight: .bold, design: .rounded)))
                .padding(.horizontal, 6)
                .padding(.top, 3).padding(.bottom, 5)
                .background(
                    ZStack {
                        Capsule().fill(Color(white: 0.95))
                        Capsule().fill(
                            LinearGradient(colors: [Color.orange.opacity(0.3), Color.orange.opacity(0.5)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                    }
                )
                .shadow(color: .black.opacity(0.35), radius: 1, y: 3)

            // グレー
            textMod(Text("本文").font(.system(size: 10, weight: .bold, design: .rounded)))
                .padding(.horizontal, 8)
                .padding(.top, 3).padding(.bottom, 5)
                .background(
                    Capsule().fill(
                        LinearGradient(colors: [Color(white: 0.98), Color(white: 0.88)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                )
                .shadow(color: .black.opacity(0.35), radius: 1, y: 3)

            // シアン
            textMod(Text("タグ").font(.system(size: 10, weight: .bold, design: .rounded)))
                .padding(.horizontal, 8)
                .padding(.top, 3).padding(.bottom, 5)
                .background(
                    ZStack {
                        Capsule().fill(Color(white: 0.95))
                        Capsule().fill(
                            LinearGradient(colors: [Color.cyan.opacity(0.18), Color.cyan.opacity(0.35)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                    }
                )
                .shadow(color: .black.opacity(0.35), radius: 1, y: 3)
        }
    }
}
