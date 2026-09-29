import XCTest
@testable import Bubu

// The course played the way a real learner plays it: some answers wrong, "Can't speak now"
// and "Can't listen now" tapped, wrong pairs tried in a match, buns running out part-way.
// (A bug reached the phone because every other test answers everything right: a mistake
// late in a stone left a word unlearnt, so the stone never completed.)
//
// The learner's choices come from a seed, and every failure names the seed and the stone.
// The app's own shuffles aren't seeded, so a seed replays the learner's temper, not the
// very same session: each failure also lists the last steps that led to it.

// MARK: - the learner

/// A small deterministic generator (SplitMix64).
private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// How a learner plays: each number is how often (0…1) they do it when they could.
private struct Learner {
    let seed: UInt64
    /// an answer is wrong
    let mistakes: Double
    /// "Can't speak now" or "Can't listen now", at a speaking or listening exercise
    var skips = 0.2
    /// a wrong pair is tried before the right one, in a match
    var wrongPairs = 0.3
    /// out of buns part-way: the session is ended there (otherwise a fresh batch is had)
    var quits = 0.3
}

/// The time, in the test's hands (ms).
private final class Clock {
    var ms: Double
    init(_ ms: Double) { self.ms = ms }
    func pass(minutes: Double) { ms += minutes * 60_000 }
}

/// What has happened so far in one session.
private struct Seen {
    /// the seed, the mistake rate and the stone: the start of every failure message
    let tag: String
    /// the words with a record when the session began
    let hadRecord: Set<String>
    /// whether "Which pinyin?" may be asked in this session
    let tones: Bool
    /// the words met on a card so far
    var shown = Set<String>()
    /// the words skipped with "Can't speak now" or "Can't listen now"
    var skipped = Set<String>()
    /// the word of the exercise just before (nil at the start and after a match)
    var lastAsked: String?
    var noSpeaking = false
    var noListening = false
    var trace: [String] = []

    mutating func note(_ step: String) { trace.append(step) }

    func why(_ what: String) -> String {
        "\(tag) \(what) · the last steps: \(trace.suffix(8).joined(separator: ", "))"
    }
}

// MARK: - playing

/// Plays stones as a learner would, checking the app's promises at every step. `strict`
/// checks all of them (chapter 1); otherwise only that a stone finishes, is marked done and
/// never asks for a word not yet met (the whole course).
private final class Player {
    /// No session takes this many steps: one that does is going round in circles.
    static let stepCap = 600
    /// A stone takes one session, or two when the learner ends one at the buns sheet.
    static let sessionCap = 3

    private let course = Course.shared
    private let p: ProgressStore
    private let learner: Learner
    private let clock: Clock?
    private let strict: Bool
    private var rng: SplitMix64
    /// the stones whose session the learner has ended early (once each, so it can't go on for ever)
    private var gaveUp = Set<String>()

    private enum Outcome { case finished, quit, stuck }

    init(_ p: ProgressStore, _ learner: Learner, clock: Clock? = nil, strict: Bool) {
        self.p = p
        self.learner = learner
        self.clock = clock
        self.strict = strict
        self.rng = SplitMix64(seed: learner.seed)
    }

    func chance(_ odds: Double) -> Bool {
        guard odds > 0 else { return false }
        return Double.random(in: 0..<1, using: &rng) < odds
    }

    func tag(_ stone: String) -> String {
        "[seed \(learner.seed), \(Int((learner.mistakes * 100).rounded()))% wrong, stone \(stone)]"
    }

    /// One stone, until it's done: a session played to the end must finish it.
    func playStone(_ stone: String) {
        var sessions = 0
        while !p.isDone(stone) && sessions < Self.sessionCap {
            sessions += 1
            guard let s = start(stone) else {
                XCTFail("\(tag(stone)) session \(sessions) didn't start, with \(p.buns) buns")
                return
            }
            switch play(s, stone) {
            case .finished, .stuck: return
            case .quit: clock?.pass(minutes: 5)       // a breather, then the stone again
            }
        }
    }

    // MARK: starting

    private func start(_ stone: String) -> StudySession? {
        let newWords = course.cards(in: stone).contains { p.srs[$0.id] == nil }
        if strict && !p.isPlus { checkNewWordsNeedABun(stone, newWords: newWords) }
        if let s = StudySession.lesson(stone, p) { return s }
        XCTAssertTrue(newWords && p.buns < 1, "\(tag(stone)) only a lack of buns stops a stone starting")
        clock?.pass(minutes: 4 * 60 + 1)               // one grows back in four hours
        return StudySession.lesson(stone, p)
    }

    /// With no buns a stone with new words to meet can't start; a practice stone, or a
    /// stone whose words have all been met, can.
    private func checkNewWordsNeedABun(_ stone: String, newWords: Bool) {
        let had = p.buns
        p.setBuns(0)
        let s = StudySession.lesson(stone, p)
        XCTAssertEqual(s == nil, newWords, "\(tag(stone)) with no buns, new words to meet: \(newWords)")
        p.setBuns(had)
    }

    /// "Which pinyin?" may be asked once the tones stone is done, and in it or any stone after.
    private func tonesIntroduced(at stone: String) -> Bool {
        guard let tones = StudySession.tonesStone else { return true }
        if p.isDone(tones) { return true }
        guard let here = course.lessonOrder[stone], let at = course.lessonOrder[tones] else { return false }
        return here >= at
    }

    // MARK: a session

    private func play(_ s: StudySession, _ stone: String) -> Outcome {
        // nothing has been answered yet: the records are as they were when the session began
        var seen = Seen(tag: tag(stone), hadRecord: Set(p.srs.keys), tones: tonesIntroduced(at: stone))
        if strict { XCTAssertEqual(s.tonesTaught, seen.tones, seen.why("whether the tones have been introduced")) }
        if strict && s.onBuns { XCTAssertGreaterThanOrEqual(p.buns, 1, seen.why("new words started with no buns")) }
        var steps = 0
        while s.result == nil {
            steps += 1
            guard steps <= Self.stepCap, let item = s.current else {
                XCTFail(seen.why("no result after \(steps - 1) steps (the cap is \(Self.stepCap))"))
                return .stuck
            }
            switch item {
            case .meet(let cards, _, _):
                seen.shown.formUnion(cards.map(\.id))
                seen.note("meet " + cards.map(\.word.hanzi).joined(separator: " "))
            case .match(let cards, _):
                pair(s, cards, &seen)
            case .card(let c):
                check(s, c, seen)
                respond(s, c, &seen)
            }
            clock?.pass(minutes: 0.1)
            // as the app does (StudyView.advance): out of buns part-way through, the buns
            // sheet comes up, and it's the end of the session or a fresh batch
            if s.onBuns && p.buns < 1 && s.hasMore {
                if !gaveUp.contains(stone) && chance(learner.quits) {
                    gaveUp.insert(stone)
                    return .quit
                }
                p.setBuns(ProgressStore.bunsMax)
            }
            s.next()
        }
        if strict {
            XCTAssertTrue(s.retries.isEmpty, seen.why("mistakes were still waiting at the end"))
            XCTAssertEqual(s.progressFraction, 1, seen.why("the bar didn't end full"))
        }
        let left = s.result?.wordsLeft ?? 0
        XCTAssertEqual(s.result?.lessonFinished, true,
                       seen.why("played to the end in \(steps) steps, but the stone isn't complete (\(left) words left)"))
        return .finished
    }

    /// Whether a word has been met: it has a record, or its card was shown this session.
    private func met(_ shown: Set<String>) -> (String) -> Bool {
        let store = p
        return { id in store.srs[id] != nil || shown.contains(id) }
    }

    // MARK: an exercise

    /// The exercise on screen, before it's answered.
    private func check(_ s: StudySession, _ c: Card, _ seen: Seen) {
        let dir = s.exercise?.dir ?? s.dir
        let word = "\(dir) \(c.word.hanzi)"
        let isMet = met(seen.shown)
        XCTAssertNotNil(s.exercise, seen.why("\(word): there's nothing to show"))
        XCTAssertTrue(isMet(c.id), seen.why("\(word) was asked before the word was met"))
        if let ex = s.exercise, let sentence = ex.sentence {
            // a sentence to build may hold its card's own word (met, as above) in pieces;
            // one to say aloud holds no unmet word at all
            let unmet = course.unmetWords(in: sentence, for: c, met: isMet, ownAllowed: ex.kind != .speak)
            XCTAssertTrue(unmet.isEmpty, seen.why("\(word): \(sentence.hanzi) has words not yet met: \(unmet)"))
        }
        guard strict else { return }
        if dir == "pinyin" {
            XCTAssertTrue(seen.tones, seen.why("\(word): the tones haven't been introduced"))
        }
        if dir == "speak" {
            let firstSession = !seen.hadRecord.contains(c.id) || seen.shown.contains(c.id)
            XCTAssertFalse(firstSession, seen.why("\(word): spoken in the word's first session"))
            XCTAssertFalse(seen.noSpeaking, seen.why("\(word): speaking, after \"Can't speak now\""))
        }
        if dir == "listen" {
            XCTAssertFalse(seen.noListening, seen.why("\(word): listening, after \"Can't listen now\""))
        }
        if seen.lastAsked == c.id { checkNotTwiceRunning(s, c, seen, word) }
    }

    /// The same word twice running. The app's rule has two halves, because missed words wait
    /// for the end: in the plan a word follows itself only when nothing else is planned
    /// (stoneOrder: "only the last word is left"), and in the mistakes stretch only when no
    /// other mistake waits (nextRetry: "unless it's the only thing left").
    private func checkNotTwiceRunning(_ s: StudySession, _ c: Card, _ seen: Seen, _ word: String) {
        if s.previousMistake {
            let others = s.retries.contains(where: { $0.id != c.id })
            XCTAssertFalse(others, seen.why("\(word) came straight back, with other mistakes waiting"))
            return
        }
        // a skipped word goes to the back of the plan as it is (StudySession.skip), beside
        // whatever is there: the app makes no promise about its neighbours
        if seen.skipped.contains(c.id) { return }
        let others = s.queue.contains(where: { isAnother($0, than: c.id) })
        XCTAssertFalse(others, seen.why("\(word) twice running, with other exercises planned"))
    }

    private func isAnother(_ item: StudySession.Item, than id: String) -> Bool {
        switch item {
        case .card(let c): return c.id != id
        case .meet, .match: return true
        }
    }

    /// The learner's go at an exercise: a skip, a right answer or a wrong one.
    private func respond(_ s: StudySession, _ c: Card, _ seen: inout Seen) {
        let dir = s.exercise?.dir ?? s.dir
        seen.lastAsked = c.id
        if (dir == "speak" || dir == "listen") && chance(learner.skips) {
            skip(s, c, dir, &seen)
            return
        }
        let right = !chance(learner.mistakes)
        let buns = p.buns
        let wasNew = p.srs[c.id] == nil
        s.answer(right)
        seen.note("\(dir) \(c.word.hanzi) \(right ? "right" : "wrong")")
        guard strict else { return }
        let word = "\(dir) \(c.word.hanzi)"
        XCTAssertEqual(s.lastCorrect, right, seen.why("\(word): the answer wasn't taken"))
        XCTAssertNotNil(p.srs[c.id], seen.why("\(word): answered, and no record"))
        if !right { XCTAssertEqual(s.retries.last?.id, c.id, seen.why("\(word): missed, and not waiting to come back")) }
        if !p.isPlus { checkBuns(s, had: buns, right: right, wasNew: wasNew, seen.why("\(word):")) }
    }

    /// A mistake in a session of new words eats a bun (not on a word's first try); a right
    /// answer in a practice stone earns one back, up to five; and there are never fewer than none.
    private func checkBuns(_ s: StudySession, had: Int, right: Bool, wasNew: Bool, _ why: String) {
        var expected = had
        if !right && s.onBuns && !wasNew { expected = had - 1 }
        if right && s.earnsBuns { expected = min(ProgressStore.bunsMax, had + 1) }
        XCTAssertEqual(p.buns, expected, "\(why) buns")
        XCTAssertGreaterThanOrEqual(p.buns, 0, "\(why) fewer than no buns")
        XCTAssertGreaterThanOrEqual(p.activity.buns?.n ?? 0, 0, "\(why) fewer than no buns saved")
    }

    /// "Can't speak now" or "Can't listen now": nothing lost, and the word comes back.
    private func skip(_ s: StudySession, _ c: Card, _ dir: String, _ seen: inout Seen) {
        let record = p.srs[c.id]
        let buns = p.buns
        s.skip()
        seen.note("\(dir) \(c.word.hanzi) skipped")
        seen.skipped.insert(c.id)
        if dir == "listen" { seen.noListening = true } else { seen.noSpeaking = true }
        guard strict else { return }
        XCTAssertEqual(p.srs[c.id], record, seen.why("a skip changed the word's record"))
        XCTAssertEqual(p.buns, buns, seen.why("a skip cost a bun"))
        XCTAssertTrue(s.hasMore, seen.why("the skipped word doesn't come back"))
    }

    // MARK: a match

    /// Tap the pairs: every word in it met, a wrong pair now and then (it costs nothing).
    private func pair(_ s: StudySession, _ cards: [Card], _ seen: inout Seen) {
        seen.note("match of \(cards.count)")
        let isMet = met(seen.shown)
        for c in cards {
            XCTAssertTrue(isMet(c.id), seen.why("a match has \(c.word.hanzi), not yet met"))
        }
        if strict && s.matchAudio {
            XCTAssertFalse(seen.noListening, seen.why("a match of sounds, after \"Can't listen now\""))
        }
        for c in cards.shuffled(using: &rng) {
            if let other = cards.first(where: { $0.id != c.id }), chance(learner.wrongPairs) {
                let buns = p.buns
                let mistakes = s.mistakes
                XCTAssertFalse(s.matchPair(c.id, other.id), seen.why("\(c.word.hanzi) paired with \(other.word.hanzi)"))
                XCTAssertEqual(p.buns, buns, seen.why("a wrong pair cost a bun"))
                XCTAssertEqual(s.mistakes, mistakes, seen.why("a wrong pair was saved as a mistake"))
            }
            XCTAssertTrue(s.matchPair(c.id, c.id), seen.why("\(c.word.hanzi) wouldn't pair with itself"))
        }
        XCTAssertTrue(s.matchFinished, seen.why("every pair found, and the match isn't finished"))
        seen.lastAsked = nil
    }
}

// MARK: - the tests

final class PlaythroughTests: XCTestCase {
    private let course = Course.shared
    private let seeds: [UInt64] = [1, 2, 3]
    private let noon = 1_791_201_600_000.0            // 2026-10-05 12:00 UTC

    private func tempFile() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    // MARK: chapter 1, stone by stone

    func testChapterOneWithACarefulLearner() throws {
        for seed in seeds { try playChapterOne(Learner(seed: seed, mistakes: 0)) }
    }

    func testChapterOneWithASloppyLearner() throws {
        for seed in seeds { try playChapterOne(Learner(seed: seed, mistakes: 0.25)) }
    }

    func testChapterOneWithAStrugglingLearner() throws {
        for seed in seeds { try playChapterOne(Learner(seed: seed, mistakes: 0.5)) }
    }

    /// Chapter 1's eight stones in order (two of them practice stones), one store carried
    /// through, without Plus; then the app is reopened.
    private func playChapterOne(_ learner: Learner) throws {
        let stones = course.chapters[0].lessons
        let after = try XCTUnwrap(course.chapters[1].lessons.first)
        XCTAssertEqual(stones.count, 8)
        XCTAssertEqual(stones.filter { course.lessonById[$0]?.isPractice == true }.count, 2)

        let url = tempFile()
        let clock = Clock(noon)
        let p = ProgressStore(course: course, url: url)
        p.now = { clock.ms }
        XCTAssertFalse(p.isPlus, "the buns rules are checked without Plus")
        let player = Player(p, learner, clock: clock, strict: true)

        for (i, stone) in stones.enumerated() {
            let tag = player.tag(stone)
            XCTAssertEqual(p.currentLessonId, stone, "\(tag) is the stone to play")
            player.playStone(stone)
            guard p.isDone(stone) else {
                XCTFail("\(tag) isn't marked done")
                return
            }
            let next = i + 1 < stones.count ? stones[i + 1] : after
            XCTAssertEqual(p.currentLessonId, next, "\(tag) is done, and the path hasn't moved on")
            // straight on to the next stone, or back tomorrow
            clock.pass(minutes: player.chance(0.5) ? 5 : 24 * 60)
        }

        // reopen the app: the same file, a fresh store
        p.save()
        let again = ProgressStore(course: course, url: url)
        let chapter = player.tag("chapter 1")
        for stone in stones { XCTAssertTrue(again.isDone(stone), "\(chapter) \(stone) is still done after a reload") }
        XCTAssertEqual(again.currentLessonId, after, "\(chapter) chapter 2's first stone is next after a reload")
    }

    // MARK: the whole course

    /// Every 5th stone, the first and last stone of every chapter and the practice stones
    /// (about a third of the course): played in full it takes minutes, not seconds (each
    /// exercise looks through the whole course for its wrong options). Run with
    /// PLAYTHROUGH_ALL=1 in the environment to play every stone.
    private func stonesToPlay() -> Set<String> {
        let lessons = course.lessons
        if ProcessInfo.processInfo.environment["PLAYTHROUGH_ALL"] == "1" { return Set(lessons.map(\.id)) }
        var ids = Set<String>()
        for (i, l) in lessons.enumerated() where i % 5 == 0 || l.isPractice { ids.insert(l.id) }
        for ch in course.chapters {
            if let first = ch.lessons.first { ids.insert(first) }
            if let last = ch.lessons.last { ids.insert(last) }
        }
        return ids
    }

    /// The course from end to end with Plus, a quarter of the answers wrong: each stone
    /// played has every earlier stone done and its words known. It must finish, be marked
    /// done, and never ask for a word not yet met.
    func testTheWholeCourseWithASloppyLearner() {
        let p = ProgressStore(course: course, url: tempFile())
        p.setPlus(true)
        p.holdSaves()                                  // one write at the end, not one an answer
        let player = Player(p, Learner(seed: 7, mistakes: 0.25), strict: false)
        let play = stonesToPlay()
        var played = 0
        for lesson in course.lessons {
            if play.contains(lesson.id) {
                played += 1
                player.playStone(lesson.id)
                XCTAssertTrue(p.isDone(lesson.id), "\(player.tag(lesson.id)) isn't marked done")
            }
            // a stone not played (or one that failed): its words known, and done
            for c in course.cards(in: lesson.id) { p.seedKnown(c.id) }
            if !p.isDone(lesson.id) { p.markDone(lesson.id) }
        }
        p.releaseSaves()
        XCTAssertEqual(played, play.count)
        XCTAssertNil(p.currentLessonId, "every stone is done")
    }
}
