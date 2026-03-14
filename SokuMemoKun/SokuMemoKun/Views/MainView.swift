import SwiftUI
import SwiftData

struct MainView: View {
    @State private var viewModel = MemoInputViewModel()
    @State private var showSettings = false
    @State private var focusInput = false
    @State private var selectedTabIndex: Int = 0
    @State private var searchText = ""
    @AppStorage("defaultMarkdown") private var defaultMarkdown = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    // 上半分: 入力欄（常に同じ画面）
                    MemoInputView(
                        viewModel: viewModel,
                        focusInput: $focusInput
                    )
                    .frame(height: geo.size.height * 0.48)

                    // 下半分: フォルダ付きメモ一覧
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
                        }
                    )
                }
            }
            .ignoresSafeArea(.keyboard)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 左: ＋ボタン（新規メモ作成）
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.clearInput()
                        focusInput = true
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 17))
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
                // キーボード上: 閉じるボタン
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .onChange(of: defaultMarkdown) { _, newValue in
                if viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    viewModel.isMarkdown = newValue
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .switchToTab)) { notification in
                if let tabIndex = notification.userInfo?["tabIndex"] as? Int {
                    selectedTabIndex = tabIndex
                }
            }
            .onAppear {
                viewModel.restoreLastMemo(context: modelContext)
            }
        }
    }
}
