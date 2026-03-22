import SwiftUI
import SwiftData
import os

private let qsLogger = Logger(subsystem: "com.sokumemokun.app", category: "QuickSort")


struct MainView: View {
    @State private var viewModel = MemoInputViewModel()
    @State private var suggestEngine = TagSuggestEngine()
    @State private var suggestions: [TagSuggestEngine.Suggestion] = []
    @State private var suggestDismissed = false // そのメモ確定まで非表示
    @State private var suggestDebounceTask: Task<Void, Never>?
    @AppStorage("tagSuggestEnabled") private var tagSuggestEnabled = true
    @State private var isKeyboardVisible = false
    @State private var showSettings = false
    @State private var focusInput = false
    @State private var selectedTabIndex: Int = 0
    @State private var searchText = ""
    @State private var isSearchFocused = false
    @FocusState private var isSearchFieldFocused: Bool
    @State private var isInputExpanded = false
    @State private var isMemoListExpanded = false
    @State private var enteredFromMemoList = false
    @State private var showSavedToast = false
    @State private var originalContent = ""
    @State private var originalTitle = ""
    // 「ここに保存」確認ダイアログ
    @State private var showSaveToTabAlert = false
    @State private var pendingSaveTagID: UUID? = nil
    // フォルダタブ並び替えモード中フラグ
    @State private var isTabReorderMode = false
    // 爆速メモ整理モード
    @State private var showQuickSort = false
    // ToDoリストモード
    @State private var showTodoList = false
    // サジェスト新規タグ作成ダイアログ
    @State private var showNewTagConfirm = false
    @State private var pendingNewTagName = ""
    @State private var showNewTagColorSheet = false
    @AppStorage("defaultMarkdown") private var defaultMarkdown = false
    @AppStorage("markdownEnabled") private var markdownEnabled = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \Tag.name) private var tags: [Tag]

    // 横画面かつiPad判定（横画面の時だけ左右分割）
    private var isIPad: Bool { horizontalSizeClass == .regular && UIDevice.current.userInterfaceIdiom == .pad }
    private var useSideBySide: Bool { isIPad && isLandscape }
    @State private var isLandscape = false

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                if useSideBySide {
                    // iPad横画面: 左右分割レイアウト（右利き: 左=フォルダ、右=入力欄）
                    HStack(spacing: 0) {
                        // 左: フォルダ付きメモ一覧
                        tabbedMemoList
                            .frame(width: geo.size.width * 0.6)

                        // 区切り線
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 1)

                        // 右: 入力欄
                        MemoInputView(
                            viewModel: viewModel,
                            focusInput: $focusInput,
                            isExpanded: .constant(false),
                            hasDiff: viewModel.inputText != originalContent || viewModel.titleText != originalTitle,
                            onConfirm: { confirmMemo() }
                        )
                    }
                } else {
                    // iPhone: 上下分割レイアウト（従来通り）
                    VStack(spacing: 0) {
                        if !isMemoListExpanded {
                            MemoInputView(
                                viewModel: viewModel,
                                focusInput: $focusInput,
                                isExpanded: $isInputExpanded,
                                hasDiff: viewModel.inputText != originalContent || viewModel.titleText != originalTitle,
                                onConfirm: { confirmMemo() }
                            )
                            .frame(height: isInputExpanded ? geo.size.height * 0.92 : geo.size.height * 0.48 - 30)

                            // Specialメニュー用スペース（入力欄とフォルダの間）
                            // 並び替えモード中は非表示（全体を上に詰める）
                            if !isInputExpanded && !isTabReorderMode {
                                HStack(spacing: 0) {
                                    // 爆速メモ整理ボタン
                                    Button {
                                        showQuickSort = true
                                    } label: {
                                        Image(systemName: "bolt.fill")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.orange.opacity(0.7))
                                            .frame(width: 44, height: 30)
                                    }
                                    .buttonStyle(.plain)

                                    // ToDoリストボタン
                                    Button {
                                        showTodoList = true
                                    } label: {
                                        Image(systemName: "checklist")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.blue.opacity(0.7))
                                            .frame(width: 44, height: 30)
                                    }
                                    .buttonStyle(.plain)

                                    // 中央: メモ一覧最大化
                                    Button {
                                        withAnimation(.spring(response: 0.35)) {
                                            isMemoListExpanded = true
                                        }
                                    } label: {
                                        Image(systemName: "chevron.compact.up")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(.secondary.opacity(0.5))
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 30)
                                    }
                                    .buttonStyle(.plain)

                                    // 右のスペーサー（左右バランス用）
                                    Color.clear.frame(width: 44, height: 30)
                                }
                            }
                        } else {
                            Button {
                                withAnimation(.spring(response: 0.35)) {
                                    isMemoListExpanded = false
                                }
                            } label: {
                                Image(systemName: "chevron.compact.down")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 28)
                                    .background(Color(uiColor: .secondarySystemBackground).opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }

                        tabbedMemoList
                    }
                    .overlay(alignment: .center) {
                        // サジェストを画面中央付近に表示（フォルダタブ位置に依存しない）
                        tagSuggestOverlay
                            .offset(y: -geo.size.height * 0.08)
                    }
                }
            }
            .ignoresSafeArea(.keyboard)
            .onChange(of: viewModel.inputText) { _, _ in triggerSuggest() }
            .onChange(of: viewModel.titleText) { _, _ in triggerSuggest() }
            .onChange(of: viewModel.selectedTagID) { _, newVal in
                if newVal != nil {
                    suggestions = [] // タグ選択されたら消す
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 左: 展開時は「←」で縮小、最大化時は「↓」で戻す、通常時は「＋」で新規メモ
                ToolbarItem(placement: .topBarLeading) {
                    if isInputExpanded {
                        Button {
                            if enteredFromMemoList {
                                // メモ一覧最大化から来た場合→メモ一覧最大化に戻る
                                enteredFromMemoList = false
                                isInputExpanded = false
                                isMemoListExpanded = true
                            } else {
                                isInputExpanded = false
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17))
                        }
                    } else if isMemoListExpanded {
                        Button {
                            withAnimation(.spring(response: 0.35)) {
                                isMemoListExpanded = false
                            }
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 17))
                        }
                    } else {
                        Button {
                            viewModel.clearInput()
                            focusInput = true
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 17))
                        }
                    }
                }
                // 中央: 検索バー（未フォーカス時は短め、フォーカスで横いっぱいに広がる）
                ToolbarItem(placement: .principal) {
                    let expanded = isSearchFocused || !searchText.isEmpty
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        ZStack {
                            // 縮小時のラベル
                            Text("メモを探す")
                                .font(.system(size: 15, design: .rounded))
                                .foregroundStyle(.secondary)
                                .opacity(expanded ? 0 : 1)
                            // 常に存在するTextField（縮小時は非表示・無効）
                            TextField("", text: $searchText)
                                .font(.system(size: 15, design: .rounded))
                                .textFieldStyle(.plain)
                                .autocorrectionDisabled()
                                .focused($isSearchFieldFocused)
                                .opacity(expanded ? 1 : 0)
                                .disabled(!expanded)
                        }
                        // バツ印（拡大中のみ表示）
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .opacity(expanded ? 1 : 0)
                            .onTapGesture {
                                searchText = ""
                                isSearchFieldFocused = false
                                isSearchFocused = false
                            }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(uiColor: .secondarySystemBackground))
                    )
                    .frame(maxWidth: expanded ? .infinity : 170)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !isSearchFocused {
                            withAnimation(.easeOut(duration: 0.2)) {
                                isSearchFocused = true
                            }
                            // アニメーション完了後にフォーカスを当てる
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                isSearchFieldFocused = true
                            }
                        }
                    }
                }
                // 右: 差分ありの入力欄最大化時は「確定」、それ以外は設定
                ToolbarItem(placement: .topBarTrailing) {
                    let isEditing = viewModel.editingMemo != nil
                    let hasDiff = viewModel.inputText != originalContent || viewModel.titleText != originalTitle
                    let hasContent = viewModel.hasText
                    let showConfirm = isInputExpanded && hasContent && (!isEditing || hasDiff)
                    if showConfirm {
                        Button {
                            confirmMemo()
                        } label: {
                            Text("確定")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.blue)
                        }
                    } else {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 15))
                        }
                    }
                }
            }
            // 保存トースト
            .overlay(alignment: .top) {
                if showSavedToast {
                    Text("保存しました")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.7))
                        )
                        .padding(.top, 60)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showSavedToast)
            .fullScreenCover(isPresented: $showQuickSort) {
                QuickSortView(onDismiss: { showQuickSort = false })
            }
            .fullScreenCover(isPresented: $showTodoList) {
                TodoListView(onDismiss: { showTodoList = false })
            }
            .sheet(isPresented: $showSettings, onDismiss: {
                // 設定画面を閉じた時にマスタースイッチの状態を反映
                if !markdownEnabled {
                    viewModel.isMarkdown = false
                } else if viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    viewModel.isMarkdown = defaultMarkdown
                }
            }) {
                SettingsView()
            }
            .onChange(of: defaultMarkdown) { _, newValue in
                if viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    viewModel.isMarkdown = newValue
                }
            }
            .onChange(of: markdownEnabled) { _, newValue in
                // マスタースイッチOFF → 強制的にマークダウン解除
                if !newValue {
                    viewModel.isMarkdown = false
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .switchToTab)) { notification in
                if let tabIndex = notification.userInfo?["tabIndex"] as? Int {
                    selectedTabIndex = tabIndex
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if isKeyboardVisible {
                    Button {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
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
                // 検索テキストが空ならフォーカス解除→検索バーを縮小
                if searchText.isEmpty {
                    isSearchFocused = false
                }
            }
            .alert("このメモを「\(saveToTabTagName)」に保存します。よろしいですか？", isPresented: $showSaveToTabAlert) {
                Button("保存") {
                    let savedMemoID = viewModel.editingMemo?.id
                    viewModel.selectedTagID = pendingSaveTagID
                    viewModel.onTagChanged(tags: tags)
                    try? modelContext.save()
                    viewModel.clearInput()
                    if let memoID = savedMemoID {
                        NotificationCenter.default.post(
                            name: .memoSavedFlash,
                            object: nil,
                            userInfo: ["memoID": memoID]
                        )
                    }
                }
                Button("キャンセル", role: .cancel) {}
            }
            .overlay {
                if showNewTagConfirm {
                    newTagConfirmDialog
                }
            }
            .sheet(isPresented: $showNewTagColorSheet, onDismiss: {
                // タグが作成されなかった（キャンセル）→ ダイアログに戻る
                if viewModel.selectedTagID == nil || tags.first(where: { $0.name == pendingNewTagName }) == nil {
                    showNewTagConfirm = true
                } else {
                    suggestions = [] // 作成確定で消す
                }
            }) {
                NewTagSheetView(
                    onTagCreated: { newTagID in
                        viewModel.selectedTagID = newTagID
                        viewModel.onTagChanged(tags: tags)
                    },
                    initialName: pendingNewTagName,
                    initialColorIndex: 1 // アクア（デフォルト）
                )
            }
            .onAppear {
                viewModel.suggestEngine = suggestEngine
                viewModel.suggestContext = modelContext
                viewModel.restoreLastMemo(context: modelContext)
                if !markdownEnabled {
                    viewModel.isMarkdown = false
                }
                // 画面向き初期化
                updateLandscape()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                updateLandscape()
            }
        }
    }

    // 画面向き更新
    private func updateLandscape() {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
        if let interfaceOrientation = scene?.interfaceOrientation {
            isLandscape = interfaceOrientation.isLandscape
        }
    }

    // 確定処理（共通）
    private func confirmMemo() {
        let savedMemoID = viewModel.editingMemo?.id
        viewModel.clearInput()
        originalContent = ""
        originalTitle = ""
        suggestDismissed = false // 新しいメモでサジェスト復活
        suggestions = []
        showSavedToast = true
        if let memoID = savedMemoID {
            NotificationCenter.default.post(
                name: .memoSavedFlash,
                object: nil,
                userInfo: ["memoID": memoID]
            )
        }
        if enteredFromMemoList {
            enteredFromMemoList = false
            withAnimation(.spring(response: 0.35)) {
                isInputExpanded = false
                isMemoListExpanded = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showSavedToast = false }
        }
    }

    // フォルダ付きメモ一覧（iPhone/iPad共通）
    private var tabbedMemoList: some View {
        TabbedMemoListView(
            selectedTabIndex: $selectedTabIndex,
            searchText: $searchText,
            onAddMemo: { tagID, childTagID in
                if isMemoListExpanded {
                    viewModel.clearInput()
                    viewModel.isLoadingMemo = true
                    viewModel.selectedTagID = tagID
                    viewModel.selectedChildTagID = childTagID
                    enteredFromMemoList = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        viewModel.isLoadingMemo = false
                    }
                    withAnimation(.spring(response: 0.35)) {
                        isMemoListExpanded = false
                        isInputExpanded = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        focusInput = true
                    }
                } else {
                    viewModel.clearInput()
                    viewModel.isLoadingMemo = true
                    viewModel.selectedTagID = tagID
                    viewModel.selectedChildTagID = childTagID
                    focusInput = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        viewModel.isLoadingMemo = false
                    }
                }
            },
            onEditMemo: { memo in
                if isMemoListExpanded {
                    viewModel.loadMemo(memo)
                    originalContent = viewModel.inputText
                    originalTitle = viewModel.titleText
                    enteredFromMemoList = true
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.9)) {
                        isMemoListExpanded = false
                        isInputExpanded = true
                    }
                } else {
                    viewModel.loadMemo(memo)
                    originalContent = viewModel.inputText
                    originalTitle = viewModel.titleText
                }
            },
            onDeleteMemo: { memo in
                if viewModel.editingMemo?.id == memo.id {
                    viewModel.clearInput()
                }
            },
            isCompact: useSideBySide ? false : isInputExpanded,
            onAddToCurrentTab: { tagID in
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                pendingSaveTagID = tagID
                showSaveToTabAlert = true
            },
            isInReorderMode: $isTabReorderMode
        )
    }

    // 「ここに保存」ダイアログ用のタグ名
    private var saveToTabTagName: String {
        if let tagID = pendingSaveTagID,
           let tag = tags.first(where: { $0.id == tagID }) {
            return tag.name
        }
        return "タグなし"
    }

    // MARK: - タグサジェスト

    // サジェスト表示条件: 設定ON & タグ未選択 & 閉じてない & 候補あり
    private var shouldShowSuggestions: Bool {
        tagSuggestEnabled
        && viewModel.selectedTagID == nil
        && !suggestDismissed
        && !suggestions.isEmpty
    }

    // セクションごとにフィルタ
    private var dictSuggestions: [TagSuggestEngine.Suggestion] {
        suggestions.filter { $0.kind == .dictMatch }
    }
    private var newTagSuggestions: [TagSuggestEngine.Suggestion] {
        suggestions.filter { $0.kind == .newTag }
    }
    private var historySuggestions: [TagSuggestEngine.Suggestion] {
        suggestions.filter { $0.kind == .history }
    }

    // サジェストオーバーレイ
    @ViewBuilder
    private var tagSuggestOverlay: some View {
        if shouldShowSuggestions {
            VStack(spacing: 4) {
                // タイトル + 閉じるボタン
                HStack {
                    Text("タグの提案")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        suggestDismissed = true
                        suggestions = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)

                // セクション1: おすすめタグ
                if !dictSuggestions.isEmpty {
                    suggestSection(title: "おすすめタグ", icon: "tag.fill", suggestions: dictSuggestions)
                }

                // セクション2: 新規タグ提案
                if !newTagSuggestions.isEmpty {
                    suggestSection(title: "新規タグ提案", icon: "plus.circle.fill", suggestions: newTagSuggestions)
                }

                // セクション3: 履歴から
                if !historySuggestions.isEmpty {
                    suggestSection(title: "履歴から", icon: "clock.fill", suggestions: historySuggestions)
                }
            }
            .padding(.bottom, 6)
            .background(Color(uiColor: .secondarySystemBackground).opacity(0.9))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            .padding(.horizontal, 12)
            .padding(.top, 4)
        }
    }

    // セクション共通ビュー
    @ViewBuilder
    private func suggestSection(title: String, icon: String, suggestions: [TagSuggestEngine.Suggestion]) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)

            ForEach(suggestions) { suggestion in
                Button {
                    applySuggestion(suggestion)
                } label: {
                    HStack(spacing: 6) {
                        if suggestion.kind == .newTag {
                            // 新規タグ提案：＋アイコン + 緑色
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.green)
                            Text(suggestion.parentName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text("タグを作成")
                                .font(.system(size: 11))
                                .foregroundStyle(.green)
                        } else {
                            // 既存タグ：色付き丸
                            if let parentTag = tags.first(where: { $0.id == suggestion.parentID }) {
                                Circle()
                                    .fill(tagColor(for: parentTag.colorIndex))
                                    .frame(width: 10, height: 10)
                            }
                            Text(suggestion.parentName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.primary)
                            if let childName = suggestion.childName {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                                Text(childName)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        suggestion.kind == .newTag
                            ? Color.green.opacity(0.08)
                            : Color(uiColor: .systemBackground).opacity(0.95)
                    )
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
    }

    // サジェストをタップ → 既存タグ適用 or 新規タグ確認ダイアログ
    private func applySuggestion(_ suggestion: TagSuggestEngine.Suggestion) {
        if suggestion.kind == .newTag {
            // 新規タグ → 確認ダイアログを表示（サジェストリストは消さない）
            pendingNewTagName = suggestion.parentName
            showNewTagConfirm = true
        } else {
            viewModel.selectedTagID = suggestion.parentID
            if let childID = suggestion.childID {
                viewModel.selectedChildTagID = childID
            }
            viewModel.onTagChanged(tags: tags)
            suggestions = [] // 既存タグ適用時のみ消す
        }
    }

    // おまかせカラーで新規タグを即作成
    private func createNewTagWithAutoColor() {
        let colorIndex = pickDistinctColor(tags: tags)
        let newTag = Tag(name: pendingNewTagName, colorIndex: colorIndex)
        let maxOrder = tags.filter { $0.parentTagID == nil }.map { $0.sortOrder }.max() ?? 0
        newTag.sortOrder = maxOrder + 1
        modelContext.insert(newTag)
        try? modelContext.save()
        viewModel.selectedTagID = newTag.id
        viewModel.onTagChanged(tags: tags + [newTag])
        suggestions = [] // 作成確定で消す
    }

    // RGBから色相(0〜360)を計算
    private func hueFromColorIndex(_ index: Int) -> Double {
        // tabColorsのRGB値から色相を算出（TabbedMemoListViewのパレット対応）
        let rgbTable: [(r: Double, g: Double, b: Double)] = [
            (0.82, 0.80, 0.76), // 0: タグなし
            (0.55, 0.80, 0.95), // 1: 水色
            (0.95, 0.70, 0.55), // 2: オレンジ
            (0.70, 0.90, 0.70), // 3: 緑
            (0.90, 0.70, 0.90), // 4: 紫
            (0.95, 0.85, 0.55), // 5: 黄色
            (0.95, 0.60, 0.60), // 6: 赤
            (0.60, 0.75, 0.95), // 7: 青
            (0.80, 0.92, 0.98), // 8: ベビーブルー
            (0.98, 0.85, 0.80), // 9: ピーチ
            (0.85, 0.95, 0.85), // 10: ミント
            (0.95, 0.85, 0.95), // 11: ラベンダー
            (0.98, 0.95, 0.80), // 12: クリーム
            (0.98, 0.82, 0.82), // 13: サーモンピンク
            (0.82, 0.88, 0.98), // 14: ペリウィンクル
            (0.35, 0.65, 0.80), // 15: ティール
            (0.85, 0.60, 0.45), // 16: テラコッタ
            (0.40, 0.70, 0.50), // 17: フォレスト
            (0.75, 0.58, 0.78), // 18: プラム
            (0.80, 0.70, 0.40), // 19: マスタード
            (0.82, 0.52, 0.52), // 20: ワインレッド
            (0.52, 0.62, 0.85), // 21: インディゴ
            (0.50, 0.85, 0.80), // 22: ターコイズ
            (0.95, 0.55, 0.40), // 23: コーラル
            (0.60, 0.82, 0.55), // 24: ライム
            (0.75, 0.55, 0.85), // 25: アメジスト
            (0.90, 0.80, 0.50), // 26: ゴールド
            (0.88, 0.55, 0.62), // 27: ローズ
            (0.50, 0.65, 0.85), // 28: スレートブルー
            (0.85, 0.78, 0.68), // 29: サンド
            (0.72, 0.82, 0.75), // 30: セージ
            (0.78, 0.72, 0.65), // 31: モカ
            (0.88, 0.85, 0.78), // 32: アイボリー
            (0.68, 0.75, 0.70), // 33: オリーブグレー
            (0.82, 0.70, 0.62), // 34: キャメル
            (0.75, 0.80, 0.82), // 35: ブルーグレー
            (0.98, 0.45, 0.52), // 36: ホットピンク
            (0.30, 0.75, 0.93), // 37: スカイブルー
            (0.55, 0.88, 0.45), // 38: ブライトグリーン
            (0.98, 0.75, 0.30), // 39: マンゴー
            (0.68, 0.52, 0.92), // 40: バイオレット
            (0.98, 0.42, 0.30), // 41: トマト
            (0.25, 0.82, 0.75), // 42: エメラルド
            (0.75, 0.68, 0.72), // 43: モーヴ
            (0.68, 0.78, 0.75), // 44: ダスティミント
            (0.82, 0.75, 0.72), // 45: ダスティローズ
            (0.72, 0.72, 0.80), // 46: ダスティブルー
            (0.78, 0.80, 0.68), // 47: カーキ
            (0.80, 0.68, 0.68), // 48: ベージュピンク
            (0.68, 0.75, 0.82), // 49: ストーンブルー
            (0.88, 0.62, 0.48), // 50: テラコッタライト
            (0.58, 0.72, 0.68), // 51: ヴィンテージグリーン
            (0.72, 0.58, 0.52), // 52: ココア
            (0.62, 0.68, 0.82), // 53: ウェッジウッド
            (0.85, 0.72, 0.52), // 54: ハニー
            (0.78, 0.60, 0.65), // 55: ボルドー
            (0.52, 0.72, 0.78), // 56: ナイルブルー
            (0.98, 0.60, 0.75), // 57: フラミンゴ
            (0.45, 0.82, 0.95), // 58: アクアマリン
            (0.75, 0.92, 0.45), // 59: キウイ
            (0.95, 0.82, 0.40), // 60: サンフラワー
            (0.82, 0.55, 0.92), // 61: オーキッド
            (0.92, 0.52, 0.45), // 62: パプリカ
            (0.40, 0.88, 0.82), // 63: ミントソーダ
            (0.62, 0.58, 0.65), // 64: ラベンダーグレー
            (0.65, 0.70, 0.62), // 65: モスグレー
            (0.72, 0.62, 0.58), // 66: クレイ
            (0.58, 0.65, 0.72), // 67: フォグブルー
            (0.75, 0.72, 0.58), // 68: サンドストーン
            (0.70, 0.58, 0.62), // 69: プラムグレー
            (0.58, 0.70, 0.72), // 70: アイスブルー
            (0.92, 0.88, 0.72), // 71: シャンパン
            (0.55, 0.62, 0.55), // 72: フォレストミスト
        ]
        guard index >= 0 && index < rgbTable.count else { return 0 }
        let (r, g, b) = rgbTable[index]
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC
        if delta < 0.01 { return 0 } // 無彩色
        var hue: Double
        if maxC == r {
            hue = 60.0 * (((g - b) / delta).truncatingRemainder(dividingBy: 6))
        } else if maxC == g {
            hue = 60.0 * (((b - r) / delta) + 2)
        } else {
            hue = 60.0 * (((r - g) / delta) + 4)
        }
        if hue < 0 { hue += 360 }
        return hue
    }

    // 色相の距離（環状）
    private func hueDist(_ h1: Double, _ h2: Double) -> Double {
        let d = abs(h1 - h2)
        return min(d, 360 - d)
    }

    // 最後尾2タグと異なる系統 ＆ 既存タグと被らない色を選ぶ
    private func pickDistinctColor(tags: [Tag]) -> Int {
        let parentTags = tags.filter { $0.parentTagID == nil }
            .sorted { $0.sortOrder < $1.sortOrder }
        let usedIndices = Set(parentTags.map { $0.colorIndex })

        // 最後尾2つの色相を取得
        let tail2Hues: [Double] = parentTags.suffix(2).map { hueFromColorIndex($0.colorIndex) }

        // 候補: 1〜72（全カラーパレット、0=タグなしは除外）
        let candidates = Array(1...72)

        // 各候補のスコア = 最後尾2色との色相距離の最小値（大きいほど良い）
        var scored: [(index: Int, dist: Double)] = candidates.map { idx in
            let hue = hueFromColorIndex(idx)
            let minDist = tail2Hues.isEmpty ? 180.0 : tail2Hues.map { hueDist(hue, $0) }.min()!
            return (idx, minDist)
        }
        // 色相距離が大きい順にソート
        scored.sort { $0.dist > $1.dist }

        // 未使用で最も色相が離れたものを選ぶ
        if let best = scored.first(where: { !usedIndices.contains($0.index) }) {
            return best.index
        }
        // 全色使われてる場合は色相距離だけで選ぶ
        return scored.first?.index ?? 1
    }

    // MARK: - 新規タグ作成確認ダイアログ（カスタム）

    @ViewBuilder
    private var newTagConfirmDialog: some View {
        ZStack {
            // 背景暗幕
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) { showNewTagConfirm = false }
                }

            VStack(spacing: 0) {
                // ヘッダー
                VStack(spacing: 8) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.green)

                    Text("新しいタグを作成")
                        .font(.system(size: 17, weight: .bold, design: .rounded))

                    // タグ名プレビュー（タブ風）
                    Text(pendingNewTagName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.green.opacity(0.15))
                        )
                }
                .padding(.top, 20)
                .padding(.bottom, 16)

                Divider()

                // おまかせカラー
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showNewTagConfirm = false }
                    createNewTagWithAutoColor()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.blue)
                        Text("おまかせカラーで作成")
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

                // 色を指定
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showNewTagConfirm = false }
                    showNewTagColorSheet = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "eyedropper")
                            .font(.system(size: 16))
                            .foregroundStyle(.purple)
                        Text("色を指定して作成")
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

                Divider()

                // 戻る
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showNewTagConfirm = false }
                } label: {
                    Text("戻る")
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

    // デバウンス付きサジェスト更新（1秒待つ）
    private func triggerSuggest() {
        suggestDebounceTask?.cancel()
        // テキストが空なら候補を消して終了
        let hasContent = !viewModel.titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard tagSuggestEnabled && viewModel.selectedTagID == nil && !suggestDismissed && hasContent else {
            if !hasContent { suggestions = [] }
            return
        }
        suggestDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
            guard !Task.isCancelled else { return }
            await MainActor.run {
                suggestions = suggestEngine.suggest(
                    title: viewModel.titleText,
                    body: viewModel.inputText,
                    tags: tags,
                    context: modelContext,
                    limit: 3
                )
            }
        }
    }
}
