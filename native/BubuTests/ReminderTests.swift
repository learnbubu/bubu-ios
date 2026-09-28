import XCTest
@testable import Bubu

/// The reminder plan: which days get reminders, what goes once the day is lit,
/// and when the streak-at-risk nudge is added.
final class ReminderTests: XCTestCase {
    private let noon = Date(timeIntervalSince1970: 1_791_201_600)    // 2026-10-05 12:00 UTC
    private let hour = 3600.0
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    private let on = ReminderPlan.Settings(on: true, minutes: 19 * 60, streakRisk: true)

    private func plan(_ s: ReminderPlan.Settings? = nil, now: Date? = nil, lit: Bool = false, streak: Int = 0) -> [ReminderPlan.Request] {
        ReminderPlan.requests(s ?? on, now: now ?? noon, calendar: cal, litToday: lit, streak: streak)
    }
    private func ids(_ r: [ReminderPlan.Request]) -> [String] { r.map(\.id) }

    func testOffMeansNothing() {
        XCTAssertTrue(plan(ReminderPlan.Settings(on: false, minutes: 1140, streakRisk: true), streak: 20).isEmpty)
    }

    func testAWeekOfDailyRemindersFromToday() {
        let r = plan()
        XCTAssertEqual(r.map(\.day), ["2026-10-05", "2026-10-06", "2026-10-07", "2026-10-08", "2026-10-09", "2026-10-10", "2026-10-11"])
        XCTAssertTrue(r.allSatisfy { $0.kind == .daily })
        XCTAssertEqual(r[0].id, "bubu.remind.daily.2026-10-05")
        XCTAssertEqual(r[0].fire, noon.addingTimeInterval(7 * hour))           // 19:00 today
        XCTAssertEqual(r[1].fire, noon.addingTimeInterval(31 * hour))          // 19:00 tomorrow
        XCTAssertEqual(Set(ids(r)).count, r.count)
    }

    func testChosenTimeIsUsed() {
        let r = plan(ReminderPlan.Settings(on: true, minutes: 8 * 60 + 15, streakRisk: true))
        // 08:15 has passed today, so the first is tomorrow's
        XCTAssertEqual(r.first?.day, "2026-10-06")
        XCTAssertEqual(r.first?.fire, noon.addingTimeInterval(20 * hour + 15 * 60))
        XCTAssertEqual(r.count, 6)
    }

    func testTimeAlreadyPassedTodaySkipsToday() {
        let r = plan(now: noon.addingTimeInterval(7.5 * hour))                 // 19:30
        XCTAssertEqual(r.first?.day, "2026-10-06")
        XCTAssertEqual(r.count, 6)
    }

    func testLitTodayHasNoReminderToday() {
        let r = plan(lit: true, streak: 5)
        XCTAssertFalse(r.contains { $0.day == "2026-10-05" })
        XCTAssertEqual(r.first?.day, "2026-10-06")
        XCTAssertEqual(r.count, 6 + 1)                                          // six days, and tomorrow's nudge
        for id in ReminderPlan.litIds("2026-10-05") { XCTAssertFalse(ids(r).contains(id)) }
    }

    func testLitIdsAreTodaysPair() {
        XCTAssertEqual(ReminderPlan.litIds("2026-10-05"), ["bubu.remind.daily.2026-10-05", "bubu.remind.risk.2026-10-05"])
        let before = plan(streak: 4)
        XCTAssertEqual(Set(before.filter { $0.day == "2026-10-05" }.map(\.id)), Set(ReminderPlan.litIds("2026-10-05")))
    }

    func testStreakAtRiskNeedsThreeDays() {
        XCTAssertFalse(plan(streak: 2).contains { $0.kind == .risk })
        let r = plan(streak: 3)
        let risk = r.filter { $0.kind == .risk }
        XCTAssertEqual(risk.count, 1)
        XCTAssertEqual(risk[0].day, "2026-10-05")
        XCTAssertEqual(risk[0].fire, noon.addingTimeInterval(9.5 * hour))      // 21:30
        XCTAssertTrue(risk[0].title.contains("3") || risk[0].body.contains("3"))
    }

    func testStreakAtRiskOnlyOnTheFirstOpenDay() {
        let today = plan(streak: 12).filter { $0.kind == .risk }
        XCTAssertEqual(today.map(\.day), ["2026-10-05"])
        let lit = plan(lit: true, streak: 12).filter { $0.kind == .risk }
        XCTAssertEqual(lit.map(\.day), ["2026-10-06"])
    }

    func testStreakAtRiskCanBeSwitchedOff() {
        XCTAssertFalse(plan(ReminderPlan.Settings(on: true, minutes: 1140, streakRisk: false), streak: 30).contains { $0.kind == .risk })
    }

    func testStreakAtRiskGoneOnceItsTimePasses() {
        let r = plan(now: noon.addingTimeInterval(10 * hour), streak: 8)       // 22:00
        XCTAssertFalse(r.contains { $0.day == "2026-10-05" })
        XCTAssertFalse(r.contains { $0.kind == .risk })
    }

    func testDailyGivesWayToANudgeAtTheSameTime() {
        let late = ReminderPlan.Settings(on: true, minutes: 21 * 60 + 15, streakRisk: true)
        let r = plan(late, streak: 5)
        XCTAssertEqual(r.filter { $0.day == "2026-10-05" }.map(\.kind), [.risk])
        // without a streak worth saving the daily one stays
        XCTAssertEqual(plan(late, streak: 1).filter { $0.day == "2026-10-05" }.map(\.kind), [.daily])
    }

    func testOnlyTheFirstOpenDayNamesTheStreak() {
        let r = plan(streak: 12).filter { $0.kind == .daily }
        XCTAssertTrue((r[0].title + r[0].body).contains("12") || (r[0].title + r[0].body).contains("13"))
        for x in r.dropFirst() { XCTAssertFalse((x.title + x.body).contains("12"), x.body) }
        // no streak: nothing about one
        for x in plan() { XCTAssertFalse(x.body.contains("-day")) }
    }

    func testCopyIsStablePerDayAndVaries() {
        XCTAssertEqual(plan(streak: 4), plan(streak: 4))
        XCTAssertGreaterThan(Set(plan().map(\.title)).count, 1)
    }

    func testPrefsDefaultsAndOldBackups() throws {
        let old = try JSONDecoder().decode(Prefs.self, from: Data(#"{"theme":"dark","rate":0.9}"#.utf8))
        XCTAssertNil(old.reminders)
        let s = ReminderPlan.Settings(prefs: old)
        XCTAssertEqual(s, ReminderPlan.Settings(on: false, minutes: 19 * 60, streakRisk: true))
        var p = Prefs()
        p.reminders = true; p.reminderMinutes = 7 * 60; p.streakNudge = false; p.remindersAsked = true
        let back = try JSONDecoder().decode(Prefs.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(back, p)
        XCTAssertEqual(ReminderPlan.Settings(prefs: back), ReminderPlan.Settings(on: true, minutes: 420, streakRisk: false))
    }

    func testLightingTheFireAnnouncesIt() {
        let p = ProgressStore(course: Course.shared, url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json"))
        let heard = expectation(forNotification: .bubuDayLit, object: p)
        p.lightFire()
        wait(for: [heard], timeout: 1)
    }
}
