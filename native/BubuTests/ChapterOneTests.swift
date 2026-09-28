import XCTest
@testable import Bubu

/// Chapter 1 shaped by hand (bubu-course/docs/sequencing.md, "Chapter 1 by hand"): greetings and
/// names in small stones, practice stones, one new word met at a time, and short meanings.
final class ChapterOneTests: XCTestCase {
    let course = Course.shared

    private func store() -> ProgressStore {
        ProgressStore(course: course, url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json"))
    }
    private func card(_ hanzi: String) -> Card { course.cards.first { $0.word.hanzi == hanzi }! }
    private var chapter1: [Lesson] { course.chapters[0].lessons.map { course.lessonById[$0]! } }

    // MARK: the chapter

    func testChapterOneMatchesThePlan() {
        let plan: [[String]?] = [["你", "好", "你好"], ["我", "是"], ["谢谢", "再见"], nil,
                                 ["叫", "什么", "名字"], ["很", "高兴", "认识"], ["吗", "也", "呢"], nil]
        XCTAssertEqual(chapter1.count, plan.count)
        for (l, items) in zip(chapter1, plan) {
            if let items {
                XCTAssertFalse(l.isPractice, l.id)
                XCTAssertEqual(l.words.map(\.hanzi), items, l.id)
                XCTAssertEqual(course.cards(in: l.id).map(\.word.hanzi), items, "each is its word's first card: \(l.id)")
            } else {
                XCTAssertTrue(l.isPractice, l.id)
                XCTAssertTrue(l.words.isEmpty, l.id)
            }
        }
        XCTAssertNotEqual(chapter1[3].review, true)
        XCTAssertEqual(chapter1[7].review, true)
        XCTAssertEqual(course.hero[chapter1[3].id], "练")
        XCTAssertEqual(course.hero[chapter1[7].id], "复")
    }

    func testTheOldChapterOnesWordsMovedOnAndKeptTheirIds() {
        // the words the plan names, in the next chapters now, with the ids their cards always had
        for h in ["姓", "对", "这", "朋友", "学生", "不", "喝", "咖啡", "茶", "他", "她", "水", "老师", "客气", "对不起",
                  "不客气", "没关系", "请", "请问", "再", "说", "慢", "一点儿", "懂", "请再说一遍", "我不懂", "这个", "用", "中文", "怎么"] {
            let ci = course.chapterOf[card(h).lessonId]!
            XCTAssertTrue((1...2).contains(ci), "\(h) is in chapter \(ci + 1)")
        }
        XCTAssertEqual(card("你").id, "qibu1-u1-1:0")
        XCTAssertEqual(card("呢").id, "qibu1-u1-3:4")
        XCTAssertEqual(card("对不起").id, "qibu1-s0-1:3")
    }

    // MARK: practice stones

    func testPracticeStonesTeachNothingNewAndAreNotOnBuns() throws {
        let p = store()
        let practice = chapter1[3]
        XCTAssertEqual(Set(course.practiceScope(practice.id)), Set(chapter1[0..<3].map(\.id)))
        XCTAssertEqual(Set(course.practiceScope(chapter1[7].id)), Set(chapter1.filter { !$0.isPractice }.map(\.id)))
        XCTAssertTrue(course.cards(in: practice.id).isEmpty)
        // play the chapter up to it
        for l in chapter1[0..<3] { _ = play(StudySession(lessonId: l.id, progress: p)) }
        XCTAssertEqual(p.currentLessonId, practice.id)
        p.setBuns(0)                                  // no buns needed
        let s = try XCTUnwrap(StudySession.lesson(practice.id, p))
        XCTAssertFalse(s.onBuns)
        XCTAssertTrue(s.isPractice)
        XCTAssertTrue(s.earnsBuns)
        XCTAssertEqual(s.title, "Practice")
        XCTAssertEqual(s.sessionTotal, StudySession.practiceLen)
        let words = Set(course.practiceCards(practice.id).map(\.id))
        var asked = 0
        while s.result == nil && asked < 100 {
            if case .meet = s.current { XCTFail("a practice stone meets no new words") }
            if let c = s.card { XCTAssertTrue(words.contains(c.id), c.word.hanzi); s.answer(true); asked += 1 }
            s.next()
        }
        XCTAssertEqual(asked, StudySession.practiceLen)
        XCTAssertEqual(s.bunsEaten, 0)
        XCTAssertTrue(try XCTUnwrap(s.result).lessonFinished)
        XCTAssertTrue(p.isDone(practice.id))
        XCTAssertEqual(p.currentLessonId, chapter1[4].id, "the next stone opens")
        XCTAssertGreaterThan(p.buns, 0, "right answers earn buns back")
    }

    func testPracticePicksTheWeakerWordsFirst() {
        let p = store()
        let practice = chapter1[3]
        let words = course.practiceCards(practice.id)            // 7 words
        for c in words { _ = p.answer(c.id, correct: true, dir: "recall", sessionStart: 0, mistakesMode: false) }
        let weak = card("是")
        _ = p.answer(weak.id, correct: false, dir: "recognize", sessionStart: 1, mistakesMode: false)
        for _ in 0..<5 {
            let q = StudySession.practiceQueue(practice.id, p)
            XCTAssertEqual(q.count, StudySession.practiceLen)
            XCTAssertEqual(Set(q.map(\.id)), Set(words.map(\.id)), "every word comes up")
            XCTAssertEqual(q.filter { $0.id == weak.id }.count, 2, "the weakest comes twice")
            for i in q.indices.dropFirst() { XCTAssertNotEqual(q[i].id, q[i - 1].id, "never twice in a row") }
        }
    }

    // MARK: meeting one word at a time

    func testEachNewWordIsMetAloneBeforeItsFirstExercise() {
        for l in chapter1 where !l.isPractice {
            let s = StudySession(lessonId: l.id, progress: store())
            var met = Set<String>(), steps = 0, meets = 0
            while s.result == nil && steps < 200 {
                steps += 1
                if case .meet(let cards, _, _) = s.current {
                    XCTAssertEqual(cards.count, 1, "one word at a time")
                    meets += 1
                    met.formUnion(cards.map(\.id))
                }
                if let c = s.card {
                    XCTAssertTrue(met.contains(c.id), "\(c.word.hanzi) was met before its first exercise")
                    s.answer(true)
                }
                s.next()
            }
            XCTAssertEqual(meets, l.words.count, l.id)
        }
    }

    func testTheExerciseRightAfterMeetingAWordIsOnThatWordAndEasy() {
        let s = StudySession(lessonId: chapter1[0].id, progress: store())
        var steps = 0
        while s.result == nil && steps < 200 {
            steps += 1
            if case .meet(let cards, _, _) = s.current {
                s.next()
                XCTAssertEqual(s.card?.id, cards[0].id)
                XCTAssertTrue(["recognize", "listen"].contains(s.dir), s.dir)
                continue
            }
            if s.card != nil { s.answer(true) }
            s.next()
        }
    }

    // MARK: short meanings

    func testShortMeaningsAreUsedWherePresent() {
        let please = card("请"), ma = card("吗"), hello = card("你好"), ni = card("你")
        XCTAssertEqual(please.word.gloss, "please")
        XCTAssertEqual(please.word.en, "to invite; to treat (someone to something)")
        XCTAssertEqual(ma.word.gloss, "(yes/no question)")
        XCTAssertEqual(hello.word.gloss, "hello")
        XCTAssertNil(ni.word.short)                              // "you" was short already
        XCTAssertEqual(ni.word.gloss, "you")
        for c in course.chapterCards[0] { XCTAssertLessThanOrEqual(c.word.gloss.count, 20, c.word.hanzi) }
        // the options and the answer use it
        for dir in ["recognize", "listen"] {
            let ex = Exercise.choice(ma, dir: dir, scope: [ma.lessonId])
            XCTAssertEqual(ex.answer, "(yes/no question)")
            XCTAssertTrue(ex.options.contains("(yes/no question)"))
            XCTAssertFalse(ex.options.contains(ma.word.en))
        }
        XCTAssertEqual(Exercise.choice(please, dir: "recognize", scope: [please.lessonId]).answer, "please")
    }

    func testDistractorsForATinyStoneComeFromNearby() {
        let ni = card("你")
        let here = course.lessonOrder[ni.lessonId]!
        for _ in 0..<10 {
            let ex = Exercise.choice(ni, dir: "recognize", scope: [ni.lessonId])
            XCTAssertEqual(Set(ex.options).count, 4)
            for o in ex.options where o != ex.answer {
                let from = course.cards.filter { $0.word.gloss == o }.compactMap { course.lessonOrder[$0.lessonId] }.min() ?? 999
                XCTAssertLessThanOrEqual(abs(from - here), Exercise.nearby, o)
            }
        }
    }

    // MARK: old progress

    func testV294StonesMapToTheNewChapter() {
        let map = Backup.oldStones
        XCTAssertFalse(map.isEmpty)
        for (old, stones) in map {
            XCTAssertNil(course.lessonById[old], "v294 id \(old) is retired")
            for s in stones { XCTAssertNotNil(course.lessonById[s], "\(old) → \(s)") }
        }
        // v294's first stone was 你 好 你好 谢谢 我: done there, stone 1 is done here; stone 2
        // (我 是) waits for v294's second stone, and stone 3 (谢谢 再见) for 再见's
        var done: Set<String> = ["qibu1-u1-1a"]
        Backup.migrateDone(&done, srs: [:])
        XCTAssertEqual(done, [chapter1[0].id])
        // all of v294's chapter 1: stones 1–3, the practice after them, and more
        var all = Set(map.keys.filter { $0.hasPrefix("qibu1-u1-") || $0.hasPrefix("qibu1-s0-") })
        Backup.migrateDone(&all, srs: [:])
        for l in chapter1 { XCTAssertTrue(all.contains(l.id), l.id) }
    }

    func testAPracticeStoneIsDoneWhenTheStonesBeforeItAre() {
        // the old lessons that fed stones 1–3 (JIC-era ids), nothing else
        var done: Set<String> = ["qibu1-u1-1", "qibu1-s0-1"]
        Backup.migrateDone(&done, srs: [:])
        XCTAssertTrue(done.contains(chapter1[0].id))
        XCTAssertTrue(done.contains(chapter1[2].id))
        XCTAssertEqual(done.contains(chapter1[3].id), chapter1[0..<3].allSatisfy { done.contains($0.id) })
        // and with stones 1–3 known by their words, the practice after them follows
        var srs: [String: SRSRecord] = [:]
        for l in chapter1[0..<3] { for c in course.cards(in: l.id) { srs[c.id] = SRSRecord(reps: 1) } }
        var d2: Set<String> = ["some-old-id"]
        Backup.migrateDone(&d2, srs: srs)
        XCTAssertTrue(chapter1[0..<4].allSatisfy { d2.contains($0.id) })
        XCTAssertFalse(d2.contains(chapter1[4].id))
    }

    func testSavedV294ProgressMigratesOnLoad() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let json = try JSONSerialization.data(withJSONObject: ["srs": [String: Any](), "done": ["qibu1-u1-1a", "qibu1-u1-1b"]])
        try json.write(to: url)
        let p = ProgressStore(course: course, url: url)
        XCTAssertTrue(p.done.allSatisfy { course.lessonById[$0] != nil })
        XCTAssertTrue(p.isDone(chapter1[0].id))
        XCTAssertTrue(p.isDone(chapter1[1].id))              // 我 是: both from v294's first two stones
    }

    private func play(_ s: StudySession) -> StudySession.Result? {
        var n = 0
        while s.result == nil && n < 300 { n += 1; if s.card != nil { s.answer(true) }; s.next() }
        return s.result
    }
}
