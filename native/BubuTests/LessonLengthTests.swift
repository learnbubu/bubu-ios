import XCTest
@testable import Bubu

/// A stone's session is Duolingo-length (~15 exercises): each new word comes up several
/// times, easy to hard and spaced apart, and earlier words fill the rest as review.
/// "Which pinyin?" waits until the tones have been introduced.
final class LessonLengthTests: XCTestCase {
    let course = Course.shared

    private func store() -> ProgressStore {
        ProgressStore(course: course, url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json"))
    }
    private var chapter1: [Lesson] { course.chapters[0].lessons.map { course.lessonById[$0]! } }

    /// One step of a session played through: a word met, or an exercise on a word.
    private struct Step { let meet: Bool; let id: String; let hanzi: String; let dir: String }

    /// Plays a session through, every answer right, and returns what came up.
    private func play(_ s: StudySession) -> [Step] {
        var steps: [Step] = [], n = 0
        while s.result == nil && n < 300 {
            n += 1
            if case .meet(let cards, _, _) = s.current {
                for c in cards { steps.append(Step(meet: true, id: c.id, hanzi: c.word.hanzi, dir: "")) }
            }
            if let c = s.card {
                steps.append(Step(meet: false, id: c.id, hanzi: c.word.hanzi, dir: s.dir))
                s.answer(true)
            }
            s.next()
        }
        XCTAssertNotNil(s.result, "the session finishes")
        return steps
    }

    /// The new words: each met before its first exercise, at least three exercises each,
    /// never twice in a row.
    private func checkNewWords(_ steps: [Step], _ fresh: [Card], file: StaticString = #filePath, line: UInt = #line) {
        let ex = steps.filter { !$0.meet }
        var met = Set<String>()
        for st in steps {
            if st.meet { met.insert(st.id) }
            else if fresh.contains(where: { $0.id == st.id }) {
                XCTAssertTrue(met.contains(st.id), "\(st.hanzi) is met before its first exercise", file: file, line: line)
            }
        }
        for c in fresh {
            XCTAssertGreaterThanOrEqual(ex.filter { $0.id == c.id }.count, 3, "\(c.word.hanzi) comes up 3+ times", file: file, line: line)
        }
        for i in ex.indices.dropFirst() {
            XCTAssertNotEqual(ex[i].id, ex[i - 1].id, "\(ex[i].hanzi) twice in a row at \(i + 1)", file: file, line: line)
        }
    }

    // MARK: the numbers

    func testTheShapeNumbers() {
        XCTAssertEqual(StudySession.stoneLen, 15)
        XCTAssertEqual(StudySession.baseReps(new: 2), 4)
        XCTAssertEqual(StudySession.baseReps(new: 3), 4)
        XCTAssertEqual(StudySession.baseReps(new: 5), 3)
        XCTAssertEqual(StudySession.reviewsWanted(new: 3), 3)
        XCTAssertEqual(StudySession.reviewsWanted(new: 2), 7)
        XCTAssertEqual(StudySession.reviewsWanted(new: 5), 0)
        XCTAssertEqual(StudySession.repsPerNew(new: 3, reviews: 0), 5, "the first stone: 3 words × 5")
        XCTAssertEqual(StudySession.repsPerNew(new: 3, reviews: 3), 4)
        XCTAssertEqual(StudySession.repsPerNew(new: 2, reviews: 7), 4)
        XCTAssertEqual(StudySession.repsPerNew(new: 5, reviews: 0), 3)
    }

    // MARK: stone 1, the showcase

    /// The very first stone (你 · 好 · 你好) has no earlier words: its own words come up five
    /// times each, recognise → listen → recall, the kinds alternating. This is the exact
    /// sequence to compare with the phone.
    func testTheFirstStoneIsFifteenVariedExercises() {
        let p = store()
        let stone = chapter1[0]
        let fresh = course.cards(in: stone.id)
        XCTAssertEqual(fresh.map(\.word.hanzi), ["你", "好", "你好"])
        let s = StudySession(lessonId: stone.id, progress: p)
        XCTAssertTrue(s.stoneShaped)
        XCTAssertFalse(s.tonesTaught)
        XCTAssertEqual(s.sessionTotal, 15)
        let steps = play(s)
        let ex = steps.filter { !$0.meet }
        XCTAssertEqual(ex.count, s.sessionTotal, "the progress bar counts every exercise")
        checkNewWords(steps, fresh)
        for c in fresh { XCTAssertEqual(ex.filter { $0.id == c.id }.count, 5, c.word.hanzi) }
        XCTAssertTrue(ex.allSatisfy { ["recognize", "listen", "recall"].contains($0.dir) }, "\(ex.map(\.dir))")
        let got = steps.map { $0.meet ? "meet \($0.hanzi)" : "\($0.dir) \($0.hanzi)" }
        XCTAssertEqual(got, [
            "meet 你", "recognize 你",
            "meet 好", "recognize 好",
            "listen 你",
            "meet 你好", "recognize 你好",
            "listen 好", "recall 你", "listen 你好", "recall 好", "listen 你", "recall 你好",
            "listen 好", "recall 你", "listen 你好", "recognize 好", "recall 你好",
        ])
        // after its meet card, a word's first exercise is the easy one
        for (i, st) in steps.enumerated() where st.meet {
            XCTAssertEqual(steps[i + 1].id, st.id)
            XCTAssertEqual(steps[i + 1].dir, "recognize")
        }
        XCTAssertTrue(p.isDone(stone.id))
    }

    /// The extra practice doesn't push a new word's first review further out than two right
    /// answers would.
    func testExtraPracticeDoesntStretchTheFirstReview() {
        let p = store()
        _ = play(StudySession(lessonId: chapter1[0].id, progress: p))
        for c in course.cards(in: chapter1[0].id) { XCTAssertEqual(p.srs[c.id]?.reps, StudySession.scheduledPerSession, c.word.hanzi) }
    }

    // MARK: the next stones

    /// Stones 2 and 3 have few earlier words: they come round, and the new words come up more.
    func testTheEarlyStonesAreFullLengthToo() {
        let p = store()
        _ = play(StudySession(lessonId: chapter1[0].id, progress: p))
        for stone in chapter1[1...2] {
            let s = StudySession(lessonId: stone.id, progress: p)
            XCTAssertTrue((14...16).contains(s.sessionTotal), "\(stone.id): \(s.sessionTotal)")
            let steps = play(s)
            XCTAssertEqual(steps.filter { !$0.meet }.count, s.sessionTotal)
            checkNewWords(steps, course.cards(in: stone.id))
            XCTAssertTrue(p.isDone(stone.id))
        }
    }

    /// A stone further on, with three new words and plenty of earlier ones: 14–16 exercises,
    /// each new word 3+ times and spaced, earlier words (from stones before it) filling the rest.
    func testAMidCourseStoneWithThreeNewWords() throws {
        let p = store()
        let i = try XCTUnwrap(course.lessons.indices.first { $0 >= 10 && !course.lessons[$0].isPractice && course.cards(in: course.lessons[$0].id).count == 3 })
        let stone = course.lessons[i]
        for l in course.lessons[..<i] {
            for c in course.cards(in: l.id) { p.seedKnown(c.id) }
            p.markDone(l.id)
        }
        let fresh = course.cards(in: stone.id)
        let s = StudySession(lessonId: stone.id, progress: p)
        XCTAssertTrue((14...16).contains(s.sessionTotal), "\(s.sessionTotal)")
        let steps = play(s)
        let ex = steps.filter { !$0.meet }
        XCTAssertEqual(ex.count, s.sessionTotal)
        checkNewWords(steps, fresh)
        let reviews = ex.filter { st in !fresh.contains { $0.id == st.id } }
        XCTAssertEqual(reviews.count, StudySession.reviewsWanted(new: 3))
        let earlier = Set(course.lessons[..<i].flatMap { course.cards(in: $0.id) }.map(\.id))
        for r in reviews { XCTAssertTrue(earlier.contains(r.id), "\(r.hanzi) is an earlier word") }
        // each new word's exercises climb: its first is the easy one
        for c in fresh {
            XCTAssertTrue(["recognize", "listen"].contains(ex.first { $0.id == c.id }?.dir ?? ""), c.word.hanzi)
        }
        XCTAssertTrue(p.isDone(stone.id))
    }

    /// A mistake still sends the word round again, and the bar still ends full.
    func testMistakesStillComeBack() {
        let p = store()
        let s = StudySession(lessonId: chapter1[0].id, progress: p)
        let total = s.sessionTotal
        var n = 0, missed = false, asked = 0
        while s.result == nil && n < 300 {
            n += 1
            if s.card != nil {
                asked += 1
                if !missed && asked == 3 { s.answer(false); missed = true } else { s.answer(true) }
            }
            s.next()
        }
        XCTAssertEqual(asked, total + 1)
        XCTAssertEqual(s.progressFraction, 1)
    }

    // MARK: practice stones

    func testAPracticeStoneIsAboutFifteenExercises() throws {
        let p = store()
        for l in chapter1[0..<3] { _ = play(StudySession(lessonId: l.id, progress: p)) }
        let s = try XCTUnwrap(StudySession.lesson(chapter1[3].id, p))
        XCTAssertTrue(s.isPractice)
        XCTAssertFalse(s.stoneShaped)
        XCTAssertTrue((14...16).contains(s.sessionTotal), "\(s.sessionTotal)")
        XCTAssertEqual(play(s).count, s.sessionTotal)
    }

    // MARK: tones

    /// The tones are introduced on chapter 1's first practice stone; no "Which pinyin?" before.
    func testTheTonesStoneIsChapterOnesFirstPractice() {
        XCTAssertEqual(StudySession.tonesStone, chapter1[3].id)
        let p = store()
        for l in chapter1[0..<3] { XCTAssertFalse(StudySession.tonesIntroduced(l.id, mode: .lesson, p), l.id) }
        XCTAssertTrue(StudySession.tonesIntroduced(chapter1[3].id, mode: .lesson, p))
        XCTAssertTrue(StudySession.tonesIntroduced(chapter1[4].id, mode: .lesson, p))
        XCTAssertFalse(StudySession.tonesIntroduced("", mode: .review, p))
        p.markDone(chapter1[3].id)
        XCTAssertTrue(StudySession.tonesIntroduced("", mode: .review, p))
    }

    func testNoPinyinExerciseBeforeTheTones() throws {
        for _ in 0..<3 {
            let p = store()
            for l in chapter1[0..<3] {
                let s = StudySession(lessonId: l.id, progress: p)
                XCTAssertFalse(s.showsTonesIntro, l.id)
                for st in play(s) where !st.meet { XCTAssertNotEqual(st.dir, "pinyin", "\(l.id): \(st.hanzi)") }
            }
            // a quiz or a review before the tones stone asks no pinyin either
            let words = chapter1[0..<3].flatMap { course.cards(in: $0.id) }
            let quiz = try XCTUnwrap(StudySession.quiz(p, cards: words))
            for st in play(quiz) { XCTAssertNotEqual(st.dir, "pinyin", st.hanzi) }
            let review = StudySession(lessonId: "", progress: p, cards: words, mode: .review, title: "Review")
            for st in play(review) { XCTAssertNotEqual(st.dir, "pinyin", st.hanzi) }
            // from the tones stone on, it may
            XCTAssertTrue(try XCTUnwrap(StudySession.lesson(chapter1[3].id, p)).tonesTaught)
        }
    }
}
