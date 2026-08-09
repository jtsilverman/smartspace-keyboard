import Testing
import TypingEngine

// MARK: - KeyTouchTracker: per-touch decisions (stock-parity: no tap is
// ever eaten -- a held key still types on release).

@Test func tapCommitsOnRelease() {
    var tracker = KeyTouchTracker()
    #expect(tracker.began(1, key: "g") == .keyDown("g"))
    #expect(tracker.ended(1, x: 0) == .commit("g"))
}

@Test func holdWithoutAlternatesStillCommitsOnRelease() {
    var tracker = KeyTouchTracker()
    _ = tracker.began(1, key: "t")
    // Hold fires; "t" has no alternates, so nothing changes visually and
    // the release must still type the letter (stock behavior).
    #expect(tracker.holdFired(1, hasAlternates: false) == KeyTouchTracker.Event.none)
    #expect(tracker.ended(1, x: 0) == .commit("t"))
}

@Test func holdWithAlternatesEntersSlideSelectAndDefaultsToBase() {
    var tracker = KeyTouchTracker()
    _ = tracker.began(1, key: "e")
    #expect(tracker.holdFired(1, hasAlternates: true) == .showAlternates("e"))
    // Releasing without sliding commits via the alternates overlay, which
    // defaults to the base key (stock types "e").
    #expect(tracker.ended(1, x: 12) == .commitAlternate(base: "e", x: 12))
}

@Test func slideDuringAlternatesReportsPosition() {
    var tracker = KeyTouchTracker()
    _ = tracker.began(1, key: "e")
    _ = tracker.holdFired(1, hasAlternates: true)
    #expect(tracker.moved(1, key: "r", x: 55) == .moveAlternate(x: 55))
    #expect(tracker.ended(1, x: 60) == .commitAlternate(base: "e", x: 60))
}

@Test func retargetAndExitKeepStockSemantics() {
    var tracker = KeyTouchTracker()
    _ = tracker.began(1, key: "g")
    #expect(tracker.moved(1, key: "h", x: 0) == .retarget(from: "g", to: "h"))
    #expect(tracker.moved(1, key: nil, x: 0) == .exitKey("h"))
    #expect(tracker.ended(1, x: 0) == KeyTouchTracker.Event.none)
}

@Test func twoFingersTrackIndependently() {
    var tracker = KeyTouchTracker()
    _ = tracker.began(1, key: "a")
    _ = tracker.began(2, key: "l")
    #expect(tracker.ended(2, x: 0) == .commit("l"))
    #expect(tracker.ended(1, x: 0) == .commit("a"))
}

@Test func cancelDropsTheTouch() {
    var tracker = KeyTouchTracker()
    _ = tracker.began(1, key: "a")
    #expect(tracker.cancelled(1) == KeyTouchTracker.Event.none)
    #expect(tracker.ended(1, x: 0) == KeyTouchTracker.Event.none)
}
