import SwiftUI
import SwiftData

struct MainView: View {
    @State private var viewModel = MemoInputViewModel()
    @State private var isKeyboardVisible = false
    @State private var showSettings = false
    @State private var focusInput = false
    // タブ切替指示: (タグID, トリガーカウンター) をセットで管理
    @State private var switchToTagID: UUID? = nil
    @State private var switchTrigger: Int = 0
    @AppStorage("defaultMarkdown") private var defaultMarkdown = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 入力エリア（大枠で囲まれた入力欄+ルーレット）
                MemoInputView(
                    viewModel: viewModel,
                    focusInput: $focusInput,
                    onSaved: { savedTagID in
                        // 保存時に該当タグのタブに切替（次フレームで実行し確実に反映）
                        DispatchQueue.main.async {
                            switchToTagID = savedTagID
                            switchTrigger += 1
                        }
                    }
                )

                // 台形タブ付きメモ一覧
                TabbedMemoListView(
                    switchToTagID: $switchToTagID,
                    switchTrigger: $switchTrigger,
                    onAddMemo: {
                        viewModel.clearInput()
                        focusInput = true
                    },
                    onEditMemo: { memo in
                        viewModel.loadMemo(memo)
                        if memo.isMarkdown {
                            viewModel.openFullEditor = true
                        }
                        focusInput = true
                    },
                    onDeleteMemo: { memo in
                        // 編集中のメモが削除された場合は入力欄をクリア
                        if viewModel.editingMemo?.id == memo.id {
                            viewModel.clearInput()
                        }
                    }
                )
            }
            .navigationTitle("即メモ君")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
                // 入力欄が空のときだけデフォルト設定を即反映
                if viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    viewModel.isMarkdown = newValue
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
                // 起動時に前回のメモを復元（設定に応じて）
                viewModel.restoreLastMemo(context: modelContext)
            }
        }
    }
}
