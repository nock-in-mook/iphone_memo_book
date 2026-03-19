import SwiftUI
import SwiftData

struct MainView: View {
    @State private var viewModel = MemoInputViewModel()
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
                            if !isInputExpanded {
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
                }
            }
            .ignoresSafeArea(.keyboard)
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
            .onAppear {
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
                pendingSaveTagID = tagID
                showSaveToTabAlert = true
            }
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
}
