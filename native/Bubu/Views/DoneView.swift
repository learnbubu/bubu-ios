import SwiftUI

/// The end of a session, in the web's three stages: what you earned, your fire,
/// then today's quests with where to go next. All on one card, as on the web.
struct DoneView: View {
    let session: StudySession
    var close: () -> Void
    var again: () -> Void
    var next: (String) -> Void
    @Environment(ProgressStore.self) private var progress
    // the step screenshot opens on the last stage, where Next step is
    @State private var stage = Launch.screen == "donenext" ? 2 : 0
    @State private var flameIn = false
    /// the opening splash: the title over a tilted band with Bùbù and confetti, about a second
    /// (the owner's Duolingo recording, 6 Oct 2026); not on the debug screens past the first stage
    @State private var splash = Launch.screen != "donenext"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let course = Course.shared

    static let milestoneWords: [Int: String] = [
        3: "Three days. It's a habit now.", 7: "A whole week on fire.", 14: "Two weeks. Unstoppable.",
        30: "A month. Seriously impressive.", 50: "Fifty days of Chinese.", 100: "One hundred days.",
        200: "Two hundred days.", 365: "A full year. 太厉害了!",
    ]

    var body: some View {
        let r = session.result!
        // the stage fills the space above the buttons (the first keeps its parts together,
        // centred) and the buttons stay pinned at the foot
        VStack(spacing: 0) {
            Group {
                if !r.simple.isEmpty { simple(r) } else if splash && stage == 0 { splashView(r) } else {
                switch stage {
                case 0: stageOne(r)
                case 1: stageTwo(r)
                default: stageThree(r)
                }
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            .id(stage)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            buttons(r).padding(.top, 12)
                .opacity(splash && r.simple.isEmpty && stage == 0 ? 0 : 1)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 18)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Color.line, lineWidth: 1))
        .padding(.top, 8).padding(.bottom, 8)
        .sensoryFeedback(.success, trigger: stage) { _, n in n == 1 }
        .onAppear {
            guard splash else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.6 : 1.35)) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { splash = false }
            }
        }
    }

    /// The opening splash: a tilted band, Bùbù big and pleased, the title, confetti.
    private func splashView(_ r: StudySession.Result) -> some View {
        SplashMoment(title: r.title)
    }

    /// The short result the skip test ends on (web: doneSimple).
    private func simple(_ r: StudySession.Result) -> some View {
        VStack(spacing: 0) {
            Image(r.title == "Not yet" ? "panda-sad" : "done-panda").resizable().scaledToFit().frame(width: 120, height: 120)
            heading(r.title).padding(.top, 4)
            HStack(spacing: 10) {
                ForEach(Array(r.simple.enumerated()), id: \.offset) { _, s in
                    VStack(spacing: 2) {
                        Text(s.value).font(.nunito(24.8, .black)).foregroundStyle(Color.accent)
                        Text(s.label.uppercased()).font(.nunitoXB(10.9)).tracking(1.1).foregroundStyle(Color.accent)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(.top, 14)
        }
    }

    private func heading(_ t: String) -> some View {
        Text(t).font(.nunito(16.8, .bold)).foregroundStyle(Color.ink).multilineTextAlignment(.center)
    }

    // MARK: stage 1: XP, time, accuracy

    private func stageOne(_ r: StudySession.Result) -> some View {
        // a stone's new words (or a practice stone's words) take the place of "This week",
        // which the fire stage shows next anyway
        let recap = r.learned.isEmpty ? r.practised : r.learned
        return VStack(spacing: 0) {
            // Bùbù takes whatever height is spare, so the card is filled from the top rather than
            // centred with empty room above (the owner, 4 Oct 2026)
            Image("done-panda").resizable().scaledToFit()
                .frame(minHeight: 120, maxHeight: recap.isEmpty ? 300 : 260)
                .layoutPriority(-1)
            Text(r.title).font(.nunito(28, .black)).tracking(-0.4).foregroundStyle(Color.gold).multilineTextAlignment(.center)
                .padding(.top, 2)
            if r.steps > 1 {
                // a step of a longer lesson: how far through it you are, and what's next
                StepSegments(done: r.step, total: r.steps, width: 34, height: 7).padding(.top, 8)
                Text(r.steps - r.step == 1 ? "One more step finishes the lesson" : "\(r.steps - r.step) more steps finish the lesson")
                    .font(.nunito(14, .semibold)).foregroundStyle(Color.muted).padding(.top, 6)
            } else if r.lessonFinished, let l = course.lessonById[session.lessonId] {
                Text(l.name).font(.nunito(14.5, .semibold))
                    .foregroundStyle(Color.muted).lineLimit(1).minimumScaleFactor(0.8).padding(.top, 4)
            }
            // Duolingo's result tiles: a coloured band with the label, the number on white under it
            HStack(spacing: 10) {
                XPTile(steps: Self.xpSteps(r), delay: 0.2)
                DoneTile(value: r.seconds, format: { String(format: "%d:%02d", $0 / 60, $0 % 60) }, label: Self.timeLabel(r), icon: "clock.fill", tint: .accent, delay: 0.42)
                DoneTile(value: r.accuracy, format: { "\($0)%" }, label: Self.accuracyLabel(r.accuracy), icon: "scope", tint: .good, delay: 0.64)
            }
            .padding(.top, recap.isEmpty ? 22 : 16).padding(.bottom, 4)
            // what this earned, as quiet rows rather than shouting pills
            let notes: [(String, String, Color)] = ([
                r.perfect ? ("star.fill", "Perfect: no mistakes, +5 XP", Color.gold) : nil,
                r.lessonFinished ? ("bolt.fill", "Double XP for the next 15 minutes", Color.accent) : nil,
                r.fixed > 0 ? ("checkmark.circle.fill", "\(r.fixed) mistake\(r.fixed == 1 ? "" : "s") fixed", Color.good)
                    : r.mistakes > 0 ? ("arrow.counterclockwise.circle.fill", "\(r.mistakes) mistake\(r.mistakes == 1 ? "" : "s") saved to Fix your mistakes", Color.again)
                    : progress.boostActive && !r.lessonFinished ? ("bolt.fill", "Double XP is on", Color.accent) : nil,
            ] as [(String, String, Color)?]).compactMap { $0 }
            if !notes.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(notes, id: \.1) { n in note(n.1, icon: n.0, tint: n.2) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14).padding(.vertical, 11)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.line, lineWidth: 1.5))
                .padding(.top, 12)
            }
            if !recap.isEmpty {
                WordRecap(title: r.learned.isEmpty ? "YOU PRACTISED" : "YOU LEARNED", cards: recap)
                    .padding(.top, 14)
            } else {
                // this week, so the streak is in view from the first screen
                VStack(spacing: 10) {
                    HStack {
                        Text("THIS WEEK").font(.nunitoXB(10.9)).tracking(1.1).foregroundStyle(Color.muted)
                        Spacer()
                        Label("\(progress.streak) day\(progress.streak == 1 ? "" : "s")", systemImage: "flame.fill")
                            .font(.nunitoXB(12)).foregroundStyle(Color.gold)
                    }
                    WeekStrip()
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Color.bg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.top, 18)
            }
        }
    }

    /// The XP tile's steps, each counted up to in turn with its own label (as Duolingo's): the
    /// lesson's own XP, then what runs added, then what double XP added.
    static func xpSteps(_ r: StudySession.Result) -> [XPTile.Step] {
        let base = max(0, r.xp - r.xpCombo - r.xpDouble)
        var out = [XPTile.Step(label: "Lesson XP", value: base, tint: Color(light: 0xF0A92E, dark: 0xF5B03D))]
        if r.xpCombo > 0 { out.append(.init(label: "Combo", value: base + r.xpCombo, tint: Color(light: 0xE8743B, dark: 0xF08A5A))) }
        if r.xpDouble > 0 { out.append(.init(label: "2× XP", value: r.xp, tint: Color(light: 0x8B5CF6, dark: 0xA78BFA))) }
        // each part keeps its own label; the total comes last, in the gold of the plain tile
        if out.count > 1 { out.append(.init(label: "Total XP", value: r.xp, tint: Color(light: 0xF0A92E, dark: 0xF5B03D))) }
        return out
    }
    static func accuracyLabel(_ a: Int) -> String { a >= 100 ? "Perfect" : a >= 90 ? "Amazing" : a >= 75 ? "Great" : "Accuracy" }
    /// Quick for its length: under about 9 seconds an answer.
    static func timeLabel(_ r: StudySession.Result) -> String {
        r.seconds > 0 && r.seconds <= 150 ? "Speedy" : "Time"
    }

    private func note(_ t: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 20)
            Text(t).font(.nunito(14, .bold)).foregroundStyle(Color.ink).lineLimit(2)
        }
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
            Group {
                Label((r.fire?.ember == true ? "You earned an ember · " : "") + "\(progress.embers) ember\(progress.embers == 1 ? "" : "s") protecting it",
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { Moments.shared.show(.milestone(f.streak, ember: f.ember, coins: f.coins)) }
            } else if r.fireJustLit { Sounds.shared.play("goal") }
        }
    }

    // MARK: stage 3: quests

    private func stageThree(_ r: StudySession.Result) -> some View {
        let quests = progress.todayQuests
        let done = quests.filter { progress.progress(of: $0) >= $0.target }.count
        return VStack(spacing: 4) {
            heading("Daily quests")
            Text(done == 3 ? "All three done. Lucky pocket opened!" : "\(done) of 3 done today")
                .font(.nunito(16)).foregroundStyle(Color.muted)
            QuestRows(animated: true).padding(.top, 6).padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: buttons

    @ViewBuilder
    private func buttons(_ r: StudySession.Result) -> some View {
        VStack(spacing: 8) {
            if !r.simple.isEmpty {
                Button("← Back to path") { close() }.buttonStyle(WideButton())
            } else if stage < 2 {
                Button("Continue") { withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { stage += 1 } }
                    .buttonStyle(WideButton())
            } else {
                if r.wordsLeft > 0 {
                    // the next step of this lesson, straight away
                    Button("Next step →") { next(session.lessonId) }
                        .buttonStyle(WideButton())
                } else if let id = r.nextLessonId, let l = course.lessonById[id] {
                    Button("Next: \(l.name) →") { next(id) }
                        .buttonStyle(WideButton())
                }
                if !session.isQuiz {
                    Button("Practice again", action: again)
                        .buttonStyle(WideButton())
                }
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
    var icon: String
    var tint: Color
    let delay: Double
    @State private var shown = 0

    var body: some View {
        VStack(spacing: 0) {
            Text(label.uppercased()).font(.nunitoXB(11)).tracking(1.1).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity).padding(.vertical, 5)
                .background(tint)
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 15, weight: .bold))
                Text(format(shown)).font(.nunito(21, .black)).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .contentTransition(.numericText())
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity).padding(.vertical, 12).padding(.horizontal, 4)
            .background(Color.panel)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .padding([.horizontal, .bottom], 2.5)
        }
        .background(tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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

/// This week, Monday to Sunday: a tick for a day with a finished session, today dashed.
struct WeekStrip: View {
    @Environment(ProgressStore.self) private var progress
    var body: some View {
        let days = progress.thisWeek, today = progress.today
        let names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        HStack(spacing: 2) {
            ForEach(0..<7, id: \.self) { i in
                let d = days[i]
                let met = progress.litOn(d), goal = false
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
    /// on the done screen: each bar fills in turn, and a finished quest glows gold and shines
    var animated = false
    @State private var filled = false
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
                        Bar(value: !animated || filled ? Double(n) / Double(q.target) : 0, fill: ok ? .good : .accent)
                            .animation(.easeOut(duration: 0.55).delay(0.15 + Double(i) * 0.35), value: filled)
                    }
                    Text(ok ? "Done" : "\(n)/\(q.target)").font(.nunitoXB(13)).monospacedDigit()
                        .foregroundStyle(ok ? Color.good : Color.muted)
                        .frame(minWidth: 40, alignment: .trailing)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, animated && ok ? 8 : 0)
                .background {
                    if animated && ok {
                        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.goodSoft.opacity(0.5))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.gold, lineWidth: 2))
                    }
                }
                .modifier(SuccessShine(on: animated && ok && filled, delay: 0.15 + Double(i) * 0.35 + 0.5))
                .overlay(alignment: .top) { if i > 0 && !(animated && ok) { Rectangle().fill(Color.line).frame(height: 1) } }
            }
        }
        .onAppear { if animated { DispatchQueue.main.async { filled = true } } }
    }
}

/// The XP tile on the done screen: counts up through its steps (Lesson XP, Combo, 2× XP),
/// its label and colour changing at each, with a little pop as each lands (as Duolingo's).
struct XPTile: View {
    struct Step { let label: String; let value: Int; let tint: Color }
    let steps: [Step]
    let delay: Double
    @State private var shown = 0
    @State private var at = 0
    @State private var pop = false

    var body: some View {
        let s = steps[min(at, steps.count - 1)]
        VStack(spacing: 0) {
            Text(s.label.uppercased()).font(.nunitoXB(11)).tracking(1.1).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity).padding(.vertical, 5)
                .background(s.tint)
                .contentTransition(.opacity)
            HStack(spacing: 5) {
                Image(systemName: "bolt.fill").font(.system(size: 15, weight: .bold))
                Text("+\(shown)").font(.nunito(21, .black)).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .contentTransition(.numericText())
            }
            .foregroundStyle(s.tint)
            .frame(maxWidth: .infinity).padding(.vertical, 12).padding(.horizontal, 4)
            .background(Color.panel)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .padding([.horizontal, .bottom], 2.5)
        }
        .background(s.tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .scaleEffect(pop ? 1.07 : 1)
        .shadow(color: s.tint.opacity(pop ? 0.5 : 0), radius: 8)
        .overlay { CornerSparkles(on: pop, tint: .white) }
        .animation(.easeOut(duration: 0.2), value: at)
        .task {
            try? await Task.sleep(for: .seconds(delay))
            var from = 0
            for (k, step) in steps.enumerated() {
                at = k
                let n = 16
                for i in 1...n {
                    let t = Double(i) / Double(n), eased = 1 - pow(1 - t, 3)
                    withAnimation(.linear(duration: 0.03)) { shown = from + Int((Double(step.value - from) * eased).rounded()) }
                    try? await Task.sleep(for: .milliseconds(30))
                }
                from = step.value
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { pop = true }
                try? await Task.sleep(for: .milliseconds(180))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { pop = false }
                if k < steps.count - 1 { try? await Task.sleep(for: .milliseconds(220)) }
            }
        }
    }
}

/// The done screen's opening: a tilted green band, Bùbù big and pleased, the title, confetti.
struct SplashMoment: View {
    let title: String
    @State private var band = false
    @State private var panda = false
    @State private var words = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.accent.opacity(0.35), Color.accent.opacity(0.75)], startPoint: .leading, endPoint: .trailing)
                .frame(height: 230)
                .rotationEffect(.degrees(-9))
                .scaleEffect(x: band ? 1.4 : 0.01, y: 1, anchor: .leading)
                .offset(y: -40)
            VStack(spacing: 18) {
                Image("panda-celebrate").resizable().scaledToFit().frame(height: 230)
                    .scaleEffect(panda ? 1 : 0.3).opacity(panda ? 1 : 0)
                    .rotationEffect(.degrees(panda ? -4 : 8))
                Text(title).font(.nunito(32, .black)).foregroundStyle(Color.gold).multilineTextAlignment(.center)
                    .scaleEffect(words ? 1 : 0.6).opacity(words ? 1 : 0)
            }
            Confetti(count: 40).allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .onAppear {
            withAnimation(.easeOut(duration: 0.25)) { band = true }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55).delay(0.12)) { panda = true }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6).delay(0.3)) { words = true }
        }
    }
}

/// The done screen's recap of a stone's new words ("You learned") or a practice stone's
/// words ("You practised"): characters, pinyin, a short meaning and a speaker each, two to
/// a row so up to six fit without crowding the screen.
struct WordRecap: View {
    let title: String
    let cards: [Card]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.nunitoXB(10.9)).tracking(1.1).foregroundStyle(Color.muted)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(cards, id: \.id) { c in cell(c) }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 11)
        .background(Color.bg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func cell(_ c: Card) -> some View {
        let w = c.word
        return HStack(spacing: 4) {
            if let pic = Pictures.asset(w.hanzi) {
                Image(pic).resizable().scaledToFit().frame(width: 30, height: 30).padding(.trailing, 4)
            }
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(w.hanzi).font(.hanzi(w.hanzi.count > 2 ? 16 : 19, .semibold)).foregroundStyle(Color.ink)
                        .lineLimit(1).layoutPriority(1)
                    PinyinText(pinyin: w.pinyin, size: 12).lineLimit(1).minimumScaleFactor(0.6)
                }
                Text(w.gloss).font(.nunito(12.5, .semibold)).foregroundStyle(Color.muted)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
            SpeakerButton(text: w.hanzi, size: 15)
                .accessibilityLabel("Hear \(w.hanzi)")
        }
        .padding(.leading, 10).padding(.trailing, 4).padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
