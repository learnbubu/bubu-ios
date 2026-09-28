import XCTest
@testable import Bubu

/// The course builds up slowly (bubu-course/docs/sequencing.md): stones of at most five new
/// words, words before the phrases made of them, short items first, and old progress carried over.
final class SequencingTests: XCTestCase {
    let course = Course.shared

    private func card(_ hanzi: String) -> Card {
        course.cards.first { $0.word.hanzi == hanzi }!
    }
    /// where a word is first taught
    private func stone(_ hanzi: String) -> Int {
        course.lessonOrder[card(hanzi).lessonId]!
    }

    func testNoStoneHasMoreThanFiveNewItems() {
        for l in course.lessons {
            XCTAssertLessThanOrEqual(course.cards(in: l.id).count, 5, l.id)
            XCTAssertLessThanOrEqual(l.words.count, 5, l.id)
            XCTAssertFalse(l.words.isEmpty, l.id)
        }
    }

    func testEveryPhrasesWordsComeInEarlierStones() {
        var phrases = 0
        for (i, l) in course.lessons.enumerated() {
            for w in l.words {
                guard let parts = w.parts else { continue }
                phrases += 1
                XCTAssertGreaterThanOrEqual(parts.count, 1, w.hanzi)
                for p in parts {
                    let at = course.cardsByHanzi[p]?.compactMap { course.lessonOrder[$0.lessonId] }.min()
                    XCTAssertNotNil(at, "\(w.hanzi): \(p) is never taught")
                    guard let at else { continue }
                    XCTAssertLessThan(at, i, "\(w.hanzi): \(p) comes in stone \(at), the phrase in \(i)")
                    // a long phrase waits two stones after its last word
                    if w.hanzi.count >= 6 { XCTAssertLessThanOrEqual(at, i - 2, "\(w.hanzi): \(p)") }
                }
            }
        }
        XCTAssertGreaterThan(phrases, 100)
    }

    /// The owner's examples from testing on an iPhone.
    func testSurvivalPhrasesComeAfterTheirWords() {
        for (phrase, words) in [("我不懂", ["我", "不", "懂"]),
                                ("这个用中文怎么说", ["这个", "用", "中文", "怎么", "说"]),
                                ("不客气", ["不", "客气"])] {
            for w in words { XCTAssertLessThan(stone(w), stone(phrase), "\(w) before \(phrase)") }
        }
        XCTAssertLessThanOrEqual(stone("你"), stone("你好"))
        XCTAssertLessThanOrEqual(stone("好"), stone("你好"))
    }

    func testTheFirstStonesTeachOnlyShortItems() {
        for l in course.lessons.prefix(3) {
            for w in l.words {
                XCTAssertLessThanOrEqual(w.hanzi.count, 2, "\(l.id): \(w.hanzi)")
                XCTAssertNil(w.parts, "\(l.id): \(w.hanzi)")
            }
        }
        XCTAssertEqual(course.lessons[0].words.map(\.hanzi).prefix(3), ["你", "好", "你好"])
    }

    func testOneSessionTeachesAWholeStone() {
        let most = course.lessons.map { course.cards(in: $0.id).count }.max()!
        XCTAssertGreaterThanOrEqual(StudySession.newPerSession, most)
        for l in course.lessons { XCTAssertEqual(StudySession.batches(course.cards(in: l.id).count), 1, l.id) }
    }

    func testWordsKeepTheirCardIds() {
        // the ids these words had before stones were cut to five (web v293)
        XCTAssertEqual(card("你").id, "qibu1-u1-1:0")
        XCTAssertEqual(card("你好").id, "qibu1-s0-1:0")
        XCTAssertEqual(card("我不懂").id, "qibu1-s0-1:8")
        XCTAssertEqual(card("懂").id.components(separatedBy: ":").first, "qibu4-u4-4")
    }

    // MARK: migration

    func testEveryOldLessonMapsToStonesThatExist() {
        let map = Backup.oldLessons
        XCTAssertGreaterThan(map.count, 300)
        for (old, stones) in map {
            XCTAssertNil(course.lessonById[old], "old id \(old) must not be a stone's id")
            for s in stones { XCTAssertNotNil(course.lessonById[s], "\(old) → \(s)") }
        }
        // every stone is fed by some old lesson
        let fed = Set(map.values.flatMap { $0 })
        for l in course.lessons { XCTAssertTrue(fed.contains(l.id), l.id) }
    }

    func testAFinishedOldLessonFinishesItsStones() {
        let map = Backup.oldLessons
        var from: [String: [String]] = [:]
        for (o, ss) in map { for s in ss { from[s, default: []].append(o) } }
        // all of 起步 1 finished in the old course
        let old = Set(map.keys.filter { $0.hasPrefix("qibu1-") })
        var done = old
        let (restoned, _) = Backup.migrateDone(&done, srs: [:])
        XCTAssertTrue(done.isDisjoint(with: old), "old ids are gone")
        for l in course.lessons {
            let feeders = from[l.id] ?? []
            XCTAssertEqual(done.contains(l.id), feeders.allSatisfy(old.contains), l.id)
        }
        XCTAssertGreaterThan(restoned, 20)
        // a word brought forward from a lesson not reached yet keeps its stone open
        XCTAssertFalse(done.contains(card("客气").lessonId))
        XCTAssertFalse(done.contains(card("懂").lessonId))
        XCTAssertTrue(done.contains(card("你").lessonId))
        XCTAssertTrue(done.contains(card("一").lessonId))
    }

    func testAStoneWhoseWordsAreAllKnownIsDoneToo() {
        // the old lesson that brought 懂 is not done, but 懂 has been answered: its stone is done
        let map = Backup.oldLessons
        var from: [String: [String]] = [:]
        for (o, ss) in map { for s in ss { from[s, default: []].append(o) } }
        let target = card("懂").lessonId
        let feeders = Set(from[target]!)
        var done = Set(map.keys.filter { $0.hasPrefix("qibu1-") })
        XCTAssertFalse(feeders.isSubset(of: done))
        var srs: [String: SRSRecord] = [:]
        for c in course.cards(in: target) { srs[c.id] = SRSRecord(reps: 1) }
        Backup.migrateDone(&done, srs: srs)
        XCTAssertTrue(done.contains(target))
    }

    func testSavedProgressWithOldLessonIdsMigratesOnLoad() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let old = ["qibu1-u1-1", "qibu1-u1-4", "qibu1-s0-1", "qibu5-u2-4"]
        let json = try JSONSerialization.data(withJSONObject: ["srs": [String: Any](), "done": old])
        try json.write(to: url)
        let p = ProgressStore(course: course, url: url)
        XCTAssertTrue(p.done.allSatisfy { course.lessonById[$0] != nil })
        XCTAssertTrue(p.isDone(course.lessons[0].id))     // 你 好 你好 谢谢 我
        XCTAssertTrue(p.isDone(card("客气").lessonId))       // fed by qibu1-s0-1, -u1-4 and qibu5-u2-4, all done
        XCTAssertFalse(p.isDone(card("懂").lessonId))       // 懂 comes from 起步 4
        // and it was saved: a second load finds the new ids
        let again = ProgressStore(course: course, url: url)
        XCTAssertEqual(again.done, p.done)
    }

    func testABackupWithOldLessonIdsRestoresTheirStones() throws {
        let old = Backup.oldLessons.keys.filter { $0.hasPrefix("qibu1-u1-") }.sorted()
        let doneText = String(data: try JSONSerialization.data(withJSONObject: old), encoding: .utf8)!
        let file = try JSONSerialization.data(withJSONObject: [
            "app": "zhBeginnerA", "version": 1, "exported": "2026-09-27T10:00:00.000Z",
            "data": ["zhBeginnerA.done.v1": doneText, "zhBeginnerA.srs.v1": "{}"],
        ])
        let p = ProgressStore(course: course, url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json"))
        XCTAssertTrue(Backup.restore(file, into: p))
        XCTAssertFalse(p.done.isEmpty)
        XCTAssertTrue(p.done.allSatisfy { course.lessonById[$0] != nil })
        for id in p.done { XCTAssertTrue(course.lessonById[id] != nil) }
    }
}
