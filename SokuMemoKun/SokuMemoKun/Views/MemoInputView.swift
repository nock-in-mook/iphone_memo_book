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
    // 子タグダイアル展開
    @State private var showChildDial = false

    // 親タグオプション（parentTagID == nil のタグのみ）
    private var parentOptions: [(id: String, name: String, color: Color)] {
        var list: [(String, String, Color)] = [("none", "タグなし", tagColor(for: 0))]
        for tag in tags where tag.parentTagID == nil {
            list.append((tag.id.uuidString, tag.name, tagColor(for: tag.colorIndex)))
        }
        return list
    }

    // 子タグオプション（選択中の親タグの子タグのみ）
    private var childOptions: [(id: String, name: String, color: Color)] {
        guard let parentID = viewModel.selectedTagID else { return [] }
        var list: [(String, String, Color)] = [("none", "なし", tagColor(for: 0))]
        for tag in tags where tag.parentTagID == parentID {
            list.append((tag.id.uuidString, tag.name, tagColor(for: tag.colorIndex)))
        }
        return list
    }

    // 選択中の親タグに子タグが存在するか
    private var hasChildTags: Bool {
        guard let parentID = viewModel.selectedTagID else { return false }
        return tags.contains { $0.parentTagID == parentID }
    }

    // 選択中タグの表示名と色（ルーレット・タブと統一）
    private var selectedTagInfo: (name: String, color: Color) {
        if let tagID = viewModel.selectedTagID,
           let tag = tags.first(where: { $0.id == tagID }) {
            return (tag.name, tagColor(for: tag.colorIndex))
        }
        return ("タグなし", tagColor(for: 0))
    }

    // 子タグ情報
    private var selectedChildTagInfo: (name: String, color: Color)? {
        if let childID = viewModel.selectedChildTagID,
           let tag = tags.first(where: { $0.id == childID }) {
            return (tag.name, tagColor(for: tag.colorIndex))
        }
        return nil
    }

    // 5文字省略
    private var truncatedTagName: String {
        let name = selectedTagInfo.name
        if name.count > 5 {
            return String(name.prefix(5)) + "…"
        }
        return name
    }

    private var truncatedChildTagName: String? {
        guard let info = selectedChildTagInfo else { return nil }
        if info.name.count > 4 {
            return String(info.name.prefix(4)) + "…"
        }
        return info.name
    }

    var body: some View {
        HStack(spacing: 0) {
            // 左3/4: 入力エリア + タイトル + ボタン行
            VStack(spacing: 0) {
                // メモ入力欄
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $viewModel.inputText)
                        .font(.system(size: 14))
                        .padding(.leading, 4)
                        .padding(.trailing, 28) // 右側ボタン(拡大・破棄)との重なり防止
                        .padding(.top, 4)
                        .padding(.bottom, 20) // 最下行の余白（スクロール時に窮屈にならないように）
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

                    // オーバーレイボタン（右上: 拡大、右下: 破棄）
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
                        HStack {
                            Spacer()
                            if viewModel.canClear {
                                Button {
                                    showDiscardAlert = true
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.red.opacity(0.5))
                                        .padding(5)
                                        .background(
                                            Circle()
                                                .fill(Color(uiColor: .systemBackground).opacity(0.8))
                                        )
                                }
                                .padding(.trailing, 4)
                                .padding(.bottom, 4)
                            }
                        }
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
                        // 親タグ表示
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

                        // 子タグ表示
                        if let childName = truncatedChildTagName,
                           let childInfo = selectedChildTagInfo {
                            Text("›")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                            Text(childName)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(childInfo.color)
                                )
                        }

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

            // 右側: 親タグダイアル + 子タグダイアル
            HStack(spacing: 0) {
                // 親タグダイアル
                TagDialView(
                    options: parentOptions,
                    selectedID: $viewModel.selectedTagID,
                    width: showChildDial ? 70 : 100
                )

                // 子タグエリア
                if hasChildTags {
                    if showChildDial {
                        // 仕切り線
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 1)

                        // 子タグダイアル
                        TagDialView(
                            options: childOptions,
                            selectedID: $viewModel.selectedChildTagID,
                            width: 70
                        )

                        // 閉じるタブ（右端）
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                showChildDial = false
                            }
                        } label: {
                            Text("›")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 14, height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.1))
                                )
                        }
                    } else {
                        // 「子」タブ突起（タップで子ダイアル展開）
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                showChildDial = true
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Text("子")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                Text("›")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundStyle(.secondary)
                            .frame(width: 18, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.15))
                            )
                        }
                    }
                }
            }
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
        // 自動保存: 親タグ変更
        .onChange(of: viewModel.selectedTagID) { _, _ in
            // 親タグが変わったら子タグをリセット
            viewModel.selectedChildTagID = nil
            // 子タグがない親に切り替えたら子ダイアルを閉じる
            if !hasChildTags {
                showChildDial = false
            }
            viewModel.onTagChanged(tags: tags)
        }
        // 自動保存: 子タグ変更
        .onChange(of: viewModel.selectedChildTagID) { _, _ in
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
