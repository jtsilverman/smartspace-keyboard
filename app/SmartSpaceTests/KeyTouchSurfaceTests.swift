import XCTest
import UIKit
import TypingEngine

/// Gutter touches around function keys must resolve to the function key,
/// exactly like the letter gutters already resolve to the nearest letter
/// (stock-parity: no dead space anywhere on the key area).
final class KeyTouchSurfaceTests: XCTestCase {

    /// Row-3 geometry cut down to the seam under test: shift cell 0-51,
    /// flank gap to 58.67, "z" cell from there. Full-height 54pt cells.
    private func makeSurface(buttons: [String: UIButton]) -> KeyTouchSurface {
        let surface = KeyTouchSurface(frame: CGRect(x: 0, y: 0, width: 200, height: 54))
        surface.zoneProvider = {
            [KeyZone(id: "__shift", frame: Rect(x: 0, y: 0, width: 51, height: 54)),
             KeyZone(id: "z", frame: Rect(x: 58.67, y: 0, width: 36, height: 54))]
        }
        surface.functionButtonProvider = { buttons[$0] }
        return surface
    }

    func testFunctionCellTouchResolvesToItsButton() {
        let shift = UIButton()
        let surface = makeSurface(buttons: ["__shift": shift])
        XCTAssertTrue(surface.hitTest(CGPoint(x: 25, y: 27), with: nil) === shift)
    }

    func testFlankGapTouchNearerFunctionKeyResolvesToItsButton() {
        let shift = UIButton()
        let surface = makeSurface(buttons: ["__shift": shift])
        // 2pt into the gap right of the shift cell: nearest key is shift.
        XCTAssertTrue(surface.hitTest(CGPoint(x: 53, y: 27), with: nil) === shift)
    }

    func testFlankGapTouchNearerCharacterStaysWithSurface() {
        let shift = UIButton()
        let surface = makeSurface(buttons: ["__shift": shift])
        // 2pt left of the "z" cell: nearest key is z, surface keeps it.
        XCTAssertTrue(surface.hitTest(CGPoint(x: 57, y: 27), with: nil) === surface)
    }

    func testCharacterCellTouchStaysWithSurface() {
        let surface = makeSurface(buttons: [:])
        XCTAssertTrue(surface.hitTest(CGPoint(x: 70, y: 27), with: nil) === surface)
    }

    func testKeyButtonHitAreaExtendsByOutset() {
        let cap = KeyButton(frame: CGRect(x: 0, y: 0, width: 33, height: 43))
        cap.hitOutset = UIEdgeInsets(top: -11, left: -13.4, bottom: -20, right: -13.4)
        // 12pt below the cap: inside the cell hang plus tolerance.
        XCTAssertTrue(cap.point(inside: CGPoint(x: 16, y: 55), with: nil))
        // Far beyond the outset stays outside.
        XCTAssertFalse(cap.point(inside: CGPoint(x: 16, y: 80), with: nil))
    }
}
