import SwiftUI

// フォントラボ: ToDoリスト用フォントのプレビュー
struct FontLabView: View {
    // サンプルテキスト
    private let sampleText = "買い物リストを作る"
    private let sampleDone = "牛乳を買う"

    // フォントデザイン
    private let designs: [(String, Font.Design)] = [
        ("デフォルト", .default),
        ("丸ゴシック", .rounded),
        ("セリフ", .serif),
        ("等幅", .monospaced),
    ]

    // フォントウェイト
    private let weights: [(String, Font.Weight)] = [
        ("Thin", .thin),
        ("Light", .light),
        ("Regular", .regular),
        ("Medium", .medium),
        ("Semibold", .semibold),
        ("Bold", .bold),
        ("Heavy", .heavy),
        ("Black", .black),
    ]

    // フォントサイズ
    private let sizes: [CGFloat] = [14, 15, 16, 17, 18, 20]

    var body: some View {
        List {
            // デザイン × ウェイト（サイズ16固定）
            Section {
                ForEach(designs, id: \.0) { designName, design in
                    ForEach(weights, id: \.0) { weightName, weight in
                        sampleRow(
                            label: "\(designName) / \(weightName)",
                            font: .system(size: 16, weight: weight, design: design)
                        )
                    }
                }
            } header: {
                Text("デザイン × ウェイト（16pt）")
            }

            // サイズ比較（丸ゴシック × Medium）
            Section {
                ForEach(sizes, id: \.self) { size in
                    sampleRow(
                        label: "丸ゴシック Medium \(Int(size))pt",
                        font: .system(size: size, weight: .medium, design: .rounded)
                    )
                }
            } header: {
                Text("サイズ比較（丸ゴシック Medium）")
            }

            // サイズ比較（デフォルト × Semibold）
            Section {
                ForEach(sizes, id: \.self) { size in
                    sampleRow(
                        label: "デフォルト Semibold \(Int(size))pt",
                        font: .system(size: size, weight: .semibold, design: .default)
                    )
                }
            } header: {
                Text("サイズ比較（デフォルト Semibold）")
            }

            // おすすめ候補
            Section {
                sampleRow(label: "★ 丸ゴシック Regular 16pt", font: .system(size: 16, weight: .regular, design: .rounded))
                sampleRow(label: "★ 丸ゴシック Medium 16pt", font: .system(size: 16, weight: .medium, design: .rounded))
                sampleRow(label: "★ 丸ゴシック Semibold 15pt", font: .system(size: 15, weight: .semibold, design: .rounded))
                sampleRow(label: "★ デフォルト Medium 16pt", font: .system(size: 16, weight: .medium, design: .default))
                sampleRow(label: "★ デフォルト Semibold 16pt", font: .system(size: 16, weight: .semibold, design: .default))
                sampleRow(label: "★ セリフ Regular 16pt", font: .system(size: 16, weight: .regular, design: .serif))
                sampleRow(label: "★ セリフ Medium 17pt", font: .system(size: 17, weight: .medium, design: .serif))
            } header: {
                Text("おすすめ候補")
            }
        }
        .navigationTitle("フォントラボ")
        .navigationBarTitleDisplayMode(.inline)
    }

    // サンプルToDo行
    @ViewBuilder
    private func sampleRow(label: String, font: Font) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // ラベル
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.bottom, 2)

            // 未チェック行
            HStack(spacing: 8) {
                Image(systemName: "square")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.35))
                Text(sampleText)
                    .font(font)
            }

            // チェック済み行
            HStack(spacing: 8) {
                Image(systemName: "checkmark.square.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.green)
                Text(sampleDone)
                    .font(font)
                    .strikethrough(color: .secondary)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
