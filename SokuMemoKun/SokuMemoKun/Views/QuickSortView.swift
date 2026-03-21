import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.sokumemokun.app", category: "QuickSort")

// 爆速振り分けモード: セル内包方式（カード+サジェスト+ルーレットを1セルに統合）
struct QuickSortView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var tags: [Tag]

    var onDismiss: () -> Void

    // フェーズ管理: フィルタ選択 → セット確認 → カルーセル
    enum Phase { case filter, setConfirm, carousel }
    @State private var phase: Phase = .filter

    // セット管理
    private let setSize = 50
    @State private var allFilteredMemos: [Memo] = []
    @State private var targetMemos: [Memo] = []
    @State private var currentSetIndex = 0
    private var totalSets: Int { max(1, (allFilteredMemos.count + setSize - 1) / setSize) }
    private var isLastSet: Bool { currentSetIndex >= totalSets - 1 }

    // カルーセル
    @State private var scrolledMemoID: UUID?
    @State private var isCarouselScrolling = false

    // 編集オーバーレイ用
    @State private var editingTitle = ""
    @State private var editingContent = ""
    @State private var isKeyboardVisible = false
    @State private var isCardEditing = false
    @State private var editingTitleSnapshot = ""
    @State private var editingContentSnapshot = ""
    @State private var showDiscardAlert = false
    @FocusState private var titleFieldFocused: Bool

    // タグ追加シート
    @State private var showNewTagSheet = false
    @State private var newTagIsChild = false
    @State private var newTagParentID: UUID?  // 新規子タグ作成時の親タグID

    // 変更ログ
    @State private var taggedMemoIDs: Set<UUID> = []
    @State private var titledMemoIDs: Set<UUID> = []
    @State private var editedMemoIDs: Set<UUID> = []
    @State private var deleteQueue: [Memo] = []
    @State private var skippedIndices: Set<Int> = []

    // 終了確認
    @State private var showExitConfirm = false

    // 戦績
    @State private var showResult = false
    @State private var showDeleteReview = false

    // アクティブなメモ（削除キューを除外した配列）
    private var activeMemos: [Memo] {
        let skippedIDs = Set(deleteQueue.map { $0.id })
        return targetMemos.filter { !skippedIDs.contains($0.id) }
    }

    private var currentMemo: Memo? {
        guard let id = scrolledMemoID else { return activeMemos.first }
        return activeMemos.first(where: { $0.id == id })
    }

    private var currentIndexInActive: Int {
        guard let memo = currentMemo else { return 0 }
        return activeMemos.firstIndex(where: { $0.id == memo.id }) ?? 0
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

                switch phase {
                case .filter:
                    QuickSortFilterView(
                        onStart: { memos in
                            allFilteredMemos = memos
                            currentSetIndex = 0
                            if memos.count > setSize {
                                phase = .setConfirm
                            } else {
                                targetMemos = memos
                                scrolledMemoID = memos.first?.id
                                phase = .carousel
                            }
                        },
                        onCancel: { onDismiss() }
                    )

                case .setConfirm:
                    setConfirmView

                case .carousel:
                    if !activeMemos.isEmpty {
                        mainContent(geo: geo)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.green)
                            Text("対象のメモがありません")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // カード編集モード
                if phase == .carousel && isCardEditing {
                    cardEditOverlay(geo: geo)
                }

                // 終了確認ダイアログ
                if showExitConfirm {
                    exitConfirmDialog
                }

                if showResult {
                    QuickSortResultView(
                        taggedCount: taggedMemoIDs.count,
                        titledCount: titledMemoIDs.count,
                        editedCount: editedMemoIDs.count,
                        deletedCount: deleteQueue.count,
                        deletedMemos: deleteQueue,
                        onReviewDeleted: { showResult = false; showDeleteReview = true },
                        onNextSet: isLastSet ? nil : {
                            for m in deleteQueue { modelContext.delete(m) }
                            try? modelContext.save()
                            showResult = false
                            currentSetIndex += 1
                            startCurrentSet()
                        },
                        onClose: {
                            for m in deleteQueue { modelContext.delete(m) }
                            try? modelContext.save()
                            onDismiss()
                        }
                    )
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .overlay(alignment: .bottomTrailing) {
            if isKeyboardVisible {
                Button {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .padding(10)
                        .background(
                            Circle()
                                .fill(Color(uiColor: .secondarySystemBackground))
                                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)
                .padding(.bottom, 8)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isKeyboardVisible)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .sheet(isPresented: $showDeleteReview) { deleteReviewSheet }
        .sheet(isPresented: $showNewTagSheet) {
            NewTagSheetView(
                parentTagID: newTagIsChild ? newTagParentID : nil,
                onTagCreated: { newTagID in
                    // セルのonChange(memo.tags)が自動検知 → ルーレット同期
                    guard let memo = currentMemo, let tag = tags.first(where: { $0.id == newTagID }) else { return }
                    if newTagIsChild {
                        memo.tags.removeAll(where: { $0.parentTagID != nil })
                    } else {
                        memo.tags.removeAll(where: { $0.parentTagID == nil })
                    }
                    memo.tags.append(tag)
                    memo.updatedAt = Date()
                    taggedMemoIDs.insert(memo.id)
                }
            )
        }
    }

    // MARK: - メインコンテンツ（セル内包方式）

    @ViewBuilder
    private func mainContent(geo: GeometryProxy) -> some View {
        let dialAreaHeight = QuickSortCellView.dialAreaHeight
        let cardWidth = geo.size.width * 0.78
        let headerHeight: CGFloat = 76
        let cellHeight = geo.size.height - headerHeight
        let cardHeight = max(cellHeight - dialAreaHeight, 200)

        VStack(spacing: 0) {
            // カウンター（一番上）
            if !activeMemos.isEmpty {
                let current = currentIndexInActive + 1
                let total = activeMemos.count
                let isLastPage = current == total
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(current)")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(isLastPage
                            ? AnyShapeStyle(.linearGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple], startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(.blue))
                    Text("/\(total)")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("枚")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }

            // ナビバー
            navBar
                .padding(.horizontal, 16)
                .padding(.top, 2)

            // カルーセル（セル内包: カード+ルーレットが1セル）
            CarouselView(
                items: activeMemos,
                cardWidth: geo.size.width,
                cardHeight: cellHeight,
                currentMemoID: $scrolledMemoID,
                isScrolling: $isCarouselScrolling,
                isScrollDisabled: isCardEditing,
                dialHeight: dialAreaHeight,
                cardContent: { memo in
                    let activeIdx = activeMemos.firstIndex(where: { $0.id == memo.id }) ?? 0
                    return AnyView(
                        QuickSortCellView(
                            memo: memo,
                            cardWidth: cardWidth,
                            cardHeight: cardHeight,
                            showLeftArrow: activeIdx > 0,
                            showRightArrow: activeIdx < activeMemos.count - 1,
                            isActive: memo.id == scrolledMemoID,
                            onTagChanged: { id in taggedMemoIDs.insert(id) },
                            onEditTapped: {
                                scrolledMemoID = memo.id
                                enterEditMode(for: memo)
                            },
                            onDelete: { deleteMemo($0) },
                            onNewTagSheet: { isChild, parentID in
                                newTagIsChild = isChild
                                newTagParentID = parentID
                                showNewTagSheet = true
                            }
                        )
                    )
                }
            )
        }
    }

    // MARK: - カード編集オーバーレイ（背景グレーアウト + カードが浮き上がる）

    @ViewBuilder
    private func cardEditOverlay(geo: GeometryProxy) -> some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }

            VStack(spacing: 0) {
                HStack {
                    Button {
                        if editingTitle != editingTitleSnapshot || editingContent != editingContentSnapshot {
                            showDiscardAlert = true
                        } else {
                            exitEditMode(discard: true)
                        }
                    } label: {
                        Text("キャンセル")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    Spacer()
                    Button {
                        exitEditMode(discard: false)
                    } label: {
                        Text("確定")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

                VStack(alignment: .leading, spacing: 0) {
                    TextField("タイトルを入力", text: $editingTitle)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .focused($titleFieldFocused)
                        .padding(.horizontal, 14)
                        .padding(.top, 10)
                        .padding(.bottom, 6)

                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 1)
                        .padding(.horizontal, 10)

                    TextEditor(text: $editingContent)
                        .font(.system(size: 15))
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 10)
                        .padding(.top, 4)
                        .frame(maxHeight: .infinity)
                }
                .background(Color(uiColor: .systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                .padding(.horizontal, 12)
            }
            .frame(maxHeight: min(geo.size.height * 0.45, 400))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 80)
        }
        .ignoresSafeArea(.keyboard)
        .transition(.opacity)
        .alert("変更は保存されません。よろしいですか？", isPresented: $showDiscardAlert) {
            Button("はい", role: .destructive) { exitEditMode(discard: true) }
            Button("編集に戻る", role: .cancel) {}
        }
    }

    // MARK: - セット確認画面

    private var setConfirmView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "rectangle.stack.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.orange)

                Text("セットを組みます")
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text("一度に処理できるのは\(setSize)枚までです。\n下記のようにセットを組んで、順番に処理します。")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                VStack(spacing: 0) {
                    ForEach(0..<totalSets, id: \.self) { i in
                        let start = i * setSize + 1
                        let end = min((i + 1) * setSize, allFilteredMemos.count)
                        let isCurrent = i == currentSetIndex

                        HStack {
                            Image(systemName: isCurrent ? "play.circle.fill" : "circle")
                                .font(.system(size: 18))
                                .foregroundStyle(isCurrent ? .orange : .secondary.opacity(0.3))

                            Text("セット\(i + 1)")
                                .font(.system(size: 15, weight: isCurrent ? .bold : .medium, design: .rounded))

                            Spacer()

                            Text("\(start)〜\(end)枚目（\(end - start + 1)枚）")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        if i < totalSets - 1 {
                            Divider().padding(.leading, 50)
                        }
                    }
                }
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 20)

                Text("途中でいつでも保存・終了できます")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary.opacity(0.6))
            }

            Spacer()

            Button {
                startCurrentSet()
            } label: {
                Text("開始")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.orange))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            Button {
                onDismiss()
            } label: {
                Text("閉じる")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .padding(.bottom, 16)
        }
    }

    // 現在のセットのメモを切り出して開始
    private func startCurrentSet() {
        let start = currentSetIndex * setSize
        let end = min(start + setSize, allFilteredMemos.count)
        targetMemos = Array(allFilteredMemos[start..<end])

        deleteQueue = []
        taggedMemoIDs = []
        titledMemoIDs = []
        editedMemoIDs = []
        scrolledMemoID = targetMemos.first?.id

        phase = .carousel
    }

    private func enterEditMode(for memo: Memo) {
        editingTitle = memo.title
        editingContent = memo.content
        editingTitleSnapshot = memo.title
        editingContentSnapshot = memo.content
        withAnimation(.spring(response: 0.3)) { isCardEditing = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            titleFieldFocused = true
        }
    }

    private func exitEditMode(discard: Bool) {
        if !discard {
            // 確定: メモに反映
            if let memo = currentMemo {
                let newTitle = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if newTitle != memo.title {
                    memo.title = newTitle
                    memo.updatedAt = Date()
                    if !newTitle.isEmpty { titledMemoIDs.insert(memo.id) }
                }
                if editingContent != memo.content {
                    memo.content = editingContent
                    memo.updatedAt = Date()
                    editedMemoIDs.insert(memo.id)
                }
            }
        }
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        withAnimation(.spring(response: 0.3)) { isCardEditing = false }
    }

    // MARK: - ナビバー

    private var navBar: some View {
        HStack {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { showExitConfirm = true }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                withAnimation(.easeOut(duration: 0.25)) { showResult = true }
            } label: {
                Text("完了")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.orange))
            }
        }
    }

    // MARK: - 終了確認ダイアログ

    private var exitConfirmDialog: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) { showExitConfirm = false }
                }

            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.orange)

                    Text("爆速振り分けモードを終了")
                        .font(.system(size: 17, weight: .bold, design: .rounded))

                    Text("変更は保存されません。\nよろしいですか？")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Text("保存するには、完了ボタンを押すか\n完走してください。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }
                .padding(.top, 24)
                .padding(.bottom, 16)
                .padding(.horizontal, 20)

                Divider()

                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showExitConfirm = false }
                    onDismiss()
                } label: {
                    Text("終了する")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)

                Divider()

                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showExitConfirm = false }
                } label: {
                    Text("戻る")
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

    // MARK: - 削除確認シート

    private var deleteReviewSheet: some View {
        NavigationStack {
            List {
                ForEach(deleteQueue, id: \.id) { memo in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(memo.title.isEmpty ? "（タイトルなし）" : memo.title)
                            .font(.system(size: 15, weight: .semibold))
                        Text(String(memo.content.prefix(100)))
                            .font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(2)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("復元") {
                            if let idx = deleteQueue.firstIndex(where: { $0.id == memo.id }) {
                                deleteQueue.remove(at: idx)
                            }
                        }
                        .tint(.green)
                    }
                }
            }
            .navigationTitle("削除予定のメモ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("戻る") { showDeleteReview = false; showResult = true }
                }
            }
        }
    }

    // MARK: - アクション

    private func deleteMemo(_ memo: Memo) {
        deleteQueue.append(memo)
        // 削除されたメモを指していたら次のカードに移動
        if scrolledMemoID == memo.id {
            if let next = activeMemos.first {
                scrolledMemoID = next.id
            }
        }
        if activeMemos.isEmpty {
            withAnimation(.easeOut(duration: 0.25)) { showResult = true }
        }
    }

}
