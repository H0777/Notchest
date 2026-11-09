import CoreGraphics
import XCTest
@testable import Notchest

final class IslandFrameTransitionTests: XCTestCase {
    private let compact = CGRect(x: -350, y: 766, width: 300, height: 34)
    private let expanded = CGRect(x: -580, y: 256, width: 760, height: 544)

    func testOpeningExpandsFromTopCenterAndEasesIntoItsTarget() {
        let opening = IslandFrameTransition(start: compact, target: expanded, expanded: true)
        let middle = opening.frame(at: 0.5)
        XCTAssertEqual(middle.midX, compact.midX, accuracy: 0.001)
        XCTAssertEqual(middle.maxY, compact.maxY, accuracy: 0.001)
        let widthFraction = (middle.width - compact.width) / (expanded.width - compact.width)
        let heightFraction = (middle.height - compact.height) / (expanded.height - compact.height)
        XCTAssertEqual(widthFraction, heightFraction, accuracy: 0.001)
        XCTAssertGreaterThan(widthFraction, 0.5)
        XCTAssertLessThan(widthFraction, 1)
        XCTAssertEqual(opening.frame(at: -0.1), compact)
        XCTAssertEqual(opening.frame(at: 1), expanded)
        XCTAssertEqual(opening.frame(at: 1.1), expanded)
    }

    func testMidFlightReversalStartsAtTheVisibleFrameAndKeepsItsScreenAnchor() {
        let opening = IslandFrameTransition(start: compact, target: expanded, expanded: true)
        let visible = opening.frame(at: 0.35)
        let closing = IslandFrameTransition(start: visible, target: compact, expanded: false)
        XCTAssertEqual(closing.frame(at: 0), visible)

        let middle = closing.frame(at: 0.5)
        XCTAssertEqual(middle.midX, compact.midX, accuracy: 0.001)
        XCTAssertEqual(middle.maxY, compact.maxY, accuracy: 0.001)
        XCTAssertEqual(middle.width, (visible.width + compact.width) / 2, accuracy: 0.001)
        XCTAssertEqual(middle.height, (visible.height + compact.height) / 2, accuracy: 0.001)
        XCTAssertEqual(closing.frame(at: 1), compact)
    }

    func testClosingMovesMonotonicallyAndEasesAtBothEnds() {
        let closing = IslandFrameTransition(start: expanded, target: compact, expanded: false)
        let widths = (0...4).map { closing.frame(at: CGFloat($0) / 4).width }
        let travel = expanded.width - compact.width
        XCTAssertEqual(widths.first, expanded.width)
        XCTAssertEqual(widths.last, compact.width)
        for (previous, next) in zip(widths, widths.dropFirst()) {
            XCTAssertGreaterThan(previous, next)
        }
        XCTAssertLessThan(expanded.width - widths[1], travel / 4)
        XCTAssertLessThan(widths[3] - compact.width, travel / 4)
    }
}
