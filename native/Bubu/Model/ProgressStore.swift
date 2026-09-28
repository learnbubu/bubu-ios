import Foundation
import Observation
import AVFoundation

/// Everything the web app keeps in its activity record, with the same names and
/// shapes (dates as "yyyy-MM-dd", sets as {date: true}), so a backup moves
/// between the website and the app untouched.
struct Activity: Codable, Equatable {
    var days: [String: Int] = [:]            // answers per day
    var xpDays: [String: Int] = [:]          // XP per day
    var lit: [String: Bool] = [:]            // days a session was finished: the fire
    var relit: [String: Bool] = [:]          // missed days covered by an ember
    var celebrated: String?                  // the day the goal bonus was paid
    var boostUntil: Double = 0               // double XP until (ms)
    var qc: [String: [String: Int]] = [:]    // today's quest counters
    var embers: Int?                         // nil means the one you start with
    var emberFor: [String: String] = [:]     // streak milestone → the day its ember was given
    var coinsFor: [String: String] = [:]     // streak milestone → the day its coins were given
    var best: Int = 0                        // longest streak
    var levelSeen: Int = 1
    var chests: Int = 0
    var questMonths: [String: Int] = [:]     // "2026-09" → quests done that month
    var quests: QuestDay?
    var achv: [String: String] = [:]         // achievement → the day it was earned
    var readsDone: [String: String] = [:]    // story → the day it was first read
    var relightAsked: String?
    var coinsIn: [String: Int] = [:]         // coins from red pockets, per day
    var coinsOut: [String: Int] = [:]        // coins spent in the shop, per day
    var buns: Buns?                          // nil means a full five
    var pocketDay: String?                   // the day the daily red pocket was given
    var plus = false                         // Bùbù Plus

    /// n buns as of `at` (ms), one growing back every four hours; `t` is when
    /// they were last changed, so the newer record wins a merge.
    struct Buns: Codable, Equatable { var n: Int; var at: Double; var t: Double }

    struct QuestDay: Codable, Equatable {
        var date: String
        var ids: [String]
        var done: [String: Bool] = [:]
        var chest = false
    }

    init() {}
    // lenient: a field the web wrote differently is dropped, not the whole record
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func get<T: Decodable>(_ k: CodingKeys, _ d: T) -> T { (try? c.decode(T.self, forKey: k)) ?? d }
        days = get(.days, [:]); xpDays = get(.xpDays, [:]); lit = get(.lit, [:]); relit = get(.relit, [:])
        celebrated = try? c.decode(String.self, forKey: .celebrated)
        boostUntil = get(.boostUntil, 0); qc = get(.qc, [:]); embers = try? c.decode(Int.self, forKey: .embers)
        emberFor = get(.emberFor, [:]); coinsFor = get(.coinsFor, [:]); best = get(.best, 0); levelSeen = get(.levelSeen, 1); chests = get(.chests, 0)
        questMonths = get(.questMonths, [:]); quests = try? c.decode(QuestDay.self, forKey: .quests)
        achv = get(.achv, [:]); readsDone = get(.readsDone, [:])
        relightAsked = try? c.decode(String.self, forKey: .relightAsked)
        coinsIn = get(.coinsIn, [:]); coinsOut = get(.coinsOut, [:]); buns = try? c.decode(Buns.self, forKey: .buns)
        pocketDay = try? c.decode(String.self, forKey: .pocketDay); plus = get(.plus, false)
    }
}

/// Everything a learner has done, saved as JSON in Application Support.
@Observable
final class ProgressStore {
    private(set) var srs: [String: SRSRecord] = [:]
    private(set) var done: Set<String> = []
    private(set) var activity = Activity()
    private(set) var hooks: [String: String] = [:]    // your own memory hooks, by character
    var prefs = Prefs() { didSet { if prefs != oldValue { saveSoon() } } }
    var name: String = "" { didSet { if name != oldValue { saveSoon() } } }
    private(set) var onboarded = false
    private(set) var lastBackup: Double = 0           // when a backup was last made (ms)
    private(set) var backupSnooze: Double = 0         // the reminder is quiet until (ms)

    /// The store in use, for small views that read a setting (tone colours, pinyin).
    @ObservationIgnored static weak var current: ProgressStore?

    private let course: Course
    private let url: URL
    var now: () -> Double = { Date().timeIntervalSince1970 * 1000 }

    private struct Saved: Codable {
        var srs: [String: SRSRecord]
        var done: [String]
        var name: String?
        var hooks: [String: String]?
        var prefs: Prefs?
        var activity: Activity?
        var onboarded: Bool?
        var lastBackup: Double?
        var backupSnooze: Double?
        // the first native builds kept these at the top level
        var xpDays: [String: Int]?, qc: [String: [String: Int]]?, lit: [String]?, days: [String: Int]?
        var celebrated: String?, boostUntil: Double?
    }

    init(course: Course, url: URL? = nil) {
        self.course = course
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.url = url ?? dir.appendingPathComponent("progress.json")
        load()
        if url == nil { Self.current = self }
    }

    // MARK: saving
    private func load() {
        guard let data = try? Data(contentsOf: url),
              let s = try? JSONDecoder().decode(Saved.self, from: data) else { return }
        // loading must never write: a save half-way through would store what isn't loaded yet
        held += 1
        defer { held -= 1; pending = false }
        srs = s.srs; done = Set(s.done); name = s.name ?? ""; hooks = s.hooks ?? [:]
        // someone with progress from an earlier build has already started
        onboarded = s.onboarded ?? (!s.srs.isEmpty || !s.done.isEmpty)
        lastBackup = s.lastBackup ?? 0; backupSnooze = s.backupSnooze ?? 0
        prefs = s.prefs ?? Prefs()
        if let a = s.activity { activity = a } else {
            var a = Activity()
            a.xpDays = s.xpDays ?? [:]; a.qc = s.qc ?? [:]; a.days = s.days ?? [:]
            a.lit = Dictionary(uniqueKeysWithValues: (s.lit ?? []).map { ($0, true) })
            a.celebrated = s.celebrated; a.boostUntil = s.boostUntil ?? 0
            activity = a
        }
    }

    @ObservationIgnored private var held = 0
    @ObservationIgnored private var pending = false
    /// Hold saves while several changes are made, then write once.
    func holdSaves() { held += 1 }
    func releaseSaves() {
        held = max(0, held - 1)
        if held == 0 && pending { pending = false; save() }
    }

    /// For settings and typing: one write once the changes stop.
    @ObservationIgnored private var soon: DispatchWorkItem?
    func saveSoon() {
        if held > 0 { pending = true; return }
        soon?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.save() }
        soon = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: w)
    }

    func save() {
        soon?.cancel(); soon = nil
        if held > 0 { pending = true; return }
        let s = Saved(srs: srs, done: done.sorted(), name: name, hooks: hooks, prefs: prefs, activity: activity,
                      onboarded: onboarded, lastBackup: lastBackup, backupSnooze: backupSnooze)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(s) { try? data.write(to: url, options: .atomic) }
        didSave?()
    }

    /// Called after every save; cloud sync uses it to queue a push (see Cloud.swift).
    @ObservationIgnored var didSave: (() -> Void)?

    /// Everything replaced at once, from a backup.
    func replaceAll(srs: [String: SRSRecord], done: Set<String>, activity: Activity, name: String,
                    hooks: [String: String], prefs: Prefs) {
        holdSaves()
        self.srs = srs; self.done = done; self.activity = activity; self.name = name
        self.hooks = hooks; self.prefs = prefs
        pending = true
        releaseSaves()
    }

    func markOnboarded() { onboarded = true; save() }
    /// Count the levels already reached as seen.
    func settleLevel() { activity.levelSeen = max(activity.levelSeen, level.level); save() }

    // MARK: the backup reminder (web: backupOverdue)
    static let staleDays = 14.0, snoozeDays = 7.0
    func markBackedUp() { lastBackup = now(); backupSnooze = 0; save() }
    func snoozeBackup() { backupSnooze = now() + Self.snoozeDays * FSRS.day; save() }
    var backupAge: String {
        guard lastBackup > 0 else { return "never backed up" }
        let d = Int((now() - lastBackup) / FSRS.day)
        return d <= 0 ? "backed up today" : "backed up \(d) day\(d == 1 ? "" : "s") ago"
    }
    /// Only when there's something worth losing, and not while snoozed.
    var backupOverdue: Bool {
        guard !done.isEmpty || srs.count >= 8 || streak > 0 else { return false }
        guard now() >= backupSnooze else { return false }
        return lastBackup == 0 || (now() - lastBackup) / FSRS.day >= Self.staleDays
    }

    /// Start again from nothing, keeping your name and settings.
    func resetProgress() {
        replaceAll(srs: [:], done: [], activity: Activity(), name: name, hooks: hooks, prefs: prefs)
    }

    /// The settings as the web stores them.
    func prefsJSON() -> [String: Any] {
        guard let d = try? JSONEncoder().encode(prefs),
              let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return [:] }
        return o
    }

    // MARK: what to study

    /// The lessons chosen in "What to study"; all of them unless some were picked.
    var selectedLessons: Set<String> {
        if let l = prefs.lessons, !l.isEmpty { return Set(l) }
        return Set(course.lessons.map(\.id))
    }
    /// The skills switched on; all seven unless some were switched off.
    var selectedFocuses: Set<String> {
        if let f = prefs.focuses, !f.isEmpty { return Set(f) }
        return Set(StudySession.allDirs)
    }
    /// The words of the chosen lessons (web: activeCards).
    var activeCards: [Card] { let s = selectedLessons; return course.cards.filter { s.contains($0.lessonId) } }

    // MARK: shortcuts into the activity record
    var xpDays: [String: Int] { activity.xpDays }
    var days: [String: Int] { activity.days }
    var qc: [String: [String: Int]] { activity.qc }
    var celebrated: String? { activity.celebrated }
    var boostUntil: Double { activity.boostUntil }
    var lit: Set<String> { Set(activity.lit.filter(\.value).keys) }

    // MARK: lessons
    func isDone(_ lessonId: String) -> Bool { done.contains(lessonId) }

    /// The first lesson, in course order, that isn't done yet.
    var currentLessonId: String? { course.lessons.first { !done.contains($0.id) }?.id }

    func markDone(_ lessonId: String) { done.insert(lessonId); save() }

    func chapterProgress(_ ci: Int) -> (done: Int, total: Int) {
        let ids = course.chapters[ci].lessons
        return (ids.filter { done.contains($0) }.count, ids.count)
    }

    /// Every lesson of a chapter is done (web: chapterDone).
    func chapterDone(_ ci: Int) -> Bool { course.chapters[ci].lessons.allSatisfy(done.contains) }

    // MARK: reviews
    func review(_ cardId: String, _ grade: Grade) {
        srs[cardId] = FSRS.schedule(srs[cardId], grade: grade, now: now())
        save()
    }

    /// Words falling due, from lessons done or the one you're on (web: dueReviewCards).
    func dueReviewCards(excluding lessonId: String? = nil) -> [Card] {
        let t = now(), cur = currentLessonId
        return course.cards.filter { c in
            guard c.lessonId != lessonId, let r = srs[c.id], let due = r.due, due <= t else { return false }
            return done.contains(c.lessonId) || c.lessonId == cur
        }
    }
    var dueCount: Int { dueReviewCards().count }

    /// Words answered wrong and not yet put right, newest first (web: mistakeCards).
    func mistakeCards() -> [Card] {
        course.cards.filter { srs[$0.id]?.miss != nil }.sorted { (srs[$0.id]?.miss?.at ?? 0) > (srs[$1.id]?.miss?.at ?? 0) }
    }
    var mistakeCount: Int { srs.values.filter { $0.miss != nil }.count }

    /// Words that keep tripping you up, most-missed first (web: troubleCards).
    func troubleCards() -> [Card] {
        let cur = currentLessonId
        return course.cards.filter { c in
            guard let s = srs[c.id], (s.reps ?? 0) > 0 || (s.lapses ?? 0) > 0 else { return false }
            guard done.contains(c.lessonId) || c.lessonId == cur else { return false }
            return (s.lapses ?? 0) > 0 || (s.ease ?? 2.4) < 2.4
        }
        .sorted { a, b in
            let sa = srs[a.id]!, sb = srs[b.id]!
            if (sa.lapses ?? 0) != (sb.lapses ?? 0) { return (sa.lapses ?? 0) > (sb.lapses ?? 0) }
            return (sa.ease ?? 2.4) < (sb.ease ?? 2.4)
        }
    }
    var weakCount: Int { troubleCards().count }

    var wordsLearned: Int { srs.values.filter { ($0.reps ?? 0) > 0 }.count }

    /// Well learnt: spaced a week out and produced at least once (web: isMastered).
    func isMastered(_ cardId: String) -> Bool {
        guard let s = srs[cardId] else { return false }
        return (s.interval ?? 0) >= 7 && (s.prod ?? false)
    }

    // MARK: days
    private static let dayFormat: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    static func dayKey(_ ms: Double) -> String {
        // the phone's time zone now, not the one it had when the app started
        if dayFormat.timeZone != TimeZone.current { dayFormat.timeZone = .current }
        return dayFormat.string(from: Date(timeIntervalSince1970: ms / 1000))
    }
    var today: String { Self.dayKey(now()) }
    /// The day n days from today (web: dayKeyOffset).
    func day(_ offset: Int) -> String {
        let d = Calendar(identifier: .gregorian).date(byAdding: .day, value: offset, to: Date(timeIntervalSince1970: now() / 1000))!
        return Self.dayKey(d.timeIntervalSince1970 * 1000)
    }

    /// Monday to Sunday of this week, as day keys.
    var thisWeek: [String] {
        var cal = Calendar(identifier: .gregorian); cal.firstWeekday = 2
        let now = Date(timeIntervalSince1970: self.now() / 1000)
        let monday = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        return (0..<7).map { Self.dayKey(cal.date(byAdding: .day, value: $0, to: monday)!.timeIntervalSince1970 * 1000) }
    }

    // MARK: XP, goal, levels
    func xp(on day: String) -> Int { activity.xpDays[day] ?? 0 }
    var xpToday: Int { xp(on: today) }
    var xpTotal: Int { activity.xpDays.values.reduce(0, +) }

    /// Level L until 50·L·(L+1) XP in all (web: levelInfo).
    var level: (level: Int, into: Int, span: Int, next: Int) {
        let total = xpTotal
        var L = 1
        while total >= 50 * L * (L + 1) { L += 1 }
        let floor = 50 * (L - 1) * L, ceil = 50 * L * (L + 1)
        return (L, total - floor, ceil - floor, ceil - total)
    }

    var boostActive: Bool { activity.boostUntil > now() }
    func startBoost() { activity.boostUntil = now() + 15 * 60_000; save() }

    func earn(_ xp: Int) { earnXP(xp) }

    /// Earn XP: doubled during a boost; then quests and levels are checked. There's no
    /// daily XP target: a day is done by finishing a session (see lightFire).
    /// Every XP ever earned this run, bonuses included: a session reads the difference.
    @ObservationIgnored private(set) var xpCounter = 0

    @discardableResult
    func earnXP(_ n: Int) -> (earned: Int, goalReached: Bool) {
        guard n > 0 else { return (0, false) }
        holdSaves(); defer { releaseSaves() }
        let mult = boostActive ? 2 : 1, t = today
        activity.xpDays[t, default: 0] += n * mult
        let total = n * mult, reached = false
        xpCounter += total
        save()
        checkQuests()
        let lv = level.level
        if lv > max(activity.levelSeen, 1) {
            activity.levelSeen = lv; save()
            Moments.shared.show(.level(lv, next: level.next))
        }
        return (total, reached)
    }

    func recordReview() { activity.days[today, default: 0] += 1; save() }

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

    /// Words passed in a skip test are seeded as already known (web: finishPlacement).
    func seedKnown(_ cardId: String) {
        guard srs[cardId] == nil else { return }
        let t = now()
        srs[cardId] = SRSRecord(ease: 2.4, interval: 3, due: t + 3 * FSRS.day, reps: 2, S: 3, D: 5, last: t, lapses: 0)
        srs[cardId]?.known = true
        srs[cardId]?.prod = true
        save()
    }

    func setHook(_ ch: String, _ text: String?) { hooks[ch] = text; save() }

    func markRead(_ storyId: String) -> Bool {
        let first = activity.readsDone[storyId] == nil
        activity.readsDone[storyId] = today; save()
        return first
    }
    func readDone(_ storyId: String) -> Bool { activity.readsDone[storyId] != nil }

    // MARK: coins, buns and red pockets
    // Coins come in red pockets (福): one for the first lesson finished each day
    // (every lesson with Plus) and a fuller one at the end of a chapter. They buy
    // a fresh batch of buns, double XP and, with Plus, embers. The daily quests'
    // reward is the jade pocket (吉), full of XP.
    // Buns (包子) are a new lesson's lives: each mistake in one eats a bun, and
    // with none left a new lesson can't be started. One comes back every four
    // hours, one for each right answer in a review (up to five), or a batch from
    // the shop. Plus has no limit. Coins are kept as earned and spent per day,
    // so they merge across devices like XP does.

    static let bunsMax = 5, bunMs = 4 * 60 * 60 * 1000.0, coinsStart = 100
    static let pocketLesson = (lo: 20, hi: 35), pocketChapter = 100
    static let chestXP = 50

    /// Whether Bùbù Plus is offered at all. It can't be bought yet (no StoreKit), and
    /// Apple rejects "coming soon" placeholders, so release builds never show it.
    /// In debug builds `-plusShop` turns the rows back on. The Plus logic stays.
    static let plusForSale: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-plusShop")
        #else
        return false
        #endif
    }()
    /// A Plus row (buns sheet, shop) is shown: Plus is on sale and you aren't a member.
    var offersPlus: Bool { Self.plusForSale && !isPlus }

    var isPlus: Bool {
        #if DEBUG
        if Launch.plus { return true }
        #endif
        return activity.plus
    }
    /// There's no purchase yet: this is for the debug switch and the tests.
    func setPlus(_ on: Bool) { activity.plus = on; save() }

    var coins: Int {
        max(0, Self.coinsStart + activity.coinsIn.values.reduce(0, +) - activity.coinsOut.values.reduce(0, +))
    }
    func addCoins(_ n: Int) { activity.coinsIn[today, default: 0] += n; save() }
    @discardableResult
    func spendCoins(_ n: Int) -> Bool {
        guard coins >= n else { return false }
        activity.coinsOut[today, default: 0] += n
        save()
        return true
    }

    /// The buns there are now, and how long (ms) until the next grows back; 0 when full.
    var bunState: (n: Int, next: Double) {
        guard let b = activity.buns, b.n < Self.bunsMax else { return (Self.bunsMax, 0) }
        let t = now()
        let k = max(0, Int(((t - b.at) / Self.bunMs).rounded(.down)))
        let n = min(Self.bunsMax, b.n + k)
        return (n, n >= Self.bunsMax ? 0 : b.at + Double(k + 1) * Self.bunMs - t)
    }
    /// Int.max with Plus: no limit.
    var buns: Int { isPlus ? Int.max : bunState.n }
    func setBuns(_ n: Int) {
        let s = bunState, t = now()
        let n = max(0, min(Self.bunsMax, n))
        // the time already grown toward the next bun is kept
        let at = s.n >= Self.bunsMax || n >= Self.bunsMax ? t : t - (Self.bunMs - s.next)
        activity.buns = Activity.Buns(n: n, at: at, t: t)
        save()
    }
    func eatBun() { if !isPlus { setBuns(bunState.n - 1) } }
    @discardableResult
    func earnBun() -> Bool {
        guard !isPlus, bunState.n < Self.bunsMax else { return false }
        setBuns(bunState.n + 1)
        return true
    }
    /// "2h 5m", or "40m" under the hour (web: fmtWait).
    static func waitText(_ ms: Double) -> String {
        let m = Int((ms / 60000).rounded(.up)), h = m / 60
        return h > 0 ? "\(h)h \(m % 60)m" : "\(m)m"
    }

    /// What coins buy.
    enum ShopItem {
        case buns, ember, boost
        var price: Int { switch self { case .buns: return 350; case .ember: return 250; case .boost: return 200 } }
    }
    /// Whether an item can be had now, coins aside: an ember only below your cap.
    func canBuy(_ item: ShopItem) -> Bool {
        switch item {
        case .ember: return embers < emberCap
        case .buns: return !isPlus && bunState.n < Self.bunsMax
        case .boost: return !boostActive
        }
    }
    /// Pay for something and have it; false if there aren't the coins, or an ember
    /// is already at your cap (nothing is spent then).
    @discardableResult
    func buy(_ item: ShopItem) -> Bool {
        if item == .ember && !canBuy(.ember) { return false }
        guard spendCoins(item.price) else { return false }
        switch item {
        case .buns: setBuns(Self.bunsMax)
        case .ember: activity.embers = embers + 1; save()
        case .boost: startBoost()
        }
        return true
    }

    /// A red pocket for a finished lesson: the first each day (every one with Plus),
    /// and a fuller one when it finishes a chapter. The coins in it, 0 for none.
    func lessonPocket(chapterEnd: Bool) -> Int {
        if chapterEnd { return Self.pocketChapter }
        let t = today
        if !isPlus && activity.pocketDay == t { return 0 }
        activity.pocketDay = t
        save()
        let (lo, hi) = Self.pocketLesson
        return lo + 5 * Int.random(in: 0...((hi - lo) / 5))
    }

    #if DEBUG
    /// For the reward screenshots: a fresh store each launch, apart from the real one,
    /// with today's fire lit, a few coins and one bun left (none for the buns sheet).
    static func debugRewards(_ screen: String) -> ProgressStore {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("rewards-\(screen).json")
        try? FileManager.default.removeItem(at: url)
        let p = ProgressStore(course: Course.shared, url: url)
        current = p
        p.holdSaves()
        p.onboarded = true
        p.lightFire()
        p.addCoins(35)
        p.setBuns(screen == "buns" ? 0 : 1)
        p.releaseSaves()
        return p
    }
    #endif

    // MARK: the fire: streak, embers and relighting

    /// Before this day XP lit the fire; days from then count if they met the old goal.
    static let litCutoff = "2026-09-19"
    /// A day counts once a session was finished on it, or an ember covered it (web: litOn).
    func litOn(_ day: String) -> Bool {
        (activity.lit[day] ?? false) || (activity.relit[day] ?? false)
            || (day < Self.litCutoff && ((activity.xpDays[day] ?? 0) >= 10 || (activity.days[day] ?? 0) >= 20))
    }
    func relitOn(_ day: String) -> Bool { activity.relit[day] ?? false }

    /// Days in a row with the fire lit, ending today, or yesterday if today isn't lit yet.
    var streak: Int {
        var k = litOn(today) ? 0 : -1, n = 0
        while litOn(day(k)) { n += 1; k -= 1 }
        return n
    }
    var bestStreak: Int { max(activity.best, streak) }

    static let milestones = [3, 7, 14, 30, 50, 100, 200, 365]
    static let emberAt = [3, 7, 14, 30, 60, 100]
    /// Coins for reaching a milestone, once per streak.
    static let milestoneCoins = [3: 20, 7: 50, 14: 75, 30: 150, 50: 200, 100: 300, 200: 400, 365: 500]
    var embers: Int { activity.embers ?? 1 }
    /// One ember held at a time, three with Plus; any already held above that are kept.
    var emberCap: Int { isPlus ? 3 : 1 }

    struct Fire { let streak: Int; let ember: Bool; let milestone: Bool; var coins = 0 }

    /// Light today's fire (web: lightFire). Nil if it was already lit today.
    @discardableResult
    func lightFire() -> Fire? {
        let t = today
        guard !(activity.lit[t] ?? false) else { return nil }
        activity.lit[t] = true
        let s = streak
        let start = day(1 - s)                                  // the day this streak began
        var ember = false
        for m in Self.emberAt {
            let key = String(m)
            if s < m || (activity.emberFor[key].map { $0 >= start } ?? false) { continue }
            activity.emberFor[key] = t
            if embers < emberCap { activity.embers = embers + 1; ember = true }
        }
        // a milestone's coins, once per streak, kept the same way as its ember
        var coins = 0
        if let n = Self.milestoneCoins[s], !(activity.coinsFor[String(s)].map { $0 >= start } ?? false) {
            activity.coinsFor[String(s)] = t
            activity.coinsIn[t, default: 0] += n
            coins = n
        }
        if s > activity.best { activity.best = s }
        save()
        NotificationCenter.default.post(name: .bubuDayLit, object: self)   // today's reminders go
        return Fire(streak: s, ember: ember, milestone: Self.milestones.contains(s), coins: coins)
    }

    /// The day the fire went out, if it can still be relit: yesterday was missed
    /// and the day before was lit (web: outSince).
    var outSince: (date: String, lost: Int)? {
        let y = day(-1)
        guard !litOn(y) else { return nil }
        var k = -2, run = 0
        while litOn(day(k)) { run += 1; k -= 1 }
        return run > 0 ? (y, run) : nil
    }

    /// Spend an ember to cover the missed day.
    @discardableResult
    func relight() -> Bool {
        guard let out = outSince, embers >= 1 else { return false }
        activity.embers = embers - 1
        activity.relit[out.date] = true
        save()
        return true
    }

    /// When the app opens after a missed day (web: protectStreak): an ember relights
    /// the fire by itself unless that's switched off; with none left, the fire is out.
    func protectStreak() {
        guard let out = outSince, activity.relightAsked != out.date else { return }
        activity.relightAsked = out.date
        save()
        if embers >= 1 && prefs.autoRelight {
            if relight() { Moments.shared.show(.relit(streak: streak, left: embers)) }
        } else if embers >= 1 {
            Moments.shared.show(.askRelight(lost: out.lost, embers: embers))
        } else {
            Moments.shared.show(.fireOut(lost: out.lost))
        }
    }

    // MARK: quests

    var qcToday: [String: Int] { activity.qc[today] ?? [:] }

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
        activity.qc = [today: c]                          // yesterday's counters are no longer needed
        save()
        checkQuests()
    }

    func reviewedToday() -> Int { activity.days[today] ?? 0 }

    /// Today's three quests, picked from the same pools by the same date hash as the web.
    var todayQuests: [Quest] {
        let t = today
        if let q = activity.quests, q.date == t { return q.ids.compactMap { Quest.all[$0] } }
        let second = Quest.pick(Quest.sets[1], seed: t + "b")
        let on = selectedFocuses
        let skills = Quest.sets[2].filter { Quest.skillDir[$0].map(on.contains) ?? false }
        let third = skills.isEmpty ? Quest.pick(Quest.sets[1].filter { $0 != second }, seed: t + "c")
                                   : Quest.pick(skills, seed: t + "c")
        return [Quest.pick(Quest.sets[0], seed: t + "a"), second, third].compactMap { Quest.all[$0] }
    }

    /// Fix today's three quests the first time they're asked for, as the web does.
    func ensureQuests() {
        guard activity.quests?.date != today else { return }
        activity.quests = Activity.QuestDay(date: today, ids: todayQuests.map(\.id))
        save()
    }

    private var questDay: Activity.QuestDay {
        if let q = activity.quests, q.date == today { return q }
        return Activity.QuestDay(date: today, ids: todayQuests.map(\.id))
    }
    func questDone(_ q: Quest) -> Bool { questDay.done[q.id] ?? false }
    var chestOpened: Bool { questDay.chest }

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

    /// Mark quests done as they're reached; all three open the jade pocket (web: checkQuests).
    func checkQuests() {
        ensureQuests()
        var q = questDay
        let newly = todayQuests.filter { !(q.done[$0.id] ?? false) && progress(of: $0) >= $0.target }
        guard !newly.isEmpty else { return }
        for n in newly { q.done[n.id] = true }
        let month = String(today.prefix(7))
        activity.questMonths[month, default: 0] += newly.count
        let all = q.ids.allSatisfy { q.done[$0] ?? false }
        var ember = false
        if all && !q.chest {
            q.chest = true
            activity.chests += 1
            if activity.chests % 5 == 0 && embers < emberCap { activity.embers = embers + 1; ember = true }
        }
        activity.quests = q
        save()
        if all {
            earnXP(Self.chestXP)
            Moments.shared.show(.pocket(.init(kind: .jade, reward: Self.chestXP, title: "All 3 daily quests done!",
                                              sub: ember ? "A lucky pocket, full of XP, and an ember" : "A lucky pocket, full of XP")))
        } else {
            for n in newly { Moments.shared.toast("Quest done: \(n.title)") }
        }
    }

    /// For backups: the activity record as it is.
    func stampAchievement(_ id: String) {
        guard activity.achv[id] == nil else { return }
        activity.achv[id] = today; save()
    }
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
