import SwiftUI

// ToDoリストのタイトル横アイコン候補を並べるラボ
struct IconLabView: View {
    // アイコン候補一覧
    private let icons: [(name: String, label: String)] = [
        // リスト系
        ("list.bullet", "list.bullet"),
        ("list.bullet.rectangle", "list.bullet.rectangle"),
        ("list.clipboard", "list.clipboard"),
        ("list.dash", "list.dash"),
        ("list.number", "list.number"),
        ("checklist", "checklist"),
        ("checklist.checked", "checklist.checked"),
        // ドキュメント系
        ("doc.text", "doc.text"),
        ("doc.plaintext", "doc.plaintext"),
        ("doc.richtext", "doc.richtext"),
        ("note.text", "note.text"),
        ("square.and.pencil", "square.and.pencil"),
        ("pencil.line", "pencil.line"),
        ("rectangle.and.pencil.and.ellipsis", "rect.pencil.ellipsis"),
        // チェック・完了系
        ("checkmark.circle", "checkmark.circle"),
        ("checkmark.circle.fill", "checkmark.circle.fill"),
        ("checkmark.seal", "checkmark.seal"),
        ("checkmark.seal.fill", "checkmark.seal.fill"),
        ("checkmark.square", "checkmark.square"),
        ("checkmark.rectangle", "checkmark.rectangle"),
        // ピン・ブックマーク系
        ("pin", "pin"),
        ("pin.fill", "pin.fill"),
        ("bookmark", "bookmark"),
        ("bookmark.fill", "bookmark.fill"),
        ("flag", "flag"),
        ("flag.fill", "flag.fill"),
        // ターゲット・目標系
        ("target", "target"),
        ("scope", "scope"),
        ("star", "star"),
        ("star.fill", "star.fill"),
        ("bolt", "bolt"),
        ("bolt.fill", "bolt.fill"),
        // フォルダ・収納系
        ("folder", "folder"),
        ("folder.fill", "folder.fill"),
        ("tray", "tray"),
        ("tray.fill", "tray.fill"),
        ("archivebox", "archivebox"),
        ("archivebox.fill", "archivebox.fill"),
        // タグ系
        ("tag", "tag"),
        ("tag.fill", "tag.fill"),
        ("number", "number"),
        // 生活・用途系
        ("cart", "cart"),
        ("cart.fill", "cart.fill"),
        ("bag", "bag"),
        ("bag.fill", "bag.fill"),
        ("basket", "basket"),
        ("basket.fill", "basket.fill"),
        ("gift", "gift"),
        ("gift.fill", "gift.fill"),
        // 矢印・進捗系
        ("arrow.right.circle", "arrow.right.circle"),
        ("arrow.triangle.2.circlepath", "arrow.tri.2.circle"),
        ("clock", "clock"),
        ("clock.fill", "clock.fill"),
        ("calendar", "calendar"),
        ("bell", "bell"),
        ("bell.fill", "bell.fill"),
        // その他
        ("lightbulb", "lightbulb"),
        ("lightbulb.fill", "lightbulb.fill"),
        ("sparkles", "sparkles"),
        ("wand.and.stars", "wand.and.stars"),
        ("leaf", "leaf"),
        ("leaf.fill", "leaf.fill"),
        ("heart", "heart"),
        ("heart.fill", "heart.fill"),
        ("flame", "flame"),
        ("flame.fill", "flame.fill"),
        ("diamond", "diamond"),
        ("diamond.fill", "diamond.fill"),
        ("hexagon", "hexagon"),
        ("hexagon.fill", "hexagon.fill"),
        ("circle.grid.3x3", "circle.grid.3x3"),
        ("puzzlepiece", "puzzlepiece"),
        ("puzzlepiece.fill", "puzzlepiece.fill"),
    ]

    private let todoTabColor = Color(red: 0.55, green: 0.82, blue: 0.55)

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // プレビューエリア（実際のヘッダー風）
                previewSection

                Divider()
                    .padding(.horizontal, 16)

                // アイコングリッド
                Text("タイトル横アイコン候補")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 16) {
                    ForEach(icons, id: \.name) { icon in
                        iconCell(icon)
                    }
                }
                .padding(.horizontal, 16)

                // ナビバー風プレビュー
                Text("ナビバー風プレビュー")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 12) {
                    ForEach(icons, id: \.name) { icon in
                        navBarPreview(icon)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .padding(.top, 16)
        }
        .navigationTitle("アイコンラボ")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - プレビュー（実際のヘッダー風）
    private var previewSection: some View {
        VStack(spacing: 12) {
            Text("ヘッダープレビュー")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)

            // 3つピックアップしてプレビュー
            ForEach(["checklist", "list.clipboard", "note.text", "target", "pin.fill", "bookmark.fill"], id: \.self) { iconName in
                headerPreviewRow(iconName: iconName)
            }
        }
        .padding(.horizontal, 16)
    }

    // ヘッダープレビュー行
    private func headerPreviewRow(iconName: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 22))
                .foregroundStyle(todoTabColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("買い物リスト")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text("3/5 完了")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("60%")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(0.12))
                )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }

    // MARK: - アイコンセル
    private func iconCell(_ icon: (name: String, label: String)) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon.name)
                .font(.system(size: 28))
                .foregroundStyle(todoTabColor)
                .frame(width: 56, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemBackground))
                )

            Text(icon.label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    // MARK: - ナビバー風プレビュー
    private func navBarPreview(_ icon: (name: String, label: String)) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon.name)
                .font(.system(size: 16))
                .foregroundStyle(todoTabColor)
            Text("ToDoリスト")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}
