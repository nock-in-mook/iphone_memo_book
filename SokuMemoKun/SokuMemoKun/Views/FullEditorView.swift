import SwiftUI

// 全画面編集モード（マークダウン/ノーマル共通）
struct FullEditorView: View {
    @Binding var text: String
    @Binding var isMarkdown: Bool
    @Environment(\.dismiss) private var dismiss

    // マークダウン設定
    @AppStorage("markdownEnabled") private var markdownEnabled = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isMarkdown {
                    // Bear風インラインプレビュー
                    MarkdownTextEditor(text: $text)
                        .padding(4)
                } else {
                    // ノーマルモード: シンプルなテキストエディタ
                    TextEditor(text: $text)
                        .font(.system(size: 16))
                        .padding(8)
                }

                // マークダウン時のみ記号バー + キーボード閉じる
                if isMarkdown && markdownEnabled {
                    HStack(spacing: 0) {
                        MarkdownToolbar(text: $text)
                        dismissKeyboardButton
                    }
                }
            }
            .navigationTitle(isMarkdown ? "マークダウン編集" : "テキスト編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("戻る") { dismiss() }
                }

                ToolbarItem(placement: .principal) {
                    if markdownEnabled {
                        HStack(spacing: 6) {
                            Image(systemName: isMarkdown ? "text.quote" : "text.alignleft")
                                .font(.system(size: 12))
                                .foregroundStyle(isMarkdown ? .blue : .secondary)
                            Toggle("", isOn: $isMarkdown)
                                .toggleStyle(.switch)
                                .scaleEffect(0.7)
                                .labelsHidden()
                        }
                    }
                }

                // ノーマルモード時: キーボード上に閉じるボタン
                if !isMarkdown || !markdownEnabled {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        dismissKeyboardButton
                    }
                }
            }
        }
    }

    // キーボード閉じるボタン
    private var dismissKeyboardButton: some View {
        Button {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        } label: {
            Image(systemName: "keyboard.chevron.compact.down")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
    }
}
