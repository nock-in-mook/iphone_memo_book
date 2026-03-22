import SwiftUI
import UIKit

/// タップ位置の文字オフセットを返す読み取り専用テキスト表示
/// ScrollView内に配置して使用（isScrollEnabled = false）
struct TappableReadOnlyText: UIViewRepresentable {
    let text: String
    var font: UIFont = .systemFont(ofSize: 17)
    var textColor: UIColor = .label
    var onTapAtOffset: (Int) -> Void

    func makeUIView(context: Context) -> TapTextInternalView {
        let view = TapTextInternalView()
        view.configure(font: font, textColor: textColor)
        view.onTapAtOffset = onTapAtOffset
        view.updateText(text)
        return view
    }

    func updateUIView(_ view: TapTextInternalView, context: Context) {
        view.updateText(text)
        view.textView.textColor = textColor
        view.onTapAtOffset = onTapAtOffset
    }

    // iOS 16+: SwiftUIがサイズを問い合わせるときに正確な高さを返す
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: TapTextInternalView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        let size = uiView.textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: size.height)
    }
}

/// 内部UIView: 非編集UITextViewでタップ位置を検出
class TapTextInternalView: UIView {
    let textView = UITextView(usingTextLayoutManager: false)
    var onTapAtOffset: ((Int) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        textView.isEditable = false
        textView.isSelectable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        addSubview(textView)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(font: UIFont, textColor: UIColor) {
        textView.font = font
        textView.textColor = textColor
    }

    func updateText(_ text: String) {
        guard textView.text != text else { return }
        textView.text = text
        invalidateIntrinsicContentSize()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        textView.frame = bounds
    }

    override var intrinsicContentSize: CGSize {
        let width = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width - 40
        return textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: textView)
        let layoutManager = textView.layoutManager
        let textContainer = textView.textContainer

        // テキストコンテナ座標に変換
        let adjusted = CGPoint(
            x: point.x - textView.textContainerInset.left,
            y: point.y - textView.textContainerInset.top
        )

        let index = layoutManager.characterIndex(
            for: adjusted,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )

        let textLength = (textView.text ?? "").count
        onTapAtOffset?(min(index, textLength))
    }
}
