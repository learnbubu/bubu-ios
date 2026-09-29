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

    // MARK: guidance by how often a character has been written

    private func store(_ url: URL? = nil) -> ProgressStore {
        ProgressStore(course: Course.shared, url: url ?? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json"))
    }

    func testGuidanceLevelsByTimesWritten() {
        XCTAssertEqual(WriteGuidance(timesWritten: 0), .full)
        XCTAssertEqual(WriteGuidance(timesWritten: 1), .outline)
        XCTAssertEqual(WriteGuidance(timesWritten: 2), .memory)
        XCTAssertEqual(WriteGuidance(timesWritten: 9), .memory)
        // the strokes play and the outline shows only while it's new
        XCTAssertTrue(WriteGuidance.full.playsDemo)
        XCTAssertFalse(WriteGuidance.outline.playsDemo)
        XCTAssertFalse(WriteGuidance.memory.playsDemo)
        XCTAssertTrue(WriteGuidance.full.showsOutline)
        XCTAssertTrue(WriteGuidance.outline.showsOutline)
        XCTAssertFalse(WriteGuidance.memory.showsOutline)
    }

    /// First time: the next stroke is lit up from the start. Second: after one miss on it.
    /// From the third: after two misses, with the trace.
    func testHighlightAppearsAfterTheRightNumberOfMisses() {
        XCTAssertTrue(WriteGuidance.full.highlights(misses: 0))
        XCTAssertFalse(WriteGuidance.full.traces(misses: 0))
        XCTAssertTrue(WriteGuidance.full.traces(misses: 1))

        XCTAssertFalse(WriteGuidance.outline.highlights(misses: 0))
        XCTAssertTrue(WriteGuidance.outline.highlights(misses: 1))
        XCTAssertFalse(WriteGuidance.outline.traces(misses: 1))
        XCTAssertTrue(WriteGuidance.outline.traces(misses: 2))

        XCTAssertFalse(WriteGuidance.memory.highlights(misses: 0))
        XCTAssertFalse(WriteGuidance.memory.highlights(misses: 1))
        XCTAssertFalse(WriteGuidance.memory.traces(misses: 1))
        XCTAssertTrue(WriteGuidance.memory.highlights(misses: 2))
        XCTAssertTrue(WriteGuidance.memory.traces(misses: 2))
    }

    func testTimesWrittenAreCountedAndKept() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let p = store(url)
        XCTAssertEqual(p.timesWritten("你"), 0)
        XCTAssertEqual(p.guidance(for: "你"), .full)
        p.recordWritten("你")
        XCTAssertEqual(p.guidance(for: "你"), .outline)
        p.recordWritten("你")
        XCTAssertEqual(p.guidance(for: "你"), .memory)
        // saved: a fresh store from the same file has them
        let again = store(url)
        XCTAssertEqual(again.timesWritten("你"), 2)
        XCTAssertEqual(again.guidance(for: "你"), .memory)
        XCTAssertEqual(again.timesWritten("好"), 0)
        // and they go with a backup
        let other = store()
        XCTAssertTrue(Backup.restore(Backup.export(again), into: other))
        XCTAssertEqual(other.timesWritten("你"), 2)
        // starting again forgets them
        again.resetProgress()
        XCTAssertEqual(again.timesWritten("你"), 0)
    }

    /// The exercise's prompt follows the word's least-written character.
    func testWriteExercisePromptFollowsTheLeastWrittenCharacter() throws {
        let p = store()
        let card = try XCTUnwrap(Course.shared.cards.first { $0.word.hanzi == "你好" })
        func stage() -> WriteGuidance? {
            Exercise.make(card: card, dir: "write", scope: [], progress: p).flatMap { WriteGuidance(rawValue: $0.writeStage) }
        }
        XCTAssertEqual(stage(), .full)
        p.recordWritten("你")
        XCTAssertEqual(stage(), .full)          // 好 is still new
        p.recordWritten("好")
        XCTAssertEqual(stage(), .outline)
        p.recordWritten("你"); p.recordWritten("好")
        XCTAssertEqual(stage(), .memory)
        XCTAssertEqual(Exercise.make(card: card, dir: "write", scope: [], progress: p)?.label, "Write it from memory")
    }

    /// Two devices: each character keeps the most times either has written it.
    func testTimesWrittenMergeAcrossDevices() {
        let A = CloudMerge.activityKey
        let local: [String: Any] = [A: CloudMerge.text(["written": ["你": 2, "我": 1]])]
        let remote: [String: Any] = [A: CloudMerge.text(["written": ["你": 1, "好": 3]])]
        let m = CloudMerge.merge(local: local, remote: remote)
        let a = m[A].flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) } as? [String: Any]
        XCTAssertEqual(a?["written"] as? [String: Int], ["你": 2, "我": 1, "好": 3])
        // neither side has any: nothing added
        let none = CloudMerge.merge(local: [:], remote: [:])
        let b = none[A].flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) } as? [String: Any]
        XCTAssertNil(b?["written"])
    }

    // MARK: the brush

    /// Samples along a line at a steady speed (pt/s), 240 a second.
    private func samples(from a: CGPoint, to b: CGPoint, speed: CGFloat, force: CGFloat? = nil) -> [InkGeometry.Sample] {
        let len = InkGeometry.gap(a, b)
        let step = speed / 240
        let n = max(1, Int(len / step))
        return (0...n).map { (k: Int) -> InkGeometry.Sample in
            let t = CGFloat(k) / CGFloat(n)
            return InkGeometry.Sample(point: CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t),
                                      time: Double(k) / 240, force: force)
        }
    }

    func testBrushWidthStaysInRangeAndFollowsSpeed() throws {
        let b = InkGeometry.Brush.standard
        XCTAssertEqual(b.minWidth, 5)
        XCTAssertEqual(b.maxWidth, 11)
        let slow = InkGeometry.widths(samples(from: .zero, to: CGPoint(x: 40, y: 0), speed: 50), brush: b)
        let fast = InkGeometry.widths(samples(from: .zero, to: CGPoint(x: 1500, y: 0), speed: 3000), brush: b)
        for w in slow + fast {
            XCTAssertGreaterThanOrEqual(w, b.minWidth)
            XCTAssertLessThanOrEqual(w, b.maxWidth)
        }
        // slower is thicker
        XCTAssertEqual(try XCTUnwrap(slow.last), b.maxWidth, accuracy: 0.2)
        XCTAssertEqual(try XCTUnwrap(fast.last), b.minWidth, accuracy: 0.2)
        // pressure, where a touch reports it, sets the width instead
        let hard = InkGeometry.widths(samples(from: .zero, to: CGPoint(x: 1500, y: 0), speed: 3000, force: 1), brush: b)
        XCTAssertEqual(try XCTUnwrap(hard.last), b.maxWidth, accuracy: 0.2)
    }

    /// A jittery speed doesn't make the width flicker: it moves a little each sample.
    func testBrushWidthIsLowPassFiltered() {
        let b = InkGeometry.Brush.standard
        var s: [InkGeometry.Sample] = []
        var x: CGFloat = 0
        for k in 0..<200 {
            s.append(InkGeometry.Sample(point: CGPoint(x: x, y: 0), time: Double(k) / 240))
            x += k % 2 == 0 ? 100.0 / 240 : 1500.0 / 240
        }
        let w = InkGeometry.widths(s, brush: b)
        for (a, c) in zip(w, w.dropFirst()) { XCTAssertLessThan(abs(c - a), 0.5) }
    }

    func testBrushTapersAtBothEnds() throws {
        let b = InkGeometry.Brush.standard
        let lengths = (0...100).map { CGFloat($0) }
        let even = [CGFloat](repeating: 10, count: lengths.count)
        let lifted = InkGeometry.taper(even, lengths: lengths, brush: b, lifted: true)
        XCTAssertEqual(lifted[0], 10 * b.startTaperFrom, accuracy: 1e-6)
        XCTAssertEqual(lifted[50], 10, accuracy: 1e-6)
        XCTAssertEqual(lifted[100], 10 * b.endTaperTo, accuracy: 1e-6)
        XCTAssertEqual(b.endTaperTo, 0.35)
        // the lift narrows steadily over its last 12 points
        for i in 88..<100 { XCTAssertGreaterThanOrEqual(lifted[i], lifted[i + 1]) }
        XCTAssertEqual(lifted[88], 10, accuracy: 1e-6)
        // while the finger is still down, the end isn't tapered
        let down = InkGeometry.taper(even, lengths: lengths, brush: b, lifted: false)
        XCTAssertEqual(down[100], 10, accuracy: 1e-6)
        // and through the whole brush: the lifted end is 35% of the same line still down
        let line = samples(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 150, y: 60), speed: 500)
        let up = InkGeometry.brushLine(line, brush: b, lifted: true).widths
        let held = InkGeometry.brushLine(line, brush: b, lifted: false).widths
        XCTAssertEqual(try XCTUnwrap(up.last), try XCTUnwrap(held.last) * b.endTaperTo, accuracy: 1e-6)
        XCTAssertLessThan(try XCTUnwrap(up.first), try XCTUnwrap(up[up.count / 2]))
    }

    private func crosses(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint) -> Bool {
        func orient(_ p: CGPoint, _ q: CGPoint, _ r: CGPoint) -> CGFloat { (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x) }
        let d1 = orient(c, d, a), d2 = orient(c, d, b), d3 = orient(a, b, c), d4 = orient(a, b, d)
        return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) && ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))
    }

    private func signedArea(_ poly: [CGPoint]) -> CGFloat {
        var s: CGFloat = 0
        for i in poly.indices {
            let p = poly[i], q = poly[(i + 1) % poly.count]
            s += p.x * q.y - q.x * p.y
        }
        return s / 2
    }

    /// A simple curve (a quarter circle, speeding up and slowing down) gives an outline that never crosses itself.
    func testBrushOutlineOfASimpleCurveDoesNotCrossItself() {
        var s: [InkGeometry.Sample] = []
        var time = 0.0
        for k in 0...120 {
            let a = Double.pi / 2 * Double(k) / 120
            s.append(InkGeometry.Sample(point: CGPoint(x: 200 - 120 * cos(a), y: 40 + 120 * sin(a)), time: time))
            time += 1.0 / 240 * (1 + 2 * abs(sin(Double(k) / 12)))
        }
        for lifted in [false, true] {
            let line = InkGeometry.brushLine(s, brush: .standard, lifted: lifted)
            // no corner tight enough to need a dab
            XCTAssertTrue(InkGeometry.joints(line.points, line.widths).isEmpty)
            let poly = InkGeometry.outline(line.points, line.widths)
            XCTAssertGreaterThan(poly.count, 20)
            let n = poly.count
            var crossing = 0
            for i in 0..<n {
                for j in stride(from: i + 2, to: n, by: 1) where !(i == 0 && j == n - 1) {
                    if crosses(poly[i], poly[(i + 1) % n], poly[j], poly[(j + 1) % n]) { crossing += 1 }
                }
            }
            XCTAssertEqual(crossing, 0, "lifted: \(lifted)")
        }
    }

    /// The outline and any corner dabs wind the same way, so a non-zero fill adds them up.
    func testBrushPiecesWindTheSameWay() {
        let line = samples(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 100, y: 30), speed: 400)
        let out = InkGeometry.brushLine(line, brush: .standard, lifted: true)
        let outlineArea = signedArea(InkGeometry.outline(out.points, out.widths))
        let discArea = signedArea(InkGeometry.disc(.zero, radius: 5))
        XCTAssertNotEqual(outlineArea, 0)
        XCTAssertEqual(outlineArea > 0, discArea > 0)
        // a sharp corner gets a dab
        var corner = samples(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 60, y: 0), speed: 300)
        let back = samples(from: CGPoint(x: 60, y: 0), to: CGPoint(x: 60, y: 60), speed: 300)
        let t0 = corner.last?.time ?? 0
        corner += back.dropFirst().map { InkGeometry.Sample(point: $0.point, time: $0.time + t0) }
        XCTAssertGreaterThan(InkGeometry.brushPolygons(corner, brush: .standard, lifted: true).count, 1)
    }

    /// One or two samples still give a sensible shape: a round dab, or a short capsule.
    func testBrushWithOneOrTwoSamples() {
        let b = InkGeometry.Brush.standard
        XCTAssertTrue(InkGeometry.brushPolygons([], brush: b, lifted: true).isEmpty)
        let p = CGPoint(x: 50, y: 50)
        let one = InkGeometry.brushPolygons([.init(point: p, time: 0)], brush: b, lifted: true)
        XCTAssertEqual(one.count, 1)
        for q in one[0] {
            XCTAssertTrue(q.x.isFinite && q.y.isFinite)
            XCTAssertLessThanOrEqual(InkGeometry.gap(p, q), b.maxWidth / 2 + 1e-6)
        }
        // the same point twice is still a dab
        let same = InkGeometry.brushPolygons([.init(point: p, time: 0), .init(point: p, time: 0.01)], brush: b, lifted: true)
        XCTAssertEqual(same.count, 1)
        XCTAssertFalse(same[0].isEmpty)
        // two points: a short capsule around them
        let q = CGPoint(x: 60, y: 54)
        for lifted in [false, true] {
            let two = InkGeometry.brushPolygons([.init(point: p, time: 0), .init(point: q, time: 0.008)], brush: b, lifted: lifted)
            XCTAssertEqual(two.count, 1)
            XCTAssertGreaterThan(two[0].count, 4)
            for r in two[0] { XCTAssertTrue(r.x.isFinite && r.y.isFinite) }
            let box = InkGeometry.brushPath([.init(point: p, time: 0), .init(point: q, time: 0.008)], brush: b, lifted: lifted).boundingBoxOfPath
            XCTAssertTrue(box.insetBy(dx: -0.01, dy: -0.01).contains(p))
            XCTAssertTrue(box.insetBy(dx: -0.01, dy: -0.01).contains(q))
        }
    }

    func testBrushScalesWithTheBox() {
        let small = InkGeometry.Brush.forBox(170)
        XCTAssertEqual(small.minWidth, 2.5, accuracy: 1e-6)
        XCTAssertEqual(small.maxWidth, 5.5, accuracy: 1e-6)
        XCTAssertEqual(InkGeometry.Brush.forBox(340), InkGeometry.Brush.standard)
    }

    /// Where a stroke's direction arrow goes: a distance along its centre line, and which way it runs there.
    func testPointAlongAStrokesCentreLine() throws {
        let l = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0), CGPoint(x: 10, y: 20)]
        let a = try XCTUnwrap(InkGeometry.along(l, distance: 5))
        XCTAssertEqual(a.point, CGPoint(x: 5, y: 0))
        XCTAssertEqual(a.direction, CGPoint(x: 1, y: 0))
        let b = try XCTUnwrap(InkGeometry.along(l, distance: 15))
        XCTAssertEqual(b.point, CGPoint(x: 10, y: 5))
        XCTAssertEqual(b.direction, CGPoint(x: 0, y: 1))
        // past the end: the end
        XCTAssertEqual(InkGeometry.along(l, distance: 100)?.point, CGPoint(x: 10, y: 20))
        XCTAssertNil(InkGeometry.along([CGPoint(x: 1, y: 1)], distance: 3))
    }

    /// Every character's first stroke has a centre line to hang the start dot and arrow on.
    func testEveryStrokeHasAStartAndADirection() throws {
        for ch in ["你", "好", "我", "是", "一"] {
            let c = try XCTUnwrap(data.chars[ch])
            let box = GlyphSpace(size: 340)
            for i in 0..<c.count {
                let m = c.median(i).map(box.toView)
                XCTAssertNotNil(InkGeometry.along(m, distance: 20), "\(ch) stroke \(i)")
            }
        }
    }

    func testDemoPacing() {
        // about half a second a stroke, and the pause after
        XCTAssertEqual(GlyphAnimation.duration(strokes: 7), 7 * 0.65 + 0.6, accuracy: 1e-9)
    }
}
