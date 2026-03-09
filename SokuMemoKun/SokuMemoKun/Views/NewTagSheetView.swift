import SwiftUI
import SwiftData

// 新規タグ作成シート
struct NewTagSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var tagName = ""
    @State private var selectedColorIndex = 1

    // 選択可能な色（tabColorsと同じパレット、index 0のタグ無し色は除外）
    private let colorOptions: [(index: Int, label: String)] = [
        (1, "水色"), (2, "オレンジ"), (3, "緑"), (4, "紫"),
        (5, "黄色"), (6, "赤"), (7, "青")
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // タグ名入力
                VStack(alignment: .leading, spacing: 6) {
                    Text("タグ名")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    TextField("タグ名を入力（20文字まで）", text: $tagName)
                        .font(.system(size: 16, design: .rounded))
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(uiColor: .secondarySystemBackground))
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

                // カラー選択
                VStack(alignment: .leading, spacing: 6) {
                    Text("カラー")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                        ForEach(colorOptions, id: \.index) { option in
                            Button {
                                selectedColorIndex = option.index
                            } label: {
                                VStack(spacing: 4) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(tagColor(for: option.index))
                                        .frame(height: 40)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(
                                                    selectedColorIndex == option.index
                                                        ? Color.primary : Color.clear,
                                                    lineWidth: 2.5
                                                )
                                        )

                                    Text(option.label)
                                        .font(.system(size: 10, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                // プレビュー
                VStack(alignment: .leading, spacing: 6) {
                    Text("プレビュー")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("タグ:")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.secondary)

                        Text(previewName)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(tagColor(for: selectedColorIndex))
                            )
                    }
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("新規タグ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveTag()
                    }
                    .disabled(tagName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .bold()
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var previewName: String {
        let name = tagName.isEmpty ? "サンプル" : tagName
        if name.count > 5 {
            return String(name.prefix(5)) + "…"
        }
        return name
    }

    private func saveTag() {
        let trimmed = tagName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let tag = Tag(name: trimmed, colorIndex: selectedColorIndex)
        modelContext.insert(tag)
        dismiss()
    }
}
