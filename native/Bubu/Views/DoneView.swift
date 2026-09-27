import SwiftUI

/// The end of a session, in the web's three stages: what you earned, your fire,
/// then today's quests with where to go next. All on one card, as on the web.
struct DoneView: View {
    let session: StudySession
    var close: () -> Void
    var again: () -> Void
    var next: (String) -> Void
    @Environment(ProgressStore.self) private var progress
    @State private var stage = 0
    @State private var flameIn = false
    private let course = Course.shared

    static let milestoneWords: [Int: String] = [
        3: "Three days. It's a habit now.", 7: "A whole week on fire.", 14: "Two weeks. Unstoppable.",
        30: "A month. Seriously impressive.", 50: "Fifty days of Chinese.", 100: "One hundred days.",
        200: "Two hundred days.", 365: "A full year. 太厉害了!",
    ]

    var body: some View {
        let r = session.result!
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Group {
                switch stage {
                case 0: stageOne(r)
                case 1: stageTwo(r)
                default: stageThree(r)
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            .id(stage)
            Spacer(minLength: 12)
            buttons(r)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16).padding(.top, 26).padding(.bottom, 18)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Color.line, lineWidth: 1))
        .padding(.top, 8).padding(.bottom, 8)
        .sensoryFeedback(.success, trigger: stage) { _, n in n == 1 }
    }

    private func heading(_ t: String) -> some View {
        Text(t).font(.nunito(16.8, .bold)).foregroundStyle(Color.ink).multilineTextAlignment(.center)
    }

    // MARK: stage 1: XP, time, accuracy

    private func stageOne(_ r: StudySession.Result) -> some View {
        VStack(spacing: 0) {
            Image("done-panda").resizable().scaledToFit().frame(width: 160)
            heading(r.title).padding(.top, 4)
            HStack(spacing: 10) {
                DoneTile(value: r.xp, format: { "+\($0)" }, label: "XP", bg: Color(light: 0xFEEBBB, dark: 0x2A2B23), ink: Color(light: 0xB06A0A, dark: 0xF5B03D), delay: 0.2)
                DoneTile(value: r.seconds, format: { String(format: "%d:%02d", $0 / 60, $0 % 60) }, label: "Time", bg: .accentSoft, ink: .accent, delay: 0.42)
                DoneTile(value: r.accuracy, format: { "\($0)%" }, label: "Accuracy", bg: .goodSoft, ink: .good, delay: 0.64)
            }
            .padding(.top, 14).padding(.bottom, 6)
            VStack(spacing: 6) {
                if r.perfect { note("Perfect! No mistakes, +5 XP", fg: .gold, bg: .accentSoft) }
                if r.lessonFinished { note("Lesson done: double XP for the next 15 minutes", fg: .accent, bg: .accentSoft) }
                if r.fixed > 0 { note("\(r.fixed) mistake\(r.fixed == 1 ? "" : "s") fixed", fg: .good, bg: .goodSoft) }
                else if r.mistakes > 0 { note("\(r.mistakes) mistake\(r.mistakes == 1 ? "" : "s") saved to practise in Fix your mistakes", fg: .again, bg: .againSoft) }
                else if progress.boostActive { note("Double XP is on", fg: .accent, bg: .accentSoft) }
            }
            .padding(.top, 10)
        }
    }

    private func note(_ t: String, fg: Color, bg: Color) -> some View {
        Text(t).font(.nunito(13.8, .bold)).foregroundStyle(fg).multilineTextAlignment(.center)
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(bg, in: Capsule())
    }

    // MARK: stage 2: the fire

    private func stageTwo(_ r: StudySession.Result) -> some View {
        let streak = progress.streak, lit = progress.litOn(progress.today)
        let msg: String = r.fireJustLit
            ? (streak == 1 ? "Fire lit. Come back tomorrow to make it two."
               : Self.milestoneWords[streak] ?? "Fire lit. Keep it going tomorrow.")
            : lit ? "Already lit today. Keep it going tomorrow." : "Finish a session to light today's fire."
        return VStack(spacing: 0) {
            FlameIcon(lit: lit, size: 110)
                .shadow(color: lit ? Color(UIColor(hex: 0xF08A7A)).opacity(0.6) : .clear, radius: 16)
                .scaleEffect(flameIn ? 1 : 0.6)
            Text("\(streak)").font(.nunito(57.6, .black)).tracking(-1.7).foregroundStyle(Color.ink).padding(.top, 6)
            heading("day streak").padding(.top, 4)
            WeekStrip().frame(maxWidth: 330).padding(.top, 14)
            if let f = r.fire, f.ember || progress.embers > 0 {
                Label((f.ember ? "You earned an ember · " : "") + "\(progress.embers) ember\(progress.embers == 1 ? "" : "s") protecting it",
                      systemImage: "flame.fill")
                    .font(.nunito(13, .bold)).foregroundStyle(Color.gold)
                    .padding(.horizontal, 12).padding(.vertical, 5).background(Color.accentSoft, in: Capsule())
                    .padding(.top, 10)
            }
            Text(msg).font(.nunito(16)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
                .padding(.top, 10).padding(.bottom, 14)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) { flameIn = true }
            if let f = r.fire, f.milestone {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { Moments.shared.show(.milestone(f.streak, ember: f.ember)) }
            } else if r.fireJustLit && !r.goalReached { Sounds.shared.play("goal") }
        }
    }

    // MARK: stage 3: quests

    private func stageThree(_ r: StudySession.Result) -> some View {
        let quests = progress.todayQuests
        let done = quests.filter { progress.progress(of: $0) >= $0.target }.count
        return VStack(spacing: 4) {
            heading("Daily quests")
            Text(done == 3 ? "All three done. Chest opened!" : "\(done) of 3 done today")
                .font(.nunito(16)).foregroundStyle(Color.muted)
            QuestRows().padding(.top, 6).padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: buttons

    @ViewBuilder
    private func buttons(_ r: StudySession.Result) -> some View {
        VStack(spacing: 8) {
            if stage < 2 {
                Button("Continue") { withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { stage += 1 } }
                    .buttonStyle(WideButton())
            } else {
                if r.wordsLeft > 0 {
                    Button("Keep going — \(r.wordsLeft) word\(r.wordsLeft == 1 ? "" : "s") left →") { next(session.lessonId) }
                        .buttonStyle(WideButton())
                } else if let id = r.nextLessonId, let l = course.lessonById[id] {
                    Button("Next: \(l.name) →") { next(id) }
                        .buttonStyle(WideButton())
                }
                Button("Practice again", action: again)
                    .buttonStyle(WideButton())
                Button(session.mode == .lesson ? "← Back to path" : "← Back to home") { close() }
                    .buttonStyle(WideButton(ghost: true))
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: 360)
    }
}

/// The web's full-width button: accent, or a ghost with a thin border.
struct WideButton: ButtonStyle {
    var ghost = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.nunitoXB(16.8)).lineLimit(1).minimumScaleFactor(0.8)
            .foregroundStyle(ghost ? Color.ink : Color.onAccent)
            .frame(maxWidth: .infinity).padding(14)
            .background(ghost ? Color.clear : Color.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(ghost ? Color.line : .clear, lineWidth: 1))
            .offset(y: configuration.isPressed ? 1 : 0)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed)
    }
}

/// The web's two-tone flame; grey until the day is lit.
struct FlameIcon: View {
    var lit: Bool
    var size: CGFloat
    var body: some View {
        Image("flame").resizable().scaledToFit()
            .frame(width: size, height: size)
            .saturation(lit ? 1 : 0.15)
            .opacity(lit ? 1 : 0.6)
    }
}

/// A result tile that counts up from zero: its label on top, the number below.
struct DoneTile: View {
    let value: Int
    let format: (Int) -> String
    let label: String
    let bg: Color
    let ink: Color
    let delay: Double
    @State private var shown = 0

    var body: some View {
        VStack(spacing: 2) {
            Text(label.uppercased()).font(.nunitoXB(10.9)).tracking(1.1).foregroundStyle(ink)
            Text(format(shown)).font(.nunito(24.8, .black)).monospacedDigit().foregroundStyle(ink)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity).padding(.top, 12).padding(.horizontal, 6).padding(.bottom, 10)
        .background(bg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .task {
            try? await Task.sleep(for: .seconds(delay))
            let steps = 20
            for i in 1...steps {
                let t = Double(i) / Double(steps)
                let eased = 1 - pow(1 - t, 3)                 // ease-out cubic over 700 ms
                withAnimation(.linear(duration: 0.035)) { shown = Int((Double(value) * eased).rounded()) }
                try? await Task.sleep(for: .milliseconds(35))
            }
        }
    }
}

/// This week, Monday to Sunday: a tick for a lit day, gold for a goal met, today dashed.
struct WeekStrip: View {
    @Environment(ProgressStore.self) private var progress
    var body: some View {
        let days = progress.thisWeek, today = progress.today
        let names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        HStack(spacing: 2) {
            ForEach(0..<7, id: \.self) { i in
                let d = days[i]
                let met = progress.litOn(d), goal = progress.xp(on: d) >= progress.dailyGoal
                let isToday = d == today, future = d > today
                VStack(spacing: 4) {
                    ZStack {
                        Circle().fill(goal ? Color.gold : met ? Color.good : .clear)
                        Circle().strokeBorder(goal ? Color.gold : met ? Color.good : isToday ? Color.accent : Color.line,
                                              style: StrokeStyle(lineWidth: 2, dash: isToday && !met ? [4, 3] : []))
                        if met { Image(systemName: "checkmark").font(.system(size: 12, weight: .heavy)).foregroundStyle(.white) }
                    }
                    .frame(width: 26, height: 26)
                    Text(names[i]).font(.nunito(11, .bold))
                        .foregroundStyle(isToday ? Color.accent : met ? Color.ink : Color.muted)
                }
                .frame(maxWidth: .infinity)
                .opacity(future ? 0.5 : 1)
            }
        }
    }
}

/// Today's three quests with their bars.
struct QuestRows: View {
    @Environment(ProgressStore.self) private var progress
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(progress.todayQuests.enumerated()), id: \.offset) { i, q in
                let n = min(q.target, progress.progress(of: q)), ok = n >= q.target
                HStack(spacing: 10) {
                    Image(systemName: ok ? "checkmark" : q.icon).font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ok ? Color.good : Color.accent)
                        .frame(width: 30, height: 30)
                        .background(ok ? Color.goodSoft : Color.accentSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(q.title).font(.nunito(14, .bold)).foregroundStyle(Color.ink).lineLimit(1)
                        Bar(value: Double(n) / Double(q.target), fill: ok ? .good : .accent)
                    }
                    Text(ok ? "Done" : "\(n)/\(q.target)").font(.nunitoXB(13)).monospacedDigit()
                        .foregroundStyle(ok ? Color.good : Color.muted)
                        .frame(minWidth: 40, alignment: .trailing)
                }
                .padding(.vertical, 8)
                .overlay(alignment: .top) { if i > 0 { Rectangle().fill(Color.line).frame(height: 1) } }
            }
        }
    }
}
