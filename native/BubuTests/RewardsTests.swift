import XCTest
@testable import Bubu

final class RewardsTests: XCTestCase {
    private let noon = 1_791_201_600_000.0            // 2026-10-05 12:00 UTC
    private let dayMs = 86_400_000.0

    private func make(at t: Double) -> (ProgressStore, (Double) -> Void) {
        var now = t
        let p = ProgressStore(course: Course.shared, url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json"))
        p.now = { now }
        return (p, { now = $0 })
    }

    func testLevelsFollowTheWebCurve() {
        let (p, _) = make(at: noon)
        XCTAssertEqual(p.level.level, 1)
        p.earnXP(80)                               // 80 + the 15 goal bonus = 95
        XCTAssertEqual(p.level.level, 1)
        p.earnXP(5)                                // 100 reaches level 2
        XCTAssertEqual(p.level.level, 2)
        XCTAssertEqual(p.level.next, 300 - p.xpTotal)
    }

    func testGoalBonusOncePerDay() {
        let (p, _) = make(at: noon)
        let a = p.earnXP(19)
        XCTAssertFalse(a.goalReached)
        let b = p.earnXP(2)
        XCTAssertTrue(b.goalReached)
        XCTAssertEqual(p.xpToday, 36)             // 21 + 15
        XCTAssertFalse(p.earnXP(2).goalReached)
    }

    func testThreeDayStreakEarnsAnEmber() {
        let (p, setNow) = make(at: noon)
        XCTAssertEqual(p.embers, 1)
        for d in 0..<3 {
            setNow(noon + Double(d) * dayMs)
            let f = p.lightFire()
            XCTAssertNotNil(f)
            if d == 2 { XCTAssertEqual(f?.streak, 3); XCTAssertTrue(f?.ember ?? false); XCTAssertTrue(f?.milestone ?? false) }
        }
        XCTAssertEqual(p.embers, 2)
        XCTAssertNil(p.lightFire())               // already lit today
    }

    func testAMissedDayCanBeRelit() {
        let (p, setNow) = make(at: noon)
        setNow(noon); p.lightFire()
        setNow(noon + dayMs); p.lightFire()
        // skip a day, come back the day after
        setNow(noon + 3 * dayMs)
        let out = try? XCTUnwrap(p.outSince)
        XCTAssertEqual(out?.lost, 2)
        XCTAssertEqual(p.streak, 0)
        XCTAssertTrue(p.relight())
        XCTAssertEqual(p.embers, 0)
        XCTAssertEqual(p.streak, 3)               // the relit day joins the run
        XCTAssertNil(p.outSince)
        XCTAssertFalse(p.relight())
    }

    func testAllThreeQuestsOpenTheChest() {
        let (p, _) = make(at: noon)
        let before = p.xpTotal
        // meet every quest target there is
        for _ in 0..<12 { p.questEvent("listen", correct: true) }
        for k in ["write", "speak", "sentence"] { for _ in 0..<5 { p.questEvent(k, correct: true) } }
        for _ in 0..<3 { p.questEvent("session", correct: true, lesson: true, perfect: true) }
        for _ in 0..<30 { p.recordReview() }
        p.earnXP(60)
        XCTAssertTrue(p.chestOpened)
        XCTAssertTrue(p.todayQuests.allSatisfy(p.questDone))
        XCTAssertEqual(p.activity.chests, 1)
        XCTAssertGreaterThanOrEqual(p.xpTotal - before, 60 + 15 + 20)
    }

    func testTheWholeActivityRecordSurvivesABackup() throws {
        let (a, setNow) = make(at: noon)
        for d in 0..<3 { setNow(noon + Double(d) * dayMs); a.lightFire() }
        a.earnXP(40)
        XCTAssertTrue(a.markRead("story-1"))
        let (b, _) = make(at: noon)
        XCTAssertTrue(Backup.restore(Backup.export(a), into: b))
        XCTAssertEqual(b.activity, a.activity)
        XCTAssertTrue(b.readDone("story-1"))
    }

    /// Loading must never save part-way: once it wrote an empty activity record over
    /// the streak whenever your settings differed from the defaults.
    func testReopeningKeepsEverything() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let a = ProgressStore(course: Course.shared, url: url)
        a.prefs.dailyGoal = 30
        a.lightFire()
        a.earnXP(12)
        a.save()
        for _ in 0..<2 {
            let b = ProgressStore(course: Course.shared, url: url)
            XCTAssertEqual(b.prefs.dailyGoal, 30)
            XCTAssertEqual(b.xpToday, 12)
            XCTAssertEqual(b.streak, 1)
        }
    }
}
