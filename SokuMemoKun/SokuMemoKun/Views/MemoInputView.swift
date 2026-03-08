import SwiftUI
import SwiftData

struct MemoInputView: View {
    @Bindable var viewModel: MemoInputViewModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var tags: [Tag]

    var body: some View {
        HStack(spacing: 0) {
            // 左: テキスト入力 + ボタン
            VStack(spacing: 6) {
                TextEditor(text: $viewModel.inputText)
                    .frame(minHeight: 80, maxHeight: 120)
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

            // 右: ジョグダイヤル
            TagDialView(selectedTagID: $viewModel.selectedTagID)
                .frame(width: 55, height: 150)
                .clipped()
        }
        .padding(.trailing, 0)
    }
}
