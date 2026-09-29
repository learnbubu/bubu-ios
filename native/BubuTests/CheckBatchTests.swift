import XCTest
@testable import Bubu

/// Four of Duolingo's habits: pick an option then Check, "Can't listen now", a Chinese option
/// or tile said as it's tapped, and missed words coming back at the end of the lesson.
final class CheckBatchTests: XCTestCase {
    private let course = Course.shared

    private func store() -> ProgressStore {
        ProgressStore(course: course, url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json"))
    }

    private func card(_ hanzi: String) throws -> Card {
        try XCTUnwrap(course.cardsByHanzi[hanzi]?.first, "the course teaches \(hanzi)")
    }

    /// Past the new-word cards (and any match) to the next exercise.
    private func toNextExercise(_ s: StudySession) {
        var n = 0
        while s.card == nil && s.result == nil && n < 20 {
            n += 1
            if case .match(let cards, _) = s.current { for c in cards { _ = s.matchPair(c.id, c.id) } }
            s.next()
        }
    }

    /// Plays what's left of a session, every answer and every pair right; `each` sees every
    /// exercise before it's answered.
    private func finish(_ s: StudySession, each: (Card) -> Void = { _ in }) {
        var n = 0
        while s.result == nil && n < 400 {
            n += 1
            if case .match(let cards, _) = s.current { for c in cards { _ = s.matchPair(c.id, c.id) } }
            if let c = s.card, !s.answered {
                each(c)
                s.answer(true)
            }
            s.next()
        }
        XCTAssertNotNil(s.result, "the session finishes")
    }

    // MARK: pick, then Check

    func testASelectionAloneIsNotAnAnswer() throws {
        let p = store()
        let s = StudySession(lessonId: course.lessons[0].id, progress: p, focuses: ["recognize"])
        toNextExercise(s)
        let ex = try XCTUnwrap(s.exercise)
        XCTAssertEqual(ex.kind, .choice)
        let wrong = try XCTUnwrap(ex.options.first { $0 != ex.answer })

        var pick = ChoicePick()
        XCTAssertFalse(pick.canCheck, "Check is off until something is selected")
        XCTAssertNil(pick.verdict(ex))

        XCTAssertTrue(pick.select(wrong, in: ex, answered: s.answered))
        XCTAssertEqual(pick.selected, wrong)
        XCTAssertTrue(pick.canCheck)
        // the session hasn't heard of it
        XCTAssertFalse(s.answered)
        XCTAssertNil(s.lastCorrect)
        XCTAssertEqual(s.answeredCount, 0)
        XCTAssertEqual(s.againCount, 0)
        XCTAssertEqual(s.mistakes, 0)
        XCTAssertEqual(s.bunsEaten, 0)
        XCTAssertEqual(s.sessionXP, 0)
        XCTAssertTrue(s.retries.isEmpty)
        XCTAssertNil(p.srs[ex.card.id], "no record yet")
        XCTAssertTrue(p.mistakeCards().isEmpty)
    }

    func testOnlyTheOptionCheckedCounts() throws {
        let p = store()
        let s = StudySession(lessonId: course.lessons[0].id, progress: p, focuses: ["recognize"])
        toNextExercise(s)
        let ex = try XCTUnwrap(s.exercise)
        let wrong = try XCTUnwrap(ex.options.first { $0 != ex.answer })

        // a slip of the thumb, then the option meant
        var pick = ChoicePick()
        pick.select(wrong, in: ex, answered: s.answered)
        XCTAssertEqual(pick.verdict(ex), false)
        pick.select(ex.answer, in: ex, answered: s.answered)
        XCTAssertEqual(pick.selected, ex.answer, "the selection moved")
        XCTAssertEqual(pick.verdict(ex), true)

        // Check
        let verdict = try XCTUnwrap(pick.verdict(ex))
        s.answer(verdict)
        XCTAssertTrue(s.answered)
        XCTAssertEqual(s.lastCorrect, true)
        XCTAssertEqual(s.answeredCount, 1)
        XCTAssertEqual(s.againCount, 0, "the slip wasn't counted")
        XCTAssertEqual(s.mistakes, 0)
        XCTAssertEqual(s.bunsEaten, 0)
        XCTAssertTrue(s.retries.isEmpty)
        XCTAssertTrue(p.mistakeCards().isEmpty)

        // once it's answered the selection stays put
        XCTAssertFalse(pick.select(wrong, in: ex, answered: s.answered))
        XCTAssertEqual(pick.selected, ex.answer)
    }

    func testOnlyAnExercisesOwnOptionsCanBeSelected() throws {
        let c = try card("你好")
        let ex = Exercise.choice(c, dir: "recognize", scope: [c.lessonId])
        var pick = ChoicePick()
        XCTAssertFalse(pick.select("not one of the options", in: ex, answered: false))
        XCTAssertFalse(pick.canCheck)
        // and only multiple choice is picked this way
        let write = Exercise(kind: .write, dir: "write", card: c)
        XCTAssertFalse(pick.select(c.word.hanzi, in: write, answered: false))
        XCTAssertNil(pick.verdict(write))
    }

    // MARK: can't listen now

    func testCantListenNowCostsNothingAndStopsListening() throws {
        let p = store()
        let s = StudySession(lessonId: course.lessons[0].id, progress: p, focuses: ["recognize", "listen"])
        XCTAssertTrue(s.onBuns)
        // play to the first listening exercise
        var n = 0
        while s.result == nil && n < 100 && !(s.card != nil && s.dir == "listen") {
            n += 1
            if s.card != nil { s.answer(true) }
            s.next()
        }
        let c = try XCTUnwrap(s.card, "a listening exercise comes up")
        XCTAssertEqual(s.exercise?.dir, "listen")
        XCTAssertFalse(s.listeningOff)

        let buns = p.buns
        let xp = s.sessionXP
        let answers = s.answeredCount
        let steps = s.stepsDone
        let reps = p.srs[c.id]?.reps
        s.skip()
        XCTAssertTrue(s.answered, "the exercise is over")
        XCTAssertNil(s.lastCorrect, "neither right nor wrong")
        XCTAssertTrue(s.listeningOff)
        XCTAssertEqual(p.buns, buns, "no bun eaten")
        XCTAssertEqual(s.bunsEaten, 0)
        XCTAssertEqual(s.sessionXP, xp, "no XP")
        XCTAssertEqual(s.answeredCount, answers)
        XCTAssertEqual(s.stepsDone, steps)
        XCTAssertEqual(s.againCount, 0)
        XCTAssertEqual(s.mistakes, 0)
        XCTAssertTrue(s.retries.isEmpty, "it isn't a mistake")
        XCTAssertTrue(p.mistakeCards().isEmpty, "no mistake saved")
        XCTAssertEqual(p.srs[c.id]?.reps, reps, "the word's record is as it was")

        // the rest of the session: no listening, and the word is asked another way
        s.next()
        var again: [String] = []
        finish(s) { card in
            XCTAssertNotEqual(s.dir, "listen", card.word.hanzi)
            XCTAssertNotEqual(s.exercise?.dir, "listen", card.word.hanzi)
            XCTAssertFalse(s.matchAudio)
            if card.id == c.id { again.append(s.dir) }
        }
        XCTAssertFalse(again.isEmpty, "the word comes back")
        XCTAssertEqual(s.stepsDone, s.sessionTotal, "every exercise was done, the skipped one as something else")
        XCTAssertEqual(s.progressFraction, 1)
        XCTAssertEqual(s.bunsEaten, 0)
    }

    func testAListeningSessionEndsWhenListeningIsOff() throws {
        let p = store()
        let lesson = course.lessons[0].id
        finish(StudySession(lessonId: lesson, progress: p))             // meet the words
        let cards = course.cards(in: lesson)
        XCTAssertGreaterThanOrEqual(cards.count, 2)
        let s = StudySession(lessonId: "", progress: p, focuses: ["listen"], cards: cards, mode: .listen, title: "Listening")
        toNextExercise(s)
        XCTAssertEqual(s.exercise?.dir, "listen")
        s.answer(true)
        s.next()
        XCTAssertEqual(s.exercise?.dir, "listen")
        let xp = s.sessionXP
        s.skip()
        XCTAssertTrue(s.listeningOff)
        XCTAssertFalse(s.hasMore, "nothing else to ask")
        XCTAssertEqual(s.sessionXP, xp)
        s.next()
        let r = try XCTUnwrap(s.result, "the session ends")
        XCTAssertEqual(r.mistakes, 0)
        XCTAssertEqual(r.accuracy, 100)
        XCTAssertEqual(s.againCount, 0)
    }

    func testAListeningSessionSkippedAtOnceEarnsNothing() throws {
        let p = store()
        let cards = course.cards(in: course.lessons[0].id)
        let s = StudySession(lessonId: "", progress: p, focuses: ["listen"], cards: cards, mode: .listen, title: "Listening")
        toNextExercise(s)
        let c = try XCTUnwrap(s.card)
        XCTAssertEqual(s.exercise?.dir, "listen")
        s.skip()
        XCTAssertTrue(s.nothingAnswered)
        XCTAssertFalse(s.hasMore)
        s.next()
        let r = try XCTUnwrap(s.result, "the session ends")
        XCTAssertEqual(r.xp, 0, "nothing answered, nothing earned")
        XCTAssertFalse(r.fireJustLit)
        XCTAssertNil(p.srs[c.id])
        XCTAssertEqual(s.bunsEaten, 0)
    }

    /// "Can't speak now" still only stops speaking.
    func testCantSpeakNowLeavesListeningOn() throws {
        let p = store()
        let lesson = course.lessons[0].id
        finish(StudySession(lessonId: lesson, progress: p))
        let s = StudySession(lessonId: lesson, progress: p, focuses: ["speak"])
        toNextExercise(s)
        let c = try XCTUnwrap(s.card)
        XCTAssertEqual(s.exercise?.dir, "speak")
        s.skip()
        XCTAssertFalse(s.maySpeak(c))
        XCTAssertFalse(s.listeningOff)
        XCTAssertTrue(s.hasMore, "the word comes back")
    }

    // MARK: tap to hear

    func testTapToHearIsSilentInAnUnansweredListeningExercise() throws {
        let c = try card("你好")
        let listen = Exercise.choice(c, dir: "listen", scope: [c.lessonId])
        XCTAssertEqual(listen.dir, "listen")
        for o in listen.options {
            XCTAssertNil(TapToHear.option(o, in: listen, answered: false), o)
        }
        // even a listening exercise whose options are Chinese
        let other = try card("谢谢")
        let chinese = Exercise(kind: .choice, dir: "listen", card: c,
                               options: [c.word.hanzi, other.word.hanzi], answer: c.word.hanzi)
        for o in chinese.options {
            XCTAssertNil(TapToHear.option(o, in: chinese, answered: false), o)
            XCTAssertNil(TapToHear.say(o, in: chinese, answered: false, allowed: true), o)
            // once it's answered the sound gives nothing away
            XCTAssertEqual(TapToHear.option(o, in: chinese, answered: true), o)
        }
        // or a tile in one
        let tile = Exercise.Tile(id: 0, text: c.word.hanzi, pinyin: c.word.pinyin)
        let heard = Exercise(kind: .sentence, dir: "listen", card: c)
        XCTAssertNil(TapToHear.tile(tile, in: heard, answered: false))
    }

    func testTapToHearSaysChineseOptionsAndTiles() throws {
        let c = try card("你好")
        let scope: Set<String> = [c.lessonId]
        // recall: the options are characters
        let recall = Exercise.choice(c, dir: "recall", scope: scope)
        XCTAssertEqual(TapToHear.option(recall.answer, in: recall, answered: false), c.word.hanzi)
        for o in recall.options where o.contains(where: Course.isHan) {
            XCTAssertEqual(TapToHear.option(o, in: recall, answered: false), o)
            XCTAssertNil(TapToHear.option(o, in: recall, answered: false, allowed: false), "switched off in Settings")
        }
        // English meanings and pinyin aren't said
        let recognize = Exercise.choice(c, dir: "recognize", scope: scope)
        for o in recognize.options { XCTAssertNil(TapToHear.option(o, in: recognize, answered: false), o) }
        let pinyin = Exercise.choice(c, dir: "pinyin", scope: scope)
        for o in pinyin.options { XCTAssertNil(TapToHear.option(o, in: pinyin, answered: false), o) }
        // sentence tiles: Chinese ones speak, English ones don't
        let build = Exercise(kind: .sentence, dir: "sentence", card: c)
        let zh = Exercise.Tile(id: 0, text: "你好", pinyin: "nǐ hǎo")
        let en = Exercise.Tile(id: 1, text: "hello", pinyin: nil)
        XCTAssertEqual(TapToHear.tile(zh, in: build, answered: false), "你好")
        XCTAssertNil(TapToHear.tile(en, in: build, answered: false))
        XCTAssertNil(TapToHear.tile(zh, in: build, answered: false, allowed: false))
        // an option isn't a tile, nor a tile an option
        XCTAssertNil(TapToHear.option("你好", in: build, answered: false))
        XCTAssertNil(TapToHear.tile(zh, in: recall, answered: false))
    }

    func testTapToHearFollowsTheSettings() {
        var prefs = Prefs()
        XCTAssertEqual(TapToHear.allowed(prefs), TapToHear.enabled)
        prefs.sound = false
        XCTAssertFalse(TapToHear.allowed(prefs))
        prefs.sound = true
        prefs.autoplay = false
        XCTAssertFalse(TapToHear.allowed(prefs))
    }

    // MARK: missed words come back at the end

    func testWhichMistakeComesNext() {
        XCTAssertNil(StudySession.nextRetry([], after: "a"))
        XCTAssertEqual(StudySession.nextRetry(["a"], after: nil), 0)
        XCTAssertEqual(StudySession.nextRetry(["a", "b"], after: "c"), 0)
        XCTAssertEqual(StudySession.nextRetry(["a", "b"], after: "a"), 1, "not the word just asked")
        XCTAssertEqual(StudySession.nextRetry(["a", "a", "b"], after: "a"), 2)
        XCTAssertEqual(StudySession.nextRetry(["a"], after: "a"), 0, "unless it's the only thing left")
        XCTAssertEqual(StudySession.nextRetry(["a", "a"], after: "a"), 0)
    }

    func testAMissedWordWaitsForTheEndOfTheLesson() throws {
        let p = store()
        p.setPlus(true)                                   // buns don't matter here
        let s = try XCTUnwrap(StudySession.lesson(course.lessons[0].id, p))
        let total = s.sessionTotal
        // the fourth exercise is missed
        var asked = 0, n = 0
        while s.result == nil && n < 100 && asked < 3 {
            n += 1
            if s.card != nil { s.answer(true); asked += 1 }
            s.next()
        }
        toNextExercise(s)
        let missed = try XCTUnwrap(s.card)
        XCTAssertFalse(s.previousMistake)
        s.answer(false)
        asked += 1
        XCTAssertEqual(s.retries.map(\.id), [missed.id], "it waits in the mistakes stretch")
        let planned = s.queue.filter { if case .meet = $0 { return false } else { return true } }.count
        XCTAssertGreaterThan(planned, 0)
        s.next()

        // the planned exercises, none of them labelled; then the mistake, labelled
        var between = 0, cameBack = false
        n = 0
        while s.result == nil && n < 300 {
            n += 1
            if case .match(let cards, _) = s.current { for c in cards { _ = s.matchPair(c.id, c.id) }; between += 1 }
            if let c = s.card {
                asked += 1
                if s.previousMistake {
                    XCTAssertEqual(c.id, missed.id)
                    XCTAssertTrue(s.queue.isEmpty, "after everything planned")
                    XCTAssertEqual(between, planned)
                    cameBack = true
                } else {
                    XCTAssertFalse(cameBack, "nothing planned comes after the mistakes stretch")
                    between += 1
                }
                s.answer(true)
            }
            s.next()
        }
        XCTAssertNotNil(s.result, "the session finishes")
        XCTAssertTrue(cameBack, "the missed word came back before the end")
        XCTAssertTrue(s.retries.isEmpty)
        XCTAssertEqual(s.stepsDone, total)
        XCTAssertEqual(s.progressFraction, 1)
        XCTAssertEqual(s.result?.lessonFinished, true)
    }

    func testAMissedWordIsNeverTheVeryNextExerciseWhileOthersRemain() throws {
        let p = store()
        p.setPlus(true)
        // stone 1, then stone 2 with its reviews: mistakes all the way through, some of them
        // in the mistakes stretch itself
        for lesson in course.lessons[0..<2] {
            let s = try XCTUnwrap(StudySession.lesson(lesson.id, p))
            var asked = 0, misses = 0, n = 0
            var owed: [String: Int] = [:]                 // mistakes not yet come back, per word
            while s.result == nil && n < 400 {
                n += 1
                if case .match(let cards, _) = s.current { for c in cards { _ = s.matchPair(c.id, c.id) } }
                guard let c = s.card else { s.next(); continue }
                asked += 1
                if s.previousMistake {
                    XCTAssertTrue(s.queue.isEmpty, "the mistakes stretch comes last")
                    XCTAssertGreaterThan(owed[c.id] ?? 0, 0, "\(c.word.hanzi) was missed")
                    owed[c.id, default: 0] -= 1
                }
                let wrong = misses < 6 && asked % 3 == 0
                guard wrong else { s.answer(true); s.next(); continue }
                misses += 1
                s.answer(false)
                owed[c.id, default: 0] += 1
                XCTAssertEqual(s.retries.last?.id, c.id)
                // what else is left to ask
                let others = !s.queue.isEmpty || s.retries.contains { $0.id != c.id }
                s.next()
                XCTAssertNil(s.result, "a missed word always comes back")
                if others && s.previousMistake {
                    XCTAssertNotEqual(s.card?.id, c.id, "\(c.word.hanzi) came straight back")
                }
                if !others {
                    XCTAssertEqual(s.card?.id, c.id, "the only thing left")
                    XCTAssertTrue(s.previousMistake)
                }
            }
            XCTAssertNotNil(s.result, "the session finishes")
            XCTAssertEqual(misses, 6)
            XCTAssertTrue(s.retries.isEmpty)
            XCTAssertTrue(owed.values.allSatisfy { $0 == 0 }, "every mistake came back before the end")
            XCTAssertEqual(s.progressFraction, 1)
            XCTAssertEqual(s.result?.lessonFinished, true, "\(lesson.id) completes despite the mistakes")
        }
    }
}
