import XCTest
@testable import Bubu

/// The Classroom's Vocabulary: its garden and today's words, worked out quickly, and the search, in English,
/// 汉字 or pinyin.
final class VocabRoomTests: XCTestCase {
    let course = Course.shared

    private func store() -> ProgressStore {
        ProgressStore(course: course, url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json"))
    }

    func testANewLearnerHasTodaysWordsFromTheFirstLesson() {
        let g = VocabGarden(store())
        XCTAssertTrue(g.growing.isEmpty)
        XCTAssertTrue(g.blooming.isEmpty)
        XCTAssertFalse(g.fresh.isEmpty)
        XCTAssertFalse(g.today.isEmpty)
        XCTAssertLessThanOrEqual(g.today.count, 12)
        // only the lessons reached: the first
        let first = course.lessons[0].id
        XCTAssertTrue(g.fresh.allSatisfy { $0.lessonId == first })
        XCTAssertTrue(g.today.allSatisfy { !$0.isSentence })
    }

    func testWordsLearntGrowAndTodayPutsThemFirst() {
        let p = store()
        for l in course.lessons.prefix(4) { p.markDone(l.id) }
        let learnt = course.cards(in: course.lessons[1].id).filter { !$0.isSentence }.prefix(3)
        for c in learnt { p.review(c.id, .good) }
        let g = VocabGarden(p)
        for c in learnt { XCTAssertTrue(g.growing.contains { $0.id == c.id } || g.blooming.contains { $0.id == c.id }) }
        XCTAssertTrue(learnt.allSatisfy { c in g.today.contains { $0.id == c.id } })
        XCTAssertEqual(Set(g.today.map(\.id)).count, g.today.count)
    }

    func testTheGardenIsQuick() {
        let p = store()
        for l in course.lessons.prefix(40) { p.markDone(l.id) }
        let t0 = CFAbsoluteTimeGetCurrent()
        _ = VocabGarden(p)
        XCTAssertLessThan((CFAbsoluteTimeGetCurrent() - t0) * 1000, 150)
    }

    func testSearchFindsAWordByItsHanziPinyinOrMeaning() {
        let c = course.cards.first { !$0.isSentence && $0.word.hanzi.count == 2 && $0.word.en.count > 2 && $0.word.en.allSatisfy(\.isLetter) }!
        XCTAssertEqual(VocabSearch.find(c.word.hanzi).first?.word.hanzi, c.word.hanzi)
        XCTAssertTrue(VocabSearch.find(c.word.en).contains { $0.word.hanzi == c.word.hanzi })
        let py = Pinyin.toneless(c.word.pinyin).replacingOccurrences(of: " ", with: "")
        XCTAssertTrue(VocabSearch.find(py).contains { $0.word.hanzi == c.word.hanzi })
        XCTAssertTrue(VocabSearch.find("").isEmpty)
        XCTAssertLessThanOrEqual(VocabSearch.find("a").count, 40)
        XCTAssertTrue(VocabSearch.find("a").allSatisfy { !$0.isSentence })
    }

    func testFlashcardsEndAsALessonDoes() {
        let p = store()
        let cards = Array(course.cards.filter { !$0.isSentence }.prefix(6))
        let s = StudySession.flashcards(p, cards: cards)
        let xp0 = p.xpTotal
        for c in cards { s.flashcard(c, gotIt: true) }
        XCTAssertEqual(s.combo, 6)
        s.flashcard(cards[0], gotIt: false)
        XCTAssertEqual(s.combo, 0)
        XCTAssertNil(s.result)
        s.finishFlashcards()
        let r = s.result
        XCTAssertEqual(r?.title, "Flashcards done!")
        XCTAssertGreaterThan(r?.xp ?? 0, 0)
        XCTAssertGreaterThanOrEqual(p.xpTotal - xp0, r?.xp ?? 0)
        XCTAssertNil(s.exercise)
        XCTAssertEqual(s.again().title, "Review")
        // each answer scheduled the word
        XCTAssertTrue(cards.allSatisfy { p.srs[$0.id] != nil })
    }

    func testMatchingEndsAsALessonDoes() {
        let p = store()
        let cards = Array(course.cards.filter { !$0.isSentence }.prefix(5))
        let s = StudySession.matching(p, cards: cards)
        for c in cards { s.matchTapped(c, right: true) }
        XCTAssertEqual(s.combo, 5)
        // a wrong pair breaks the run, but marks no word forgotten
        let before = p.srs[cards[0].id]
        s.matchTapped(cards[0], right: false)
        XCTAssertEqual(s.combo, 0)
        XCTAssertEqual(p.srs[cards[0].id], before)
        s.finishFlashcards()
        XCTAssertEqual(s.result?.title, "Matching done!")
        XCTAssertGreaterThan(s.result?.xp ?? 0, 0)
        XCTAssertLessThan(s.result?.accuracy ?? 100, 100)
        XCTAssertEqual(s.again().title, "Review")
    }

    func testTheExactPinyinComesFirst() {
        // 医生 yī shēng before 一身 yī shēn, which "yisheng" starts like
        XCTAssertEqual(VocabSearch.find("yisheng").first?.word.hanzi, "医生")
        XCTAssertEqual(VocabSearch.find("yi sheng").first?.word.hanzi, "医生")
        XCTAssertEqual(VocabSearch.find("yishen").first?.word.hanzi, "一身")
    }

    func testAWholeWordComesBeforeOneThatStartsWithIt() {
        // "eat" finds a word meaning eat before one meaning "eaten up" or the like
        let r = VocabSearch.find("eat")
        guard let i = r.firstIndex(where: { $0.word.en.lowercased().split(whereSeparator: { !$0.isLetter }).contains("eat") }) else { return }
        let j = r.firstIndex { !$0.word.en.lowercased().split(whereSeparator: { !$0.isLetter }).contains("eat") } ?? r.count
        XCTAssertLessThan(i, j)
    }
}
