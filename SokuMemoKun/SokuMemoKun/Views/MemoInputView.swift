import SwiftUI
import SwiftData

struct MemoInputView: View {
    @Bindable var viewModel: MemoInputViewModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var tags: [Tag]

    // 保存アニメーション用
    @State private var showSaveAnimation = false
    @State private var saveAnimationOffset: CGFloat = 0

    // 新規タグ作成シート
    @State private var showNewTagSheet = false

    // 選択中タグの表示名と色（ルーレット・タブと統一）
    private var selectedTagInfo: (name: String, color: Color) {
        if let tagID = viewModel.selectedTagID,
           let tag = tags.first(where: { $0.id == tagID }) {
            return (tag.name, tagColor(for: tag.colorIndex))
        }
        return ("タグなし", tagColor(for: 0))
    }

    // 5文字省略
    private var truncatedTagName: String {
        let name = selectedTagInfo.name
        if name.count > 5 {
            return String(name.prefix(5)) + "…"
        }
        return name
    }

    var body: some View {
        HStack(spacing: 0) {
            // 左3/4: 入力エリア + タイトル + ボタン行
            VStack(spacing: 0) {
                // メモ入力欄
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $viewModel.inputText)
                        .font(.system(size: 14))
                        .padding(4)

                    if viewModel.inputText.isEmpty {
                        Text("メモを入力...")
                            .foregroundStyle(.gray.opacity(0.5))
                            .font(.system(size: 14))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                }
                .frame(maxHeight: .infinity)

                Divider()
                    .padding(.horizontal, 6)

                // タイトル入力
                TextField("タイトル（任意）", text: $viewModel.titleText)
                    .font(.system(size: 12, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)

                Divider()
                    .padding(.horizontal, 6)

                // ボタン行: タグ: + タグ表示 + 追加 + コピー + 保存
                HStack(spacing: 5) {
                    // 「タグ:」ラベル
                    Text("タグ:")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.secondary)

                    // タグ表示（リアルタイム反映・ルーレット/タブと色統一）
                    Text(truncatedTagName)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.8))
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTagInfo.color)
                        )

                    // 新規タグ追加ボタン
                    Button {
                        showNewTagSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.blue)
                    }

                    Spacer()

                    Button {
                        UIPasteboard.general.string = viewModel.inputText
                    } label: {
                        Label("コピー", systemImage: "doc.on.doc")
                            .font(.system(size: 11))
                    }
                    .disabled(viewModel.inputText.isEmpty)

                    Button {
                        viewModel.save(context: modelContext, tags: tags)
                        triggerSaveAnimation()
                    } label: {
                        Label("保存", systemImage: "square.and.arrow.down.fill")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .disabled(!viewModel.canSave)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }

            // 区切り線
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1)

            // 右1/4: タグルーレット
            TagDialView(selectedTagID: $viewModel.selectedTagID)
        }
        .frame(height: 160)
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
        .sheet(isPresented: $showNewTagSheet) {
            NewTagSheetView()
        }
    }

    private func triggerSaveAnimation() {
        // 保存後の吸い込みアニメーション（将来実装）
        withAnimation(.easeIn(duration: 0.3)) {
            showSaveAnimation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showSaveAnimation = false
        }
    }
}
