import Foundation
import Observation

/// One Study session, a port of the web app's study flow (launchLesson →
/// buildStudyQueue → sessionOrder → pickDirection → answerStudy → finishStudy).
@Observable
final class StudySession: Identifiable {
    // web constants
    /// New words are met one at a time, each practised straight away (Duolingo's way).
    static let newPerSession = 6, meetGroup = 1, sessionLen = 12
    /// A stone's session is about this many exercises (Duolingo's lesson: ~15, 3–5 minutes).
    static let stoneLen = 15
    /// How often each new word comes up in its stone's session: usually `newReps` (3 when a
    /// stone has 4–5 new words), up to `newRepsMax` when there are too few earlier words to
    /// review (the course's first stones).
    static let newRepsMin = 3, newReps = 4, newRepsMax = 5
    /// A new word's first right answers in a session schedule its reviews; the extra practice
    /// after them doesn't push its first review further out.
    static let scheduledPerSession = 2
    /// A practice stone's exercises.
    static let practiceLen = 15
    static let xpCorrect = 2, xpCombo = 3, xpPerfect = 5, xpSession = 10, xpLesson = 25, comboAt = 5

    /// The exercise kinds, as the web's FOCUSES.
    static let allDirs = ["recognize", "recall", "pinyin", "listen", "write", "sentence", "speak"]

    enum Item {
        case meet(cards: [Card], first: Bool, left: Int)
        case card(Card)
    }

    /// What the session is for. Only a lesson session can finish a lesson.
    enum Mode { case lesson, review, mistakes, trouble, listen, write, quiz, placement }
    var isQuiz: Bool { mode == .quiz || mode == .placement }

    let id = UUID()
    let lessonId: String
    let mode: Mode
    let title: String
    /// the lessons whose words make the wrong options
    let scope: Set<String>
    let focuses: Set<String>
    /// A session that introduces new words (it has words to meet) is played on buns,
    /// wherever it was started: the path, Home or after onboarding (web: bunMode).
    /// Reviews, mistakes, trouble words, quizzes and the skip test never are.
    private(set) var onBuns = false
    /// A practice stone's session: no new words, the chapter so far, weaker words first.
    let isPractice: Bool
    /// A stone's session of new words (Duolingo's shape): each new word comes up several
    /// times on a ladder of its own, earlier words fill the rest (see stoneOrder).
    let stoneShaped: Bool
    /// "Which pinyin?" asks about tones: only once they've been introduced (see tonesIntroduced).
    let tonesTaught: Bool
    /// the words new when the session started
    private let freshIds: Set<String>
    /// right answers this session, per word: a new word's rung on its ladder
    private var rightInSession: [String: Int] = [:]
    /// how often each kind of exercise has been asked this session
    private var dirsUsed: [String: Int] = [:]
    /// Buns are earned back here, one per right answer (web: a review while below five);
    /// a practice stone earns them back too.
    var earnsBuns: Bool { !onBuns && ([.review, .mistakes, .trouble].contains(mode) || isPractice) }
    /// Counted so the screen can show a bun eaten or earned.
    private(set) var bunsEaten = 0
    private(set) var bunsEarned = 0
    private let course = Course.shared
    private let progress: ProgressStore

    private(set) var queue: [Item] = []
    private(set) var current: Item?
    private(set) var dir: String = "recognize"
    private(set) var exercise: Exercise?
    private(set) var answered = false
    private(set) var lastCorrect: Bool?

    private(set) var sessionTotal = 0
    private(set) var stepsDone = 0
    private(set) var cleared: Set<String> = []
    private(set) var answeredCount = 0
    private(set) var againCount = 0
    private(set) var learnedCount = 0
    private(set) var sessionXP = 0
    private(set) var combo = 0
    private(set) var mistakes = 0
    private(set) var fixedCount = 0
    let start: Double
    private var lastDir: String?
    private var dirByCard: [String: String] = [:]
    private let source: [Card]
    /// words met on screen this session (their record comes with the first answer)
    private var metInSession: Set<String> = []
    /// the lesson step this session is, for a lesson: 1 of 2, 2 of 2 (0 otherwise)
    private(set) var stepAtStart = 0

    /// Set when the session is over.
    private(set) var result: Result?

    struct Result {
        let title: String
        let xp: Int
        let seconds: Int
        let accuracy: Int
        let perfect: Bool
        let lessonFinished: Bool
        let fireJustLit: Bool
        let goalReached: Bool
        let mistakes: Int
        let fixed: Int
        let nextLessonId: String?
        let wordsLeft: Int
        let fire: ProgressStore.Fire?
        let mode: Mode
        /// the skip test's short result: two numbers, no fire or quests
        var simple: [(value: String, label: String)] = []
        /// a lesson step finished that wasn't the last: "Step 1 of 2 done" (0 otherwise)
        var step = 0
        var steps = 0
    }

    // the skip test's tally
    private var placeRange: [String] = []
    private var placeTarget: String?
    private var placeScores: [String: (ok: Int, total: Int)] = [:]
    private var placeCorrect: Set<String> = []
    // The adaptive placement test, for a long way to skip: chapters are probed a few
    // questions at a time, the first first (miss it and the test stops), then halving
    // the range each time, so even the whole course takes ~20 questions.
    private var placeBlocks: [[String]] = []       // the untaken lessons, grouped by chapter
    private var placeLo = -1                        // the highest block shown to be known
    private var placeHi = -1                        // the highest block that still might be
    private var placeProbe: Int?                    // the block being asked about now
    private var probeOk = 0
    private var probeN = 0
    private var probes = 0
    static let probeSize = 3, probePass = 2, maxProbes = 8
    private(set) var quizScore = 0

    init(lessonId: String, progress: ProgressStore, focuses: Set<String>? = nil, cards: [Card]? = nil,
         mode: Mode = .lesson, title: String = "Study", scope: Set<String>? = nil) {
        self.lessonId = lessonId
        self.progress = progress
        self.mode = mode
        self.title = title
        // a mixed session uses the skills switched on in "What to study"
        self.focuses = focuses ?? (mode == .mistakes ? Set(Self.allDirs) : progress.selectedFocuses)
        self.start = progress.now()
        let practice = mode == .lesson && Course.shared.lessonById[lessonId]?.isPractice == true
        self.isPractice = practice
        // as buildQueue: a session of only writing or only speaking isn't shaped like a stone
        let fs = self.focuses
        let shaped = mode == .lesson && !practice && fs != ["write"] && fs != ["speak"]
        self.stoneShaped = shaped
        self.tonesTaught = StudySession.tonesIntroduced(lessonId, mode: mode, progress)
        let chosen = cards ?? (practice ? StudySession.practiceQueue(lessonId, progress)
                                        : StudySession.buildQueue(lessonId: lessonId, progress: progress, focuses: self.focuses))
        self.scope = scope ?? (practice ? Set(Course.shared.practiceScope(lessonId)) : mode == .lesson ? [lessonId] : Set(chosen.map(\.lessonId)))
        self.source = chosen
        self.freshIds = shaped ? Set(chosen.filter { progress.srs[$0.id] == nil }.map(\.id)) : []
        // a practice stone meets no words: it's all exercises, in the order they were picked
        self.queue = mode == .quiz || mode == .placement || practice ? chosen.map { .card($0) } : sessionOrder(chosen)
        self.sessionTotal = queue.filter { if case .card = $0 { return true } else { return false } }.count
        self.onBuns = [.lesson, .listen, .write].contains(mode) && hasMeetLeft
        if mode == .lesson && !lessonId.isEmpty { stepAtStart = Self.lessonSteps(lessonId, progress).step }
        next()
    }

    // MARK: the practice modes

    /// A lesson from the path, Home, the done screen or onboarding (web: launchLesson).
    /// `review` is what the buns sheet's Review button does, when not the usual.
    static func lesson(_ id: String, _ p: ProgressStore, focuses: Set<String>? = nil,
                       review: (() -> Void)? = nil) -> StudySession? {
        onBunsCheck(StudySession(lessonId: id, progress: p, focuses: focuses, title: title(id)), p, review: review)
    }

    /// A session's name in its top bar: "Practice" or "Chapter review" for a practice stone.
    static func title(_ lessonId: String) -> String {
        guard let l = Course.shared.lessonById[lessonId], l.isPractice else { return "Study" }
        return l.review == true ? "Chapter review" : "Practice"
    }

    /// Where the tones are introduced: the course's first practice stone (chapter 1's stone 4),
    /// when there are seven familiar words to hear them on.
    static var tonesStone: String? { Course.shared.lessons.first { $0.isPractice }?.id }

    /// Whether a session may ask "Which pinyin?": once the tones stone is done, and in that
    /// stone or any after it, not before.
    static func tonesIntroduced(_ lessonId: String, mode: Mode, _ p: ProgressStore) -> Bool {
        guard let t = tonesStone else { return true }
        if p.isDone(t) { return true }
        guard mode == .lesson, let here = Course.shared.lessonOrder[lessonId],
              let at = Course.shared.lessonOrder[t] else { return false }
        return here >= at
    }

    /// The tones' one-time intro card, shown before the first session that may ask about them.
    var showsTonesIntro: Bool { mode == .lesson && tonesTaught && focuses.contains("pinyin") && !Coach.tonesSeen }

    /// How weak a word is: never answered, missed lately, lapsed, not yet right, little practised.
    static func weakness(_ s: SRSRecord?) -> Double {
        guard let s else { return 100 }
        let miss: Double = s.miss != nil ? 50 : 0
        let lapses = Double(s.lapses ?? 0) * 10
        let unsure: Double = (s.reps ?? 0) >= 1 ? 0 : 20
        let reps = Double(min(s.reps ?? 0, 5)) * 2
        let spaced = min(s.interval ?? 0, 30) / 3
        return miss + lapses + unsure - reps - spaced
    }

    /// A practice stone's exercises: about fifteen on the words its chapter has taught so far,
    /// weakest first; with fewer words than that the weakest come again, never twice in a row.
    static func practiceQueue(_ lessonId: String, _ p: ProgressStore) -> [Card] {
        let pool = Course.shared.practiceCards(lessonId).shuffled()
            .sorted { weakness(p.srs[$0.id]) > weakness(p.srs[$1.id]) }
        guard !pool.isEmpty else { return [] }
        var picked = Array(pool.prefix(practiceLen))
        var i = 0
        while picked.count < practiceLen { picked.append(pool[i % pool.count]); i += 1 }
        var out = picked.shuffled()
        var tries = 0
        while tries < 50, out.indices.dropFirst().contains(where: { out[$0].id == out[$0 - 1].id }) { out.shuffle(); tries += 1 }
        return out
    }

    /// A session with new words in it needs a bun to start: with none left the buns
    /// sheet opens instead and there's no session.
    static func onBunsCheck(_ s: StudySession, _ p: ProgressStore, review: (() -> Void)? = nil) -> StudySession? {
        guard s.onBuns && p.buns < 1 else { return s }
        Moments.shared.show(.buns(.init(ctx: .start, review: review)))
        return nil
    }

    /// Words from the lessons you've reached: done ones and the one you're on.
    static func reachedCards(_ p: ProgressStore) -> [Card] {
        let cur = p.currentLessonId
        return Course.shared.cards.filter { p.isDone($0.lessonId) || $0.lessonId == cur }
    }

    static func review(_ p: ProgressStore) -> StudySession? {
        let cards = p.dueReviewCards()
        guard !cards.isEmpty else { Moments.shared.toast("Nothing due yet - come back later."); return nil }
        return StudySession(lessonId: "", progress: p, cards: Array(cards.shuffled().prefix(20)), mode: .review, title: "Review")
    }

    static func mistakes(_ p: ProgressStore) -> StudySession? {
        let cards = Array(p.mistakeCards().prefix(sessionLen))
        guard !cards.isEmpty else { Moments.shared.toast("No mistakes to fix. Nice!"); return nil }
        return StudySession(lessonId: "", progress: p, cards: cards, mode: .mistakes, title: "Your mistakes")
    }

    static func trouble(_ p: ProgressStore) -> StudySession? {
        let cards = p.troubleCards()
        guard !cards.isEmpty else { Moments.shared.toast("No trouble words yet — nothing you're stuck on. Nice!"); return nil }
        return StudySession(lessonId: "", progress: p, cards: Array(cards.prefix(20)), mode: .trouble, title: "Trouble words")
    }

    static func listening(_ p: ProgressStore) -> StudySession? {
        let cards = p.activeCards
        let studied = cards.filter { p.srs[$0.id] != nil }
        let pool = studied.isEmpty ? cards : studied
        guard !pool.isEmpty else { Moments.shared.toast("Pick at least one lesson — open “What to study”."); return nil }
        return onBunsCheck(StudySession(lessonId: "", progress: p, focuses: ["listen"], cards: Array(pool.shuffled().prefix(20)),
                                        mode: .listen, title: "Listening", scope: p.selectedLessons), p)
    }

    static func writing(_ p: ProgressStore) -> StudySession? {
        let cards = p.activeCards.filter { StrokeData.shared.writable($0.word.hanzi) }
        let studied = cards.filter { p.srs[$0.id] != nil }
        let pool = studied.isEmpty ? cards : studied
        guard !pool.isEmpty else { Moments.shared.toast("Pick at least one lesson — open “What to study”."); return nil }
        return onBunsCheck(StudySession(lessonId: "", progress: p, focuses: ["write"], cards: Array(pool.shuffled().prefix(12)),
                                        mode: .write, title: "Writing", scope: p.selectedLessons), p)
    }

    /// A quiz on some words: up to 20, multiple choice only (web: startQuiz).
    static func quiz(_ p: ProgressStore, cards: [Card], focuses: Set<String>? = nil, scope: Set<String>? = nil,
                     tooFew: String = "Pick more lessons — a quiz needs at least 3 words.") -> StudySession? {
        guard cards.count >= 3 else { Moments.shared.toast(tooFew); return nil }
        let items = Array(cards.shuffled().prefix(20))
        return StudySession(lessonId: "", progress: p, focuses: focuses, cards: items, mode: .quiz, title: "Quiz · \(items.count) questions", scope: scope)
    }

    /// The skip test: pass it to unlock a lesson and everything before it (web: startPlacement).
    static func placement(_ p: ProgressStore, to target: String, label: String = "Skip test") -> StudySession? {
        let order = Course.shared.lessons.map(\.id)
        guard let ti = order.firstIndex(of: target) else { return nil }
        let range = order[...ti].filter { !p.isDone($0) }
        guard !range.isEmpty else { Moments.shared.toast("That's already unlocked."); return nil }
        // a few chapters or more: adaptive, a handful of questions per chapter probed
        var blocks: [[String]] = []
        for lid in range {
            if let last = blocks.last?.last, Course.shared.chapterOf[last] == Course.shared.chapterOf[lid] { blocks[blocks.count - 1].append(lid) }
            else { blocks.append([lid]) }
        }
        if blocks.count >= 3 {
            let first = probeCards(blocks[0])
            let s = StudySession(lessonId: "", progress: p, focuses: ["recognize", "recall"], cards: first, mode: .placement, title: label)
            s.placeRange = Array(range); s.placeTarget = target
            s.placeBlocks = blocks; s.placeHi = blocks.count - 1; s.placeProbe = 0; s.probes = 1
            // about how long it'll take: the first probe, then halving the rest
            s.sessionTotal = probeSize * min(maxProbes, 1 + Int(ceil(log2(Double(blocks.count)))))
            return s
        }
        let perLesson = max(2, min(5, 20 / range.count))
        let items = range.flatMap { lid in Course.shared.cards(in: lid).shuffled().prefix(perLesson) }.shuffled()
        let s = StudySession(lessonId: "", progress: p, focuses: ["recognize", "recall"], cards: items, mode: .placement,
                             title: "\(label) · \(items.count) question\(items.count == 1 ? "" : "s")")
        s.placeRange = Array(range); s.placeTarget = target
        s.placeScores = Dictionary(uniqueKeysWithValues: range.map { ($0, (0, 0)) })
        return s
    }

    /// A probe's questions: spread across the chapter's lessons, one word from each in turn.
    private static func probeCards(_ block: [String]) -> [Card] {
        var pools = block.map { Course.shared.cards(in: $0).shuffled() }.filter { !$0.isEmpty }.shuffled()
        var out: [Card] = []
        while out.count < probeSize, pools.contains(where: { !$0.isEmpty }) {
            for i in pools.indices where !pools[i].isEmpty && out.count < probeSize { out.append(pools[i].removeFirst()) }
        }
        return out
    }

    /// After a probe: move the range, and pick the next chapter to ask about (nil: done).
    private func nextProbe() -> Int? {
        guard let b = placeProbe else { return nil }
        let passed = probeN > 0 && probeOk >= min(Self.probePass, probeN)
        if passed { placeLo = max(placeLo, b) } else { placeHi = min(placeHi, b - 1) }
        probeOk = 0; probeN = 0
        // missing the first chapter ends it: start from the beginning
        if b == 0 && !passed { return nil }
        guard placeLo < placeHi, probes < Self.maxProbes else { return nil }
        return (placeLo + placeHi + 1) / 2
    }

    // MARK: building the session

    /// A word not yet learned (web: isNewCard).
    static func isNewCard(_ s: SRSRecord?) -> Bool {
        guard let s else { return true }
        return !((s.reps ?? 0) >= 1) && !(s.known ?? false) && !((s.lapses ?? 0) >= 2) && !((s.interval ?? 0) > 0)
    }

    /// How many sessions n new words take, in the even batches of at most six that
    /// buildQueue makes: 6 is one, 7 is two (4 + 3), 15 is three (5 + 5 + 5).
    static func batches(_ n: Int) -> Int {
        var left = n, k = 0
        while left > 0 {
            left -= left > newPerSession ? Int(ceil(Double(left) / ceil(Double(left) / Double(newPerSession)))) : left
            k += 1
        }
        return k
    }

    /// How often each of n new words usually comes up in a stone's session: 4 for up to three
    /// words, 3 for four or more (so five new words alone make 15).
    static func baseReps(new n: Int) -> Int {
        guard n > 0 else { return 0 }
        return min(newReps, max(newRepsMin, stoneLen / n))
    }

    /// How many earlier words a stone's session brings back around n new ones, to make
    /// about `stoneLen`: 3 around three new words, 7 around two.
    static func reviewsWanted(new n: Int) -> Int {
        guard n > 0 else { return 0 }
        return max(0, stoneLen - n * baseReps(new: n))
    }

    /// How often each of n new words comes up beside this many reviews: enough to make about
    /// `stoneLen`, between newRepsMin and newRepsMax (the first stone: 3 words × 5).
    static func repsPerNew(new n: Int, reviews: Int) -> Int {
        guard n > 0 else { return 0 }
        let want = (stoneLen - reviews + n - 1) / n
        return min(newRepsMax, max(newRepsMin, want))
    }

    /// A lesson's steps (its batches of new words) and the one you're on (web: lessonSteps).
    /// A lesson you've finished is on its last step. A lesson whose words have all been
    /// met but aren't all right yet has one step left: the session that clears them.
    static func lessonSteps(_ lessonId: String, _ p: ProgressStore) -> (step: Int, total: Int) {
        let cards = Course.shared.cards(in: lessonId)
        let total = max(1, batches(cards.count))
        if p.isDone(lessonId) { return (total, total) }
        let fresh = cards.filter { p.srs[$0.id] == nil }.count
        let unsure = cards.filter { p.srs[$0.id] != nil && (p.srs[$0.id]?.reps ?? 0) < 1 }.count
        let left = max(1, batches(fresh) + (fresh == 0 && unsure > 0 ? 1 : 0))
        return (min(total, max(1, total - left + 1)), total)
    }

    /// Which cards a lesson session studies (web: buildStudyQueue).
    static func buildQueue(lessonId: String, progress: ProgressStore, focuses: Set<String>) -> [Card] {
        let course = Course.shared
        var cards = course.cards(in: lessonId)
        if focuses == ["sentence"] {
            let withSentences = cards.filter { c in !course.sentences(for: c, met: { id in progress.srs[id] != nil }).isEmpty }
            if !withSentences.isEmpty { cards = withSentences }
        }
        let now = progress.now()
        let due = cards.filter { progress.srs[$0.id] == nil || (progress.srs[$0.id]?.due ?? 0) <= now }
        let fresh = due.filter { progress.srs[$0.id] == nil }
        if !fresh.isEmpty && focuses != ["write"] && focuses != ["speak"] {
            // even batches of at most 6: 15 new words go 5, 5, 5
            let n = fresh.count > newPerSession
                ? Int(ceil(Double(fresh.count) / ceil(Double(fresh.count) / Double(newPerSession))))
                : fresh.count
            let picked = Array(fresh.prefix(n))
            let want = reviewsWanted(new: picked.count)
            var reviews: [Card] = []
            var seen = Set(picked.map(\.id))
            // the last step brings back every word of the lesson not yet got right, however
            // many, so finishing it finishes the lesson
            if picked.count == fresh.count {
                for c in cards where !seen.contains(c.id) && progress.srs[c.id] != nil && (progress.srs[c.id]?.reps ?? 0) < 1 {
                    reviews.append(c); seen.insert(c.id)
                }
            }
            let add = { (list: [Card]) in
                for c in list where reviews.count < want && !seen.contains(c.id) {
                    reviews.append(c); seen.insert(c.id)
                }
            }
            add(due.filter { progress.srs[$0.id] != nil }.shuffled())
            add(progress.dueReviewCards(excluding: lessonId).shuffled())
            // then the earlier words met so far, weakest first
            add(reachedCards(progress).filter { $0.lessonId != lessonId && progress.srs[$0.id] != nil }
                .shuffled().sorted { weakness(progress.srs[$0.id]) > weakness(progress.srs[$1.id]) })
            add(cards.filter { (progress.srs[$0.id]?.reps ?? 0) >= 1 }.shuffled())
            // too few earlier words (the course's first stones): the new words come up more
            // often, up to newRepsMax each, and then the earlier ones come round again
            let spare = want - reviews.count - picked.count * (newRepsMax - baseReps(new: picked.count))
            if spare > 0 && !reviews.isEmpty {
                let again = Array(reviews.prefix(spare))
                reviews += again
            }
            return picked + reviews
        }
        let pool = (due.isEmpty ? cards : due).shuffled()
        let n = pool.count > sessionLen
            ? Int(ceil(Double(pool.count) / ceil(Double(pool.count) / Double(sessionLen))))
            : pool.count
        return Array(pool.prefix(n))
    }

    /// New words met one at a time, reviews woven between (web: sessionOrder). A stone's
    /// session is laid out by stoneOrder; other sessions of new words practise each twice.
    private func sessionOrder(_ cards: [Card]) -> [Item] {
        let order = Dictionary(uniqueKeysWithValues: course.cards.enumerated().map { ($1.id, $0) })
        let fresh = cards.filter { progress.srs[$0.id] == nil }.sorted { (order[$0.id] ?? 0) < (order[$1.id] ?? 0) }
        var known = cards.filter { progress.srs[$0.id] != nil }.shuffled()
        if fresh.isEmpty { return cards.shuffled().map { .card($0) } }
        if stoneShaped { return Self.stoneOrder(fresh: fresh, known: known) }
        let k = Int(ceil(Double(fresh.count) / Double(Self.meetGroup)))
        let size = Int(ceil(Double(fresh.count) / Double(k)))
        let groups = stride(from: 0, to: fresh.count, by: size).map { Array(fresh[$0..<min(fresh.count, $0 + size)]) }
        var out: [Item] = [], met = 0
        for (gi, g) in groups.enumerated() {
            met += g.count
            out.append(.meet(cards: g, first: gi == 0, left: fresh.count - met))
            out += g.shuffled().map { .card($0) }
            if !known.isEmpty { out.append(.card(known.removeFirst())) }
            if gi > 0 {
                out += groups[gi - 1].shuffled().map { .card($0) }
                if !known.isEmpty { out.append(.card(known.removeFirst())) }
            }
        }
        out += (groups.last ?? []).shuffled().map { .card($0) }
        out += known.map { .card($0) }
        return out
    }

    /// A stone's session, Duolingo's shape: each new word is met on its own card and asked
    /// straight away, then comes back until it has come up `repsPerNew` times, never twice in
    /// a row; the next word is met once the one before has come up again. The earlier words
    /// (`known`) are spread evenly between as review. Which exercise each one gets is chosen
    /// as it comes (see newWordLadder).
    static func stoneOrder(fresh: [Card], known: [Card]) -> [Item] {
        let n = fresh.count
        let reps = repsPerNew(new: n, reviews: known.count)
        let total = reps * n + known.count
        var reviews = known
        var done = Array(repeating: 0, count: n)       // times each new word has come up
        var lastAt = Array(repeating: -1, count: n)    // where it last came up
        var out: [Item] = []
        var met = 0, placed = 0, reviewed = 0, sinceMeet = 0, lastRung = -1
        var lastId = ""
        func meetNext() {
            out.append(.meet(cards: [fresh[met]], first: met == 0, left: n - met - 1))
            out.append(.card(fresh[met]))
            done[met] = 1
            lastAt[met] = placed
            placed += 1
            lastId = fresh[met].id
            lastRung = 0
            sinceMeet = 1
            met += 1
        }
        while done.contains(where: { $0 < reps }) {
            if met < n && (met == 0 || sinceMeet >= 2) { meetNext(); continue }
            var cands = (0..<met).filter { done[$0] < reps && fresh[$0].id != lastId }
            let r = reviews.firstIndex { $0.id != lastId }
            let reviewDue = (reviewed + 1) * total <= (placed + 1) * known.count
            if let r, reviewDue || cands.isEmpty {
                let c = reviews.remove(at: r)
                out.append(.card(c))
                lastId = c.id
                lastRung = -1
                reviewed += 1
                placed += 1
                continue
            }
            if cands.isEmpty {
                if met < n { meetNext(); continue }
                cands = (0..<met).filter { done[$0] < reps }  // only the last word is left
            }
            // the word that has come up least, preferring one on a different rung from the
            // exercise before (so the kinds of exercise alternate), then the longest ago
            func key(_ i: Int) -> (Int, Int, Int) { (done[i] == lastRung ? 1 : 0, done[i], lastAt[i]) }
            guard let i = cands.min(by: { key($0) < key($1) }) else { break }
            out.append(.card(fresh[i]))
            lastRung = done[i]
            done[i] += 1
            lastAt[i] = placed
            placed += 1
            lastId = fresh[i].id
            sinceMeet += 1
        }
        out += reviews.map { Item.card($0) }
        return out
    }

    // MARK: moving through it

    func next() {
        answered = false
        lastCorrect = nil
        exercise = nil
        if queue.isEmpty, mode == .placement, !placeBlocks.isEmpty, let b = nextProbe() {
            placeProbe = b; probes += 1
            queue = Self.probeCards(placeBlocks[b]).map { .card($0) }
            sessionTotal = max(sessionTotal, stepsDone + Self.probeSize)
        }
        guard !queue.isEmpty else { finish(); return }
        let item = queue.removeFirst()
        current = item
        if case .meet(let cards, _, _) = item { metInSession.formUnion(cards.map(\.id)) }
        if case .card(let c) = item {
            dir = pickDirection(c)
            exercise = Exercise.make(card: c, dir: dir, scope: scope, progress: progress, met: self.isMet)
            if exercise == nil {               // a sentence that couldn't be built: fall back
                dir = "recognize"
                exercise = Exercise.make(card: c, dir: dir, scope: scope, progress: progress)
            }
            exercise?.isNew = Self.isNewCard(progress.srs[c.id])
            dirsUsed[dir, default: 0] += 1
        }
    }

    /// A new word's exercises in its stone's session, easy to hard, one rung per right answer:
    /// recognise it, hear it (or pick its tones), recall its characters or build a sentence
    /// with it, then the harder kinds again. Each rung lists its kinds in order of preference.
    static let newWordLadder: [[String]] = [
        ["recognize", "listen"],
        ["listen", "pinyin"],
        ["recall", "sentence"],
        ["sentence", "pinyin", "recall", "listen"],
        ["recall", "listen", "pinyin", "recognize"],
    ]

    /// A new word's exercise from its ladder (nil: none of its rung's kinds are switched on).
    /// Past the first rung it avoids the kind just asked and the word's own last kind, and
    /// takes the kind asked least this session, so the session doesn't repeat itself.
    private func ladderDir(_ c: Card, _ enabled: [String]) -> String? {
        let rung = min(rightInSession[c.id] ?? 0, Self.newWordLadder.count - 1)
        var on = Self.newWordLadder[rung].filter { enabled.contains($0) }
        guard !on.isEmpty else { return nil }
        if rung > 0 {
            if let l = lastDir, on.count > 1 { on.removeAll { $0 == l } }
            if let b = dirByCard[c.id], on.count > 1 { on.removeAll { $0 == b } }
            let least = on.map { dirsUsed[$0] ?? 0 }.min() ?? 0
            on = on.filter { (dirsUsed[$0] ?? 0) == least }
        }
        return on.first
    }

    /// Which exercise a card gets, climbing a ladder as the word gets stronger (web: pickDirection).
    private func pickDirection(_ c: Card) -> String {
        if isQuiz {
            let mc = focuses.filter { !["write", "sentence", "speak"].contains($0) && (tonesTaught || $0 != "pinyin") }
            return mc.randomElement() ?? "recognize"
        }
        let s = progress.srs[c.id]
        if mode == .mistakes, let m = s?.miss, dirByCard[c.id] == nil, missedDirPossible(c, m.d) {
            dirByCard[c.id] = m.d; lastDir = m.d; return m.d
        }
        var enabled = Self.allDirs.filter { focuses.contains($0) }
        // "Which pinyin?" asks about tones: not until they've been introduced
        if !tonesTaught { enabled.removeAll { $0 == "pinyin" } }
        // a sentence only when all its other words have been met (see Course.sentences(for:met:))
        if course.sentences(for: c, met: isMet).isEmpty { enabled.removeAll { $0 == "sentence" } }
        if !StrokeData.shared.writable(c.word.hanzi) { enabled.removeAll { $0 == "write" } }
        // a word new in a stone's session climbs its own ladder
        if freshIds.contains(c.id), let d = ladderDir(c, enabled) {
            dirByCard[c.id] = d
            lastDir = d
            return d
        }
        if focuses.count > 1 {
            let reps = s?.reps ?? 0, interval = s?.interval ?? 0
            let level = reps >= 2 || interval >= 7 ? 2 : reps >= 1 ? 1 : 0
            let rung: [String]? = level == 0 ? ["recognize", "listen"] : level == 1 ? ["recall", "pinyin", "sentence", "listen"] : nil
            if let rung {
                var on = enabled.filter { rung.contains($0) }
                if let before = dirByCard[c.id], on.count > 1 { on.removeAll { $0 == before } }
                let eased = enabled.filter { $0 != "write" && $0 != "speak" }
                enabled = on.isEmpty ? (eased.isEmpty ? enabled : eased) : on
            }
        }
        if enabled.isEmpty { enabled = ["recognize"] }
        if let l = lastDir, enabled.count > 1 { enabled.removeAll { $0 == l } }
        let d = enabled.randomElement() ?? "recognize"
        dirByCard[c.id] = d
        lastDir = d
        return d
    }

    private func missedDirPossible(_ c: Card, _ d: String) -> Bool {
        if d == "write" { return StrokeData.shared.writable(c.word.hanzi) }
        if d == "sentence" { return !course.sentences(for: c, met: isMet).isEmpty }
        if d == "pinyin" { return tonesTaught }
        return Self.allDirs.contains(d)
    }

    /// A word the learner has met: it has a record, or it was met on screen this session.
    func isMet(_ cardId: String) -> Bool { progress.srs[cardId] != nil || metInSession.contains(cardId) }

    var card: Card? { if case .card(let c) = current { return c } else { return nil } }

    /// Grade the current card (web: answerStudy). Returns the XP just earned.
    @discardableResult
    func answer(_ correct: Bool) -> Int {
        guard !answered, let c = card else { return 0 }
        answered = true
        progress.holdSaves()
        defer { progress.releaseSaves() }
        let wasNew = progress.srs[c.id] == nil
        lastCorrect = correct
        if correct { quizScore += 1 }
        if mode == .placement {
            probeN += 1; if correct { probeOk += 1 }
            placeScores[c.lessonId, default: (0, 0)].total += 1
            if correct { placeScores[c.lessonId, default: (0, 0)].ok += 1; placeCorrect.insert(c.id) }
        } else if mode == .quiz {
            progress.review(c.id, correct ? .good : .again)
            progress.recordReview()
        } else {
            // a stone's extra practice on a word doesn't push its first review further out
            let schedule = !stoneShaped || (rightInSession[c.id] ?? 0) < Self.scheduledPerSession
            let r = progress.answer(c.id, correct: correct, dir: dir, sessionStart: start,
                                    mistakesMode: mode == .mistakes, schedule: schedule)
            if r.mistake { mistakes += 1 }
            if r.fixed { fixedCount += 1 }
            progress.recordReview()
        }
        if correct { rightInSession[c.id, default: 0] += 1 }
        // a mistake in a session of new words eats a bun, except on a word's first try
        // (it was only just met); a right answer in a review earns one back
        if !correct && onBuns && !wasNew { progress.eatBun(); bunsEaten += 1 }
        else if correct && earnsBuns && progress.earnBun() { bunsEarned += 1 }
        // XP for the answer, more on a run
        var xp = 0
        if correct {
            combo += 1
            if combo == Self.comboAt { DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { Sounds.shared.play("combo") } }
            let mark = progress.xpCounter
            progress.earnXP(combo >= Self.comboAt ? Self.xpCombo : Self.xpCorrect)
            xp = progress.xpCounter - mark
        } else {
            combo = 0
        }
        sessionXP += xp
        let qMark = progress.xpCounter
        progress.questEvent(dir, correct: correct)
        xp += progress.xpCounter - qMark; sessionXP += progress.xpCounter - qMark
        answeredCount += 1
        if isQuiz {
            stepsDone += 1                     // one go at each question
            if !correct { againCount += 1 }
            return xp
        }
        if correct {
            stepsDone += 1
            if !cleared.contains(c.id) {
                cleared.insert(c.id)
                if wasNew { learnedCount += 1 }
            }
        } else {
            againCount += 1
            queue.append(.card(c))
        }
        return xp
    }

    /// Shuffle what's left (web: #studyShuffle). New words keep their order until all are met.
    func shuffleRest() -> Bool {
        guard !hasMeetLeft else { return false }
        if !answered, let c = card { queue.append(.card(c)) }
        queue.shuffle()
        next()
        return true
    }

    /// "Can't speak now": the word comes back later, with no penalty and no XP.
    func skip() {
        guard !answered, let c = card else { return }
        answered = true
        queue.append(.card(c))
    }

    var progressFraction: Double { sessionTotal == 0 ? 0 : min(Double(stepsDone), Double(sessionTotal)) / Double(sessionTotal) }
    var hasMeetLeft: Bool { queue.contains { if case .meet = $0 { return true } else { return false } } }

    // MARK: the end

    private func finish() {
        current = nil
        progress.holdSaves(); defer { progress.releaseSaves() }
        if mode == .placement { return finishPlacement() }
        let lessonCards = mode == .lesson ? course.cards(in: lessonId) : []
        // a practice stone is finished by playing it through
        let cleared = isPractice || (!lessonCards.isEmpty && lessonCards.allSatisfy { (progress.srs[$0.id]?.reps ?? 0) >= 1 })
        let justFinished = mode == .lesson && !progress.isDone(lessonId) && cleared
        if justFinished { progress.markDone(lessonId) }
        let perfect = againCount == 0 && answeredCount >= 5
        let mark = progress.xpCounter
        progress.questEvent("session", correct: true, lesson: justFinished, perfect: perfect)
        var goal = false
        let s = progress.earnXP(justFinished ? Self.xpLesson : Self.xpSession)
        goal = goal || s.goalReached
        if perfect { let p = progress.earnXP(Self.xpPerfect); goal = goal || p.goalReached }
        sessionXP += progress.xpCounter - mark
        if justFinished {
            progress.startBoost()
            redPocket()
            storyUnlocked()
        }
        let fire = progress.lightFire()
        let left = justFinished ? 0 : lessonCards.filter { (progress.srs[$0.id]?.reps ?? 0) < 1 }.count
        // a lesson comes in steps (its batches of new words): one done, more to go
        let total = mode == .lesson ? Self.lessonSteps(lessonId, progress).total : 0
        let stepDone = left > 0 && stepAtStart > 0 && stepAtStart < total
        let title = mode == .quiz ? "Quiz complete" : mode == .mistakes ? "Mistakes practised" : [.review, .trouble].contains(mode) ? "Review complete"
            : isPractice ? (self.title == "Chapter review" ? "Chapter review done!" : "Practice done!")
            : justFinished ? "Lesson complete!" : stepDone ? "Step \(stepAtStart) of \(total) done" : "Session complete"
        let seconds = Int(((progress.now() - start) / 1000).rounded())
        let accuracy = answeredCount == 0 ? 100 : Int((Double(answeredCount - againCount) / Double(answeredCount) * 100).rounded())
        result = Result(title: title, xp: sessionXP, seconds: seconds, accuracy: accuracy, perfect: perfect,
                        lessonFinished: justFinished, fireJustLit: fire != nil, goalReached: goal,
                        mistakes: mistakes, fixed: fixedCount,
                        nextLessonId: justFinished ? nextLesson(after: lessonId) : nil, wordsLeft: left,
                        fire: fire, mode: mode)
        if stepDone { result?.step = stepAtStart; result?.steps = total }
        Coach.sessionFinished()
    }

    /// The notes to show as a tip before this lesson starts: once per stone, then never again
    /// (they stay on the lesson sheet and in the Guide).
    var tips: [Note] {
        guard mode == .lesson, !isPractice, !lessonId.isEmpty, !Coach.tipSeen(lessonId) else { return [] }
        return course.notes(for: lessonId)
    }

    /// The skip test's verdict: lessons pass at 70%, in order, stopping at the first that
    /// doesn't (adaptive: every chapter up to the highest passed); the words you got right
    /// in them are seeded as known (web: finishPlacement).
    private func finishPlacement() {
        var unlocked: [String] = []
        if !placeBlocks.isEmpty {
            // adaptive: every chapter up to the highest one shown to be known
            if placeLo >= 0 { unlocked = Array(placeBlocks[0...placeLo].joined()) }
        } else {
            for lid in placeRange {
                // a practice stone has no words to be asked: it passes with the stones before it
                if course.cards(in: lid).isEmpty { unlocked.append(lid); continue }
                let s = placeScores[lid] ?? (0, 0)
                if s.total > 0 && Double(s.ok) / Double(s.total) >= 0.7 { unlocked.append(lid) } else { break }
            }
        }
        progress.holdSaves()
        unlocked.forEach(progress.markDone)
        for id in placeCorrect { if let c = course.cardById[id], unlocked.contains(c.lessonId) { progress.seedKnown(id) } }
        progress.releaseSaves()
        let reached = placeTarget.map(unlocked.contains) ?? false
        Sounds.shared.play(unlocked.isEmpty ? "wrong" : "complete")
        Moments.shared.toast(unlocked.isEmpty ? "Keep studying from where you are — you'll get there."
            : reached ? "Unlocked all the way to your target — nice!"
            : "Unlocked what you're solid on — the rest needs a little more study.")
        var r = Result(title: unlocked.isEmpty ? "Not yet" : reached ? "You tested out!" : "Skipped ahead",
                       xp: sessionXP, seconds: 0, accuracy: 0, perfect: false, lessonFinished: false, fireJustLit: false,
                       goalReached: false, mistakes: 0, fixed: 0, nextLessonId: nil, wordsLeft: 0, fire: nil, mode: mode)
        r.simple = [("\(quizScore)/\(answeredCount)", "correct"),
                    ("\(unlocked.count)", unlocked.count == 1 ? "lesson unlocked" : "lessons unlocked")]
        result = r
    }

    /// A red pocket for the lesson just finished: credited now, opened on screen (web: finishStudy).
    private func redPocket() {
        let chapterEnd = course.chapterOf[lessonId].map(progress.chapterDone) ?? false
        let got = progress.lessonPocket(chapterEnd: chapterEnd)
        guard got > 0 else { return }
        progress.addCoins(got)
        let pocket = Moments.Pocket(kind: .red, reward: got, title: chapterEnd ? "Chapter complete!" : "Lesson complete!",
                                    sub: chapterEnd ? "A fuller pocket for a whole chapter" : "Bùbù has something for you.")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { Moments.shared.show(.pocket(pocket)) }
    }

    /// Finishing a chapter's last lesson unlocks its story (web: finishStudy's toast).
    private func storyUnlocked() {
        guard let ci = course.chapterOf[lessonId], progress.chapterDone(ci),
              let story = course.data.readings.first(where: { $0.chapter == ci }), !progress.readDone(story.id) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { Moments.shared.toast("New story unlocked: \(story.title)") }
    }

    /// The next unfinished lesson after this one, else the first unfinished (web: nextLessonId).
    private func nextLesson(after id: String) -> String? {
        let ls = course.lessons
        let i = ls.firstIndex { $0.id == id } ?? -1
        if let l = ls[(i + 1)...].first(where: { !progress.isDone($0.id) }) { return l.id }
        return ls.first { !progress.isDone($0.id) }?.id
    }

    #if DEBUG
    /// For screenshots: skip ahead to a given exercise on a word that suits it.
    func debugShow(dir: String) {
        let cards = course.cards(in: lessonId)
        let c = dir == "sentence" ? (course.cards.first { !course.sentences(for: $0).isEmpty } ?? cards[0]) : cards[0]
        current = .card(c)
        self.dir = dir
        // every word counts as met here, so the screenshot always has a sentence
        exercise = Exercise.make(card: c, dir: dir, scope: [c.lessonId], progress: progress, met: { _ in true })
        exercise?.isNew = true
    }
    func debugFinish() {
        combo = 4; answeredCount = 8; againCount = 1; stepsDone = sessionTotal
        queue = []
        next()
    }
    #endif

    /// The same words again (web: Practice again).
    func again() -> StudySession {
        StudySession(lessonId: lessonId, progress: progress, focuses: focuses, cards: source, mode: mode, title: title)
    }
}

// MARK: exercises

/// One question on screen: what's asked, the options, and the right answer.
struct Exercise {
    enum Kind { case choice, sentence, speak, write }
    let kind: Kind
    let dir: String
    let card: Card
    // multiple choice
    var options: [String] = []
    var answer: String = ""
    // sentence
    var sentence: Sentence?
    var toChinese = true
    var tiles: [Tile] = []
    /// a word not learned yet when the question was asked: shows the NEW WORD badge
    var isNew = false
    /// writing help: 0 trace, 1 first part shown, 2 from memory
    var writeStage = 0

    struct Tile: Identifiable, Hashable { let id: Int; let text: String; let pinyin: String? }
    /// How many stones away a wrong option may come from, for a stone with too few words of its own.
    static let nearby = 12

    var label: String {
        switch dir {
        case "recall": return "Which characters mean this?"
        case "pinyin": return "Which pinyin is correct?"
        case "listen": return "What did you hear?"
        case "sentence": return toChinese ? "Build the Chinese" : "Translate this sentence"
        case "speak": return "Say it out loud"
        case "write": return ["Trace, then write it", "Write it", "Write it from memory"][writeStage]
        default: return "What does this mean?"
        }
    }

    /// `met` says whether a word (a card id) has been met: a sentence may only use met words.
    static func make(card c: Card, dir: String, scope: Set<String>, progress: ProgressStore,
                     met: ((String) -> Bool)? = nil) -> Exercise? {
        switch dir {
        case "sentence": return sentence(c, met: met ?? { progress.srs[$0] != nil })
        case "speak": return speak(c)
        case "write":
            let s = progress.srs[c.id]
            // the help fades: new, learning, then from memory once spaced a week out
            let stage = (s?.reps ?? 0) < 1 ? 0 : (s?.interval ?? 0) >= 7 ? 2 : 1
            return Exercise(kind: .write, dir: "write", card: c, writeStage: stage)
        default: return choice(c, dir: dir, scope: scope)
        }
    }

    private static func field(_ w: Word, _ dir: String) -> String {
        switch dir {
        case "recall": return w.hanzi
        case "pinyin": return w.pinyin
        default: return w.gloss             // the short meaning, when the word has one
        }
    }

    /// One answer and three distractors (web: buildChoiceExercise).
    static func choice(_ c: Card, dir: String, scope: Set<String>) -> Exercise {
        let course = Course.shared
        let inScope = course.cards.filter { scope.contains($0.lessonId) }
        let cards = inScope.isEmpty ? course.cards : inScope
        let answer = field(c.word, dir)
        var distractors: [String] = []
        let others = { (exclude: [String]) -> [String] in
            var seen = Set<String>(), out: [String] = []
            for x in cards { let v = field(x.word, dir); if v != answer && !exclude.contains(v) && seen.insert(v).inserted { out.append(v) } }
            return out.shuffled()
        }
        switch dir {
        case "pinyin":
            distractors = Pinyin.variants(answer, 3)
            if distractors.count < 3 { distractors += others(distractors).prefix(3 - distractors.count) }
        case "listen":
            let bare = Pinyin.toneless(c.word.pinyin)
            var near: [String] = []
            for x in cards.shuffled() where Pinyin.toneless(x.word.pinyin) == bare && x.word.gloss != answer && !near.contains(x.word.gloss) { near.append(x.word.gloss) }
            distractors = Array(near.prefix(3))
            distractors += others(distractors).prefix(3 - distractors.count)
        default:
            var near: [String] = []
            // look-alikes the learner has reached, or nearly (not one from a later book)
            let here = course.lessonOrder[c.lessonId] ?? 0
            let reached = course.lookalikes(c, 8).filter { (course.lessonOrder[$0.lessonId] ?? 0) <= here + Exercise.nearby }
            for x in reached.prefix(2) { let v = field(x.word, dir); if v != answer && !near.contains(v) { near.append(v) } }
            distractors = near + others(near).prefix(3 - near.count)
        }
        // a lesson with very few words borrows from the words nearest it in the course (not
        // "portion, serving" beside 你 on day one), so there are always four options
        if distractors.count < 3 {
            var seen = Set(distractors + [answer])
            let here = course.lessonOrder[c.lessonId] ?? 0
            let nearest = course.cards.sorted { abs((course.lessonOrder[$0.lessonId] ?? 0) - here) < abs((course.lessonOrder[$1.lessonId] ?? 0) - here) }
            for x in nearest.prefix(40).filter({ abs((course.lessonOrder[$0.lessonId] ?? 0) - here) <= Exercise.nearby }).shuffled() + nearest.shuffled()
                where distractors.count < 3 {
                let v = field(x.word, dir)
                if seen.insert(v).inserted { distractors.append(v) }
            }
        }
        return Exercise(kind: .choice, dir: dir, card: c, options: (distractors.prefix(3) + [answer]).shuffled(), answer: answer)
    }

    /// Say it aloud: a short phrase with the word in it, since a lone syllable is too
    /// easily misheard, else the word itself (web: the speak card).
    static func speak(_ c: Card) -> Exercise {
        let phrase = Course.shared.sentences(for: c)
            .filter { (3...12).contains($0.hanzi.filter(Course.isHan).count) }
            .min { $0.hanzi.filter(Course.isHan).count < $1.hanzi.filter(Course.isHan).count }
        return Exercise(kind: .speak, dir: "speak", card: c, sentence: phrase)
    }

    /// What to say, its pinyin and its meaning.
    var sayHanzi: String { sentence?.hanzi ?? card.word.hanzi }
    var sayPinyin: String { sentence?.pinyin ?? card.word.pinyin }
    var sayEn: String { sentence?.en ?? card.word.gloss }

    /// Word tiles to put in order (web: buildSentenceExercise).
    static func sentence(_ c: Card, met: (String) -> Bool) -> Exercise? {
        let course = Course.shared
        guard let sent = course.sentences(for: c, met: met).randomElement() else { return nil }
        let enWords = Sentence.enWords(sent.en)
        let toChinese = enWords.count < 2 || Bool.random()
        let long = sent.words.count > 6 || enWords.count > 7
        let nDistract = long ? 2 : 3
        var tiles: [Tile] = []
        if toChinese {
            let target = Set(sent.words.map(\.hanzi))
            var pool: [SentenceWord] = [], seen = Set<String>()
            for s in course.sentences.shuffled().prefix(200) where s.hanzi != sent.hanzi {
                for w in s.words where !target.contains(w.hanzi) && seen.insert(w.hanzi).inserted { pool.append(w) }
                if pool.count > 40 { break }
            }
            let words = sent.words + pool.shuffled().prefix(nDistract)
            tiles = words.enumerated().map { Tile(id: $0.offset, text: $0.element.hanzi, pinyin: $0.element.pinyin) }
        } else {
            let target = Set(enWords.map { $0.lowercased() })
            var pool: [String] = [], seen = Set<String>()
            for s in course.sentences.shuffled().prefix(200) where s.en != sent.en {
                for w in Sentence.enWords(s.en) where !target.contains(w.lowercased()) && seen.insert(w.lowercased()).inserted { pool.append(w) }
                if pool.count > 40 { break }
            }
            let words = enWords + pool.shuffled().prefix(nDistract)
            tiles = words.enumerated().map { Tile(id: $0.offset, text: $0.element, pinyin: nil) }
        }
        return Exercise(kind: .sentence, dir: "sentence", card: c, sentence: sent, toChinese: toChinese, tiles: tiles.shuffled())
    }

    /// Whether the tiles placed, in order, make the sentence.
    func check(_ placed: [Tile]) -> Bool {
        guard let sent = sentence else { return false }
        let texts = placed.map(\.text)
        if toChinese { return sent.acceptedOrders.contains(texts) }
        return texts.map { $0.lowercased() } == Sentence.enWords(sent.en).map { $0.lowercased() }
    }
}
