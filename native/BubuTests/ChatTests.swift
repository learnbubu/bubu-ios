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

    func testEachChatIsWithItsCast() {
        let first = course.data.dialogues.first!
        XCTAssertEqual(ChatCast.members(first), ["小雨"])
        XCTAssertEqual(ChatCast.chatName(first), "小雨")
        XCTAssertEqual(ChatCast.photo("小雨"), "chat-xiaoyu")
        XCTAssertEqual(ChatCast.photo(nil), "chat-bubu")
        // every one who speaks in a chat has a photo of their own
        for d in course.data.dialogues {
            for m in ChatCast.members(d) { XCTAssertNotEqual(ChatCast.photo(m), "chat-bubu", "\(d.id): \(m)") }
        }
        // a group of five: three names, and how many
        let big = course.data.dialogues.first { ChatCast.members($0).count == 5 }!
        XCTAssertTrue(ChatCast.chatName(big).hasSuffix("(5)"))
        XCTAssertTrue(ChatCast.preview(big).contains(": "))
    }

    func testAVoiceNoteIsAsLongAsItsLine() {
        // (no clips under the tests: about a third of a second a character)
        XCTAssertGreaterThan(ChatPage.seconds("你好！请问，你是马克吗？"), ChatPage.seconds("你好！"))
    }

    func testSpeakingFreelyIsJudgedByTheTutor() async {
        let d = course.data.dialogues.first!
        let goal = d.turns.first { $0.who == "you" && $0.free != true }!
        let before = d.turns.first { $0.who == "app" }
        // (no on-phone model under the tests: the chat keeps its set lines)
        XCTAssertFalse(FreeSpeech.available)
        // the example said: spot on, no need to ask
        let v = await FreeSpeech.judge(said: [goal.hanzi], goal: goal, before: before)
        XCTAssertEqual(v?.works, true)
        XCTAssertEqual(v?.spotOn, true)
        // said another way, and no tutor to ask: nil, judged as before
        let other = await FreeSpeech.judge(said: ["我不知道"], goal: goal, before: before)
        XCTAssertNil(other)
        // nothing heard: nothing to judge
        let none = await FreeSpeech.judge(said: [], goal: goal, before: before)
        XCTAssertNil(none)
        // the tutor's told what was said to them, what you meant and what you said
        let p = FreeSpeech.prompt(heard: "我不知道", goal: goal, before: before)
        XCTAssertTrue(p.contains(goal.en) && p.contains(goal.hanzi) && p.contains("我不知道"))
        if let b = before { XCTAssertTrue(p.contains(b.hanzi)) }
    }
}
