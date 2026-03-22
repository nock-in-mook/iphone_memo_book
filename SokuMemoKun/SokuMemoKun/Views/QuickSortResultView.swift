import SwiftUI

// 爆速メモ整理モード: 戦績表示（全画面リッチ）
struct QuickSortResultView: View {
    let taggedCount: Int
    let titledCount: Int
    let editedCount: Int
    let deletedCount: Int
    let deletedMemos: [Memo]
    var onReviewDeleted: () -> Void
    var onNextSet: (() -> Void)? = nil  // 次のセットがある場合
    var onClose: () -> Void
    var onGoBack: () -> Void = {}  // 整理画面にもどる

    private var totalActions: Int {
        taggedCount + titledCount + editedCount + deletedCount
    }

    var body: some View {
        ZStack {
            // 背景（全画面）
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ヘッダー
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.orange)

                    Text("振り分け完了！")
                        .font(.system(size: 26, weight: .black, design: .rounded))

                    if totalActions > 0 {
                        Text("\(totalActions)件の操作を実行しました")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("操作はありませんでした")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 32)

                // 戦績カード
                VStack(spacing: 0) {
                    resultRow(icon: "🏷", label: "にタグ付け", count: taggedCount)
                    Divider().padding(.leading, 44)
                    resultRow(icon: "📝", label: "にタイトル付け", count: titledCount)
                    Divider().padding(.leading, 44)
                    resultRow(icon: "✏️", label: "の本文を編集", count: editedCount)
                    Divider().padding(.leading, 44)
                    resultRow(icon: "🗑", label: "を削除", count: deletedCount, isDestructive: true)
                }
                .background(Color(uiColor: .systemBackground))
                .cornerRadius(14)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
                .padding(.horizontal, 24)

                Spacer()

                // ボタン
                VStack(spacing: 12) {
                    if deletedCount > 0 {
                        Button {
                            onReviewDeleted()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                                Text("削除したメモを確認（\(deletedCount)件）")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.red.opacity(0.08))
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if let onNextSet = onNextSet {
                        // 次のセットへ
                        Button {
                            onNextSet()
                        } label: {
                            HStack(spacing: 8) {
                                Text("次のセットへ")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.orange)
                            )
                        }
                        .buttonStyle(.plain)

                        // 終了する
                        Button {
                            onClose()
                        } label: {
                            Text("終了する")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    } else {
                        // 最終セット or 単一セット
                        Button {
                            onClose()
                        } label: {
                            Text("完了")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.orange)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    // 整理画面にもどる（共通）
                    Button {
                        onGoBack()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 13, weight: .semibold))
                            Text("整理画面にもどる")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .transition(.opacity)
    }

    @ViewBuilder
    private func resultRow(icon: String, label: String, count: Int, isDestructive: Bool = false) -> some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.system(size: 24))
                .frame(width: 32)

            Text("\(count)件\(label)")
                .font(.system(size: 17, weight: count > 0 ? .bold : .regular, design: .rounded))
                .foregroundStyle(count > 0 ? (isDestructive ? .red : .primary) : .secondary)

            Spacer()

            if count > 0 {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(isDestructive ? .red : .green)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
