import SwiftUI
import SwiftData

struct MainView: View {
    @State private var viewModel = MemoInputViewModel()
    @State private var isKeyboardVisible = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // テキスト入力エリア
                MemoInputView(viewModel: viewModel)

                Divider()

                // 台形タブ付きメモ一覧
                TabbedMemoListView()
            }
            .navigationTitle("即メモ君")
            .navigationBarTitleDisplayMode(.inline)
            // ジョグダイヤル（画面右端に張り付き）
            .overlay(alignment: .trailing) {
                if !isKeyboardVisible {
                    TagDialView(selectedTagID: $viewModel.selectedTagID)
                        .frame(height: 200)
                        .offset(y: -60) // 入力欄の横あたりに配置
                        .transition(.move(edge: .trailing))
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
            .sheet(isPresented: $viewModel.showTagTitleSheet) {
                if let memo = viewModel.savedMemo {
                    TagTitleSheetView(memo: memo)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                isKeyboardVisible = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                isKeyboardVisible = false
            }
        }
    }
}
