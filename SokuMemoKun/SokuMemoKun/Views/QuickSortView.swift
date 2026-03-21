import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.sokumemokun.app", category: "QuickSort")

// 爆速振り分けモード: メインカード画面（カルーセル方式）
struct QuickSortView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var tags: [Tag]

    var onDismiss: () -> Void

    // フェーズ管理: フィルタ選択 → セット確認 → 準備中 → カルーセル
    enum Phase { case filter, setConfirm, loading, carousel }
    @State private var phase: Phase = .filter

    // セット管理
    private let setSize = 50
    @State private var allFilteredMemos: [Memo] = []  // フィルタ後の全メモ
    @State private var targetMemos: [Memo] = []       // 現在のセット
    @State private var currentSetIndex = 0            // 現在のセット番号（0始まり）
    private var totalSets: Int { max(1, (allFilteredMemos.count + setSize - 1) / setSize) }
    private var isLastSet: Bool { currentSetIndex >= totalSets - 1 }

    @State private var suggestEngine = TagSuggestEngine()

    // カルーセル: scrollPosition で現在のカードを追跡
    @State private var scrolledMemoID: UUID?

    // 上フリック削除用
    @State private var deletingMemoID: UUID? = nil
    @State private var deleteOffset: CGFloat = 0

    // ルーレット（子タグ表示デフォ）
    @State private var selectedParentTagID: UUID? = nil
    @State private var selectedChildTagID: UUID? = nil
    @State private var showChildDial = true
    @State private var childExternalDragY: CGFloat? = nil
    @State private var isInternalTagChange = false

    // 編集
    @State private var editingTitle = ""
    @State private var editingContent = ""
    @State private var isKeyboardVisible = false

    // カード編集モード
    @State private var isCardEditing = false
    @State private var editingTitleSnapshot = ""  // 編集前スナップショット（差分検出用）
    @State private var editingContentSnapshot = ""
    @State private var showDiscardAlert = false
    @FocusState private var titleFieldFocused: Bool

    // タグ追加シート
    @State private var showNewTagSheet = false
    @State private var newTagIsChild = false

    // サジェスト
    @State private var currentSuggestions: [TagSuggestEngine.Suggestion] = []
    @State private var suggestCache: [Int: [TagSuggestEngine.Suggestion]] = [:]

    // 変更ログ
    @State private var taggedMemoIDs: Set<UUID> = []
    @State private var titledMemoIDs: Set<UUID> = []
    @State private var editedMemoIDs: Set<UUID> = []
    @State private var deleteQueue: [Memo] = []
    @State private var skippedIndices: Set<Int> = []

    // 準備中
    @State private var loadingProgress = 0

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
                    // フィルタ選択画面（fullScreenCover内）
                    QuickSortFilterView(
                        onStart: { memos in
                            allFilteredMemos = memos
                            currentSetIndex = 0
                            if memos.count > setSize {
                                // セット確認画面へ
                                phase = .setConfirm
                            } else {
                                // そのまま開始
                                targetMemos = memos
                                phase = .loading
                                prepareAll()
                            }
                        },
                        onCancel: { onDismiss() }
                    )

                case .setConfirm:
                    // セット確認画面
                    setConfirmView

                case .loading:
                    // 準備中画面
                    VStack(spacing: 16) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.orange)
                        Text("準備中...")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Text("\(loadingProgress) / \(targetMemos.count)")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(.secondary)
                        ProgressView(value: Double(loadingProgress), total: Double(max(1, targetMemos.count)))
                            .tint(.orange)
                            .frame(width: 200)
                    }

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
                            // 現在のセットの削除を実行
                            for m in deleteQueue { modelContext.delete(m) }
                            try? modelContext.save()
                            showResult = false
                            // 次のセットへ
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
                parentTagID: newTagIsChild ? selectedParentTagID : nil,
                onTagCreated: { newTagID in
                    isInternalTagChange = true
                    if newTagIsChild {
                        selectedChildTagID = newTagID
                    } else {
                        selectedParentTagID = newTagID
                    }
                    isInternalTagChange = false
                    applyTagFromDial()
                }
            )
        }
        .onAppear { }
        .onChange(of: scrolledMemoID) { oldID, newID in
            // 前のメモを保存（oldIDで特定）
            if let oldID = oldID, let oldMemo = activeMemos.first(where: { $0.id == oldID }) {
                saveToMemo(oldMemo)
            }
            // 新しいメモに同期
            if let newID = newID, let memo = activeMemos.first(where: { $0.id == newID }) {
                syncEditingState(for: memo)
            }
        }
        .onChange(of: selectedParentTagID) { _, _ in
            if !isInternalTagChange { applyTagFromDial() }
        }
        .onChange(of: selectedChildTagID) { _, _ in
            if !isInternalTagChange { applyTagFromDial() }
        }
    }

    // MARK: - メインコンテンツ

    @ViewBuilder
    private func mainContent(geo: GeometryProxy) -> some View {
        let cardWidth = geo.size.width * 0.78

        VStack(spacing: 0) {
            // ナビバー（×と完了）
            navBar
                .padding(.horizontal, 16)
                .padding(.top, 6)

            // カウンター（ドーンと大きく）
            if !activeMemos.isEmpty {
                Text("\(currentIndexInActive + 1) / \(activeMemos.count)")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                    .padding(.top, 2)
            }

            // 通常モード（常に表示、編集中はグレーアウト）
            arrowGuide
                .padding(.top, 6)
                .padding(.bottom, 8)

            // カルーセル（タブ付きカード）
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(activeMemos, id: \.id) { memo in
                        cardItem(memo: memo, width: cardWidth, height: geo.size.height * 0.32)
                            .id(memo.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, (geo.size.width - cardWidth) / 2)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrolledMemoID)
            .scrollDisabled(isCardEditing)
            .padding(.top, 2)

            // 下部: サジェスト(左) + ルーレット(右)
            HStack(alignment: .top, spacing: 0) {
                suggestPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                dialArea
            }
            .frame(height: 215)
            .padding(.top, 4)
        }
    }

    // MARK: - カルーセルのカード1枚（タブ付き：左上にタイトルタブ、右上に鉛筆ボタン）

    @ViewBuilder
    private func cardItem(memo: Memo, width: CGFloat, height: CGFloat) -> some View {
        let isDeleting = deletingMemoID == memo.id
        let isCurrent = scrolledMemoID == memo.id
        let title = isCurrent ? editingTitle : memo.title

        ZStack(alignment: .topLeading) {
            let tabH: CGFloat = 26
            let tabW: CGFloat = min(width * 0.6, 180)
            let bodyR: CGFloat = 14

            // 一体成型の背景Shape
            CardWithTabShape(tabWidth: tabW, tabHeight: tabH, bodyRadius: bodyR)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)

            // コンテンツ
            VStack(alignment: .leading, spacing: 0) {
                // タブ行
                HStack(spacing: 0) {
                    // タイトルテキスト
                    Text(title.isEmpty ? "タイトルなし" : title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(title.isEmpty ? Color.secondary.opacity(0.4) : Color.primary)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .frame(height: tabH)
                        .frame(maxWidth: tabW, alignment: .leading)

                    Spacer()

                    // 鉛筆ボタン
                    Button {
                        if scrolledMemoID != memo.id { scrolledMemoID = memo.id }
                        enterEditMode()
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 4)
                    .padding(.top, 4)
                }

                // 本文（タブ高さから開始）
                Text(memo.content.isEmpty ? "（本文なし）" : memo.content)
                    .font(.system(size: 13))
                    .foregroundColor(memo.content.isEmpty ? Color.secondary.opacity(0.4) : Color.primary)
                    .lineLimit(nil)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(12)
            }

            // タグバッジ（右下）
            tagBadge(for: memo)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: -8, y: 6)
        }
        .frame(width: width, height: height)
        .offset(y: isDeleting ? deleteOffset : 0)
        .opacity(isDeleting ? max(0.0, 1.0 + Double(deleteOffset) / 300.0) : 1.0)
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    let t = value.translation
                    if t.height < -15 && abs(t.height) > abs(t.width) * 1.5 {
                        deletingMemoID = memo.id
                        deleteOffset = t.height
                    }
                }
                .onEnded { value in
                    guard deletingMemoID == memo.id else { return }
                    if value.translation.height < -100 {
                        withAnimation(.easeOut(duration: 0.2)) { deleteOffset = -500 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            deleteMemo(memo)
                            deletingMemoID = nil
                            deleteOffset = 0
                        }
                    } else {
                        withAnimation(.spring(response: 0.3)) { deleteOffset = 0 }
                        deletingMemoID = nil
                    }
                }
        )
    }

    // MARK: - カード編集オーバーレイ（背景グレーアウト + カードが浮き上がる）

    @ViewBuilder
    private func cardEditOverlay(geo: GeometryProxy) -> some View {
        ZStack {
            // 背景グレーアウト
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    // 背景タップでキーボード閉じる
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }

            // 浮かぶ編集カード
            VStack(spacing: 0) {
                // 編集ヘッダー（キャンセル / 確定）
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

                // 編集カード本体
                VStack(alignment: .leading, spacing: 0) {
                    // タイトル入力
                    HStack {
                        Text("タイトル")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary.opacity(0.5))
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)

                    TextField("タイトルを入力", text: $editingTitle)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .focused($titleFieldFocused)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)

                    Divider().padding(.horizontal, 14)

                    // 本文入力
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
            Button("破棄する", role: .destructive) { exitEditMode(discard: true) }
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

                // セット一覧
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

            // 開始ボタン
            Button {
                startCurrentSet()
            } label: {
                Text("セット\(currentSetIndex + 1)を開始")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.orange))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            // 閉じるボタン
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

    // 現在のセットのメモを切り出して準備開始
    private func startCurrentSet() {
        let start = currentSetIndex * setSize
        let end = min(start + setSize, allFilteredMemos.count)
        targetMemos = Array(allFilteredMemos[start..<end])

        // 前セットの状態をリセット
        deleteQueue = []
        taggedMemoIDs = []
        titledMemoIDs = []
        editedMemoIDs = []
        suggestCache = [:]
        scrolledMemoID = nil
        currentSuggestions = []

        phase = .loading
        prepareAll()
    }

    private func enterEditMode() {
        editingTitleSnapshot = editingTitle
        editingContentSnapshot = editingContent
        withAnimation(.spring(response: 0.3)) { isCardEditing = true }
        // タイトル末尾にカーソル
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            titleFieldFocused = true
        }
    }

    private func exitEditMode(discard: Bool) {
        if discard {
            editingTitle = editingTitleSnapshot
            editingContent = editingContentSnapshot
        } else {
            // 確定: メモオブジェクトに反映
            saveCurrent()
        }
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        withAnimation(.spring(response: 0.3)) { isCardEditing = false }
    }

    // MARK: - タグバッジ（MemoInputViewのtagDisplayと同じデザイン・大きめ）

    @ViewBuilder
    private func tagBadge(for memo: Memo) -> some View {
        let parentTag = memo.tags.first(where: { $0.parentTagID == nil })
        let childTag = memo.tags.first(where: { $0.parentTagID != nil })

        if let pt = parentTag {
            if let ct = childTag {
                // 親タグ＋右下に子タグめり込み
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
                // 親タグのみ
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
        } else {
            // タグなし
            HStack(spacing: 4) {
                Image(systemName: "tag")
                    .font(.system(size: 13))
                Text("タグなし")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.secondary.opacity(0.6))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(tagColor(for: 0))
                    .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
            )
        }
    }

    // MARK: - ナビバー（×と完了のみ）

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
                saveCurrent()
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

    // MARK: - 終了確認ダイアログ（リッチ）

    private var exitConfirmDialog: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) { showExitConfirm = false }
                }

            VStack(spacing: 0) {
                // ヘッダー
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

                // 終了する
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

                // 戻る
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

    // MARK: - 3方向矢印ガイド（三角配置・でかく極太）

    private var arrowGuide: some View {
        let isDeleteActive = deletingMemoID != nil && deleteOffset < -30

        return VStack(spacing: 0) {
            // 上: 削除（赤）
            VStack(spacing: -2) {
                Image(systemName: "arrow.up")
                    .font(.system(size: isDeleteActive ? 50 : 40, weight: .black))
                Text("削除")
                    .font(.system(size: isDeleteActive ? 22 : 18, weight: .black, design: .rounded))
            }
            .foregroundStyle(isDeleteActive ? .red : .red.opacity(0.3))
            .animation(.easeOut(duration: 0.15), value: isDeleteActive)

            // 下: 左右（青）
            HStack(spacing: 50) {
                // 左: 前
                HStack(spacing: 2) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 30, weight: .black))
                    Text("前")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                }
                .foregroundStyle(.blue.opacity(0.25))

                // 右: 次
                HStack(spacing: 2) {
                    Text("次")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 30, weight: .black))
                }
                .foregroundStyle(.blue.opacity(0.25))
            }
            .padding(.top, -4)
        }
    }



    // MARK: - サジェストパネル（枠付き）

    private var suggestPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !currentSuggestions.isEmpty {
                let dictSugs = currentSuggestions.filter { $0.kind == .dictMatch }
                let newSugs = currentSuggestions.filter { $0.kind == .newTag }
                let histSugs = currentSuggestions.filter { $0.kind == .history }

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

    // MARK: - ルーレット（トレー風・常時全開・子タグ常時表示）

    // ルーレットオプション生成
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
        // 親タグ未選択でも「子タグなし」だけ表示（常時子ダイアル表示のため）
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
                    showNewTagSheet = true
                    newTagIsChild = false
                } label: {
                    Label("親タグ追加", systemImage: "plus.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
                Button {
                    if selectedParentTagID != nil {
                        showNewTagSheet = true
                        newTagIsChild = true
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

    // 現在のメモ情報をローカル編集状態に同期
    private func syncEditingState(for memo: Memo) {
        editingTitle = memo.title
        editingContent = memo.content

        isInternalTagChange = true
        let parentTag = memo.tags.first(where: { $0.parentTagID == nil })
        let childTag = memo.tags.first(where: { $0.parentTagID != nil })
        selectedParentTagID = parentTag?.id
        selectedChildTagID = childTag?.id
        if parentTag != nil {
            let hasChildren = tags.contains(where: { $0.parentTagID == parentTag?.id })
            if hasChildren { showChildDial = true }
        }
        isInternalTagChange = false

        updateSuggestions()
    }

    // 指定したメモに現在の編集内容を保存（変更があったときだけupdatedAt更新）
    private func saveToMemo(_ memo: Memo) {
        let origTitle = memo.title
        let origContent = memo.content
        let newTitle = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        var changed = false

        if newTitle != origTitle {
            memo.title = newTitle
            if !newTitle.isEmpty { titledMemoIDs.insert(memo.id) }
            changed = true
        }
        if editingContent != origContent {
            memo.content = editingContent
            editedMemoIDs.insert(memo.id)
            changed = true
        }
        if changed { memo.updatedAt = Date() }
    }

    private func saveCurrent() {
        guard let memo = currentMemo else { return }
        saveToMemo(memo)
    }

    private func deleteMemo(_ memo: Memo) {
        // 前のメモを保存してから
        saveCurrent()
        deleteQueue.append(memo)
        // カルーセルが自動で隣のカードを表示する
        // scrolledMemoIDが削除されたカードを指していたら次のに移る
        if scrolledMemoID == memo.id {
            let remaining = activeMemos
            if let first = remaining.first {
                scrolledMemoID = first.id
                syncEditingState(for: first)
            }
        }
        if activeMemos.isEmpty {
            withAnimation(.easeOut(duration: 0.25)) { showResult = true }
        }
    }

    private func applyTagFromDial() {
        guard let memo = currentMemo else { return }
        let originalTags = Set(memo.tags.map { $0.id })
        memo.tags.removeAll()
        if let pid = selectedParentTagID, let tag = tags.first(where: { $0.id == pid }) { memo.tags.append(tag) }
        if let cid = selectedChildTagID, let tag = tags.first(where: { $0.id == cid }) { memo.tags.append(tag) }
        let newTags = Set(memo.tags.map { $0.id })
        if originalTags != newTags {
            memo.updatedAt = Date()
            taggedMemoIDs.insert(memo.id)
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

    private func applyTitleEdit() {
        guard let memo = currentMemo else { return }
        let newTitle = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if newTitle != memo.title {
            memo.title = newTitle
            memo.updatedAt = Date()
            if !newTitle.isEmpty { titledMemoIDs.insert(memo.id) }
        }
    }

    private func applyContentEdit() {
        guard let memo = currentMemo else { return }
        if editingContent != memo.content {
            memo.content = editingContent
            memo.updatedAt = Date()
            editedMemoIDs.insert(memo.id)
        }
    }

    // MARK: - サジェスト

    // 起動時に全メモのサジェストを一括計算
    private func prepareAll() {
        loadingProgress = 0

        // バックグラウンドで計算してメインスレッドにUI更新
        Task {
            var cache: [Int: [TagSuggestEngine.Suggestion]] = [:]
            let allTags = tags
            let ctx = modelContext

            for (i, memo) in targetMemos.enumerated() {
                let result = suggestEngine.suggest(
                    title: memo.title, body: memo.content,
                    tags: allTags, context: ctx, limit: 3
                )
                cache[i] = result

                // UI更新（数件ごとにまとめて更新）
                if i % 5 == 0 || i == targetMemos.count - 1 {
                    await MainActor.run {
                        loadingProgress = i + 1
                    }
                }
            }

            await MainActor.run {
                suggestCache = cache
                loadingProgress = targetMemos.count

                // 初期表示
                if let first = activeMemos.first {
                    scrolledMemoID = first.id
                    syncEditingState(for: first)
                }
                phase = .carousel
            }
        }
    }

    private func updateSuggestions() {
        guard let memo = currentMemo else { currentSuggestions = []; return }
        let idx = targetMemos.firstIndex(where: { $0.id == memo.id }) ?? 0
        if let cached = suggestCache[idx] { currentSuggestions = cached; return }
        // キャッシュにない場合（通常ありえないが安全のため）
        let result = suggestEngine.suggest(title: memo.title, body: memo.content, tags: tags, context: modelContext, limit: 3)
        currentSuggestions = result
        suggestCache[idx] = result
    }
}

// MARK: - タブ付きカード一体成型Shape

struct CardWithTabShape: Shape {
    var tabWidth: CGFloat
    var tabHeight: CGFloat
    var bodyRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let tabR: CGFloat = 7       // タブ上部角丸
        let tabInset: CGFloat = 5   // タブの台形傾き
        let jointR: CGFloat = 8     // タブと本体の接続部の逆カーブ

        // タブの座標
        let tabTopLeft = CGPoint(x: tabInset, y: 0)
        let tabTopRight = CGPoint(x: tabWidth - tabInset, y: 0)
        let tabBottomRight = CGPoint(x: tabWidth, y: tabHeight)
        // 本体の上辺はy=tabHeight
        let bodyTop = tabHeight
        let bodyRight = rect.maxX

        var p = Path()

        // 左下から開始
        p.move(to: CGPoint(x: 0, y: rect.maxY - bodyRadius))
        // 左下角丸
        p.addArc(tangent1End: CGPoint(x: 0, y: rect.maxY),
                 tangent2End: CGPoint(x: bodyRadius, y: rect.maxY), radius: bodyRadius)
        // 下辺
        p.addLine(to: CGPoint(x: bodyRight - bodyRadius, y: rect.maxY))
        // 右下角丸
        p.addArc(tangent1End: CGPoint(x: bodyRight, y: rect.maxY),
                 tangent2End: CGPoint(x: bodyRight, y: rect.maxY - bodyRadius), radius: bodyRadius)
        // 右辺
        p.addLine(to: CGPoint(x: bodyRight, y: bodyTop + bodyRadius))
        // 右上角丸
        p.addArc(tangent1End: CGPoint(x: bodyRight, y: bodyTop),
                 tangent2End: CGPoint(x: bodyRight - bodyRadius, y: bodyTop), radius: bodyRadius)
        // 上辺（タブ右端まで）
        p.addLine(to: CGPoint(x: tabWidth + jointR, y: bodyTop))
        // タブ右の逆カーブ（本体上辺→タブ右下）
        p.addArc(tangent1End: tabBottomRight,
                 tangent2End: tabTopRight, radius: jointR)
        // タブ右上角丸
        p.addArc(tangent1End: tabTopRight,
                 tangent2End: tabTopLeft, radius: tabR)
        // タブ左上角丸
        p.addArc(tangent1End: tabTopLeft,
                 tangent2End: CGPoint(x: 0, y: tabHeight), radius: tabR)
        // タブ左辺→本体左辺へ（そのまま下に）
        p.addLine(to: CGPoint(x: 0, y: rect.maxY - bodyRadius))

        p.closeSubpath()
        return p
    }
}
