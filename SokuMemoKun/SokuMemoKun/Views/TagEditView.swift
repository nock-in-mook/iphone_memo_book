import SwiftUI
import SwiftData

// タグ編集画面（一覧・色変更・名前変更・削除）
struct TagEditView: View {
    @Query(sort: \Tag.name) private var tags: [Tag]
    @Environment(\.modelContext) private var modelContext
    @State private var editingTag: Tag?
    @State private var showNewTagSheet = false
    @State private var isDeleteMode = false
    @State private var selectedForDeletion: Set<UUID> = []

    var body: some View {
        // タグ一覧（ボタンもリスト内に含める）
        List {
            // 上部: 新規追加 / 選択削除ボタン
            if isDeleteMode {
                HStack {
                    Button {
                        isDeleteMode = false
                        selectedForDeletion.removeAll()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14))
                            Text("キャンセル")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        deleteSelected()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                            Text("削除(\(selectedForDeletion.count))")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.red)
                    }
                    .disabled(selectedForDeletion.isEmpty)
                }
                .listRowBackground(Color.clear)
            } else {
                HStack {
                    Button {
                        showNewTagSheet = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                            Text("新規追加")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                        }
                    }

                    Spacer()

                    Button {
                        isDeleteMode = true
                        selectedForDeletion.removeAll()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                            Text("選択削除")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(.red.opacity(0.7))
                    }
                    .disabled(tags.isEmpty)
                }
                .listRowBackground(Color.clear)
            }

            // タグ一覧
            ForEach(tags) { tag in
                Button {
                    if isDeleteMode {
                        toggleDeletion(tag)
                    } else {
                        editingTag = tag
                    }
                } label: {
                    HStack(spacing: 10) {
                        // 削除モード時のチェックマーク
                        if isDeleteMode {
                            Image(systemName: selectedForDeletion.contains(tag.id)
                                  ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundStyle(selectedForDeletion.contains(tag.id)
                                                 ? .red : .gray.opacity(0.4))
                        }

                        // カラー付きタグ名（文字色は黒）
                        Text(tag.name)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(tagColor(for: tag.colorIndex))
                            )

                        Spacer()

                        if !isDeleteMode {
                            // メモ数
                            Text("\(tag.memos.count)件")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.tertiary)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("タグ編集")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingTag) { tag in
            TagDetailEditView(tag: tag)
        }
        .sheet(isPresented: $showNewTagSheet) {
            NewTagSheetView()
        }
    }

    private func toggleDeletion(_ tag: Tag) {
        if selectedForDeletion.contains(tag.id) {
            selectedForDeletion.remove(tag.id)
        } else {
            selectedForDeletion.insert(tag.id)
        }
    }

    private func deleteSelected() {
        for tag in tags where selectedForDeletion.contains(tag.id) {
            for memo in tag.memos {
                memo.tags.removeAll { $0.id == tag.id }
            }
            modelContext.delete(tag)
        }
        selectedForDeletion.removeAll()
        isDeleteMode = false
    }
}

// カラーパレット（56色、コンパクト表示）
struct ColorPaletteGrid: View {
    @Binding var selectedIndex: Int

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 8)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 5) {
            ForEach(1...56, id: \.self) { index in
                Button {
                    selectedIndex = index
                } label: {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(tagColor(for: index))
                        .frame(height: 26)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(
                                    selectedIndex == index
                                        ? Color.primary : Color.clear,
                                    lineWidth: 2
                                )
                        )
                }
            }
        }
    }
}

// プレビュー枠（プレビューラベル + タグパネル）
struct TagPreviewBox: View {
    let name: String
    let colorIndex: Int

    private var displayName: String {
        let n = name.isEmpty ? "サンプル" : name
        return n.count > 5 ? String(n.prefix(5)) + "…" : n
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("プレビュー")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.secondary)

            // タグパネル（メイン画面と同じ見た目、タグ:なし）
            Text(displayName)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.8))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(tagColor(for: colorIndex))
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// 個別タグ編集シート（名前変更・色変更）
struct TagDetailEditView: View {
    @Bindable var tag: Tag
    @Environment(\.dismiss) private var dismiss

    @State private var editName: String = ""
    @State private var editColorIndex: Int = 1

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // タグ名入力（背景なし）
                VStack(alignment: .leading, spacing: 6) {
                    Text("タグ名")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    TextField("タグ名を入力（20文字まで）", text: $editName)
                        .font(.system(size: 16, design: .rounded))
                        .padding(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .onChange(of: editName) { _, newValue in
                            if newValue.count > 20 {
                                editName = String(newValue.prefix(20))
                            }
                        }

                    Text("\(editName.count)/20")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                // プレビュー（常にスペース確保、入力中のみ表示）
                Text(editName.trimmingCharacters(in: .whitespaces).isEmpty ? " " : editName.trimmingCharacters(in: .whitespaces))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(editName.trimmingCharacters(in: .whitespaces).isEmpty ? .clear : tagTextColor(for: editColorIndex))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(editName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.clear : tagColor(for: editColorIndex))
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                    .animation(.easeOut(duration: 0.15), value: editColorIndex)

                // カラー選択（コンパクト）
                VStack(alignment: .leading, spacing: 6) {
                    Text("カラー")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    ColorPaletteGrid(selectedIndex: $editColorIndex)
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("タグを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveChanges()
                    }
                    .disabled(editName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .bold()
                }
            }
            .onAppear {
                editName = tag.name
                editColorIndex = tag.colorIndex
            }
        }
        .presentationDetents([.medium])
    }

    private func saveChanges() {
        let trimmed = editName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        tag.name = trimmed
        tag.colorIndex = editColorIndex
        dismiss()
    }
}
