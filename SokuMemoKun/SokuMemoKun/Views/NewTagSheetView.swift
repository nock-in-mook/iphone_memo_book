import SwiftUI
import SwiftData

// 新規タグ作成シート
struct NewTagSheetView: View {
    // nil = 親タグ追加、UUID = その親の子タグ追加
    var parentTagID: UUID? = nil
    // 追加完了時に新タグIDを返すコールバック
    var onTagCreated: ((UUID) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var tagName = ""
    @State private var selectedColorIndex = 1

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // タグ名入力
                VStack(alignment: .leading, spacing: 6) {
                    Text("タグ名")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    TextField("タグ名を入力（20文字まで）", text: $tagName)
                        .font(.system(size: 16, design: .rounded))
                        .padding(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .onChange(of: tagName) { _, newValue in
                            if newValue.count > 20 {
                                tagName = String(newValue.prefix(20))
                            }
                        }

                    Text("\(tagName.count)/20")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                // カラー選択（コンパクト28色）
                VStack(alignment: .leading, spacing: 6) {
                    Text("カラー")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    ColorPaletteGrid(selectedIndex: $selectedColorIndex)
                }

                // プレビュー枠
                TagPreviewBox(name: tagName, colorIndex: selectedColorIndex)

                Spacer()
            }
            .padding(20)
            .navigationTitle(parentTagID != nil ? "新規子タグ" : "新規タグ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        saveTag()
                    }
                    .disabled(tagName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .bold()
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func saveTag() {
        let trimmed = tagName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let tag = Tag(name: trimmed, colorIndex: selectedColorIndex, parentTagID: parentTagID)
        modelContext.insert(tag)
        onTagCreated?(tag.id)
        dismiss()
    }
}
