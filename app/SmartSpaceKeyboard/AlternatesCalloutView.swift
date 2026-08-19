import UIKit
import TypingEngine

/// Stock action callout: the alternates bubble extends from the held key
/// toward the screen center, joined to the key by the same neck as the
/// preview balloon. Items are passive; the controller drives selection
/// from the ongoing touch and paints the blue pill.
final class AlternatesCalloutView: UIView {
    private let shape = CAShapeLayer()
    private(set) var itemButtons: [UIButton] = []

    /// - Parameter capFrame: the held key cap in the superview's
    ///   coordinates; options come pre-cased.
    init(options: [String], capFrame: CGRect, screenWidth: CGFloat) {
        let growLeading = CalloutGeometry.alternatesGrowLeading(
            keyMinX: capFrame.minX, screenWidth: screenWidth)
        let pad = CGFloat(CalloutGeometry.neckCurveWidth)
        let itemWidth = min(capFrame.width + 2 * StockLayoutMetrics.capInsetSide,
                            CalloutGeometry.alternateItemMaxSize)
        let width = CGFloat(options.count) * itemWidth + 2 * pad
        let height = CalloutGeometry.bubbleHeight + CalloutGeometry.neckHeight
            + capFrame.height
        var x = growLeading ? capFrame.maxX + pad - width : capFrame.minX - pad
        x = max(CalloutGeometry.screenMargin,
                min(x, screenWidth - width - CalloutGeometry.screenMargin))
        super.init(frame: CGRect(x: x, y: capFrame.maxY - height,
                                 width: width, height: height))
        isUserInteractionEnabled = false

        shape.path = CalloutPath.outline(width: width,
                                         capLeft: capFrame.minX - x,
                                         capRight: capFrame.maxX - x,
                                         capHeight: capFrame.height).cgPath
        layer.addSublayer(shape)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.1
        layer.shadowRadius = 5
        layer.shadowOffset = .zero

        // The nearest option sits over the held key: reversed when the
        // callout grows leading.
        let ordered = growLeading ? Array(options.reversed()) : options
        for (index, option) in ordered.enumerated() {
            let item = Self.itemButton(title: option)
            item.frame = CGRect(x: pad + CGFloat(index) * itemWidth, y: 6,
                                width: itemWidth,
                                height: CalloutGeometry.bubbleHeight - 12)
            addSubview(item)
            itemButtons.append(item)
        }
        refreshFill()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// The item under a horizontal position in this view's coordinates;
    /// stock is forgiving on y, only x picks.
    func item(atX x: CGFloat) -> UIButton? {
        itemButtons.first { $0.frame.minX <= x && x < $0.frame.maxX }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refreshFill()
    }

    private func refreshFill() {
        let dark = traitCollection.userInterfaceStyle == .dark
        shape.fillColor = KeyboardViewController.uiColor(
            StockKeyTheme.balloonFill(dark: dark)).cgColor
    }

    private static func itemButton(title: String) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.baseForegroundColor = .label
        config.contentInsets = .zero
        config.cornerStyle = .fixed
        config.background.cornerRadius = CalloutGeometry.selectedCornerRadius
        config.background.backgroundColor = .clear
        let item = UIButton(configuration: config)
        item.titleLabel?.font = .systemFont(ofSize: CalloutGeometry.alternateFontSize)
        item.isUserInteractionEnabled = false
        return item
    }
}
