import SwiftUI
import SwiftData

struct MemoInputView: View {
    @Bindable var viewModel: MemoInputViewModel
    @Binding var focusInput: Bool
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var tags: [Tag]
    @FocusState private var isTextEditorFocused: Bool

    // 保存アニメーション用
    @State private var showSaveAnimation = false
    @State private var saveAnimationOffset: CGFloat = 0

    // 新規タグ作成シート
    @State private var showNewTagSheet = false
    // 全画面編集
    @State private var showFullEditor = false
    // 破棄確認ダイアログ
    @State private var showDiscardAlert = false

    // 選択中タグの表示名と色（ルーレット・タブと統一）
    private var selectedTagInfo: (name: String, color: Color) {
        if let tagID = viewModel.selectedTagID,
           let tag = tags.first(where: { $0.id == tagID }) {
            return (tag.name, tagColor(for: tag.colorIndex))
        }
        return ("タグなし", tagColor(for: 0))
    }

    // 5文字省略
    private var truncatedTagName: String {
        let name = selectedTagInfo.name
        if name.count > 5 {
            return String(name.prefix(5)) + "…"
        }
        return name
    }

    var body: some View {
        HStack(spacing: 0) {
            // 左3/4: 入力エリア + タイトル + ボタン行
            VStack(spacing: 0) {
                // メモ入力欄
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $viewModel.inputText)
                        .font(.system(size: 14))
                        .padding(4)
                        .focused($isTextEditorFocused)

                    if viewModel.inputText.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.isMarkdown ? "タップでマークダウン編集..." : "メモを入力...")
                                .font(.system(size: 14))
                            if viewModel.isMarkdown {
                                Text("(設定でオンオフ切替できます)")
                                    .font(.system(size: 10))
                            }
                        }
                        .foregroundStyle(.gray.opacity(0.5))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                    }

                    // マークダウンON＋空欄のとき、タップで全画面編集へ
                    if viewModel.isMarkdown && viewModel.inputText.isEmpty {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                showFullEditor = true
                            }
                    }

                    // 拡大ボタン（右上）
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                showFullEditor = true
                            } label: {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.gray.opacity(0.5))
                                    .padding(5)
                                    .background(
                                        Circle()
                                            .fill(Color(uiColor: .systemBackground).opacity(0.8))
                                    )
                            }
                            .padding(.trailing, 4)
                            .padding(.top, 4)
                        }
                        Spacer()
                    }
                }
                .frame(maxHeight: .infinity)

                Divider()
                    .padding(.horizontal, 6)

                // タイトル入力
                TextField("タイトル（任意）", text: $viewModel.titleText)
                    .font(.system(size: 12, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)

                Divider()
                    .padding(.horizontal, 6)

                // ボタン行: 2段（上:タグ: 下:タグパネル+ボタン）
                VStack(alignment: .leading, spacing: 2) {
                    // 「タグ:」ラベル（左上に配置）
                    Text("タグ:")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(.tertiary)

                    HStack(spacing: 5) {
                        // タグ表示（リアルタイム反映・ルーレット/タブと色統一）
                        Text(truncatedTagName)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedTagInfo.color)
                            )

                        Spacer()

                        // 新規タグ追加ボタン（薄グレー、コピーの左）
                        Button {
                            showNewTagSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(.gray.opacity(0.4))
                        }

                        // タグ系とアクション系の仕切り線
                        Rectangle()
                            .fill(Color.gray.opacity(0.25))
                            .frame(width: 1, height: 18)

                        // 破棄ボタン
                        Button {
                            showDiscardAlert = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundStyle(.red.opacity(0.6))
                        }
                        .disabled(!viewModel.canClear)

                        Button {
                            UIPasteboard.general.string = viewModel.inputText
                        } label: {
                            Label("コピー", systemImage: "doc.on.doc")
                                .font(.system(size: 11))
                        }
                        .disabled(viewModel.inputText.isEmpty)

                        Button {
                            viewModel.clearInput()
                            triggerSaveAnimation()
                        } label: {
                            Label("保存", systemImage: "square.and.arrow.down.fill")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                        .disabled(!viewModel.canClear)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 3)
                .padding(.bottom, 5)
            }

            // 区切り線
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1)

            // 右1/4: タグルーレット
            TagDialView(selectedTagID: $viewModel.selectedTagID)
        }
        .frame(height: 160)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(uiColor: .systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .alert("書きかけのメモを破棄します。よろしいですか？", isPresented: $showDiscardAlert) {
            Button("破棄", role: .destructive) {
                viewModel.discardMemo(context: modelContext)
            }
            Button("キャンセル", role: .cancel) {}
        }
        .sheet(isPresented: $showNewTagSheet) {
            NewTagSheetView()
        }
        .fullScreenCover(isPresented: $showFullEditor) {
            FullEditorView(
                text: $viewModel.inputText,
                isMarkdown: $viewModel.isMarkdown
            )
        }
        .onChange(of: focusInput) { _, newValue in
            if newValue {
                isTextEditorFocused = true
                focusInput = false
            }
        }
        // 自動保存: テキスト変更
        .onChange(of: viewModel.inputText) { _, _ in
            viewModel.onContentChanged(context: modelContext, tags: tags)
        }
        // 自動保存: タイトル変更
        .onChange(of: viewModel.titleText) { _, _ in
            viewModel.onTitleChanged()
        }
        // 自動保存: タグ変更
        .onChange(of: viewModel.selectedTagID) { _, _ in
            viewModel.onTagChanged(tags: tags)
        }
        // マークダウンメモ読み込み時にFullEditorを自動起動
        .onChange(of: viewModel.openFullEditor) { _, newValue in
            if newValue {
                showFullEditor = true
                viewModel.openFullEditor = false
            }
        }
    }

    private func triggerSaveAnimation() {
        // 保存後の吸い込みアニメーション（将来実装）
        withAnimation(.easeIn(duration: 0.3)) {
            showSaveAnimation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showSaveAnimation = false
        }
    }
}
