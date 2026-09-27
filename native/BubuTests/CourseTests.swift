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
        for c in course.cards.prefix(50) { XCTAssertTrue(c.id.hasPrefix(c.lessonId + ":")) }
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
        let b = ProgressStore(course: course, url: url)
        XCTAssertTrue(b.isDone(first))
        XCTAssertEqual(b.wordsLearned, 1)
        XCTAssertEqual(b.xpToday, 10)
        XCTAssertEqual(b.streak, 1)
        XCTAssertNotEqual(b.currentLessonId, first)
    }
}
