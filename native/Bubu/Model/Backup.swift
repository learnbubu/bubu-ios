import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Your settings, with the web app's names and defaults (its prefs.v1).
struct Prefs: Codable, Equatable {
    var theme = "system"        // system, light, dark
    var rate = 0.85             // speech speed, 0.4 to 1
    var voiceURI: String?       // chosen voice identifier
    var dailyGoal = 20          // 10, 20, 30, 50
    var sound = true
    var showPinyin = true
    var toneColours = true
    var checkStrokes = true
    var autoRelight = true      // an ember relights a missed day by itself
    var lessons: [String]?      // "What to study": the lessons chosen (nil or empty = all)
    var focuses: [String]?      // and the skills switched on (nil or empty = all)
    var avatar: AvatarConfig?   // your avatar's look
    // reminder notifications (see Reminders.swift); nil means never chosen
    var reminders: Bool?        // the daily reminder is on
    var reminderMinutes: Int?   // its time, minutes after midnight (nil = 19:00)
    var streakNudge: Bool?      // the late "streak at risk" nudge (nil = on)
    var remindersAsked: Bool?   // the "Want a daily reminder?" card has been answered

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        theme = (try? c.decode(String.self, forKey: .theme)) ?? "system"
        rate = (try? c.decode(Double.self, forKey: .rate)) ?? 0.85
        voiceURI = try? c.decode(String.self, forKey: .voiceURI)
        dailyGoal = (try? c.decode(Int.self, forKey: .dailyGoal)) ?? 20
        sound = (try? c.decode(Bool.self, forKey: .sound)) ?? true
        showPinyin = (try? c.decode(Bool.self, forKey: .showPinyin)) ?? true
        toneColours = (try? c.decode(Bool.self, forKey: .toneColours)) ?? true
        checkStrokes = (try? c.decode(Bool.self, forKey: .checkStrokes)) ?? true
        autoRelight = (try? c.decode(Bool.self, forKey: .autoRelight)) ?? true
        lessons = try? c.decode([String].self, forKey: .lessons)
        focuses = try? c.decode([String].self, forKey: .focuses)
        avatar = try? c.decode(AvatarConfig.self, forKey: .avatar)
        reminders = try? c.decode(Bool.self, forKey: .reminders)
        reminderMinutes = try? c.decode(Int.self, forKey: .reminderMinutes)
        streakNudge = try? c.decode(Bool.self, forKey: .streakNudge)
        remindersAsked = try? c.decode(Bool.self, forKey: .remindersAsked)
    }

    var colorScheme: ColorScheme? { theme == "light" ? .light : theme == "dark" ? .dark : nil }
}

/// Backups in the web app's own file format, so a backup from the website
/// restores here and a backup from here restores on the website:
/// { app: "zhBeginnerA", version: 1, exported, data: { "<localStorage key>": "<json text>" } }
enum Backup {
    static let srsKey = "zhBeginnerA.srs.v1", prefsKey = "zhBeginnerA.prefs.v1"
    static let doneKey = "zhBeginnerA.done.v1", activityKey = "zhBeginnerA.activity.v1"

    struct Summary { let date: String; let lessons: Int; let words: Int }

    private static func text<T: Encodable>(_ v: T) -> String {
        (try? String(data: JSONEncoder().encode(v), encoding: .utf8) ?? "{}") ?? "{}"
    }

    /// A backup file of everything, in the web's format.
    static func export(_ p: ProgressStore) -> Data {
        var prefs = p.prefsJSON()
        prefs["name"] = p.name
        if !p.hooks.isEmpty { prefs["hooks"] = p.hooks }
        let data: [String: String] = [
            srsKey: text(p.srs),
            doneKey: text(p.done.sorted()),
            prefsKey: json(prefs),
            activityKey: text(p.activity),
        ]
        let payload: [String: Any] = [
            "app": "zhBeginnerA", "version": 1,
            "exported": ISO8601DateFormatter().string(from: Date()), "data": data,
        ]
        return (try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])) ?? Data()
    }

    private static func json(_ o: Any) -> String {
        guard let d = try? JSONSerialization.data(withJSONObject: o) else { return "{}" }
        return String(data: d, encoding: .utf8) ?? "{}"
    }

    /// The old edition's card ids and their words.
    static let oldCards: [String: String] = {
        guard let url = Bundle.main.url(forResource: "oldcards", withExtension: "json"),
              let d = try? Data(contentsOf: url), let o = try? JSONDecoder().decode([String: String].self, from: d) else { return [:] }
        return o
    }()

    /// Records under the old edition's ids move to the course's word of the same
    /// characters, keeping whichever is newer. True if anything moved.
    static func migrate(_ srs: inout [String: SRSRecord]) -> Bool {
        let course = Course.shared
        var byHanzi: [String: String] = [:]
        for c in course.cards where byHanzi[c.word.hanzi] == nil { byHanzi[c.word.hanzi] = c.id }
        let old = srs.keys.filter { course.cardById[$0] == nil && oldCards[$0] != nil }
        for k in old {
            let rec = srs[k]!
            if let h = oldCards[k], let to = byHanzi[h], (srs[to].map { (rec.last ?? 0) > ($0.last ?? 0) } ?? true) { srs[to] = rec }
            srs[k] = nil
        }
        return !old.isEmpty
    }

    /// Lessons before they were cut into stones of at most five new words (web v294): each old
    /// lesson id and the stones that now hold its words.
    static let oldLessons: [String: [String]] = bundled("oldlessons")
    /// Web v294's stones retired when chapter 1 was shaped by hand (v295), and the stones now
    /// holding their words.
    static let oldStones: [String: [String]] = bundled("oldstones")

    private static func bundled(_ name: String) -> [String: [String]] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let d = try? Data(contentsOf: url), let o = try? JSONDecoder().decode([String: [String]].self, from: d) else { return [:] }
        return o
    }

    /// Done lesson ids the course no longer has (web: migrateOldDone). An old lesson cut into
    /// stones finishes each stone whose words all came from lessons that were done, so a word
    /// brought forward from a lesson not reached yet keeps its stone open; v294's retired stones
    /// do the same, checked on their own. Any other stone counts as done once every one of its
    /// words has been answered (the old edition's ids), and a practice stone once every stone
    /// before it in its chapter is done.
    /// Returns the stones marked done from old lessons, and those from word history.
    @discardableResult
    static func migrateDone(_ done: inout Set<String>, srs: [String: SRSRecord], course: Course = .shared,
                            oldLessons: [String: [String]] = Backup.oldLessons,
                            oldStones: [String: [String]] = Backup.oldStones) -> (restoned: Int, carried: Int) {
        let stale = done.filter { course.lessonById[$0] == nil }
        guard !stale.isEmpty else { return (0, 0) }
        done.subtract(stale)
        var restoned = 0, carried = 0
        for map in [oldLessons, oldStones] {
            let was = stale.filter { map[$0] != nil }
            guard !was.isEmpty else { continue }
            var from: [String: [String]] = [:]
            for (old, stones) in map { for id in stones { from[id, default: []].append(old) } }
            for l in course.lessons where !done.contains(l.id) {
                if let olds = from[l.id], !olds.isEmpty, olds.allSatisfy({ was.contains($0) }) { done.insert(l.id); restoned += 1 }
            }
        }
        for l in course.lessons where !done.contains(l.id) {
            let cs = course.cards(in: l.id)
            if !cs.isEmpty && cs.allSatisfy({ (srs[$0.id]?.reps ?? 0) > 0 }) { done.insert(l.id); carried += 1 }
        }
        for ch in course.chapters {
            for (i, id) in ch.lessons.enumerated() where i > 0 && !done.contains(id) && course.lessonById[id]?.isPractice == true {
                if ch.lessons[..<i].allSatisfy({ done.contains($0) }) { done.insert(id); carried += 1 }
            }
        }
        return (restoned, carried)
    }

    static func restonedNote(_ n: Int) -> String {
        "Lessons are now shorter: up to five new words a stone. \(n) stone\(n == 1 ? " is" : "s are") done from your progress, and your words keep their reviews."
    }

    /// What a backup holds, before restoring it; nil if it isn't one.
    static func summary(_ file: Data) -> Summary? {
        guard let p = try? JSONSerialization.jsonObject(with: file) as? [String: Any],
              p["app"] as? String == "zhBeginnerA", let data = p["data"] as? [String: String] else { return nil }
        let words = (data[srsKey].flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any] })?.count ?? 0
        let lessons = (data[doneKey].flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) as? [Any] })?.count ?? 0
        return Summary(date: String((p["exported"] as? String ?? "unknown date").prefix(10)), lessons: lessons, words: words)
    }

    /// Replace everything with the backup. Returns false if it isn't one.
    static func restore(_ file: Data, into p: ProgressStore) -> Bool {
        guard let payload = try? JSONSerialization.jsonObject(with: file) as? [String: Any],
              payload["app"] as? String == "zhBeginnerA", let data = payload["data"] as? [String: String] else { return false }
        let obj = { (k: String) -> Any? in data[k].flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) } }
        // word records decode one by one, so a single odd record can't sink the rest
        var srs: [String: SRSRecord] = [:]
        if let s = obj(srsKey) as? [String: Any] {
            for (id, v) in s {
                if let d = try? JSONSerialization.data(withJSONObject: v), let r = try? JSONDecoder().decode(SRSRecord.self, from: d) { srs[id] = r }
            }
        }
        var done = Set((obj(doneKey) as? [Any] ?? []).compactMap { $0 as? String })
        let prefsObj = obj(prefsKey) as? [String: Any] ?? [:]
        var prefs = (try? JSONSerialization.data(withJSONObject: prefsObj)).flatMap { try? JSONDecoder().decode(Prefs.self, from: $0) } ?? Prefs()
        let activity = data[activityKey].flatMap { try? JSONDecoder().decode(Activity.self, from: Data($0.utf8)) } ?? Activity()

        // the old edition's words carry over by what they are (web: migrateOldSRS, migrateOldDone)
        let course = Course.shared
        let moved = migrate(&srs)
        let lessonIds = Set(course.lessons.map(\.id))
        let stale = done.subtracting(lessonIds)
        let (restoned, fromWords) = migrateDone(&done, srs: srs, course: course)
        let carried = restoned + fromWords
        if let chosen = prefs.lessons, chosen.contains(where: { !lessonIds.contains($0) }) { prefs.lessons = nil }

        p.replaceAll(srs: srs, done: done, activity: activity, name: (prefsObj["name"] as? String) ?? "",
                     hooks: prefsObj["hooks"] as? [String: String] ?? [:], prefs: prefs)
        // a record from before levels were tracked: no level-up for XP already earned
        if let a = data[activityKey], !a.contains("\"levelSeen\"") { p.settleLevel() }
        p.markBackedUp()
        if restoned > 0 {
            Moments.shared.toast(restonedNote(carried))
        } else if moved || !stale.isEmpty {
            Moments.shared.toast(carried > 0
                ? "Welcome to the new course! \(carried) stone\(carried == 1 ? " is" : "s are") already done from your old progress, and your words keep their reviews."
                : "Welcome to the new course! Your words keep their reviews.")
        }
        return true
    }
}

/// The backup as a file to share or save, built only when it's shared.
struct BackupFile: Transferable {
    let progress: ProgressStore
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { f in await MainActor.run { Backup.export(f.progress) } }
            .suggestedFileName { _ in "chinese-progress-\(ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withFullDate])).json" }
    }
}
