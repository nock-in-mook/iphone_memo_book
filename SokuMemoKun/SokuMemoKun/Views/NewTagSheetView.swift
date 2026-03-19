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
    @Query(sort: \Tag.name) private var allTags: [Tag]

    @State private var tagName = ""
    @State private var selectedColorIndex = 1

    private var trimmedName: String {
        tagName.trimmingCharacters(in: .whitespaces)
    }

    // 同じ階層に同名タグがあるか
    private var isDuplicate: Bool {
        guard !trimmedName.isEmpty else { return false }
        return allTags.contains { $0.parentTagID == parentTagID && $0.name == trimmedName }
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
                        if isDuplicate {
                            Text("同じ名前のタグが既にあります")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(.red)
                        }
                        Spacer()
                        Text("\(tagName.count)/20")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }

                // プレビュー
                if parentTagID == nil {
                    // 親タグ: リアルなタブデザイン
                    let isEmpty = trimmedName.isEmpty
                    Text(isEmpty ? " " : trimmedName)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(isEmpty ? .clear : tagTextColor(for: selectedColorIndex))
                        .shadow(color: isEmpty ? .clear : .black.opacity(0.35), radius: 1.5, x: -1, y: 1)
                        .lineLimit(1)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .frame(minWidth: 52)
                        .background(
                            TrapezoidTabShape()
                                .fill(isEmpty ? Color.clear : tagColor(for: selectedColorIndex))
                                .shadow(color: isEmpty ? .clear : .black.opacity(0.4), radius: 5, x: -3, y: 3)
                        )
                        .overlay(
                            Canvas { context, size in
                                for _ in 0..<200 {
                                    let x = CGFloat.random(in: 0...size.width)
                                    let y = CGFloat.random(in: 0...size.height)
                                    let op = Double.random(in: 0.02...0.08)
                                    context.opacity = op
                                    context.fill(
                                        Path(ellipseIn: CGRect(x: x, y: y, width: 1.5, height: 1.5)),
                                        with: .color(.black)
                                    )
                                }
                            }
                            .clipShape(TrapezoidTabShape())
                            .allowsHitTesting(false)
                            .opacity(isEmpty ? 0 : 1)
                        )
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    // 子タグ: シンプルなバッジ
                    Text(trimmedName.isEmpty ? " " : trimmedName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(trimmedName.isEmpty ? .clear : tagTextColor(for: selectedColorIndex))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(trimmedName.isEmpty ? Color.clear : tagColor(for: selectedColorIndex))
                        )
                        .frame(maxWidth: .infinity, alignment: .center)
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(parentTagID != nil ? "子タグの追加" : "親タグの追加")
                            .font(.headline)
                        if parentTagID == nil {
                            Text("（フォルダの追加）")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        saveTag()
                    }
                    .disabled(trimmedName.isEmpty || isDuplicate)
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
