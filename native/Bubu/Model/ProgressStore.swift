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
    var name: String = ""

    private let course: Course
    private let url: URL
    var now: () -> Double = { Date().timeIntervalSince1970 * 1000 }

    private struct Saved: Codable {
        var srs: [String: SRSRecord]
        var done: [String]
        var xpDays: [String: Int]?
        var name: String?
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
        srs = s.srs; done = Set(s.done); xpDays = s.xpDays ?? [:]; name = s.name ?? ""
    }

    func save() {
        let s = Saved(srs: srs, done: done.sorted(), xpDays: xpDays, name: name)
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
}
