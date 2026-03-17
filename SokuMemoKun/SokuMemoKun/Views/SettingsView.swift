import SwiftUI

// 設定画面
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("markdownEnabled") private var markdownEnabled = false
    @AppStorage("defaultMarkdown") private var defaultMarkdown = false
    @AppStorage("restoreLastMemo") private var restoreLastMemo = false
    @AppStorage("dialDefault") private var dialDefault: Int = 0

    var body: some View {
        NavigationStack {
            List {
                // タグ編集
                NavigationLink {
                    TagEditView()
                } label: {
                    Label("タグ編集", systemImage: "tag")
                }

                // 起動時の動作
                Section("起動時の動作") {
                    Picker(selection: $restoreLastMemo) {
                        Text("常に白紙で始める").tag(false)
                        Text("前回のメモを続行").tag(true)
                    } label: {
                        Label("アプリ起動時の入力欄", systemImage: "doc.text")
                    }
                }

                // タグトレー
                Section("タグトレー") {
                    Picker(selection: $dialDefault) {
                        Text("チラ見せ").tag(0)
                        Text("全開").tag(1)
                        Text("隠す").tag(2)
                    } label: {
                        Label("起動時の状態", systemImage: "tray.and.arrow.down")
                    }
                }

                // マークダウン設定
                Section {
                    Toggle(isOn: $markdownEnabled) {
                        Label("マークダウンモード", systemImage: "text.quote")
                    }

                    if markdownEnabled {
                        Toggle(isOn: $defaultMarkdown) {
                            HStack {
                                Text("新規メモでデフォルトON")
                                    .font(.system(size: 15))
                            }
                        }
                        .padding(.leading, 8)
                    }
                } header: {
                    Text("マークダウン")
                } footer: {
                    if !markdownEnabled {
                        Text("ONにすると記号入力バーやプレビュー機能が使えます")
                            .font(.system(size: 12))
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
