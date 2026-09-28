import XCTest
@testable import Bubu

/// Sentences only from words you've met, and a lesson's steps.
final class LessonFlowTests: XCTestCase {
    let course = Course.shared

    private func store() -> ProgressStore {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        return ProgressStore(course: course, url: url)
    }

    private func card(_ hanzi: String) -> Card {
        course.cards.first { $0.word.hanzi == hanzi }!
    }

    // MARK: the sentence rule

    func testALongSentenceOfNewWordsIsNeverChosen() {
        // the owner's report: 那我就不客气了…哇，是一本相册 on the very first stone
        let c = card("不客气")
        let long = course.sentences(for: c).first { $0.hanzi.contains("相册") }
        XCTAssertNotNil(long, "the course still has the sentence")
        let met = Set(course.cards(in: course.lessons[0].id).map(\.id))
        let ok = course.sentences(for: c, met: { met.contains($0) })
        XCTAssertFalse(ok.contains { $0.hanzi.contains("相册") })
        XCTAssertGreaterThanOrEqual(course.unmetWords(in: long!, for: c, met: { met.contains($0) }).count, 2)
    }

    func testOnlyTheCardsOwnWordMayBeNew() {
        let bye = card("再见"), thanks = card("谢谢")
        // 谢谢！再见！ for 再见: fine once 谢谢 has been met, not before
        let met = course.sentences(for: bye, met: { $0 == thanks.id })
        XCTAssertTrue(met.contains { $0.hanzi == "谢谢！再见！" })
        let none = course.sentences(for: bye, met: { _ in false })
        XCTAssertFalse(none.contains { $0.hanzi == "谢谢！再见！" })
    }

    func testParticlesDontCountAsNewWords() {
        let thanks = card("谢谢")
        let s = Sentence(hanzi: "谢谢啊！", pinyin: "xièxie a!", en: "Thanks!",
                         words: [.init(hanzi: "谢谢", pinyin: "xièxie"), .init(hanzi: "啊", pinyin: "a")])
        XCTAssertEqual(course.unmetWords(in: s, for: thanks, met: { _ in false }), [])
        let two = Sentence(hanzi: "谢谢相册", pinyin: "xièxie xiàngcè", en: "",
                           words: [.init(hanzi: "谢谢", pinyin: "xièxie"), .init(hanzi: "相册", pinyin: "xiàngcè")])
        XCTAssertEqual(course.unmetWords(in: two, for: thanks, met: { _ in false }), ["相册"])
    }

    func testShortSentencesArePreferred() {
        let everything: (String) -> Bool = { _ in true }
        for c in course.cards(in: course.lessons[3].id) {
            let all = course.sentences(for: c)
            let chosen = course.sentences(for: c, met: everything)
            if all.contains(where: { $0.words.count <= Course.shortSentence }) {
                XCTAssertTrue(chosen.allSatisfy { $0.words.count <= Course.shortSentence }, c.word.hanzi)
            }
        }
    }

    /// A whole first lesson: every sentence asked uses only words met by then.
    func testEverySentenceAskedUsesMetWords() {
        let p = store()
        let lid = course.lessons[0].id
        for _ in 0..<3 {
            let s = StudySession(lessonId: lid, progress: p)
            var n = 0
            while s.result == nil && n < 300 {
                n += 1
                if let c = s.card, let ex = s.exercise, ex.kind == .sentence, let sent = ex.sentence {
                    XCTAssertEqual(course.unmetWords(in: sent, for: c, met: s.isMet), [], sent.hanzi)
                }
                if s.card != nil { s.answer(true) }
                s.next()
            }
        }
    }

    // MARK: steps

    func testStepsFollowTheBatches() {
        XCTAssertEqual(StudySession.batches(0), 0)
        XCTAssertEqual(StudySession.batches(4), 1)
        XCTAssertEqual(StudySession.batches(6), 1)
        XCTAssertEqual(StudySession.batches(7), 2)
        XCTAssertEqual(StudySession.batches(12), 2)
        XCTAssertEqual(StudySession.batches(13), 3)
        XCTAssertEqual(StudySession.batches(15), 3)
    }

    private func play(_ s: StudySession) -> StudySession.Result {
        var n = 0
        while s.result == nil && n < 300 {
            n += 1
            if s.card != nil { s.answer(true) }
            s.next()
        }
        return s.result!
    }

    func testTheFinalStepCompletesTheLessonAndOpensTheNext() {
        let p = store()
        let lid = course.lessons[0].id, count = course.cards(in: lid).count
        let total = StudySession.batches(count)
        XCTAssertGreaterThan(total, 1, "the first lesson comes in steps")
        XCTAssertEqual(StudySession.lessonSteps(lid, p).step, 1)
        XCTAssertEqual(StudySession.lessonSteps(lid, p).total, total)
        for step in 1..<total {
            let r = play(StudySession(lessonId: lid, progress: p))
            XCTAssertFalse(r.lessonFinished)
            XCTAssertEqual(r.title, "Step \(step) of \(total) done")
            XCTAssertEqual(r.step, step)
            XCTAssertEqual(r.steps, total)
            XCTAssertGreaterThan(r.wordsLeft, 0)
            XCTAssertEqual(StudySession.lessonSteps(lid, p).step, step + 1)
            XCTAssertEqual(p.currentLessonId, lid, "the next stone stays shut until the lesson is done")
        }
        let r = play(StudySession(lessonId: lid, progress: p))
        XCTAssertTrue(r.lessonFinished)
        XCTAssertEqual(r.title, "Lesson complete!")
        XCTAssertEqual(r.steps, 0)
        XCTAssertTrue(p.isDone(lid))
        XCTAssertEqual(p.currentLessonId, course.lessons[1].id, "the next stone opens")
        XCTAssertEqual(r.nextLessonId, course.lessons[1].id)
    }

    /// Words met but not yet right (a session left half-way) all come back in the last
    /// step, even more than the usual four reviews, so it still finishes the lesson.
    func testTheLastStepBringsBackEveryWordNotYetRight() {
        let p = store()
        let lid = course.lessons[0].id
        let cards = course.cards(in: lid)
        let first = StudySession.buildQueue(lessonId: lid, progress: p, focuses: p.selectedFocuses).filter { $0.lessonId == lid }
        // the first step's words were all met, and all missed
        for c in first { _ = p.answer(c.id, correct: false, dir: "recognize", sessionStart: 0, mistakesMode: false) }
        XCTAssertGreaterThan(first.count, StudySession.reviewPerSession)
        let last = StudySession.buildQueue(lessonId: lid, progress: p, focuses: p.selectedFocuses)
        XCTAssertTrue(Set(cards.map(\.id)).isSubset(of: Set(last.map(\.id))))
        let r = play(StudySession(lessonId: lid, progress: p))
        XCTAssertTrue(r.lessonFinished)
        XCTAssertTrue(p.isDone(lid))
    }
}
