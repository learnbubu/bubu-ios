import XCTest
@testable import Bubu

/// The done screen's sticker moments: which one a session gets.
final class MomentTests: XCTestCase {
    private func pick(_ change: (inout ResultMoment.Facts) -> Void) -> String? {
        var f = ResultMoment.Facts(mode: .lesson, answered: 12, accuracy: 75, perfect: false, seconds: 300, bestRun: 4, hour: 14)
        change(&f)
        return ResultMoment.pick(f)?.key
    }

    func testAnOrdinarySessionGetsNone() {
        XCTAssertNil(pick { _ in })
    }

    func testTooShortOrTheSkipTestGetsNone() {
        XCTAssertNil(pick { $0.answered = 3; $0.perfect = true })
        XCTAssertNil(pick { $0.mode = .placement; $0.perfect = true })
    }

    func testEachMoment() {
        XCTAssertEqual(pick { $0.perfect = true; $0.accuracy = 100 }, "flawless")
        XCTAssertEqual(pick { $0.bestRun = 15 }, "kungfu")
        XCTAssertEqual(pick { $0.seconds = 95; $0.accuracy = 90 }, "speedy")
        XCTAssertEqual(pick { $0.learned = 5 }, "brain")
        XCTAssertEqual(pick { $0.hour = 23 }, "nightowl")
        XCTAssertEqual(pick { $0.hour = 2 }, "nightowl")
        XCTAssertEqual(pick { $0.hour = 6 }, "earlybird")
        XCTAssertEqual(pick { $0.mode = .mistakes; $0.fixed = 3; $0.accuracy = 90 }, "sweep")
        XCTAssertEqual(pick { $0.milestone = true; $0.streak = 7 }, "onfire")
    }

    func testTheRarestWins() {
        // a streak milestone over a perfect lesson; every mistake fixed over every answer right
        XCTAssertEqual(pick { $0.milestone = true; $0.streak = 30; $0.perfect = true }, "onfire")
        XCTAssertEqual(pick { $0.mode = .mistakes; $0.fixed = 4; $0.perfect = true; $0.accuracy = 100 }, "sweep")
        // a perfect lesson at night is flawless; a long run beats being quick
        XCTAssertEqual(pick { $0.perfect = true; $0.hour = 23 }, "flawless")
        XCTAssertEqual(pick { $0.bestRun = 16; $0.seconds = 80; $0.accuracy = 95 }, "kungfu")
    }

    func testSlowOrSloppyIsntSpeedy() {
        XCTAssertNil(pick { $0.seconds = 130; $0.accuracy = 90 })
        XCTAssertNil(pick { $0.seconds = 90; $0.accuracy = 60 })
    }

    func testLines() {
        var f = ResultMoment.Facts(mode: .lesson, answered: 20, accuracy: 90, bestRun: 17, hour: 14)
        XCTAssertEqual(ResultMoment.pick(f)?.line, "17 in a row. Unstoppable.")
        f = ResultMoment.Facts(mode: .mistakes, answered: 8, accuracy: 100, mistakes: 0, fixed: 6, hour: 14)
        XCTAssertEqual(ResultMoment.pick(f)?.line, "Every mistake fixed.")
        f = ResultMoment.Facts(mode: .lesson, answered: 8, streak: 14, milestone: true)
        XCTAssertEqual(ResultMoment.pick(f)?.line, "A 14 day streak!")
    }

    /// The moment player's page is in the app, and knows every moment.
    func testThePlayerIsBundled() throws {
        let url = try XCTUnwrap(Bundle(for: MomentPlayer.self).url(forResource: "moments-player", withExtension: "html")
                                ?? Bundle.main.url(forResource: "moments-player", withExtension: "html"))
        let page = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(page.contains("window.BUBU_PLAYER="))
        for k in ["speedy", "flawless", "kungfu", "sweep", "nightowl", "earlybird", "brain", "onfire", "spare"] { XCTAssertTrue(page.contains("\"\(k)\""), k) }
    }
}
