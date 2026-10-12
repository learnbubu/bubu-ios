import SwiftUI

/// The end of a session, a screen at a time (the after-lesson prototype, 12 Oct 2026): how it went,
/// the words met, the streak's lantern lighting, a red pocket, the quests moving on, then where
/// to go next. Screens with nothing to show are skipped.
struct DoneView: View {
    let session: StudySession
    var close: () -> Void
    var again: () -> Void
    var next: (String) -> Void
    @Environment(ProgressStore.self) private var progress
    // the step screenshot opens on the last stage, where Next step is
    @State private var stage = Launch.screen == "donenext" ? 99 : 0
    /// the button waits while the streak plays and until the pocket is opened
    @State private var held = false

    enum Step { case result, learned, streak, pocket, quests }
    /// The screens this session gets, in order.
    private func steps(_ r: StudySession.Result) -> [Step] {
        guard r.simple.isEmpty else { return [.result] }
        var out: [Step] = [.result]
        if !(r.learned.isEmpty ? r.practised : r.learned).isEmpty { out.append(.learned) }
        if r.fireJustLit { out.append(.streak) }
        if r.pocket != nil { out.append(.pocket) }
        if progress.todayQuests.contains(where: { progress.progress(of: $0) > (r.questsBefore[$0.id] ?? 0) }) || out.count == 1 { out.append(.quests) }
        return out
    }
    private func step(_ r: StudySession.Result) -> Step { let s = steps(r); return s[min(stage, s.count - 1)] }
    private func isLast(_ r: StudySession.Result) -> Bool { stage >= steps(r).count - 1 }
    private func advance(_ r: StudySession.Result) {
        let s = steps(r), n = min(stage + 1, s.count - 1)
        held = (s[n] == .streak && !reduceMotion) || s[n] == .pocket
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { stage = n }
    }
    /// the opening splash: the title over a tilted band with Bùbù and confetti, about a second
    /// (the owner's Duolingo recording, 6 Oct 2026); not on the debug screens past the first stage
    @State private var splash = Launch.screen != "donenext"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let course = Course.shared
    /// the sticker moment (made in the effects studio) plays only if its player has loaded; else
    /// the usual splash and Bùbù
    @State private var playerReady = MomentPlayer.shared.ready
    @State private var stickerBox: CGRect = .zero
    @State private var stageOrigin: CGPoint = .zero
    @State private var momentStarted = false
    private var moment: ResultMoment? { playerReady ? session.result?.moment : nil }

    static let milestoneWords: [Int: String] = [
        3: "Three days. It's a habit now.", 7: "A whole week, lantern lit.", 14: "Two weeks. Unstoppable.",
        30: "A month. Seriously impressive.", 50: "Fifty days of Chinese.", 100: "One hundred days.",
        200: "Two hundred days.", 365: "A full year. 太厉害了!",
    ]

    var body: some View {
        let r = session.result!
        // the stage fills the space above the buttons (the first keeps its parts together,
        // centred) and the buttons stay pinned at the foot
        VStack(spacing: 0) {
            Group {
                if !r.simple.isEmpty { simple(r) } else if splash && stage == 0 && moment == nil { splashView(r) } else {
                switch step(r) {
                case .result: stageOne(r)
                case .learned: LearnedStage(title: r.learned.isEmpty ? "YOU PRACTISED" : "YOU LEARNED", cards: r.learned.isEmpty ? r.practised : r.learned)
                case .streak: streakStage(r)
                case .pocket: PocketCard(pocket: r.pocket!, opened: { DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { withAnimation { held = false } } }, close: { advance(r) }, button: false)
                        .frame(maxHeight: .infinity)
                case .quests: QuestStage(before: r.questsBefore)
                }
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            .id(stage)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            buttons(r).padding(.top, 12)
                .opacity(splash && r.simple.isEmpty && stage == 0 && moment == nil || held ? 0 : 1)
                .allowsHitTesting(!held)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 18)
        .padding(.top, 8).padding(.bottom, 8)
        // the moment's sticker plays over the whole screen (it can fly in from off it), lined up with
        // its place on the first stage
        .overlay {
            if let m = moment, stage == 0 {
                MomentStage()
                    .background(GeometryReader { g in Color.clear.preference(key: MomentStageOrigin.self, value: g.frame(in: .global).origin) })
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .onPreferenceChange(MomentStageOrigin.self) { stageOrigin = $0; place(m) }
            }
        }
        .onPreferenceChange(MomentStickerBox.self) { stickerBox = $0; if let m = moment { place(m) } }
        // the player finished loading while the opening splash is still up: the moment takes over
        .onReceive(NotificationCenter.default.publisher(for: MomentPlayer.readyNote)) { _ in
            if stage == 0 && !momentStarted && splash { playerReady = true }
        }
        .sensoryFeedback(.success, trigger: stage) { _, n in n == 1 }
        .onAppear {
            guard splash else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.6 : 1.35)) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { splash = false }
            }
        }
    }

    /// Starts the moment once its sticker's place is known, and keeps it lined up after.
    private func place(_ m: ResultMoment) {
        guard stickerBox.width > 20, stickerBox.height > 20 else { return }
        let side = min(stickerBox.width, stickerBox.height)
        // (the web view's real place in the window: the stage's measured origin was off by the card's margin)
        let o = MomentPlayer.shared.origin ?? stageOrigin
        let box = CGRect(x: stickerBox.midX - side / 2 - o.x, y: stickerBox.midY - side / 2 - o.y, width: side, height: side)
        if momentStarted { MomentPlayer.shared.move(to: box) } else {
            momentStarted = true; MomentPlayer.shared.play(m.key, in: box)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { place(m) }
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
        return VStack(spacing: 0) {
            // Bùbù takes whatever height is spare, so the card is filled from the top rather than
            // centred with empty room above (the owner, 4 Oct 2026)
            if let m = moment {
                // the moment's sticker (drawn by the player over this space), its title and line
                Color.clear
                    .frame(minHeight: 120, maxHeight: 360)
                    .frame(maxWidth: .infinity)
                    .background(GeometryReader { g in Color.clear.preference(key: MomentStickerBox.self, value: g.frame(in: .global)) })
                    .layoutPriority(-1)
                Text(m.title).font(.nunito(28, .black)).tracking(-0.4).foregroundStyle(Color(UIColor(hex: m.color)))
                    .multilineTextAlignment(.center).padding(.top, 2)
                Text(m.line).font(.nunito(15, .bold)).foregroundStyle(Color.ink).multilineTextAlignment(.center)
                    .padding(.top, 2)
            } else {
                Image("done-panda").resizable().scaledToFit()
                    .frame(minHeight: 120, maxHeight: 360)
                    .layoutPriority(-1)
                Text(r.title).font(.nunito(28, .black)).tracking(-0.4).foregroundStyle(Color.gold).multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
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
            .padding(.top, 22).padding(.bottom, 4)
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

    // MARK: the streak

    private func streakStage(_ r: StudySession.Result) -> some View {
        VStack(spacing: 0) {
            StreakStage(streak: progress.streak, milestone: r.fire?.milestone == true) {
                withAnimation(.easeOut(duration: 0.3)) { held = false }
                if r.fire?.milestone == true { Sounds.shared.play("milestone") }
            }
            // what the day earned: a spare lantern, a milestone's coins
            HStack(spacing: 8) {
                if r.fire?.ember == true {
                    Label { Text("A spare lantern") } icon: { LanternMark(size: 15) }
                        .padding(.horizontal, 12).padding(.vertical, 6).background(Color.accentSoft, in: Capsule())
                }
                if let c = r.fire?.coins, c > 0 {
                    Label { Text("+\(c) coins").monospacedDigit() } icon: { CoinIcon(size: 16) }
                        .padding(.horizontal, 12).padding(.vertical, 6).background(Color.accentSoft, in: Capsule())
                }
            }
            .font(.nunito(14, .bold)).foregroundStyle(Color.gold)
            .padding(.bottom, 8)
        }
    }

    // MARK: buttons

    @ViewBuilder
    private func buttons(_ r: StudySession.Result) -> some View {
        VStack(spacing: 8) {
            if !r.simple.isEmpty {
                Button("← Back to path") { close() }.buttonStyle(WideButton())
            } else if !isLast(r) {
                Button(step(r) == .streak ? "Keep it up" : "Continue") { advance(r) }
                    .buttonStyle(WideButton())
            } else {
                // one button, as Duolingo's: back to the path (or home), where the next stone waits
                Button("Continue") { close() }
                    .buttonStyle(WideButton())
            }
        }
        .frame(maxWidth: 360)
    }
}

/// The full-width button: raised like the answer tiles (accent, or white with a grey lip for a
/// ghost), the accent one with a sweep of light now and then.
struct WideButton: ButtonStyle {
    var ghost = false
    func makeBody(configuration: Configuration) -> some View {
        RaisedButton(fill: ghost ? Color.panel : Color.accent, ink: ghost ? Color.ink : Color.onAccent,
                     edge: ghost ? Color.line : nil, sweep: !ghost).makeBody(configuration: configuration)
    }
}

/// A big button with a lip under it, as the answer tiles: it presses down onto the lip.
struct RaisedButton: ButtonStyle {
    var fill: Color
    var ink: Color
    /// the lip's colour (nil: the fill, darkened)
    var edge: Color? = nil
    var sweep = true
    var radius: CGFloat = 16
    var lip: CGFloat = 5
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        configuration.label
            // capitals, spaced a little, as Duolingo's buttons
            .font(.nunito(17, .black)).textCase(.uppercase).tracking(0.9).lineLimit(1).minimumScaleFactor(0.8)
            .foregroundStyle(ink)
            .frame(maxWidth: .infinity).padding(15)
            .background(fill, in: shape)
            .overlay { if let edge { shape.strokeBorder(edge, lineWidth: 2) } }
            .modifier(IdleSweep(on: sweep, radius: radius))
            .offset(y: configuration.isPressed ? max(0, lip - 1) : 0)
            .padding(.bottom, lip)
            .background {
                ZStack {
                    shape.fill(edge ?? fill)
                    if edge == nil { shape.fill(Color.black.opacity(0.22)) }
                }
                .padding(.top, lip)
            }
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed)
    }
}

/// Now and then a band of light sweeps across (a button inviting a tap).
struct IdleSweep: ViewModifier {
    var on = true
    var radius: CGFloat = 16
    func body(content: Content) -> some View {
        content.overlay {
            if on {
                GeometryReader { g in
                    LinearGradient(colors: [.white.opacity(0), .white.opacity(0.32), .white.opacity(0)], startPoint: .leading, endPoint: .trailing)
                        .frame(width: max(40, g.size.width * 0.3), height: g.size.height * 2)
                        .rotationEffect(.degrees(20))
                        .position(x: 0, y: g.size.height / 2)
                        .keyframeAnimator(initialValue: -0.4, repeating: true) { v, x in
                            v.offset(x: x * g.size.width)
                        } keyframes: { _ in
                            KeyframeTrack {
                                LinearKeyframe(-0.4, duration: 3.6)
                                CubicKeyframe(1.4, duration: 0.85)
                            }
                        }
                }
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .allowsHitTesting(false)
            }
        }
    }
}

/// The streak's lantern: lit once the day's session is done, unlit (brown paper) until then.
struct FlameIcon: View {
    var lit: Bool
    var size: CGFloat
    var body: some View {
        Image(lit ? "lantern-lit" : "lantern-unlit").resizable().scaledToFit()
            .frame(width: size, height: size)
    }
}

/// A small lantern for labels and rows: lit for the streak, unlit for a spare lantern.
struct LanternMark: View {
    var lit = false
    var size: CGFloat = 15
    var body: some View {
        Image(lit ? "licon-lit" : "licon-unlit").resizable().scaledToFit().frame(width: size, height: size)
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
    @State private var words = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.accent.opacity(0.35), Color.accent.opacity(0.75)], startPoint: .leading, endPoint: .trailing)
                .frame(height: 230)
                .rotationEffect(.degrees(-9))
                .scaleEffect(x: band ? 1.4 : 0.01, y: 1, anchor: .leading)
                .offset(y: -40)
            VStack(spacing: 18) {
                BubuRig(act: .double, then: .idle, height: 240)
                Text(title).font(.nunito(32, .black)).foregroundStyle(Color.gold).multilineTextAlignment(.center)
                    .scaleEffect(words ? 1 : 0.6).opacity(words ? 1 : 0)
            }
            Confetti(count: 40).allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .onAppear {
            withAnimation(.easeOut(duration: 0.25)) { band = true }
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

/// The done screen's moment: where its sticker sits, and where the player's layer starts (both global).
struct MomentStickerBox: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { let n = nextValue(); if n != .zero { value = n } }
}
struct MomentStageOrigin: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) { value = nextValue() }
}
