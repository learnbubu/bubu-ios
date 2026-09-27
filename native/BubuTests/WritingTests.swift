import XCTest
@testable import Bubu

final class WritingTests: XCTestCase {
    let data = StrokeData.shared

    func testStrokeDataLoads() {
        XCTAssertGreaterThan(data.chars.count, 1000)
        XCTAssertTrue(data.writable("你好"))
        XCTAssertFalse(data.writable("ABC"))
    }

    /// A stroke drawn along its own centre line, with a little wobble, is accepted.
    func testDrawingEachStrokeAlongItsMedianMatches() throws {
        for ch in ["你", "好", "我", "是"] {
            let c = try XCTUnwrap(data.chars[ch])
            for i in 0..<c.count {
                let drawn = c.median(i).enumerated().map { k, p in CGPoint(x: p.x + (k % 2 == 0 ? 8 : -8), y: p.y + 6) }
                XCTAssertTrue(StrokeMatch.matches(drawn, char: c, stroke: i, leniency: 1.4, outlineVisible: true), "\(ch) stroke \(i)")
            }
        }
    }

    func testWrongOrBackwardsStrokesAreRejected() throws {
        let c = try XCTUnwrap(data.chars["好"])
        // the last stroke drawn where the first should be
        XCTAssertFalse(StrokeMatch.matches(c.median(c.count - 1), char: c, stroke: 0, leniency: 1.4, outlineVisible: true))
        // the first stroke drawn backwards
        XCTAssertFalse(StrokeMatch.matches(c.median(0).reversed(), char: c, stroke: 0, leniency: 1.4, outlineVisible: true))
        // a dot
        XCTAssertFalse(StrokeMatch.matches([CGPoint(x: 500, y: 500)], char: c, stroke: 0, leniency: 1.4, outlineVisible: true))
    }

    func testStrokeOutlinesParse() throws {
        let c = try XCTUnwrap(data.chars["你"])
        for s in c.strokes { XCTAssertFalse(SVGPath.parse(s).boundingRect.isEmpty) }
    }

    func testGlyphSpaceRoundTrips() {
        let g = GlyphSpace(size: 300)
        let p = CGPoint(x: 512, y: 400)
        let back = g.toGlyph(g.toView(p))
        XCTAssertEqual(back.x, p.x, accuracy: 0.001)
        XCTAssertEqual(back.y, p.y, accuracy: 0.001)
    }
}
