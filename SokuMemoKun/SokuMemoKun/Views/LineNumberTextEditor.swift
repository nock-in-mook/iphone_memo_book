import SwiftUI
import UIKit

/// 行番号付きテキストエディタ（UITextView + 行番号ガター）
struct LineNumberTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var showLineNumbers: Bool
    var fontSize: CGFloat = 17

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> GutteredTextView {
        let view = GutteredTextView(fontSize: fontSize)
        view.textView.delegate = context.coordinator
        view.textView.text = text
        view.showGutter = showLineNumbers
        return view
    }

    func updateUIView(_ view: GutteredTextView, context: Context) {
        // テキスト同期（外部からの変更のみ反映）
        if view.textView.text != text {
            view.textView.text = text
            view.refreshLineNumbers()
        }
        view.showGutter = showLineNumbers

        // フォーカス管理
        if isFocused && !view.textView.isFirstResponder {
            DispatchQueue.main.async { view.textView.becomeFirstResponder() }
        } else if !isFocused && view.textView.isFirstResponder {
            view.textView.resignFirstResponder()
        }
    }

    class Coordinator: NSObject, UITextViewDelegate {
        let parent: LineNumberTextEditor
        init(_ p: LineNumberTextEditor) { parent = p }

        func textViewDidChange(_ tv: UITextView) {
            parent.text = tv.text ?? ""
            (tv.superview as? GutteredTextView)?.refreshLineNumbers()
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

    var showGutter: Bool = false {
        didSet {
            guard showGutter != oldValue else { return }
            gutterScroll.isHidden = !showGutter
            setNeedsLayout()
        }
    }

    init(fontSize: CGFloat) {
        // TextKit 1を使用（行レイアウト情報の取得に必要）
        textView = UITextView(usingTextLayoutManager: false)
        super.init(frame: .zero)

        textView.font = .systemFont(ofSize: fontSize)
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 6, bottom: 0, right: 4)
        textView.contentInset.bottom = 40
        textView.alwaysBounceVertical = true

        gutterScroll.showsVerticalScrollIndicator = false
        gutterScroll.showsHorizontalScrollIndicator = false
        gutterScroll.isUserInteractionEnabled = false
        gutterScroll.isHidden = true
        gutterScroll.addSubview(gutterDrawView)

        addSubview(gutterScroll)
        addSubview(textView)
        backgroundColor = .clear
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
        VStack(alignment: .trailing, spacing: 0) {
            let lines = text.components(separatedBy: "\n")
            ForEach(Array(lines.enumerated()), id: \.offset) { index, _ in
                Text("\(index + 1)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(height: 22, alignment: .top)
            }
        }
        .padding(.top, 2)
    }
}
