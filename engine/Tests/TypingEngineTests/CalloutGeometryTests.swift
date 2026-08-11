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

@Test func alternatesMetricsMatchStock() {
    #expect(CalloutGeometry.alternateItemMaxSize == 50)
    #expect(CalloutGeometry.alternateFontSize == 20)
    #expect(CalloutGeometry.selectedCornerRadius == 10)
}
