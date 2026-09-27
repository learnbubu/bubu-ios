import Foundation
import Observation

/// Everything a learner has done, saved as JSON in Application Support.
/// Field names follow the web app's saved progress (srs, done, activity), so a
/// backup from the website can be read here and the other way round.
@Observable
final class ProgressStore {
    private(set) var srs: [String: SRSRecord] = [:]
    private(set) var done: Set<String> = []
    private(set) var xpDays: [String: Int] = [:]      // "2026-09-27" → XP earned that day
    /// today's quest counters (combo, sessions, lessons, perfect, listen, write, speak, sentence)
    private(set) var qc: [String: [String: Int]] = [:]
    private(set) var lit: Set<String> = []            // days a session was finished: the fire
    private(set) var days: [String: Int] = [:]        // reviews answered per day
    private(set) var celebrated: String?              // the day the goal bonus was paid
    private(set) var boostUntil: Double = 0           // double XP until (ms)
    var name: String = ""

    private let course: Course
    private let url: URL
    var now: () -> Double = { Date().timeIntervalSince1970 * 1000 }

    private struct Saved: Codable {
        var srs: [String: SRSRecord]
        var done: [String]
        var xpDays: [String: Int]?
        var name: String?
        var qc: [String: [String: Int]]?
        var lit: [String]?
        var days: [String: Int]?
        var celebrated: String?
        var boostUntil: Double?
    }

    init(course: Course, url: URL? = nil) {
        self.course = course
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.url = url ?? dir.appendingPathComponent("progress.json")
        load()
    }

    // MARK: saving
    private func load() {
        guard let data = try? Data(contentsOf: url),
              let s = try? JSONDecoder().decode(Saved.self, from: data) else { return }
        srs = s.srs; done = Set(s.done); xpDays = s.xpDays ?? [:]; name = s.name ?? ""; qc = s.qc ?? [:]
        lit = Set(s.lit ?? []); days = s.days ?? [:]; celebrated = s.celebrated; boostUntil = s.boostUntil ?? 0
    }

    @ObservationIgnored private var held = 0
    @ObservationIgnored private var pending = false
    /// Hold saves while several changes are made, then write once.
    func holdSaves() { held += 1 }
    func releaseSaves() {
        held = max(0, held - 1)
        if held == 0 && pending { pending = false; save() }
    }

    func save() {
        if held > 0 { pending = true; return }
        let s = Saved(srs: srs, done: done.sorted(), xpDays: xpDays, name: name, qc: qc,
                      lit: lit.sorted(), days: days, celebrated: celebrated, boostUntil: boostUntil)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(s) { try? data.write(to: url, options: .atomic) }
    }

    // MARK: lessons
    func isDone(_ lessonId: String) -> Bool { done.contains(lessonId) }

    /// The first lesson, in course order, that isn't done yet.
    var currentLessonId: String? { course.lessons.first { !done.contains($0.id) }?.id }

    func markDone(_ lessonId: String) { done.insert(lessonId); save() }

    func chapterProgress(_ ci: Int) -> (done: Int, total: Int) {
        let ids = course.chapters[ci].lessons
        return (ids.filter { done.contains($0) }.count, ids.count)
    }

    // MARK: reviews
    func review(_ cardId: String, _ grade: Grade) {
        srs[cardId] = FSRS.schedule(srs[cardId], grade: grade, now: now())
        save()
    }

    var dueCount: Int {
        let t = now()
        return srs.values.filter { ($0.due ?? 0) <= t && ($0.reps ?? 0) > 0 }.count
    }

    /// Due reviews from other lessons, from lessons done or the one you're on (web: dueReviewCards).
    func dueReviewCards(excluding lessonId: String) -> [Card] {
        let t = now(), cur = currentLessonId
        return course.cards.filter { c in
            guard c.lessonId != lessonId, let r = srs[c.id], let due = r.due, due <= t else { return false }
            return done.contains(c.lessonId) || c.lessonId == cur
        }
    }

    var wordsLearned: Int { srs.values.filter { ($0.reps ?? 0) > 0 }.count }

    // MARK: streak and XP
    private static let dayFormat: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    static func dayKey(_ ms: Double) -> String { dayFormat.string(from: Date(timeIntervalSince1970: ms / 1000)) }

    func earn(_ xp: Int) { earnXP(xp) }

    var xpToday: Int { xpDays[Self.dayKey(now())] ?? 0 }

    /// A day counts once a session was finished on it (the web's litOn).
    /// Before this day XP lit the fire; days from then count if they met the old goal.
    static let litCutoff = "2026-09-19"
    func litOn(_ day: String) -> Bool {
        lit.contains(day) || (day < Self.litCutoff && ((xpDays[day] ?? 0) >= 10 || (days[day] ?? 0) >= 20))
    }

    /// Days in a row with the fire lit, ending today, or yesterday if today isn't lit yet.
    var streak: Int {
        let cal = Calendar(identifier: .gregorian)
        var d = Date(timeIntervalSince1970: now() / 1000)
        let key = { (d: Date) in Self.dayKey(d.timeIntervalSince1970 * 1000) }
        if !litOn(key(d)) { d = cal.date(byAdding: .day, value: -1, to: d)! }
        var n = 0
        while litOn(key(d)) { n += 1; d = cal.date(byAdding: .day, value: -1, to: d)! }
        return n
    }

    /// Light today's fire. Returns true if it wasn't lit yet.
    @discardableResult
    func lightFire() -> Bool {
        let t = today
        guard !lit.contains(t) else { return false }
        lit.insert(t); save()
        return true
    }

    var boostActive: Bool { boostUntil > now() }
    func startBoost() { boostUntil = now() + 15 * 60_000; save() }

    /// Earn XP as the web's earnXP: doubled during a boost, and the first time today's
    /// total crosses the daily goal a +15 bonus is paid. Returns what was actually earned,
    /// and whether the goal was just reached.
    @discardableResult
    func earnXP(_ n: Int) -> (earned: Int, goalReached: Bool) {
        let mult = boostActive ? 2 : 1
        let t = today
        let before = xpDays[t, default: 0]
        xpDays[t, default: 0] += n * mult
        var total = n * mult, reached = false
        if before < dailyGoal && xpDays[t, default: 0] >= dailyGoal && celebrated != t {
            celebrated = t
            xpDays[t, default: 0] += 15 * mult
            total += 15 * mult; reached = true
        }
        save()
        return (total, reached)
    }

    func recordReview() { days[today, default: 0] += 1; save() }

    /// Grade an answer in a study session, as the web's answerStudy does to the record.
    func answer(_ cardId: String, correct: Bool, dir: String, sessionStart: Double, mistakesMode: Bool) -> (mistake: Bool, fixed: Bool) {
        var s = FSRS.schedule(srs[cardId], grade: correct ? .good : .again, now: now())
        var mistake = false, fixed = false
        if correct {
            s.known = true
            if let m = s.miss, mistakesMode || m.s != sessionStart { s.miss = nil; fixed = true }
            if ["recall", "write", "speak"].contains(dir) { s.prod = true }
        } else {
            s.miss = SRSRecord.Miss(d: dir, at: now(), s: sessionStart)
            mistake = true
        }
        srs[cardId] = s
        save()
        return (mistake, fixed)
    }

    // MARK: daily goal, week and quests
    let dailyGoal = 20

    func xp(on day: String) -> Int { xpDays[day] ?? 0 }
    var today: String { Self.dayKey(now()) }

    /// Monday to Sunday of this week, as day keys.
    var thisWeek: [String] {
        var cal = Calendar(identifier: .gregorian); cal.firstWeekday = 2
        let now = Date(timeIntervalSince1970: self.now() / 1000)
        let monday = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        return (0..<7).map { Self.dayKey(cal.date(byAdding: .day, value: $0, to: monday)!.timeIntervalSince1970 * 1000) }
    }

    var qcToday: [String: Int] { qc[today] ?? [:] }

    /// Called after every answer and every finished session, as the web's questEvent.
    func questEvent(_ kind: String, correct: Bool = false, lesson: Bool = false, perfect: Bool = false) {
        var c = qcToday
        if kind == "session" {
            c["sessions", default: 0] += 1
            if lesson { c["lessons", default: 0] += 1 }
            if perfect { c["perfect", default: 0] += 1 }
        } else {
            c["combo"] = correct ? (c["combo"] ?? 0) + 1 : 0
            c["comboMax"] = max(c["comboMax"] ?? 0, c["combo"] ?? 0)
            if correct && ["listen", "write", "speak", "sentence"].contains(kind) { c[kind, default: 0] += 1 }
        }
        qc = [today: c]                                  // yesterday's counters are no longer needed
        save()
    }

    func reviewedToday() -> Int { days[today] ?? 0 }

    /// Today's three quests, picked from the same pools by the same date hash as the web.
    var todayQuests: [Quest] {
        let t = today
        let second = Quest.pick(Quest.sets[1], seed: t + "b")
        let skills = Quest.sets[2].filter { Quest.skillDir[$0].map(StudySession.allDirs.contains) ?? false }
        let third = skills.isEmpty ? Quest.pick(Quest.sets[1].filter { $0 != second }, seed: t + "c")
                                   : Quest.pick(skills, seed: t + "c")
        return [Quest.pick(Quest.sets[0], seed: t + "a"), second, third].compactMap { Quest.all[$0] }
    }

    func progress(of q: Quest) -> Int {
        let c = qcToday
        switch q.id {
        case "xp30", "xp50": return xpToday
        case "combo5", "combo10": return c["comboMax"] ?? 0
        case "review15", "review30": return reviewedToday()
        case "lesson1": return c["lessons"] ?? 0
        case "session2": return c["sessions"] ?? 0
        case "perfect1": return c["perfect"] ?? 0
        case "listen5": return c["listen"] ?? 0
        case "write3": return c["write"] ?? 0
        case "speak3": return c["speak"] ?? 0
        case "sentence2": return c["sentence"] ?? 0
        default: return 0
        }
    }

    /// Cards whose last answer was wrong and haven't been put right yet.
    var mistakeCount: Int { srs.values.filter { ($0.lapses ?? 0) > 0 && ($0.reps ?? 0) == 0 }.count }
    /// Words that keep slipping: lapsed twice or more.
    var weakCount: Int { srs.values.filter { ($0.lapses ?? 0) >= 2 }.count }
}

struct Quest: Identifiable {
    let id: String, title: String, icon: String, target: Int
    static let all: [String: Quest] = Dictionary(uniqueKeysWithValues: [
        Quest(id: "xp30", title: "Earn 30 XP", icon: "star.fill", target: 30),
        Quest(id: "xp50", title: "Earn 50 XP", icon: "star.fill", target: 50),
        Quest(id: "combo5", title: "Get 5 right in a row", icon: "scope", target: 5),
        Quest(id: "combo10", title: "Get 10 right in a row", icon: "scope", target: 10),
        Quest(id: "review15", title: "Review 15 words", icon: "rectangle.stack", target: 15),
        Quest(id: "review30", title: "Review 30 words", icon: "rectangle.stack", target: 30),
        Quest(id: "lesson1", title: "Finish a lesson", icon: "flag.fill", target: 1),
        Quest(id: "session2", title: "Finish 2 sessions", icon: "checkmark", target: 2),
        Quest(id: "perfect1", title: "Finish a session with no mistakes", icon: "crown.fill", target: 1),
        Quest(id: "listen5", title: "Get 5 listening exercises right", icon: "headphones", target: 5),
        Quest(id: "write3", title: "Write 3 characters", icon: "pencil", target: 3),
        Quest(id: "speak3", title: "Say 3 words aloud", icon: "mic", target: 3),
        Quest(id: "sentence2", title: "Build 2 sentences", icon: "bubble.left.and.bubble.right", target: 2),
    ].map { ($0.id, $0) })
    /// the exercise a skill quest needs
    static let skillDir = ["listen5": "listen", "write3": "write", "speak3": "speak", "sentence2": "sentence"]
    static let sets = [["xp30", "xp50"], ["combo5", "combo10", "review15", "review30", "lesson1", "session2", "perfect1"],
                       ["listen5", "write3", "speak3", "sentence2"]]
    /// FNV-1a over the seed, as the web's seededPick
    static func pick(_ list: [String], seed: String) -> String {
        var h: UInt32 = 2166136261
        for u in seed.utf16 { h ^= UInt32(u); h = h &* 16777619 }
        return list[Int(h % UInt32(list.count))]
    }
}
