import Foundation
import Observation
import UserNotifications

extension Notification.Name {
    /// Posted by the store when today's fire is lit: today's reminders are no longer wanted.
    static let bubuDayLit = Notification.Name("bubu.dayLit")
}

/// Which reminders to have waiting, decided without the notification centre so it
/// can be tested. Local notifications can't look at the streak when they fire, so a
/// week of one-off reminders is scheduled ahead, one per day, and the lot is redone
/// whenever the app opens, a setting changes or the day is lit.
enum ReminderPlan {
    static let prefix = "bubu.remind."
    static let defaultMinutes = 19 * 60             // 7:00 pm
    static let riskMinutes = 21 * 60 + 30           // 9:30 pm, the streak-at-risk nudge
    static let riskThreshold = 3                    // a streak worth warning about
    static let horizon = 7                          // days scheduled ahead

    enum Kind: String { case daily, risk }

    struct Settings: Equatable {
        var on: Bool
        var minutes: Int
        var streakRisk: Bool
    }

    struct Request: Equatable {
        let id: String
        let kind: Kind
        let day: String                             // yyyy-MM-dd, in the calendar's time zone
        let fire: Date
        let title: String
        let body: String
    }

    static func id(_ kind: Kind, _ day: String) -> String { prefix + kind.rawValue + "." + day }

    static func dayKey(_ d: Date, _ cal: Calendar) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// The reminders to have pending. `streak` is the store's streak now (ending today
    /// if it's lit, else yesterday). The first unlit day is the only one where that
    /// count is sure to be right, so only it names the streak and gets the late nudge;
    /// if you do practise that day the app is open and plans again anyway.
    static func requests(_ s: Settings, now: Date, calendar cal: Calendar, litToday: Bool, streak: Int) -> [Request] {
        guard s.on else { return [] }
        let start = cal.startOfDay(for: now)
        let firstOpen = litToday ? 1 : 0
        var out: [Request] = []
        for i in 0..<horizon {
            if i == 0 && litToday { continue }
            guard let day = cal.date(byAdding: .day, value: i, to: start) else { continue }
            let key = dayKey(day, cal)
            let at = { (m: Int) in cal.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: day) }
            let named = i == firstOpen ? streak : 0
            var riskAt: Date?
            if s.streakRisk && i == firstOpen && streak >= riskThreshold, let t = at(riskMinutes), t > now { riskAt = t }
            // the daily one gives way to the late nudge when they'd come within half an hour
            if let t = at(s.minutes), t > now, !(riskAt != nil && abs(s.minutes - riskMinutes) < 30) {
                let c = daily(streak: named, seed: key)
                out.append(Request(id: id(.daily, key), kind: .daily, day: key, fire: t, title: c.title, body: c.body))
            }
            if let t = riskAt {
                let c = risk(streak: streak, seed: key)
                out.append(Request(id: id(.risk, key), kind: .risk, day: key, fire: t, title: c.title, body: c.body))
            }
        }
        return out
    }

    /// Today's reminders, to take away once the day is lit.
    static func litIds(_ today: String) -> [String] { [id(.daily, today), id(.risk, today)] }

    // MARK: the words, in Bùbù's voice

    static func daily(streak n: Int, seed: String) -> (title: String, body: String) {
        let list: [(String, String)] = n > 0 ? [
            ("Bùbù's hungry for a lesson 🥟", "One short lesson keeps your \(n)-day streak going."),
            ("你好! Got 5 minutes?", "Your \(n)-day streak would love a lesson today."),
            ("Time for a little Chinese 🐼", "Day \(n + 1) of your streak is one lesson away."),
            ("Bùbù saved you a seat", "A quick lesson keeps your \(n)-day fire lit 🔥"),
        ] : [
            ("Bùbù's hungry for a lesson 🥟", "Five minutes of Chinese today? Bùbù will be right there with you."),
            ("5 minutes of Chinese?", "你好 is waiting. One short lesson lights today's fire."),
            ("Time for a little Chinese 🐼", "A few words a day add up. 一步一步, step by step."),
            ("Bùbù has new words for you", "Pop in for a quick lesson and light today's fire 🔥"),
        ]
        return pick(list, seed: seed)
    }

    static func risk(streak n: Int, seed: String) -> (title: String, body: String) {
        pick([
            ("Your \(n)-day streak ends at midnight", "One lesson keeps it alive. Bùbù believes in you 🐼"),
            ("Still time to keep your \(n)-day streak 🔥", "One short lesson before midnight keeps the fire lit."),
            ("\(n) days and counting 🔥", "Your streak ends at midnight. A quick lesson keeps it going."),
        ], seed: seed)
    }

    /// A variant chosen by the day, the same every time (FNV-1a, as ProgressStore.pick).
    private static func pick(_ list: [(String, String)], seed: String) -> (title: String, body: String) {
        var h: UInt32 = 2166136261
        for u in seed.utf16 { h ^= UInt32(u); h = h &* 16777619 }
        let c = list[Int(h % UInt32(list.count))]
        return (c.0, c.1)
    }

    /// "7:00 PM", in the phone's own style.
    static func timeText(_ minutes: Int) -> String {
        let d = Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
        return d.formatted(date: .omitted, time: .shortened)
    }
}

extension ReminderPlan.Settings {
    init(prefs: Prefs) {
        self.init(on: prefs.reminders == true, minutes: prefs.reminderMinutes ?? ReminderPlan.defaultMinutes,
                  streakRisk: prefs.streakNudge ?? true)
    }
}

/// The notification centre side: permission, and putting the plan in place.
@Observable
final class Reminders {
    static let shared = Reminders()

    private(set) var status: UNAuthorizationStatus = .notDetermined
    /// A reminder was tapped: the root view goes to Learn and clears this.
    var openLearn = false

    @ObservationIgnored private let delegate = Delegate()
    @ObservationIgnored private var installed = false
    private var center: UNUserNotificationCenter { .current() }

    var allowed: Bool { [.authorized, .provisional, .ephemeral].contains(status) }

    /// Once, at launch: take reminder taps, and listen for the day being lit.
    func install() {
        guard !installed else { return }
        installed = true
        delegate.tapped = { [weak self] in DispatchQueue.main.async { self?.openLearn = true } }
        center.delegate = delegate
        NotificationCenter.default.addObserver(forName: .bubuDayLit, object: nil, queue: .main) { [weak self] n in
            guard let p = n.object as? ProgressStore else { return }
            self?.dayLit(p)
        }
    }

    func refresh(_ then: (() -> Void)? = nil) {
        center.getNotificationSettings { s in
            DispatchQueue.main.async { self.status = s.authorizationStatus; then?() }
        }
    }

    /// iOS's own permission prompt; true if reminders may be shown.
    func ask(_ done: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .sound]) { ok, _ in
            DispatchQueue.main.async { self.refresh { done(ok) } }
        }
    }

    /// Today's fire is lit: today's reminders go at once, then the week is planned again.
    func dayLit(_ p: ProgressStore) {
        let ids = ReminderPlan.litIds(p.today)
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
        reschedule(p)
    }

    /// Replace the pending reminders with the plan for now.
    func reschedule(_ p: ProgressStore) {
        let settings = ReminderPlan.Settings(prefs: p.prefs)
        let lit = p.litOn(p.today), streak = p.streak
        let now = Date(timeIntervalSince1970: p.now() / 1000)
        refresh { [self] in
            let plan = allowed ? ReminderPlan.requests(settings, now: now, calendar: .current, litToday: lit, streak: streak) : []
            apply(plan)
        }
    }

    private func apply(_ plan: [ReminderPlan.Request]) {
        let keep = Set(plan.map(\.id)), center = self.center
        center.getPendingNotificationRequests { pending in
            let stale = pending.map(\.identifier).filter { $0.hasPrefix(ReminderPlan.prefix) && !keep.contains($0) }
            center.removePendingNotificationRequests(withIdentifiers: stale)
            for r in plan {
                let c = UNMutableNotificationContent()
                c.title = r.title
                c.body = r.body
                c.sound = .default
                c.threadIdentifier = "bubu.reminders"
                let when = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: r.fire)
                // the same id replaces what was there
                center.add(UNNotificationRequest(identifier: r.id, content: c,
                                                 trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: false)))
            }
        }
    }

    private final class Delegate: NSObject, UNUserNotificationCenterDelegate {
        var tapped: (() -> Void)?
        /// In the app already: no banner.
        func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                    withCompletionHandler done: @escaping (UNNotificationPresentationOptions) -> Void) {
            done([])
        }
        func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                    withCompletionHandler done: @escaping () -> Void) {
            if response.notification.request.identifier.hasPrefix(ReminderPlan.prefix) { tapped?() }
            done()
        }
    }
}
