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

    func testAWholeWordComesBeforeOneThatStartsWithIt() {
        // "eat" finds a word meaning eat before one meaning "eaten up" or the like
        let r = VocabSearch.find("eat")
        guard let i = r.firstIndex(where: { $0.word.en.lowercased().split(whereSeparator: { !$0.isLetter }).contains("eat") }) else { return }
        let j = r.firstIndex { !$0.word.en.lowercased().split(whereSeparator: { !$0.isLetter }).contains("eat") } ?? r.count
        XCTAssertLessThan(i, j)
    }
}
