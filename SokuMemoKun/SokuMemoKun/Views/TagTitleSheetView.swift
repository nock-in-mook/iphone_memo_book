import SwiftUI
import SwiftData

struct TagTitleSheetView: View {
    @Bindable var memo: Memo
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var existingTags: [Tag]
    @State private var titleText: String = ""
    @State private var contentText: String = ""
    @State private var selectedTags: [Tag] = []
    @State private var newTagName: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("メモ内容") {
                    TextEditor(text: $contentText)
                        .frame(minHeight: 100)
                }

                Section("タイトル（任意）") {
                    TextField("タイトルを入力", text: $titleText)
                }

                Section("タグを選択（任意）") {
                    // 既存タグの選択
                    ForEach(existingTags) { tag in
                        Button {
                            toggleTag(tag)
                        } label: {
                            HStack {
                                Text(tag.name)
                                Spacer()
                                if selectedTags.contains(where: { $0.id == tag.id }) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }

                    // 新規タグ追加
                    HStack {
                        TextField("新しいタグ", text: $newTagName)
                        Button {
                            addNewTag()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .navigationTitle("メモの設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        applySettings()
                        dismiss()
                    }
                }
            }
            .onAppear {
                // 既存の値を読み込み
                titleText = memo.title
                contentText = memo.content
                selectedTags = memo.tags
            }
        }
        .presentationDetents([.large])
    }

    private func toggleTag(_ tag: Tag) {
        if let index = selectedTags.firstIndex(where: { $0.id == tag.id }) {
            selectedTags.remove(at: index)
        } else {
            selectedTags.append(tag)
        }
    }

    private func addNewTag() {
        let name = newTagName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let tag = Tag(name: name)
        modelContext.insert(tag)
        selectedTags.append(tag)
        newTagName = ""
    }

    private func applySettings() {
        memo.content = contentText
        memo.title = titleText
        memo.tags = selectedTags
        memo.updatedAt = Date()
    }
}
