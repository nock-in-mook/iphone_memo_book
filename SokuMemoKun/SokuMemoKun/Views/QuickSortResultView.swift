import SwiftUI

// 爆速振り分けモード: 戦績表示
struct QuickSortResultView: View {
    let taggedCount: Int
    let titledCount: Int
    let editedCount: Int
    let deletedCount: Int
    let deletedMemos: [Memo]
    var onReviewDeleted: () -> Void
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // ヘッダー
                VStack(spacing: 8) {
                    Text("📊")
                        .font(.system(size: 40))
                    Text("振り分け結果")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                }
                .padding(.top, 24)
                .padding(.bottom, 16)

                Divider()

                // 戦績リスト
                VStack(spacing: 0) {
                    resultRow(icon: "🏷", label: "タグ付け", count: taggedCount)
                    resultRow(icon: "📝", label: "タイトル付け", count: titledCount)
                    resultRow(icon: "✏️", label: "本文を編集", count: editedCount)
                    resultRow(icon: "🗑", label: "削除", count: deletedCount)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                Divider()

                // ボタン
                VStack(spacing: 0) {
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
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)

                        Divider()
                    }

                    Button {
                        onClose()
                    } label: {
                        Text("閉じる")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.2), radius: 16, y: 6)
            .padding(.horizontal, 36)
        }
        .transition(.opacity)
    }

    @ViewBuilder
    private func resultRow(icon: String, label: String, count: Int) -> some View {
        HStack {
            Text(icon)
                .font(.system(size: 18))
            Text("\(count)件に\(label)")
                .font(.system(size: 15, weight: count > 0 ? .semibold : .regular))
                .foregroundStyle(count > 0 ? .primary : .secondary)
            Spacer()
        }
        .padding(.vertical, 6)
    }
}
