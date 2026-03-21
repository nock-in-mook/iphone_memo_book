import SwiftUI
import SwiftData

// セル内包方式: カード+サジェスト+ルーレットを1セルに統合（爆速スクロール用）
// 各セルが独立したタグ状態を持ち、親ビューのState変更をゼロにする
struct QuickSortCellView: View {
    let memo: Memo
    let suggestions: [TagSuggestEngine.Suggestion]
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    var suggestEngine: TagSuggestEngine
    let showLeftArrow: Bool
    let showRightArrow: Bool
    var isActive: Bool = false  // 現在表示中のセルだけtrue → ルーレット状態変更を有効化

    // コールバック（親ビューへの通知）
    var onTagChanged: (UUID) -> Void = { _ in }
    var onEditTapped: () -> Void = {}
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

    // ローカル削除状態
    @State private var deleteOffset: CGFloat = 0
    @State private var isDeletingCard = false

    var body: some View {
        VStack(spacing: 0) {
            // 上部: サジェスト(左) + ルーレット(右)
            HStack(alignment: .top, spacing: 0) {
                suggestPanel
                    .frame(maxWidth: .infinity, maxHeight: 300, alignment: .topLeading)
                dialArea
                    .frame(maxHeight: 300, alignment: .top)
            }
            .frame(height: 370, alignment: .top)
            .clipped()

            // カード + 操作ガイド
            cardView
        }
        .onAppear { initFromMemo() }
        .onChange(of: memo.tags.map(\.id)) { _, _ in initFromMemo() }
        .onChange(of: selectedParentTagID) { oldVal, newVal in
            guard !isInternalTagChange else { return }
            // 親タグが変わったら子タグをリセット（「子タグなし」にセンタリング）
            if oldVal != newVal {
                selectedChildTagID = nil
            }
            applyTagFromDial()
        }
        .onChange(of: selectedChildTagID) { _, _ in
            guard !isInternalTagChange else { return }
            applyTagFromDial()
        }
    }

    // MARK: - 初期化（memo.tagsからローカルStateを設定）

    private func initFromMemo() {
        let parentTag = memo.tags.first(where: { $0.parentTagID == nil })
        let childTag = memo.tags.first(where: { $0.parentTagID != nil })
        let newParentID = parentTag?.id
        let newChildID = childTag?.id
        // 値が変わった時だけ設定（不要なonChange発火を防止）
        let needsUpdate = (newParentID != selectedParentTagID) || (newChildID != selectedChildTagID)
        guard needsUpdate else { return }
        isInternalTagChange = true
        selectedParentTagID = newParentID
        selectedChildTagID = newChildID
        if parentTag != nil {
            let hasChildren = tags.contains(where: { $0.parentTagID == parentTag?.id })
            if hasChildren { showChildDial = true }
        }
        // SwiftUIのonChangeは遅延発火するため、asyncでリセット
        DispatchQueue.main.async { isInternalTagChange = false }
    }

    // MARK: - タグ操作（セル内で直接memo.tagsに書き込み）

    private func applyTagFromDial() {
        let originalTags = Set(memo.tags.map { $0.id })
        memo.tags.removeAll()
        if let pid = selectedParentTagID, let tag = tags.first(where: { $0.id == pid }) { memo.tags.append(tag) }
        if let cid = selectedChildTagID, let tag = tags.first(where: { $0.id == cid }) { memo.tags.append(tag) }
        let newTags = Set(memo.tags.map { $0.id })
        if originalTags != newTags {
            memo.updatedAt = Date()
            onTagChanged(memo.id)
            suggestEngine.learn(title: memo.title, body: memo.content, tagIDs: memo.tags.map { $0.id }, context: modelContext)
        }
    }

    private func applySuggestion(_ suggestion: TagSuggestEngine.Suggestion) {
        if suggestion.kind == .newTag { return }
        isInternalTagChange = true
        selectedParentTagID = suggestion.parentID
        selectedChildTagID = suggestion.childID
        isInternalTagChange = false
        applyTagFromDial()
    }

    // MARK: - カードビュー

    @ViewBuilder
    private var cardView: some View {
        let parentTag = memo.tags.first(where: { $0.parentTagID == nil })
        let borderColor = parentTag != nil ? tagColor(for: parentTag!.colorIndex) : Color.clear
        let tabH: CGFloat = 34
        let tabW: CGFloat = cardWidth * 0.68
        let cardShape = CardWithTabShape(tabRatio: 0.68, tabHeight: tabH)

        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                // タイトルタブ
                Text(memo.title.isEmpty ? "タイトルなし" : memo.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(memo.title.isEmpty ? Color.secondary.opacity(0.4) : Color.primary)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .frame(height: tabH - 2, alignment: .leading)
                    .frame(width: tabW, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemBackground).opacity(parentTag != nil ? 0.8 : 0.6))

                // 本文
                Text(memo.content.isEmpty ? "（本文なし）" : memo.content)
                    .font(.system(size: 13))
                    .foregroundColor(memo.content.isEmpty ? Color.secondary.opacity(0.4) : Color.primary)
                    .lineLimit(nil)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(12)

                // タグフッター
                HStack(spacing: 6) {
                    Text("タグ:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if parentTag != nil {
                        tagBadge
                    } else {
                        Text("なし")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary.opacity(0.5))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(uiColor: .secondarySystemBackground).opacity(0.4))
                .overlay(
                    Rectangle()
                        .frame(height: parentTag != nil ? 2 : 0)
                        .foregroundStyle(borderColor),
                    alignment: .top
                )
            }
            .background(Color(uiColor: .systemBackground))
            .clipShape(cardShape)
            .overlay(
                cardShape.stroke(parentTag != nil ? borderColor.opacity(0.4) : Color.secondary.opacity(0.1), lineWidth: 2.5)
            )
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)

            // 鉛筆ボタン
            Button { onEditTapped() } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
            .frame(height: tabH - 2)
            .offset(x: tabW + 6, y: 0)
        }
        .frame(width: cardWidth, height: cardHeight)
        .offset(y: isDeletingCard ? deleteOffset : 0)
        .opacity(isDeletingCard ? max(0.0, 1.0 - Double(deleteOffset) / 300.0) : 1.0)
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    let t = value.translation
                    if t.height > 15 && abs(t.height) > abs(t.width) * 1.5 {
                        isDeletingCard = true
                        deleteOffset = t.height
                    }
                }
                .onEnded { value in
                    guard isDeletingCard else { return }
                    if value.translation.height > 100 {
                        withAnimation(.easeOut(duration: 0.2)) { deleteOffset = 500 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onDelete(memo)
                            isDeletingCard = false
                            deleteOffset = 0
                        }
                    } else {
                        withAnimation(.spring(response: 0.3)) { deleteOffset = 0 }
                        isDeletingCard = false
                    }
                }
        )
        // 左右の三角マーク
        .overlay {
            HStack {
                if showLeftArrow {
                    Triangle()
                        .fill(Color.blue.opacity(0.5))
                        .frame(width: 18, height: 40)
                        .rotationEffect(.degrees(-90))
                } else {
                    Color.clear.frame(width: 18)
                }
                Spacer()
                if showRightArrow {
                    Triangle()
                        .fill(Color.blue.opacity(0.5))
                        .frame(width: 18, height: 40)
                        .rotationEffect(.degrees(90))
                } else {
                    Color.clear.frame(width: 18)
                }
            }
            .allowsHitTesting(false)
        }
        // 削除ガイド
        .overlay(alignment: .bottom) {
            let isDeleteActive = isDeletingCard && deleteOffset > 30
            VStack(spacing: -2) {
                Text("削除")
                    .font(.system(size: isDeleteActive ? 16 : 13, weight: .black, design: .rounded))
                Image(systemName: "arrow.down")
                    .font(.system(size: isDeleteActive ? 38 : 28, weight: .black))
            }
            .foregroundStyle(isDeleteActive ? .red : .red.opacity(0.35))
            .animation(.easeOut(duration: 0.15), value: isDeleteActive)
            .offset(y: -10)
            .allowsHitTesting(false)
        }
    }

    // MARK: - タグバッジ

    @ViewBuilder
    private var tagBadge: some View {
        let parentTag = memo.tags.first(where: { $0.parentTagID == nil })
        let childTag = memo.tags.first(where: { $0.parentTagID != nil })

        if let pt = parentTag {
            if let ct = childTag {
                HStack(alignment: .bottom, spacing: -6) {
                    Text(pt.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.leading, 10)
                        .padding(.trailing, 14)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(tagColor(for: pt.colorIndex))
                                .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
                        )
                    Text(ct.name)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(tagColor(for: ct.colorIndex))
                                .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white, lineWidth: 2)
                        )
                }
            } else {
                Text(pt.name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(tagColor(for: pt.colorIndex))
                            .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
                    )
            }
        }
    }

    // MARK: - サジェストパネル

    private var suggestPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !suggestions.isEmpty {
                let dictSugs = suggestions.filter { $0.kind == .dictMatch }
                let newSugs = suggestions.filter { $0.kind == .newTag }
                let histSugs = suggestions.filter { $0.kind == .history }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("タグの提案")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 6)

                    if !dictSugs.isEmpty { suggestSection(title: "おすすめ", icon: "tag.fill", items: dictSugs) }
                    if !newSugs.isEmpty { suggestSection(title: "新規タグ", icon: "plus.circle.fill", items: newSugs) }
                    if !histSugs.isEmpty { suggestSection(title: "履歴", icon: "clock.fill", items: histSugs) }
                }
                .padding(.bottom, 6)
                .background(Color(uiColor: .secondarySystemBackground).opacity(0.9))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
    }

    @ViewBuilder
    private func suggestSection(title: String, icon: String, items: [TagSuggestEngine.Suggestion]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 9)).foregroundStyle(.secondary)
                Text(title).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)

            ForEach(items) { suggestion in
                Button { applySuggestion(suggestion) } label: {
                    HStack(spacing: 4) {
                        if suggestion.kind == .newTag {
                            Image(systemName: "plus.circle.fill").font(.system(size: 12)).foregroundStyle(.green)
                        } else if let pt = tags.first(where: { $0.id == suggestion.parentID }) {
                            Circle().fill(tagColor(for: pt.colorIndex)).frame(width: 8, height: 8)
                        }
                        Text(suggestion.parentName).font(.system(size: 13, weight: .semibold)).foregroundStyle(.primary)
                        if let cn = suggestion.childName {
                            Image(systemName: "chevron.right").font(.system(size: 8)).foregroundStyle(.tertiary)
                            Text(cn).font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(suggestion.kind == .newTag ? Color.green.opacity(0.08) : Color(uiColor: .systemBackground).opacity(0.95))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)
            }
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
