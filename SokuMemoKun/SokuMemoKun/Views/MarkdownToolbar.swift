import SwiftUI

// マークダウン記号入力バー（キーボード上部に表示）
struct MarkdownToolbar: View {
    @Binding var text: String

    // 挿入用の記号定義
    private let symbols: [(label: String, prefix: String, suffix: String, hint: String)] = [
        ("H1", "# ", "", "見出し1"),
        ("H2", "## ", "", "見出し2"),
        ("H3", "### ", "", "見出し3"),
        ("B", "**", "**", "太字"),
        ("I", "*", "*", "斜体"),
        ("—", "- ", "", "リスト"),
        ("□", "- [ ] ", "", "チェック"),
        (">", "> ", "", "引用"),
        ("</>", "```\n", "\n```", "コード"),
        ("~", "~~", "~~", "取消線"),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(symbols, id: \.label) { sym in
                    Button {
                        insertSymbol(prefix: sym.prefix, suffix: sym.suffix)
                    } label: {
                        Text(sym.label)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(.primary)
                            .frame(minWidth: 32, minHeight: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(uiColor: .systemBackground))
                                    .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .background(Color(uiColor: .secondarySystemBackground))
    }

    private func insertSymbol(prefix: String, suffix: String) {
        if suffix.isEmpty {
            // 行頭挿入系（見出し、リスト、引用）
            // 改行の直後またはテキスト先頭に挿入
            if text.isEmpty || text.hasSuffix("\n") {
                text += prefix
            } else {
                text += "\n" + prefix
            }
        } else {
            // 囲み系（太字、斜体、コード、取消線）
            text += prefix + suffix
        }
    }
}
