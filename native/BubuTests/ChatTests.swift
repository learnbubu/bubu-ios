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
        // something else altogether: not near the reply expected, so try again, the example offered
        let other = await FreeSpeech.judge(said: ["我不知道"], goal: goal, before: before)
        XCTAssertEqual(other?.works, false)
        XCTAssertEqual(other?.better, goal.hanzi)
        // the line itself: every word of it said
        XCTAssertEqual(FreeSpeech.coverage(goal.hanzi, goal: goal).0, 1)
        // a reply that works but isn't the line: the example as the better way
        let fine = FreeSpeech.advised(SpeakingVerdict(works: true, comment: "Nice."), missing: [], goal: goal)
        XCTAssertEqual(fine.better, goal.hanzi)
        // nothing heard: nothing to judge
        let none = await FreeSpeech.judge(said: [], goal: goal, before: before)
        XCTAssertNil(none)
        // the tutor's told what was said to them, what you meant and what you said
        let p = FreeSpeech.prompt(heard: "我不知道", goal: goal, before: before)
        XCTAssertTrue(p.contains(goal.en) && p.contains(goal.hanzi) && p.contains("我不知道"))
        if let b = before { XCTAssertTrue(p.contains(b.hanzi)) }
    }

    func testAPracticeStoneHasAChatOnceItsWordsAreMet() throws {
        // every word met: the first practice stone with a chat ready
        let p = store()
        for c in course.cards { _ = p.answer(c.id, correct: true, dir: "recall", sessionStart: 0, mistakesMode: false) }
        let practice = try XCTUnwrap(course.lessons.first { $0.isPractice && StudySession.practiceChat($0.id, p) != nil })
        // nothing met: no chat
        XCTAssertNil(StudySession.practiceChat(practice.id, store()))
        let (d, turns) = try XCTUnwrap(StudySession.practiceChat(practice.id, p))
        XCTAssertTrue(StudySession.chatUnits(practice.id).contains(d.lesson))
        let mine = turns.filter { $0.who == "you" }.count
        XCTAssertTrue((1...StudySession.chatLines).contains(mine), "\(mine) of your lines")
        XCTAssertEqual(turns.last?.who, "you", "it ends on yours")
        let s = try XCTUnwrap(StudySession.lesson(practice.id, p))
        var sawChat = false
        var guardN = 0
        while s.result == nil && guardN < 100 {
            guardN += 1
            if case .chat = s.current {
                sawChat = true
                let xp = p.xpCounter
                s.chatLine(right: true)
                XCTAssertGreaterThan(p.xpCounter, xp, "a line said earns XP")
                let steps = s.stepsDone
                s.chatDone()
                XCTAssertEqual(s.stepsDone, steps + 1, "the chat is one step")
            } else if s.card != nil { s.answer(true) }
            s.next()
        }
        XCTAssertTrue(sawChat)
    }

    func testAChatSliceStartsWithWhatYoureAnswering() {
        let d = course.data.dialogues.max { $0.turns.filter { $0.who == "you" }.count < $1.turns.filter { $0.who == "you" }.count }!
        for _ in 0..<20 {
            let sl = StudySession.chatSlice(d.turns)
            XCTAssertEqual(sl.filter { $0.who == "you" }.count, min(StudySession.chatLines, d.turns.filter { $0.who == "you" }.count))
            // one stretch of the chat, opening on the line you answer (or your first, at the chat's start)
            let at = d.turns.firstIndex(of: sl[0])!
            XCTAssertEqual(Array(d.turns[at..<(at + sl.count)]), sl)
            XCTAssertLessThanOrEqual(sl.firstIndex { $0.who == "you" }!, 1)
            XCTAssertEqual(sl.last?.who, "you")
        }
    }

    func testEnglishOrNothingIsntJudgedAsChinese() async {
        let d = course.data.dialogues.first!
        let goal = d.turns.first { $0.who == "you" && $0.free != true }!
        // the owner's phone: English heard, and the tutor said it works
        let v = FreeSpeech.noChinese(FreeSpeech.clean("呃 yes am call"), goal: goal)
        XCTAssertEqual(v?.works, false)
        XCTAssertEqual(v?.better, goal.hanzi)
        let judged = await FreeSpeech.judge(said: ["呃 yes am call"], goal: goal, before: nil)
        XCTAssertEqual(judged?.works, false, "not passed to the tutor at all")
        // only hesitations: nothing to judge either
        XCTAssertEqual(FreeSpeech.noChinese(FreeSpeech.clean("呃嗯"), goal: goal)?.works, false)
        // Chinese, worded otherwise: for the tutor
        XCTAssertNil(FreeSpeech.noChinese("对，我是马克", goal: goal))
        // the example with hesitations is still spot on
        let spot = await FreeSpeech.judge(said: ["呃" + goal.hanzi], goal: goal, before: nil)
        XCTAssertEqual(spot?.spotOn, true)
    }

    func testTheTutorsPinyinIsTheCourses() {
        // every line of the course's chats, back from its own words (马克 is Mǎkè, not the model's "mǎk")
        for t in course.data.dialogues.flatMap(\.turns) where Sentence.segment(hanzi: t.hanzi, pinyin: t.pinyin) != nil {
            XCTAssertNotNil(FreeSpeech.pinyin(t.hanzi), t.hanzi)
        }
        let mark = course.data.dialogues.flatMap(\.turns).first { $0.hanzi.contains("马克") }!
        XCTAssertTrue(FreeSpeech.pinyin(mark.hanzi)!.lowercased().contains("mǎkè"))
        // a character the course doesn't have: no pinyin rather than a guess
        XCTAssertNil(FreeSpeech.pinyin("龘"))
    }

    func testTheTutorNeverLeavesChineseUnexplained() {
        // a word of the course in the comment: out of the sentence, listed with its pinyin and meaning
        let known = course.cards.first { !$0.isSentence && $0.word.hanzi.count == 2 }!
        let (text, words) = FreeSpeech.explained(comment: "Nice try, but “\(known.word.hanzi)” doesn't fit here.", named: [])
        XCTAssertFalse(text.contains(where: Course.isHan), text)
        XCTAssertTrue(text.contains("that word"))
        XCTAssertEqual(words.first?.hanzi, known.word.hanzi.filter(Course.isHan))
        XCTAssertEqual(words.first?.en, known.word.gloss)
        XCTAssertNotNil(words.first?.pinyin)
        // a misheard word nobody explained: not shown at all
        let (t2, w2) = FreeSpeech.explained(comment: "You said 龘龘 there.", named: [])
        XCTAssertFalse(t2.contains("龘"))
        XCTAssertTrue(w2.isEmpty)
        // a word the tutor named, with its meaning: listed with it
        let (_, w3) = FreeSpeech.explained(comment: "Use the word for student.", named: [("龘", "a test word")])
        XCTAssertEqual(w3.first?.en, "a test word")
    }
}
