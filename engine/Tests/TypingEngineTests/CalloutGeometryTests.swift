import Testing
import TypingEngine

// Stock callout geometry (KeyboardKit Callouts source, research
// 2026-08-10, high confidence): the preview balloon reads as the key cap
// extending upward, overhanging 13pt per side (8pt neck curve + half the
// 10pt bubble radius), bubble 55pt tall, neck 15pt tall, 34pt light
// label. It appears instantly and stays at least 0.05s so a fast tap
// still shows it.

@Test func balloonOverhangsThirteenPointsPerSide() {
    #expect(CalloutGeometry.overhangPerSide == 13)
    #expect(CalloutGeometry.bubbleWidth(keyWidth: 33) == 59)
}

@Test func balloonVerticalMetricsMatchStock() {
    #expect(CalloutGeometry.bubbleHeight == 55)
    #expect(CalloutGeometry.neckHeight == 15)
    #expect(CalloutGeometry.bubbleCornerRadius == 10)
    #expect(CalloutGeometry.neckCurveWidth == 8)
}

@Test func previewLabelIsThirtyFourLight() {
    #expect(CalloutGeometry.previewFontSize == 34)
}

@Test func previewStaysUpAtLeastFiftyMilliseconds() {
    #expect(CalloutGeometry.minimumDwell == 0.05)
}

// Stock skews edge balloons: q and p keep the full 26pt total overhang
// but give the off-screen side to the other. 2pt stays clear of the
// screen edge.

@Test func centeredKeyKeepsSymmetricOverhang() {
    let o = CalloutGeometry.overhangs(keyMinX: 180, keyWidth: 33, screenWidth: 402)
    #expect(o.left == 13)
    #expect(o.right == 13)
}

@Test func leftEdgeKeyGivesItsOverhangToTheRight() {
    let o = CalloutGeometry.overhangs(keyMinX: 4, keyWidth: 33, screenWidth: 402)
    #expect(o.left == 2)
    #expect(o.right == 24)
}

@Test func rightEdgeKeyGivesItsOverhangToTheLeft() {
    let o = CalloutGeometry.overhangs(keyMinX: 365, keyWidth: 33, screenWidth: 402)
    #expect(o.left == 24)
    #expect(o.right == 2)
}

@Test func alternatesMetricsMatchStock() {
    #expect(CalloutGeometry.alternateItemMaxSize == 50)
    #expect(CalloutGeometry.alternateFontSize == 20)
    #expect(CalloutGeometry.selectedCornerRadius == 10)
}
