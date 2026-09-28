import SwiftUI
import UIKit

extension View {
    /// Keeps the reminders planned (launch, coming back, settings changing), sends a
    /// tapped reminder to Learn, and offers reminders once the first session is done.
    /// Goes inside the root view's `.environment(router)`.
    func reminderHost() -> some View { modifier(ReminderHost()) }
}

private struct ReminderHost: ViewModifier {
    @Environment(ProgressStore.self) private var progress
    @Environment(Router.self) private var router
    @Environment(\.scenePhase) private var phase
    @State private var reminders = Reminders.shared
    @State private var offer = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if offer {
                    ReminderOffer { withAnimation(.easeOut(duration: 0.25)) { offer = false } }
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .zIndex(6)
                }
            }
            .onChange(of: phase, initial: true) { _, ph in
                if ph == .active { reminders.reschedule(progress) }
            }
            .onChange(of: ReminderPlan.Settings(prefs: progress.prefs)) { _, _ in reminders.reschedule(progress) }
            .onChange(of: reminders.openLearn, initial: true) { _, go in
                guard go else { return }
                reminders.openLearn = false
                if router.study == nil && router.lesson == nil { router.tab = .learn }
            }
            // a session has just closed: the first one done is the moment to ask
            .onChange(of: router.study == nil) { _, closed in if closed { maybeOffer() } }
            .onAppear {
                #if DEBUG
                if Launch.screen == "remind" {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { offer = true } }
                }
                #endif
            }
    }

    private func maybeOffer() {
        guard Launch.screen == nil, progress.prefs.remindersAsked != true, progress.prefs.reminders == nil,
              progress.litOn(progress.today) else { return }
        reminders.refresh {
            guard reminders.status == .notDetermined else { return }
            // after the done screen's own moments have had their turn
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                guard router.study == nil, Moments.shared.current == nil else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { offer = true }
            }
        }
    }
}

/// "Want a daily reminder?", once, after the first session is done.
struct ReminderOffer: View {
    var close: () -> Void
    @Environment(ProgressStore.self) private var progress
    @State private var shown = false

    var body: some View {
        let time = ReminderPlan.timeText(progress.prefs.reminderMinutes ?? ReminderPlan.defaultMinutes)
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 6) {
                Image("done-panda").resizable().scaledToFit().frame(width: 120)
                Text("Want a daily reminder?").font(.nunitoXB(22)).foregroundStyle(Color.ink)
                Text("Bùbù can give you a gentle nudge at \(time) on days you haven't practised yet. Nothing on days you have.")
                    .font(.nunito(15.5, .semibold)).foregroundStyle(Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 8) {
                    Button("Remind me") { remind() }.buttonStyle(WideButton())
                    Button("Not now") { answer(nil) }.buttonStyle(WideButton(ghost: true))
                }
                .padding(.top, 14)
                Text("You can change this any time in Settings.")
                    .font(.nunito(12.5)).foregroundStyle(Color.muted).padding(.top, 4)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24).padding(.vertical, 26)
            .frame(maxWidth: 330)
            .background(Color.panel, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 30, y: 12)
            .scaleEffect(shown ? 1 : 0.85)
            .padding(24)
        }
        .onAppear { withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) { shown = true } }
    }

    private func remind() {
        Reminders.shared.ask { ok in
            answer(ok)
            if ok {
                let t = ReminderPlan.timeText(progress.prefs.reminderMinutes ?? ReminderPlan.defaultMinutes)
                Moments.shared.toast("Reminders on for \(t). Change it any time in Settings.")
            }
        }
    }

    /// nil is "Not now": reminders stay off, and the card doesn't come back.
    private func answer(_ on: Bool?) {
        progress.prefs.remindersAsked = true
        if let on { progress.prefs.reminders = on }
        close()
    }
}

/// The Reminders section of Settings: on or off, the time, and the streak-at-risk nudge.
struct ReminderSettings: View {
    @Environment(ProgressStore.self) private var progress
    @State private var reminders = Reminders.shared

    var body: some View {
        let p = progress
        let on = p.prefs.reminders == true
        VStack(alignment: .leading, spacing: 0) {
            row("Reminders", "A gentle nudge from Bùbù on days you haven't practised yet.") {
                Toggle("", isOn: Binding(get: { on }, set: setOn)).labelsHidden().tint(.accent)
            }
            if on && reminders.status == .denied { denied }
            line
            row("Reminder time", "Bùbù skips the day once you've done a session.") {
                DatePicker("", selection: Binding(get: { date(p.prefs.reminderMinutes ?? ReminderPlan.defaultMinutes) },
                                                  set: { p.prefs.reminderMinutes = minutes($0) }),
                           displayedComponents: .hourAndMinute)
                    .labelsHidden().tint(.accent)
            }
            .disabled(!on).opacity(on ? 1 : 0.45)
            line
            row("Streak at risk", "One more nudge at \(ReminderPlan.timeText(ReminderPlan.riskMinutes)) when a streak of \(ReminderPlan.riskThreshold) days or more would end at midnight.") {
                Toggle("", isOn: Binding(get: { p.prefs.streakNudge ?? true }, set: { p.prefs.streakNudge = $0 }))
                    .labelsHidden().tint(.accent)
            }
            .disabled(!on).opacity(on ? 1 : 0.45)
        }
        .padding(.horizontal, 14)
        .panel(radius: 18)
        .onAppear { reminders.refresh() }
    }

    /// Switching on asks iOS the first time; if notifications are off for the app,
    /// the note below says where to turn them on.
    private func setOn(_ v: Bool) {
        progress.prefs.remindersAsked = true
        progress.prefs.reminders = v
        if v && reminders.status == .notDetermined { reminders.ask { _ in reminders.reschedule(progress) } }
    }

    private var denied: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "bell.slash.fill").foregroundStyle(Color.again).padding(.top, 2)
            VStack(alignment: .leading, spacing: 6) {
                Text("Notifications are off for Bùbù").font(.nunito(14, .bold)).foregroundStyle(Color.ink)
                Text("Turn them on in the iPhone's Settings → Notifications → 步步 Bùbù, then reminders will start.")
                    .font(.nunito(13)).foregroundStyle(Color.muted).fixedSize(horizontal: false, vertical: true)
                Button("Open Settings") {
                    if let u = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(u) }
                }
                .font(.nunito(14, .bold)).foregroundStyle(Color.accent)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.againSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.bottom, 13)
    }

    private func date(_ m: Int) -> Date {
        Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Date()) ?? Date()
    }
    private func minutes(_ d: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return (c.hour ?? 19) * 60 + (c.minute ?? 0)
    }

    // the same look as Settings' own rows
    private var line: some View { Rectangle().fill(Color.line).frame(height: 1) }

    private func row<C: View>(_ label: String, _ desc: String, @ViewBuilder control: () -> C) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.nunitoXB(16)).foregroundStyle(Color.ink)
                Text(desc).font(.nunito(13)).foregroundStyle(Color.muted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            control()
        }
        .padding(.vertical, 13)
    }
}
