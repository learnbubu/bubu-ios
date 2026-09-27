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
        let done = Set((obj(doneKey) as? [Any] ?? []).compactMap { $0 as? String })
        let prefsObj = obj(prefsKey) as? [String: Any] ?? [:]
        let prefs = (try? JSONSerialization.data(withJSONObject: prefsObj)).flatMap { try? JSONDecoder().decode(Prefs.self, from: $0) } ?? Prefs()
        let activity = data[activityKey].flatMap { try? JSONDecoder().decode(Activity.self, from: Data($0.utf8)) } ?? Activity()
        p.replaceAll(srs: srs, done: done, activity: activity, name: (prefsObj["name"] as? String) ?? "",
                     hooks: prefsObj["hooks"] as? [String: String] ?? [:], prefs: prefs)
        p.markBackedUp()
        return true
    }
}

/// The backup as a file to share or save.
struct BackupFile: Transferable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { $0.data }
            .suggestedFileName { _ in "chinese-progress-\(ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withFullDate])).json" }
    }
}
