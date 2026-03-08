import SwiftUI
import SwiftData

struct MemoInputView: View {
    @Bindable var viewModel: MemoInputViewModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var tags: [Tag]

    var body: some View {
        HStack(spacing: 0) {
            // 左: テキスト入力 + タイトル + ボタン
            VStack(spacing: 4) {
                TextEditor(text: $viewModel.inputText)
                    .frame(minHeight: 70, maxHeight: 110)
                    .padding(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3))
                    )
                    .overlay(alignment: .topLeading) {
                        if viewModel.inputText.isEmpty {
                            Text("メモを入力...")
                                .foregroundStyle(.gray.opacity(0.5))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 14)
                                .allowsHitTesting(false)
                        }
                    }

                // タイトル入力（小さく）
                TextField("タイトル（任意）", text: $viewModel.titleText)
                    .font(.system(size: 12, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.08))
                    )

                HStack {
                    Spacer()
                    Button {
                        UIPasteboard.general.string = viewModel.inputText
                    } label: {
                        Label("コピー", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                    .disabled(viewModel.inputText.isEmpty)

                    Button {
                        viewModel.save(context: modelContext, tags: tags)
                    } label: {
                        Label("保存", systemImage: "square.and.arrow.down")
                            .font(.caption)
                            .bold()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canSave)
                }
            }
            .padding(.leading)
            .padding(.vertical, 6)

            // 右: タグルーレット
            TagDialView(selectedTagID: $viewModel.selectedTagID)
                .padding(.horizontal, 4)
        }
    }
}
