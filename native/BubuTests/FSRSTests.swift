import XCTest
@testable import Bubu

final class FSRSTests: XCTestCase {
    let now = 1_790_000_000_000.0

    func testFirstGoodReviewIsThreeDays() {
        let s = FSRS.schedule(nil, grade: .good, now: now, random: { 0.5 })
        XCTAssertEqual(s.S!, FSRS.w[2], accuracy: 1e-9)
        XCTAssertEqual(s.interval, 3)
        XCTAssertEqual(s.due, now + 3 * FSRS.day)
        XCTAssertEqual(s.reps, 1)
    }

    func testIntervalEqualsStabilityAtNinetyPercent() {
        XCTAssertEqual(FSRS.interval(S: 10), 10, accuracy: 1e-9)
    }

    /// Right again and again the same day (practice stones, matches): stability stops growing
    /// at a hundred years and the interval at a year, instead of overflowing (the app trapped).
    func testManyRightAnswersInOneDayDontOverflow() {
        var s = FSRS.schedule(nil, grade: .good, now: now, random: { 0.5 })
        for k in 1...5000 { s = FSRS.schedule(s, grade: .easy, now: now + Double(k) * 1000, random: { 0.5 }) }
        XCTAssertTrue(s.S!.isFinite)
        XCTAssertLessThanOrEqual(s.S!, 36_500)
        XCTAssertEqual(s.interval, 365)
    }

    func testAgainComesBackInAMinute() {
        let first = FSRS.schedule(nil, grade: .good, now: now, random: { 0.5 })
        let later = now + 3 * FSRS.day
        let s = FSRS.schedule(first, grade: .again, now: later)
        XCTAssertEqual(s.due, later + 60_000)
        XCTAssertEqual(s.lapses, 1)
        XCTAssertEqual(s.reps, 0)
        XCTAssertLessThan(s.S!, first.S!)
    }

    func testOldSchedulerRecordIsCarriedOver() {
        let old = SRSRecord(ease: 2.4, interval: 6, due: now, reps: 3)
        let s = FSRS.schedule(old, grade: .good, now: now, random: { 0.5 })
        XCTAssertGreaterThan(s.interval!, 6)
    }

    func testLenientDecoding() throws {
        let json = #"{"interval":"4","due":1790000000000,"reps":2.0,"S":null,"weird":true}"#
        let r = try JSONDecoder().decode(SRSRecord.self, from: Data(json.utf8))
        XCTAssertEqual(r.interval, 4)
        XCTAssertEqual(r.reps, 2)
        XCTAssertNil(r.S)
    }
}
