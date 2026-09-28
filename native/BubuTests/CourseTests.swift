import XCTest
@testable import Bubu

final class CourseTests: XCTestCase {
    let course = Course.shared

    func testCourseLoads() {
        XCTAssertGreaterThan(course.lessons.count, 300)
        XCTAssertGreaterThan(course.chapters.count, 50)
        XCTAssertFalse(course.data.readings.isEmpty)
    }

    func testCardIdsAreUniqueAndWebShaped() {
        XCTAssertEqual(Set(course.cards.map(\.id)).count, course.cards.count)
        // "lesson:index", the lesson being where the word was first taught before stones were cut to five
        for c in course.cards { XCTAssertNotNil(c.id.range(of: #"^[a-z0-9]+-[a-z0-9]+-\d+[a-z]?:\d+$"#, options: .regularExpression), c.id) }
    }

    func testEveryChapterLessonExists() {
        for ch in course.chapters { for id in ch.lessons { XCTAssertNotNil(course.lessonById[id], id) } }
    }

    func testEveryLessonHasAHero() {
        for l in course.lessons { XCTAssertEqual(course.hero[l.id]?.count, 1, l.id) }
    }

    func testPathPiecesPointAtRealStonesAndArt() {
        for p in course.data.pathLayout.pieces {
            XCTAssertNotNil(course.lessonById[p.stone], p.stone)
            XCTAssertNotNil(course.data.art[p.art], p.art)
        }
    }

    func testProgressRoundTrip() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let a = ProgressStore(course: course, url: url)
        let first = course.lessons[0].id
        a.markDone(first)
        a.review(course.cards[0].id, .good)
        a.earn(10)
        a.lightFire()
        let b = ProgressStore(course: course, url: url)
        XCTAssertTrue(b.isDone(first))
        XCTAssertEqual(b.wordsLearned, 1)
        XCTAssertEqual(b.xpToday, 10)
        XCTAssertEqual(b.streak, 1)
        XCTAssertNotEqual(b.currentLessonId, first)
    }

    func testQuestsMatchTheWeb() {
        // values from the web app's seededPick for the same dates
        let s = Quest.sets
        XCTAssertEqual([Quest.pick(s[0], seed: "2026-09-27a"), Quest.pick(s[1], seed: "2026-09-27b"), Quest.pick(s[2], seed: "2026-09-27c")],
                       ["xp30", "perfect1", "listen5"])
        XCTAssertEqual([Quest.pick(s[1], seed: "2026-10-01b"), Quest.pick(s[2], seed: "2026-10-01c")], ["review15", "speak3"])
    }

    func testLessonNameSplits() {
        let l = Lesson(id: "x", title: "起步1 US.1 · 你好！ Hello! Sounds and survival", words: [])
        XCTAssertEqual(l.nameParts.hanzi, "你好！")
        XCTAssertEqual(l.nameParts.en, "Hello! Sounds and survival")
    }
}
