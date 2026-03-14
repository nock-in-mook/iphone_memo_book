import SwiftUI
import SwiftData

extension Notification.Name {
    static let switchToTab = Notification.Name("switchToTab")
}

struct MemoInputView: View {
    @Bindable var viewModel: MemoInputViewModel
    @Binding var focusInput: Bool
    @Binding var isExpanded: Bool
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var tags: [Tag]
    @FocusState private var isTextEditorFocused: Bool

    // 新規タグ作成シート
    @State private var showNewTagSheet = false
    @State private var newTagIsChild = false
    // 既存メモ読み込み時は閲覧モード（タップで編集開始）
    @State private var isEditing = true
    // 削除確認ダイアログ
    @State private var showDeleteAlert = false
    // ルーレット展開状態
    @State private var showParentDial = false
    @State private var showChildDial = false
    @State private var childExternalDragY: CGFloat? = nil
    @AppStorage("dialDefault") private var dialDefault: Int = 0

    @AppStorage("allTagSortOrder") private var allTagSortOrder: Int = -1
    @AppStorage("noTagSortOrder") private var noTagSortOrder: Int = 9999

    private func tabIndex(for tagID: UUID?) -> Int {
        // TabbedMemoListViewのtabItemsと同じ並び順で計算
        // label: "all"=すべて, "none"=タグなし, それ以外=タグID
        struct TabEntry: Comparable {
            let key: String
            let order: Int
            static func < (lhs: TabEntry, rhs: TabEntry) -> Bool { lhs.order < rhs.order }
        }
        var entries: [TabEntry] = []
        entries.append(TabEntry(key: "all", order: allTagSortOrder))
        entries.append(TabEntry(key: "none", order: noTagSortOrder))
        for tag in tags where tag.parentTagID == nil {
            entries.append(TabEntry(key: tag.id.uuidString, order: tag.sortOrder))
        }
        entries.sort()

        // タグなし選択時は「タグなし」タブへ
        guard let tagID = tagID else {
            return entries.firstIndex(where: { $0.key == "none" }) ?? 0
        }
        if let idx = entries.firstIndex(where: { $0.key == tagID.uuidString }) {
            return idx
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
            // 本文（右端はタグタブ分空ける）
            ZStack(alignment: .topTrailing) {
                // 本文入力（編集中はTextEditor、閲覧中はText）
                ZStack(alignment: .topLeading) {
                    if isEditing {
                        TextEditor(text: $viewModel.inputText)
                            .font(.system(size: 17))
                            .padding(.leading, 10)
                            .padding(.trailing, 4)
                            .padding(.top, 16)
                            .contentMargins(.bottom, 40, for: .scrollContent)
                            .focused($isTextEditorFocused)
                    } else {
                        ScrollView {
                            Text(viewModel.inputText.isEmpty ? " " : viewModel.inputText)
                                .font(.system(size: 17))
                                .foregroundStyle(viewModel.inputText.isEmpty ? .clear : .primary)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .padding(.leading, 15)
                                .padding(.trailing, 9)
                                .padding(.top, 24)
                                .padding(.bottom, 40)
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
                            .padding(.leading, 14)
                            .padding(.trailing, 8)
                            .padding(.vertical, 24)
                            .allowsHitTesting(false)
                    }
                }
                .frame(maxHeight: .infinity)

            }
            .padding(.trailing, showParentDial ? (showChildDial ? 185 : 135) : 0)
            .animation(.spring(response: 0.3), value: showParentDial)
            .animation(.spring(response: 0.3), value: showChildDial)
            .overlay(alignment: .bottomTrailing) {
                // 展開/縮小ボタン
                Button {
                    withAnimation(.spring(response: 0.35)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "arrow.down.forward.and.arrow.up.backward" : "arrow.up.backward.and.arrow.down.forward")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle().fill(Color.blue.opacity(0.6))
                        )
                        .shadow(color: .black.opacity(0.2), radius: 2, x: -1, y: 1)
                }
                .padding(.trailing, 8)
                .padding(.bottom, 8)
            }
            .overlay(alignment: .topTrailing) {
                // 仕切り線直下・右端からタグタブを生やす
                dialArea
                    .padding(.trailing, -10)
                    .offset(y: -1)
            }
            Divider()
            // フッター: 左=削除 右=コピー+保存
            footerRow
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(uiColor: .systemBackground))
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
            }
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
            if viewModel.selectedTagID == nil {
                // タグ未選択時はアイコンのみ
                Image(systemName: "tag")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
            } else {
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
    }

    // MARK: - フッター（左=削除 右=コピー+保存）

    private var footerRow: some View {
        HStack(spacing: 8) {
            // 左: 削除
            Button { showDeleteAlert = true } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15))
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

    // ルーレットの固定高さ
    private let dialFixedHeight: CGFloat = 160

    private var dialArea: some View {
        VStack(spacing: 0) {
            dialContent
                .frame(height: showParentDial ? dialFixedHeight : nil)
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var dialContent: some View {
        HStack(spacing: 0) {
            if showParentDial {
                Rectangle().fill(Color.gray.opacity(0.2)).frame(width: 1)

                TagDialView(
                    options: parentOptions,
                    selectedID: $viewModel.selectedTagID,
                    width: showChildDial ? 85 : 110,
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
                                width: 80,
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
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(red: 0.90, green: 0.90, blue: 0.92))
                        )
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
                // 逆さL字タブ（上=横タブ、下=縦グリップ）
                VStack(alignment: .trailing, spacing: 0) {
                    // 上部: 横長タブ（今まで通り）
                    HStack(spacing: 2) {
                        Text("◀").font(.system(size: 12))
                        Text("タグ").font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 22, alignment: .leading)
                    .padding(.leading, 6)
                    .background(
                        UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 6, bottomTrailingRadius: 0, topTrailingRadius: 0)
                            .fill(Color(red: 0.76, green: 0.76, blue: 0.78))
                    )

                    // 下部: 縦長グリップ（包丁の刃先カーブ）
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        GripShape()
                            .fill(Color(red: 0.76, green: 0.76, blue: 0.78))
                            .frame(width: 35, height: 70)
                    }
                    .frame(width: 60)
                }
                .shadow(color: .black.opacity(0.15), radius: 2, x: -1, y: 1)
                .contentShape(Rectangle())
                .gesture(
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

// グリップの包丁刃先シェイプ
// 上部は幅16ptの長方形、下端が左に向かってカーブしながら広がり刃先のように消える
struct GripShape: Shape {
    func path(in rect: CGRect) -> Path {
        let gripWidth: CGFloat = 8
        let left = rect.maxX - gripWidth  // グリップ左端
        let right = rect.maxX             // グリップ右端（画面端）

        let filletR: CGFloat = 7  // L字内側の丸み半径

        var path = Path()
        // 左上: フィレットの開始点（上辺から）
        path.move(to: CGPoint(x: left - filletR, y: 0))
        // 内側の丸みカーブ（水平→垂直へ滑らかに）
        path.addQuadCurve(
            to: CGPoint(x: left, y: filletR),
            control: CGPoint(x: left, y: 0)
        )
        // 左辺をまっすぐ途中まで下へ
        path.addLine(to: CGPoint(x: left, y: rect.height * 0.5))
        // 左辺がカーブして右へ→最後は水平に右辺と合流
        path.addCurve(
            to: CGPoint(x: right, y: rect.height),
            control1: CGPoint(x: left, y: rect.height * 0.85),
            control2: CGPoint(x: right - gripWidth * 0.6, y: rect.height)
        )
        // 右辺をまっすぐ上へ
        path.addLine(to: CGPoint(x: right, y: 0))
        path.closeSubpath()
        return path
    }
}
