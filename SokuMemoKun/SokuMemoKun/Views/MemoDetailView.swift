import SwiftUI
import SwiftData

// 既存メモの全画面表示・編集画面
struct MemoDetailView: View {
    @Bindable var memo: Memo
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var allTags: [Tag]

    @State private var isEditing = false
    @State private var editText: String = ""
    @State private var editTitle: String = ""
    @FocusState private var isBodyFocused: Bool
    @FocusState private var isTitleFocused: Bool

    // タグ選択状態
    @State private var selectedTagID: UUID? = nil
    @State private var selectedChildTagID: UUID? = nil

    // ルーレット展開状態
    @State private var showParentDial = false
    @State private var showChildDial = false
    @State private var childExternalDragY: CGFloat? = nil

    // 新規タグ作成シート
    @State private var showNewTagSheet = false
    @State private var newTagIsChild = false

    // 削除確認
    @State private var showDeleteAlert = false
    // 「ここに保存」確認
    @State private var showSaveToTagAlert = false

    // タグ情報の計算
    private var selectedTagInfo: (name: String, color: Color) {
        if let tagID = selectedTagID,
           let tag = allTags.first(where: { $0.id == tagID }) {
            return (tag.name, tagColor(for: tag.colorIndex))
        }
        return ("タグなし", tagColor(for: 0))
    }

    private var selectedChildTagInfo: (name: String, color: Color)? {
        if let childID = selectedChildTagID,
           let tag = allTags.first(where: { $0.id == childID }) {
            return (tag.name, tagColor(for: tag.colorIndex))
        }
        return nil
    }

    private var parentOptions: [(id: String, name: String, color: Color)] {
        var list: [(String, String, Color)] = [("none", "タグなし", tagColor(for: 0))]
        for tag in allTags where tag.parentTagID == nil {
            list.append((tag.id.uuidString, tag.name, tagColor(for: tag.colorIndex)))
        }

        return list
    }

    private var childOptions: [(id: String, name: String, color: Color)] {
        var list: [(String, String, Color)] = [("none", "なし", tagColor(for: 0))]
        if let parentID = selectedTagID {
            for tag in allTags where tag.parentTagID == parentID {
                list.append((tag.id.uuidString, tag.name, tagColor(for: tag.colorIndex)))
            }
        }

        return list
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ヘッダー: タイトル + タグ
                headerRow
                Divider()

                // 本文 + ルーレット（横並び）
                HStack(spacing: 0) {
                    bodyArea
                    dialArea
                }

                Divider()
                // フッター: 日付（左下・右下のみ）
                footerRow
            }
            .navigationTitle(isEditing ? "編集中" : "メモ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        if isEditing { saveEdits() }
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    // コピーボタン
                    Button {
                        UIPasteboard.general.string = isEditing ? editText : memo.content
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14))
                    }

                    // 削除ボタン
                    Button { showDeleteAlert = true } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundStyle(.red.opacity(0.6))
                    }

                    // 完了ボタン（編集中のみ）
                    if isEditing {
                        Button("完了") {
                            saveEdits()
                            isEditing = false
                            isBodyFocused = false
                            isTitleFocused = false
                        }
                    }
                }
            }
        }
        .alert("このメモを削除します。よろしいですか？", isPresented: $showDeleteAlert) {
            Button("削除", role: .destructive) {
                modelContext.delete(memo)
                dismiss()
            }
            Button("キャンセル", role: .cancel) {}
        }
        .alert("このメモを「\(saveToTagLabel)」のタグで保存します。よろしいですか？", isPresented: $showSaveToTagAlert) {
            Button("保存") {
                syncTagsToMemo()
                try? modelContext.save()
                dismiss()
            }
            Button("キャンセル", role: .cancel) {}
        }
        .sheet(isPresented: $showNewTagSheet) {
            NewTagSheetView(
                parentTagID: newTagIsChild ? selectedTagID : nil,
                onTagCreated: { newTagID in
                    if newTagIsChild {
                        selectedChildTagID = newTagID
                    } else {
                        selectedTagID = newTagID
                    }
                }
            )
        }
        .onChange(of: selectedTagID) { _, _ in
            selectedChildTagID = nil
            syncTagsToMemo()
        }
        .onChange(of: selectedChildTagID) { _, _ in
            syncTagsToMemo()
        }
        .onAppear {
            editText = memo.content
            editTitle = memo.title
            if let parent = memo.tags.first(where: { $0.parentTagID == nil }) {
                selectedTagID = parent.id
            }
            if let child = memo.tags.first(where: { $0.parentTagID != nil }) {
                selectedChildTagID = child.id
            }
        }
    }

    // MARK: - ヘッダー（タイトル + タグ）

    private var headerRow: some View {
        HStack(spacing: 6) {
            // タイトル — タップで即編集モード
            if isEditing {
                TextField("タイトル（任意）", text: $editTitle)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .focused($isTitleFocused)
            } else {
                if memo.title.isEmpty {
                    Text("タイトル（任意）")
                        .font(.system(size: 18, design: .rounded))
                        .foregroundStyle(.gray.opacity(0.4))
                        .onTapGesture { startEditing() }
                } else {
                    Text(memo.title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .onTapGesture { startEditing() }
                }
            }

            Spacer()

            // タグ表示（右寄せ）— タップでルーレット展開
            HStack(spacing: 3) {
                let info = selectedTagInfo
                Text(info.name.prefix(6) + (info.name.count > 6 ? "…" : ""))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 6).fill(info.color))
                if let childInfo = selectedChildTagInfo {
                    Text(childInfo.name.prefix(4) + (childInfo.name.count > 4 ? "…" : ""))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 5).fill(childInfo.color))
                }
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.3)) {
                    showParentDial = true
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - 本文

    @ViewBuilder
    private var bodyArea: some View {
        if isEditing {
            TextEditor(text: $editText)
                .font(.system(size: 17))
                .padding(.horizontal, 8)
                .padding(.top, 4)
                .focused($isBodyFocused)
                .frame(maxHeight: .infinity)
        } else {
            // 閲覧モード — タップで即編集（textSelection なし→1タップで反応）
            ScrollView {
                if memo.isMarkdown {
                    markdownContent
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                } else {
                    Text(memo.content)
                        .font(.system(size: 17))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { startEditing() }
        }
    }

    // MARK: - フッター（日付 + ここに保存ボタン）

    private var footerRow: some View {
        VStack(spacing: 4) {
            HStack {
                Text("作成: \(memo.createdAt.formatted(date: .abbreviated, time: .shortened))")
                Spacer()
                Text("更新: \(memo.updatedAt.formatted(date: .abbreviated, time: .shortened))")
            }
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 12)

            // 「ここに保存」ボタン（タグ変更の確定用）
            Button {
                if isEditing { saveEdits() }
                showSaveToTagAlert = true
            } label: {
                let tagName = selectedTagInfo.name
                let childName = selectedChildTagInfo?.name
                let label = childName != nil ? "\(tagName) - \(childName!)" : tagName
                Label("このメモを「\(label)」に保存", systemImage: "arrow.down.doc")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(
                        Capsule()
                            .fill(Color(uiColor: .secondarySystemBackground))
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
    }

    // MARK: - ルーレット（収納式、全画面用 — タブを上寄せ）

    private var dialArea: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if showParentDial {
                    Rectangle().fill(Color.gray.opacity(0.2)).frame(width: 1)

                    TagDialView(
                        parentOptions: parentOptions,
                        parentSelectedID: $selectedTagID,
                        childOptions: childOptions,
                        childSelectedID: $selectedChildTagID,
                        showChild: $showChildDial,
                        childExternalDragY: $childExternalDragY
                    )

                    // 子タブ開閉ボタン
                    ZStack {
                        if showChildDial {
                            Text("›")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 14, height: 60)
                                .background(RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.1)))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3)) { showChildDial = false }
                                }
                        } else {
                            VStack(spacing: 2) {
                                Text("子").font(.system(size: 11, weight: .bold, design: .rounded))
                                Text("‹").font(.system(size: 12, weight: .bold))
                            }
                            .foregroundStyle(.secondary)
                            .frame(width: 20, height: 60)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.15)))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) { showChildDial = true }
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 5)
                            .onChanged { value in
                                if !showChildDial { showChildDial = true }
                                childExternalDragY = value.translation.height
                            }
                            .onEnded { _ in childExternalDragY = nil }
                    )

                    // 全収納ボタン
                    Text("›")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 12, height: 50)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                showParentDial = false; showChildDial = false
                            }
                        }
                } else {
                    // 収納状態（上寄せ）
                    VStack(spacing: 3) {
                        Text("タグ").font(.system(size: 11, weight: .bold, design: .rounded))
                        Text("‹").font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 60)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.12)))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) { showParentDial = true }
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 5)
                            .onChanged { _ in
                                if !showParentDial {
                                    withAnimation(.spring(response: 0.3)) { showParentDial = true }
                                }
                            }
                    )
                }
            }
            // ルーレットは上寄せ、残りの空間は空白
            Spacer()
        }
    }

    // ダイアログ用のタグラベル
    private var saveToTagLabel: String {
        let tagName = selectedTagInfo.name
        if let childName = selectedChildTagInfo?.name {
            return "\(tagName) - \(childName)"
        }
        return tagName
    }

    // MARK: - ヘルパー

    private func startEditing() {
        editText = memo.content
        editTitle = memo.title
        isEditing = true
    }

    private func saveEdits() {
        memo.content = editText
        memo.title = editTitle
        memo.updatedAt = Date()
    }

    private func syncTagsToMemo() {
        memo.tags.removeAll()
        if let tagID = selectedTagID,
           let tag = allTags.first(where: { $0.id == tagID }) {
            memo.tags.append(tag)
        }
        if let childID = selectedChildTagID,
           let childTag = allTags.first(where: { $0.id == childID }) {
            memo.tags.append(childTag)
        }
        memo.updatedAt = Date()
    }

    // MARK: - マークダウン表示

    private var markdownContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(memo.content.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                markdownLine(line)
            }
        }
    }

    @ViewBuilder
    private func markdownLine(_ line: String) -> some View {
        if line.hasPrefix("### ") {
            Text(String(line.dropFirst(4)))
                .font(.system(size: 18, weight: .bold, design: .rounded))
        } else if line.hasPrefix("## ") {
            Text(String(line.dropFirst(3)))
                .font(.system(size: 20, weight: .bold, design: .rounded))
        } else if line.hasPrefix("# ") {
            Text(String(line.dropFirst(2)))
                .font(.system(size: 24, weight: .bold, design: .rounded))
        } else if line.hasPrefix("- ") {
            HStack(alignment: .top, spacing: 6) {
                Text("•").font(.system(size: 16))
                Text(String(line.dropFirst(2))).font(.system(size: 16))
            }
        } else if line.hasPrefix("> ") {
            Text(String(line.dropFirst(2)))
                .font(.system(size: 16, design: .serif))
                .italic()
                .padding(.leading, 10)
                .overlay(
                    Rectangle()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 3),
                    alignment: .leading
                )
        } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
            Spacer().frame(height: 8)
        } else {
            Text(line)
                .font(.system(size: 16))
        }
    }
}
