import SwiftUI
import SwiftData

// セル内包方式: メモカード（上）→ ルーレット（中）→ コントロールパネル（下）
// スワイプ操作は一切なし、全てタップで完結
struct QuickSortCellView: View {
    let memo: Memo
    let showLeftArrow: Bool
    let showRightArrow: Bool
    var isActive: Bool = false

    // ルーレット領域の高さ
    static let dialAreaHeight: CGFloat = 250

    // コールバック（親ビューへの通知）
    var onTagChanged: (UUID) -> Void = { _ in }
    var onTitleChanged: (UUID) -> Void = { _ in }
    var onEditBody: () -> Void = {}
    var onDelete: (Memo) -> Void = { _ in }
    var onNewTagSheet: (_ isChild: Bool, _ parentTagID: UUID?) -> Void = { _, _ in }
    var onGoPrev: () -> Void = {}
    var onGoNext: () -> Void = {}

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

    // ピカピカアニメーション
    @State private var flashTag = false
    @State private var flashTitle = false

    // 削除確認
    @State private var showDeleteConfirm = false

    // ルーレット表示（タグ編集ボタンで切替）
    @State private var showDialArea = false

    var body: some View {
        GeometryReader { geo in
            let cardW = geo.size.width * 0.80
            let cardH = geo.size.height * 0.35  // カード上下幅を控えめに

            VStack(spacing: 0) {
                    Spacer(minLength: 12)

                    // ── メモカード（タイトル+本文+タグフッター）──
                    memoCard
                        .frame(width: cardW, height: cardH)
                        .frame(maxWidth: .infinity)

                    Spacer(minLength: 10)

                    // ── ルーレット（タグ編集時のみ表示）──
                    if showDialArea {
                        dialArea
                            .frame(height: QuickSortCellView.dialAreaHeight, alignment: .top)
                            .clipped()
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }

                    Spacer(minLength: 10)

                    // ── コントローラーエリア（弧の仕切り線 + ボタン + 操作パネル）──
                    controllerArea
                        .padding(.bottom, 4)
            }
        }
        .onAppear {
            initFromMemo()
            editingTitle = memo.title
        }
        .onChange(of: memo.tags.map(\.id)) { _, _ in initFromMemo() }
        .onChange(of: memo.id) { _, _ in
            initFromMemo()
            editingTitle = memo.title
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
            if !focused { commitTitle() }
        }
        .onChange(of: isActive) { _, active in
            if active { triggerFlash() }
            else { flashTag = false; flashTitle = false }
        }
        .overlay {
            if showDeleteConfirm {
                deleteConfirmDialog
            }
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
                            flashTitle
                                ? Color.orange.opacity(0.2)
                                : Color(uiColor: .secondarySystemBackground).opacity(
                                    parentTag != nil ? 0.8 : 0.6
                                )
                        )

                    // 本文（タップで編集画面へ）
                    Text(memo.content.isEmpty ? "（本文なし）" : String(memo.content.prefix(200)))
                        .font(.system(size: 15))
                        .foregroundColor(memo.content.isEmpty ? Color.secondary.opacity(0.4) : Color.primary)
                        .lineLimit(nil)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(12)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            commitTitle()
                            isTitleFocused = false
                            onEditBody()
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
                            ? Color.orange.opacity(0.15)
                            : Color(uiColor: .secondarySystemBackground).opacity(0.4)
                    )
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

                // 鉛筆ボタン（タブの右横、カードの外エリア）
                Button {
                    commitTitle()
                    isTitleFocused = false
                    onEditBody()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .frame(height: tabH - 2)
                .offset(x: tabW + 6, y: 0)
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

    // MARK: - コントローラーエリア（弧 + 3ボタン + 操作パネル）

    private var controllerArea: some View {
        VStack(spacing: 0) {
            // 弧の仕切り線
            ArcDivider()
                .stroke(Color.secondary.opacity(0.5), lineWidth: 2.5)
                .frame(height: 60)

            // 3ボタン（弧に沿って配置・P2ベース押せるボタン）
            ZStack {
                // 本文編集（中央固定）
                TapPressableView(shadowHeight: 5, shadowColor: .black.opacity(0.35)) {
                    commitTitle()
                    isTitleFocused = false
                    onEditBody()
                } label: {
                    Text("本文編集")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 18)
                        .padding(.top, 5).padding(.bottom, 9)
                        .background(
                            ArcCapsule().fill(
                                LinearGradient(colors: [Color(white: 0.98), Color(white: 0.88)],
                                               startPoint: .top, endPoint: .bottom)
                            )
                        )
                }
                .offset(y: -10)

                // タイトル編集（左）
                TapPressableView(shadowHeight: 5, shadowColor: .black.opacity(0.35)) {
                    isTitleFocused = true
                } label: {
                    Text("タイトル編集")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .frame(width: 90)
                        .padding(.top, 5).padding(.bottom, 9)
                        .background(
                            ZStack {
                                ArcCapsule().fill(Color(white: 0.95))
                                ArcCapsule().fill(
                                    LinearGradient(colors: [Color.orange.opacity(0.3), Color.orange.opacity(0.5)],
                                                   startPoint: .top, endPoint: .bottom)
                                )
                            }
                        )
                }
                .rotationEffect(.degrees(-11))
                .offset(x: -135, y: 0)

                // タグ編集（右）
                TapPressableView(shadowHeight: 5, shadowColor: .black.opacity(0.35)) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showDialArea.toggle()
                    }
                } label: {
                    Text("タグ編集")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .frame(width: 90)
                        .padding(.top, 5).padding(.bottom, 9)
                        .background(
                            ZStack {
                                ArcCapsule().fill(Color(white: 0.95))
                                ArcCapsule().fill(
                                    LinearGradient(colors: [Color.cyan.opacity(0.18), Color.cyan.opacity(0.35)],
                                                   startPoint: .top, endPoint: .bottom)
                                )
                            }
                        )
                }
                .rotationEffect(.degrees(11))
                .offset(x: 135, y: 0)
            }
            .padding(.top, -22)

            // 操作パネル（前へ / ゴミ箱 / 次へ）
            controlPanel
                .padding(.horizontal, 24)
                .padding(.top, 12)
        }
    }

    // MARK: - コントロールパネル（◁前へ / ゴミ箱 / ▷次へ）

    private var controlPanel: some View {
        HStack(spacing: 0) {
            // ◁ タップで前へ
            Button {
                commitTitle()
                isTitleFocused = false
                onGoPrev()
            } label: {
                HStack(spacing: 6) {
                    Triangle()
                        .fill(Color.blue.opacity(0.7))
                        .frame(width: 14, height: 20)
                        .rotationEffect(.degrees(-90))
                    Text("前へ")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.blue)
                }
            }
            .disabled(!showLeftArrow)
            .buttonStyle(.plain)

            Spacer()

            // ゴミ箱（でかめ・タップで確認後に削除）
            Button {
                withAnimation(.easeOut(duration: 0.2)) { showDeleteConfirm = true }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "trash")
                        .font(.system(size: 26, weight: .medium))
                    Text("削除")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.red.opacity(0.6))
            }
            .buttonStyle(.plain)

            Spacer()

            // ▷ タップで次へ
            Button {
                commitTitle()
                isTitleFocused = false
                onGoNext()
            } label: {
                HStack(spacing: 6) {
                    Text("次へ")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(showRightArrow ? .blue : .secondary.opacity(0.3))
                    Triangle()
                        .fill(showRightArrow ? Color.blue.opacity(0.7) : Color.secondary.opacity(0.15))
                        .frame(width: 14, height: 20)
                        .rotationEffect(.degrees(90))
                }
            }
            .disabled(!showRightArrow)
            .buttonStyle(.plain)
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
