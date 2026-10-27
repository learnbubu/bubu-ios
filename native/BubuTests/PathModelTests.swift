import XCTest
import UIKit
import CoreText
@testable import Bubu

/// The learning path's layout: built once, quickly, and drawn only near the screen.
final class PathModelTests: XCTestCase {
    let course = Course.shared
    let W: CGFloat = 393, H: CGFloat = 852          // an iPhone 15/16's points

    private func ms(_ block: () -> Void) -> Double {
        let t0 = CFAbsoluteTimeGetCurrent(); block(); return (CFAbsoluteTimeGetCurrent() - t0) * 1000
    }

    /// The stones' storybook lettering is in the app under the name the path asks for, with every stone's character
    /// (a wrong name or a missing character falls back to the system font without a word).
    func testTheStoneLetteringHasEveryStonesCharacter() throws {
        let font = try XCTUnwrap(UIFont(name: "ZCOOLKuaiLe-Regular", size: 20), "the stone font isn't installed under that name")
        let ct = font as CTFont
        let missing = Set(course.lessons.compactMap { course.hero[$0.id] }.joined()).filter { ch in
            var glyphs = [CGGlyph](repeating: 0, count: 2)
            let units = Array(String(ch).utf16)
            return !CTFontGetGlyphsForCharacters(ct, units, &glyphs, units.count)
        }
        XCTAssertTrue(missing.isEmpty, "not in the stone font: \(String(missing))")
    }

    func testEveryStoneIsLaidOutInOrder() {
        let m = PathModel(course: course, width: W, current: course.lessons[3].id)
        XCTAssertEqual(m.items.count, course.lessons.count)
        XCTAssertEqual(m.xs.count, m.items.count)
        for (a, b) in zip(m.items, m.items.dropFirst()) { XCTAssertLessThan(a.y, b.y) }
        XCTAssertEqual(m.currentY, m.items[3].y)
        // a divider before every chapter but the first
        XCTAssertEqual(m.dividers.count, m.items.filter { $0.chapter != nil }.count - 1)
        // every composed piece of the kinds the path shows (Bùbù, hanging pieces), then the scenery it planted itself
        let composed = course.data.pathLayout.pieces.count
        let shown = course.data.pathLayout.pieces.filter { p in PathModel.sceneryKinds.contains { p.art.hasPrefix($0) } }.count
        XCTAssertEqual(m.pieces.filter { $0.id < composed }.count, shown)
        XCTAssertGreaterThanOrEqual(m.pieces.count, shown)
        XCTAssertFalse(m.pebbles.isEmpty)
        XCTAssertGreaterThan(m.height, m.items.last!.y)
    }

    /// Every chapter starts and ends in the middle of the page (its wave eased in and out, as Duolingo's units
    /// wind in at their ends), and swings full out in between.
    func testEachChapterStartsAndEndsInTheMiddle() {
        let m = PathModel(course: course, width: W, current: nil)
        for ci in Set(m.items.map(\.ci)) {
            let ch = m.items.filter { $0.ci == ci }
            guard ch.count >= 3 else { continue }
            XCTAssertEqual(m.xs[ch.first!.index], W / 2, accuracy: 0.5, "chapter \(ci) starts off the middle")
            XCTAssertEqual(m.xs[ch.last!.index], W / 2, accuracy: 0.5, "chapter \(ci) ends off the middle")
            if ch.count >= 6 {
                let out = ch.map { abs(m.xs[$0.index] - W / 2) }.max()!
                XCTAssertEqual(out, PathModel.wave, accuracy: 0.5, "chapter \(ci) never swings full out")
            }
        }
    }

    /// The chapter pinned at the top is the one scrolled into: the first at the top, then each in turn once
    /// its divider has gone up under the pinned bar.
    func testThePinnedChapterFollowsTheScroll() {
        let m = PathModel(course: course, width: W, current: nil)
        XCTAssertEqual(m.chapter(atScroll: 0), m.items.first!.ci)
        for t in m.chapterTops.dropFirst().prefix(5) {
            let under = t.y - PathModel.hud - PathModel.pinH
            XCTAssertNotEqual(m.chapter(atScroll: under - 4), t.ci, "chapter \(t.ci) pinned before its divider got there")
            XCTAssertEqual(m.chapter(atScroll: under + 4), t.ci, "chapter \(t.ci) not pinned once its divider went under")
        }
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
        let everything = m.items.count + m.pebbles.count + m.pieces.count + m.dividers.count
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

    /// The path plants one thing at each bend, on its open side: Bùbù and the scenery taking turns (so both
    /// turn up on both sides), real art only, clear of the dividers, Bùbù whole on the screen, the same every build.
    func testThePathPlantsOneThingAtEachBend() throws {
        try XCTSkipUnless(PathModel.plantsBends, "planting at the bends is off while the scale is set by hand")
        let composed = course.data.pathLayout.pieces.count
        for width in [375, 393, 402, 430] as [CGFloat] {
            let m = PathModel(course: course, width: width, current: course.lessons[0].id)
            let generated = m.pieces.filter { $0.id >= composed }
            let bends = m.items.filter { PathModel.swing($0) > 0.99 && abs(abs(PathModel.lean($0)) - 1) < 1e-6 }
            XCTAssertGreaterThan(generated.count, bends.count / 2, "too little scenery at \(width)")
            XCTAssertEqual(Set(m.pieces.map(\.id)).count, m.pieces.count, "piece ids must be unique")
            var sides: [String: Set<Bool>] = ["panda": [], "scenery": []]
            for p in generated {
                XCTAssertNotNil(course.data.art[p.art] ?? NewArt.art[p.art], "\(p.art) isn't in the art table")
                // at a bend, on its open side (across from where the stones swing)
                let near = bends.filter { abs($0.y - p.y) < PathModel.gap * 1.6 }
                XCTAssertTrue(near.contains { (PathModel.lean($0) > 0) == (p.x < width / 2) }, "\(p.art) isn't at a bend's open side at \(width)")
                for (_, mid) in m.dividers {
                    XCTAssertFalse(p.y - p.h / 2 < mid + PathModel.divH / 2 && p.y + p.h / 2 > mid - PathModel.divH / 2 && p.art.hasPrefix("panda"),
                                   "\(p.art) over a divider at \(width)")
                }
                if p.art.hasPrefix("panda") {
                    XCTAssertGreaterThanOrEqual(p.x - p.w / 2, -0.5, "\(p.art) off the left at \(width)")
                    XCTAssertLessThanOrEqual(p.x + p.w / 2, width + 0.5, "\(p.art) off the right at \(width)")
                }
                sides[p.art.hasPrefix("panda") ? "panda" : "scenery"]!.insert(p.x < width / 2)
            }
            XCTAssertEqual(sides["panda"], [true, false], "Bùbù only on one side at \(width)")
            XCTAssertEqual(sides["scenery"], [true, false], "scenery only on one side at \(width)")
            XCTAssertTrue(generated.contains { $0.art.hasPrefix("hang-") }, "no hanging pieces at \(width)")
            // only Bùbù and the hanging pieces, placed or planted
            for p in m.pieces { XCTAssertTrue(PathModel.sceneryKinds.contains { p.art.hasPrefix($0) }, "\(p.art) isn't Bùbù or a hanging piece") }
            XCTAssertGreaterThan(Set(generated.filter { $0.art.hasPrefix("panda") }.map(\.art)).count, 5, "too few of Bùbù's poses at \(width)")
            // stable between launches
            let again = PathModel(course: course, width: width, current: course.lessons[0].id)
            XCTAssertEqual(again.pieces.map(\.art), m.pieces.map(\.art))
            XCTAssertEqual(again.pieces.map(\.x), m.pieces.map(\.x))
            XCTAssertEqual(again.pieces.map(\.y), m.pieces.map(\.y))
        }
    }

    func testScenerySpanningTheScreenIsDrawn() {
        let m = PathModel(course: course, width: W, current: course.lessons[0].id)
        let win = PathModel.window(band: 0, viewport: H)
        let visible = m.pieces.filter { $0.y + $0.h / 2 >= 0 && $0.y - $0.h / 2 <= H }
        let drawn = m.pieces(in: win, behind: true) + m.pieces(in: win, behind: false)
        for p in visible { XCTAssertTrue(drawn.contains { $0.id == p.id }, p.art) }
    }
}
