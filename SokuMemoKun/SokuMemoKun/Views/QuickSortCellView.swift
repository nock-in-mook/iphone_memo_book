import SwiftUI
import SwiftData

// 編集モード（親子間で共有）
enum CellEditMode: Equatable {
    case none, title, content, tag
}

// セル内包方式: メモカード（上）→ ルーレット（中）
// コントローラーエリアは親ビュー側に固定配置
struct QuickSortCellView: View {
    let memo: Memo
    var isActive: Bool = false
    @Binding var editMode: CellEditMode
    // セル内で直接キーボード高さを監視（UICollectionView経由だと伝播しないため）
    @State private var keyboardHeight: CGFloat = 0

    // ルーレット領域の高さ
    static let dialAreaHeight: CGFloat = 250

    // コールバック（親ビューへの通知）
    var onTagChanged: (UUID) -> Void = { _ in }
    var onTitleChanged: (UUID) -> Void = { _ in }
    var onDelete: (Memo) -> Void = { _ in }
    var onNewTagSheet: (_ isChild: Bool, _ parentTagID: UUID?) -> Void = { _, _ in }

    @Query(sort: \Tag.name) private var tags: [Tag]
    @Environment(\.modelContext) private var modelContext

    // ローカルタグ状態（セル独立 → 親ビューの再描画ゼロ）
    @State private var selectedParentTagID: UUID?
    @State private var selectedChildTagID: UUID?
    @State private var showChildDial = true
    @State private var childExternalDragY: CGFloat?
    @State private var isInternalTagChange = false

    // タイトル編集（インライン）
    @State private var editingTitle: String = ""
    @FocusState private var isTitleFocused: Bool

    // 本文インライン編集
    @State private var editingContent: String = ""
    @State private var isContentEditing = false
    @State private var isContentFocused = false
    /// タップ位置のカーソルオフセット（nil=末尾）
    @State private var contentTapOffset: Int?
    /// 本文タップ経由で編集開始したか（カード自動拡大を抑制）
    @State private var editFromTap = false

    // ピカピカアニメーション
    @State private var flashTag = false
    @State private var flashTitle = false

    // 削除確認
    @State private var showDeleteConfirm = false

    // ルーレット表示（タグ編集ボタンで切替）
    @State private var showDialArea = false

    // ロックアイコンフラッシュ
    @State private var lockIconFlash = false

    // 閲覧時カード拡大
    @State private var isExpanded = false
    @State private var showExpandButton = false


    var body: some View {
        GeometryReader { geo in
            let cardW = geo.size.width * 0.80
            // ルーレット表示中は本文拡大しない（共存禁止）
            // キーボード表示中はカードがキーボードに被らないよう制限
            let normalH = geo.size.height * 0.35
            let editH = geo.size.height * 0.55
            let expandedH = geo.size.height * 0.80
            // isExpanded最優先、ルーレット中は通常サイズ、タップ編集はnormalH維持
            let baseCardH = showDialArea ? normalH
                           : isExpanded ? expandedH
                           : isContentEditing ? (editFromTap ? normalH : editH)
                           : isTitleFocused ? editH
                           : normalH
            let maxCardH = keyboardHeight > 0 ? geo.size.height - keyboardHeight - 20 : geo.size.height * 0.80
            let cardH = min(baseCardH, maxCardH)

            VStack(spacing: 0) {
                    Spacer(minLength: 12)

                    // ── メモカード（タイトル+本文+タグフッター）──
                    memoCard
                        .frame(width: cardW, height: cardH)
                        .frame(maxWidth: .infinity)
                        .animation(.easeInOut(duration: 0.25), value: isContentEditing)
                        .animation(.easeInOut(duration: 0.25), value: isExpanded)
                        .animation(.easeInOut(duration: 0.25), value: isTitleFocused)
                        .animation(.easeInOut(duration: 0.25), value: showDialArea)
                        .animation(.easeInOut(duration: 0.25), value: keyboardHeight)

                    Spacer(minLength: 10)

                    // ── ルーレット（タグ編集時のみ表示）──
                    if showDialArea {
                        dialArea
                            .frame(height: QuickSortCellView.dialAreaHeight, alignment: .top)
                            .clipped()
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }

                    Spacer(minLength: 0)
            }
            // 全体の背景タップで編集解除
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { dismissEditing() }
            )
        }
        .onAppear {
            initFromMemo()
            editingTitle = memo.title
            editingContent = memo.content
        }
        .onChange(of: memo.tags.map(\.id)) { _, _ in initFromMemo() }
        .onChange(of: memo.id) { _, _ in
            // 編集中なら前のメモの変更を保存してから切替
            commitTitle()
            if isContentEditing { commitContent() }
            initFromMemo()
            editingTitle = memo.title
            editingContent = memo.content
            isContentEditing = false
            isExpanded = false
            showExpandButton = false
            flashTag = false
            flashTitle = false
        }
        .onChange(of: selectedParentTagID) { oldVal, newVal in
            guard !isInternalTagChange else { return }
            if oldVal != newVal { selectedChildTagID = nil }
            applyTagFromDial()
        }
        .onChange(of: selectedChildTagID) { _, _ in
            guard !isInternalTagChange else { return }
            applyTagFromDial()
        }
        .onChange(of: isTitleFocused) { _, focused in
            if focused {
                // 直接タップでフォーカスされた場合もeditModeを同期
                if editMode != .title { editMode = .title }
            } else {
                commitTitle()
                if editMode == .title { editMode = .none }
            }
        }
        .onChange(of: isContentFocused) { _, focused in
            if !focused {
                commitContent(); isContentEditing = false; editFromTap = false
                if editMode == .content { editMode = .none }
            }
        }
        .onChange(of: isActive) { _, active in
            if active { triggerFlash() }
            else { flashTag = false; flashTitle = false }
        }
        // 外部からの編集モード変更に応答
        .onChange(of: editMode) { _, newMode in
            applyEditMode(newMode)
        }
        .overlay {
            if showDeleteConfirm {
                deleteConfirmDialog
            }
        }
        // セル内で直接キーボード高さを監視（カスタムキーボード対応）
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                let screenHeight = UIScreen.main.bounds.height
                let kbH = screenHeight - frame.origin.y
                keyboardHeight = kbH > 0 ? kbH : 0
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
    }

    // MARK: - 削除確認ダイアログ（リッチ）

    private var deleteConfirmDialog: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) { showDeleteConfirm = false }
                }

            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.red.opacity(0.8))

                    Text("メモを削除します")
                        .font(.system(size: 17, weight: .bold, design: .rounded))

                    Text("よろしいですか？")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)

                    Text("「完了」画面で復元できます。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary.opacity(0.7))
                        .padding(.top, 2)
                }
                .padding(.top, 24)
                .padding(.bottom, 16)
                .padding(.horizontal, 20)

                Divider()

                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showDeleteConfirm = false }
                    onDelete(memo)
                } label: {
                    Text("削除する")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)

                Divider()

                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showDeleteConfirm = false }
                } label: {
                    Text("キャンセル")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.2), radius: 16, y: 6)
            .padding(.horizontal, 40)
        }
        .transition(.opacity)
    }

    // MARK: - 初期化

    private func initFromMemo() {
        let parentTag = memo.tags.first(where: { $0.parentTagID == nil })
        let childTag = memo.tags.first(where: { $0.parentTagID != nil })
        let newParentID = parentTag?.id
        let newChildID = childTag?.id
        let needsUpdate = (newParentID != selectedParentTagID) || (newChildID != selectedChildTagID)
        guard needsUpdate else { return }
        isInternalTagChange = true
        selectedParentTagID = newParentID
        selectedChildTagID = newChildID
        if parentTag != nil {
            let hasChildren = tags.contains(where: { $0.parentTagID == parentTag?.id })
            if hasChildren { showChildDial = true }
        }
        DispatchQueue.main.async { isInternalTagChange = false }
    }

    // MARK: - タグ操作

    private func applyTagFromDial() {
        let originalTags = Set(memo.tags.map { $0.id })
        memo.tags.removeAll()
        if let pid = selectedParentTagID, let tag = tags.first(where: { $0.id == pid }) { memo.tags.append(tag) }
        if let cid = selectedChildTagID, let tag = tags.first(where: { $0.id == cid }) { memo.tags.append(tag) }
        let newTags = Set(memo.tags.map { $0.id })
        if originalTags != newTags {
            memo.updatedAt = Date()
            onTagChanged(memo.id)
        }
    }

    // MARK: - タイトル確定

    private func commitTitle() {
        let newTitle = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if newTitle != memo.title {
            memo.title = newTitle
            memo.updatedAt = Date()
            if !newTitle.isEmpty { onTitleChanged(memo.id) }
        }
    }

    // MARK: - 本文確定

    private func commitContent() {
        if editingContent != memo.content {
            memo.content = editingContent
            memo.updatedAt = Date()
        }
    }

    // 枠外タップで全フォーカス解除
    private func dismissEditing() {
        isTitleFocused = false
        isContentFocused = false
        commitTitle()
        if isContentEditing {
            commitContent()
            isContentEditing = false
        }
        if showDialArea {
            withAnimation(.easeInOut(duration: 0.25)) { showDialArea = false }
        }
        editMode = .none
    }

    // 外部からの編集モード切替
    private func applyEditMode(_ mode: CellEditMode) {
        showExpandButton = false
        // isExpanded はユーザーが明示的に縮小するまで保持する

        switch mode {
        case .none:
            isTitleFocused = false
            if isContentEditing { commitContent(); isContentEditing = false; isContentFocused = false }
            if showDialArea { withAnimation(.easeInOut(duration: 0.25)) { showDialArea = false } }
            commitTitle()
        case .title:
            if isContentEditing { commitContent(); isContentEditing = false; isContentFocused = false }
            if showDialArea { withAnimation(.easeInOut(duration: 0.25)) { showDialArea = false } }
            if !isTitleFocused { isTitleFocused = true }
            flashTitle = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { flashTitle = false }
        case .content:
            commitTitle()
            isTitleFocused = false
            if showDialArea { withAnimation(.easeInOut(duration: 0.25)) { showDialArea = false } }
            editingContent = memo.content
            contentTapOffset = nil  // ボタン経由 → 末尾カーソル
            editFromTap = false     // ボタン経由 → カード拡大OK
            isContentEditing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isContentFocused = true }
        case .tag:
            commitTitle()
            isTitleFocused = false
            if isContentEditing { commitContent(); isContentEditing = false; isContentFocused = false }
            withAnimation(.easeInOut(duration: 0.25)) { showDialArea = true }
        }
    }

    // MARK: - ピカピカアニメーション

    private func triggerFlash() {
        let noTag = selectedParentTagID == nil
        let noTitle = memo.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if noTag {
            flashTag = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeInOut(duration: 0.25).repeatCount(5, autoreverses: true)) {
                    flashTag = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.7) {
                withAnimation(.easeOut(duration: 0.3)) { flashTag = false }
            }
        }
        if noTitle {
            flashTitle = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeInOut(duration: 0.25).repeatCount(5, autoreverses: true)) {
                    flashTitle = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.7) {
                withAnimation(.easeOut(duration: 0.3)) { flashTitle = false }
            }
        }
    }

    // MARK: - メモカード（CardWithTabShape一体成型 + 鉛筆ボタン）

    private var memoCard: some View {
        let parentTag = memo.tags.first(where: { $0.parentTagID == nil })
        let borderColor: Color = parentTag != nil ? tagColor(for: parentTag!.colorIndex) : Color.clear
        let tabH: CGFloat = 34
        let cardShape = CardWithTabShape(tabRatio: 0.68, tabHeight: tabH)

        return GeometryReader { geo in
            let tabW = geo.size.width * 0.68

            ZStack(alignment: .topLeading) {
                // カード全体（タブ＋本体を1つのShapeで描画）
                VStack(alignment: .leading, spacing: 0) {
                    // タイトルタブ領域
                    TextField("タイトルなし", text: $editingTitle)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .focused($isTitleFocused)
                        .onSubmit { isTitleFocused = false }
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .frame(height: tabH - 2, alignment: .leading)
                        .frame(width: tabW, alignment: .leading)
                        .background(
                            (flashTitle || editMode == .title)
                                ? Color.orange.opacity(flashTitle ? 0.45 : 0.35)
                                : Color.orange.opacity(0.18)
                        )
                        .overlay(
                            // 編集時: 白いインナーシャドウ（縁取り風）
                            editMode == .title
                                ? RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.white.opacity(0.95), lineWidth: 4)
                                    .blur(radius: 3)
                                    .padding(1)
                                    .mask(RoundedRectangle(cornerRadius: 4))
                                : nil
                        )
                        .animation(.easeInOut(duration: 0.2), value: editMode)

                    // 本文（インライン編集）
                    if isContentEditing {
                        ZStack(alignment: .bottomTrailing) {
                            LineNumberTextEditor(
                                text: $editingContent,
                                isFocused: $isContentFocused,
                                showLineNumbers: false,
                                fontSize: 15,
                                initialCursorOffset: contentTapOffset
                            )
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                            // 拡大/縮小ボタン（閲覧・編集共通）
                            if !isExpanded {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.25)) { isExpanded = true }
                                } label: {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.white)
                                        .frame(width: 30, height: 30)
                                        .background(Circle().fill(Color.blue.opacity(0.7)))
                                }
                                .buttonStyle(.plain)
                                .padding(8)
                                .transition(.scale.combined(with: .opacity))
                            } else {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.25)) { isExpanded = false }
                                } label: {
                                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.white)
                                        .frame(width: 30, height: 30)
                                        .background(Circle().fill(Color.blue.opacity(0.7)))
                                }
                                .buttonStyle(.plain)
                                .padding(8)
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                    } else {
                        ZStack(alignment: .bottomTrailing) {
                            ScrollView {
                                TappableReadOnlyText(
                                    text: memo.content.isEmpty ? "（本文なし）" : memo.content,
                                    font: .systemFont(ofSize: 15),
                                    textColor: memo.content.isEmpty
                                        ? UIColor.secondaryLabel.withAlphaComponent(0.4)
                                        : UIColor.label,
                                    // 編集モード（GutteredTextView）と同じインセットで位置を揃える
                                    insets: UIEdgeInsets(top: 16, left: 6, bottom: 0, right: 4),
                                    lineFragmentPadding: 5,
                                    onTapAtOffset: { offset in
                                        commitTitle()
                                        isTitleFocused = false
                                        editingContent = memo.content
                                        // 空テキスト時はオフセット不要
                                        contentTapOffset = memo.content.isEmpty ? nil : offset
                                        editFromTap = true  // カード自動拡大を抑制
                                        isContentEditing = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            isContentFocused = true
                                        }
                                    }
                                )
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                // 編集モードと同じSwiftUIパディング
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 5)
                                    .onChanged { _ in
                                        if !showExpandButton && !memo.content.isEmpty {
                                            withAnimation(.easeOut(duration: 0.2)) { showExpandButton = true }
                                        }
                                    }
                            )

                            // 拡大ボタン
                            if showExpandButton && !isExpanded {
                                Button {
                                    if showDialArea { withAnimation(.easeInOut(duration: 0.25)) { showDialArea = false } }
                                    if editMode == .tag { editMode = .none }
                                    withAnimation(.easeInOut(duration: 0.25)) { isExpanded = true }
                                    showExpandButton = false
                                } label: {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.white)
                                        .frame(width: 30, height: 30)
                                        .background(Circle().fill(Color.blue.opacity(0.7)))
                                }
                                .buttonStyle(.plain)
                                .padding(8)
                                .transition(.scale.combined(with: .opacity))
                            }

                            if isExpanded {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.25)) { isExpanded = false }
                                } label: {
                                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.white)
                                        .frame(width: 30, height: 30)
                                        .background(Circle().fill(Color.blue.opacity(0.7)))
                                }
                                .buttonStyle(.plain)
                                .padding(8)
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }

                    // タグフッター
                    HStack(spacing: 6) {
                        Text("タグ:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let pt = parentTag {
                            tagBadge(parentTag: pt)
                        } else {
                            Text("なし")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        flashTag
                            ? Color.cyan.opacity(0.2)
                            : Color.cyan.opacity(0.06)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // タグフッタータップでルーレットトグル
                        editMode = (editMode == .tag) ? .none : .tag
                    }
                    .overlay(alignment: .top) {
                        Rectangle()
                            .frame(height: parentTag != nil ? 2 : 0)
                            .foregroundStyle(borderColor)
                    }
                }
                .background(Color(uiColor: .systemBackground))
                .clipShape(cardShape)
                .overlay(
                    cardShape.stroke(
                        parentTag != nil ? borderColor.opacity(0.4) : Color.secondary.opacity(0.1),
                        lineWidth: 2.5
                    )
                )
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)

                // ロックアイコン（カード右上端）
                if memo.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.orange)
                        .padding(6)
                        .background(
                            Circle()
                                .fill(Color.orange.opacity(lockIconFlash ? 0.25 : 0.1))
                        )
                        .scaleEffect(lockIconFlash ? 1.3 : 1.0)
                        .offset(x: geo.size.width - 28, y: 6)
                        .transition(.scale.combined(with: .opacity))
                        .onAppear {
                            // 出現時フラッシュ
                            withAnimation(.easeOut(duration: 0.15)) { lockIconFlash = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation(.easeOut(duration: 0.3)) { lockIconFlash = false }
                            }
                        }
                }
            }
        }
    }

    // MARK: - タグバッジ

    @ViewBuilder
    private func tagBadge(parentTag pt: Tag) -> some View {
        let childTag = memo.tags.first(where: { $0.parentTagID != nil })

        if let ct = childTag {
            HStack(alignment: .bottom, spacing: -6) {
                Text(pt.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.leading, 8)
                    .padding(.trailing, 12)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(tagColor(for: pt.colorIndex))
                    )
                Text(ct.name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(tagColor(for: ct.colorIndex))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.white, lineWidth: 1.5)
                    )
            }
        } else {
            Text(pt.name)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(tagColor(for: pt.colorIndex))
                )
        }
    }

    // MARK: - ルーレットエリア

    private var parentOptions: [(id: String, name: String, color: Color)] {
        let parentTags = tags.filter { $0.parentTagID == nil }.sorted { $0.sortOrder < $1.sortOrder }
        return [("none", "タグなし", Color(white: 0.82))] +
            parentTags.map { ($0.id.uuidString, $0.name, tagColor(for: $0.colorIndex)) }
    }

    private var childOptions: [(id: String, name: String, color: Color)] {
        let childTags: [Tag] = {
            guard let pid = selectedParentTagID else { return [] }
            return tags.filter { $0.parentTagID == pid }.sorted { $0.name < $1.name }
        }()
        return [("none", "子タグなし", Color(white: 0.82))] +
            childTags.map { ($0.id.uuidString, $0.name, tagColor(for: $0.colorIndex)) }
    }

    private var dialArea: some View {
        VStack(spacing: 0) {
            // ラベル（親タグ・子タグ）
            ZStack(alignment: .trailing) {
                Text("親タグ")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .padding(.trailing, 165)
                Text("子タグ")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .padding(.trailing, 50)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .frame(height: 14)

            // ルーレット本体
            TagDialView(
                parentOptions: parentOptions,
                parentSelectedID: $selectedParentTagID,
                childOptions: childOptions,
                childSelectedID: $selectedChildTagID,
                showChild: $showChildDial,
                isOpen: true,
                childExternalDragY: $childExternalDragY,
                onLongPress: nil
            )
            .frame(height: 211)

            // 追加ボタン
            HStack(spacing: 12) {
                Spacer()
                Button {
                    onNewTagSheet(false, nil)
                } label: {
                    Label("親タグ追加", systemImage: "plus.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
                Button {
                    if selectedParentTagID != nil {
                        onNewTagSheet(true, selectedParentTagID)
                    }
                } label: {
                    Label("子タグ追加", systemImage: "plus.circle")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary.opacity(selectedParentTagID == nil ? 0.25 : 0.5))
                }
            }
            .padding(.trailing, 8)
            .offset(y: -8)
        }
    }
}

// テキストを緩やかな弧に沿って表示
// テキストを緩やかな弧に沿って表示（Y offset方式）
struct CurvedText: View {
    let text: String
    let radius: CGFloat // 未使用（互換性のため残す）
    let font: Font
    var charSpacing: Double = 5 // 未使用

    var body: some View {
        let chars = Array(text)
        let count = chars.count
        let mid = Double(count - 1) / 2.0
        let bulge: CGFloat = 2.5 // 弧の深さ（控えめ）

        HStack(spacing: 1) {
            ForEach(0..<count, id: \.self) { i in
                let t = (Double(i) - mid) / max(mid, 1) // -1〜1
                let y = bulge * CGFloat(t * t) // 放物線（中央が高い）
                Text(String(chars[i]))
                    .font(font)
                    .foregroundStyle(.primary)
                    .offset(y: y)
            }
        }
    }
}

// 弧の上側を塗りつぶすShape
struct ArcFill: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

// 控えめな弧の仕切り線
struct ArcDivider: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.minY)
        )
        return path
    }
}

// 弧を描くカプセル型（上下辺が外側に緩やかに膨らむ）
struct ArcCapsule: Shape {
    func path(in rect: CGRect) -> Path {
        let r = rect.height / 2
        // 仕切り線と同じ円弧に沿う（bulge ∝ width²）
        let bulge: CGFloat = rect.width * rect.width / 4800
        var path = Path()
        // 左端の丸み（外側に膨らむ）
        path.move(to: CGPoint(x: r, y: rect.maxY))
        path.addArc(center: CGPoint(x: r, y: rect.midY), radius: r, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
        // 上辺（外側に膨らむ弧）
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - r, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.minY - bulge)
        )
        // 右端の丸み（外側に膨らむ）
        path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.midY), radius: r, startAngle: .degrees(270), endAngle: .degrees(90), clockwise: false)
        // 下辺（上辺と平行に、同じ方向に膨らむ弧）
        path.addQuadCurve(
            to: CGPoint(x: r, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.maxY - bulge)
        )
        path.closeSubpath()
        return path
    }
}
