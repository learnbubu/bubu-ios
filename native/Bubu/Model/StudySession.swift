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
    static let stoneLen = 12          // (was 15: the owner, 4 Oct 2026, "feels slow learning")
    /// How often each new word comes up in its stone's session: usually `newReps` (3 when a
    /// stone has 4–5 new words), up to `newRepsMax` when there are too few earlier words to
    /// review (the course's first stones).
    static let newRepsMin = 3, newReps = 3, newRepsMax = 4
    /// A new word's first right answers in a session schedule its reviews; the extra practice
    /// after them doesn't push its first review further out.
    static let scheduledPerSession = 2
    /// A practice stone's exercises.
    static let practiceLen = 12
    static let xpCorrect = 2, xpCombo = 3, xpPerfect = 5, xpSession = 10, xpLesson = 25, comboAt = 5

    /// The exercise kinds, as the web's FOCUSES.
    static let allDirs = ["recognize", "recall", "pinyin", "listen", "write", "sentence", "speak"]

    enum Item {
        case meet(cards: [Card], first: Bool, left: Int)
        case card(Card)
        /// Tap the pairs (see MatchView): 4–5 words already met, Chinese beside English, or
        /// (`listen`, when every word is past its first rung) sounds beside characters.
        case match(cards: [Card], listen: Bool)
    }

    /// A match exercise's pairs: at most this many, and it needs at least `matchMin` words
    /// known or just met (with different characters and meanings) to be asked at all.
    static let matchMax = 5, matchMin = 4
    /// How many matches a practice stone has: one half-way, one at the end. They take the
    /// place of two of its exercises, so it stays `practiceLen` steps long.
    static let practiceMatches = 2

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
    /// the words with no record when the session started, in any kind of session: a word in
    /// its very first session is never spoken
    private let newAtStart: Set<String>
    /// "Can't speak now", or no microphone: no more speaking this session
    private var speakingOff = false
    /// "Can't listen now": no more listening this session
    private(set) var listeningOff = false
    /// "Can't listen now" in a session of only listening: it ended there, not played through
    private var endedEarly = false
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
    /// The words missed this session, waiting for the end-of-lesson mistakes stretch: they
    /// come back once the planned exercises (`queue`) are done.
    private(set) var retries: [Card] = []
    /// The exercise on screen is a word missed earlier this session, back in the mistakes
    /// stretch: it's labelled "Previous mistake".
    private(set) var previousMistake = false
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
    /// how the session's XP was made up, for the done screen's XP tile (Lesson XP, then the
    /// extra a run earned, then what double XP added): the extra for runs, and the doubling
    private(set) var xpComboExtra = 0
    private(set) var xpDoubled = 0
    private(set) var combo = 0
    private(set) var mistakes = 0
    private(set) var fixedCount = 0
    /// The match on screen: the words paired so far, and whether it pairs sounds with characters.
    private(set) var matched: Set<String> = []
    private(set) var matchAudio = false
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
        /// the words met this session, for the done screen's "You learned" card
        var learned: [Card] = []
        /// a practice stone's words (up to 6), for its "You practised" card
        var practised: [Card] = []
        /// of `xp`: the extra runs earned, and what double XP added (the rest is the lesson's own)
        var xpCombo = 0
        var xpDouble = 0
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
        // a practice stone's two matches, when it has enough words met (they replace two exercises)
        let pMatches: [[Card]] = practice ? StudySession.practiceMatchWords(lessonId, progress) : []
        let practiceCount = StudySession.practiceLen - pMatches.count
        let chosen = cards ?? (practice ? StudySession.practiceQueue(lessonId, progress, count: practiceCount)
                                        : StudySession.buildQueue(lessonId: lessonId, progress: progress, focuses: self.focuses))
        self.scope = scope ?? (practice ? Set(Course.shared.practiceScope(lessonId)) : mode == .lesson ? [lessonId] : Set(chosen.map(\.lessonId)))
        self.source = chosen
        self.freshIds = shaped ? Set(chosen.filter { progress.srs[$0.id] == nil }.map(\.id)) : []
        self.newAtStart = Set(chosen.filter { progress.srs[$0.id] == nil }.map(\.id))
        // a practice stone meets no words: it's all exercises, in the order they were picked
        var items: [Item] = mode == .quiz || mode == .placement || practice ? chosen.map { .card($0) } : sessionOrder(chosen)
        // tap the pairs: twice in a practice stone, once near the end of a stone's session
        if practice && !pMatches.isEmpty {
            items = StudySession.withPracticeMatches(items, pMatches)
        } else if shaped {
            items = StudySession.withStoneMatch(items, progress)
        }
        self.queue = items
        // the progress bar's steps: each exercise, and each match as one (see progressFraction)
        self.sessionTotal = items.filter { if case .meet = $0 { return false } else { return true } }.count
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
    static func practiceQueue(_ lessonId: String, _ p: ProgressStore, count: Int = practiceLen) -> [Card] {
        let pool = Course.shared.practiceCards(lessonId).shuffled()
            .sorted { weakness(p.srs[$0.id]) > weakness(p.srs[$1.id]) }
        guard !pool.isEmpty, count > 0 else { return [] }
        var picked = Array(pool.prefix(count))
        var i = 0
        while picked.count < count { picked.append(pool[i % pool.count]); i += 1 }
        var out = picked.shuffled()
        var tries = 0
        while tries < 50, out.indices.dropFirst().contains(where: { out[$0].id == out[$0 - 1].id }) { out.shuffle(); tries += 1 }
        return out
    }

    // MARK: tap the pairs

    /// Up to `matchMax` words for a match, in the order given, each with its own characters and
    /// its own meaning (so every tile has exactly one partner); none when fewer than `matchMin`.
    static func matchWords(_ cards: [Card]) -> [Card] {
        var hanzi = Set<String>()
        var glosses = Set<String>()
        var out: [Card] = []
        for c in cards where out.count < matchMax && !c.isSentence {
            let g = c.word.gloss.lowercased()
            if hanzi.contains(c.word.hanzi) || glosses.contains(g) { continue }
            hanzi.insert(c.word.hanzi)
            glosses.insert(g)
            out.append(c)
        }
        return out.count >= matchMin ? out : []
    }

    /// A practice stone's two matches, on its words already met, weakest first: the second
    /// takes the words the first left out, then some of the first's again. Empty when there
    /// are too few words met.
    static func practiceMatchWords(_ lessonId: String, _ p: ProgressStore) -> [[Card]] {
        let pool = Course.shared.practiceCards(lessonId).filter { p.srs[$0.id] != nil }.shuffled()
            .sorted { weakness(p.srs[$0.id]) > weakness(p.srs[$1.id]) }
        let first = matchWords(pool)
        guard !first.isEmpty else { return [] }
        let firstIds = Set(first.map(\.id))
        let second = matchWords(pool.filter { !firstIds.contains($0.id) } + first.shuffled())
        guard !second.isEmpty else { return [first] }
        return [first, second]
    }

    /// A practice stone's exercises with its matches: the first half-way, the second at the
    /// end (it may pair sounds with characters, see next()).
    static func withPracticeMatches(_ items: [Item], _ matches: [[Card]]) -> [Item] {
        var out = items
        if matches.count >= 2 {
            out.insert(.match(cards: matches[0], listen: false), at: out.count / 2)
            out.append(.match(cards: matches[1], listen: true))
        } else if let only = matches.first {
            out.append(.match(cards: only, listen: false))
        }
        return out
    }

    /// A stone's session with one match about two-thirds of the way through, after the last
    /// new word has been met and asked once, on the words known or met by then: the stone's
    /// new words first, then the earlier ones it reviews, weakest first. Unchanged when there
    /// are fewer than `matchMin` of them (the course's first stone).
    static func withStoneMatch(_ items: [Item], _ p: ProgressStore) -> [Item] {
        let isCard = { (it: Item) -> Bool in if case .card = it { return true } else { return false } }
        let nCards = items.filter(isCard).count
        guard nCards > 0 else { return items }
        let lastMeet = items.lastIndex { if case .meet = $0 { return true } else { return false } } ?? -1
        let target = (nCards * 2 + 2) / 3
        var at = items.count, seen = 0
        for (i, it) in items.enumerated() where isCard(it) {
            seen += 1
            if seen == target { at = i + 1; break }
        }
        at = min(items.count, max(at, lastMeet + 2))
        // the words met by then: those met on a card before it, and those with a record
        var metBefore = Set<String>()
        for it in items[..<at] { if case .meet(let cs, _, _) = it { metBefore.formUnion(cs.map(\.id)) } }
        var fresh: [Card] = [], known: [Card] = []
        var ids = Set<String>()
        for it in items {
            guard case .card(let c) = it, ids.insert(c.id).inserted else { continue }
            if p.srs[c.id] != nil { known.append(c) } else if metBefore.contains(c.id) { fresh.append(c) }
        }
        known = known.shuffled().sorted { weakness(p.srs[$0.id]) > weakness(p.srs[$1.id]) }
        let words = matchWords(fresh + known)
        guard !words.isEmpty else { return items }
        var out = items
        out.insert(.match(cards: words, listen: false), at: at)
        return out
    }

    /// A word still new to the learner (the match shows its pinyin): met this session, or not
    /// yet got right.
    func isStillNew(_ cardId: String) -> Bool {
        freshIds.contains(cardId) || metInSession.contains(cardId) || Self.isNewCard(progress.srs[cardId])
    }

    /// Whether a word is past its first rung: right once this session, or before it.
    private func pastFirstRung(_ c: Card) -> Bool {
        (rightInSession[c.id] ?? 0) >= 1 || (progress.srs[c.id]?.reps ?? 0) >= 1
    }

    /// The words of the match on screen.
    var matchCards: [Card] { if case .match(let cs, _) = current { return cs } else { return [] } }
    var matchFinished: Bool { !matchCards.isEmpty && matched.count >= matchCards.count }

    /// XP through here, so the done screen can show how it was made up: the extra a run earned,
    /// and what double XP added.
    @discardableResult private func gain(_ n: Int, comboExtra: Int = 0) -> (earned: Int, goalReached: Bool) {
        let r = progress.earnXP(n)
        if r.earned > n { xpDoubled += r.earned - n }
        xpComboExtra += comboExtra
        return r
    }

    /// A pair tapped in the match on screen: the word on the left and the word on the right.
    /// A right pair counts as a right answer on that word for XP and the quest counters; only a
    /// word's first `scheduledPerSession` right answers this session reschedule it (and a word
    /// with a mistake waiting keeps it for a real exercise). A wrong pair costs nothing: no
    /// bun, no XP, no mistake saved. Finishing the match is one step of the progress bar.
    @discardableResult
    func matchPair(_ leftId: String, _ rightId: String) -> Bool {
        guard case .match(let cards, _) = current, !matched.contains(leftId), !matched.contains(rightId),
              leftId == rightId, let c = cards.first(where: { $0.id == leftId }) else { return false }
        progress.holdSaves()
        defer { progress.releaseSaves() }
        matched.insert(c.id)
        let kind = matchAudio ? "listen" : "match"
        if (rightInSession[c.id] ?? 0) < Self.scheduledPerSession && progress.srs[c.id]?.miss == nil {
            _ = progress.answer(c.id, correct: true, dir: kind, sessionStart: start, mistakesMode: false, schedule: true)
        }
        progress.recordReview()
        rightInSession[c.id, default: 0] += 1
        combo += 1
        if combo == Self.comboAt { DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { Sounds.shared.play("combo") } }
        let mark = progress.xpCounter
        gain(combo >= Self.comboAt ? Self.xpCombo : Self.xpCorrect, comboExtra: combo >= Self.comboAt ? Self.xpCombo - Self.xpCorrect : 0)
        progress.questEvent(kind, correct: true)
        sessionXP += progress.xpCounter - mark
        if matched.count >= cards.count {
            answered = true
            stepsDone += 1
        }
        return true
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
        let cards = cards.filter { !$0.isSentence }
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
        let items = range.flatMap { lid in Course.shared.cards(in: lid).filter { !$0.isSentence }.shuffled().prefix(perLesson) }.shuffled()
        let s = StudySession(lessonId: "", progress: p, focuses: ["recognize", "recall"], cards: items, mode: .placement,
                             title: "\(label) · \(items.count) question\(items.count == 1 ? "" : "s")")
        s.placeRange = Array(range); s.placeTarget = target
        s.placeScores = Dictionary(uniqueKeysWithValues: range.map { ($0, (0, 0)) })
        return s
    }

    /// A probe's questions: spread across the chapter's lessons, one word from each in turn.
    private static func probeCards(_ block: [String]) -> [Card] {
        var pools = block.map { Course.shared.cards(in: $0).filter { !$0.isSentence }.shuffled() }.filter { !$0.isEmpty }.shuffled()
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
        // speaking only: the words already met (a word is never spoken before it's been met)
        if focuses == ["speak"] {
            let met = cards.filter { progress.srs[$0.id] != nil }
            if !met.isEmpty { cards = met }
        }
        if focuses == ["sentence"] {
            let withSentences = cards.filter { c in !course.sentences(for: c, met: { id in progress.srs[id] != nil }).isEmpty }
            if !withSentences.isEmpty { cards = withSentences }
        }
        let now = progress.now()
        // a stone still open always asks its words not yet got right, due or not: a quick
        // second go after leaving half-way must be able to finish the stone
        let stillOpen = !progress.isDone(lessonId)
        let due = cards.filter { c in
            guard let r = progress.srs[c.id] else { return true }
            if stillOpen && (r.reps ?? 0) < 1 { return true }
            return (r.due ?? 0) <= now
        }
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

    /// Words skipped ("Can't speak now") that wait among the mistakes: not labelled as one.
    private var skippedBack: Set<String> = []

    func next() {
        let lastId = card?.id
        answered = false
        lastCorrect = nil
        exercise = nil
        matched = []
        matchAudio = false
        previousMistake = false
        if queue.isEmpty, mode == .placement, !placeBlocks.isEmpty, let b = nextProbe() {
            placeProbe = b; probes += 1
            queue = Self.probeCards(placeBlocks[b]).map { .card($0) }
            sessionTotal = max(sessionTotal, stepsDone + Self.probeSize)
        }
        guard hasMore else { finish(); return }
        // the planned exercises first, then the mistakes stretch
        // (a word just asked, skipped back into the plan, waits behind whatever else is left)
        if case .card(let first)? = queue.first, first.id == lastId {
            if queue.count > 1 { queue.append(queue.removeFirst()) }
            else if !retries.isEmpty { queue.removeFirst(); retries.append(first); skippedBack.insert(first.id) }
        }
        let item: Item
        if queue.isEmpty, let i = Self.nextRetry(retries.map(\.id), after: lastId) {
            let c = retries.remove(at: i)
            item = .card(c)
            // a skipped word waiting among the mistakes isn't one itself
            previousMistake = skippedBack.remove(c.id) == nil
        } else {
            item = queue.removeFirst()
        }
        current = item
        if case .meet(let cards, _, _) = item { metInSession.formUnion(cards.map(\.id)) }
        // a match may pair sounds with characters once all its words are past their first
        // rung, and listening is switched on
        if case .match(let cards, let listen) = item {
            matchAudio = listen && !listeningOff && focuses.contains("listen") && cards.allSatisfy { pastFirstRung($0) }
        }
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

    /// Whether anything is left to ask: planned exercises, or mistakes waiting to come back.
    var hasMore: Bool { !queue.isEmpty || !retries.isEmpty }

    /// Which of the mistakes waiting comes next (an index into `waiting`, their words' ids in
    /// order; nil when none wait): the first that isn't the word just asked, so a missed word
    /// is never the very next exercise unless it's the only thing left.
    static func nextRetry(_ waiting: [String], after last: String?) -> Int? {
        guard !waiting.isEmpty else { return nil }
        return waiting.firstIndex { $0 != last } ?? 0
    }

    /// A new word's exercises in its stone's session, easy to hard, one rung per right answer:
    /// recognise it, hear it (or pick its tones), recall its characters or build a sentence
    /// with it, then the harder kinds again. Each rung lists its kinds in order of preference.
    /// (1 Oct 2026, the owner: "follow the structure of duolingo lessons": fewer single words with
    /// four options, more sentences.) After its first recognition a word is met in sentences:
    /// translated with tiles, a gap filled, heard and built; and, a little (`ladderOnce`),
    /// written or said.
    static let newWordLadder: [[String]] = [
        ["picture", "recognize", "listen"],
        ["sentence", "gap", "listen", "pinyin"],
        ["hear", "gap", "recall", "sentence", "type", "build", "write", "speak"],
        ["gap", "sentence", "hear", "type", "write", "speak", "pinyin", "recall"],
        ["type", "speak", "write", "hear", "sentence", "recall", "listen"],
    ]
    /// A stone's new words are written once and said once in its session, no more ("a little").
    static let ladderOnce: Set<String> = ["write", "speak", "type", "build"]
    /// A new word may be written or said once it's been got right this often in the session.
    static let rightBeforeSpeaking = 2

    /// The kinds that need a sentence the learner can read (see Course.sentences(for:met:)).
    static let sentenceKinds: Set<String> = ["sentence", "gap", "hear"]

    /// A new word's exercise from its ladder (nil: none of its rung's kinds are switched on).
    /// Past the first rung it avoids the kind just asked and the word's own last kind, and
    /// takes the kind asked least this session, so the session doesn't repeat itself.
    private func ladderDir(_ c: Card, _ enabled: [String]) -> String? {
        let rung = min(rightInSession[c.id] ?? 0, Self.newWordLadder.count - 1)
        var on = Self.newWordLadder[rung].filter { enabled.contains($0) }
        if on.contains(where: { !Self.ladderOnce.contains($0) }) {
            on.removeAll { Self.ladderOnce.contains($0) && (dirsUsed[$0] ?? 0) >= 1 }
        }
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
        // a whole sentence is read and its English built from tiles: never multiple choice
        if c.isSentence, c.ownSentence != nil {
            dirByCard[c.id] = "sentence"; lastDir = "sentence"
            return "sentence"
        }
        if isQuiz {
            let mc = focuses.filter {
                !["write", "sentence", "speak"].contains($0) && (tonesTaught || $0 != "pinyin") && (!listeningOff || $0 != "listen")
            }
            return mc.randomElement() ?? "recognize"
        }
        let s = progress.srs[c.id]
        if mode == .mistakes, let m = s?.miss, dirByCard[c.id] == nil, missedDirPossible(c, m.d) {
            dirByCard[c.id] = m.d; lastDir = m.d; return m.d
        }
        var enabled = Self.allDirs.filter { focuses.contains($0) }
        // filling a gap goes with building sentences, and "tap what you hear" with those and listening
        if focuses.contains("sentence") { enabled.append("gap") }
        if focuses.contains("sentence") && focuses.contains("listen") { enabled.append("hear") }
        // picture cards for a word with a picture, when three others with pictures can stand beside it
        if focuses.contains("recognize") && Exercise.pictureChoice(c) != nil { enabled.append("picture") }
        // building a character from its parts goes with writing
        if focuses.contains("write") && Exercise.buildChoice(c) != nil { enabled.append("build") }
        // typing the pinyin goes with recalling a word (a phrase taught as one item isn't typed)
        if focuses.contains("recall") && !c.isSentence && c.word.hanzi.filter(Course.isHan).count <= 3 { enabled.append("type") }
        // "Which pinyin?" asks about tones: not until they've been introduced
        if !tonesTaught { enabled.removeAll { $0 == "pinyin" } }
        // a sentence only when all its other words have been met (see Course.sentences(for:met:))
        let usable = course.sentences(for: c, met: isMet)
        if usable.isEmpty { enabled.removeAll { Self.sentenceKinds.contains($0) } }
        // a gap needs the word standing as a word of its own in the sentence
        if course.gapSentences(for: c, among: usable).isEmpty { enabled.removeAll { $0 == "gap" } }
        if !StrokeData.shared.writable(c.word.hanzi) { enabled.removeAll { $0 == "write" } }
        // no speaking a word in its very first session, or once speaking's been put off
        if !maySpeak(c) { enabled.removeAll { $0 == "speak" } }
        // no listening once it's been put off ("Can't listen now")
        if listeningOff { enabled.removeAll { $0 == "listen" || $0 == "hear" } }
        // a word new in a stone's session climbs its own ladder
        if freshIds.contains(c.id), let d = ladderDir(c, enabled) {
            dirByCard[c.id] = d
            lastDir = d
            return d
        }
        if focuses.count > 1 {
            let reps = s?.reps ?? 0, interval = s?.interval ?? 0
            let level = reps >= 2 || interval >= 7 ? 2 : reps >= 1 ? 1 : 0
            let rung: [String]? = level == 0 ? ["recognize", "listen", "picture"] : level == 1 ? ["recall", "pinyin", "sentence", "listen", "gap", "hear", "picture"] : nil
            if let rung {
                var on = enabled.filter { rung.contains($0) }
                if let before = dirByCard[c.id], on.count > 1 { on.removeAll { $0 == before } }
                let eased = enabled.filter { $0 != "write" && $0 != "speak" }
                enabled = on.isEmpty ? (eased.isEmpty ? enabled : eased) : on
            }
        }
        if enabled.isEmpty { enabled = ["recognize"] }
        // reviews too: each of the harder kinds (write, speak, type, build) once a lesson at most
        // (the step logs of 4 Oct 2026 showed four to six of them in a lesson of fifteen)
        if enabled.contains(where: { !Self.ladderOnce.contains($0) }) {
            enabled.removeAll { Self.ladderOnce.contains($0) && (dirsUsed[$0] ?? 0) >= 1 }
        }
        if let l = lastDir, enabled.count > 1 { enabled.removeAll { $0 == l } }
        // a word with a picture gets its picture card often, not as one kind in eight (the owner,
        // 5 Oct 2026: "not really seeing that exercise"): up to twice a session
        if enabled.contains("picture"), (dirsUsed["picture"] ?? 0) < 2, Double.random(in: 0..<1) < 0.45 {
            dirByCard[c.id] = "picture"
            lastDir = "picture"
            return "picture"
        }
        let d = enabled.randomElement() ?? "recognize"
        dirByCard[c.id] = d
        lastDir = d
        return d
    }

    private func missedDirPossible(_ c: Card, _ d: String) -> Bool {
        if d == "write" { return StrokeData.shared.writable(c.word.hanzi) }
        if d == "gap" { return !course.gapSentences(for: c, met: isMet).isEmpty }
        if Self.sentenceKinds.contains(d) { return (c.isSentence && c.ownSentence != nil) || !course.sentences(for: c, met: isMet).isEmpty }
        if d == "pinyin" { return tonesTaught }
        if d == "speak" { return maySpeak(c) }
        if d == "listen" { return !listeningOff }
        return Self.allDirs.contains(d)
    }

    /// Whether a word may be spoken now: in its very first session (new when the session began,
    /// or met on screen in it) only after a couple of right answers, and not once "Can't speak
    /// now" has been tapped.
    func maySpeak(_ c: Card) -> Bool {
        guard !speakingOff else { return false }
        // in a word's first session, not until it's been got right a couple of times
        return !Self.inFirstSession(c.id, newAtStart: newAtStart, metInSession: metInSession)
            || (rightInSession[c.id] ?? 0) >= Self.rightBeforeSpeaking
    }

    /// A word's very first session: it had no record when the session began, or was met on
    /// screen in it.
    static func inFirstSession(_ cardId: String, newAtStart: Set<String>, metInSession: Set<String>) -> Bool {
        newAtStart.contains(cardId) || metInSession.contains(cardId)
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
            // (a word not yet got right, or missed since, always counts: else a late mistake
            // would leave it unlearnt and the stone could never complete)
            let unlearnt = (progress.srs[c.id]?.reps ?? 0) < 1
            let schedule = !stoneShaped || unlearnt || (rightInSession[c.id] ?? 0) < Self.scheduledPerSession
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
            gain(combo >= Self.comboAt ? Self.xpCombo : Self.xpCorrect, comboExtra: combo >= Self.comboAt ? Self.xpCombo - Self.xpCorrect : 0)
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
            // a missed word comes back after the planned exercises, in the mistakes stretch
            againCount += 1
            retries.append(c)
        }
        return xp
    }

    /// Shuffle what's left (web: #studyShuffle). New words keep their order until all are met.
    func shuffleRest() -> Bool {
        guard !hasMeetLeft else { return false }
        if !answered, let c = card {
            if previousMistake { retries.append(c) } else { queue.append(.card(c)) }
        }
        if !answered, let m = current, case .match = m { queue.append(m) }
        queue.shuffle()
        next()
        return true
    }

    /// "Can't speak now" (or no microphone) and "Can't listen now": the word comes back later
    /// as another kind of exercise, with no penalty and no XP, and there's no more speaking
    /// (or listening, when it's a listening exercise that's skipped) this session. A session
    /// of only listening has nothing else to ask, so it ends there.
    func skip() {
        guard !answered, let c = card else { return }
        answered = true
        if dir == "listen" || dir == "hear" {
            listeningOff = true
            if focuses == ["listen"] {
                endedEarly = true
                queue = []
                retries = []
                return
            }
        } else {
            speakingOff = true
        }
        if previousMistake { retries.append(c) } else { queue.append(.card(c)) }
    }

    /// Nothing was answered and no match finished: a session that ended at "Can't listen now"
    /// before it began. Nothing is earned for it.
    var nothingAnswered: Bool { answeredCount == 0 && stepsDone == 0 }

    /// A match is one step: the bar creeps through it a pair at a time, and it's counted
    /// in `stepsDone` once every pair is found.
    var progressFraction: Double {
        guard sessionTotal > 0 else { return 0 }
        let pairs = matchCards.count
        let part = pairs == 0 || matchFinished ? 0 : Double(matched.count) / Double(pairs)
        // a wrong answer moves the bar too, half a step, as Duolingo's does (the step it owes is
        // added to the length, so the bar still ends exactly full)
        let missed = isQuiz ? 0 : Double(againCount) * 0.5
        return min(Double(stepsDone) + part + missed, Double(sessionTotal) + missed) / (Double(sessionTotal) + missed)
    }
    var hasMeetLeft: Bool { queue.contains { if case .meet = $0 { return true } else { return false } } }

    // MARK: the end

    private func finish() {
        current = nil
        progress.holdSaves(); defer { progress.releaseSaves() }
        if mode == .placement { return finishPlacement() }
        let lessonCards = mode == .lesson ? course.cards(in: lessonId) : []
        // a practice stone is finished by playing it through (not by ending it early)
        let played = isPractice && !endedEarly
        let cleared = played || (!lessonCards.isEmpty && lessonCards.allSatisfy { (progress.srs[$0.id]?.reps ?? 0) >= 1 })
        let justFinished = mode == .lesson && !progress.isDone(lessonId) && cleared
        if justFinished { progress.markDone(lessonId) }
        let perfect = againCount == 0 && answeredCount >= 5
        let mark = progress.xpCounter
        var goal = false
        // a session ended before anything was answered earns nothing: no XP, no fire
        let idle = nothingAnswered && !justFinished
        if !idle {
            progress.questEvent("session", correct: true, lesson: justFinished, perfect: perfect)
            let s = gain(justFinished ? Self.xpLesson : Self.xpSession)
            goal = goal || s.goalReached
            if perfect { let p = gain(Self.xpPerfect); goal = goal || p.goalReached }
        }
        sessionXP += progress.xpCounter - mark
        if justFinished {
            progress.startBoost()
            redPocket()
            storyUnlocked()
        }
        let fire: ProgressStore.Fire? = idle ? nil : progress.lightFire()
        let left = justFinished ? 0 : lessonCards.filter { (progress.srs[$0.id]?.reps ?? 0) < 1 }.count
        // a lesson comes in steps (its batches of new words): one done, more to go
        let total = mode == .lesson ? Self.lessonSteps(lessonId, progress).total : 0
        let stepDone = left > 0 && stepAtStart > 0 && stepAtStart < total
        let title = mode == .quiz ? "Quiz complete" : mode == .mistakes ? "Mistakes practised" : [.review, .trouble].contains(mode) ? "Review complete"
            : played ? (self.title == "Chapter review" ? "Chapter review done!" : "Practice done!")
            : justFinished ? "Lesson complete!" : stepDone ? "Step \(stepAtStart) of \(total) done" : "Session complete"
        let seconds = Int(((progress.now() - start) / 1000).rounded())
        let accuracy = answeredCount == 0 ? 100 : Int((Double(answeredCount - againCount) / Double(answeredCount) * 100).rounded())
        result = Result(title: title, xp: sessionXP, seconds: seconds, accuracy: accuracy, perfect: perfect,
                        lessonFinished: justFinished, fireJustLit: fire != nil, goalReached: goal,
                        mistakes: mistakes, fixed: fixedCount,
                        nextLessonId: justFinished ? nextLesson(after: lessonId) : nil, wordsLeft: left,
                        fire: fire, mode: mode)
        if stepDone { result?.step = stepAtStart; result?.steps = total }
        result?.learned = learnedWords
        result?.xpCombo = xpComboExtra
        result?.xpDouble = xpDoubled
        if isPractice { result?.practised = practisedWords }
        if !idle { Coach.sessionFinished() }
    }

    /// The words met this session, in the lesson's order (the done screen's "You learned").
    var learnedWords: [Card] {
        var seen = Set<String>()
        return source.filter { metInSession.contains($0.id) && seen.insert($0.id).inserted }
    }

    /// A practice stone's words, up to six, in the order they came (its "You practised").
    var practisedWords: [Card] {
        var seen = Set<String>()
        return Array(source.filter { seen.insert($0.id).inserted }.prefix(6))
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
        // after the done screen's opening splash (about 1.35 s), not over it
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { Moments.shared.show(.pocket(pocket)) }
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
        let c = dir == "sentence" ? (course.cards.first { !course.sentences(for: $0).isEmpty } ?? cards[0])
            : dir == "gap" || dir == "hear" ? (course.cards.first { $0.word.hanzi == "是" } ?? cards[0])
            : dir == "picture" ? (course.cards.first { $0.word.hanzi == "茶" } ?? cards[0])
            : dir == "build" ? (course.cards.first { $0.word.hanzi == "好" } ?? cards[0]) : cards[0]
        current = .card(c)
        self.dir = dir
        // every word counts as met here, so the screenshot always has a sentence
        exercise = Exercise.make(card: c, dir: dir, scope: [c.lessonId], progress: progress, met: { _ in true })
        exercise?.isNew = true
    }
    /// four right already, so the next right answer is the fifth in a row
    func debugCombo(_ n: Int) { combo = n }
    /// the pairs screenshot: four of the lesson's words to match, with more of the lesson after
    func debugMatch() {
        exercise = nil
        matched = []
        matchAudio = false
        current = .match(cards: Array(course.cards(in: lessonId).prefix(4)), listen: false)
    }
    /// the done screenshot with every XP step: a run's extra and double XP in the total
    func debugFinishBoosted() {
        debugFinish()
        // the parts as shares of whatever the debug finish came to (it differs from one install
        // to the next): a fifth from a run, half doubled, the rest the lesson's own
        guard let x = result?.xp, x > 0 else { return }
        result?.xpCombo = x / 5
        result?.xpDouble = x / 2
    }
    func debugFinish() {
        combo = 4; answeredCount = 8; againCount = 1; stepsDone = sessionTotal
        queue = []
        retries = []
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
    enum Kind { case choice, sentence, speak, write, type, build }
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
    /// "Tap what you hear": the sentence is only said, and built from Chinese tiles
    var hearOnly = false
    /// a typing exercise answered in characters (the iPhone's Chinese keyboard), not pinyin
    var typeHanzi = false
    /// a word not learned yet when the question was asked: shows the NEW WORD badge
    var isNew = false
    /// writing help, a `WriteGuidance` raw value: 0 full, 1 outline, 2 from memory
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
        case "hear": return "Tap what you hear"
        case "gap": return "Fill the gap"
        case "speak": return "Say it out loud"
        case "write": return (WriteGuidance(rawValue: writeStage) ?? .full).label
        case "type": return typeHanzi ? "Type it in Chinese" : "Type it in pinyin"
        case "build": return "Build the character"
        case "picture": return "Which one is “\(card.word.gloss)”?"
        default: return "What does this mean?"
        }
    }

    /// `met` says whether a word (a card id) has been met: a sentence may only use met words.
    static func make(card c: Card, dir: String, scope: Set<String>, progress: ProgressStore,
                     met: ((String) -> Bool)? = nil) -> Exercise? {
        switch dir {
        case "sentence": return sentence(c, met: met ?? { progress.srs[$0] != nil })
        case "hear": return sentence(c, met: met ?? { progress.srs[$0] != nil }, hear: true)
        case "type":
            // (the owner, 4 Oct 2026: characters preferred, pinyin fine for the first books, and a choice)
            return Exercise(kind: .type, dir: "type", card: c, answer: c.word.pinyin,
                            typeHanzi: typesHanzi(c, setting: progress.prefs.typing))
        case "picture": return pictureChoice(c)
        case "build": return buildChoice(c)
        case "gap": return gap(c, scope: scope, met: met ?? { progress.srs[$0] != nil })
        case "speak": return speak(c, met: met ?? { progress.srs[$0] != nil })
        case "write":
            // the help fades as the characters are written: the least-written one sets the prompt
            let times = c.word.hanzi.filter(Course.isHan).map { progress.timesWritten(String($0)) }
            let stage = WriteGuidance(timesWritten: times.min() ?? 0)
            return Exercise(kind: .write, dir: "write", card: c, writeStage: stage.rawValue)
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
        // whole sentences are never options (see Card.isSentence)
        let words = course.cards.filter { !$0.isSentence }
        let inScope = words.filter { scope.contains($0.lessonId) }
        let cards = inScope.isEmpty ? words : inScope
        let answer = field(c.word, dir)
        var distractors: [String] = []
        let others = { (exclude: [String]) -> [String] in
            var seen = Set<String>(), out: [String] = []
            for x in cards { let v = field(x.word, dir); if v != answer && !exclude.contains(v) && seen.insert(v).inserted { out.append(v) } }
            return out.shuffled()
        }
        switch dir {
        case "pinyin":
            // (never a "wrong" option that is also a right way to say it: Fà guó for 法国)
            distractors = Array(Pinyin.variants(answer, 8)
                .filter { !Pinyin.isAlsoRight($0, hanzi: c.word.hanzi, pinyin: answer) }.prefix(3))
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
            let reached = course.lookalikes(c, 8).filter { !$0.isSentence && (course.lessonOrder[$0.lessonId] ?? 0) <= here + Exercise.nearby }
            for x in reached.prefix(2) { let v = field(x.word, dir); if v != answer && !near.contains(v) { near.append(v) } }
            distractors = near + others(near).prefix(3 - near.count)
        }
        // a lesson with very few words borrows from the words nearest it in the course (not
        // "portion, serving" beside 你 on day one), so there are always four options
        if distractors.count < 3 {
            var seen = Set(distractors + [answer])
            let here = course.lessonOrder[c.lessonId] ?? 0
            let nearest = words.sorted { abs((course.lessonOrder[$0.lessonId] ?? 0) - here) < abs((course.lessonOrder[$1.lessonId] ?? 0) - here) }
            for x in nearest.prefix(40).filter({ abs((course.lessonOrder[$0.lessonId] ?? 0) - here) <= Exercise.nearby }).shuffled() + nearest.shuffled()
                where distractors.count < 3 {
                let v = field(x.word, dir)
                if seen.insert(v).inserted { distractors.append(v) }
            }
        }
        return Exercise(kind: .choice, dir: dir, card: c, options: (distractors.prefix(3) + [answer]).shuffled(), answer: answer)
    }

    /// Say it aloud: the word itself, or now and then a short sentence with it in, but only
    /// one whose every word has been met (see Course.speakSentences). `sentenceChance` is how
    /// often a sentence is asked for when one will do.
    static func speak(_ c: Card, met: (String) -> Bool, sentenceChance: Double = 0.5) -> Exercise {
        let ok = Course.shared.speakSentences(for: c, met: met)
        let phrase = !ok.isEmpty && Double.random(in: 0..<1) < sentenceChance ? ok.randomElement() : nil
        return Exercise(kind: .speak, dir: "speak", card: c, sentence: phrase)
    }

    /// Picture cards: four words with pictures, the card's among them, the others from the stones
    /// nearest it (never two with the same picture). Nil when the word has no picture or too few
    /// others do.
    static func pictureChoice(_ c: Card) -> Exercise? {
        let course = Course.shared
        guard let mine = Pictures.of(c.word.hanzi) else { return nil }
        let here = course.lessonOrder[c.lessonId] ?? 0
        let others = course.cards.filter { Pictures.of($0.word.hanzi) != nil && $0.word.hanzi != c.word.hanzi && !$0.isSentence }
            .sorted { abs((course.lessonOrder[$0.lessonId] ?? 0) - here) < abs((course.lessonOrder[$1.lessonId] ?? 0) - here) }
        var options: [String] = [], pics: Set<String> = [mine], words: Set<String> = [c.word.hanzi]
        // from the nearest twelve, shuffled, so it isn't always the same three
        for x in Array(others.prefix(12)).shuffled() + others where options.count < 3 {
            guard let p = Pictures.of(x.word.hanzi), !pics.contains(p), !words.contains(x.word.hanzi) else { continue }
            pics.insert(p); words.insert(x.word.hanzi); options.append(x.word.hanzi)
        }
        guard options.count == 3 else { return nil }
        return Exercise(kind: .choice, dir: "picture", card: c, options: (options + [c.word.hanzi]).shuffled(), answer: c.word.hanzi)
    }

    /// Build the character: a one-character word's parts (女 + 子 = 好) among parts of other
    /// characters, to pick. Nil for a word of more characters, or one that doesn't split into
    /// two or three parts. `options` are the parts to choose from; `answer` the right ones, joined.
    static func buildChoice(_ c: Card) -> Exercise? {
        let ch = c.word.hanzi.filter(Course.isHan)
        guard ch.count == 1, let parts = CharData.shared.chars[ch]?.c?.map({ $0[0] }), (2...3).contains(parts.count),
              Set(parts).count == parts.count, !parts.contains(ch) else { return nil }
        let course = Course.shared
        let here = course.lessonOrder[c.lessonId] ?? 0
        // other parts: from the characters of the words nearest this one in the course
        let near = course.cards.filter { $0.word.hanzi.filter(Course.isHan).count == 1 && $0.word.hanzi != ch }
            .sorted { abs((course.lessonOrder[$0.lessonId] ?? 0) - here) < abs((course.lessonOrder[$1.lessonId] ?? 0) - here) }
        var others: [String] = [], seen = Set(parts)
        for x in Array(near.prefix(30)).shuffled() + near where others.count < 6 - parts.count {
            for p in CharData.shared.chars[x.word.hanzi]?.c?.map({ $0[0] }) ?? [] where others.count < 6 - parts.count {
                if seen.insert(p).inserted { others.append(p) }
            }
        }
        guard others.count == 6 - parts.count else { return nil }
        return Exercise(kind: .build, dir: "build", card: c, options: (parts + others).shuffled(), answer: parts.joined(separator: "|"))
    }

    /// The parts picked make the character: the same parts, in any order.
    func builds(_ picked: Set<String>) -> Bool { picked == Set(answer.components(separatedBy: "|")) }

    /// Whether a word is typed in characters: always, never, or (Automatic) from 起步 4 on.
    static func typesHanzi(_ c: Card, setting: String?) -> Bool {
        switch setting {
        case "hanzi": return true
        case "pinyin": return false
        default: return !["qibu1-", "qibu2-", "qibu3-"].contains { c.lessonId.hasPrefix($0) }
        }
    }

    /// A typed answer: the word's characters always count; in pinyin mode, its pinyin too.
    func typedRight(_ typed: String) -> Bool {
        let han = typed.filter(Course.isHan)
        if !han.isEmpty { return han == card.word.hanzi.filter(Course.isHan) }
        return !typeHanzi && Exercise.typedMatches(typed, pinyin: answer)
    }

    /// Typed pinyin against the right pinyin: letters only, tones optional (tone marks or numbers),
    /// ü as u or v, spaces and apostrophes ignored.
    static func typedMatches(_ typed: String, pinyin: String) -> Bool {
        func plain(_ s: String) -> String {
            s.lowercased().decomposedStringWithCanonicalMapping
                .unicodeScalars.filter { CharacterSet.letters.contains($0) && $0.value < 0x300 }
                .map { String($0) }.joined()
                .replacingOccurrences(of: "v", with: "u").replacingOccurrences(of: "ü", with: "u")
        }
        let a = plain(typed), b = plain(pinyin)
        return !a.isEmpty && a == b
    }

    /// What to say, its pinyin and its meaning.
    var sayHanzi: String { sentence?.hanzi ?? card.word.hanzi }
    var sayPinyin: String { sentence?.pinyin ?? card.word.pinyin }
    var sayEn: String { sentence?.en ?? card.word.gloss }

    /// Word tiles to put in order (web: buildSentenceExercise).
    static func sentence(_ c: Card, met: (String) -> Bool, hear: Bool = false) -> Exercise? {
        let course = Course.shared
        // a sentence card is its own sentence, always Chinese to English
        let own = c.isSentence && !hear ? c.ownSentence : nil
        guard let sent = own ?? course.sentences(for: c, met: met).randomElement() else { return nil }
        let enWords = Sentence.enWords(sent.en)
        let toChinese = hear || (own == nil && (enWords.count < 2 || Bool.random()))
        let long = sent.words.count > 6 || enWords.count > 7
        let nDistract = long ? 2 : 3
        var tiles: [Tile] = []
        // the extra tiles: words already met, as Duolingo has it (the owner, 2 Oct 2026: 快 可 能 in
        // the first lessons), then words from the stones up to this one; never a word from further on
        let here = course.lessonOrder[c.lessonId] ?? 0
        let known = course.cards.filter { !$0.isSentence && met($0.id) }
        let reached = course.cards.filter { !$0.isSentence && (course.lessonOrder[$0.lessonId] ?? .max) <= here }
        if toChinese {
            let target = Set(sent.words.map(\.hanzi))
            var pool: [SentenceWord] = [], seen = Set<String>()
            for group in [known, reached] where pool.count < nDistract {
                for x in group.shuffled() where !target.contains(x.word.hanzi) && seen.insert(x.word.hanzi).inserted {
                    pool.append(SentenceWord(hanzi: x.word.hanzi, pinyin: Course.wordPy[x.word.hanzi] ?? x.word.pinyin))
                }
            }
            // (fewer extra tiles rather than a word not met yet: the first stones have few words)
            let words = sent.words + pool.prefix(nDistract)
            tiles = words.enumerated().map { Tile(id: $0.offset, text: $0.element.hanzi, pinyin: $0.element.pinyin) }
        } else {
            let target = Set(enWords.map { $0.lowercased() })
            var pool: [String] = [], seen = Set<String>()
            // the English of words already met (their one-word meanings), then of other sentences
            for group in [known, reached] where pool.count < nDistract {
                for x in group.shuffled() {
                    let e = Sentence.enWords(x.word.gloss)
                    guard e.count == 1, let w = e.first, w.count > 1, !target.contains(w.lowercased()),
                          seen.insert(w.lowercased()).inserted else { continue }
                    pool.append(w)
                }
            }
            for s in course.sentences.shuffled().prefix(200) where s.en != sent.en && pool.count < nDistract {
                for w in Sentence.enWords(s.en) where !target.contains(w.lowercased()) && seen.insert(w.lowercased()).inserted { pool.append(w) }
            }
            let words = enWords + pool.prefix(nDistract)
            tiles = words.enumerated().map { Tile(id: $0.offset, text: $0.element, pinyin: nil) }
        }
        return Exercise(kind: .sentence, dir: hear ? "hear" : "sentence", card: c, sentence: sent, toChinese: toChinese,
                        tiles: tiles.shuffled(), hearOnly: hear)
    }

    /// Fill the gap: a sentence with the card's word missing, and four words to choose from
    /// (nil when no readable sentence has the word standing by itself).
    static func gap(_ c: Card, scope: Set<String>, met: (String) -> Bool) -> Exercise? {
        let course = Course.shared
        let word = c.word.hanzi
        guard let sent = course.gapSentences(for: c, met: met).randomElement() else { return nil }
        // the other options: words that aren't in the sentence, from the stones in scope (or
        // near this one)
        let inSentence = Set(sent.words.map(\.hanzi))
        let here = course.lessonOrder[c.lessonId] ?? 0
        let fits: (Card) -> Bool = { !inSentence.contains($0.word.hanzi) && $0.word.hanzi != word && !$0.isSentence }
        var options: [String] = [], seen = Set<String>()
        // (the whole course is only looked through if the stones nearby don't have three)
        let groups: [(Card) -> Bool] = [
            { scope.contains($0.lessonId) },
            { abs((course.lessonOrder[$0.lessonId] ?? 0) - here) <= Exercise.nearby },
            { _ in true },
        ]
        for inGroup in groups where options.count < 3 {
            for x in course.cards.filter({ inGroup($0) && fits($0) }).shuffled() where options.count < 3 {
                if seen.insert(x.word.hanzi).inserted { options.append(x.word.hanzi) }
            }
        }
        guard options.count == 3 else { return nil }
        return Exercise(kind: .choice, dir: "gap", card: c, options: (options + [word]).shuffled(), answer: word, sentence: sent)
    }

    /// Whether the tiles placed, in order, make the sentence.
    func check(_ placed: [Tile]) -> Bool {
        guard let sent = sentence else { return false }
        let texts = placed.map(\.text)
        if toChinese { return sent.acceptedOrders.contains(texts) }
        return texts.map { $0.lowercased() } == Sentence.enWords(sent.en).map { $0.lowercased() }
    }
}
