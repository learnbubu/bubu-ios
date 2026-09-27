import SwiftUI

/// The end of a session, in the web's three stages: what you earned, your fire,
/// then today's quests with where to go next.
struct DoneView: View {
    let session: StudySession
    var close: () -> Void
    var again: () -> Void
    var next: (String) -> Void
    @Environment(ProgressStore.self) private var progress
    @State private var stage = 0
    private let course = Course.shared

    var body: some View {
        let r = session.result!
        VStack(spacing: 0) {
            Spacer(minLength: 12)
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
        .padding(.horizontal, 20).padding(.bottom, 14)
        .frame(maxWidth: 460)
        .onAppear { if r.goalReached { Sounds.shared.play("goal") } }
    }

    // MARK: stage 1: XP, time, accuracy

    private func stageOne(_ r: StudySession.Result) -> some View {
        VStack(spacing: 0) {
            Image("panda-celebrate").resizable().scaledToFit().frame(height: 160)
            Text(r.title).font(.nunitoXB(26)).foregroundStyle(Color.ink).padding(.top, 4)
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
                else if progress.boostActive && !r.lessonFinished { note("Double XP is on", fg: .accent, bg: .accentSoft) }
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
            ? (streak == 1 ? "Fire lit. Come back tomorrow to make it two." : "Fire lit. Keep it going tomorrow.")
            : lit ? "Already lit today. Keep it going tomorrow." : "Finish a session to light today's fire."
        return VStack(spacing: 0) {
            Image(systemName: "flame.fill")
                .font(.system(size: 96))
                .foregroundStyle(lit ? AnyShapeStyle(LinearGradient(colors: [Color(UIColor(hex: 0xFFB347)), Color(UIColor(hex: 0xF0742F))], startPoint: .top, endPoint: .bottom))
                                     : AnyShapeStyle(Color.muted.opacity(0.6)))
                .shadow(color: lit ? Color(UIColor(hex: 0xF08A7A)).opacity(0.6) : .clear, radius: 16)
                .frame(width: 110, height: 110)
                .phaseAnimator([0.6, 1.0], trigger: stage) { v, s in v.scaleEffect(s) } animation: { _ in .spring(response: 0.5, dampingFraction: 0.5) }
            Text("\(streak)").font(.nunito(57.6, .black)).tracking(-1.5).foregroundStyle(Color.ink).padding(.top, 6)
            Text("day streak").font(.nunitoXB(22)).foregroundStyle(Color.ink).padding(.top, 4)
            WeekStrip().frame(maxWidth: 330).padding(.top, 14)
            Text(msg).font(.nunito(15, .semibold)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
                .padding(.top, 10).padding(.bottom, 14)
        }
        .onAppear { if r.fireJustLit { Sounds.shared.play("goal") } }
        .sensoryFeedback(.success, trigger: stage)
    }

    // MARK: stage 3: quests

    private func stageThree(_ r: StudySession.Result) -> some View {
        let quests = progress.todayQuests
        let done = quests.filter { progress.progress(of: $0) >= $0.target }.count
        return VStack(alignment: .leading, spacing: 4) {
            Text("Daily quests").font(.nunitoXB(26)).foregroundStyle(Color.ink)
            Text(done == 3 ? "All three done. Chest opened!" : "\(done) of 3 done today")
                .font(.nunito(15, .semibold)).foregroundStyle(Color.muted)
            QuestRows().padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: buttons

    @ViewBuilder
    private func buttons(_ r: StudySession.Result) -> some View {
        VStack(spacing: 8) {
            if stage < 2 {
                Button("Continue") { withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { stage += 1 } }
                    .buttonStyle(PrimaryButtonStyle())
            } else {
                if r.wordsLeft > 0 {
                    Button("Keep going — \(r.wordsLeft) word\(r.wordsLeft == 1 ? "" : "s") left →") { next(session.lessonId) }
                        .buttonStyle(PrimaryButtonStyle())
                } else if let id = r.nextLessonId, id != session.lessonId, let l = course.lessonById[id] {
                    Button("Next: \(l.name) →") { next(id) }
                        .buttonStyle(PrimaryButtonStyle())
                }
                Button("Practice again", action: again)
                    .buttonStyle(PrimaryButtonStyle(color: .panel, base: .line, text: .ink))
                Button { close() } label: {
                    Text("← Back to path").font(.nunito(16, .bold)).foregroundStyle(Color.muted).padding(10)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: 360)
    }
}

/// A result tile that counts up from zero.
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
            Text(format(shown)).font(.nunito(24, .black)).monospacedDigit().foregroundStyle(ink)
                .contentTransition(.numericText())
            Text(label).font(.nunito(12.5, .bold)).foregroundStyle(ink.opacity(0.8))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
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
