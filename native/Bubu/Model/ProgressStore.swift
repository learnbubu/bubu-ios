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
    }

    func save() {
        let s = Saved(srs: srs, done: done.sorted(), xpDays: xpDays, name: name, qc: qc)
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

    var wordsLearned: Int { srs.values.filter { ($0.reps ?? 0) > 0 }.count }

    // MARK: streak and XP
    static func dayKey(_ ms: Double) -> String {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date(timeIntervalSince1970: ms / 1000))
    }

    func earn(_ xp: Int) {
        xpDays[Self.dayKey(now()), default: 0] += xp
        save()
    }

    var xpToday: Int { xpDays[Self.dayKey(now())] ?? 0 }

    /// Days in a row with any XP, counting today if you've practised, else from yesterday.
    var streak: Int {
        var n = 0, t = now()
        if (xpDays[Self.dayKey(t)] ?? 0) == 0 { t -= FSRS.day }
        while (xpDays[Self.dayKey(t)] ?? 0) > 0 { n += 1; t -= FSRS.day }
        return n
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

    func reviewedToday() -> Int {
        let t = today
        return srs.values.filter { $0.last.map { Self.dayKey($0) == t } ?? false }.count
    }

    /// Today's three quests, picked from the same pools by the same date hash as the web.
    var todayQuests: [Quest] {
        let t = today
        return [Quest.pick(Quest.sets[0], seed: t + "a"), Quest.pick(Quest.sets[1], seed: t + "b"),
                Quest.pick(Quest.sets[2], seed: t + "c")].compactMap { Quest.all[$0] }
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
    static let sets = [["xp30", "xp50"], ["combo5", "combo10", "review15", "review30", "lesson1", "session2", "perfect1"],
                       ["listen5", "write3", "speak3", "sentence2"]]
    /// FNV-1a over the seed, as the web's seededPick
    static func pick(_ list: [String], seed: String) -> String {
        var h: UInt32 = 2166136261
        for u in seed.utf16 { h ^= UInt32(u); h = h &* 16777619 }
        return list[Int(h % UInt32(list.count))]
    }
}
