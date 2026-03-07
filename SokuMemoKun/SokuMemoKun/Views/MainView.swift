import SwiftUI
import SwiftData

struct MainView: View {
    @State private var viewModel = MemoInputViewModel()
    @State private var selectedTag: Tag?
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // タグフィルター（常に表示）
                TagFilterPickerView(selectedTag: $selectedTag)

                // テキスト入力エリア
                MemoInputView(viewModel: viewModel, isInputFocused: $isInputFocused)

                Divider()

                // メモリスト
                MemoListView(selectedTag: selectedTag)
            }
            .navigationTitle("即メモ君")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // キーボード閉じるボタン
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("閉じる") {
                        isInputFocused = false
                    }
                }
            }
            .sheet(isPresented: $viewModel.showTagTitleSheet) {
                if let memo = viewModel.savedMemo {
                    TagTitleSheetView(memo: memo)
                }
            }
        }
    }
}
