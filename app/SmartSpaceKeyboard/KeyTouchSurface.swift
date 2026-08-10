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
    /// Text before the cursor; feeds the letter-bigram prior that grows
    /// hit targets toward likely next letters (stock behavior).
    var contextProvider: (() -> String)?
    private var zones: [KeyZone] = []
    private var zonesDirty = true

    func invalidateZones() {
        zonesDirty = true
    }

    private func freshenZones() {
        guard zonesDirty, let zoneProvider else { return }
        zones = zoneProvider()
        zonesDirty = false
    }

    private func resolvedKey(at point: CGPoint) -> String? {
        BiasedKeyResolver.key(at: Point(x: point.x, y: point.y),
                              zones: zones,
                              context: contextProvider?() ?? "")
    }

    var onTouchDown: ((String) -> Void)?
    /// (from, to): the finger slid from one character key to another.
    var onTouchMoved: ((String, String) -> Void)?
    var onCommit: ((String) -> Void)?
    /// The finger slid off the character keys; that touch types nothing.
    var onTouchExit: ((String) -> Void)?
    var onCancel: (() -> Void)?
    /// Hold fired on a key. Returns true when the controller showed the
    /// alternates overlay; the touch then enters slide-select.
    var onHold: ((String) -> Bool)?
    /// The finger slid while alternates are showing (point in surface coords).
    var onAlternateMoved: ((CGPoint) -> Void)?
    /// Release while alternates are showing: (base key, release point).
    var onAlternateEnded: ((String, CGPoint) -> Void)?

    /// All per-touch decisions live in the tested tracker; this view only
    /// forwards raw events and dispatches the resulting UI effects.
    private var tracker = KeyTouchTracker()
    private var holdTimers: [UITouch: Timer] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func characterKey(at point: CGPoint) -> String? {
        guard let id = resolvedKey(at: point),
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
              let id = resolvedKey(at: point) else { return nil }
        if id.hasPrefix(Self.passthroughPrefix) {
            return functionButtonProvider?(id)
        }
        return self
    }

    /// Stock hold delay before the alternates overlay appears.
    static let holdDelay: TimeInterval = 0.5

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let loc = touch.location(in: self)
            let event = tracker.began(touch.hash, key: characterKey(at: loc))
            guard case .keyDown(let key) = event else { continue }
            onTouchDown?(key)
            let timer = Timer.scheduledTimer(withTimeInterval: Self.holdDelay, repeats: false) { [weak self] _ in
                guard let self else { return }
                self.holdTimers[touch] = nil
                let shown = self.onHold?(key) ?? false
                _ = self.tracker.holdFired(touch.hash, hasAlternates: shown)
            }
            holdTimers[touch] = timer
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let loc = touch.location(in: self)
            let event = tracker.moved(touch.hash, key: characterKey(at: loc), x: loc.x)
            switch event {
            case .retarget(let from, let to):
                holdTimers[touch]?.invalidate()
                holdTimers[touch] = nil
                onTouchMoved?(from, to)
            case .exitKey(let key):
                holdTimers[touch]?.invalidate()
                holdTimers[touch] = nil
                onTouchExit?(key)
            case .moveAlternate:
                onAlternateMoved?(loc)
            default:
                break
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            holdTimers[touch]?.invalidate()
            holdTimers[touch] = nil
            let loc = touch.location(in: self)
            let event = tracker.ended(touch.hash, x: loc.x)
            switch event {
            case .commit(let key):
                onCommit?(key)
            case .commitAlternate(let base, _):
                onAlternateEnded?(base, loc)
            default:
                break
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            holdTimers[touch]?.invalidate()
            holdTimers[touch] = nil
            _ = tracker.cancelled(touch.hash)
        }
        if tracker.isIdle { onCancel?() }
    }
}
