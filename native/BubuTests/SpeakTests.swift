import XCTest
@testable import Bubu

/// Speaking: what's asked for (never words not met yet), how it's marked, and when.
final class SpeakTests: XCTestCase {
    private let course = Course.shared

    private func store() -> ProgressStore {
        ProgressStore(course: Course.shared, url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json"))
    }

    private var ni: Card {
        get throws { try XCTUnwrap(course.cardsByHanzi["你"]?.first, "the course teaches 你") }
    }

    // MARK: what to say

    func testASentenceWithAnUnmetWordMeansJustTheWord() throws {
        let c = try ni
        // the owner's example: 你姓林吗？ early in chapter 1, before 姓 and 林
        XCTAssertTrue(course.sentences(for: c).contains { $0.hanzi == "你姓林吗？" })
        let onlyNi: (String) -> Bool = { $0 == c.id }
        let allowed = course.speakSentences(for: c, met: onlyNi)
        XCTAssertFalse(allowed.contains { $0.hanzi == "你姓林吗？" })
        // whatever is allowed is only 你 and the little particles
        for s in allowed {
            for w in s.words { XCTAssertTrue(w.hanzi == "你" || Course.trivialWords.contains(w.hanzi), "\(s.hanzi): \(w.hanzi)") }
        }
        // nothing met at all (not even the word): never a sentence, always the word
        for _ in 0..<20 {
            let ex = Exercise.speak(c, met: { _ in false }, sentenceChance: 1)
            XCTAssertNil(ex.sentence)
            XCTAssertEqual(ex.sayHanzi, c.word.hanzi)
        }
    }

    func testTheCardsOwnWordGetsNoExceptionInASpokenSentence() throws {
        let c = try ni
        // everything met but 你 itself: no sentence (unlike a sentence-building exercise)
        let allButNi: (String) -> Bool = { $0 != c.id }
        let others = course.cardsByChar["你"] ?? []
        if others.allSatisfy({ $0.id == c.id }) {
            XCTAssertTrue(course.speakSentences(for: c, met: allButNi).isEmpty)
        }
        XCTAssertFalse(course.speakSentences(for: c, met: allButNi).contains { $0.hanzi == "你姓林吗？" })
    }

    func testAllMetAndShortMeansTheSentenceIsAllowed() throws {
        let c = try ni
        let all: (String) -> Bool = { _ in true }
        let allowed = course.speakSentences(for: c, met: all)
        XCTAssertTrue(allowed.contains { $0.hanzi == "你姓林吗？" })
        XCTAssertTrue(allowed.allSatisfy { $0.words.count <= Course.speakSentenceMax })
        // a long sentence never is, even with every word met
        if let long = course.sentences(for: c).first(where: { $0.words.count > Course.speakSentenceMax }) {
            XCTAssertFalse(allowed.contains(long))
        }
        let ex = Exercise.speak(c, met: all, sentenceChance: 1)
        XCTAssertNotNil(ex.sentence)
        XCTAssertTrue(ex.sayHanzi.contains(c.word.hanzi))
        // and by default it's sometimes just the word
        XCTAssertNil(Exercise.speak(c, met: all, sentenceChance: 0).sentence)
    }

    // MARK: marking

    func testEachCharacterIsGreenIfHeardAndRedIfMissed() {
        let exact: (Character, Character) -> Bool = { $0 == $1 }
        let all = SpeechScore.marks("你姓林吗？", ["你姓林吗"], same: exact)
        XCTAssertEqual(all.map(\.char), Array("你姓林吗？"))
        XCTAssertEqual(all.map(\.heard), [true, true, true, true, nil])     // punctuation isn't judged

        let some = SpeechScore.marks("你姓林吗？", ["你是林。"], same: exact)
        XCTAssertEqual(some.map(\.heard), [true, false, true, false, nil])
        XCTAssertEqual(SpeechScore.heardShare(some), 0.5, accuracy: 0.001)

        // in order: a character heard out of place only counts once
        XCTAssertEqual(SpeechScore.marks("你好", ["好你"], same: exact).compactMap(\.heard).filter { $0 }.count, 1)
        // the best of the guesses
        XCTAssertEqual(SpeechScore.marks("你好", ["你", "你好"], same: exact).map(\.heard), [true, true])
        // nothing heard: all red
        XCTAssertEqual(SpeechScore.marks("你好！", [], same: exact).map(\.heard), [false, false, nil])
    }

    func testTonesAndHomophonesDontCount() {
        // 她 for 他: the same sound, and speaking isn't judged on tones
        XCTAssertTrue(SpeechScore.sameSound("他", "她"))
        XCTAssertFalse(SpeechScore.sameSound("你", "我"))
        XCTAssertEqual(SpeechScore.marks("他好", ["她好"]).map(\.heard), [true, true])
        XCTAssertTrue(SpeechScore.passes("他", ["她"], keyword: "他"))
        XCTAssertTrue(SpeechScore.passes("你姓林吗？", ["你姓林吗"], keyword: "你"))
        XCTAssertFalse(SpeechScore.passes("你姓林吗？", ["我"], keyword: "你"))
    }

    // MARK: when

    /// (The owner, 1 Oct 2026: a little speaking and writing inside a lesson.) A word just met
    /// is said aloud only once it's been got right a couple of times, and a lesson asks for
    /// one word aloud, no more.
    func testALittleSpeakingInAWordsFirstSession() {
        XCTAssertTrue(StudySession.inFirstSession("a", newAtStart: ["a"], metInSession: []))
        XCTAssertTrue(StudySession.inFirstSession("a", newAtStart: [], metInSession: ["a"]))
        XCTAssertFalse(StudySession.inFirstSession("a", newAtStart: ["b"], metInSession: ["b"]))

        let p = store()
        let lesson = course.lessons[0].id
        for focuses in [Set(StudySession.allDirs), ["speak"]] {
            let fresh = focuses.count == 1 ? store() : p
            let s = StudySession(lessonId: lesson, progress: fresh, focuses: focuses)
            var spoken: [String] = [], right: [String: Int] = [:], guardN = 0
            while s.result == nil && guardN < 300 {
                guardN += 1
                if let c = s.card {
                    XCTAssertEqual(s.maySpeak(c), right[c.id, default: 0] >= StudySession.rightBeforeSpeaking, c.word.hanzi)
                    if s.exercise?.dir == "speak" {
                        XCTAssertGreaterThanOrEqual(right[c.id, default: 0], StudySession.rightBeforeSpeaking, c.word.hanzi)
                        spoken.append(c.word.hanzi)
                    }
                    s.answer(true)
                    right[c.id, default: 0] += 1
                }
                s.next()
            }
            XCTAssertNotNil(s.result)
            // (a session of only speaking has nothing else to ask once a word may be said)
            if focuses.count > 1 { XCTAssertLessThanOrEqual(spoken.count, 1, "a little: \(spoken)") }
        }

        // the next session, the words met are spoken
        let later = StudySession(lessonId: lesson, progress: p, focuses: ["speak"])
        var guardN = 0
        while later.card == nil && later.result == nil && guardN < 20 { guardN += 1; later.next() }
        XCTAssertEqual(later.exercise?.dir, "speak")
        XCTAssertEqual(later.exercise?.kind, .speak)
    }

    func testCantSpeakNowStopsSpeakingForTheSession() {
        let p = store()
        let lesson = course.lessons[0].id
        // meet the lesson's words first
        let first = StudySession(lessonId: lesson, progress: p)
        var guardN = 0
        while first.result == nil && guardN < 300 {
            guardN += 1
            if first.card != nil { first.answer(true) }
            first.next()
        }
        let s = StudySession(lessonId: lesson, progress: p, focuses: ["speak", "recognize"])
        guardN = 0
        while s.card == nil && s.result == nil && guardN < 20 { guardN += 1; s.next() }
        guard let c = s.card else { return XCTFail("a card to practise") }
        XCTAssertTrue(s.maySpeak(c))
        s.skip()
        XCTAssertFalse(s.maySpeak(c))
        guardN = 0
        s.next()
        while s.result == nil && guardN < 100 {
            guardN += 1
            if s.card != nil {
                XCTAssertNotEqual(s.exercise?.dir, "speak")
                s.answer(true)
            }
            s.next()
        }
    }
}
