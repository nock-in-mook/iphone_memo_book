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
    @Query(sort: \Tag.name) private var tags: [Tag]

    // 親タグのみ（タブ順序と一致させる）
    private var parentTags: [Tag] {
        tags.filter { $0.parentTagID == nil }
    }

    // タグIDからタブインデックスを算出（0=タグなし、1〜=親タグ順）
    private func tabIndex(for tagID: UUID?) -> Int {
        guard let tagID = tagID else { return 0 }
        if let idx = parentTags.firstIndex(where: { $0.id == tagID }) {
            return idx + 1  // +1 は「タグなし」タブの分
        }
        return 0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 入力エリア
                MemoInputView(viewModel: viewModel, focusInput: $focusInput, selectedTabIndex: $selectedTabIndex)

                // 台形タブ付きメモ一覧
                TabbedMemoListView(
                    selectedTabIndex: $selectedTabIndex,
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
                viewModel.restoreLastMemo(context: modelContext)
            }
        }
    }
}
