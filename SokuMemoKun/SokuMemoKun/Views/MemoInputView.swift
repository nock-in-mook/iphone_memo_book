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
    // ルーレット展開状態
    @State private var showParentDial = false
    @State private var showChildDial = false
    @State private var childExternalDragY: CGFloat? = nil
    @AppStorage("dialDefault") private var dialDefault: Int = 0

    @AppStorage("allTagSortOrder") private var allTagSortOrder: Int = -1
    @AppStorage("noTagSortOrder") private var noTagSortOrder: Int = 9999

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
        for tag in tags where tag.parentTagID == nil {
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
                    .padding(.trailing, -10)
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
            showParentDial = dialDefault >= 1
            showChildDial = dialDefault >= 2
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
        .padding(.vertical, 6)
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
    private let dialFixedHeight: CGFloat = 160
    // トレーの設定
    private let trayColor = Color(red: 0.76, green: 0.76, blue: 0.78)
    private let trayCornerRadius: CGFloat = 10

    // タブ寸法
    private let tabWidth: CGFloat = 70      // タブの横幅
    private let tabHeight: CGFloat = 22     // タブの高さ（最初のデザインと同じ細さ）
    private let tabRadius: CGFloat = 6      // タブの左側角丸

    private var dialArea: some View {
        Group {
            if showParentDial {
                openTray
                    .transition(.move(edge: .trailing))
            } else {
                closedTab
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    // 閉じている時のタブ
    private var closedTab: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                Text("◀").font(.system(size: 12))
                Text("タグ付け").font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(width: tabWidth, height: tabHeight, alignment: .leading)
            .padding(.leading, 6)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: tabRadius,
                    bottomLeadingRadius: tabRadius,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0
                )
                .fill(trayColor)
                .shadow(color: .black.opacity(0.15), radius: 2, x: -1, y: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3)) { showParentDial = true }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        if value.translation.width < -10 {
                            withAnimation(.spring(response: 0.3)) { showParentDial = true }
                        }
                    }
            )
            Spacer(minLength: 0)
        }
    }

    // 展開時: タブがトレーの左上から飛び出した一体型
    private var openTray: some View {
        // GeometryReaderでトレー本体の実サイズを取得し、
        // その上にタブが飛び出すShapeを正確に描画する
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                TagDialView(
                    parentOptions: parentOptions,
                    parentSelectedID: $viewModel.selectedTagID,
                    childOptions: childOptions,
                    childSelectedID: $viewModel.selectedChildTagID,
                    showChild: $showChildDial,
                    childExternalDragY: $childExternalDragY
                )
                childDialToggle
            }
            .frame(height: dialFixedHeight)

            HStack(spacing: 6) {
                Button {
                    newTagIsChild = false
                    showNewTagSheet = true
                } label: {
                    Label("親タグ追加", systemImage: "plus.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                if showChildDial {
                    Button {
                        newTagIsChild = true
                        showNewTagSheet = true
                    } label: {
                        Label("子タグ追加", systemImage: "plus.circle")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .padding(.vertical, 4)
        }
        // コンテンツをボディ領域に配置（タブの右＋下）
        .padding(.top, tabHeight + 10)
        .padding(.bottom, 10)
        .padding(.leading, tabWidth + 12)
        .padding(.trailing, 12)
        .background(
            TrayWithTabShape(
                tabWidth: tabWidth,
                tabHeight: tabHeight,
                tabRadius: tabRadius,
                bodyRadius: trayCornerRadius
            )
            .fill(trayColor)
            .shadow(color: .black.opacity(0.2), radius: 3, x: -2, y: 2)
        )
        // タブテキストを左上に配置
        .overlay(alignment: .topLeading) {
            HStack(spacing: 2) {
                Text("▶").font(.system(size: 12))
                Text("しまう").font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(width: tabWidth, height: tabHeight, alignment: .leading)
            .padding(.leading, 6)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3)) {
                    showParentDial = false; showChildDial = false
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

    func path(in rect: CGRect) -> Path {
        // タブ: (0,0) → (tabWidth, tabHeight) 左上に飛び出す
        // ボディ: (tabWidth, tabHeight) → (maxX, maxY)
        let bodyTop = tabHeight

        var p = Path()

        // 1. タブ左上角（丸み）
        p.move(to: CGPoint(x: 0, y: tabRadius))
        p.addArc(center: CGPoint(x: tabRadius, y: tabRadius),
                 radius: tabRadius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)

        // 2. タブ上辺 → 右端まで（ボディ上辺と同じ高さ）
        p.addLine(to: CGPoint(x: rect.maxX, y: 0))

        // 3. 右辺を下へ
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))

        // 4. ボディ下辺 → ボディ左下角（丸み）
        p.addLine(to: CGPoint(x: tabWidth + bodyRadius, y: rect.maxY))
        p.addArc(center: CGPoint(x: tabWidth + bodyRadius, y: rect.maxY - bodyRadius),
                 radius: bodyRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)

        // 5. ボディ左辺を上へ → タブ下辺
        p.addLine(to: CGPoint(x: tabWidth, y: bodyTop))

        // 6. タブ下辺を左へ（左下角の丸み分手前まで）
        p.addLine(to: CGPoint(x: tabRadius, y: bodyTop))

        // 9. タブ左下角（丸み）
        p.addArc(center: CGPoint(x: tabRadius, y: bodyTop - tabRadius),
                 radius: tabRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)

        // 10. タブ左辺を上へ → 始点に戻る
        p.closeSubpath()

        return p
    }
}
