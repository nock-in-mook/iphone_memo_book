import SwiftUI
import UIKit

// Bear風インラインマークダウンエディタ
// 記号を薄く表示しつつ、見出し・太字・斜体などをリアルタイムでスタイリング
struct MarkdownTextEditor: UIViewRepresentable {
    @Binding var text: String

    // 基本フォントサイズ
    private let baseFontSize: CGFloat = 16
    // 記号の色（薄いグレー）
    private let symbolColor = UIColor.systemGray3

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: baseFontSize)
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        textView.autocorrectionType = .default
        textView.autocapitalizationType = .none
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.text = text
        applyStyle(to: textView)

        // カーソル位置の通知を受け取る
        context.coordinator.cursorObserver = NotificationCenter.default.addObserver(
            forName: .markdownCursorFromEnd,
            object: nil,
            queue: .main
        ) { notification in
            guard let offset = notification.userInfo?["offset"] as? Int else { return }
            let len = textView.text.count
            let pos = max(0, len - offset)
            textView.selectedRange = NSRange(location: pos, length: 0)
        }

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // Coordinator側からの更新中はスキップ（ループ防止）
        guard !context.coordinator.isUpdating else { return }
        // SwiftUI側からの変更（MarkdownToolbar等）を反映
        if textView.text != text {
            context.coordinator.isUpdating = true
            textView.text = text
            applyStyle(to: textView)
            context.coordinator.isUpdating = false
        }
    }

    static func dismantleUIView(_ textView: UITextView, coordinator: Coordinator) {
        if let observer = coordinator.cursorObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // textStorageを直接操作してスタイリング（テキスト自体は変えない）
    func applyStyle(to textView: UITextView) {
        let storage = textView.textStorage
        let fullText = storage.string
        guard !fullText.isEmpty else { return }
        let fullRange = NSRange(location: 0, length: storage.length)

        // デフォルトスタイルをリセット
        let defaultFont = UIFont.systemFont(ofSize: baseFontSize)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4

        storage.beginEditing()

        storage.setAttributes([
            .font: defaultFont,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle,
        ], range: fullRange)

        storage.removeAttribute(.backgroundColor, range: fullRange)
        storage.removeAttribute(.strikethroughStyle, range: fullRange)

        let lines = fullText.components(separatedBy: "\n")
        var currentLocation = 0

        for line in lines {
            let lineLen = (line as NSString).length
            let lineRange = NSRange(location: currentLocation, length: lineLen)

            // ネストリスト（インデント付き箇条書き / チェックボックス）
            let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
            let indent = line.count - trimmed.count

            if line.hasPrefix("### ") {
                styleHeading(storage, lineRange: lineRange, prefixLength: 4, fontSize: baseFontSize + 2)
            } else if line.hasPrefix("## ") {
                styleHeading(storage, lineRange: lineRange, prefixLength: 3, fontSize: baseFontSize + 5)
            } else if line.hasPrefix("# ") {
                styleHeading(storage, lineRange: lineRange, prefixLength: 2, fontSize: baseFontSize + 8)
            }
            // 水平線（---、***、___ の3文字以上）
            else if lineLen >= 3 && (
                line.allSatisfy({ $0 == "-" }) ||
                line.allSatisfy({ $0 == "*" }) ||
                line.allSatisfy({ $0 == "_" })
            ) {
                storage.addAttribute(.foregroundColor, value: symbolColor, range: lineRange)
            }
            // チェックボックス（ネスト対応）
            else if String(trimmed).hasPrefix("- [ ] ") || String(trimmed).hasPrefix("- [x] ") || String(trimmed).hasPrefix("- [X] ") {
                styleSymbol(storage, lineRange: lineRange, symbolLength: indent + 6)
                // インデント分の左マージン
                if indent > 0 {
                    applyIndent(storage, lineRange: lineRange, level: indent)
                }
                if String(trimmed).hasPrefix("- [x] ") || String(trimmed).hasPrefix("- [X] ") {
                    let contentRange = NSRange(location: lineRange.location + indent + 6, length: max(0, lineLen - indent - 6))
                    storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: contentRange)
                    storage.addAttribute(.foregroundColor, value: UIColor.secondaryLabel, range: contentRange)
                }
            }
            // 箇条書き（ネスト対応）
            else if String(trimmed).hasPrefix("- ") {
                styleSymbol(storage, lineRange: lineRange, symbolLength: indent + 2)
                if indent > 0 {
                    applyIndent(storage, lineRange: lineRange, level: indent)
                }
            }
            // 番号付きリスト（ネスト対応: "1. ", "12. " 等）
            else if let dotRange = matchNumberedList(String(trimmed)) {
                let prefixLen = indent + dotRange
                styleSymbol(storage, lineRange: lineRange, symbolLength: prefixLen)
                if indent > 0 {
                    applyIndent(storage, lineRange: lineRange, level: indent)
                }
            }
            else if line.hasPrefix("> ") {
                styleSymbol(storage, lineRange: lineRange, symbolLength: 2)
                let contentRange = NSRange(location: lineRange.location + 2, length: max(0, lineLen - 2))
                storage.addAttribute(.font, value: UIFont.italicSystemFont(ofSize: baseFontSize), range: contentRange)
                storage.addAttribute(.foregroundColor, value: UIColor.secondaryLabel, range: contentRange)
            }
            else if line.hasPrefix("```") {
                storage.addAttribute(.foregroundColor, value: symbolColor, range: lineRange)
                storage.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: baseFontSize - 1, weight: .regular), range: lineRange)
            }

            applyInlineStyles(storage, in: lineRange, text: line)

            currentLocation += lineLen + 1
        }

        storage.endEditing()
    }

    private func styleHeading(_ storage: NSTextStorage, lineRange: NSRange, prefixLength: Int, fontSize: CGFloat) {
        let headingFont = UIFont.systemFont(ofSize: fontSize, weight: .bold)
        storage.addAttribute(.font, value: headingFont, range: lineRange)
        let symbolRange = NSRange(location: lineRange.location, length: min(prefixLength, lineRange.length))
        storage.addAttribute(.foregroundColor, value: symbolColor, range: symbolRange)
    }

    private func styleSymbol(_ storage: NSTextStorage, lineRange: NSRange, symbolLength: Int) {
        let symbolRange = NSRange(location: lineRange.location, length: min(symbolLength, lineRange.length))
        storage.addAttribute(.foregroundColor, value: symbolColor, range: symbolRange)
    }

    // 番号付きリストかどうか判定（"1. " "12. " 等）。マッチしたら接頭辞の長さを返す
    private func matchNumberedList(_ line: String) -> Int? {
        guard let first = line.first, first.isNumber else { return nil }
        for (i, ch) in line.enumerated() {
            if ch == "." {
                // "数字." の直後がスペースであること
                let nextIndex = line.index(line.startIndex, offsetBy: i + 1, limitedBy: line.endIndex)
                if let nextIndex, line[nextIndex] == " " {
                    return i + 2  // "1. " → 3文字
                }
                return nil
            }
            if !ch.isNumber { return nil }
        }
        return nil
    }

    // ネストリストのインデント表現（段落の左余白を増やす）
    private func applyIndent(_ storage: NSTextStorage, lineRange: NSRange, level: Int) {
        let indentParagraph = NSMutableParagraphStyle()
        indentParagraph.lineSpacing = 4
        // 1インデント（スペース2つ or タブ1つ）= 20pt
        let indentPoints = CGFloat(level) * 10.0
        indentParagraph.headIndent = indentPoints
        indentParagraph.firstLineHeadIndent = indentPoints
        storage.addAttribute(.paragraphStyle, value: indentParagraph, range: lineRange)
    }

    private func applyInlineStyles(_ storage: NSTextStorage, in lineRange: NSRange, text: String) {
        let nsText = text as NSString

        applyPattern("\\*\\*(.+?)\\*\\*", storage: storage, lineRange: lineRange, nsText: nsText) { matchRange, innerRange in
            let startSymbol = NSRange(location: matchRange.location, length: 2)
            let endSymbol = NSRange(location: matchRange.location + matchRange.length - 2, length: 2)
            storage.addAttribute(.foregroundColor, value: symbolColor, range: startSymbol)
            storage.addAttribute(.foregroundColor, value: symbolColor, range: endSymbol)
            storage.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: baseFontSize), range: innerRange)
        }

        applyPattern("(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)", storage: storage, lineRange: lineRange, nsText: nsText) { matchRange, innerRange in
            let startSymbol = NSRange(location: matchRange.location, length: 1)
            let endSymbol = NSRange(location: matchRange.location + matchRange.length - 1, length: 1)
            storage.addAttribute(.foregroundColor, value: symbolColor, range: startSymbol)
            storage.addAttribute(.foregroundColor, value: symbolColor, range: endSymbol)
            storage.addAttribute(.font, value: UIFont.italicSystemFont(ofSize: baseFontSize), range: innerRange)
        }

        applyPattern("~~(.+?)~~", storage: storage, lineRange: lineRange, nsText: nsText) { matchRange, innerRange in
            let startSymbol = NSRange(location: matchRange.location, length: 2)
            let endSymbol = NSRange(location: matchRange.location + matchRange.length - 2, length: 2)
            storage.addAttribute(.foregroundColor, value: symbolColor, range: startSymbol)
            storage.addAttribute(.foregroundColor, value: symbolColor, range: endSymbol)
            storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: innerRange)
        }

        applyPattern("`([^`]+)`", storage: storage, lineRange: lineRange, nsText: nsText) { matchRange, innerRange in
            let startSymbol = NSRange(location: matchRange.location, length: 1)
            let endSymbol = NSRange(location: matchRange.location + matchRange.length - 1, length: 1)
            storage.addAttribute(.foregroundColor, value: symbolColor, range: startSymbol)
            storage.addAttribute(.foregroundColor, value: symbolColor, range: endSymbol)
            storage.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: baseFontSize - 1, weight: .regular), range: innerRange)
            storage.addAttribute(.backgroundColor, value: UIColor.systemGray6, range: innerRange)
        }

        // リンク [テキスト](URL)
        applyPattern("\\[([^\\]]+)\\]\\(([^)]+)\\)", storage: storage, lineRange: lineRange, nsText: nsText) { matchRange, innerRange in
            // [と] を薄く
            let openBracket = NSRange(location: matchRange.location, length: 1)
            storage.addAttribute(.foregroundColor, value: symbolColor, range: openBracket)
            let closeBracketPos = matchRange.location + 1 + innerRange.length
            let closeBracket = NSRange(location: closeBracketPos, length: 1)
            storage.addAttribute(.foregroundColor, value: symbolColor, range: closeBracket)
            // テキスト部分をリンク色に
            storage.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: innerRange)
            storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: innerRange)
            // (URL) 部分を薄く
            let urlPartStart = closeBracketPos + 1
            let urlPartLen = matchRange.location + matchRange.length - urlPartStart
            if urlPartLen > 0 {
                let urlRange = NSRange(location: urlPartStart, length: urlPartLen)
                storage.addAttribute(.foregroundColor, value: symbolColor, range: urlRange)
                storage.addAttribute(.font, value: UIFont.systemFont(ofSize: baseFontSize - 2), range: urlRange)
            }
        }
    }

    private func applyPattern(
        _ pattern: String,
        storage: NSTextStorage,
        lineRange: NSRange,
        nsText: NSString,
        apply: (NSRange, NSRange) -> Void
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let matches = regex.matches(in: nsText as String, range: NSRange(location: 0, length: nsText.length))

        for match in matches {
            let matchRange = NSRange(
                location: lineRange.location + match.range.location,
                length: match.range.length
            )
            let innerLocalRange = match.range(at: 1)
            let innerRange = NSRange(
                location: lineRange.location + innerLocalRange.location,
                length: innerLocalRange.length
            )

            guard matchRange.location + matchRange.length <= storage.length,
                  innerRange.location + innerRange.length <= storage.length else { continue }

            apply(matchRange, innerRange)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkdownTextEditor
        var isUpdating = false
        var cursorObserver: Any?

        init(_ parent: MarkdownTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isUpdating else { return }
            isUpdating = true
            parent.text = textView.text
            parent.applyStyle(to: textView)
            isUpdating = false
        }

        deinit {
            if let observer = cursorObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}
