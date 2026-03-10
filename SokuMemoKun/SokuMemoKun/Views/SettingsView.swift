import SwiftUI

// 設定画面
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("defaultMarkdown") private var defaultMarkdown = false
    @AppStorage("markdownLayout") private var markdownLayout: String = MarkdownLayout.split.rawValue

    var body: some View {
        NavigationStack {
            List {
                // タグ編集
                NavigationLink {
                    TagEditView()
                } label: {
                    Label("タグ編集", systemImage: "tag")
                }

                // マークダウン設定
                Section("マークダウン") {
                    Toggle(isOn: $defaultMarkdown) {
                        Label("新規メモでデフォルトON", systemImage: "text.quote")
                    }

                    // レイアウト選択
                    HStack {
                        HStack(spacing: 8) {
                            LayoutIcon(
                                layout: MarkdownLayout(rawValue: markdownLayout) ?? .split,
                                size: 20
                            )
                            Text("プレビュー表示形式")
                        }
                        Spacer()
                        Picker("", selection: $markdownLayout) {
                            ForEach(MarkdownLayout.allCases, id: \.rawValue) { layout in
                                Text(layout.rawValue).tag(layout.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                // バックアップ（将来実装）
                Section {
                    HStack {
                        Label("Googleドライブにバックアップ", systemImage: "icloud.and.arrow.up")
                        Spacer()
                        Text("準備中")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }

                // メモ設定（将来実装）
                Section("メモ設定") {
                    HStack {
                        Label("最大文字数", systemImage: "textformat.123")
                        Spacer()
                        Text("準備中")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}
