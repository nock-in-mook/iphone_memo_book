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
        // スクロールを有効化
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // SwiftUI側からの変更を反映（ループ防止）
        if textView.text != text {
            let selectedRange = textView.selectedRange
            textView.text = text
            applyMarkdownStyling(to: textView)
            // カーソル位置を復元
            let safeRange = NSRange(
                location: min(selectedRange.location, textView.text.count),
                length: 0
            )
            textView.selectedRange = safeRange
        }
    }

    // マークダウンスタイリングを適用
    func applyMarkdownStyling(to textView: UITextView) {
        let fullText = textView.text ?? ""
        let attributed = NSMutableAttributedString(string: fullText)
        let fullRange = NSRange(location: 0, length: attributed.length)

        // デフォルトスタイル
        let defaultFont = UIFont.systemFont(ofSize: baseFontSize)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4

        attributed.addAttributes([
            .font: defaultFont,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle,
        ], range: fullRange)

        let lines = fullText.components(separatedBy: "\n")
        var currentLocation = 0

        for line in lines {
            let lineRange = NSRange(location: currentLocation, length: line.count)

            // 見出し（### → ## → # の順で判定）
            if line.hasPrefix("### ") {
                styleHeading(attributed, line: line, lineRange: lineRange, prefixLength: 4, fontSize: baseFontSize + 2)
            } else if line.hasPrefix("## ") {
                styleHeading(attributed, line: line, lineRange: lineRange, prefixLength: 3, fontSize: baseFontSize + 5)
            } else if line.hasPrefix("# ") {
                styleHeading(attributed, line: line, lineRange: lineRange, prefixLength: 2, fontSize: baseFontSize + 8)
            }
            // リスト
            else if line.hasPrefix("- [ ] ") || line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") {
                styleSymbol(attributed, lineRange: lineRange, symbolLength: 6)
                // チェック済みは取消線
                if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") {
                    let contentRange = NSRange(location: lineRange.location + 6, length: max(0, lineRange.length - 6))
                    attributed.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: contentRange)
                    attributed.addAttribute(.foregroundColor, value: UIColor.secondaryLabel, range: contentRange)
                }
            } else if line.hasPrefix("- ") {
                styleSymbol(attributed, lineRange: lineRange, symbolLength: 2)
            }
            // 引用
            else if line.hasPrefix("> ") {
                styleSymbol(attributed, lineRange: lineRange, symbolLength: 2)
                let contentRange = NSRange(location: lineRange.location + 2, length: max(0, lineRange.length - 2))
                let italicFont = UIFont.italicSystemFont(ofSize: baseFontSize)
                attributed.addAttribute(.font, value: italicFont, range: contentRange)
                attributed.addAttribute(.foregroundColor, value: UIColor.secondaryLabel, range: contentRange)
            }
            // コードブロック区切り
            else if line.hasPrefix("```") {
                attributed.addAttribute(.foregroundColor, value: symbolColor, range: lineRange)
                attributed.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: baseFontSize - 1, weight: .regular), range: lineRange)
            }

            // インライン装飾（全行に適用）
            applyInlineStyles(attributed, in: lineRange, text: line)

            currentLocation += line.count + 1 // +1 for \n
        }

        textView.attributedText = attributed
    }

    // 見出しスタイル
    private func styleHeading(_ attributed: NSMutableAttributedString, line: String, lineRange: NSRange, prefixLength: Int, fontSize: CGFloat) {
        // 記号部分を薄く
        let symbolRange = NSRange(location: lineRange.location, length: prefixLength)
        attributed.addAttribute(.foregroundColor, value: symbolColor, range: symbolRange)
        attributed.addAttribute(.font, value: UIFont.systemFont(ofSize: fontSize, weight: .bold), range: symbolRange)

        // 本文部分を太字・大きく
        let contentRange = NSRange(location: lineRange.location + prefixLength, length: max(0, lineRange.length - prefixLength))
        let headingFont = UIFont.systemFont(ofSize: fontSize, weight: .bold)
        attributed.addAttribute(.font, value: headingFont, range: contentRange)
    }

    // 行頭記号を薄くする
    private func styleSymbol(_ attributed: NSMutableAttributedString, lineRange: NSRange, symbolLength: Int) {
        let symbolRange = NSRange(location: lineRange.location, length: min(symbolLength, lineRange.length))
        attributed.addAttribute(.foregroundColor, value: symbolColor, range: symbolRange)
    }

    // インライン装飾（太字・斜体・取消線・コード）
    private func applyInlineStyles(_ attributed: NSMutableAttributedString, in lineRange: NSRange, text: String) {
        let nsText = text as NSString

        // **太字**
        applyPattern("\\*\\*(.+?)\\*\\*", to: attributed, in: lineRange, nsText: nsText) { matchRange, innerRange in
            // ** 記号を薄く
            let startSymbol = NSRange(location: matchRange.location, length: 2)
            let endSymbol = NSRange(location: matchRange.location + matchRange.length - 2, length: 2)
            attributed.addAttribute(.foregroundColor, value: symbolColor, range: startSymbol)
            attributed.addAttribute(.foregroundColor, value: symbolColor, range: endSymbol)
            // 中身を太字
            let boldFont = UIFont.boldSystemFont(ofSize: baseFontSize)
            attributed.addAttribute(.font, value: boldFont, range: innerRange)
        }

        // *斜体*（**を除外するため、前後が*でないことを確認）
        applyPattern("(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)", to: attributed, in: lineRange, nsText: nsText) { matchRange, innerRange in
            let startSymbol = NSRange(location: matchRange.location, length: 1)
            let endSymbol = NSRange(location: matchRange.location + matchRange.length - 1, length: 1)
            attributed.addAttribute(.foregroundColor, value: symbolColor, range: startSymbol)
            attributed.addAttribute(.foregroundColor, value: symbolColor, range: endSymbol)
            let italicFont = UIFont.italicSystemFont(ofSize: baseFontSize)
            attributed.addAttribute(.font, value: italicFont, range: innerRange)
        }

        // ~~取消線~~
        applyPattern("~~(.+?)~~", to: attributed, in: lineRange, nsText: nsText) { matchRange, innerRange in
            let startSymbol = NSRange(location: matchRange.location, length: 2)
            let endSymbol = NSRange(location: matchRange.location + matchRange.length - 2, length: 2)
            attributed.addAttribute(.foregroundColor, value: symbolColor, range: startSymbol)
            attributed.addAttribute(.foregroundColor, value: symbolColor, range: endSymbol)
            attributed.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: innerRange)
        }

        // `インラインコード`
        applyPattern("`([^`]+)`", to: attributed, in: lineRange, nsText: nsText) { matchRange, innerRange in
            let startSymbol = NSRange(location: matchRange.location, length: 1)
            let endSymbol = NSRange(location: matchRange.location + matchRange.length - 1, length: 1)
            attributed.addAttribute(.foregroundColor, value: symbolColor, range: startSymbol)
            attributed.addAttribute(.foregroundColor, value: symbolColor, range: endSymbol)
            let monoFont = UIFont.monospacedSystemFont(ofSize: baseFontSize - 1, weight: .regular)
            attributed.addAttribute(.font, value: monoFont, range: innerRange)
            attributed.addAttribute(.backgroundColor, value: UIColor.systemGray6, range: innerRange)
        }
    }

    // 正規表現パターンを適用するヘルパー
    private func applyPattern(
        _ pattern: String,
        to attributed: NSMutableAttributedString,
        in lineRange: NSRange,
        nsText: NSString,
        apply: (NSRange, NSRange) -> Void
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let matches = regex.matches(in: nsText as String, range: NSRange(location: 0, length: nsText.length))

        for match in matches {
            // マッチ全体のレンジ（行内オフセット→全体オフセットに変換）
            let matchRange = NSRange(
                location: lineRange.location + match.range.location,
                length: match.range.length
            )
            // キャプチャグループ（中身）のレンジ
            let innerLocalRange = match.range(at: 1)
            let innerRange = NSRange(
                location: lineRange.location + innerLocalRange.location,
                length: innerLocalRange.length
            )

            // 範囲チェック
            guard matchRange.location + matchRange.length <= attributed.length,
                  innerRange.location + innerRange.length <= attributed.length else { continue }

            apply(matchRange, innerRange)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkdownTextEditor

        init(_ parent: MarkdownTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            // テキスト変更をSwiftUI側に反映
            parent.text = textView.text
            // スタイリングを再適用
            parent.applyMarkdownStyling(to: textView)
        }
    }
}
