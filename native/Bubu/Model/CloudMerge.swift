import Foundation

/// The website's cloud merge (app.js `mergeProgress`), ported rule for rule, so
/// the same account merges the same way whichever device syncs.
///
/// Both sides are payloads in the web's shape: `{ "<localStorage key>": "<json text>" }`
/// (a value may also be the parsed object itself, as the web's `P()` allows).
/// The result always has all four keys, each as JSON text, exactly as the web
/// writes it back to the `progress` row:
///   lessons  -> union            (finished on either device counts)
///   activity -> max per day      (never double-counts, never loses a day)
///   srs      -> more-reviewed entry wins
///   prefs    -> this device wins, remote fills any gaps
enum CloudMerge {
    static let srsKey = Backup.srsKey, prefsKey = Backup.prefsKey
    static let doneKey = Backup.doneKey, activityKey = Backup.activityKey
    static let keys = [srsKey, prefsKey, doneKey, activityKey]

    static func merge(local: [String: Any], remote: [String: Any]) -> [String: String] {
        var out: [String: String] = [:]

        // srs: the entry reviewed more recently wins; without dates, more reps, then the later due
        let sa = dict(P(local[srsKey]) ?? [:]), sbb = dict(P(remote[srsKey]) ?? [:])
        var srsM = sbb
        for (id, e) in sa {
            let ed = dict(e)
            let better: Bool
            if let o = srsM[id] {
                let od = dict(o)
                if truthy(ed["last"]) || truthy(od["last"]) {
                    better = num(ed["last"]) > num(od["last"])
                } else {
                    let er = num(ed["reps"]), or = num(od["reps"])
                    better = er > or || (er == or && num(ed["due"]) > num(od["due"]))
                }
            } else { better = true }
            if better { srsM[id] = e }
        }
        out[srsKey] = text(srsM)

        // lessons: union, local first, in order
        let da = P(local[doneKey]) as? [Any] ?? [], db = P(remote[doneKey]) as? [Any] ?? []
        var seen = Set<AnyHashable>(), done: [Any] = []
        for v in da + db {
            if let h = v as? AnyHashable { if seen.insert(h).inserted { done.append(v) } } else { done.append(v) }
        }
        out[doneKey] = text(done)

        // activity
        let aa = P(local[activityKey]) as? [String: Any] ?? ["days": [String: Any]()]
        let ab = P(remote[activityKey]) as? [String: Any] ?? ["days": [String: Any]()]
        let days = perDay(aa["days"], ab["days"])
        let xpDays = perDay(aa["xpDays"], ab["xpDays"])
        let relit = assign(ab["relit"], aa["relit"])
        let embers = max(isNumber(aa["embers"]) ? num(aa["embers"]) : 1, isNumber(ab["embers"]) ? num(ab["embers"]) : 1)
        let emberFor = assign(ab["emberFor"], aa["emberFor"])
        let best = max(num(aa["best"]), num(ab["best"]))
        let questMonths = perDay(aa["questMonths"], ab["questMonths"])
        let chests = max(num(aa["chests"]), num(ab["chests"]))
        let boostUntil = max(num(aa["boostUntil"]), num(ab["boostUntil"]))
        let levelSeen = max(num(aa["levelSeen"]), num(ab["levelSeen"]))
        let lit = assign(ab["lit"], aa["lit"])
        let coinsIn = perDay(aa["coinsIn"], ab["coinsIn"]), coinsOut = perDay(aa["coinsOut"], ab["coinsOut"])
        // buns: whichever device changed them last
        let bt = { (b: Any?) -> Double in num((b as? [String: Any])?["t"]) }
        let buns: Any? = bt(aa["buns"]) >= bt(ab["buns"]) ? aa["buns"] : ab["buns"]
        let pocketDay = max(aa["pocketDay"] as? String ?? "", ab["pocketDay"] as? String ?? "")
        let plus = truthy(aa["plus"]) || truthy(ab["plus"])
        let quests = pickQuests(aa["quests"], ab["quests"])

        var act = ab
        for (k, v) in aa { act[k] = v }
        act["days"] = days; act["xpDays"] = xpDays; act["relit"] = relit; act["embers"] = jsNum(embers)
        act["emberFor"] = emberFor; act["best"] = jsNum(best); act["questMonths"] = questMonths
        act["chests"] = jsNum(chests); act["quests"] = quests; act["boostUntil"] = jsNum(boostUntil)
        act["levelSeen"] = jsNum(levelSeen); act["lit"] = lit; act["coinsIn"] = coinsIn; act["coinsOut"] = coinsOut
        act["buns"] = buns; act["pocketDay"] = pocketDay; act["plus"] = plus
        // JSON.stringify drops keys whose value is undefined (no buns / no quests on either side)
        out[activityKey] = text(act)

        // prefs: this device wins, remote fills the gaps
        out[prefsKey] = text(assign(P(remote[prefsKey]), P(local[prefsKey])))
        return out
    }

    /// Today's quests: on the same day, whichever side has claimed more; otherwise the later day.
    /// Nil when the result is JavaScript's `undefined` (the key is then left out).
    static func pickQuests(_ qa: Any?, _ qb: Any?) -> Any? {
        func nd(_ q: Any?) -> Int { ((q as? [String: Any])?["done"] as? [String: Any]).map(\.count) ?? -1 }
        func date(_ q: Any?) -> String? { (q as? [String: Any])?["date"] as? String }
        if truthy(qa) && truthy(qb) && date(qa) == date(qb) { return nd(qa) >= nd(qb) ? qa : qb }
        // (qa && qa.date) >= (qb && qb.date || "")
        let rhs = (truthy(qb) ? date(qb) : nil) ?? ""
        let takeA: Bool
        if qa is NSNull { takeA = rhs.isEmpty }                   // null >= "" is true in JavaScript
        else if let l = date(qa) { takeA = l >= rhs }
        else { takeA = false }                                    // undefined >= anything is false
        return takeA ? qa : qb
    }

    // MARK: JavaScript's rules, in Swift

    /// The web's `P(v, f)`: JSON text is parsed, anything else is taken as it is. Nil means "use the fallback".
    static func P(_ v: Any?) -> Any? {
        if let s = v as? String {
            guard let o = try? JSONSerialization.jsonObject(with: Data(s.utf8), options: [.fragmentsAllowed]) else { return nil }
            return o is NSNull ? nil : o
        }
        return truthy(v) ? v : nil
    }

    static func dict(_ v: Any?) -> [String: Any] { v as? [String: Any] ?? [:] }

    /// `Object.assign({}, a, b)` on two maybe-objects.
    static func assign(_ a: Any?, _ b: Any?) -> [String: Any] {
        var o = dict(a)
        for (k, v) in dict(b) { o[k] = v }
        return o
    }

    /// `o[d] = Math.max(n || 0, o[d] || 0)` over x, starting from y.
    static func perDay(_ x: Any?, _ y: Any?) -> [String: Any] {
        var o = dict(y)
        for (d, n) in dict(x) { o[d] = jsNum(max(num(n), num(o[d]))) }
        return o
    }

    static func isNumber(_ v: Any?) -> Bool {
        guard let n = v as? NSNumber else { return false }
        return CFGetTypeID(n) != CFBooleanGetTypeID()
    }

    /// `v || 0` as a number (numeric strings count, as they would in Math.max).
    static func num(_ v: Any?) -> Double {
        if let n = v as? NSNumber {
            let d = n.doubleValue
            return d.isNaN ? 0 : d
        }
        if let s = v as? String { return Double(s) ?? 0 }
        return 0
    }

    static func truthy(_ v: Any?) -> Bool {
        switch v {
        case nil, is NSNull: return false
        case let n as NSNumber:
            if CFGetTypeID(n) == CFBooleanGetTypeID() { return n.boolValue }
            let d = n.doubleValue
            return d != 0 && !d.isNaN
        case let s as String: return !s.isEmpty
        default: return true
        }
    }

    /// Whole numbers written as whole numbers, as JavaScript does.
    static func jsNum(_ d: Double) -> Any {
        if d == d.rounded(), abs(d) < 9e15 { return Int(d) }
        return d
    }

    static func text(_ o: Any) -> String {
        guard let d = try? JSONSerialization.data(withJSONObject: o, options: [.fragmentsAllowed]) else { return "{}" }
        return String(data: d, encoding: .utf8) ?? "{}"
    }
}
