import XCTest
@testable import Bubu

/// For total beginners: tap-the-pairs matches in stones and practice stones, the done
/// screen's "You learned" recap, and the meet card's one-line memory hook.
final class BeginnerHelpsTests: XCTestCase {
    let course = Course.shared

    private func store() -> ProgressStore {
        ProgressStore(course: course, url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json"))
    }
    private var chapter1: [Lesson] { course.chapters[0].lessons.map { course.lessonById[$0]! } }
    private func card(_ hanzi: String) -> Card { course.cards.first { $0.word.hanzi == hanzi }! }

    /// What came up in a session: a word met, an exercise, or a match (its words, and whether
    /// it paired sounds with characters) with the words met by then.
    private struct Seen { let ids: [String]; let audio: Bool; let met: Set<String> }
    private enum Step {
        case meet(String)
        case card(String)
        case match(Seen)
    }

    /// Plays a session through, every answer and every pair right.
    private func play(_ s: StudySession, _ p: ProgressStore) -> [Step] {
        var out: [Step] = [], n = 0
        var met = Set(p.srs.keys)
        while s.result == nil && n < 300 {
            n += 1
            switch s.current {
            case .meet(let cards, _, _)?:
                for c in cards { out.append(.meet(c.id)); met.insert(c.id) }
            case .match(let cards, _)?:
                out.append(.match(Seen(ids: cards.map(\.id), audio: s.matchAudio, met: met)))
                for c in cards { XCTAssertTrue(s.matchPair(c.id, c.id), c.word.hanzi) }
            case .card(let c)?:
                out.append(.card(c.id))
                met.insert(c.id)
                s.answer(true)
            case nil:
                break
            }
            s.next()
        }
        XCTAssertNotNil(s.result, "the session finishes")
        return out
    }

    private func matches(_ steps: [Step]) -> [Seen] {
        var out: [Seen] = []
        for st in steps { if case .match(let m) = st { out.append(m) } }
        return out
    }

    /// A match's words: 4–5, all met before it, each with its own characters and meaning.
    private func checkMatch(_ m: Seen, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue((StudySession.matchMin...StudySession.matchMax).contains(m.ids.count), "\(m.ids.count) pairs", file: file, line: line)
        for id in m.ids { XCTAssertTrue(m.met.contains(id), "\(course.cardById[id]?.word.hanzi ?? id) was met before the match", file: file, line: line) }
        let words = m.ids.compactMap { course.cardById[$0]?.word }
        XCTAssertEqual(Set(words.map(\.hanzi)).count, m.ids.count, "different characters", file: file, line: line)
        XCTAssertEqual(Set(words.map { $0.gloss.lowercased() }).count, m.ids.count, "different meanings", file: file, line: line)
    }

    // MARK: where the match comes

    /// Stone 1 has three words, too few to match; every stone after it has four or more
    /// known or just met, and gets one match, after its last new word is met.
    func testEachStoneWithFourWordsHasOneMatchOfMetWords() {
        for _ in 0..<3 {
            let p = store()
            for (i, stone) in chapter1.enumerated() where !stone.isPractice {
                let s = StudySession(lessonId: stone.id, progress: p)
                let steps = play(s, p)
                let ms = matches(steps)
                if i == 0 {
                    XCTAssertTrue(ms.isEmpty, "stone 1: three words, no match")
                    continue
                }
                XCTAssertEqual(ms.count, 1, stone.id)
                guard let m = ms.first else { continue }
                checkMatch(m)
                XCTAssertFalse(m.audio, "a stone's match is Chinese and English")
                // the stone's new words are in it, and it comes after the last one is met
                let fresh = Set(course.cards(in: stone.id).map(\.id))
                XCTAssertTrue(fresh.isSubset(of: Set(m.ids)), stone.id)
                let at = steps.firstIndex { if case .match = $0 { return true } else { return false } } ?? 0
                let lastMeet = steps.lastIndex { if case .meet = $0 { return true } else { return false } } ?? 0
                XCTAssertGreaterThan(at, lastMeet + 1, stone.id)
                // near the middle or the end, never first
                let exercises = steps.filter { if case .meet = $0 { return false } else { return true } }.count
                let exAt = steps[..<at].filter { if case .card = $0 { return true } else { return false } }.count
                XCTAssertGreaterThanOrEqual(exAt * 2, exercises - 1, "\(stone.id): after \(exAt) of \(exercises)")
            }
        }
    }

    /// A match never uses a word not yet met: a stone of three new words with nothing known
    /// has none, and a practice stone reached with some of its words never studied matches
    /// only the ones that were.
    func testAMatchNeverUsesUnmetWords() {
        let p = store()
        // skip ahead to stone 5 with nothing studied: three new words, too few
        XCTAssertTrue(matches(play(StudySession(lessonId: chapter1[4].id, progress: p), p)).isEmpty)
        // stones 1 and 2 studied (5 words), stone 3's two never met: the practice stone's
        // matches use only the five
        let q = store()
        for l in chapter1[0..<2] { _ = play(StudySession(lessonId: l.id, progress: q), q) }
        let known = Set(q.srs.keys)
        let unmet = Set(course.cards(in: chapter1[2].id).map(\.id))
        XCTAssertTrue(known.isDisjoint(with: unmet))
        let ms = matches(play(StudySession(lessonId: chapter1[3].id, progress: q), q))
        XCTAssertFalse(ms.isEmpty)
        for m in ms {
            checkMatch(m)
            XCTAssertTrue(Set(m.ids).isSubset(of: known))
        }
        // only stone 1 studied: three words, no match at all, fifteen exercises
        let r = store()
        _ = play(StudySession(lessonId: chapter1[0].id, progress: r), r)
        let s = StudySession(lessonId: chapter1[3].id, progress: r)
        XCTAssertEqual(s.sessionTotal, StudySession.practiceLen)
        XCTAssertTrue(matches(play(s, r)).isEmpty)
    }

    func testAPracticeStoneHasTwoMatches() throws {
        let p = store()
        for l in chapter1[0..<3] { _ = play(StudySession(lessonId: l.id, progress: p), p) }
        let s = try XCTUnwrap(StudySession.lesson(chapter1[3].id, p))
        XCTAssertEqual(s.sessionTotal, StudySession.practiceLen, "the matches take two exercises' places")
        let steps = play(s, p)
        let ms = matches(steps)
        guard ms.count == 2 else { return XCTFail("two matches, not \(ms.count)") }
        let words = Set(course.practiceCards(chapter1[3].id).map(\.id))
        for m in ms {
            checkMatch(m)
            XCTAssertTrue(Set(m.ids).isSubset(of: words))
        }
        // between them the two matches cover all seven words
        XCTAssertEqual(Set(ms.flatMap { $0.ids }), words)
        // the first half-way, the second at the end; only the second may pair sounds
        XCTAssertFalse(ms[0].audio)
        XCTAssertTrue(ms[1].audio, "every word is past its first rung by then")
        if case .match = steps.last {} else { XCTFail("the last step is a match") }
        XCTAssertEqual(steps.count, StudySession.practiceLen)
    }

    // MARK: the progress bar and the score

    /// A match is one step of the bar, filled a pair at a time; a wrong pair costs nothing.
    func testAMatchIsOneStepAndAWrongPairCostsNothing() throws {
        let p = store()
        _ = play(StudySession(lessonId: chapter1[0].id, progress: p), p)
        let s = StudySession(lessonId: chapter1[1].id, progress: p)
        let total = s.sessionTotal
        var exercises = 0, n = 0
        var rights: [String: Int] = [:]
        while s.matchCards.isEmpty && s.result == nil && n < 300 {
            n += 1
            if let c = s.card { s.answer(true); exercises += 1; rights[c.id, default: 0] += 1 }
            s.next()
        }
        let cards = s.matchCards
        guard cards.count >= StudySession.matchMin else { return XCTFail("stone 2 has a match") }
        XCTAssertEqual(s.stepsDone, exercises)
        let startFraction = s.progressFraction
        XCTAssertEqual(startFraction, Double(exercises) / Double(total), accuracy: 1e-9)
        // a wrong pair: no bun, no XP, no step, no mistake saved
        let xp = s.sessionXP, buns = p.buns, mistakes = s.mistakes
        let srsBefore = p.srs
        XCTAssertFalse(s.matchPair(cards[0].id, cards[1].id))
        XCTAssertEqual(s.sessionXP, xp)
        XCTAssertEqual(p.buns, buns)
        XCTAssertEqual(s.mistakes, mistakes)
        XCTAssertEqual(p.srs, srsBefore)
        XCTAssertEqual(s.progressFraction, startFraction)
        // right pairs: XP each, the bar creeps, the step counts at the last pair
        for (i, c) in cards.enumerated() {
            let before = s.sessionXP
            XCTAssertTrue(s.matchPair(c.id, c.id))
            XCTAssertFalse(s.matchPair(c.id, c.id), "a pair found stays found")
            XCTAssertGreaterThan(s.sessionXP, before, "XP for a right pair")
            if i < cards.count - 1 {
                XCTAssertEqual(s.stepsDone, exercises)
                XCTAssertEqual(s.progressFraction, (Double(exercises) + Double(i + 1) / Double(cards.count)) / Double(total), accuracy: 1e-9)
            }
            // light scheduling: a word already right twice this session keeps its record
            if (rights[c.id] ?? 0) >= StudySession.scheduledPerSession { XCTAssertEqual(p.srs[c.id], srsBefore[c.id], c.word.hanzi) }
        }
        XCTAssertTrue(s.matchFinished)
        XCTAssertEqual(s.stepsDone, exercises + 1)
        XCTAssertEqual(s.progressFraction, Double(exercises + 1) / Double(total), accuracy: 1e-9)
        // the rest of the session: the bar ends full
        while s.result == nil && n < 400 {
            n += 1
            if s.card != nil { s.answer(true) }
            s.next()
        }
        XCTAssertEqual(s.progressFraction, 1)
        XCTAssertEqual(s.stepsDone, total)
        XCTAssertEqual(try XCTUnwrap(s.result).accuracy, 100)
    }

    /// Stones 2 and 3 are still about fifteen steps with their match.
    func testStonesStayAboutFifteenStepsWithTheMatch() {
        let p = store()
        _ = play(StudySession(lessonId: chapter1[0].id, progress: p), p)
        for stone in chapter1[1...2] {
            let s = StudySession(lessonId: stone.id, progress: p)
            XCTAssertTrue((14...16).contains(s.sessionTotal), "\(stone.id): \(s.sessionTotal)")
            let steps = play(s, p)
            XCTAssertEqual(steps.filter { if case .meet = $0 { return false } else { return true } }.count, s.sessionTotal)
        }
    }

    // MARK: the done screen's recap

    func testTheRecapListsTheStonesNewWords() throws {
        let p = store()
        for stone in chapter1[0..<3] {
            let s = StudySession(lessonId: stone.id, progress: p)
            _ = play(s, p)
            let r = try XCTUnwrap(s.result)
            XCTAssertEqual(r.learned.map(\.word.hanzi), stone.words.map(\.hanzi), stone.id)
            XCTAssertTrue(r.practised.isEmpty)
        }
        // a practice stone: "You practised", up to six of its words
        let s = try XCTUnwrap(StudySession.lesson(chapter1[3].id, p))
        _ = play(s, p)
        let r = try XCTUnwrap(s.result)
        XCTAssertTrue(r.learned.isEmpty)
        XCTAssertFalse(r.practised.isEmpty)
        XCTAssertLessThanOrEqual(r.practised.count, 6)
        XCTAssertEqual(Set(r.practised.map(\.id)).count, r.practised.count, "no word twice")
        let words = Set(course.practiceCards(chapter1[3].id).map(\.id))
        XCTAssertTrue(Set(r.practised.map(\.id)).isSubset(of: words))
        // a review has neither
        let review = StudySession(lessonId: "", progress: p, cards: course.cards(in: chapter1[0].id), mode: .review, title: "Review")
        _ = play(review, p)
        XCTAssertTrue(try XCTUnwrap(review.result).learned.isEmpty)
        XCTAssertTrue(try XCTUnwrap(review.result).practised.isEmpty)
    }

    // MARK: the meet card's memory hook

    func testChapterOnesHooks() {
        let want: [String: String?] = [
            "你": "你 = 亻 person + 尔 you",
            "好": "好 = 女 woman + 子 child → good",
            "你好": "你好 = you + good → hello",
            "我": "我 = 扌 hand + 戈 spear → I, me",
            "是": "是 = 日 sun over 正 right → is, yes",
            "谢谢": "谢 = 讠 words + 射 shè (sound): said twice → thank you",
            "再见": "再见 = 再 again + 见 see → goodbye",
            "叫": "叫 = 口 mouth + 丩 jiū (sound) → to call, be called",
            "什么": nil,
            "名字": "名字 = 名 name + 字 character → name",
            "很": "很 = 彳 step + 艮 gěn (sound) → very",
            "高兴": "高兴 = 高 high + 兴 spirits rising → happy",
            "认识": "认识 = 认 recognise + 识 know → to know (someone)",
            "吗": "吗 = 口 mouth + 马 mǎ (sound) → a yes/no question",
            "也": nil,
            "呢": "呢 = 口 mouth + 尼 ní (sound) → asks it back: 你呢？ and you?",
        ]
        let words = chapter1.flatMap(\.words).map(\.hanzi)
        XCTAssertEqual(words.count, 16)
        XCTAssertEqual(Set(words), Set(want.keys))
        for stone in chapter1 {
            for c in course.cards(in: stone.id) {
                let hook = MemoryHook.line(for: c)
                XCTAssertEqual(hook, want[c.word.hanzi] ?? nil, c.word.hanzi)
                if let hook { XCTAssertTrue(hook.hasPrefix(String(c.word.hanzi.prefix(1))), hook) }
            }
        }
    }

    /// Past chapter 1 a hook is built from the character's parts, when they all have a role
    /// and a short name, or from the words a phrase is made of.
    func testHooksAreBuiltFromParts() {
        XCTAssertEqual(MemoryHook.charHook("吗", gloss: "question"), "吗 = 口 mouth + 马 mǎ (sound) → question")
        XCTAssertNil(MemoryHook.charHook("也", gloss: "also"), "no parts")
        XCTAssertNil(MemoryHook.charHook("再", gloss: "again"), "parts with no role")
        XCTAssertEqual(MemoryHook.short("good, well"), "good")
        // a phrase from its words: every part taught no later than the phrase
        var built = 0
        for c in course.cards where c.word.parts != nil && MemoryHook.chapterOne[c.word.hanzi] == nil {
            guard let hook = MemoryHook.line(for: c) else { continue }
            built += 1
            XCTAssertTrue(hook.hasPrefix(c.word.hanzi + " = "), hook)
            XCTAssertTrue(hook.hasSuffix("→ " + c.word.gloss), hook)
        }
        XCTAssertGreaterThan(built, 5)
    }
}
