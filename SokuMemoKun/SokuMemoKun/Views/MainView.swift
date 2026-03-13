import SwiftUI
import SwiftData

struct MainView: View {
    @State private var viewModel = MemoInputViewModel()
    @State private var isKeyboardVisible = false
    @State private var showSettings = false
    @State private var focusInput = false
    @State private var selectedTabIndex: Int = 0
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
                        onAddMemo: {
                            viewModel.clearInput()
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
                .ignoresSafeArea(.keyboard)
            }
            .navigationTitle("即メモ君")
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
            .overlay(alignment: .bottomTrailing) {
                if isKeyboardVisible {
                    Button {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(Circle().fill(.blue))
                            .shadow(radius: 3)
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
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
            .onAppear {
                viewModel.restoreLastMemo(context: modelContext)
            }
        }
    }
}
