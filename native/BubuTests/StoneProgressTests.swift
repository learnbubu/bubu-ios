import XCTest
@testable import Bubu

/// "I did two stones, went back, and it's still on the second": finishing a stone must mark
/// it done and move the path on, and that must survive the app being reopened.
final class StoneProgressTests: XCTestCase {
    private let course = Course.shared

    /// Plays a session through, answering everything right (a mistake would only add steps).
    private func finish(_ s: StudySession) {
        var n = 0
        while s.result == nil && n < 300 {
            n += 1
            if case .match(let cards, _) = s.current { for c in cards { _ = s.matchPair(c.id, c.id) } }
            if s.card != nil { s.answer(true) }
            s.next()
        }
        XCTAssertNotNil(s.result, "the session finishes")
    }

    func testFinishingTwoStonesMovesThePathOnAndSurvivesAReload() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let p = ProgressStore(course: course, url: url)
        p.setPlus(true)                                   // buns don't matter here
        let first = try XCTUnwrap(p.currentLessonId)
        XCTAssertEqual(first, course.lessons[0].id)

        for i in 0..<2 {
            let id = try XCTUnwrap(p.currentLessonId)
            XCTAssertEqual(id, course.lessons[i].id, "stone \(i + 1) is the current one")
            let s = try XCTUnwrap(StudySession.lesson(id, p), "stone \(i + 1) starts")
            finish(s)
            XCTAssertEqual(s.result?.lessonFinished, true, "stone \(i + 1) is complete")
            XCTAssertTrue(p.isDone(id), "stone \(i + 1) is marked done")
            XCTAssertEqual(p.currentLessonId, course.lessons[i + 1].id, "the path moves on after stone \(i + 1)")
        }

        // reopen the app: the same file, a fresh store (load, migrations, everything)
        p.save()
        let again = ProgressStore(course: course, url: url)
        XCTAssertTrue(again.isDone(course.lessons[0].id), "stone 1 is still done after a reload")
        XCTAssertTrue(again.isDone(course.lessons[1].id), "stone 2 is still done after a reload")
        XCTAssertEqual(again.currentLessonId, course.lessons[2].id, "the path is on stone 3 after a reload")
    }
}
