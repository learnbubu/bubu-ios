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

    // MARK: the stones' practice sentences (Duolingo's shape)

    /// Each stone of the first book has sentences of its own, made only of words taught by then
    /// (names aside), so a lesson is sentences from its second stone on, not one word from four.
    func testEveryDrillReadsWithTheWordsTaughtByItsStone() throws {
        let drills = try XCTUnwrap(course.data.drills)
        XCTAssertGreaterThanOrEqual(drills.count, 170)
        let order = course.lessonOrder
        for d in drills {
            let at = try XCTUnwrap(order[d.lesson], d.lesson)
            guard let words = Sentence.segment(hanzi: d.hanzi, pinyin: d.pinyin) else { continue }   // one word: 你好！
            let taught: (String) -> Bool = { id in
                self.course.cards.first { $0.id == id }.map { (order[$0.lessonId] ?? .max) <= at } ?? false
            }
            let s = Sentence(hanzi: d.hanzi, pinyin: d.pinyin, en: d.en, words: words)
            for c in course.cards(in: d.lesson) where d.hanzi.contains(c.word.hanzi) {
                XCTAssertEqual(course.unmetWords(in: s, for: c, met: taught), [], d.hanzi)
            }
            XCTAssertTrue(course.sentences.contains { $0.hanzi == d.hanzi }, d.hanzi)
        }
    }

    /// Fill the gap: the word is left out of a sentence it stands in, and chosen from four
    /// words (never a whole sentence among them).
    func testAGapLeavesOutTheWordAndOffersFourWords() throws {
        let shi = card("是")
        let met: (String) -> Bool = { _ in true }
        XCTAssertFalse(course.gapSentences(for: shi, met: met).isEmpty)
        for _ in 0..<20 {
            let ex = try XCTUnwrap(Exercise.make(card: shi, dir: "gap", scope: [shi.lessonId], progress: store(), met: met))
            XCTAssertEqual(ex.kind, .choice)
            XCTAssertEqual(ex.dir, "gap")
            XCTAssertEqual(ex.answer, "是")
            XCTAssertEqual(ex.options.count, 4)
            XCTAssertEqual(Set(ex.options).count, 4)
            XCTAssertTrue(ex.options.contains("是"))
            let sent = try XCTUnwrap(ex.sentence)
            XCTAssertEqual(sent.words.filter { $0.hanzi == "是" }.count, 1, sent.hanzi)
            for o in ex.options where o != "是" {
                XCTAssertFalse(sent.words.contains { $0.hanzi == o }, "\(o) is in \(sent.hanzi)")
                XCTAssertFalse(card(o).isSentence, o)
            }
            XCTAssertEqual(ex.label, "Fill the gap")
            XCTAssertEqual(ChoicePick().verdict(ex), nil)
        }
        // a word that only stands inside another (你 in 你好，马克！) has no gap to fill
        let hello = Sentence(hanzi: "你好，马克！", pinyin: "nǐhǎo, Mǎkè!", en: "Hello, Mark!",
                             words: [.init(hanzi: "你好", pinyin: "nǐhǎo"), .init(hanzi: "马克", pinyin: "Mǎkè")])
        XCTAssertEqual(hello.words.filter { $0.hanzi == "你" }.count, 0)
        XCTAssertNil(Exercise.make(card: card("你"), dir: "gap", scope: [], progress: store(), met: { _ in false }))
    }

    /// A stone's own practice sentence is asked before a dialogue's line.
    func testPracticeSentencesComeBeforeDialogueLines() {
        let shi = card("是")
        let chosen = course.sentences(for: shi, met: { _ in true })
        XCTAssertFalse(chosen.isEmpty)
        XCTAssertTrue(chosen.allSatisfy { Course.drillTexts.contains($0.hanzi) }, "\(chosen.map(\.hanzi))")
    }

    /// Tap what you hear: the sentence is only said, and built from Chinese tiles.
    func testTapWhatYouHearIsBuiltFromChineseTiles() throws {
        let shi = card("是")
        let ex = try XCTUnwrap(Exercise.make(card: shi, dir: "hear", scope: [], progress: store(), met: { _ in true }))
        XCTAssertEqual(ex.kind, .sentence)
        XCTAssertEqual(ex.dir, "hear")
        XCTAssertTrue(ex.hearOnly)
        XCTAssertTrue(ex.toChinese)
        XCTAssertEqual(ex.label, "Tap what you hear")
        let sent = try XCTUnwrap(ex.sentence)
        XCTAssertTrue(Set(sent.words.map(\.hanzi)).isSubset(of: Set(ex.tiles.map(\.text))))
        // it's said as it appears whatever the autoplay setting, and its tiles keep quiet until it's answered
        XCTAssertEqual(Autoplay.onShow(ex, autoplay: false), sent.hanzi)
        XCTAssertNil(TapToHear.tile(ex.tiles[0], in: ex, answered: false))
        XCTAssertNotNil(TapToHear.tile(ex.tiles.first { $0.text.contains(where: Course.isHan) }!, in: ex, answered: true))
        // an ordinary sentence exercise isn't one
        let plain = try XCTUnwrap(Exercise.make(card: shi, dir: "sentence", scope: [], progress: store(), met: { _ in true }))
        XCTAssertFalse(plain.hearOnly)
        XCTAssertEqual(plain.dir, "sentence")
    }

    /// The second stone (我 · 是) has sentences in it: 我是马克。 built, heard, a gap filled.
    /// (Which kinds come up depends on the earlier words' reviews, so five lessons are played.)
    func testTheSecondStoneHasSentences() {
        var all: [String] = []
        for _ in 0..<5 {
            let p = store()
            _ = play(StudySession(lessonId: course.lessons[0].id, progress: p))
            let s = StudySession(lessonId: course.lessons[1].id, progress: p)
            let fresh = Set(course.cards(in: course.lessons[1].id).map(\.id))
            var dirs: [String] = [], n = 0
            while s.result == nil && n < 300 {
                n += 1
                if let c = s.card, let ex = s.exercise {
                    if fresh.contains(c.id) { dirs.append(ex.dir) }
                    if let sent = ex.sentence, ex.kind != .speak {
                        XCTAssertEqual(course.unmetWords(in: sent, for: c, met: s.isMet), [], sent.hanzi)
                    }
                    s.answer(true)
                }
                s.next()
            }
            XCTAssertGreaterThanOrEqual(dirs.filter { StudySession.sentenceKinds.contains($0) }.count, 1, "\(dirs)")
            XCTAssertLessThanOrEqual(dirs.filter { $0 == "write" }.count, 1, "\(dirs)")
            XCTAssertLessThanOrEqual(dirs.filter { $0 == "speak" }.count, 1, "\(dirs)")
            all += dirs
        }
        XCTAssertGreaterThanOrEqual(all.filter { StudySession.sentenceKinds.contains($0) }.count, 10, "\(all)")
        XCTAssertTrue(all.contains("gap") || all.contains("hear"), "\(all)")
    }

    /// "Can't listen now" on a sentence that's only heard puts off listening, like the word kind.
    func testCantListenNowAlsoStopsTapWhatYouHear() {
        let p = store()
        _ = play(StudySession(lessonId: course.lessons[0].id, progress: p))
        let s = StudySession(lessonId: course.lessons[1].id, progress: p)
        var n = 0, skipped = false
        while s.result == nil && n < 300 {
            n += 1
            if s.card != nil, let ex = s.exercise {
                if skipped { XCTAssertFalse(["listen", "hear"].contains(ex.dir), ex.dir) }
                if !skipped, ex.dir == "hear" || ex.dir == "listen" {
                    s.skip()
                    skipped = true
                    XCTAssertTrue(s.listeningOff)
                } else {
                    s.answer(true)
                }
            }
            s.next()
        }
        XCTAssertNotNil(s.result)
    }

    /// The quick check agrees with the full list of unmet words, for a learner part-way through.
    func testReadableAgreesWithUnmetWords() {
        let known = Set(course.lessons.prefix(30).flatMap { course.cards(in: $0.id) }.map(\.id))
        let met: (String) -> Bool = { known.contains($0) }
        for c in course.lessons.prefix(40).flatMap({ course.cards(in: $0.id) }) {
            for s in course.sentences(for: c).prefix(40) {
                XCTAssertEqual(course.isReadable(s, for: c, met: met), course.unmetWords(in: s, for: c, met: met).isEmpty,
                               "\(c.word.hanzi) in \(s.hanzi)")
            }
        }
    }

    /// "Which pinyin?" never offers as wrong a reading that is also right (the owner: Fà guó).
    func testNoWrongPinyinOptionThatIsAlsoRight() {
        XCTAssertTrue(Pinyin.isAlsoRight("Fà guó", hanzi: "法国", pinyin: "Fǎ guó"))
        XCTAssertFalse(Pinyin.isAlsoRight("Fǎ guō", hanzi: "法国", pinyin: "Fǎ guó"))
        XCTAssertTrue(Pinyin.isAlsoRight("ní hǎo", hanzi: "你好", pinyin: "nǐ hǎo"))
        XCTAssertFalse(Pinyin.isAlsoRight("nǐ háo", hanzi: "你好", pinyin: "nǐ hǎo"))
        XCTAssertTrue(Pinyin.isAlsoRight("bú shì", hanzi: "不是", pinyin: "bù shì"))
        XCTAssertTrue(Pinyin.isAlsoRight("yì diǎn r", hanzi: "一点儿", pinyin: "yī diǎn r"))
        XCTAssertFalse(Pinyin.isAlsoRight("Fǎ guó", hanzi: "法国", pinyin: "Fǎ guó"), "the answer itself isn't a wrong option")
        if let france = course.cards.first(where: { $0.word.hanzi == "法国" }) {
            for _ in 0..<30 {
                let ex = Exercise.choice(france, dir: "pinyin", scope: [france.lessonId])
                for o in ex.options where o != ex.answer {
                    XCTAssertFalse(Pinyin.isAlsoRight(o, hanzi: "法国", pinyin: ex.answer), o)
                }
            }
        }
    }

    /// The owner's report: "Sure!" over 好啊 hinted 啊. A meaning's Chinese example doesn't
    /// count, a particle is never an English word's hint, and a one-word English is the whole.
    func testEnglishHintsDontComeFromExamplesOrParticles() {
        let words = [SentenceWord(hanzi: "好", pinyin: "hǎo"), SentenceWord(hanzi: "啊", pinyin: "a")]
        let sure = Hints.english("Sure!", words)
        XCTAssertEqual(sure.first?.word?.hanzi, "好啊")
        let mixed = Hints.english("Yes! Can you speak Chinese?", [SentenceWord(hanzi: "会", pinyin: "huì"), SentenceWord(hanzi: "你", pinyin: "nǐ"),
                                                                   SentenceWord(hanzi: "会", pinyin: "huì"), SentenceWord(hanzi: "说", pinyin: "shuō"),
                                                                   SentenceWord(hanzi: "中文", pinyin: "zhōngwén"), SentenceWord(hanzi: "吗", pinyin: "ma")])
        XCTAssertNil(mixed.first?.word, "Yes isn't 吗")
        let lets = Hints.english("Let's go together!", [SentenceWord(hanzi: "我们", pinyin: "wǒmen"), SentenceWord(hanzi: "一起", pinyin: "yīqǐ"),
                                                         SentenceWord(hanzi: "去", pinyin: "qù"), SentenceWord(hanzi: "吧", pinyin: "ba")])
        XCTAssertEqual(lets.first?.word?.hanzi, "吧", "吧 is let's")
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
