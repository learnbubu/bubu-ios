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

    // MARK: whole sentences taught as one item

    /// The owner: a sentence (请再说一遍, 这个用中文怎么说？) is never a multiple-choice question
    /// or option; it's read, and its English built from tiles.
    func testWholeSentencesAreOnlyEverBuiltFromTiles() {
        for s in ["请再说一遍", "请说慢一点儿", "我不懂"] { XCTAssertTrue(card(s).isSentence, s) }
        for w in ["不客气", "对不起", "你好", "什么时候", "你呢", "大床房", "问得好"] { XCTAssertFalse(card(w).isSentence, w) }
        // its own text is the sentence, split into its words, Chinese to English
        let slow = card("请说慢一点儿")
        let own = try! XCTUnwrap(slow.ownSentence)
        XCTAssertEqual(own.words.map(\.hanzi).joined(), "请说慢一点儿")
        XCTAssertEqual(own.hanzi, slow.word.hanzi)
        let p = store()
        let ex = try! XCTUnwrap(Exercise.make(card: slow, dir: "sentence", scope: [], progress: p))
        XCTAssertEqual(ex.kind, .sentence)
        XCTAssertFalse(ex.toChinese)
        XCTAssertEqual(ex.sentence?.hanzi, "请说慢一点儿")
        XCTAssertTrue(Set(Sentence.enWords(own.en)).isSubset(of: Set(ex.tiles.map(\.text))))
        // and none is ever an option beside a word
        let sentences = course.cards.filter(\.isSentence)
        let banned = Set(sentences.map(\.word.hanzi) + sentences.map(\.word.gloss))
        let chapter2 = course.chapters[1].lessons.flatMap { course.cards(in: $0) }.filter { !$0.isSentence }
        let scope = Set(course.chapters[0].lessons + course.chapters[1].lessons)
        for c in chapter2 {
            for dir in ["recognize", "recall", "listen"] {
                for _ in 0..<5 {
                    let options = Exercise.choice(c, dir: dir, scope: scope).options
                    XCTAssertTrue(banned.isDisjoint(with: options), "\(c.word.hanzi) \(dir): \(options)")
                }
            }
        }
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
        // 谢谢！再见！ for 再见: fine once 谢谢 has been met, not before (its own sentence, so a
        // rewrite of the course's dialogues can't take it away)
        let s = Sentence(hanzi: "谢谢！再见！", pinyin: "xièxie! zàijiàn!", en: "Thanks! Bye!",
                         words: [.init(hanzi: "谢谢", pinyin: "xièxie"), .init(hanzi: "再见", pinyin: "zàijiàn")])
        XCTAssertEqual(course.unmetWords(in: s, for: bye, met: { $0 == thanks.id }).count, 0)
        XCTAssertEqual(course.unmetWords(in: s, for: bye, met: { _ in false }).count, 1)
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
        for c in course.cards(in: course.lessons[4].id) {
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

    /// A stone holds at most five new words and a session teaches up to six, so one session
    /// finishes it: no steps, and the next stone opens.
    func testOneSessionFinishesAStoneAndOpensTheNext() {
        let p = store()
        let lid = course.lessons[0].id
        XCTAssertEqual(StudySession.lessonSteps(lid, p).total, 1, "a stone is one step")
        let r = play(StudySession(lessonId: lid, progress: p))
        XCTAssertTrue(r.lessonFinished)
        XCTAssertEqual(r.title, "Lesson complete!")
        XCTAssertEqual(r.steps, 0)
        XCTAssertTrue(p.isDone(lid))
        XCTAssertEqual(p.currentLessonId, course.lessons[1].id, "the next stone opens")
        XCTAssertEqual(r.nextLessonId, course.lessons[1].id)
    }

    /// Words met but not yet right (a session left half-way) all come back in the last
    /// step, even more than the usual reviews, so it still finishes the lesson.
    func testTheLastStepBringsBackEveryWordNotYetRight() {
        let p = store()
        let lid = course.lessons.first { course.cards(in: $0.id).count == 5 }!.id
        let cards = course.cards(in: lid)
        let first = StudySession.buildQueue(lessonId: lid, progress: p, focuses: p.selectedFocuses).filter { $0.lessonId == lid }
        // the first step's words were all met, and all missed
        for c in first { _ = p.answer(c.id, correct: false, dir: "recognize", sessionStart: 0, mistakesMode: false) }
        XCTAssertGreaterThan(first.count, StudySession.reviewsWanted(new: first.count))
        let last = StudySession.buildQueue(lessonId: lid, progress: p, focuses: p.selectedFocuses)
        XCTAssertTrue(Set(cards.map(\.id)).isSubset(of: Set(last.map(\.id))))
        let r = play(StudySession(lessonId: lid, progress: p))
        XCTAssertTrue(r.lessonFinished)
        XCTAssertTrue(p.isDone(lid))
    }
}
