import UIKit
import TypingEngine

/// Stock-feel touch layer for the character keys (stock-parity AC 2): sits
/// over the key rows, resolves every touch through KeyZoneMap (gutters and
/// edges belong to the nearest key), tracks multiple concurrent touches so
/// rolled fast typing never drops a character, and drives the key-pop
/// bubble at touch-down. Function keys keep their UIButton behavior: the
/// surface passes their zones through untouched.
/// Purely visual container: it and its children never claim touches, so
/// everything falls through to KeyTouchSurface beneath, whose zone map is
/// the single resolver (function-key touches come back to the buttons via
/// its redirect). Sitting above the surface keeps the buttons in the AX
/// tree; an interactive overlay on top of them culls them from it.
final class PassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        nil
    }
}

/// Key cap whose hit area can extend past the visible cap to its full
/// touch cell: gutter touches routed to a function key by KeyTouchSurface
/// must still count as "inside" or UIControl fires .touchUpOutside and the
/// tap does nothing.
final class KeyButton: UIButton {
    /// Negative values grow the hit area beyond the visible cap.
    var hitOutset = UIEdgeInsets.zero

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.inset(by: hitOutset).contains(point)
    }
}

final class KeyTouchSurface: UIView {

    /// Zones prefixed with this are function keys the surface never claims.
    static let passthroughPrefix = "__"

    /// Resolves a function zone id to its live button, so gutter touches
    /// around function keys reach them instead of dying.
    var functionButtonProvider: ((String) -> UIView?)?

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
    /// (from, to): the finger slid from one character key to another.
    var onTouchMoved: ((String, String) -> Void)?
    var onCommit: ((String) -> Void)?
    /// The finger slid off the character keys; that touch types nothing.
    var onTouchExit: ((String) -> Void)?
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

    /// Single resolver for the key area: every touch goes through the zone
    /// map (nearest key wins, gutters included). Character keys the surface
    /// tracks itself; function zones route to their live button so the
    /// gutters around shift/delete/space/return are never dead.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        freshenZones()
        guard self.point(inside: point, with: event),
              let id = zoneMap.key(at: Point(x: point.x, y: point.y))
        else { return nil }
        if id.hasPrefix(Self.passthroughPrefix) {
            return functionButtonProvider?(id)
        }
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
            guard let current = tracked[touch] else { continue }
            let key = characterKey(at: touch.location(in: self))
            if key == current { continue }
            holdTimers[touch]?.invalidate()
            holdTimers[touch] = nil
            if let key {
                // Slid to a neighboring character key: stock retargets.
                tracked[touch] = key
                onTouchMoved?(current, key)
            } else {
                // Slid onto a function key or off the surface: stock
                // cancels -- releasing there must not type the old key.
                tracked[touch] = nil
                onTouchExit?(current)
            }
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
