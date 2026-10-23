import XCTest
@testable import Bubu

/// Speaking's chats with 步步: each kept as a session, its lines counted as spoken answers, ending as a lesson does.
final class ChatTests: XCTestCase {
    let course = Course.shared

    private func store() -> ProgressStore {
        ProgressStore(course: course, url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json"))
    }

    func testAChatIsASessionThatEndsAsALessonDoes() throws {
        let p = store()
        let d = try XCTUnwrap(course.data.dialogues.first)
        let s = StudySession.chatting(p, d)
        XCTAssertNil(s.result, "a chat's session doesn't end before it's begun")
        let lines = d.turns.filter { $0.who == "you" }.count
        XCTAssertGreaterThan(lines, 0)
        for _ in 0..<lines { s.spoke(right: true) }
        XCTAssertEqual(s.combo, lines)
        s.spoke(right: false)
        XCTAssertEqual(s.combo, 0)
        s.finishFlashcards()
        XCTAssertEqual(s.result?.title, "Chat done!")
        XCTAssertGreaterThan(s.result?.xp ?? 0, 0)
        XCTAssertEqual(s.again().title, "Review")
    }

    func testEveryChatHasSomethingToSayOrHear() {
        for d in course.data.dialogues {
            XCTAssertFalse(d.turns.isEmpty, d.id)
            XCTAssertTrue(d.turns.contains { $0.who == "app" }, "\(d.id): 步步 says something")
        }
    }

    func testAVoiceNoteIsAsLongAsItsLine() {
        // (no clips under the tests: about a third of a second a character)
        XCTAssertGreaterThan(ChatPage.seconds("你好！请问，你是马克吗？"), ChatPage.seconds("你好！"))
    }
}
