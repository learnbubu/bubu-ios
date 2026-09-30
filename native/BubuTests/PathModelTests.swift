import XCTest
@testable import Bubu

/// The learning path's layout: built once, quickly, and drawn only near the screen.
final class PathModelTests: XCTestCase {
    let course = Course.shared
    let W: CGFloat = 393, H: CGFloat = 852          // an iPhone 15/16's points

    private func ms(_ block: () -> Void) -> Double {
        let t0 = CFAbsoluteTimeGetCurrent(); block(); return (CFAbsoluteTimeGetCurrent() - t0) * 1000
    }

    func testEveryStoneIsLaidOutInOrder() {
        let m = PathModel(course: course, width: W, current: course.lessons[3].id)
        XCTAssertEqual(m.items.count, course.lessons.count)
        XCTAssertEqual(m.xs.count, m.items.count)
        for (a, b) in zip(m.items, m.items.dropFirst()) { XCTAssertLessThan(a.y, b.y) }
        XCTAssertEqual(m.currentY, m.items[3].y)
        XCTAssertEqual(m.bannerMids.count, course.chapters.count)
        XCTAssertEqual(m.pieces.count, course.data.pathLayout.pieces.count)
        XCTAssertFalse(m.pebbles.isEmpty)
        XCTAssertGreaterThan(m.height, m.items.last!.y)
    }

    /// The layout the JIC edition had: pandas and landmarks whole on the screen, and the temple
    /// beside the first stones, not up under chapter 1's title (docs/reference/jic).
    func testSceneryKeepsClearOfTheEdgesAndTheFirstTitle() {
        for width in [375, 393, 402, 430] as [CGFloat] {
            let m = PathModel(course: course, width: width, current: course.lessons[0].id)
            for p in m.pieces where course.data.art[p.art]?.side == "any" {
                XCTAssertGreaterThanOrEqual(p.x - p.w / 2, -0.5, "\(p.art) off the left at \(width)")
                XCTAssertLessThanOrEqual(p.x + p.w / 2, width + 0.5, "\(p.art) off the right at \(width)")
            }
            let temple = try! XCTUnwrap(m.pieces.first { $0.art == "cluster-right-temple" })
            let titleBottom = m.bannerMids[0]! + PathModel.bannerH / 2
            XCTAssertGreaterThan(temple.y - temple.h / 2, titleBottom - 30, "the temple reaches up over chapter 1's title at \(width)")
        }
    }

    /// A header and the pebble trail agree on its side, so no pebbles run through its text.
    func testHeadersKeepTheirSideForTheTrailToo() {
        let m = PathModel(course: course, width: W, current: nil)
        XCTAssertEqual(m.bannerRight.count, course.chapters.count)
        for it in m.items where it.chapter != nil {
            XCTAssertEqual(m.bannerRight[it.index], PathModel.bannerOnRight(it, course: course, xs: m.xs, W: W))
        }
    }

    func testTheWaveMatchesTheOldFormula() {
        // the old per-call loop over one period, kept here as the reference
        func old(_ i: Int) -> CGFloat {
            var k: CGFloat = 0
            for j in 0..<8 { k = max(k, abs(sin(CGFloat(j) * 2 * .pi / 8))) }
            let half = PathModel.size / 2 + 8
            return max(half, min(W - half, W / 2 + PathModel.wave * sin((CGFloat(i) + PathModel.phase) * 2 * .pi / 8) / k))
        }
        for i in 0..<40 { XCTAssertEqual(PathModel.nodeX(i, W, count: 64), old(i), accuracy: 1e-9) }
    }

    /// What the old path redid on every render (layout, pebble trail, scenery), now done once.
    func testTheModelBuildsQuickly() {
        let cur = course.lessons[100].id
        _ = PathModel(course: course, width: W, current: cur)       // warm up
        let times = (0..<5).map { _ in ms { _ = PathModel(course: course, width: W, current: cur) } }
        let best = times.min()!
        print("PERF path model build: best \(String(format: "%.1f", best)) ms of \(times.map { String(format: "%.1f", $0) })")
        XCTAssertLessThan(best, 150, "the path's layout should take well under a frame budget's worth of work")
    }

    func testTheCacheBuildsOncePerWidthAndLesson() {
        let cache = PathModel.Cache()
        let a = course.lessons[0].id, b = course.lessons[1].id
        _ = cache.model(course, width: W, current: a)
        var hit = 0.0
        for _ in 0..<10 { hit += ms { _ = cache.model(course, width: W, current: a) } }
        print("PERF path model cached lookup: \(String(format: "%.3f", hit / 10)) ms")
        XCTAssertEqual(cache.builds, 1)
        _ = cache.model(course, width: W, current: b)
        XCTAssertEqual(cache.builds, 2)
        _ = cache.model(course, width: 430, current: b)
        XCTAssertEqual(cache.builds, 3)
    }

    /// Only a few screens' worth of the ~365 stones are drawn at a time, and every
    /// stone on screen is among them.
    func testOnlyTheStretchNearTheScreenIsDrawn() {
        let m = PathModel(course: course, width: W, current: course.lessons[200].id)
        let everything = m.items.count + m.pebbles.count + m.pieces.count + m.bannerMids.count
        for offset in stride(from: CGFloat(0), through: m.height - H, by: 173) {
            let win = PathModel.window(band: PathModel.band(for: offset), viewport: H)
            let drawn = m.items(in: win)
            for it in m.items where it.y >= offset && it.y <= offset + H {
                XCTAssertTrue(drawn.contains { $0.index == it.index }, "stone \(it.index) is on screen at \(offset)")
            }
            XCTAssertLessThan(drawn.count, 40)
        }
        let win = PathModel.window(band: m.landingBand(viewport: H), viewport: H)
        XCTAssertTrue(m.items(in: win).contains { $0.lesson.id == course.lessons[200].id })
        let drawn = m.items(in: win).count + m.pebbles(in: win).count + m.pieces(in: win, behind: true).count
            + m.pieces(in: win, behind: false).count
        print("PERF path pieces drawn near the current stone: \(drawn) of \(everything)")
    }

    func testScenerySpanningTheScreenIsDrawn() {
        let m = PathModel(course: course, width: W, current: course.lessons[0].id)
        let win = PathModel.window(band: 0, viewport: H)
        let visible = m.pieces.filter { $0.y + $0.h / 2 >= 0 && $0.y - $0.h / 2 <= H }
        let drawn = m.pieces(in: win, behind: true) + m.pieces(in: win, behind: false)
        for p in visible { XCTAssertTrue(drawn.contains { $0.id == p.id }, p.art) }
    }
}
