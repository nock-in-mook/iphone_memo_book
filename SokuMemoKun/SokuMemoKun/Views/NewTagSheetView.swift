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

    private var trimmedName: String {
        tagName.trimmingCharacters(in: .whitespaces)
    }

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

                    HStack {
                        // プレビュー（1文字以上入力で表示）
                        if !trimmedName.isEmpty {
                            Text(trimmedName)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.8))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(tagColor(for: selectedColorIndex))
                                )
                                .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        }

                        Spacer()

                        Text("\(tagName.count)/20")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                    .animation(.easeOut(duration: 0.2), value: trimmedName.isEmpty)
                }

                // カラー選択
                VStack(alignment: .leading, spacing: 6) {
                    Text("カラー")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    ColorPaletteGrid(selectedIndex: $selectedColorIndex)
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle(parentTagID != nil ? "新規子タグの追加" : "新規タグ(フォルダ)の追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        saveTag()
                    }
                    .disabled(trimmedName.isEmpty)
                    .bold()
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func saveTag() {
        guard !trimmedName.isEmpty else { return }
        let tag = Tag(name: trimmedName, colorIndex: selectedColorIndex, parentTagID: parentTagID)
        modelContext.insert(tag)
        onTagCreated?(tag.id)
        dismiss()
    }
}
