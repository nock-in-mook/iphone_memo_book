import SwiftUI
import SwiftData

struct MainView: View {
    @State private var viewModel = MemoInputViewModel()
    @State private var isKeyboardVisible = false
    @State private var showSettings = false
    @State private var focusInput = false
    @State private var selectedTabIndex: Int = 0
    @State private var searchText = ""
    @State private var isInputExpanded = false
    // 「ここに保存」確認ダイアログ
    @State private var showSaveToTabAlert = false
    @State private var pendingSaveTagID: UUID? = nil
    @AppStorage("defaultMarkdown") private var defaultMarkdown = false
    @AppStorage("markdownEnabled") private var markdownEnabled = false
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var tags: [Tag]

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    // 上: 入力欄（展開時は画面いっぱいに伸びる）
                    MemoInputView(
                        viewModel: viewModel,
                        focusInput: $focusInput,
                        isExpanded: $isInputExpanded
                    )
                    .frame(height: isInputExpanded ? geo.size.height * 0.92 : geo.size.height * 0.48 - 30)

                    // 下: フォルダ付きメモ一覧
                    TabbedMemoListView(
                        selectedTabIndex: $selectedTabIndex,
                        searchText: $searchText,
                        onAddMemo: { tagID in
                            viewModel.clearInput()
                            viewModel.selectedTagID = tagID
                            focusInput = true
                        },
                        onEditMemo: { memo in
                            // 既存メモを入力欄に読み込む
                            viewModel.loadMemo(memo)
                        },
                        onDeleteMemo: { memo in
                            if viewModel.editingMemo?.id == memo.id {
                                viewModel.clearInput()
                            }
                        },
                        isCompact: isInputExpanded,
                        onAddToCurrentTab: { tagID in
                            // 確認ダイアログを表示
                            pendingSaveTagID = tagID
                            showSaveToTabAlert = true
                        }
                    )
                }
            }
            .ignoresSafeArea(.keyboard)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 左: 展開時は「←」で縮小、通常時は「＋」で新規メモ
                ToolbarItem(placement: .topBarLeading) {
                    if isInputExpanded {
                        Button {
                            withAnimation(.spring(response: 0.35)) {
                                isInputExpanded = false
                            }
                        } label: {
                            Image(systemName: "chevron.left")
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
                // 中央: 検索バー
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        TextField("メモをさがす", text: $searchText)
                            .font(.system(size: 15, design: .rounded))
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(uiColor: .secondarySystemBackground))
                    )
                }
                // 右: 設定
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 15))
                    }
                }
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
                // マスタースイッチOFFなら起動時もマークダウン解除
                if !markdownEnabled {
                    viewModel.isMarkdown = false
                }
            }
        }
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
