import SwiftUI
import SwiftData

extension Notification.Name {
    static let switchToTab = Notification.Name("switchToTab")
}

struct MemoInputView: View {
    @Bindable var viewModel: MemoInputViewModel
    @Binding var focusInput: Bool
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var tags: [Tag]
    @FocusState private var isTextEditorFocused: Bool

    // 新規タグ作成シート
    @State private var showNewTagSheet = false
    @State private var newTagIsChild = false
    // 全画面編集
    @State private var showFullEditor = false
    // 全画面を開いた時点で既存メモだったか（途中で切り替わらないように記録）
    @State private var fullEditorIsExistingMemo = false
    // 既存メモ読み込み時は閲覧モード（タップで編集開始）
    @State private var isEditing = true
    // 削除確認ダイアログ
    @State private var showDeleteAlert = false
    // ルーレット展開状態
    @State private var showParentDial = false
    @State private var showChildDial = false
    @State private var childExternalDragY: CGFloat? = nil
    @AppStorage("dialDefault") private var dialDefault: Int = 0

    private func tabIndex(for tagID: UUID?) -> Int {
        guard let tagID = tagID else { return 0 }
        let parentTags = tags.filter { $0.parentTagID == nil }
        if let idx = parentTags.firstIndex(where: { $0.id == tagID }) {
            return idx + 1
        }
        return 0
    }

    private var parentOptions: [(id: String, name: String, color: Color)] {
        var list: [(String, String, Color)] = [("none", "タグなし", tagColor(for: 0))]
        for tag in tags where tag.parentTagID == nil {
            list.append((tag.id.uuidString, tag.name, tagColor(for: tag.colorIndex)))
        }
        list.append(("add", "＋追加", Color.blue.opacity(0.15)))
        return list
    }

    private var childOptions: [(id: String, name: String, color: Color)] {
        var list: [(String, String, Color)] = [("none", "なし", tagColor(for: 0))]
        if let parentID = viewModel.selectedTagID {
            for tag in tags where tag.parentTagID == parentID {
                list.append((tag.id.uuidString, tag.name, tagColor(for: tag.colorIndex)))
            }
        }
        list.append(("add", "＋追加", Color.blue.opacity(0.15)))
        return list
    }

    private var selectedTagInfo: (name: String, color: Color) {
        if let tagID = viewModel.selectedTagID,
           let tag = tags.first(where: { $0.id == tagID }) {
            return (tag.name, tagColor(for: tag.colorIndex))
        }
        return ("タグなし", tagColor(for: 0))
    }

    private var selectedChildTagInfo: (name: String, color: Color)? {
        if let childID = viewModel.selectedChildTagID,
           let tag = tags.first(where: { $0.id == childID }) {
            return (tag.name, tagColor(for: tag.colorIndex))
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー: タイトル + タグ
            headerRow
            Divider()
            // 本文 + ルーレット
            HStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    // 本文入力（編集中はTextEditor、閲覧中はText）
                    ZStack(alignment: .topLeading) {
                        if isEditing {
                            TextEditor(text: $viewModel.inputText)
                                .font(.system(size: 17))
                                .padding(.horizontal, 4)
                                .padding(.top, 4)
                                .padding(.trailing, 24)
                                .focused($isTextEditorFocused)
                        } else {
                            ScrollView {
                                Text(viewModel.inputText.isEmpty ? " " : viewModel.inputText)
                                    .font(.system(size: 17))
                                    .foregroundStyle(viewModel.inputText.isEmpty ? .clear : .primary)
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                    .padding(.horizontal, 8)
                                    .padding(.top, 8)
                                    .padding(.trailing, 24)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                isEditing = true
                                isTextEditorFocused = true
                            }
                        }

                        if viewModel.inputText.isEmpty && isEditing {
                            Text(viewModel.isMarkdown ? "タップでマークダウン編集..." : "メモを入力...")
                                .font(.system(size: 17))
                                .foregroundStyle(.gray.opacity(0.5))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 12)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(maxHeight: .infinity)

                    // 最大化ボタン（右上ぴったり）
                    Button {
                        fullEditorIsExistingMemo = (viewModel.editingMemo != nil)
                        showFullEditor = true
                    } label: {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 14))
                            .foregroundStyle(.gray.opacity(0.5))
                            .padding(5)
                            .background(Circle().fill(Color(uiColor: .systemBackground).opacity(0.9)))
                    }
                    .padding(.trailing, 2)
                    .padding(.top, 2)
                }
                dialArea
            }
            Divider()
            // フッター: 左=削除 右=コピー+保存
            footerRow
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(uiColor: .systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .alert("このメモを削除します。よろしいですか？", isPresented: $showDeleteAlert) {
            Button("削除", role: .destructive) {
                viewModel.discardMemo(context: modelContext)
            }
            Button("キャンセル", role: .cancel) {}
        }
        .sheet(isPresented: $showNewTagSheet) {
            NewTagSheetView(
                parentTagID: newTagIsChild ? viewModel.selectedTagID : nil,
                onTagCreated: { newTagID in
                    if newTagIsChild {
                        viewModel.selectedChildTagID = newTagID
                    } else {
                        viewModel.selectedTagID = newTagID
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            let idx = tabIndex(for: newTagID)
                            NotificationCenter.default.post(
                                name: .switchToTab, object: nil,
                                userInfo: ["tabIndex": idx]
                            )
                        }
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showFullEditor) {
            // 開いた時点のモードで固定（途中でeditingMemoが変わっても切り替わらない）
            if fullEditorIsExistingMemo, let memo = viewModel.editingMemo {
                MemoDetailView(memo: memo)
            } else {
                FullEditorView(text: $viewModel.inputText, isMarkdown: $viewModel.isMarkdown)
            }
        }
        .onChange(of: focusInput) { _, newValue in
            if newValue { isEditing = true; isTextEditorFocused = true; focusInput = false }
        }
        .onChange(of: viewModel.loadMemoCounter) { _, _ in
            // 既存メモ読み込み時は閲覧モードで開始
            isEditing = false
            isTextEditorFocused = false
        }
        .onChange(of: viewModel.inputText) { _, _ in
            viewModel.onContentChanged(context: modelContext, tags: tags)
        }
        .onChange(of: viewModel.titleText) { _, _ in
            viewModel.onTitleChanged()
        }
        .onChange(of: viewModel.selectedTagID) { _, newTagID in
            if !viewModel.isLoadingMemo { viewModel.selectedChildTagID = nil }
            viewModel.onTagChanged(tags: tags)
            let idx = tabIndex(for: newTagID)
            NotificationCenter.default.post(name: .switchToTab, object: nil, userInfo: ["tabIndex": idx])
        }
        .onChange(of: viewModel.selectedChildTagID) { _, _ in
            viewModel.onTagChanged(tags: tags)
        }
        .onAppear {
            showParentDial = dialDefault >= 1
            showChildDial = dialDefault >= 2
        }
    }

    // MARK: - ヘッダー

    private var headerRow: some View {
        HStack(spacing: 6) {
            TextField("タイトル（任意）", text: $viewModel.titleText)
                .font(.system(size: 17, weight: .semibold, design: .rounded))

            Spacer()

            // タグ表示（タップでルーレット展開）
            tagDisplay
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) {
                        showParentDial = true
                    }
                }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var tagDisplay: some View {
        HStack(spacing: 3) {
            let info = selectedTagInfo
            Text(info.name.prefix(4) + (info.name.count > 4 ? "…" : ""))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 5).fill(info.color))
            if let childInfo = selectedChildTagInfo {
                Text(childInfo.name.prefix(3) + (childInfo.name.count > 3 ? "…" : ""))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 4).fill(childInfo.color))
            }
        }
    }

    // MARK: - フッター（左=削除 右=コピー+保存）

    private var footerRow: some View {
        HStack(spacing: 8) {
            // 左: 削除
            Button { showDeleteAlert = true } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(.red.opacity(0.5))
            }
            .disabled(!viewModel.canClear)

            Spacer()

            // 右: コピー
            Button {
                UIPasteboard.general.string = viewModel.inputText
            } label: {
                Label("コピー", systemImage: "doc.on.doc").font(.system(size: 14))
            }
            .disabled(viewModel.inputText.isEmpty)

            // 右: 確定（メモは自動保存済み→入力欄をクリアして次のメモへ）
            Button {
                viewModel.clearInput()
                isEditing = true
                isTextEditorFocused = false
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            } label: {
                Label("確定", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .bold))
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
            .disabled(!viewModel.canClear)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }

    // MARK: - ルーレット（収納式）

    private var dialArea: some View {
        HStack(spacing: 0) {
            if showParentDial {
                Rectangle().fill(Color.gray.opacity(0.2)).frame(width: 1)

                TagDialView(
                    options: parentOptions,
                    selectedID: $viewModel.selectedTagID,
                    width: showChildDial ? 70 : 90,
                    onAddTap: { newTagIsChild = false; showNewTagSheet = true },
                    externalDragY: .constant(nil)
                )

                ZStack {
                    if showChildDial {
                        HStack(spacing: 0) {
                            Rectangle().fill(Color.gray.opacity(0.2)).frame(width: 1)
                            TagDialView(
                                options: childOptions,
                                selectedID: $viewModel.selectedChildTagID,
                                width: 65,
                                onAddTap: { newTagIsChild = true; showNewTagSheet = true },
                                externalDragY: $childExternalDragY
                            )
                            Text("›")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 14, height: 60)
                                .background(RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.1)))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3)) { showChildDial = false }
                                }
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
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 10)
                            .onEnded { value in
                                if value.translation.width > 20 {
                                    withAnimation(.spring(response: 0.3)) {
                                        showParentDial = false; showChildDial = false
                                    }
                                }
                            }
                    )
            } else {
                VStack(spacing: 3) {
                    Text("タグ").font(.system(size: 11, weight: .bold, design: .rounded))
                    Text("‹").font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 80)
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
    }
}
