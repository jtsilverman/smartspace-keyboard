import UIKit
import TypingEngine

/// Stock-feel touch layer for the character keys (stock-parity AC 2): sits
/// over the key rows, resolves every touch through KeyZoneMap (gutters and
/// edges belong to the nearest key), tracks multiple concurrent touches so
/// rolled fast typing never drops a character, and drives the key-pop
/// bubble at touch-down. Function keys keep their UIButton behavior: the
/// surface passes their zones through untouched.
/// Container that never claims touches itself: interactive children (the
/// function keys) win, everything else falls through to KeyTouchSurface
/// beneath. Plain UIView.hitTest would return self and swallow the touch.
final class PassthroughStackView: UIStackView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }
}

final class KeyTouchSurface: UIView {

    /// Zones prefixed with this are function keys the surface never claims.
    static let passthroughPrefix = "__"

    /// Zones are rebuilt lazily on the first touch after a layout change:
    /// stack views finish arranging AFTER the controller's layout callback,
    /// so an eager map captures stale frames and touches hit wrong keys.
    var zoneProvider: (() -> [KeyZone])?
    private var zoneMap = KeyZoneMap(keys: [])
    private var zonesDirty = true

    func invalidateZones() {
        zonesDirty = true
    }

    private func freshenZones() {
        guard zonesDirty, let zoneProvider else { return }
        zoneMap = KeyZoneMap(keys: zoneProvider())
        zonesDirty = false
    }

    var onTouchDown: ((String) -> Void)?
    var onTouchMoved: ((String) -> Void)?
    var onCommit: ((String) -> Void)?
    var onCancel: (() -> Void)?
    var onHold: ((String) -> Void)?

    private var tracked: [UITouch: String] = [:]
    private var holdTimers: [UITouch: Timer] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func characterKey(at point: CGPoint) -> String? {
        guard let id = zoneMap.key(at: Point(x: point.x, y: point.y)),
              !id.hasPrefix(Self.passthroughPrefix) else { return nil }
        return id
    }

    /// Claim only touches that resolve to a character key; everything else
    /// falls through to the buttons underneath.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        freshenZones()
        guard self.point(inside: point, with: event),
              characterKey(at: point) != nil else { return nil }
        return self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let key = characterKey(at: touch.location(in: self)) else { continue }
            tracked[touch] = key
            onTouchDown?(key)
            let timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
                guard let self, let held = self.tracked[touch] else { return }
                self.holdTimers[touch] = nil
                self.tracked[touch] = nil
                self.onHold?(held)
            }
            holdTimers[touch] = timer
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let current = tracked[touch],
                  let key = characterKey(at: touch.location(in: self)),
                  key != current else { continue }
            tracked[touch] = key
            holdTimers[touch]?.invalidate()
            holdTimers[touch] = nil
            onTouchMoved?(key)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            holdTimers[touch]?.invalidate()
            holdTimers[touch] = nil
            guard let key = tracked.removeValue(forKey: touch) else { continue }
            onCommit?(key)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            holdTimers[touch]?.invalidate()
            holdTimers[touch] = nil
            tracked[touch] = nil
        }
        if tracked.isEmpty { onCancel?() }
    }
}
