import SwiftUI
import SwiftData

struct MainView: View {
    @State private var viewModel = MemoInputViewModel()
    @State private var isKeyboardVisible = false
    @State private var showSettings = false
    @State private var focusInput = false
    @State private var selectedTabIndex: Int = 0
    // 閲覧中の既存メモ（nilなら新規入力モード）
    @State private var previewingMemo: Memo?
    @AppStorage("defaultMarkdown") private var defaultMarkdown = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    // 上半分: 入力 / 閲覧 / 編集（統合ペイン）
                    MemoInputView(
                        viewModel: viewModel,
                        focusInput: $focusInput,
                        previewingMemo: $previewingMemo
                    )
                    .frame(height: geo.size.height * 0.48)

                    // 下半分: フォルダ付きメモ一覧
                    TabbedMemoListView(
                        selectedTabIndex: $selectedTabIndex,
                        onAddMemo: {
                            previewingMemo = nil  // 閲覧→入力に戻す
                            viewModel.clearInput()
                            focusInput = true
                        },
                        onEditMemo: { memo in
                            // 上半分に閲覧表示
                            previewingMemo = memo
                        },
                        onDeleteMemo: { memo in
                            if viewModel.editingMemo?.id == memo.id {
                                viewModel.clearInput()
                            }
                            if previewingMemo?.id == memo.id {
                                previewingMemo = nil
                            }
                        }
                    )
                }
            }
            .navigationTitle("即メモ君")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 左: 戻るボタン（閲覧/編集中のみ）
                ToolbarItem(placement: .topBarLeading) {
                    if previewingMemo != nil {
                        Button {
                            previewingMemo = nil
                        } label: {
                            Image(systemName: "arrow.backward")
                                .font(.system(size: 15))
                        }
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
            // タブ切替通知を受信
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
