import SwiftUI

// 設定画面
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("markdownEnabled") private var markdownEnabled = false
    @AppStorage("defaultMarkdown") private var defaultMarkdown = false
    @AppStorage("restoreLastMemo") private var restoreLastMemo = false
    @AppStorage("dialDefault") private var dialDefault: Int = 0
    @AppStorage("coloredFrame") private var coloredFrame = true
    @AppStorage("showCharCount") private var showCharCount = false
    @AppStorage("showLineNumbers") private var showLineNumbers = false

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

                // 入力欄の見た目
                Section("入力欄") {
                    Toggle(isOn: $coloredFrame) {
                        Label("タグ色でフレームを彩色", systemImage: "paintbrush")
                    }
                    Toggle(isOn: $showCharCount) {
                        Label("文字数カウンター", systemImage: "number")
                    }
                    Toggle(isOn: $showLineNumbers) {
                        Label("行番号を表示", systemImage: "list.number")
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

                // カラーラボ
                Section("カラーラボ") {
                    NavigationLink {
                        ColorLabView()
                    } label: {
                        Label("「よく見る」配色パターン", systemImage: "paintpalette")
                    }
                }

                // ボタンデザインラボ
                Section("ボタンラボ") {
                    NavigationLink {
                        ButtonLabView()
                    } label: {
                        Label("爆速モード ボタンデザイン", systemImage: "button.programmable")
                    }
                }

                // 影ラボ
                Section("影ラボ") {
                    NavigationLink { TextureLab1() } label: { Text("1: タブシェイプ影") }
                    NavigationLink { TextureLab2() } label: { Text("2: テキスト影") }
                    NavigationLink { TextureLab3() } label: { Text("3: カード インナーシャドウ") }
                    NavigationLink { TextureLab4() } label: { Text("4: カード ドロップシャドウ") }
                    NavigationLink { TextureLab5() } label: { Text("5: インナー+ドロップ併用") }
                    NavigationLink { TextureLab6() } label: { Text("6: 全部盛り組み合わせ") }
                    NavigationLink { TextureLab7() } label: { Text("7: 色違いで確認") }
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
