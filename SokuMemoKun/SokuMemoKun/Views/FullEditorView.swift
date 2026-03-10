import SwiftUI

// マークダウンプレビューレイアウト
enum MarkdownLayout: String, CaseIterable {
    case split = "上下分割"
    case tab = "タブ切替"
}

// レイアウトアイコン（上下分割 or タブ切替）
struct LayoutIcon: View {
    let layout: MarkdownLayout
    var size: CGFloat = 16

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let rect = CGRect(x: 0, y: 0, width: w, height: h)
            let corner: CGFloat = 2

            if layout == .split {
                // 上下分割: 上にA、下にB
                let topRect = CGRect(x: 0, y: 0, width: w, height: h * 0.47)
                let bottomRect = CGRect(x: 0, y: h * 0.53, width: w, height: h * 0.47)

                context.stroke(Path(roundedRect: rect, cornerRadius: corner), with: .color(.primary.opacity(0.5)), lineWidth: 1)
                // 仕切り線
                context.stroke(Path { p in
                    p.move(to: CGPoint(x: 1, y: h * 0.5))
                    p.addLine(to: CGPoint(x: w - 1, y: h * 0.5))
                }, with: .color(.primary.opacity(0.4)), lineWidth: 0.5)

                // A
                context.draw(
                    Text("A").font(.system(size: size * 0.35, weight: .bold, design: .rounded)).foregroundColor(.primary.opacity(0.6)),
                    at: CGPoint(x: topRect.midX, y: topRect.midY)
                )
                // B
                context.draw(
                    Text("B").font(.system(size: size * 0.35, weight: .bold, design: .rounded)).foregroundColor(.primary.opacity(0.6)),
                    at: CGPoint(x: bottomRect.midX, y: bottomRect.midY)
                )
            } else {
                // タブ切替: 左にA、右にB
                context.stroke(Path(roundedRect: rect, cornerRadius: corner), with: .color(.primary.opacity(0.5)), lineWidth: 1)
                // タブ仕切り線（上部）
                let tabH = h * 0.28
                context.stroke(Path { p in
                    p.move(to: CGPoint(x: 1, y: tabH))
                    p.addLine(to: CGPoint(x: w - 1, y: tabH))
                }, with: .color(.primary.opacity(0.4)), lineWidth: 0.5)
                // タブ仕切り（中央縦線）
                context.stroke(Path { p in
                    p.move(to: CGPoint(x: w * 0.5, y: 0))
                    p.addLine(to: CGPoint(x: w * 0.5, y: tabH))
                }, with: .color(.primary.opacity(0.4)), lineWidth: 0.5)

                // A（左タブ）
                context.draw(
                    Text("A").font(.system(size: size * 0.28, weight: .bold, design: .rounded)).foregroundColor(.primary.opacity(0.6)),
                    at: CGPoint(x: w * 0.25, y: tabH * 0.5)
                )
                // B（右タブ）
                context.draw(
                    Text("B").font(.system(size: size * 0.28, weight: .bold, design: .rounded)).foregroundColor(.primary.opacity(0.6)),
                    at: CGPoint(x: w * 0.75, y: tabH * 0.5)
                )
            }
        }
        .frame(width: size, height: size)
    }
}

// 全画面編集モード（マークダウン/ノーマル共通）
struct FullEditorView: View {
    @Binding var text: String
    @Binding var isMarkdown: Bool
    @Environment(\.dismiss) private var dismiss

    // マークダウンレイアウト設定（アプリ全体で記憶）
    @AppStorage("markdownLayout") private var layoutRaw: String = MarkdownLayout.split.rawValue

    // タブ切替時の表示モード
    @State private var showPreview = false

    private var layout: MarkdownLayout {
        get { MarkdownLayout(rawValue: layoutRaw) ?? .split }
        nonmutating set { layoutRaw = newValue.rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isMarkdown {
                    markdownEditor
                } else {
                    // ノーマルモード: シンプルなテキストエディタ
                    TextEditor(text: $text)
                        .font(.system(size: 16))
                        .padding(8)
                }
            }
            .navigationTitle(isMarkdown ? "マークダウン編集" : "テキスト編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("戻る") { dismiss() }
                }

                ToolbarItem(placement: .principal) {
                    // マークダウンON/OFFトグル
                    HStack(spacing: 6) {
                        Image(systemName: isMarkdown ? "text.quote" : "text.alignleft")
                            .font(.system(size: 12))
                            .foregroundStyle(isMarkdown ? .blue : .secondary)
                        Toggle("", isOn: $isMarkdown)
                            .toggleStyle(.switch)
                            .scaleEffect(0.7)
                            .labelsHidden()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    if isMarkdown {
                        // レイアウト切替メニュー
                        Menu {
                            ForEach(MarkdownLayout.allCases, id: \.self) { option in
                                Button {
                                    layoutRaw = option.rawValue
                                } label: {
                                    HStack {
                                        Text(option.rawValue)
                                        if layout == option {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            LayoutIcon(layout: layout, size: 20)
                        }
                    }
                }
            }
        }
    }

    // マークダウンエディタ（分割 or タブ）
    @ViewBuilder
    private var markdownEditor: some View {
        let currentLayout = MarkdownLayout(rawValue: layoutRaw) ?? .split

        if currentLayout == .split {
            // 上下分割: 上がエディタ、下がプレビュー
            VStack(spacing: 0) {
                TextEditor(text: $text)
                    .font(.system(size: 15, design: .monospaced))
                    .padding(8)
                    .frame(maxHeight: .infinity)

                Divider()

                ScrollView {
                    markdownPreview
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: .infinity)
                .background(Color(uiColor: .secondarySystemBackground))
            }
        } else {
            // タブ切替: 編集 or プレビュー
            VStack(spacing: 0) {
                // タブバー
                HStack(spacing: 0) {
                    tabButton(title: "編集", isActive: !showPreview) {
                        showPreview = false
                    }
                    tabButton(title: "プレビュー", isActive: showPreview) {
                        showPreview = true
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)

                if showPreview {
                    ScrollView {
                        markdownPreview
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color(uiColor: .secondarySystemBackground))
                } else {
                    TextEditor(text: $text)
                        .font(.system(size: 15, design: .monospaced))
                        .padding(8)
                }
            }
        }
    }

    // マークダウンプレビュー（簡易レンダリング）
    private var markdownPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                markdownLine(line)
            }
        }
    }

    // 1行ごとの簡易マークダウンレンダリング
    @ViewBuilder
    private func markdownLine(_ line: String) -> some View {
        if line.hasPrefix("### ") {
            Text(String(line.dropFirst(4)))
                .font(.system(size: 16, weight: .bold, design: .rounded))
        } else if line.hasPrefix("## ") {
            Text(String(line.dropFirst(3)))
                .font(.system(size: 18, weight: .bold, design: .rounded))
        } else if line.hasPrefix("# ") {
            Text(String(line.dropFirst(2)))
                .font(.system(size: 22, weight: .bold, design: .rounded))
        } else if line.hasPrefix("- ") {
            HStack(alignment: .top, spacing: 6) {
                Text("•")
                    .font(.system(size: 14))
                Text(renderInline(String(line.dropFirst(2))))
                    .font(.system(size: 14))
            }
        } else if line.hasPrefix("> ") {
            Text(String(line.dropFirst(2)))
                .font(.system(size: 14, design: .serif))
                .italic()
                .padding(.leading, 10)
                .overlay(
                    Rectangle()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 3),
                    alignment: .leading
                )
        } else if line.hasPrefix("```") {
            // コードブロックの区切り（簡易対応）
            EmptyView()
        } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
            Spacer().frame(height: 8)
        } else {
            Text(renderInline(line))
                .font(.system(size: 14))
        }
    }

    // インライン装飾の簡易レンダリング
    private func renderInline(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        // **太字** の簡易対応
        if let boldRange = text.range(of: "\\*\\*(.+?)\\*\\*", options: .regularExpression) {
            let inner = String(text[boldRange]).replacingOccurrences(of: "**", with: "")
            result = AttributedString(text.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: inner, options: .regularExpression))
        }
        return result
    }

    // タブボタン
    private func tabButton(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isActive ? .bold : .medium, design: .rounded))
                .foregroundStyle(isActive ? .primary : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isActive
                        ? RoundedRectangle(cornerRadius: 8).fill(Color(uiColor: .secondarySystemBackground))
                        : RoundedRectangle(cornerRadius: 8).fill(Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}
