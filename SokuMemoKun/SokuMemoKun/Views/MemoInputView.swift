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
    @FocusState private var isTextEditorFocused: Bool

    // 新規タグ作成シート
    @State private var showNewTagSheet = false
    @State private var newTagIsChild = false
    // 既存メモ読み込み時は閲覧モード（タップで編集開始）
    @State private var isEditing = true
    // 削除確認ダイアログ
    @State private var showDeleteAlert = false
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
        let parentTags = tags.filter { $0.parentTagID == nil }.sorted { $0.sortOrder < $1.sortOrder }
        for tag in parentTags {
            list.append((tag.id.uuidString, tag.name, tagColor(for: tag.colorIndex)))
        }
        return list
    }

    private var childOptions: [(id: String, name: String, color: Color)] {
        var list: [(String, String, Color)] = [("none", "なし", tagColor(for: 0))]
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
            // ヘッダー: タイトル + タグ
            headerRow
            Divider()
            // 本文（右端はタグタブ分空ける）
            ZStack(alignment: .topTrailing) {
                // 本文入力（編集中はTextEditor、閲覧中はText）
                ZStack(alignment: .topLeading) {
                    if isEditing {
                        TextEditor(text: $viewModel.inputText)
                            .font(.system(size: 17))
                            .padding(.leading, 10)
                            .padding(.trailing, 4)
                            .padding(.top, 16)
                            .contentMargins(.bottom, 40, for: .scrollContent)
                            .focused($isTextEditorFocused)
                    } else {
                        ScrollView {
                            Text(viewModel.inputText.isEmpty ? " " : viewModel.inputText)
                                .font(.system(size: 17))
                                .foregroundStyle(viewModel.inputText.isEmpty ? .clear : .primary)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .padding(.leading, 15)
                                .padding(.trailing, 9)
                                .padding(.top, 24)
                                .padding(.bottom, 40)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isEditing = true
                            isTextEditorFocused = true
                        }
                    }

                    if viewModel.inputText.isEmpty && isEditing {
                        Text(viewModel.isMarkdown ? "タップでマークダウン編集..." : "メモを入力...")
                            .font(.system(size: 17))
                            .foregroundStyle(.gray.opacity(0.5))
                            .padding(.leading, 14)
                            .padding(.trailing, 8)
                            .padding(.vertical, 24)
                            .allowsHitTesting(false)
                    }
                }
                .frame(maxHeight: .infinity)

            }
            .padding(.trailing, showParentDial ? (showChildDial ? 185 : 135) : 0)
            .animation(.spring(response: 0.3), value: showParentDial)
            .animation(.spring(response: 0.3), value: showChildDial)
            .onTapGesture {
                // トレー外タップで収納
                if showParentDial {
                    withAnimation(.spring(response: 0.3)) { showParentDial = false }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                // 展開/縮小ボタン
                Button {
                    withAnimation(.spring(response: 0.35)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "arrow.down.forward.and.arrow.up.backward" : "arrow.up.backward.and.arrow.down.forward")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle().fill(Color.blue.opacity(0.6))
                        )
                        .shadow(color: .black.opacity(0.2), radius: 2, x: -1, y: 1)
                }
                .padding(.trailing, 8)
                .padding(.bottom, 8)
            }
            .overlay(alignment: .topTrailing) {
                // 仕切り線直下・右端からタグタブを生やす
                dialArea
                    .padding(.trailing, -15)
                    .offset(y: -1)
            }
            Divider()
            // フッター: 左=削除 右=コピー+保存
            footerRow
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(uiColor: .systemBackground))
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
            }
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .alert("このメモを削除します。よろしいですか？", isPresented: $showDeleteAlert) {
            Button("削除", role: .destructive) {
                viewModel.discardMemo(context: modelContext)
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
        // タグ長押しアクションシート
        .confirmationDialog(
            longPressedTag != nil ? "「\(longPressedTag!.name)」" : "タグの操作",
            isPresented: $showTagActionSheet,
            titleVisibility: .visible
        ) {
            Button("タグ名・色を編集") { showTagEditSheet = true }
            if let tag = longPressedTag, tag.memos.count > 0 {
                Button("削除（メモ\(tag.memos.count)件あり）", role: .destructive) { showTagDeleteAlert = true }
            } else {
                Button("削除", role: .destructive) { showTagDeleteAlert = true }
            }
            Button("キャンセル", role: .cancel) {}
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
        .onChange(of: viewModel.loadMemoCounter) { _, _ in
            // 既存メモ読み込み時は閲覧モードで開始
            isEditing = false
            isTextEditorFocused = false
        }
        .onChange(of: viewModel.inputText) { _, _ in
            viewModel.onContentChanged(context: modelContext, tags: tags)
        }
        .onChange(of: viewModel.titleText) { _, _ in
            viewModel.onTitleChanged()
        }
        .onChange(of: viewModel.selectedTagID) { _, newTagID in
            if !viewModel.isLoadingMemo { viewModel.selectedChildTagID = nil }
            viewModel.onTagChanged(tags: tags)
            // フォルダ移動はルーレット操作時のみ（switchToTabはTagDialViewから直接発火）
        }
        .onChange(of: viewModel.selectedChildTagID) { _, _ in
            viewModel.onTagChanged(tags: tags)
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
        HStack(spacing: 6) {
            TextField("タイトル（任意）", text: $viewModel.titleText)
                .font(.system(size: 17, weight: .semibold, design: .rounded))

            Spacer()

            // タグ表示（タップでルーレット展開）
            tagDisplay
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) {
                        showParentDial = true
                    }
                }
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
                Text(info.name.prefix(4) + (info.name.count > 4 ? "…" : ""))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 5).fill(info.color))
                if let childInfo = selectedChildTagInfo {
                    Text(childInfo.name.prefix(3) + (childInfo.name.count > 3 ? "…" : ""))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(RoundedRectangle(cornerRadius: 4).fill(childInfo.color))
                }
            }
        }
    }

    // MARK: - フッター（左=削除 右=コピー+閉じる）

    private var footerRow: some View {
        HStack(spacing: 8) {
            // 左: 削除
            Button { showDeleteAlert = true } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15))
                    .foregroundStyle(.red.opacity(0.5))
            }
            .disabled(!viewModel.canClear)

            Spacer()

            // 右: コピー
            Button {
                UIPasteboard.general.string = viewModel.inputText
            } label: {
                Label("コピー", systemImage: "doc.on.doc").font(.system(size: 14))
            }
            .disabled(viewModel.inputText.isEmpty)

            // 右: 差分あり→「確定」、差分なし→「閉じる」（既存メモを開いている時のみ表示）
            if viewModel.editingMemo != nil {
                if hasDiff {
                    Button {
                        isEditing = true
                        isTextEditorFocused = false
                        onConfirm?()
                    } label: {
                        Label("確定", systemImage: "checkmark.circle").font(.system(size: 14))
                            .foregroundStyle(.blue)
                    }
                } else {
                    Button {
                        isEditing = true
                        isTextEditorFocused = false
                        viewModel.clearInput()
                    } label: {
                        Label("閉じる", systemImage: "xmark.circle").font(.system(size: 14))
                    }
                }
            } else if viewModel.canClear {
                // 新規メモで内容がある場合も「確定」
                Button {
                    isEditing = true
                    isTextEditorFocused = false
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
    private let tabWidth: CGFloat = 80      // タブの横幅（「◀ タグ付け」テキスト分）
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
                        if let uuid = UUID(uuidString: id) {
                            longPressedTagID = uuid
                            showTagDeleteAlert = true
                        }
                    }
                )
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
                .shadow(color: .black.opacity(0.2), radius: 3, x: -2, y: 2)
                .onAppear { trayTotalWidth = geo.size.width }
                .onChange(of: geo.size.width) { _, newW in trayTotalWidth = newW }
            }
        )
        // 余白タップでトレーを閉じる（ルーレット上のタップはTagDialView側で消費）
        .contentShape(Rectangle())
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
                    Text(showParentDial ? "▶" : "◀").font(.system(size: 12))
                    Text(showParentDial ? "しまう" : "タグ付け").font(.system(size: 13, weight: .bold, design: .rounded))
                }
            }
            .foregroundStyle(.white)
            .frame(width: trayHidden ? hiddenPeekAmount : tabWidth, height: tabHeight, alignment: .leading)
            .padding(.leading, trayHidden ? 4 : 6)
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
        }
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
                        .fill(Color.white.opacity(0.2))
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
