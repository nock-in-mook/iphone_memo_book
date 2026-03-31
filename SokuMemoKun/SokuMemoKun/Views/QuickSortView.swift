import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.sokumemokun.app", category: "QuickSort")

// 爆速メモ整理モード: セル内包方式（カード+ルーレットを1セルに統合）
struct QuickSortView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var tags: [Tag]

    var onDismiss: () -> Void

    // フェーズ管理: フィルタ選択 → ローディング → セット確認 → カルーセル
    enum Phase { case filter, loading, setConfirm, carousel }
    @State private var phase: Phase = .filter
    @State private var loadingProgress: CGFloat = 0

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
    @State private var cellEditMode: CellEditMode = .none

    @State private var isKeyboardVisible = false
    @State private var keyboardHeight: CGFloat = 0

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
    @State private var showFinishConfirm = false
    @State private var showDeleteConfirmFromPanel = false

    // 戦績
    @State private var showResult = false
    @State private var showDeleteReview = false

    // ロック確認
    @State private var showLockConfirm = false

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
                            loadingProgress = 0
                            phase = .loading
                            startLoadingAnimation {
                                if memos.count > setSize {
                                    phase = .setConfirm
                                } else {
                                    targetMemos = memos
                                    scrolledMemoID = memos.first?.id
                                    phase = .carousel
                                }
                            }
                        },
                        onCancel: { onDismiss() }
                    )

                case .loading:
                    loadingView

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
                // 終了確認ダイアログ
                if showExitConfirm {
                    exitConfirmDialog
                }

                if showFinishConfirm {
                    finishConfirmDialog
                }

                if showDeleteConfirmFromPanel {
                    panelDeleteConfirmDialog
                }

                if showLockConfirm {
                    lockConfirmDialog
                }

                if showResult {
                    QuickSortResultView(
                        taggedCount: taggedMemoIDs.count,
                        titledCount: titledMemoIDs.count,
                        editedCount: editedMemoIDs.count,
                        deletedCount: deleteQueue.count,
                        deletedMemos: deleteQueue,
                        onReviewDeleted: { showDeleteReview = true },
                        onNextSet: isLastSet ? nil : {
                            for m in deleteQueue { modelContext.delete(m) }
                            try? modelContext.save()
                            showResult = false
                            currentSetIndex += 1
                            startCurrentSet()
                        },
                        onClose: {
                            returnToFilter()
                        },
                        onGoBack: {
                            withAnimation(.easeOut(duration: 0.25)) { showResult = false }
                        }
                    )
                }

            }
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: scrolledMemoID) { _, _ in
            // ルーレット表示中はページ送りしてもタグモードを維持（連続タグ付け）
            if cellEditMode != .tag {
                cellEditMode = .none
            }
        }
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
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                // スクリーン座標からキーボードが覆う高さを算出（カスタムキーボード対応）
                let screenHeight = UIScreen.main.bounds.height
                let kbH = screenHeight - frame.origin.y
                if kbH > 0 {
                    isKeyboardVisible = true
                    keyboardHeight = kbH
                } else {
                    isKeyboardVisible = false
                    keyboardHeight = 0
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
            keyboardHeight = 0
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
        let headerHeight: CGFloat = 76
        let cellHeight = geo.size.height - headerHeight

        VStack(spacing: 0) {
            // 最上段: ✕、枚数、整理をおわる
            if !activeMemos.isEmpty {
                let current = currentIndexInActive + 1
                let total = activeMemos.count
                let isLastPage = current == total
                ZStack {
                    // 中央: 枚数
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

                    // 左端: ✕ 丸囲み
                    HStack {
                        Button {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            withAnimation(.easeOut(duration: 0.2)) { showExitConfirm = true }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(Color(uiColor: .tertiarySystemBackground))
                                        .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                                )
                                .overlay(Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                        }
                        Spacer()
                    }

                    // 右端: 整理を終了
                    HStack {
                        Spacer()
                        Button {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            withAnimation(.easeOut(duration: 0.25)) { showFinishConfirm = true }
                        } label: {
                            Text("整理を終了")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().strokeBorder(Color.orange, lineWidth: 1.5))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }


            // カルーセル（フリックでページ送り対応）
            CarouselView(
                items: activeMemos,
                cardWidth: geo.size.width,
                cardHeight: cellHeight,
                currentMemoID: $scrolledMemoID,
                isScrolling: $isCarouselScrolling,
                isScrollDisabled: false,
                dialHeight: QuickSortCellView.dialAreaHeight,
                cardContent: { memo in
                    return AnyView(
                        QuickSortCellView(
                            memo: memo,
                            isActive: memo.id == scrolledMemoID,
                            editMode: $cellEditMode,
                            onTagChanged: { id in taggedMemoIDs.insert(id) },
                            onTitleChanged: { id in titledMemoIDs.insert(id) },
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

            // コントローラーエリア（弧 + 3編集ボタン）固定
            controllerButtons
                .offset(y: -50)

            // 操作パネル（前へ / ゴミ箱 / ロック / 次へ）固定
            bottomControlPanel
                .padding(.horizontal, 24)
                .padding(.bottom, 4)
                .offset(y: -20)
        }
    }

    // MARK: - コントローラーエリア（弧 + 3編集ボタン）

    private var controllerButtons: some View {
        VStack(spacing: 0) {
            // 弧の仕切り線
            ArcDivider()
                .stroke(Color.secondary.opacity(0.5), lineWidth: 2.5)
                .frame(height: 70)
                .offset(y: 10)

            // 3ボタン（弧に沿って配置）
            ZStack {
                // 本文編集（中央固定）— マット塗り
                TapPressableView(shadowHeight: 4, shadowColor: .black.opacity(0.15)) {
                    cellEditMode = (cellEditMode == .content) ? .none : .content
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "square.and.pencil")
                        Text("本文")
                    }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 16)
                        .padding(.top, 7).padding(.bottom, 8)
                        .background(
                            ZStack {
                                ArcCapsule().fill(Color(uiColor: .systemBackground))
                                ArcCapsule().fill(Color(white: 0.85).opacity(0.2))
                                ArcCapsule().fill(Color(white: 0.5).opacity(0.03))
                            }
                        )
                        .overlay(ArcCapsule().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                }
                .offset(y: -17)

                // タイトル編集（左）— マット塗り
                TapPressableView(shadowHeight: 4, shadowColor: .black.opacity(0.15)) {
                    cellEditMode = (cellEditMode == .title) ? .none : .title
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "square.and.pencil")
                        Text("タイトル")
                    }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .frame(width: 100)
                        .padding(.top, 7).padding(.bottom, 8)
                        .background(
                            ZStack {
                                ArcCapsule().fill(Color(uiColor: .systemBackground))
                                ArcCapsule().fill(Color.orange.opacity(0.2))
                                ArcCapsule().fill(Color(white: 0.5).opacity(0.03))
                            }
                        )
                        .overlay(ArcCapsule().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                }
                .rotationEffect(.degrees(-13))
                .offset(x: -128, y: -2)

                // タグ編集（右）— マット塗り
                TapPressableView(shadowHeight: 4, shadowColor: .black.opacity(0.15)) {
                    cellEditMode = (cellEditMode == .tag) ? .none : .tag
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "square.and.pencil")
                        Text("タグ")
                    }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .frame(width: 90)
                        .padding(.top, 7).padding(.bottom, 8)
                        .background(
                            ZStack {
                                ArcCapsule().fill(Color(uiColor: .systemBackground))
                                ArcCapsule().fill(Color.cyan.opacity(0.2))
                                ArcCapsule().fill(Color(white: 0.5).opacity(0.03))
                            }
                        )
                        .overlay(ArcCapsule().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                }
                .rotationEffect(.degrees(13))
                .offset(x: 128, y: -2)
            }
            .padding(.top, -27)
        }
    }

    // MARK: - 操作パネル（前へ / ゴミ箱 / 次へ or 完了）

    private var bottomControlPanel: some View {
        let canGoPrev = currentIndexInActive > 0
        let canGoNext = currentIndexInActive < activeMemos.count - 1
        let isLastPage = currentIndexInActive == activeMemos.count - 1

        return ZStack {
            // 左端: 前へ（マット塗り三角形）
            HStack {
                TapPressableView(shadowHeight: 4, shadowColor: .black.opacity(0.15)) {
                    if canGoPrev {
                        scrolledMemoID = activeMemos[currentIndexInActive - 1].id
                    }
                } label: {
                    ZStack {
                        Triangle()
                            .fill(Color(uiColor: .systemBackground))
                            .frame(width: 40, height: 40)
                            .rotationEffect(.degrees(-90))
                        Triangle()
                            .fill(canGoPrev ? Color.blue : Color.blue.opacity(0.15))
                            .frame(width: 40, height: 40)
                            .rotationEffect(.degrees(-90))
                        Triangle()
                            .fill(Color(white: 0.5).opacity(0.03))
                            .frame(width: 40, height: 40)
                            .rotationEffect(.degrees(-90))
                    }
                }
                .disabled(!canGoPrev)
                Spacer()
            }

            // 中央: 削除（マット塗り丸ボタン）
            TapPressableView(shadowHeight: 4, shadowColor: .black.opacity(0.15)) {
                if currentMemo?.isLocked == true {
                    withAnimation(.easeOut(duration: 0.2)) { showLockConfirm = true }
                    return
                }
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                withAnimation(.easeOut(duration: 0.2)) { showDeleteConfirmFromPanel = true }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "trash")
                        .font(.system(size: 20, weight: .medium))
                    Text("削除")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(currentMemo?.isLocked == true ? Color.secondary.opacity(0.3) : Color.red)
                .frame(width: 50, height: 50)
                .background(
                    ZStack {
                        Circle().fill(Color(uiColor: .systemBackground))
                        Circle().fill(Color(white: 0.85).opacity(0.2))
                        Circle().fill(Color(white: 0.5).opacity(0.03))
                    }
                )
                .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
            }
            .offset(y: 20)

            // 右端: 次へ / 完了
            HStack {
                Spacer()
                if isLastPage {
                    Button {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        withAnimation(.easeOut(duration: 0.25)) { showFinishConfirm = true }
                    } label: {
                        HStack(spacing: 4) {
                            Text("完了")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.orange))
                    }
                } else {
                    TapPressableView(shadowHeight: 4, shadowColor: .black.opacity(0.15)) {
                        if canGoNext {
                            scrolledMemoID = activeMemos[currentIndexInActive + 1].id
                        }
                    } label: {
                        ZStack {
                            Triangle()
                                .fill(Color(uiColor: .systemBackground))
                                .frame(width: 40, height: 40)
                                .rotationEffect(.degrees(90))
                            Triangle()
                                .fill(canGoNext ? Color.blue : Color.blue.opacity(0.15))
                                .frame(width: 40, height: 40)
                                .rotationEffect(.degrees(90))
                            Triangle()
                                .fill(Color(white: 0.5).opacity(0.03))
                                .frame(width: 40, height: 40)
                                .rotationEffect(.degrees(90))
                        }
                    }
                    .disabled(!canGoNext)
                }
            }

            // ロック（削除とタグ編集ボタンの中間地点）
            Button {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                withAnimation(.easeOut(duration: 0.2)) { showLockConfirm = true }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: currentMemo?.isLocked == true ? "lock.fill" : "lock.open")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(currentMemo?.isLocked == true ? Color.orange.opacity(0.12) : Color.secondary.opacity(0.15))
                        )
                        .overlay(
                            Circle()
                                .stroke(currentMemo?.isLocked == true ? Color.orange.opacity(0.3) : Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                    Text(currentMemo?.isLocked == true ? "解除" : "ロック")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(currentMemo?.isLocked == true ? Color.orange : Color.secondary.opacity(0.7))
            }
            .buttonStyle(.plain)
            .offset(x: 74, y: -10)
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
                resetToFilter()
            } label: {
                Text("終了する")
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

    // フィルター画面に戻す（変更を保存して）
    private func returnToFilter() {
        for m in deleteQueue { modelContext.delete(m) }
        try? modelContext.save()
        resetToFilter()
    }

    // フィルター画面に戻す（変更を保存せず）
    private func returnToFilterWithoutSave() {
        resetToFilter()
    }

    private func resetToFilter() {
        allFilteredMemos = []
        targetMemos = []
        deleteQueue = []
        taggedMemoIDs = []
        titledMemoIDs = []
        editedMemoIDs = []
        scrolledMemoID = nil
        currentSetIndex = 0
        cellEditMode = .none
        showResult = false
        showExitConfirm = false
        showFinishConfirm = false
        phase = .filter
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

                    Text("保存せず終了")
                        .font(.system(size: 17, weight: .bold, design: .rounded))

                    Text("変更は保存されません。\nよろしいですか？")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Text("保存するには「整理を終了」するか\n完走してください。")
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
                    returnToFilterWithoutSave()
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

    // MARK: - 整理おわりダイアログ

    private var finishConfirmDialog: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) { showFinishConfirm = false }
                }

            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            LinearGradient(colors: [.orange, .yellow],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )

                    Text("整理を終了")
                        .font(.system(size: 17, weight: .bold, design: .rounded))

                    Text("ここまでの変更を保存して、\n結果画面を表示します。")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)
                .padding(.bottom, 16)
                .padding(.horizontal, 20)

                Divider()

                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showFinishConfirm = false }
                    withAnimation(.easeOut(duration: 0.25)) { showResult = true }
                } label: {
                    Text("結果を表示")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)

                Divider()

                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showFinishConfirm = false }
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

    // MARK: - ロック確認ダイアログ

    private var lockConfirmDialog: some View {
        let isLocked = currentMemo?.isLocked == true
        return ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) { showLockConfirm = false }
                }

            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Image(systemName: isLocked ? "lock.open.fill" : "lock.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.orange)

                    Text(isLocked ? "削除ロックを解除" : "メモをロック")
                        .font(.system(size: 17, weight: .bold, design: .rounded))

                    Text(isLocked ? "削除ロックを解除します。\nよろしいですか？" : "メモをロック（削除防止）します。\nよろしいですか？")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)
                .padding(.bottom, 16)
                .padding(.horizontal, 20)

                Divider()

                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showLockConfirm = false }
                    if let memo = currentMemo {
                        memo.isLocked.toggle()
                        try? modelContext.save()
                    }
                } label: {
                    Text(isLocked ? "解除する" : "ロックする")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)

                Divider()

                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showLockConfirm = false }
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

    // MARK: - 操作パネルからの削除確認ダイアログ

    private var panelDeleteConfirmDialog: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) { showDeleteConfirmFromPanel = false }
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

                    Text("結果表示画面で復元できます。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary.opacity(0.7))
                        .padding(.top, 2)
                }
                .padding(.top, 24)
                .padding(.bottom, 16)
                .padding(.horizontal, 20)

                Divider()

                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showDeleteConfirmFromPanel = false }
                    if let memo = currentMemo { deleteMemo(memo) }
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
                    withAnimation(.easeOut(duration: 0.2)) { showDeleteConfirmFromPanel = false }
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

    // MARK: - 削除確認シート

    private var deleteReviewSheet: some View {
        NavigationStack {
            List {
                Text("← 左スワイプで復元")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
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
            .listStyle(.plain)
            .navigationTitle("削除予定のメモ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("戻る") { showDeleteReview = false }
                }
            }
        }
    }

    // MARK: - アクション

    private func deleteMemo(_ memo: Memo) {
        // 削除前に現在のインデックスを記憶
        let currentIndex = activeMemos.firstIndex(where: { $0.id == memo.id })
        deleteQueue.append(memo)
        // 削除されたメモを指していたら同じ位置（または前）のカードに移動
        if scrolledMemoID == memo.id {
            if let idx = currentIndex {
                // 同じインデックス位置のメモに移動（なければ末尾）
                if idx < activeMemos.count {
                    scrolledMemoID = activeMemos[idx].id
                } else if let last = activeMemos.last {
                    scrolledMemoID = last.id
                }
            } else if let first = activeMemos.first {
                scrolledMemoID = first.id
            }
        }
        if activeMemos.isEmpty {
            withAnimation(.easeOut(duration: 0.25)) { showResult = true }
        }
    }

    // MARK: - ダミーローディング画面

    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "doc.on.doc.fill")
                .font(.system(size: 50))
                .foregroundStyle(.green)
                .rotationEffect(.degrees(-30))

            Text("\(allFilteredMemos.count)件のメモを準備中…")
                .font(.system(size: 17, weight: .bold, design: .rounded))

            // プログレスバー
            VStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 12)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [.orange, .yellow],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * loadingProgress, height: 12)
                    }
                }
                .frame(height: 12)

                Text("\(Int(loadingProgress * 100))%")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 60)

            Spacer()
        }
        .transition(.opacity)
    }

    // ダミーローディングアニメーション（10件以下: 1.5秒、11件以上: 3秒）
    private func startLoadingAnimation(completion: @escaping () -> Void) {
        let duration = allFilteredMemos.count <= 10 ? 1.5 : 3.0
        let steps = 20
        let interval = duration / Double(steps)
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) {
                withAnimation(.easeOut(duration: 0.05)) {
                    let t = Double(i) / Double(steps)
                    loadingProgress = CGFloat(1 - pow(1 - t, 2.5))
                }
                if i == steps {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            completion()
                        }
                    }
                }
            }
        }
    }

}
