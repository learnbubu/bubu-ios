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

    // MARK: the pen's ink

    /// Straight to the first midpoint, a curve per sample (the sample its control point), straight to the end.
    func testInkCurvesThroughTheMidpoints() {
        let pts = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0), CGPoint(x: 10, y: 10), CGPoint(x: 20, y: 10)]
        let expected: [InkGeometry.Segment] = [
            .move(CGPoint(x: 0, y: 0)),
            .line(CGPoint(x: 5, y: 0)),
            .quad(to: CGPoint(x: 10, y: 5), control: CGPoint(x: 10, y: 0)),
            .quad(to: CGPoint(x: 15, y: 10), control: CGPoint(x: 10, y: 10)),
            .line(CGPoint(x: 20, y: 10)),
        ]
        XCTAssertEqual(InkGeometry.segments(pts), expected)
    }

    func testInkFromOneOrTwoSamples() {
        XCTAssertEqual(InkGeometry.segments([]), [])
        let p = CGPoint(x: 3, y: 4), q = CGPoint(x: 9, y: 4)
        // a dot: a zero-length line, which round caps draw
        XCTAssertEqual(InkGeometry.segments([p]), [.move(p), .line(p)])
        XCTAssertEqual(InkGeometry.segments([p, q]), [.move(p), .line(q)])
    }

    /// The smooth ink starts and ends where the finger did and never strays outside the samples.
    func testInkPathEndsAtTheFingerWithoutOvershoot() {
        let pts = (0..<40).map { i in CGPoint(x: Double(i) * 5, y: 50 + 30 * sin(Double(i) / 4)) }
        let path = InkGeometry.path(pts)
        XCTAssertEqual(path.currentPoint, pts[pts.count - 1])
        var hull = CGRect.null
        for p in pts { hull = hull.union(CGRect(x: p.x, y: p.y, width: 0, height: 0)) }
        XCTAssertTrue(hull.insetBy(dx: -0.001, dy: -0.001).contains(path.boundingBoxOfPath))
    }

    func testThinningKeepsTheEndsAndSpacesTheRest() {
        // 120 Hz samples half a point apart
        let pts = (0...100).map { CGPoint(x: Double($0) * 0.5, y: 0) }
        let thin = InkGeometry.thin(pts, minDistance: 2)
        XCTAssertEqual(thin.first, pts.first)
        XCTAssertEqual(thin.last, pts.last)
        XCTAssertEqual(thin.count, 26)
        for (a, b) in zip(thin, thin.dropFirst()) {
            XCTAssertGreaterThanOrEqual(StrokeMatch.dist(a, b), 2 - 1e-9)
        }
        // a sample just short of the end gives way to the end itself
        let short = [CGPoint(x: 0, y: 0), CGPoint(x: 5, y: 0), CGPoint(x: 5.5, y: 0)]
        XCTAssertEqual(InkGeometry.thin(short, minDistance: 2), [CGPoint(x: 0, y: 0), CGPoint(x: 5.5, y: 0)])
        XCTAssertEqual(InkGeometry.thin(Array(pts.prefix(2)), minDistance: 2), Array(pts.prefix(2)))
    }

    /// Ink sampled densely (every coalesced touch, with a little finger tremor), then thinned as
    /// the box does, is judged as the web judges its one-sample-a-frame strokes.
    func testDenseTremblingSamplesStillMatch() throws {
        let box = GlyphSpace(size: 300)
        for ch in ["你", "好", "我", "是"] {
            let c = try XCTUnwrap(data.chars[ch])
            for i in 0..<c.count {
                let view = c.median(i).map(box.toView)
                var dense: [CGPoint] = []
                for (a, b) in zip(view, view.dropFirst()) {
                    let n = max(1, Int(StrokeMatch.dist(a, b) / 0.5))
                    for k in 0..<n {
                        let t = CGFloat(k) / CGFloat(n)
                        let j: CGFloat = dense.count % 2 == 0 ? 0.4 : -0.4
                        dense.append(CGPoint(x: a.x + (b.x - a.x) * t + j, y: a.y + (b.y - a.y) * t - j))
                    }
                }
                dense.append(view[view.count - 1])
                let glyph = InkGeometry.thin(dense, minDistance: 2).map(box.toGlyph)
                XCTAssertTrue(StrokeMatch.matches(glyph, char: c, stroke: i, leniency: StrokeMatch.leniency, outlineVisible: true), "\(ch) stroke \(i)")
            }
        }
    }

    /// HanziWriter's tolerance at the web's leniency: near the stroke is right, elsewhere isn't.
    func testToleranceIsTheWebs() throws {
        XCTAssertEqual(StrokeMatch.leniency, 1.4)
        let c = try XCTUnwrap(data.chars["一"])
        let m = c.median(0)
        func shifted(_ dy: CGFloat) -> [CGPoint] { m.map { CGPoint(x: $0.x, y: $0.y + dy) } }
        // 80 units (8% of the box) off: still the stroke
        XCTAssertTrue(StrokeMatch.matches(shifted(80), char: c, stroke: 0, leniency: StrokeMatch.leniency, outlineVisible: false))
        // 400 units off: its ends are further than 250 × 1.4 from the stroke's
        XCTAssertFalse(StrokeMatch.matches(shifted(400), char: c, stroke: 0, leniency: StrokeMatch.leniency, outlineVisible: false))
    }
}
