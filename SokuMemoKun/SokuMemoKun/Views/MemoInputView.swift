import SwiftUI
import SwiftData

extension Notification.Name {
    static let switchToTab = Notification.Name("switchToTab")
    static let memoSavedFlash = Notification.Name("memoSavedFlash")
}

struct MemoInputView: View {
    @Bindable var viewModel: MemoInputViewModel
    @Binding var focusInput: Bool
    @Binding var isExpanded: Bool
    var hasDiff: Bool = false
    var onConfirm: (() -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var tags: [Tag]
    @AppStorage("coloredFrame") private var coloredFrame = true
    @AppStorage("showCharCount") private var showCharCount = false
    @AppStorage("showLineNumbers") private var showLineNumbers = false
    @State private var isTextEditorFocused: Bool = false
    @FocusState private var isTitleFocused: Bool

    // 新規タグ作成シート
    @State private var showNewTagSheet = false
    @State private var newTagIsChild = false
    // 既存メモ読み込み時は閲覧モード（タップで編集開始）
    @State private var isEditing = true
    /// タップ位置のカーソルオフセット（nil=末尾）
    @State private var contentTapOffset: Int?
    // 削除確認ダイアログ
    @State private var showDeleteAlert = false
    // 本文クリア確認ダイアログ
    @State private var showClearBodyAlert = false
    // 子タグ追加時の親タグ未選択警告
    @State private var showNoParentAlert = false
    // タグ長押し編集/削除
    @State private var longPressedTagID: UUID?
    @State private var longPressedIsChild = false
    @State private var showTagActionSheet = false
    @State private var showTagEditSheet = false
    @State private var showTagDeleteAlert = false
    // ルーレット展開状態
    @State private var showParentDial = false
    @State private var trayHidden = false // 完全収納（取っ手も隠れる）
    @State private var showChildDial = true
    @State private var childExternalDragY: CGFloat? = nil
    @AppStorage("dialDefault") private var dialDefault: Int = 0
    // タグ履歴
    @Binding var showTagHistory: Bool
    @Binding var tagHistoryItems: [TagHistory]

    @AppStorage("allTagSortOrder") private var allTagSortOrder: Int = -1
    @AppStorage("noTagSortOrder") private var noTagSortOrder: Int = 9999

    // タグ削除ダイアログのタイトル・メッセージ
    private var longPressedTag: Tag? {
        guard let id = longPressedTagID else { return nil }
        return tags.first(where: { $0.id == id })
    }

    private var tagDeleteAlertTitle: String {
        guard let tag = longPressedTag else { return "タグを削除" }
        let count = tag.memos.count
        if count > 0 {
            return "「\(tag.name)」を削除しますか？（メモ\(count)件あり）"
        }
        return "「\(tag.name)」を削除しますか？"
    }

    private var tagDeleteAlertMessage: String {
        guard let tag = longPressedTag else { return "" }
        let count = tag.memos.count
        if count > 0 {
            return "このタグに紐づく\(count)件のメモは「タグなし」に移動されます。メモ自体は削除されません。"
        }
        return "このタグを削除します。"
    }

    private func deleteTag() {
        guard let tag = longPressedTag else { return }
        // メモからタグを外す
        for memo in tag.memos {
            memo.tags.removeAll { $0.id == tag.id }
        }
        // 選択中のタグだった場合はクリア
        if viewModel.selectedTagID == tag.id {
            viewModel.selectedTagID = nil
        }
        if viewModel.selectedChildTagID == tag.id {
            viewModel.selectedChildTagID = nil
        }
        modelContext.delete(tag)
        longPressedTagID = nil
    }

    // タグ長押しカスタムダイアログ
    @ViewBuilder
    private func tagActionDialog(tag: Tag) -> some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) { showTagActionSheet = false }
                }

            VStack(spacing: 0) {
                // ヘッダー: 種別ラベル + 色付きバッジ
                VStack(spacing: 8) {
                    Text(longPressedIsChild ? "子タグ" : "親タグ")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    // タグ名バッジ（色付き）
                    let displayName = tag.name.count > 10 ? String(tag.name.prefix(10)) + "…" : tag.name
                    Text(displayName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(tagColor(for: tag.colorIndex))
                                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                        )
                }
                .padding(.top, 20)
                .padding(.bottom, 16)

                Divider()

                // 編集
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showTagActionSheet = false }
                    showTagEditSheet = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "pencil")
                            .font(.system(size: 16))
                            .foregroundStyle(.blue)
                        Text("タグ名・色を編集")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 50)

                // 削除
                Button {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    withAnimation(.easeOut(duration: 0.2)) { showTagActionSheet = false }
                    showTagDeleteAlert = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundStyle(.red)
                        if tag.memos.count > 0 {
                            Text("削除（メモ\(tag.memos.count)件あり）")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.red)
                        } else {
                            Text("削除")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.red)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)

                Divider()

                // 閉じる
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showTagActionSheet = false }
                } label: {
                    Text("閉じる")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
            .padding(.horizontal, 40)
        }
        .transition(.opacity)
    }

    private func tabIndex(for tagID: UUID?) -> Int {
        // TabbedMemoListViewのtabItemsと同じ並び順で計算
        // label: "all"=すべて, "none"=タグなし, それ以外=タグID
        struct TabEntry: Comparable {
            let key: String
            let order: Int
            static func < (lhs: TabEntry, rhs: TabEntry) -> Bool { lhs.order < rhs.order }
        }
        var entries: [TabEntry] = []
        entries.append(TabEntry(key: "all", order: allTagSortOrder))
        entries.append(TabEntry(key: "none", order: noTagSortOrder))
        for tag in tags where tag.parentTagID == nil {
            entries.append(TabEntry(key: tag.id.uuidString, order: tag.sortOrder))
        }
        entries.sort()

        // タグなし選択時は「タグなし」タブへ
        guard let tagID = tagID else {
            return entries.firstIndex(where: { $0.key == "none" }) ?? 0
        }
        if let idx = entries.firstIndex(where: { $0.key == tagID.uuidString }) {
            return idx
        }
        return 0
    }

    private var parentOptions: [(id: String, name: String, color: Color)] {
        var list: [(String, String, Color)] = [("none", "タグなし", tagColor(for: 0))]
        let parentTags = tags.filter { $0.parentTagID == nil && !$0.isSystem }.sorted { $0.sortOrder < $1.sortOrder }
        for tag in parentTags {
            list.append((tag.id.uuidString, tag.name, tagColor(for: tag.colorIndex)))
        }
        return list
    }

    private var childOptions: [(id: String, name: String, color: Color)] {
        var list: [(String, String, Color)] = [("none", "子タグなし", tagColor(for: 0))]
        if let parentID = viewModel.selectedTagID {
            for tag in tags where tag.parentTagID == parentID {
                list.append((tag.id.uuidString, tag.name, tagColor(for: tag.colorIndex)))
            }
        }
        return list
    }

    private var selectedTagInfo: (name: String, color: Color) {
        if let tagID = viewModel.selectedTagID,
           let tag = tags.first(where: { $0.id == tagID }) {
            return (tag.name, tagColor(for: tag.colorIndex))
        }
        return ("タグなし", tagColor(for: 0))
    }

    private var selectedChildTagInfo: (name: String, color: Color)? {
        if let childID = viewModel.selectedChildTagID,
           let tag = tags.first(where: { $0.id == childID }) {
            return (tag.name, tagColor(for: tag.colorIndex))
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー: タイトル + タグ（タップでキーボード解除）
            headerRow
                .contentShape(Rectangle())
                .onTapGesture {
                    if isTextEditorFocused {
                        isTextEditorFocused = false
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            Divider()
            // 本文（右端はタグタブ分空ける）
            ZStack(alignment: .topTrailing) {
                // 本文入力（編集中はTextEditor、閲覧中はText）
                ZStack(alignment: .topLeading) {
                    if isEditing || !viewModel.inputText.isEmpty {
                        LineNumberTextEditor(
                            text: $viewModel.inputText,
                            isFocused: $isTextEditorFocused,
                            showLineNumbers: showLineNumbers,
                            initialCursorOffset: contentTapOffset
                        )
                        .padding(.leading, showLineNumbers ? 0 : 10)
                        .padding(.trailing, 4)
                        .padding(.top, 0)
                    } else {
                        ScrollView {
                            HStack(alignment: .top, spacing: 0) {
                                // 閲覧モードでも行番号表示
                                if showLineNumbers && !viewModel.inputText.isEmpty {
                                    ReadOnlyLineNumbers(text: viewModel.inputText)
                                        .frame(width: 36)
                                }
                                TappableReadOnlyText(
                                    text: viewModel.inputText.isEmpty ? " " : viewModel.inputText,
                                    font: .systemFont(ofSize: 17),
                                    textColor: viewModel.inputText.isEmpty
                                        ? .clear
                                        : .label,
                                    // 編集モード（GutteredTextView）と同じインセットで位置を揃える
                                    insets: UIEdgeInsets(top: 20, left: 6, bottom: 0, right: 4),
                                    lineFragmentPadding: 5,
                                    onTapAtOffset: { offset in
                                        contentTapOffset = viewModel.inputText.isEmpty ? nil : offset
                                        isEditing = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            isTextEditorFocused = true
                                        }
                                    }
                                )
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                // 編集モードと同じSwiftUIパディング
                                .padding(.leading, showLineNumbers ? 0 : 10)
                                .padding(.trailing, 4)
                            }
                            .padding(.bottom, 40)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isTextEditorFocused {
                                // 編集中に空白タップ → フォーカスだけ外す（スクロール位置保持）
                                isTextEditorFocused = false
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            } else if !isEditing {
                                // 閲覧中に空白タップ → 編集モードに入る
                                contentTapOffset = nil
                                isEditing = true
                                isTextEditorFocused = true
                            }
                        }
                    }

                    if viewModel.inputText.isEmpty && isEditing {
                        Text(viewModel.isMarkdown ? "タップでマークダウン編集..." : "メモを入力...")
                            .font(.system(size: 17))
                            .foregroundStyle(.gray.opacity(0.5))
                            .padding(.leading, showLineNumbers ? 48 : 21)
                            .padding(.trailing, 8)
                            .padding(.top, 20)
                            .padding(.bottom, 24)
                            .allowsHitTesting(false)
                    }
                }
                .frame(maxHeight: .infinity)

            }
            // ルーレット展開中は本文エリアの幅を変えない（長文の再レイアウト防止）
            .overlay {
                if showParentDial {
                    Color(uiColor: .systemBackground).opacity(0.5)
                        .allowsHitTesting(true)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) { showParentDial = false }
                        }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                // 展開/縮小ボタン（ルーレット非表示時のみ）
                if !showParentDial {
                    Button {
                        withAnimation(.spring(response: 0.35)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "arrow.down.forward.and.arrow.up.backward" : "arrow.up.backward.and.arrow.down.forward")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 21, height: 21)
                            .background(
                                Circle().fill(Color.blue.opacity(0.6))
                            )
                            .shadow(color: .black.opacity(0.2), radius: 2, x: -1, y: 1)
                    }
                    .padding(.trailing, 3)
                    .padding(.bottom, 3)
                }
            }
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 6) {
                    // 本文クリアボタン（編集中かつ本文があるときだけ表示）
                    if isTextEditorFocused && !viewModel.inputText.isEmpty {
                        Button {
                            showClearBodyAlert = true
                        } label: {
                            Image(systemName: "eraser")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle().fill(Color.orange.opacity(0.6))
                                )
                                .shadow(color: .black.opacity(0.2), radius: 2, x: 1, y: 1)
                        }
                    }
                    // 文字数カウンター（フロートバッジ）
                    if showCharCount && !viewModel.inputText.isEmpty {
                        Text("\(viewModel.inputText.count.formatted())文字")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color(uiColor: .systemBackground))
                                    .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                            )
                    }
                }
                .padding(.leading, 8)
                .padding(.bottom, 8)
            }
            // トレー外タップは本文オーバーレイで処理済み
            .overlay(alignment: .topTrailing) {
                // 仕切り線直下・右端からタグタブを生やす
                dialArea
                    .padding(.trailing, -15)
                    .offset(y: -1)
            }
            // タグ履歴ボタン（トレーの外に配置）
            .overlay(alignment: .bottomTrailing) {
                if showParentDial {
                    Button {
                        if showTagHistory {
                            showTagHistory = false
                        } else {
                            tagHistoryItems = TagHistory.recentHistory(context: modelContext)
                            showTagHistory = true
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: showTagHistory ? "chevron.down" : "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                            Text("履歴")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.trailing, 8)
                    .offset(y: 21)
                }
            }
            Divider()
            // フッター: 左=削除 右=コピー+保存（ルーレット展開中は無効）
            footerRow
                .disabled(showParentDial)
                .opacity(showParentDial ? 0.4 : 1)
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(uiColor: .systemBackground))
                RoundedRectangle(cornerRadius: 10)
                    .stroke(coloredFrame ? selectedTagInfo.color.opacity(0.5) : Color.gray.opacity(0.25), lineWidth: coloredFrame ? 2.5 : 1)
            }
        )
        .animation(.easeInOut(duration: 0.3), value: viewModel.selectedTagID)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .alert("本文をクリアします。よろしいですか？", isPresented: $showClearBodyAlert) {
            Button("クリア", role: .destructive) {
                viewModel.pushUndoIfNeeded()
                viewModel.inputText = ""
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("タイトルとタグはそのまま残ります。")
        }
        .alert("このメモを削除します。よろしいですか？", isPresented: $showDeleteAlert) {
            Button("削除", role: .destructive) {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    viewModel.discardMemo(context: modelContext)
                }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .sheet(isPresented: $showNewTagSheet) {
            NewTagSheetView(
                parentTagID: newTagIsChild ? viewModel.selectedTagID : nil,
                onTagCreated: { newTagID in
                    if newTagIsChild {
                        viewModel.selectedChildTagID = newTagID
                    } else {
                        viewModel.selectedTagID = newTagID
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            let idx = tabIndex(for: newTagID)
                            NotificationCenter.default.post(
                                name: .switchToTab, object: nil,
                                userInfo: ["tabIndex": idx]
                            )
                        }
                    }
                }
            )
        }
        // 親タグ未選択で子タグ追加しようとした時の警告
        .alert("親タグを選んでください", isPresented: $showNoParentAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("子タグを追加するには、先にルーレットで親タグを選択してください。")
        }
        // タグ長押しアクションシート（カスタムダイアログ）
        .overlay {
            if showTagActionSheet, let tag = longPressedTag {
                tagActionDialog(tag: tag)
            }
        }
        // タグ編集シート
        .sheet(isPresented: $showTagEditSheet) {
            if let tagID = longPressedTagID,
               let tag = tags.first(where: { $0.id == tagID }) {
                TagDetailEditView(
                    tag: tag,
                    titleLabel: longPressedIsChild ? "子タグの編集" : "親タグの編集"
                )
            }
        }
        // タグ削除確認ダイアログ
        .alert(
            tagDeleteAlertTitle,
            isPresented: $showTagDeleteAlert
        ) {
            Button("削除", role: .destructive) { deleteTag() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text(tagDeleteAlertMessage)
        }
        .onChange(of: focusInput) { _, newValue in
            if newValue { isEditing = true; isTextEditorFocused = true; focusInput = false }
        }
        .onChange(of: isTextEditorFocused) { _, focused in
            // フォーカス喪失→カーソルが消えるだけ（Viewは切り替えない、スクロール位置保持）
        }
        // キーボード非表示通知でフォーカス状態を同期
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isTextEditorFocused = false
        }
        .onChange(of: showParentDial) { _, isShowing in
            // ルーレット展開時はテキストのフォーカスを外す
            if isShowing {
                isTextEditorFocused = false
                showTagHistory = false
            } else {
                // ルーレットを閉じた時にタグ履歴を記録
                if let parentID = viewModel.selectedTagID {
                    TagHistory.record(parentTagID: parentID, childTagID: viewModel.selectedChildTagID, context: modelContext)
                }
                showTagHistory = false
            }
        }
        .onChange(of: viewModel.loadMemoCounter) { _, _ in
            // 既存メモ読み込み時もLineNumberTextEditorを表示（フォーカスなし）
            isEditing = true
            isTextEditorFocused = false
        }
        .onChange(of: viewModel.inputText) { _, newValue in
            // 最大文字数制限
            if newValue.count > MemoInputViewModel.maxCharacterCount {
                viewModel.inputText = String(newValue.prefix(MemoInputViewModel.maxCharacterCount))
            }
            viewModel.pushUndoIfNeeded()
            viewModel.onContentChanged(context: modelContext, tags: tags)
            showTagHistory = false
        }
        .onChange(of: viewModel.titleText) { _, _ in
            viewModel.pushUndoIfNeeded()
            viewModel.onTitleChanged()
        }
        .onChange(of: viewModel.selectedTagID) { _, newTagID in
            if !viewModel.isLoadingMemo {
                viewModel.pushUndoIfNeeded()
                viewModel.selectedChildTagID = nil
            }
            viewModel.onTagChanged(tags: tags)
            showTagHistory = false
        }
        .onChange(of: viewModel.selectedChildTagID) { _, _ in
            viewModel.pushUndoIfNeeded()
            viewModel.onTagChanged(tags: tags)
            showTagHistory = false
        }
        .onAppear {
            // dialDefault: 0=チラ見せ, 1=全開, 2=完全収納
            switch dialDefault {
            case 2:
                trayHidden = true
                showParentDial = false
            case 1:
                trayHidden = false
                showParentDial = true
            default:
                trayHidden = false
                showParentDial = false
            }
            showChildDial = true // 子ルーレット常時表示
        }

    }

    // MARK: - ヘッダー

    private var headerRow: some View {
        HStack(spacing: 0) {
            // タイトルエリア（残りスペースを使い切る）
            HStack(spacing: 4) {
                ZStack(alignment: .leading) {
                    // TextFieldは常に存在（フォーカス時のみ見える）
                    TextField("タイトル（任意）", text: $viewModel.titleText)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .focused($isTitleFocused)
                        .opacity(isTitleFocused ? 1 : 0)

                    // 非フォーカス時: Text + 自動縮小を上に重ねる
                    if !isTitleFocused {
                        Text(viewModel.titleText.isEmpty ? "タイトル（任意）" : viewModel.titleText)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(viewModel.titleText.isEmpty ? .gray.opacity(0.4) : .primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture { isTitleFocused = true }
                    }
                }

                // タイトル×ボタン（テキストがあるときだけ表示）
                if !viewModel.titleText.isEmpty {
                    Button {
                        viewModel.pushUndoIfNeeded()
                        viewModel.titleText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }

            // 縦線セパレータ
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 1, height: 24)
                .padding(.horizontal, 8)

            // タグエリア（内容に応じて可変幅）
            HStack(spacing: 4) {
                tagDisplay
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            trayHidden = false
                            showParentDial = true
                        }
                    }

                // タグ×ボタン（タグ選択中のみ表示）
                if viewModel.selectedTagID != nil {
                    Button {
                        viewModel.pushUndoIfNeeded()
                        viewModel.selectedTagID = nil
                        viewModel.selectedChildTagID = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private var tagDisplay: some View {
        HStack(spacing: 3) {
            if viewModel.selectedTagID == nil {
                // タグ未選択時はアイコンのみ
                Image(systemName: "tag")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
            } else {
                let info = selectedTagInfo
                if let childInfo = selectedChildTagInfo {
                    // 表示名を半角幅換算で制限（親: 10単位=全角5文字、子: 10単位）
                    let parentDisplay = truncateByWidth(info.name, maxWidth: 10)
                    let childDisplay = truncateByWidth(childInfo.name, maxWidth: 10)
                    // 親タグ＋右下に子タグめり込みデザイン
                    HStack(alignment: .bottom, spacing: -4) {
                        // 親タグ
                        Text(parentDisplay)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.leading, 7)
                            .padding(.trailing, 10)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 6).fill(info.color))
                        // 子タグ
                        Text(childDisplay)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4).fill(childInfo.color)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.white, lineWidth: 1.5)
                            )
                    }
                } else {
                    // 親タグのみ
                    Text(truncateByWidth(info.name, maxWidth: 12))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(info.color))
                }
            }
        }
    }

    // 半角幅換算で文字列を切り詰める（全角=2、半角=1）
    private func truncateByWidth(_ text: String, maxWidth: CGFloat) -> String {
        var width: CGFloat = 0
        var result = ""
        for ch in text {
            let w: CGFloat = ch.isASCII ? 1.0 : 2.0
            if width + w > maxWidth {
                return result + "…"
            }
            width += w
            result.append(ch)
        }
        return result
    }

    // MARK: - フッター（左=削除 右=コピー+閉じる）

    private var footerRow: some View {
        HStack(spacing: 16) {
            // 左: 削除
            Button {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                showDeleteAlert = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 18))
                    .foregroundStyle(.red.opacity(0.5))
            }
            .disabled(!viewModel.canClear)

            Spacer()

            // Undo/Redo（間隔広め）
            HStack(spacing: 20) {
                Button {
                    viewModel.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 16))
                }
                .disabled(!viewModel.canUndo)

                Button {
                    viewModel.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 16))
                }
                .disabled(!viewModel.canRedo)
            }

            Spacer().frame(width: 12)

            // コピー
            Button {
                UIPasteboard.general.string = viewModel.inputText
            } label: {
                Label("コピー", systemImage: "doc.on.doc").font(.system(size: 14))
            }
            .disabled(viewModel.inputText.isEmpty)

            // 右: 編集中→「確定」、それ以外→「メモを閉じる」
            if viewModel.editingMemo != nil {
                if isTextEditorFocused {
                    // 編集中（カーソルあり）→ カーソルを消すだけ（枠外タップと同じ）
                    Button {
                        isTextEditorFocused = false
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    } label: {
                        Label("確定", systemImage: "checkmark.circle").font(.system(size: 14))
                            .foregroundStyle(.blue)
                    }
                } else {
                    Button {
                        isTextEditorFocused = false
                        viewModel.clearInput()
                    } label: {
                        Label("メモを閉じる", systemImage: "xmark.circle").font(.system(size: 14))
                    }
                }
            } else if viewModel.hasText {
                // 新規メモでテキストがある場合のみ「確定」
                Button {
                    isTextEditorFocused = false
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    onConfirm?()
                } label: {
                    Label("確定", systemImage: "checkmark.circle").font(.system(size: 14))
                        .foregroundStyle(.blue)
                }
            }

        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }

    // MARK: - ルーレット（トレー方式）

    // ルーレットの固定高さ
    private let dialFixedHeight: CGFloat = 211
    // トレーの設定
    private let trayColor = Color.gray  // 子タグドロワーと統一
    private let trayCornerRadius: CGFloat = 10

    // タブ寸法
    private let tabWidth: CGFloat = 38      // タブの横幅（「タグ」テキスト分）
    private let tabHeight: CGFloat = 22     // タブの高さ（最初のデザインと同じ細さ）
    private let tabRadius: CGFloat = 6      // タブの左側角丸

    // チラ見せ量（閉じている時にルーレットがどれだけ覗くか）
    private let peekAmount: CGFloat = 10  // トレーチラ見せ量

    // トレー全体の幅（GeometryReaderで計測）
    @State private var trayTotalWidth: CGFloat = 300

    // 完全収納時に取っ手が覗く量
    private let hiddenPeekAmount: CGFloat = 34

    private var dialArea: some View {
        openTray
            .fixedSize(horizontal: true, vertical: false)
            .offset(x: trayHidden
                ? (trayTotalWidth - hiddenPeekAmount)  // 完全収納: 取っ手が少しだけ覗く
                : (showParentDial ? 0 : (trayTotalWidth - tabWidth)))  // 通常
            .animation(.spring(response: 0.3), value: showParentDial)
            .animation(.spring(response: 0.3), value: trayHidden)
    }

    // 一体型トレー（常時描画）
    private var openTray: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                TagDialView(
                    parentOptions: parentOptions,
                    parentSelectedID: $viewModel.selectedTagID,
                    childOptions: childOptions,
                    childSelectedID: $viewModel.selectedChildTagID,
                    showChild: $showChildDial,
                    isOpen: showParentDial,
                    childExternalDragY: $childExternalDragY,
                    onEditTag: { id, isChild in
                        if let uuid = UUID(uuidString: id) {
                            longPressedTagID = uuid
                            longPressedIsChild = isChild
                            showTagEditSheet = true
                        }
                    },
                    onDeleteTag: { id in
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        if let uuid = UUID(uuidString: id) {
                            longPressedTagID = uuid
                            showTagDeleteAlert = true
                        }
                    },
                    onLongPress: { id, name, color, isChild in
                        if let uuid = UUID(uuidString: id) {
                            longPressedTagID = uuid
                            longPressedIsChild = isChild
                            showTagActionSheet = true
                        }
                    }
                )
                .background {
                    // 外周弧の左端を模した図形に影をつける（弧に沿った自然な影、クリップ不要）
                    DialEdgeArcShape(radius: 350, dialHeight: 211)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.5), radius: 3, x: -2, y: 0)
                        .allowsHitTesting(false)
                }
                .offset(x: showParentDial ? -27 : -50, y: -10) // 開き時は右寄せ、閉じ時はチラ見せ
                .allowsHitTesting(showParentDial) // チラ見せ時はタッチ無効
                // 引き出し時: 右端の余白に「しまう」ボタン
                if showParentDial {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(maxHeight: .infinity)
                        .frame(width: 36)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) { showParentDial = false }
                        }
                }
            }
            .frame(height: dialFixedHeight)

            ZStack(alignment: .trailing) {
                Button {
                    newTagIsChild = false
                    showNewTagSheet = true
                } label: {
                    Label("親タグ追加", systemImage: "plus.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.trailing, 196) // 親タグラベル（200）の下あたり +36矢印ボタン分
                if showChildDial {
                    Button {
                        if viewModel.selectedTagID == nil {
                            // 親タグが「タグなし」の時は警告
                            showNoParentAlert = true
                        } else {
                            newTagIsChild = true
                            showNewTagSheet = true
                        }
                    } label: {
                        Label("子タグ追加", systemImage: "plus.circle")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.trailing, 86) // 子タグラベル（83）の下あたり +36矢印ボタン分
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.vertical, 4)
            .offset(y: -13)
        }
        // コンテンツをボディ領域に配置（タブの右＋下）
        .padding(.top, tabHeight + 10)
        .padding(.bottom, 6) // タイトル欄拡大分をトレー下端で吸収
        .padding(.leading, tabWidth + 12)
        .padding(.trailing, 12)
        .background(
            GeometryReader { geo in
                TrayWithTabShape(
                    tabWidth: tabWidth,
                    tabHeight: tabHeight,
                    tabRadius: tabRadius,
                    bodyRadius: trayCornerRadius,
                    bodyPeek: showParentDial ? 0 : peekAmount
                )
                .fill(trayColor)
                .shadow(color: .black.opacity(0.2), radius: 3, x: -2, y: 0)
                .onAppear { trayTotalWidth = geo.size.width }
                .onChange(of: geo.size.width) { _, newW in trayTotalWidth = newW }
            }
        )
        // 余白タップでトレーを閉じる（ルーレット表示中のみ）
        .contentShape(showParentDial ? AnyShape(Rectangle()) : AnyShape(Rectangle().size(.zero)))
        .onTapGesture {
            if showParentDial {
                withAnimation(.spring(response: 0.3)) { showParentDial = false }
            }
        }
        // ルーレットラベル（展開時のみ、取っ手の帯と同じ高さに表示）
        .overlay(alignment: .topTrailing) {
            if showParentDial && !trayHidden {
                ZStack(alignment: .trailing) {
                    Text("親タグ")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(height: tabHeight)
                        .padding(.trailing, 236) // 親セクター中央 +36矢印ボタン分
                    if showChildDial {
                        Text("子タグ")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(height: tabHeight)
                            .padding(.trailing, 119) // 子セクター中央 +36矢印ボタン分
                    }
                }
            }
        }
        // タブテキストを左上に配置
        .overlay(alignment: .topLeading) {
            HStack(spacing: 2) {
                if trayHidden {
                    // 完全収納時: 矢印だけ
                    Text("◀").font(.system(size: 12))
                } else {
                    Text(showParentDial ? "しまう" : "タグ").font(.system(size: 13, weight: .bold, design: .rounded))
                }
            }
            .foregroundStyle(.white)
            .frame(width: trayHidden ? hiddenPeekAmount : tabWidth, height: tabHeight, alignment: .leading)
            .padding(.leading, trayHidden ? 4 : 3)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3)) {
                    if trayHidden {
                        // 完全収納 → 全開
                        trayHidden = false
                        showParentDial = true
                    } else if showParentDial {
                        // 全開 → チラ見せ
                        showParentDial = false
                    } else {
                        // チラ見せ → 全開
                        showParentDial = true
                    }
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        let horizontal = value.translation.width
                        // 右スワイプ → 完全収納
                        if horizontal > 40 {
                            withAnimation(.spring(response: 0.3)) {
                                showParentDial = false
                                trayHidden = true
                            }
                        }
                        // 左スワイプ → 全開
                        if horizontal < -40 {
                            withAnimation(.spring(response: 0.3)) {
                                trayHidden = false
                                showParentDial = true
                            }
                        }
                    }
            )
        }
    }

    // MARK: - タグ履歴リスト

    private var tagHistoryList: some View {
        VStack(spacing: 0) {
            // 閉じるボタン
            HStack {
                Text("タグ履歴")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showTagHistory = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            if tagHistoryItems.isEmpty {
                Text("まだ履歴がありません")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(tagHistoryItems, id: \.id) { item in
                            if let parentTag = tags.first(where: { $0.id == item.parentTagID }) {
                                Button {
                                    viewModel.selectedTagID = parentTag.id
                                    if let childID = item.childTagID {
                                        viewModel.selectedChildTagID = childID
                                    } else {
                                        viewModel.selectedChildTagID = nil
                                    }
                                    showTagHistory = false
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(parentTag.name)
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(
                                                RoundedRectangle(cornerRadius: 5)
                                                    .fill(tagColor(for: parentTag.colorIndex))
                                            )
                                        if let childID = item.childTagID,
                                           let childTag = tags.first(where: { $0.id == childID }) {
                                            Text(childTag.name)
                                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .fill(tagColor(for: childTag.colorIndex))
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                                )
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
        )
        .frame(maxWidth: 220)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, 8)
    }

    // 子ダイアル開閉ボタン（トレー内）
    private var childDialToggle: some View {
        ZStack {
            if showChildDial {
                Text("›")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 14, height: 60)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.15)))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) { showChildDial = false }
                    }
            } else {
                VStack(spacing: 2) {
                    Text("子").font(.system(size: 11, weight: .bold, design: .rounded))
                    Text("‹").font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 20, height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.15))
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) { showChildDial = true }
                }
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    if !showChildDial { showChildDial = true }
                    childExternalDragY = value.translation.height
                }
                .onEnded { _ in childExternalDragY = nil }
        )
    }
}

// タブ + トレー一体型シェイプ
//
//  ┌────────┐
//  │  タブ   ├───────────────┐
//  └────────┤               │
//           │  トレー本体    │
//           │               │
//           └───────────────┘
//
struct TrayWithTabShape: Shape {
    let tabWidth: CGFloat
    let tabHeight: CGFloat
    let tabRadius: CGFloat
    let bodyRadius: CGFloat
    var bodyPeek: CGFloat = 0  // ボディが取っ手エリアに侵入する幅
    var innerRadius: CGFloat = 10  // 取っ手とボディの内側角の丸み

    func path(in rect: CGRect) -> Path {
        // タブ: (0,0) → (tabWidth, tabHeight) 左上に飛び出す
        // ボディ: (bodyLeftX, tabHeight) → (maxX, maxY)
        let bodyTop = tabHeight
        let bodyLeftX = tabWidth - bodyPeek  // peekぶんだけ左に伸ばす
        let ir = min(innerRadius, bodyTop)  // 内側角の丸み（はみ出し防止）

        var p = Path()

        // 1. タブ左上角（丸み）
        p.move(to: CGPoint(x: 0, y: tabRadius))
        p.addArc(center: CGPoint(x: tabRadius, y: tabRadius),
                 radius: tabRadius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)

        // 2. タブ上辺 → 右端まで
        p.addLine(to: CGPoint(x: rect.maxX, y: 0))

        // 3. 右辺を下へ
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))

        // 4. ボディ下辺 → ボディ左下角（丸み）
        p.addLine(to: CGPoint(x: bodyLeftX + bodyRadius, y: rect.maxY))
        p.addArc(center: CGPoint(x: bodyLeftX + bodyRadius, y: rect.maxY - bodyRadius),
                 radius: bodyRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)

        // 5. ボディ左辺を上へ → 内側角の手前まで
        p.addLine(to: CGPoint(x: bodyLeftX, y: bodyTop + ir))

        // 5.5. 内側角の丸み（凹カーブ: 時計回り）
        p.addArc(center: CGPoint(x: bodyLeftX - ir, y: bodyTop + ir),
                 radius: ir, startAngle: .degrees(0), endAngle: .degrees(270), clockwise: true)

        // 6. タブ下辺を左へ（左下角の丸み分手前まで）
        p.addLine(to: CGPoint(x: tabRadius, y: bodyTop))

        // 7. タブ左下角（丸み）
        p.addArc(center: CGPoint(x: tabRadius, y: bodyTop - tabRadius),
                 radius: tabRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)

        // 8. タブ左辺を上へ → 始点に戻る
        p.closeSubpath()

        return p
    }
}

// ルーレット外周弧の左端を模した図形（影専用）
struct DialEdgeArcShape: Shape {
    var radius: CGFloat
    var dialHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        // TagDialViewと同じ座標系: cx = radius + 2, cy = dialHeight / 2
        let cx = radius + 2
        let cy = dialHeight / 2
        let halfH = dialHeight / 2
        let maxSin = min(1.0, Double(halfH / radius))
        let maxAngle = asin(maxSin) * 180.0 / .pi
        // 弧の幅（薄い三日月形にする）
        let thickness: CGFloat = 20
        var p = Path()
        // 外側の弧
        p.addArc(center: CGPoint(x: cx, y: cy), radius: radius,
                 startAngle: .degrees(180.0 - maxAngle), endAngle: .degrees(180.0 + maxAngle), clockwise: false)
        // 内側の弧（逆向き）
        p.addArc(center: CGPoint(x: cx, y: cy), radius: radius - thickness,
                 startAngle: .degrees(180.0 + maxAngle), endAngle: .degrees(180.0 - maxAngle), clockwise: true)
        p.closeSubpath()
        return p
    }
}
