import Foundation
import Observation

/// One Study session, a port of the web app's study flow (launchLesson →
/// buildStudyQueue → sessionOrder → pickDirection → answerStudy → finishStudy).
@Observable
final class StudySession: Identifiable {
    // web constants
    static let newPerSession = 6, reviewPerSession = 4, meetGroup = 3, sessionLen = 12
    static let xpCorrect = 2, xpCombo = 3, xpPerfect = 5, xpSession = 10, xpLesson = 25, comboAt = 5

    /// The exercise kinds, as the web's FOCUSES. Write and speak join once their screens exist.
    static let allDirs = ["recognize", "recall", "pinyin", "listen", "sentence"]

    enum Item {
        case meet(cards: [Card], first: Bool, left: Int)
        case card(Card)
    }

    let id = UUID()
    let lessonId: String
    let focuses: Set<String>
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
    private(set) var answeredCount = 0, againCount = 0, learnedCount = 0
    private(set) var sessionXP = 0
    private(set) var combo = 0
    private(set) var mistakes = 0, fixedCount = 0
    let start: Double
    private var lastDir: String?
    private var dirByCard: [String: String] = [:]
    private let source: [Card]

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
    }

    init(lessonId: String, progress: ProgressStore, focuses: Set<String>? = nil, cards: [Card]? = nil) {
        self.lessonId = lessonId
        self.progress = progress
        self.focuses = focuses ?? Set(Self.allDirs)
        self.start = progress.now()
        let chosen = cards ?? StudySession.buildQueue(lessonId: lessonId, progress: progress, focuses: self.focuses)
        self.source = chosen
        self.queue = sessionOrder(chosen)
        self.sessionTotal = queue.filter { if case .card = $0 { return true } else { return false } }.count
        next()
    }

    // MARK: building the session

    /// A word not yet learned (web: isNewCard).
    static func isNewCard(_ s: SRSRecord?) -> Bool {
        guard let s else { return true }
        return !((s.reps ?? 0) >= 1) && !(s.known ?? false) && !((s.lapses ?? 0) >= 2) && !((s.interval ?? 0) > 0)
    }

    /// Which cards a lesson session studies (web: buildStudyQueue).
    static func buildQueue(lessonId: String, progress: ProgressStore, focuses: Set<String>) -> [Card] {
        let course = Course.shared
        var cards = course.cards(in: lessonId)
        if focuses == ["sentence"] {
            let withSentences = cards.filter { !course.sentences(for: $0).isEmpty }
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
            var reviews: [Card] = []
            var seen = Set(picked.map(\.id))
            let add = { (list: [Card]) in
                for c in list.shuffled() where reviews.count < reviewPerSession && !seen.contains(c.id) {
                    reviews.append(c); seen.insert(c.id)
                }
            }
            add(due.filter { progress.srs[$0.id] != nil })
            add(progress.dueReviewCards(excluding: lessonId))
            add(cards.filter { (progress.srs[$0.id]?.reps ?? 0) >= 1 })
            return picked + reviews
        }
        let pool = (due.isEmpty ? cards : due).shuffled()
        let n = pool.count > sessionLen
            ? Int(ceil(Double(pool.count) / ceil(Double(pool.count) / Double(sessionLen))))
            : pool.count
        return Array(pool.prefix(n))
    }

    /// New words met in threes, each practised twice, reviews woven between (web: sessionOrder).
    private func sessionOrder(_ cards: [Card]) -> [Item] {
        let order = Dictionary(uniqueKeysWithValues: course.cards.enumerated().map { ($1.id, $0) })
        let fresh = cards.filter { progress.srs[$0.id] == nil }.sorted { (order[$0.id] ?? 0) < (order[$1.id] ?? 0) }
        var known = cards.filter { progress.srs[$0.id] != nil }.shuffled()
        if fresh.isEmpty { return cards.shuffled().map { .card($0) } }
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

    // MARK: moving through it

    func next() {
        answered = false
        lastCorrect = nil
        exercise = nil
        guard !queue.isEmpty else { finish(); return }
        let item = queue.removeFirst()
        current = item
        if case .card(let c) = item {
            dir = pickDirection(c)
            exercise = Exercise.make(card: c, dir: dir, lessonId: lessonId, progress: progress)
            if exercise == nil {               // a sentence that couldn't be built: fall back
                dir = "recognize"
                exercise = Exercise.make(card: c, dir: dir, lessonId: lessonId, progress: progress)
            }
            exercise?.isNew = Self.isNewCard(progress.srs[c.id])
        }
    }

    /// Which exercise a card gets, climbing a ladder as the word gets stronger (web: pickDirection).
    private func pickDirection(_ c: Card) -> String {
        let s = progress.srs[c.id]
        if let m = s?.miss, dirByCard[c.id] == nil, focuses.contains(m.d), Self.allDirs.contains(m.d) {
            dirByCard[c.id] = m.d; lastDir = m.d; return m.d
        }
        var enabled = Self.allDirs.filter { focuses.contains($0) }
        if course.sentences(for: c).isEmpty { enabled.removeAll { $0 == "sentence" } }
        if focuses.count > 1 {
            let reps = s?.reps ?? 0, interval = s?.interval ?? 0
            let level = reps >= 2 || interval >= 7 ? 2 : reps >= 1 ? 1 : 0
            let rung: [String]? = level == 0 ? ["recognize", "listen"] : level == 1 ? ["recall", "pinyin", "sentence", "listen"] : nil
            if let rung {
                var on = enabled.filter { rung.contains($0) }
                if let before = dirByCard[c.id], on.count > 1 { on.removeAll { $0 == before } }
                enabled = on.isEmpty ? enabled.filter { $0 != "write" && $0 != "speak" } : on
            } else if let before = dirByCard[c.id], enabled.count > 1 {
                enabled.removeAll { $0 == before }
            }
        }
        if enabled.isEmpty { enabled = ["recognize"] }
        if let l = lastDir, enabled.count > 1 { enabled.removeAll { $0 == l } }
        let d = enabled.randomElement() ?? "recognize"
        dirByCard[c.id] = d
        lastDir = d
        return d
    }

    var card: Card? { if case .card(let c) = current { return c } else { return nil } }

    /// Grade the current card (web: answerStudy). Returns the XP just earned.
    @discardableResult
    func answer(_ correct: Bool) -> Int {
        guard !answered, let c = card else { return 0 }
        answered = true
        let wasNew = Self.isNewCard(progress.srs[c.id])
        lastCorrect = correct
        let r = progress.answer(c.id, correct: correct, dir: dir, sessionStart: start, mistakesMode: false)
        if r.mistake { mistakes += 1 }
        if r.fixed { fixedCount += 1 }
        progress.recordReview()
        // XP for the answer, more on a run
        var xp = 0
        if correct {
            combo += 1
            xp = progress.earnXP(combo >= Self.comboAt ? Self.xpCombo : Self.xpCorrect).earned
        } else {
            combo = 0
        }
        sessionXP += xp
        progress.questEvent(dir, correct: correct)
        answeredCount += 1
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

    var progressFraction: Double { sessionTotal == 0 ? 0 : min(Double(stepsDone), Double(sessionTotal)) / Double(sessionTotal) }
    var hasMeetLeft: Bool { queue.contains { if case .meet = $0 { return true } else { return false } } }

    // MARK: the end

    private func finish() {
        current = nil
        let lessonCards = course.cards(in: lessonId)
        let cleared = lessonCards.allSatisfy { (progress.srs[$0.id]?.reps ?? 0) >= 1 }
        let justFinished = !progress.isDone(lessonId) && cleared
        if justFinished { progress.markDone(lessonId) }
        let perfect = againCount == 0 && answeredCount >= 5
        progress.questEvent("session", correct: true, lesson: justFinished, perfect: perfect)
        var goal = false
        let s = progress.earnXP(justFinished ? Self.xpLesson : Self.xpSession)
        sessionXP += s.earned; goal = goal || s.goalReached
        if perfect { let p = progress.earnXP(Self.xpPerfect); sessionXP += p.earned; goal = goal || p.goalReached }
        if justFinished { progress.startBoost() }
        let lit = progress.lightFire()
        let left = lessonCards.filter { progress.srs[$0.id] == nil }.count
        let title = justFinished ? "Lesson complete" : left > 0 ? "Batch done" : "Session complete"
        let seconds = Int((progress.now() - start) / 1000)
        let accuracy = answeredCount == 0 ? 100 : Int((Double(answeredCount - againCount) / Double(answeredCount) * 100).rounded())
        result = Result(title: title, xp: sessionXP, seconds: seconds, accuracy: accuracy, perfect: perfect,
                        lessonFinished: justFinished, fireJustLit: lit, goalReached: goal,
                        mistakes: mistakes, fixed: fixedCount,
                        nextLessonId: progress.currentLessonId, wordsLeft: left)
    }

    #if DEBUG
    /// For screenshots: skip ahead to a given exercise on a word that suits it.
    func debugShow(dir: String) {
        let cards = course.cards(in: lessonId)
        let c = dir == "sentence" ? (course.cards.first { !course.sentences(for: $0).isEmpty } ?? cards[0]) : cards[0]
        current = .card(c)
        self.dir = dir
        exercise = Exercise.make(card: c, dir: dir, lessonId: c.lessonId, progress: progress)
        exercise?.isNew = true
    }
    func debugFinish() {
        combo = 4; answeredCount = 8; againCount = 1; stepsDone = sessionTotal
        queue = []
        next()
    }
    #endif

    /// The same words again (web: Practice again).
    func again() -> StudySession { StudySession(lessonId: lessonId, progress: progress, focuses: focuses, cards: source) }
}

// MARK: exercises

/// One question on screen: what's asked, the options, and the right answer.
struct Exercise {
    enum Kind { case choice, sentence }
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

    struct Tile: Identifiable, Hashable { let id: Int; let text: String; let pinyin: String? }

    var label: String {
        switch dir {
        case "recall": return "Which characters mean this?"
        case "pinyin": return "Which pinyin is correct?"
        case "listen": return "What did you hear?"
        case "sentence": return toChinese ? "Build the Chinese" : "Translate this sentence"
        default: return "What does this mean?"
        }
    }

    static func make(card c: Card, dir: String, lessonId: String, progress: ProgressStore) -> Exercise? {
        dir == "sentence" ? sentence(c, lessonId: lessonId) : choice(c, dir: dir, lessonId: lessonId)
    }

    private static func field(_ w: Word, _ dir: String) -> String {
        switch dir {
        case "recall": return w.hanzi
        case "pinyin": return w.pinyin
        default: return w.en
        }
    }

    /// One answer and three distractors (web: buildChoiceExercise).
    static func choice(_ c: Card, dir: String, lessonId: String) -> Exercise {
        let course = Course.shared
        let cards = course.cards(in: lessonId).isEmpty ? course.cards : course.cards(in: lessonId)
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
            for x in cards.shuffled() where Pinyin.toneless(x.word.pinyin) == bare && x.word.en != answer && !near.contains(x.word.en) { near.append(x.word.en) }
            distractors = Array(near.prefix(3))
            distractors += others(distractors).prefix(3 - distractors.count)
        default:
            var near: [String] = []
            for x in course.lookalikes(c, 2) { let v = field(x.word, dir); if v != answer && !near.contains(v) { near.append(v) } }
            distractors = near + others(near).prefix(3 - near.count)
        }
        // a small lesson may not have three other answers: borrow from the whole course
        if distractors.count < 3 {
            var seen = Set(distractors + [answer])
            for x in course.cards.shuffled() where distractors.count < 3 {
                let v = field(x.word, dir)
                if seen.insert(v).inserted { distractors.append(v) }
            }
        }
        return Exercise(kind: .choice, dir: dir, card: c, options: (distractors.prefix(3) + [answer]).shuffled(), answer: answer)
    }

    /// Word tiles to put in order (web: buildSentenceExercise).
    static func sentence(_ c: Card, lessonId: String) -> Exercise? {
        let course = Course.shared
        guard let sent = course.sentences(for: c).randomElement() else { return nil }
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
