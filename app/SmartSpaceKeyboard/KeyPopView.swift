import UIKit
import TypingEngine

/// Stock key-preview balloon: the key cap extends upward into a bubble
/// overhanging each side, with a concave neck curving back down to the
/// cap. Every number comes from CalloutGeometry/StockKeyTheme; the cap
/// slice at the bottom of the path covers the key exactly, so balloon
/// and key read as one contiguous shape.
final class KeyPopView: UIView {
    private let shape = CAShapeLayer()
    private let label = UILabel()

    /// - Parameter capFrame: the key cap's frame in the superview's
    ///   coordinates; the pop frames itself over it. Edge keys skew the
    ///   bubble (overhang redistribution), like stock.
    init(title: String, capFrame: CGRect, screenWidth: CGFloat) {
        let over = CalloutGeometry.overhangs(keyMinX: capFrame.minX,
                                             keyWidth: capFrame.width,
                                             screenWidth: screenWidth)
        let width = capFrame.width + over.left + over.right
        let height = CalloutGeometry.bubbleHeight + CalloutGeometry.neckHeight + capFrame.height
        super.init(frame: CGRect(x: capFrame.minX - over.left,
                                 y: capFrame.maxY - height,
                                 width: width, height: height))
        isUserInteractionEnabled = false

        shape.path = CalloutPath.outline(width: width,
                                         capLeft: over.left,
                                         capRight: width - over.right,
                                         capHeight: capFrame.height).cgPath
        layer.addSublayer(shape)

        label.text = title
        label.font = .systemFont(ofSize: CalloutGeometry.previewFontSize, weight: .light)
        label.textAlignment = .center
        label.frame = CGRect(x: 0, y: 0, width: width, height: CalloutGeometry.bubbleHeight)
        addSubview(label)

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.1
        layer.shadowRadius = 5
        layer.shadowOffset = .zero
        refreshFill()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refreshFill()
    }

    private func refreshFill() {
        let dark = traitCollection.userInterfaceStyle == .dark
        shape.fillColor = KeyboardViewController.uiColor(
            StockKeyTheme.balloonFill(dark: dark)).cgColor
        label.textColor = dark ? .white : .black
    }

}

/// Shared outline for the preview balloon and the action callout: bubble
/// with 10pt top corners, concave necks, cap slice with the stock 5pt
/// bottom corners. When the bubble extends past the cap, the bottom edge
/// runs flat and the neck drops beside the cap.
enum CalloutPath {
    static func outline(width: CGFloat, capLeft: CGFloat, capRight: CGFloat,
                        capHeight: CGFloat) -> UIBezierPath {
        let r = CalloutGeometry.bubbleCornerRadius
        let capR = StockKeyTheme.capCornerRadius(
            liquidGlass: KeyboardViewController.liquidGlass)
        let curve = CalloutGeometry.neckCurveWidth
        let bubbleH = CalloutGeometry.bubbleHeight
        let neckMid = bubbleH + CalloutGeometry.neckHeight / 2
        let neckBottom = bubbleH + CalloutGeometry.neckHeight
        let capBottom = neckBottom + capHeight

        let p = UIBezierPath()
        p.move(to: CGPoint(x: 0, y: r))
        p.addArc(withCenter: CGPoint(x: r, y: r), radius: r,
                 startAngle: .pi, endAngle: 3 * .pi / 2, clockwise: true)
        p.addLine(to: CGPoint(x: width - r, y: 0))
        p.addArc(withCenter: CGPoint(x: width - r, y: r), radius: r,
                 startAngle: 3 * .pi / 2, endAngle: 0, clockwise: true)
        if width - capRight - curve > r {
            // Rounded bottom corner, flat run, then the neck by the cap.
            p.addLine(to: CGPoint(x: width, y: bubbleH - r))
            p.addArc(withCenter: CGPoint(x: width - r, y: bubbleH - r), radius: r,
                     startAngle: 0, endAngle: .pi / 2, clockwise: true)
            p.addLine(to: CGPoint(x: capRight + curve, y: bubbleH))
            p.addCurve(to: CGPoint(x: capRight, y: neckBottom),
                       controlPoint1: CGPoint(x: capRight + curve, y: neckMid),
                       controlPoint2: CGPoint(x: capRight, y: neckMid))
        } else {
            p.addLine(to: CGPoint(x: width, y: bubbleH))
            p.addCurve(to: CGPoint(x: capRight, y: neckBottom),
                       controlPoint1: CGPoint(x: width, y: neckMid),
                       controlPoint2: CGPoint(x: capRight, y: neckMid))
        }
        p.addLine(to: CGPoint(x: capRight, y: capBottom - capR))
        p.addArc(withCenter: CGPoint(x: capRight - capR, y: capBottom - capR), radius: capR,
                 startAngle: 0, endAngle: .pi / 2, clockwise: true)
        p.addLine(to: CGPoint(x: capLeft + capR, y: capBottom))
        p.addArc(withCenter: CGPoint(x: capLeft + capR, y: capBottom - capR), radius: capR,
                 startAngle: .pi / 2, endAngle: .pi, clockwise: true)
        p.addLine(to: CGPoint(x: capLeft, y: neckBottom))
        if capLeft - curve > r {
            p.addCurve(to: CGPoint(x: capLeft - curve, y: bubbleH),
                       controlPoint1: CGPoint(x: capLeft, y: neckMid),
                       controlPoint2: CGPoint(x: capLeft - curve, y: neckMid))
            p.addLine(to: CGPoint(x: r, y: bubbleH))
            p.addArc(withCenter: CGPoint(x: r, y: bubbleH - r), radius: r,
                     startAngle: .pi / 2, endAngle: .pi, clockwise: true)
        } else {
            p.addCurve(to: CGPoint(x: 0, y: bubbleH),
                       controlPoint1: CGPoint(x: capLeft, y: neckMid),
                       controlPoint2: CGPoint(x: 0, y: neckMid))
        }
        p.close()
        return p
    }
}
