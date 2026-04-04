import SwiftUI
import UIKit

/// 行番号付きテキストエディタ（UITextView + 行番号ガター）
struct LineNumberTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var showLineNumbers: Bool
    var fontSize: CGFloat = 17
    /// 初回フォーカス時のカーソル位置（nil = 末尾）
    var initialCursorOffset: Int? = nil
    /// 編集可能かどうか（falseだとスクロールのみ可能）
    var isEditable: Bool = true
    /// 非編集時のタップコールバック（文字オフセットを返す。UITextViewも渡す）
    var onTapWhileReadOnly: ((Int, UITextView) -> Void)? = nil
    /// マークダウンモード（Bear風インラインスタイリング + ツールバー）
    var isMarkdown: Bool = false

    func makeCoordinator() -> Coordinator {
        let c = Coordinator(self)
        c.pendingCursorOffset = initialCursorOffset
        return c
    }

    func makeUIView(context: Context) -> GutteredTextView {
        let view = GutteredTextView(fontSize: fontSize, isMarkdown: isMarkdown, textBinding: $text)
        view.textView.delegate = context.coordinator
        view.textView.text = text
        view.showGutter = showLineNumbers
        if isMarkdown {
            view.applyMarkdownStyle()
        }
        return view
    }

    func updateUIView(_ view: GutteredTextView, context: Context) {
        // テキスト同期（外部からの変更のみ反映）
        if view.textView.text != text {
            view.textView.text = text
            view.refreshLineNumbers()
            if isMarkdown {
                view.applyMarkdownStyle()
            }
        }
        view.showGutter = showLineNumbers
        view.textView.isEditable = isEditable
        view.textView.isSelectable = isEditable
        // 非編集時のタップコールバックを更新
        view.onTapWhileReadOnly = isEditable ? nil : onTapWhileReadOnly

        // マークダウンモードの動的切り替え
        view.updateMarkdownMode(isMarkdown: isMarkdown, textBinding: $text)

        // フォーカス管理
        if isFocused && !view.textView.isFirstResponder {
            DispatchQueue.main.async {
                view.textView.becomeFirstResponder()
                // カーソル位置を設定
                if let offset = context.coordinator.pendingCursorOffset {
                    let safe = min(offset, (view.textView.text ?? "").count)
                    view.textView.selectedRange = NSRange(location: safe, length: 0)
                    // カーソルが画面外なら見える位置までスクロール
                    if let pos = view.textView.position(from: view.textView.beginningOfDocument, offset: safe),
                       let range = view.textView.textRange(from: pos, to: pos) {
                        let rect = view.textView.firstRect(for: range)
                        view.textView.scrollRectToVisible(rect.insetBy(dx: 0, dy: -40), animated: false)
                    }
                    context.coordinator.pendingCursorOffset = nil
                }
            }
        } else if !isFocused && view.textView.isFirstResponder {
            view.textView.resignFirstResponder()
        }
    }

    class Coordinator: NSObject, UITextViewDelegate {
        let parent: LineNumberTextEditor
        /// フォーカス時に適用するカーソル位置
        var pendingCursorOffset: Int?
        init(_ p: LineNumberTextEditor) { parent = p }

        func textViewDidChange(_ tv: UITextView) {
            parent.text = tv.text ?? ""
            if let gutter = tv.superview as? GutteredTextView {
                gutter.refreshLineNumbers()
                if gutter.isMarkdown {
                    gutter.applyMarkdownStyle()
                }
            }
        }

        func textViewDidBeginEditing(_ tv: UITextView) {
            DispatchQueue.main.async { self.parent.isFocused = true }
        }

        func textViewDidEndEditing(_ tv: UITextView) {
            DispatchQueue.main.async { self.parent.isFocused = false }
        }


        func scrollViewDidScroll(_ sv: UIScrollView) {
            (sv.superview as? GutteredTextView)?.syncGutter()
        }

        // 最大文字数制限（UITextView側で入力をブロック）
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            let current = textView.text ?? ""
            let newLength = current.count - range.length + text.count
            return newLength <= MemoInputViewModel.maxCharacterCount
        }
    }
}

// MARK: - ガター付きUITextViewコンテナ

class GutteredTextView: UIView {
    let textView: UITextView
    private let gutterDrawView = GutterDrawView()
    private let gutterScroll = UIScrollView()
    private let gutterWidth: CGFloat = 36

    /// 非編集時のタップコールバック（文字オフセットとUITextViewを返す）
    var onTapWhileReadOnly: ((Int, UITextView) -> Void)?

    /// マークダウンモード（動的に切り替え可能）
    private(set) var isMarkdown: Bool
    private let baseFontSize: CGFloat
    private let symbolColor = UIColor.systemGray3

    var showGutter: Bool = false {
        didSet {
            guard showGutter != oldValue else { return }
            gutterScroll.isHidden = !showGutter
            setNeedsLayout()
        }
    }

    init(fontSize: CGFloat, isMarkdown: Bool = false, textBinding: Binding<String>? = nil) {
        self.isMarkdown = isMarkdown
        self.baseFontSize = fontSize
        // TextKit 1を使用（行レイアウト情報の取得に必要）
        textView = UITextView(usingTextLayoutManager: false)
        super.init(frame: .zero)

        textView.font = .systemFont(ofSize: fontSize)
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(
            top: TextAreaLayout.textInsetTop,
            left: TextAreaLayout.textInsetLeft,
            bottom: TextAreaLayout.textInsetBottom,
            right: TextAreaLayout.textInsetRight
        )
        textView.contentInset.bottom = TextAreaLayout.contentInsetBottom
        textView.textContainer.lineFragmentPadding = TextAreaLayout.lineFragmentPadding
        textView.alwaysBounceVertical = true

        gutterScroll.showsVerticalScrollIndicator = false
        gutterScroll.showsHorizontalScrollIndicator = false
        gutterScroll.isUserInteractionEnabled = false
        gutterScroll.isHidden = true
        gutterScroll.addSubview(gutterDrawView)

        addSubview(gutterScroll)
        addSubview(textView)
        backgroundColor = .clear

        // マークダウンモード: キーボード直上にツールバーを配置
        if isMarkdown, let binding = textBinding {
            let toolbar = MarkdownToolbar(text: binding)
            let hostingController = UIHostingController(rootView: toolbar)
            hostingController.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44)
            hostingController.view.backgroundColor = .secondarySystemBackground
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            let wrapper = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
            wrapper.addSubview(hostingController.view)
            NSLayoutConstraint.activate([
                hostingController.view.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
                hostingController.view.topAnchor.constraint(equalTo: wrapper.topAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            ])
            textView.inputAccessoryView = wrapper
        }

        // 非編集時のタップ検出用
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleReadOnlyTap))
        tap.cancelsTouchesInView = false
        addGestureRecognizer(tap)

        // キーボード表示/非表示でcontentInset.bottomを自動調整
        NotificationCenter.default.addObserver(self, selector: #selector(adjustForKeyboard), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(adjustForKeyboard), name: UIResponder.keyboardWillHideNotification, object: nil)

        // マークダウンツールバーからのカーソル位置通知を受信
        NotificationCenter.default.addObserver(self, selector: #selector(handleMarkdownCursor), name: .markdownCursorFromEnd, object: nil)
    }

    @objc private func handleMarkdownCursor(_ notification: Notification) {
        guard isMarkdown, let offset = notification.userInfo?["offset"] as? Int else { return }
        let len = textView.text.count
        let pos = max(0, len - offset)
        textView.selectedRange = NSRange(location: pos, length: 0)
    }

    @objc private func adjustForKeyboard(_ notification: Notification) {
        let baseBottom = TextAreaLayout.contentInsetBottom
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            textView.contentInset.bottom = baseBottom
            return
        }
        // textViewのスクリーン座標での下端
        let tvBottom = textView.convert(textView.bounds, to: nil).maxY
        // キーボードのスクリーン座標での上端
        let kbTop = frame.origin.y
        // 重なり分だけインセットを追加
        let overlap = max(0, tvBottom - kbTop)
        textView.contentInset.bottom = baseBottom + overlap
        textView.verticalScrollIndicatorInsets.bottom = overlap
    }

    @objc private func handleReadOnlyTap(_ gesture: UITapGestureRecognizer) {
        guard !textView.isEditable, let callback = onTapWhileReadOnly else { return }
        let point = gesture.location(in: textView)
        let lm = textView.layoutManager
        let tc = textView.textContainer
        let adjusted = CGPoint(
            x: point.x - textView.textContainerInset.left,
            y: point.y - textView.textContainerInset.top
        )
        let index = lm.characterIndex(for: adjusted, in: tc, fractionOfDistanceBetweenInsertionPoints: nil)
        let textLength = (textView.text ?? "").count
        callback(min(index, textLength), textView)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let gw: CGFloat = showGutter ? gutterWidth : 0
        gutterScroll.frame = CGRect(x: 0, y: 0, width: gw, height: bounds.height)
        textView.frame = CGRect(x: gw, y: 0, width: bounds.width - gw, height: bounds.height)
        refreshLineNumbers()
    }

    func syncGutter() {
        gutterScroll.contentOffset.y = textView.contentOffset.y
    }

    func refreshLineNumbers() {
        guard showGutter else { return }
        let lm = textView.layoutManager

        let nsText = (textView.text ?? "") as NSString
        let inset = textView.textContainerInset
        var entries: [(number: Int, y: CGFloat, height: CGFloat)] = []

        if nsText.length == 0 {
            // 空テキスト: 1行目だけ表示
            entries.append((1, inset.top, 22))
        } else {
            var paraNum = 1
            var charIdx = 0
            while charIdx < nsText.length {
                let glyphIdx = lm.glyphIndexForCharacter(at: charIdx)
                if glyphIdx < lm.numberOfGlyphs {
                    var range = NSRange()
                    let rect = lm.lineFragmentRect(forGlyphAt: glyphIdx, effectiveRange: &range)
                    entries.append((paraNum, rect.origin.y + inset.top, rect.size.height))
                }
                let paraRange = nsText.paragraphRange(for: NSRange(location: charIdx, length: 0))
                charIdx = NSMaxRange(paraRange)
                paraNum += 1
            }
            // 末尾が改行 → 空の次行を表示
            if nsText.hasSuffix("\n"), let last = entries.last {
                entries.append((paraNum, last.y + last.height, last.height))
            }
        }

        gutterDrawView.entries = entries
        let maxY = entries.last.map { $0.y + $0.height } ?? bounds.height
        let contentHeight = max(maxY + inset.bottom + 40, bounds.height)
        gutterDrawView.frame = CGRect(x: 0, y: 0, width: gutterWidth, height: contentHeight)
        gutterScroll.contentSize = gutterDrawView.frame.size
        gutterDrawView.setNeedsDisplay()
    }

    // MARK: - マークダウンモードの動的切り替え

    func updateMarkdownMode(isMarkdown: Bool, textBinding: Binding<String>) {
        guard self.isMarkdown != isMarkdown else { return }
        self.isMarkdown = isMarkdown

        if isMarkdown {
            // ツールバーを付ける
            let toolbar = MarkdownToolbar(text: textBinding)
            let hostingController = UIHostingController(rootView: toolbar)
            hostingController.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44)
            hostingController.view.backgroundColor = .secondarySystemBackground
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            let wrapper = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
            wrapper.addSubview(hostingController.view)
            NSLayoutConstraint.activate([
                hostingController.view.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
                hostingController.view.topAnchor.constraint(equalTo: wrapper.topAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            ])
            textView.inputAccessoryView = wrapper
            applyMarkdownStyle()
        } else {
            // ツールバーを外してスタイルをリセット
            textView.inputAccessoryView = nil
            resetTextStyle()
        }
        // inputAccessoryViewの変更を反映
        textView.reloadInputViews()
    }

    // マークダウンスタイルを解除して通常テキストに戻す
    private func resetTextStyle() {
        let storage = textView.textStorage
        guard storage.length > 0 else { return }
        let fullRange = NSRange(location: 0, length: storage.length)
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
        storage.endEditing()
    }

    // MARK: - マークダウンスタイリング（Bear風インライン装飾）

    func applyMarkdownStyle() {
        let storage = textView.textStorage
        let fullText = storage.string
        guard !fullText.isEmpty else { return }
        let fullRange = NSRange(location: 0, length: storage.length)

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

            let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
            let indent = line.count - trimmed.count

            if line.hasPrefix("### ") {
                mdStyleHeading(storage, lineRange: lineRange, prefixLength: 4, fontSize: baseFontSize + 2)
            } else if line.hasPrefix("## ") {
                mdStyleHeading(storage, lineRange: lineRange, prefixLength: 3, fontSize: baseFontSize + 5)
            } else if line.hasPrefix("# ") {
                mdStyleHeading(storage, lineRange: lineRange, prefixLength: 2, fontSize: baseFontSize + 8)
            }
            else if lineLen >= 3 && (
                line.allSatisfy({ $0 == "-" }) ||
                line.allSatisfy({ $0 == "*" }) ||
                line.allSatisfy({ $0 == "_" })
            ) {
                storage.addAttribute(.foregroundColor, value: symbolColor, range: lineRange)
            }
            else if String(trimmed).hasPrefix("- [ ] ") || String(trimmed).hasPrefix("- [x] ") || String(trimmed).hasPrefix("- [X] ") {
                mdStyleSymbol(storage, lineRange: lineRange, symbolLength: indent + 6)
                if indent > 0 { mdApplyIndent(storage, lineRange: lineRange, level: indent) }
                if String(trimmed).hasPrefix("- [x] ") || String(trimmed).hasPrefix("- [X] ") {
                    let contentRange = NSRange(location: lineRange.location + indent + 6, length: max(0, lineLen - indent - 6))
                    storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: contentRange)
                    storage.addAttribute(.foregroundColor, value: UIColor.secondaryLabel, range: contentRange)
                }
            }
            else if String(trimmed).hasPrefix("- ") {
                mdStyleSymbol(storage, lineRange: lineRange, symbolLength: indent + 2)
                if indent > 0 { mdApplyIndent(storage, lineRange: lineRange, level: indent) }
            }
            else if let dotRange = mdMatchNumberedList(String(trimmed)) {
                let prefixLen = indent + dotRange
                mdStyleSymbol(storage, lineRange: lineRange, symbolLength: prefixLen)
                if indent > 0 { mdApplyIndent(storage, lineRange: lineRange, level: indent) }
            }
            else if line.hasPrefix("> ") {
                mdStyleSymbol(storage, lineRange: lineRange, symbolLength: 2)
                let contentRange = NSRange(location: lineRange.location + 2, length: max(0, lineLen - 2))
                storage.addAttribute(.font, value: UIFont.italicSystemFont(ofSize: baseFontSize), range: contentRange)
                storage.addAttribute(.foregroundColor, value: UIColor.secondaryLabel, range: contentRange)
            }
            else if line.hasPrefix("```") {
                storage.addAttribute(.foregroundColor, value: symbolColor, range: lineRange)
                storage.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: baseFontSize - 1, weight: .regular), range: lineRange)
            }

            mdApplyInlineStyles(storage, in: lineRange, text: line)
            currentLocation += lineLen + 1
        }

        storage.endEditing()

        // カーソル位置の入力属性をデフォルトに戻す
        let defaultParagraph = NSMutableParagraphStyle()
        defaultParagraph.lineSpacing = 4
        textView.typingAttributes = [
            .font: defaultFont,
            .foregroundColor: UIColor.label,
            .paragraphStyle: defaultParagraph,
        ]
    }

    private func mdStyleHeading(_ storage: NSTextStorage, lineRange: NSRange, prefixLength: Int, fontSize: CGFloat) {
        let headingFont = UIFont.systemFont(ofSize: fontSize, weight: .bold)
        storage.addAttribute(.font, value: headingFont, range: lineRange)
        let symbolRange = NSRange(location: lineRange.location, length: min(prefixLength, lineRange.length))
        storage.addAttribute(.foregroundColor, value: symbolColor, range: symbolRange)
    }

    private func mdStyleSymbol(_ storage: NSTextStorage, lineRange: NSRange, symbolLength: Int) {
        let symbolRange = NSRange(location: lineRange.location, length: min(symbolLength, lineRange.length))
        storage.addAttribute(.foregroundColor, value: symbolColor, range: symbolRange)
    }

    private func mdMatchNumberedList(_ line: String) -> Int? {
        guard let first = line.first, first.isNumber else { return nil }
        for (i, ch) in line.enumerated() {
            if ch == "." {
                let nextIndex = line.index(line.startIndex, offsetBy: i + 1, limitedBy: line.endIndex)
                if let nextIndex, line[nextIndex] == " " { return i + 2 }
                return nil
            }
            if !ch.isNumber { return nil }
        }
        return nil
    }

    private func mdApplyIndent(_ storage: NSTextStorage, lineRange: NSRange, level: Int) {
        let indentParagraph = NSMutableParagraphStyle()
        indentParagraph.lineSpacing = 4
        let indentPoints = CGFloat(level) * 10.0
        indentParagraph.headIndent = indentPoints
        indentParagraph.firstLineHeadIndent = indentPoints
        storage.addAttribute(.paragraphStyle, value: indentParagraph, range: lineRange)
    }

    private func mdApplyInlineStyles(_ storage: NSTextStorage, in lineRange: NSRange, text: String) {
        let nsText = text as NSString

        mdApplyPattern("\\*\\*(.+?)\\*\\*", storage: storage, lineRange: lineRange, nsText: nsText) { matchRange, innerRange in
            storage.addAttribute(.foregroundColor, value: self.symbolColor, range: NSRange(location: matchRange.location, length: 2))
            storage.addAttribute(.foregroundColor, value: self.symbolColor, range: NSRange(location: matchRange.location + matchRange.length - 2, length: 2))
            storage.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: self.baseFontSize), range: innerRange)
        }

        mdApplyPattern("(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)", storage: storage, lineRange: lineRange, nsText: nsText) { matchRange, innerRange in
            storage.addAttribute(.foregroundColor, value: self.symbolColor, range: NSRange(location: matchRange.location, length: 1))
            storage.addAttribute(.foregroundColor, value: self.symbolColor, range: NSRange(location: matchRange.location + matchRange.length - 1, length: 1))
            storage.addAttribute(.font, value: UIFont.italicSystemFont(ofSize: self.baseFontSize), range: innerRange)
        }

        mdApplyPattern("~~(.+?)~~", storage: storage, lineRange: lineRange, nsText: nsText) { matchRange, innerRange in
            storage.addAttribute(.foregroundColor, value: self.symbolColor, range: NSRange(location: matchRange.location, length: 2))
            storage.addAttribute(.foregroundColor, value: self.symbolColor, range: NSRange(location: matchRange.location + matchRange.length - 2, length: 2))
            storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: innerRange)
        }

        mdApplyPattern("`([^`]+)`", storage: storage, lineRange: lineRange, nsText: nsText) { matchRange, innerRange in
            storage.addAttribute(.foregroundColor, value: self.symbolColor, range: NSRange(location: matchRange.location, length: 1))
            storage.addAttribute(.foregroundColor, value: self.symbolColor, range: NSRange(location: matchRange.location + matchRange.length - 1, length: 1))
            storage.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: self.baseFontSize - 1, weight: .regular), range: innerRange)
            storage.addAttribute(.backgroundColor, value: UIColor.systemGray6, range: innerRange)
        }

        mdApplyPattern("\\[([^\\]]+)\\]\\(([^)]+)\\)", storage: storage, lineRange: lineRange, nsText: nsText) { matchRange, innerRange in
            storage.addAttribute(.foregroundColor, value: self.symbolColor, range: NSRange(location: matchRange.location, length: 1))
            let closeBracketPos = matchRange.location + 1 + innerRange.length
            storage.addAttribute(.foregroundColor, value: self.symbolColor, range: NSRange(location: closeBracketPos, length: 1))
            storage.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: innerRange)
            storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: innerRange)
            let urlPartStart = closeBracketPos + 1
            let urlPartLen = matchRange.location + matchRange.length - urlPartStart
            if urlPartLen > 0 {
                let urlRange = NSRange(location: urlPartStart, length: urlPartLen)
                storage.addAttribute(.foregroundColor, value: self.symbolColor, range: urlRange)
                storage.addAttribute(.font, value: UIFont.systemFont(ofSize: self.baseFontSize - 2), range: urlRange)
            }
        }
    }

    private func mdApplyPattern(
        _ pattern: String, storage: NSTextStorage, lineRange: NSRange, nsText: NSString,
        apply: (NSRange, NSRange) -> Void
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let matches = regex.matches(in: nsText as String, range: NSRange(location: 0, length: nsText.length))
        for match in matches {
            let matchRange = NSRange(location: lineRange.location + match.range.location, length: match.range.length)
            let innerLocalRange = match.range(at: 1)
            let innerRange = NSRange(location: lineRange.location + innerLocalRange.location, length: innerLocalRange.length)
            guard matchRange.location + matchRange.length <= storage.length,
                  innerRange.location + innerRange.length <= storage.length else { continue }
            apply(matchRange, innerRange)
        }
    }
}

// MARK: - 行番号描画ビュー（Core Graphics）

private class GutterDrawView: UIView {
    var entries: [(number: Int, y: CGFloat, height: CGFloat)] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: UIColor.tertiaryLabel,
        ]
        for entry in entries {
            let s = "\(entry.number)" as NSString
            let sz = s.size(withAttributes: attrs)
            let drawX = bounds.width - sz.width - 4
            let drawY = entry.y + (entry.height - sz.height) / 2
            s.draw(at: CGPoint(x: drawX, y: drawY), withAttributes: attrs)
        }
    }
}

// MARK: - 閲覧モード用の行番号（SwiftUI純正、ScrollView内で使用）

struct ReadOnlyLineNumbers: View {
    let text: String

    var body: some View {
        // 全行番号を1つのTextにまとめて描画（ForEachより大幅に軽量）
        let lineCount = max(text.components(separatedBy: "\n").count, 1)
        let numbers = (1...lineCount).map { String($0) }.joined(separator: "\n")
        Text(numbers)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.tertiary)
            .lineSpacing(5.2)
            .multilineTextAlignment(.trailing)
            .frame(width: 32, alignment: .trailing)
            .padding(.top, 2)
    }
}
