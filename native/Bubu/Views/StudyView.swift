import SwiftUI

/// A Study session, laid out as the web's study screen on a phone: a top bar, then
/// one card filling the screen with the progress bar, the prompt, the exercise and,
/// pinned at its foot, a reserved slot for the feedback and the Continue button, so
/// answering never moves anything.
struct StudyView: View {
    @State var session: StudySession
    var close: () -> Void
    /// what's been typed, in a typing exercise
    @State private var typed = ""
    /// the parts picked, in a build-the-character exercise
    @State private var built: Set<String> = []
    /// "Wait, don't go!": the close button asks first once something's been answered
    @State private var quitAsk = false
    @Environment(ProgressStore.self) private var progress

    // the current exercise's state
    /// multiple choice: the option selected, which only counts once Check is pressed
    @State private var pick = ChoicePick()
    /// "Can't listen now" was tapped on this exercise: it shows no answer
    @State private var skipped = false
    @State private var placed: [Exercise.Tile] = []
    @State private var feedback: Feedback?
    @State private var exerciseKey = UUID()
    // a bun eaten: the bitten one flies from the middle into the bun row
    @State private var munch: Int?
    @State private var bunRowFrame: CGRect = .zero
    // the stone's notes, shown once as a tip before it starts
    @State private var tips: [Note] = []
    // the tones' one-time intro, before the first session that asks about them
    @State private var tonesIntro = false
    /// Something shown before the session starts: the tones' intro or a tip.
    private var preStart: Bool { tonesIntro || !tips.isEmpty }
    /// the learner's records as this exercise appeared, so answering it doesn't change which
    /// pinyin shows until the next one
    @State private var srsAtStart: [String: SRSRecord]?
    /// pinyin training wheels for this exercise
    private var wheels: Wheels { Wheels.now(progress, srs: srsAtStart) }

    struct Feedback { let correct: Bool; let chosen: String? }

    /// the study card's height, to tell a phone where a multiple-choice exercise fits
    @State private var cardHeight: CGFloat = 0
    /// A multiple-choice exercise stays still (no scrolling); the feedback slides up over its foot.
    /// On a small phone (an SE) it scrolls instead.
    private var fixed: Bool {
        guard session.exercise?.kind == .choice, !preStart, case .card = session.current else { return false }
        return cardHeight >= 620
    }

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()
            if session.result != nil {
                DoneView(session: session, close: close, again: { restart(session.again()) },
                         next: { id in if let s = StudySession.lesson(id, progress, review: reviewHere) { restart(s) } })
                    .padding(.horizontal, 18)
                    .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    topBar
                    VStack(spacing: 0) {
                        ScrollViewReader { reader in
                            ScrollView(fixed ? [] : .vertical) {
                                content.padding(.horizontal, 12).padding(.top, 15).padding(.bottom, 12)
                                Color.clear.frame(height: 1).id("exercise-end")
                            }
                            .scrollIndicators(.hidden)
                            .scrollBounceBehavior(.basedOnSize)
                            // the feedback takes room from the exercise: keep the answers in view
                            .onChange(of: feedback != nil) { _, shown in
                                guard shown, !fixed else { return }
                                // once the feedback has taken its room (it springs in), not before:
                                // until then there's nothing to scroll
                                for delay in [0.35, 0.7] {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                        guard feedback != nil else { return }
                                        withAnimation(.easeOut(duration: 0.25)) { reader.scrollTo("exercise-end", anchor: .bottom) }
                                    }
                                }
                            }
                        }
                        if !preStart, case .card = session.current { bottomSlot }
                    }
                    .frame(maxHeight: .infinity)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { cardHeight = $0 }
                    .background(Color.panel, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Color.line, lineWidth: 1))
                    .padding(.horizontal, 18)
                }
            }
            if let m = munch {
                GeometryReader { g in
                    Munch(from: CGPoint(x: g.size.width / 2, y: g.size.height * 0.42),
                          to: CGPoint(x: bunRowFrame.maxX - 14, y: bunRowFrame.midY))
                }
                .id(m)
                .allowsHitTesting(false)
            }
            if quitAsk && session.result == nil {
                QuitAsk(keep: { withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { quitAsk = false } },
                        quit: { quitAsk = false; close() })
                    .transition(.opacity)
                    .zIndex(20)
            }
        }
        .coordinateSpace(.named("study"))
        .animation(.easeInOut(duration: 0.25), value: session.result != nil)
        .onChange(of: session.bunsEaten) { _, n in
            guard n > 0 else { return }
            munch = n
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) { if munch == n { munch = nil } }
        }
        .onAppear {
            loadTips()
            srsAtStart = progress.srs
            if !preStart { playPrompt() }
            #if DEBUG
            // the buns screenshot: out of buns part-way through a lesson
            if Launch.screen == "buns" { DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { advance() } }
            #endif
        }
        .sensoryFeedback(trigger: feedback?.correct) { _, new in
            guard let new else { return nil }
            return new ? .success : .error
        }
        .sensoryFeedback(trigger: pick.selected) { _, new in
            new == nil ? nil : .selection
        }
    }

    private func restart(_ s: StudySession) {
        session = s
        munch = nil
        loadTips()
        resetExercise()
    }

    /// The stone's notes not yet seen, as a tip before it starts (not over the screenshots,
    /// apart from the tip's own).
    private func loadTips() {
        #if DEBUG
        if let sc = Launch.screen, sc != "tip" { tips = []; tonesIntro = false; return }
        #endif
        tips = session.tips
        tonesIntro = session.showsTonesIntro
    }

    private func dismissTonesIntro() {
        Coach.markTonesSeen()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            tonesIntro = false
            if tips.isEmpty { exerciseKey = UUID() }
        }
        if !preStart { playPrompt() }
    }

    private func dismissTip() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            tips.removeFirst()
            if tips.isEmpty {
                Coach.markTipSeen(session.lessonId)
                exerciseKey = UUID()
            }
        }
        if !preStart { playPrompt() }
    }

    /// Review in place of this session, from the buns sheet.
    private func reviewHere() {
        if let s = StudySession.review(progress) { restart(s) } else { close() }
    }

    private func resetExercise() {
        pick = ChoicePick(); skipped = false; placed = []; typed = ""; built = []; feedback = nil; exerciseKey = UUID()
        srsAtStart = progress.srs
        if session.exercise != nil {
            let key = exerciseKey
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { if exerciseKey == key && !preStart { playPrompt() } }
        }
    }

    /// The exercise's Chinese, said once as it appears, where hearing it doesn't give the
    /// answer away (see Autoplay.onShow).
    private func playPrompt() {
        guard let ex = session.exercise, !session.answered else { return }
        Speech.shared.autoSpeak(Autoplay.onShow(ex, autoplay: progress.prefs.playsAutomatically),
                                always: ex.dir == "listen" || ex.hearOnly)
    }

    /// The right Chinese, said once as the feedback comes up (after the right/wrong chime).
    private func playAnswer(_ ex: Exercise) {
        guard let text = Autoplay.onAnswer(ex, autoplay: progress.prefs.playsAutomatically) else { return }
        let key = exerciseKey
        // not if it's the last thing that was said (the option just tapped said it): the chime is enough
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            if exerciseKey == key { Speech.shared.autoSpeak(text, within: .infinity) }
        }
    }

    // MARK: chrome

    /// The top of a session, as Duolingo has it: close, the progress bar and the buns
    /// in one row; the session's name, the combo and double XP in a slim row under it.
    private var topBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Button {
                    if session.nothingAnswered { close() } else { withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { quitAsk = true } }
                } label: {
                    Image(systemName: "xmark").font(.system(size: 17, weight: .bold)).foregroundStyle(Color.muted)
                        .frame(width: 34, height: 34).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
                ProgressBarShine(value: session.progressFraction, height: 8)
                // buns in a lesson, and in a review while they're being earned back
                if session.onBuns || (session.earnsBuns && progress.buns < ProgressStore.bunsMax) {
                    BunRow(n: progress.isPlus ? ProgressStore.bunsMax : progress.bunState.n, plus: progress.isPlus, bump: session.bunsEarned)
                        .background(GeometryReader { g in
                            Color.clear
                                .onAppear { bunRowFrame = g.frame(in: .named("study")) }
                                .onChange(of: g.frame(in: .named("study"))) { _, f in bunRowFrame = f }
                        })
                }
            }
            HStack(spacing: 8) {
                // a quiz's name is the screen's title ("Quiz · 20 questions"); else a small label
                if session.isQuiz {
                    Text(session.title).font(.nunitoXB(15)).foregroundStyle(Color.ink).lineLimit(1)
                } else {
                    Text(session.title).font(.nunito(13, .bold)).foregroundStyle(Color.muted)
                }
                Spacer()
                if session.combo >= 3 {
                    let hot = session.combo >= 5
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill").font(.system(size: 11))
                        Text("\(session.combo)").font(.nunitoXB(12))
                    }
                    .foregroundStyle(hot ? Color.white : Color.again)
                    .padding(.leading, 6).padding(.trailing, 8).padding(.vertical, 2)
                    .background(hot ? Color.again : Color.againSoft, in: Capsule())
                    .transition(.scale.combined(with: .opacity))
                }
                if progress.boostActive {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        let left = max(0, Int((progress.boostUntil - progress.now()) / 1000))
                        (Text("2×").font(.nunito(12, .black)) + Text(" XP · \(left / 60):\(String(format: "%02d", left % 60))").font(.nunito(12, .bold)))
                            .monospacedDigit()
                            .foregroundStyle(Color.gold)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Color.accentSoft, in: Capsule())
                    }
                }
            }
            .padding(.leading, 46)
            .frame(height: session.isQuiz ? 22 : 20)
        }
        .padding(.leading, 10).padding(.trailing, 18).padding(.top, 2).padding(.bottom, 10)
        .animation(.spring(response: 0.3), value: session.combo)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            // a word missed earlier this session, back in the end-of-lesson mistakes stretch
            if session.previousMistake { PreviousMistakeTag() }
            Text(promptLabel).font(.nunitoXB(19.2)).tracking(-0.2).foregroundStyle(Color.ink)
                .padding(.top, 4).padding(.bottom, 14)
            Group {
                if tonesIntro {
                    TonesIntroCard { dismissTonesIntro() }
                } else if let tip = tips.first {
                    TipCard(note: tip, more: tips.count - 1) { dismissTip() }
                } else {
                switch session.current {
                case .meet(let cards, _, _):
                    MeetView(cards: cards) { advance() }
                case .match(let cards, _):
                    MatchView(session: session, cards: cards, audio: session.matchAudio) { advance() }
                case .card:
                    if let ex = session.exercise {
                        if ex.kind == .sentence {
                            SentenceView(ex: ex, placed: $placed, result: feedback?.correct, wheels: wheels,
                                         skipped: skipped, skip: { cantListen() })
                        } else if ex.kind == .build {
                            BuildView(ex: ex, picked: $built, result: feedback?.correct)
                        } else if ex.kind == .type {
                            TypeView(ex: ex, typed: $typed, result: feedback?.correct) { if !session.answered { checkType() } }
                        } else if ex.kind == .write {
                            WriteView(ex: ex, answered: session.answered) { settle(true) }
                        } else if ex.kind == .speak {
                            SpeakView(ex: ex, answered: session.answered,
                                      settle: { correct in settle(correct) },
                                      skip: { session.skip() })
                        } else {
                            ChoiceView(ex: ex, picked: pick.selected, answered: session.answered, wheels: wheels,
                                       skipped: skipped, skip: { cantListen() }) { select($0) }
                        }
                    }
                case nil:
                    EmptyView()
                }
                }
            }
            .id(exerciseKey)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: exerciseKey)
    }

    private var promptLabel: String {
        if tonesIntro { return "Meet the tones" }
        if !tips.isEmpty { return "Before you start" }
        if case .meet = session.current { return "New word" }
        if case .match = session.current { return session.matchAudio ? "Match what you hear" : "Tap the pairs" }
        return session.exercise?.label ?? ""
    }

    /// The reserved slot at the card's foot. Multiple choice keeps 216 points from the
    /// start with the feedback above the button; the sentence builder keeps 84 and its
    /// feedback rises over the word bank. The one button is Check until the exercise is
    /// answered (multiple choice: once an option is selected; a sentence: once a tile is
    /// placed), then Continue, so it never moves.
    private var bottomSlot: some View {
        let ex = session.exercise
        let isSentence = ex?.kind == .sentence
        let isChoice = ex?.kind == .choice
        let isType = ex?.kind == .type
        let isBuild = ex?.kind == .build
        let checks = (isSentence || isChoice || isType || isBuild) && !session.answered
        let ready = session.answered || (isSentence && !placed.isEmpty) || (isChoice && pick.canCheck)
            || (isType && !typed.trimmingCharacters(in: .whitespaces).isEmpty)
            || (isBuild && built.count == (ex?.answer.components(separatedBy: "|").count ?? 0))
        let fill = !ready ? Color.accent.opacity(0.38) : feedback.map { $0.correct ? Color.good : Color.again } ?? Color.accent
        let ink = !ready ? Color.onAccent.opacity(0.7) : feedback.map { $0.correct ? Color.onAccent : Color.white } ?? Color.onAccent
        return ZStack(alignment: .bottom) {
            // a short slot, so the exercise keeps its room; the feedback slides up over its foot
            // as an overlay, taking no room (the owner's choice: nothing moves or shrinks)
            Color.clear.frame(height: 84)
                .overlay(alignment: .bottom) {
                    if let fb = feedback, let ex, ex.kind != .speak, ex.kind != .write {
                        FeedbackBanner(ex: ex, correct: fb.correct, chosen: fb.chosen, placed: placed.map(\.text), wheels: wheels,
                                       inARow: fb.correct && session.combo >= StudySession.comboAt && session.combo % StudySession.comboAt == 0 ? session.combo : nil)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.panel)
                                .shadow(color: Color.panel, radius: 12, y: -10))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.bottom, 79)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            Button {
                if !checks { advance() } else if isSentence { checkSentence() } else if isType { checkType() } else if isBuild { checkBuild() } else { checkChoice() }
            } label: {
                Text(checks ? "Check" : session.isQuiz ? "Next →" : "Continue")
                    .font(.nunitoXB(16.8)).foregroundStyle(ink)
                    .frame(maxWidth: .infinity).padding(15)
                    .background(fill, in: Capsule())
            }
            .buttonStyle(PressDown(depth: 1))
            .disabled(!ready)
            .padding(.bottom, 14)
        }
        .padding(.horizontal, 12)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: feedback != nil)
    }

    // MARK: answering

    /// An option tapped: it's selected, not answered (another tap moves the selection). A
    /// Chinese option is said as it's selected, where that doesn't give the answer away.
    private func select(_ option: String) {
        guard let ex = session.exercise, pick.select(option, in: ex, answered: session.answered) else { return }
        if let say = TapToHear.option(option, in: ex, answered: session.answered, allowed: TapToHear.allowed(progress.prefs)) {
            Speech.shared.speak(say)
        }
    }

    /// Check: the option selected is the answer.
    private func checkChoice() {
        guard !session.answered, let ex = session.exercise, let correct = pick.verdict(ex) else { return }
        session.answer(correct)
        Sounds.shared.play(correct ? "correct" : "wrong")
        withAnimation { feedback = Feedback(correct: correct, chosen: pick.selected) }
        playAnswer(ex)
    }

    /// "Can't listen now": the exercise is skipped with no penalty, and there's no more
    /// listening this session (see StudySession.skip).
    private func cantListen() {
        guard !session.answered, ["listen", "hear"].contains(session.exercise?.dir ?? "") else { return }
        Speech.shared.stop()
        session.skip()
        pick = ChoicePick(); placed = []
        withAnimation { skipped = true }
    }

    private func checkBuild() {
        guard let ex = session.exercise, !session.answered else { return }
        let correct = ex.builds(built)
        session.answer(correct)
        Sounds.shared.play(correct ? "correct" : "wrong")
        withAnimation { feedback = Feedback(correct: correct, chosen: built.sorted().joined(separator: " + ")) }
        playAnswer(ex)
    }

    private func checkType() {
        guard let ex = session.exercise, !session.answered else { return }
        let correct = Exercise.typedMatches(typed, pinyin: ex.answer)
        session.answer(correct)
        Sounds.shared.play(correct ? "correct" : "wrong")
        withAnimation { feedback = Feedback(correct: correct, chosen: typed) }
        playAnswer(ex)
    }

    private func checkSentence() {
        guard let ex = session.exercise, !session.answered else { return }
        let correct = ex.check(placed)
        session.answer(correct)
        Sounds.shared.play(correct ? "correct" : "wrong")
        withAnimation { feedback = Feedback(correct: correct, chosen: nil) }
        playAnswer(ex)
    }

    /// A spoken answer, marked by what was heard.
    private func settle(_ correct: Bool) {
        guard !session.answered else { return }
        session.answer(correct)
        Sounds.shared.play(correct ? "correct" : "wrong")
        withAnimation { feedback = Feedback(correct: correct, chosen: nil) }
    }

    private func advance() {
        // "Can't listen now" before anything was answered, in a session of only listening:
        // there's nothing to show for it, so it just closes
        if session.answered && !session.hasMore && session.nothingAnswered {
            Moments.shared.toast("No listening for now — come back when you can listen.")
            close()
            return
        }
        // out of buns part-way through a lesson: more buns, a review, or the end
        if session.onBuns && progress.buns < 1 && session.hasMore {
            Moments.shared.show(.buns(.init(ctx: .mid, review: reviewHere, refilled: { advance() }, end: close)))
            return
        }
        // nothing said for the last exercise runs on into the next (the owner: it "bleeds into the
        // next question that speaks")
        Speech.shared.stop()
        withAnimation {
            session.next()
            resetExercise()
        }
        if let r = session.result, !r.goalReached { Sounds.shared.play("complete") }
    }
}

// MARK: - previous mistake

/// The small label over an exercise on a word missed earlier in the session.
struct PreviousMistakeTag: View {
    var body: some View {
        Label("Previous mistake", systemImage: "arrow.counterclockwise")
            .font(.nunito(12.5, .bold)).foregroundStyle(Color.again)
            .padding(.top, 2)
    }
}

// MARK: - the progress bar

struct ProgressBarShine: View {
    var value: Double
    var height: CGFloat = 6
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.line)
                Capsule().fill(Color.accent)
                    .frame(width: max(0, g.size.width * value))
                    .overlay(alignment: .top) {
                        Capsule().fill(.white.opacity(0.25)).frame(height: 2).padding(.horizontal, 4).padding(.top, 1)
                    }
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.3), value: value)
    }
}

// MARK: - mascot and speech bubble

struct MascotPrompt<Content: View>: View {
    var mood: Bool?          // nil: asking; true: pleased; false: sad
    var sentence = false
    var long = false         // a long sentence: a smaller Bùbù, so the bubble gets the width
    /// answered: Bùbù and the bubble shrink, so the answers and the feedback fit without scrolling
    var compact = false
    @ViewBuilder var content: Content
    @State private var pop = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(mood == nil ? "panda-teacher" : mood! ? "panda-celebrate" : "panda-sad")
                .resizable().scaledToFit()
                .frame(width: long || compact ? 64 : 122, height: long || compact ? 78 : 148, alignment: .bottom)
                .shadow(color: .black.opacity(0.15), radius: 4, y: 3)
                .scaleEffect(pop ? 1.14 : 1)
            SpeechBubbleBox(sentence: sentence) { content }
                .frame(maxWidth: sentence ? .infinity : 200)
                .padding(.trailing, sentence ? 0 : 10)
            Spacer(minLength: 0)
        }
        .frame(minHeight: long || compact ? 78 : 140)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: compact)
        .onChange(of: mood) { _, new in
            guard new != nil else { return }
            withAnimation(.easeOut(duration: 0.17)) { pop = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.17) { withAnimation(.easeIn(duration: 0.17)) { pop = false } }
        }
    }
}

/// The white bubble with a tail on its left, pointing at Bùbù.
struct SpeechBubbleBox<Content: View>: View {
    var sentence = false
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 6) { content }
            .padding(.leading, sentence ? 10 : 13).padding(.trailing, sentence ? 14 : 13).padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            // the outline and tail behind the words, so a word's hint bubble is drawn over them
            // (the outline ran through the hint: the Mac's check of 0.1.30)
            .background(alignment: .leading) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color.panel)
                    RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(Color.line, lineWidth: 2)
                    tail
                }
            }
    }

    private var tail: some View {
        Color.clear.frame(width: 0)
            .overlay(alignment: .leading) {
                Rectangle().fill(Color.panel).frame(width: 14, height: 14)
                    .overlay(alignment: .bottomLeading) {
                        Path { p in p.move(to: .init(x: 0, y: 0)); p.addLine(to: .init(x: 0, y: 14)); p.addLine(to: .init(x: 14, y: 14)) }
                            .stroke(Color.line, lineWidth: 2)
                    }
                    .rotationEffect(.degrees(45))
                    .offset(x: -8)
            }
    }
}

struct SpeakerButton: View {
    let text: String
    var size: CGFloat = 20
    /// a 🐢 beside it, playing the same at about 0.6× (Speech.slowFactor): in the exercises
    var withSlow = false
    var body: some View {
        HStack(spacing: 2) {
            Button { Speech.shared.speak(text) } label: {
                Image(systemName: "speaker.wave.2").font(.system(size: size, weight: .medium)).foregroundStyle(Color.accent)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play")
            if withSlow {
                Button { Speech.shared.speak(text, slow: true) } label: {
                    Image(systemName: "tortoise").font(.system(size: size * 0.9, weight: .medium)).foregroundStyle(Color.accent)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Play slowly")
            }
        }
    }
}

/// The sound of what's in a bubble, at its left as Duolingo has it: the speaker, and the
/// tortoise under it for slowly.
struct BubbleSound: View {
    let text: String
    var body: some View {
        VStack(spacing: 2) {
            Button { Speech.shared.speak(text) } label: {
                Image(systemName: "speaker.wave.2.fill").font(.system(size: 19, weight: .medium)).foregroundStyle(Color.accent)
                    .frame(width: 34, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play")
            Button { Speech.shared.speak(text, slow: true) } label: {
                Image(systemName: "tortoise.fill").font(.system(size: 14, weight: .medium)).foregroundStyle(Color.accent.opacity(0.8))
                    .frame(width: 34, height: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play slowly")
        }
    }
}

/// A listening exercise's sound, as Duolingo has it: a big speaker button and a smaller
/// tortoise button beside it.
struct ListenButtons: View {
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            Button { Speech.shared.speak(text) } label: {
                Image(systemName: "speaker.wave.2.fill").font(.system(size: 30, weight: .semibold)).foregroundStyle(Color.onAccent)
                    .frame(width: 74, height: 64)
                    .background(Color.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(PressDown(depth: 1))
            .accessibilityLabel("Play")
            Button { Speech.shared.speak(text, slow: true) } label: {
                Image(systemName: "tortoise.fill").font(.system(size: 20, weight: .semibold)).foregroundStyle(Color.onAccent)
                    .frame(width: 52, height: 46)
                    .background(Color.accent.opacity(0.75), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(PressDown(depth: 1))
            .accessibilityLabel("Play slowly")
        }
        .padding(.vertical, 4)
    }
}

struct NewBadge: View {
    var body: some View {
        Text("NEW WORD").font(.nunito(10.2, .black)).tracking(1.0)
            .foregroundStyle(Color.tiles["purple"]!.ink)
            .padding(.horizontal, 10).padding(.vertical, 3)
            .background(Color.tiles["purple"]!.bg, in: Capsule())
    }
}

extension Color {
    static let newInk = Color.tiles["purple"]!.ink
    static let newBg = Color.tiles["purple"]!.bg
}

// MARK: - meet a new word

/// One new word, as Duolingo shows it: big characters, the pinyin, a short meaning and its
/// sound (played once on arrival), then straight on to an easy exercise on it. How the
/// characters are built is a tap away, not on the card.
struct MeetView: View {
    let cards: [Card]
    var done: () -> Void
    @State private var built = false
    @State private var played = false

    var body: some View {
        let c = cards[0]
        let w = c.word
        let parts = partLines(w.hanzi)
        VStack(spacing: 10) {
            VStack(spacing: 8) {
                NewBadge()
                TappableHanzi(text: w.hanzi, pinyin: w.pinyin, size: w.hanzi.count > 3 ? 44 : 64, weight: .bold)
                    .padding(.top, 6)
                PinyinText(pinyin: w.pinyin, size: 24, weight: .semibold)
                Text(w.gloss).font(.nunitoXB(21)).foregroundStyle(Color.ink).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                // one line to remember it by (see MemoryHook); the full breakdown is below
                if let hook = MemoryHook.line(for: c) {
                    Label { Text(hook) } icon: { Image(systemName: "lightbulb.fill").foregroundStyle(Color.gold) }
                        .font(.nunito(14.5, .semibold)).foregroundStyle(Color.muted)
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                SpeakerButton(text: w.hanzi, size: 28).padding(.top, 2)
                if !parts.isEmpty {
                    Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { built.toggle() } } label: {
                        Label(built ? "Hide how it's built" : "How it's built", systemImage: built ? "chevron.up" : "square.split.2x2")
                            .font(.nunito(13.5, .bold)).foregroundStyle(Color.accent)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .overlay(Capsule().strokeBorder(Color.line, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                    if built {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(parts, id: \.self) { line in Text(line).font(.nunito(14)).foregroundStyle(Color.muted) }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 20)
            .frame(maxWidth: 440)
            .background(Color.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.line, lineWidth: 1.5))
            Button(action: done) {
                Text("Continue").font(.nunitoXB(16.8)).foregroundStyle(Color.onAccent)
                    .frame(maxWidth: .infinity).padding(14)
                    .background(Color.accent, in: Capsule())
            }
            .buttonStyle(PressDown(depth: 3))
            .background(Color.accentDark, in: Capsule().offset(y: 3))
            .padding(.top, 18)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            guard !played else { return }
            played = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { Speech.shared.speak(w.hanzi) }
        }
    }

    /// "好 = 女 woman + 子 child", sound parts showing their pinyin.
    private func partLines(_ hanzi: String) -> [AttributedString] {
        let cd = CharData.shared
        var seen = Set<String>()
        return hanzi.filter(Course.isHan).map(String.init)
            .filter { (cd.chars[$0]?.c?.count ?? 0) > 1 && seen.insert($0).inserted }
            .prefix(3)
            .map { ch in
                var s = AttributedString(ch)
                s.foregroundColor = Color.ink; s.font = Font.nunitoXB(14)
                s += AttributedString(" = ")
                for (i, part) in (cd.chars[ch]?.c ?? []).enumerated() {
                    guard let comp = part.first else { continue }
                    let sound = part.count > 1 && part[1] == "s"
                    if i > 0 { s += AttributedString(" + ") }
                    var c = AttributedString(comp)
                    c.foregroundColor = sound ? Color.gold : Color.accent; c.font = Font.nunitoXB(14)
                    s += c
                    let names = cd.partNames[comp] ?? (cd.chars[comp].map { [$0.d ?? "", $0.p ?? ""] })
                    if let names, names.count > 1 {
                        let label = sound ? names[1] : names[0]
                        if !label.isEmpty { s += AttributedString(" " + label) }
                    }
                }
                return s
            }
    }
}

/// A stone's note, shown once as a short tip before the stone starts.
struct TipCard: View {
    let note: Note
    let more: Int
    var done: () -> Void
    var body: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Label { Text(note.title) } icon: { Image(systemName: "lightbulb.fill").foregroundStyle(Color.gold) }
                    .font(.nunitoXB(17)).foregroundStyle(Color.ink)
                Text(note.body).font(.nunito(15.5)).lineSpacing(4).foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text("You can read this again on the lesson sheet or in the Guide.")
                .font(.nunito(12.5)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
            Button(action: done) {
                Text(more > 0 ? "Next tip" : "Got it").font(.nunitoXB(16.8)).foregroundStyle(Color.onAccent)
                    .frame(maxWidth: .infinity).padding(14)
                    .background(Color.accent, in: Capsule())
            }
            .buttonStyle(PressDown(depth: 3))
            .background(Color.accentDark, in: Capsule().offset(y: 3))
            .padding(.top, 6)
        }
    }
}

/// The tones, introduced once before the first session that asks about them: the primer,
/// with its sounds to play, and a button to start.
struct TonesIntroCard: View {
    var done: () -> Void
    var body: some View {
        VStack(spacing: 14) {
            TonesPrimer()
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text("From here on, some exercises ask for the right tones. You can read this again in Settings.")
                .font(.nunito(12.5)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
            Button(action: done) {
                Text("Got it").font(.nunitoXB(16.8)).foregroundStyle(Color.onAccent)
                    .frame(maxWidth: .infinity).padding(14)
                    .background(Color.accent, in: Capsule())
            }
            .buttonStyle(PressDown(depth: 3))
            .background(Color.accentDark, in: Capsule().offset(y: 3))
            .padding(.top, 6)
        }
    }
}

/// Pinyin with each syllable in its tone colour.
struct PinyinText: View {
    let pinyin: String
    var size: CGFloat = 16
    var weight: Font.Weight = .semibold
    var body: some View {
        let words = pinyin.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        let tones = ProgressStore.current?.prefs.toneColours ?? true
        var t = Text("")
        for (i, w) in words.enumerated() {
            if i > 0 { t = t + Text(" ") }
            t = t + Text(w).foregroundColor(tones ? Color.tones[toneOf(w) - 1] : Color.gold)
        }
        return t.font(.nunito(size, weight))
    }
}

// MARK: - multiple choice

/// The pinyin under the prompt, or, with pinyin switched off, a button to reveal it.
struct PinyinHint: View {
    let pinyin: String
    let shown: Bool
    @State private var revealed = false
    var body: some View {
        if shown || revealed {
            PinyinText(pinyin: pinyin, size: 23.2)
        } else {
            Button { withAnimation { revealed = true } } label: {
                Label("Show pinyin", systemImage: "eye").font(.nunito(14, .bold)).foregroundStyle(Color.muted)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .overlay(Capsule().strokeBorder(Color.line, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
            }
            .buttonStyle(.plain)
        }
    }
}

struct ChoiceView: View {
    let ex: Exercise
    let picked: String?
    let answered: Bool
    /// pinyin training wheels: over the Chinese while the word is new, a tap away once it's strong
    var wheels = Wheels()
    /// "Can't listen now" was tapped: the exercise is over with no answer shown
    var skipped = false
    /// "Can't listen now", under a listening exercise (nil: no such button)
    var skip: (() -> Void)? = nil
    /// an option tapped: it's selected (`picked`); the answer comes with Check
    var choose: (String) -> Void
    @Environment(ProgressStore.self) private var progress
    private let course = Course.shared
    @State private var tonesOpen = false
    /// the prompt's pinyin, shown with a tap where it's hidden
    @State private var peek = false
    /// Pinyin over the tested word, and over every option (one rule for all four options, so
    /// which ones have pinyin never gives the answer away). Never where the pinyin is tested.
    private var pinyinShown: Bool {
        wheels.shows(card: ex.card, testing: TrainingWheels.testsPinyin(dir: ex.dir, answered: answered))
    }

    var body: some View {
        let w = ex.card.word
        let isNew = ex.isNew
        let big: CGFloat = w.hanzi.count > 3 ? 32 : 44
        VStack(spacing: 0) {
            MascotPrompt(mood: answered && !skipped ? (picked == ex.answer) : nil, sentence: ex.dir == "gap",
                         long: ex.dir == "gap" && (ex.sentence?.words.map(\.hanzi).joined().count ?? 0) > 9) {
                if isNew { NewBadge() }
                switch ex.dir {
                case "picture":
                    Text(w.gloss).font(.nunitoXB(19)).foregroundStyle(Color.ink).multilineTextAlignment(.center)
                case "gap":
                    if let sent = ex.sentence { gapPrompt(sent) }
                case "recall":
                    // the English can always be tapped for its characters and pinyin
                    HintChip(hanzi: w.hanzi, pinyin: w.pinyin, reverse: true) {
                        Text(w.gloss).font(.nunito(16.3)).foregroundStyle(isNew ? Color.newInk : Color.ink)
                            .multilineTextAlignment(.center)
                            .lineLimit(3).minimumScaleFactor(0.85).fixedSize(horizontal: false, vertical: true)
                            .overlay(alignment: .bottom) {
                                Line().stroke(Color.muted.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [1.5, 3]))
                                    .frame(height: 2).offset(y: 3)
                            }
                    }
                    SpeakerButton(text: w.hanzi, size: 15, withSlow: true)
                case "pinyin":
                    Text(w.hanzi).font(.hanzi(big, .medium)).foregroundStyle(isNew ? Color.newInk : Color.ink)
                    Text(w.gloss).font(.nunito(16)).foregroundStyle(Color.ink).multilineTextAlignment(.center)
                case "listen":
                    ListenButtons(text: w.hanzi)
                default:
                    // the word, the sound at its left (as Duolingo has it); its pinyin is under the bubble
                    HStack(alignment: .center, spacing: 8) {
                    BubbleSound(text: w.hanzi)
                    VStack(spacing: 2) {
                        if isNew {
                            HintChip(hanzi: w.hanzi, pinyin: w.pinyin, tapped: { reveal() }) {
                                Text(w.hanzi).font(.hanzi(big, .medium)).foregroundStyle(Color.newInk)
                                    .overlay(alignment: .bottom) { Line().stroke(Color.newInk, style: StrokeStyle(lineWidth: 2, dash: [2, 3])).frame(height: 2) }
                            }
                        } else {
                            Button { reveal() } label: {
                                ToneText(hanzi: w.hanzi, pinyin: w.pinyin, size: big, weight: .medium)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    }
                }
            }
            // the word's pinyin, big and tone-coloured under the bubble while it's new; once it's
            // strong its place stays, and a tap on the word (or the eye) shows it
            if !["recall", "pinyin", "listen", "gap", "picture"].contains(ex.dir) {
                ZStack {
                    PinyinText(pinyin: w.pinyin, size: 22).opacity(pinyinShown || peek ? 1 : 0)
                    if !(pinyinShown || peek) {
                        Button { reveal() } label: {
                            Image(systemName: "eye").font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.muted.opacity(0.7)).padding(4)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Show pinyin")
                    }
                }
                .frame(maxWidth: .infinity).padding(.top, 10)
            }
            if ex.dir == "pinyin" && Coach.showTonesLink {
                Button("What are tones?") { Coach.tonesLinkTapped(); tonesOpen = true }
                    .font(.nunito(14, .bold)).foregroundStyle(Color.accent).padding(.top, 8)
            }
            if ex.dir == "picture" {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(ex.options, id: \.self) { opt in pictureCard(opt) }
                }
                .padding(.top, 18)
            } else {
            VStack(spacing: 9) {
                ForEach(ex.options, id: \.self) { opt in option(opt) }
            }
            .padding(.top, 18)
            }
            if ex.dir == "listen", let skip {
                // its place is kept once the exercise is answered, so nothing moves
                ZStack {
                    if skipped {
                        Text("No problem — no more listening this session.")
                            .font(.nunito(14, .semibold)).foregroundStyle(Color.muted)
                            .multilineTextAlignment(.center)
                    } else {
                        Button("Can't listen now") { skip() }
                            .font(.nunito(14, .bold)).foregroundStyle(Color.muted)
                            .buttonStyle(.plain)
                            .opacity(answered ? 0 : 1)
                            .disabled(answered)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 20)
                .padding(.vertical, 8)
            }
        }
        .sheet(isPresented: $tonesOpen) {
            NavigationStack {
                ScrollView { TonesPrimer().padding(20) }
                    .navigationTitle("The four tones").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { tonesOpen = false } } }
            }
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            // the first pinyin drill ever opens the primer once
            if ex.dir == "pinyin" && !UserDefaults.standard.bool(forKey: "tonesSeen") {
                UserDefaults.standard.set(true, forKey: "tonesSeen")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { tonesOpen = true }
            }
        }
    }

    private func reveal() {
        withAnimation(.easeOut(duration: 0.15)) { peek = true }
    }

    /// One picture card: the picture, the word and (as the training wheels say) its pinyin.
    private func pictureCard(_ opt: String) -> some View {
        let isAnswer = opt == ex.answer
        let state: Bool? = !answered || skipped ? nil : isAnswer ? true : opt == picked ? false : nil
        let selected = !answered && opt == picked
        let edge: Color = state == true ? Color.good : state == false ? Color.again : selected ? Color.accent : Color.line
        let fill: Color = state == true ? Color.goodSoft : state == false ? Color.againSoft : selected ? Color.accentSoft : Color.panel
        return Button { choose(opt) } label: {
            VStack(spacing: 6) {
                Text(Pictures.of(opt) ?? "").font(.system(size: 48)).frame(height: 56)
                Text(opt).font(.hanzi(20, .bold)).foregroundStyle(Color.ink)
                PinyinText(pinyin: Course.wordPy[opt] ?? "", size: 13, weight: .bold).opacity(pinyinShown ? 1 : 0)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(edge, lineWidth: selected ? 3 : 2))
        }
        .buttonStyle(PressDown(depth: 2))
        .disabled(answered)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// The gap, as Duolingo draws it: a box you can't miss, dashed while empty, holding the
    /// option picked (blue) until Check, then the answer (green, or red for a wrong pick).
    private func gapSlot(_ answer: String, filled: Bool) -> some View {
        let shown = filled ? answer : picked
        let tint: Color = filled ? (picked == answer ? Color.good : Color.again) : Color.accent
        return Text(shown ?? "　")
            .font(.hanzi(24.8)).foregroundStyle(filled ? Color.good : Color.accent)
            .padding(.horizontal, 8).padding(.vertical, 2)
            .frame(minWidth: 56)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(filled ? Color.goodSoft : shown == nil ? Color.accentSoft.opacity(0.6) : Color.accentSoft))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(tint, style: StrokeStyle(lineWidth: 2, dash: shown == nil ? [5, 4] : [])))
            .animation(.easeOut(duration: 0.15), value: shown)
    }

    /// Fill the gap: the sentence with the word's place left empty (the word goes in, green,
    /// once it's answered), and what the whole sentence means under it.
    @ViewBuilder
    private func gapPrompt(_ sent: Sentence) -> some View {
        let filled = answered && !skipped
        FlowLayout(spacing: 2, lineSpacing: 4, center: true) {
            ForEach(Array(sent.words.enumerated()), id: \.offset) { _, word in
                let gap = word.hanzi == ex.answer
                VStack(spacing: 1) {
                    PinyinText(pinyin: word.pinyin, size: 12.5, weight: .semibold)
                        .opacity(gap ? (filled ? 1 : 0) : wheels.shows(hanzi: word.hanzi) || peek ? 1 : 0)
                    if gap {
                        gapSlot(word.hanzi, filled: filled)
                    } else {
                        Text(word.hanzi).font(.hanzi(24.8)).foregroundStyle(Color.ink).padding(.bottom, 2)
                    }
                }
                .padding(.horizontal, 3)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { reveal() }
        Text(sent.en).font(.nunito(14.5)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
            .lineLimit(3).minimumScaleFactor(0.85).fixedSize(horizontal: false, vertical: true)
    }

    private func option(_ opt: String) -> some View {
        let isAnswer = opt == ex.answer
        // right and wrong show once it's answered (not when it was skipped)
        let state: Bool? = !answered || skipped ? nil : isAnswer ? true : opt == picked ? false : nil
        // before that, the option selected is highlighted
        let selected = !answered && opt == picked
        let fill: Color = state == true ? Color.goodSoft : state == false ? Color.againSoft : selected ? Color.accentSoft : Color.panel
        let edge: Color = state == true ? Color.good : state == false ? Color.again : selected ? Color.accent : Color.line
        return Button { choose(opt) } label: {
            Group {
                if ex.dir == "recall" || ex.dir == "gap" {
                    VStack(spacing: 1) {
                        Text(opt).font(.hanzi(20, .bold)).foregroundStyle(Color.ink)
                        if pinyinShown, let py = Course.wordPy[opt] {
                            PinyinText(pinyin: py, size: 13.5, weight: .bold)
                        }
                    }
                } else {
                    Text(opt).font(.nunito(18.4, .black))
                        .foregroundStyle(Color.ink).multilineTextAlignment(.center)
                        // a long meaning keeps its two lines once answered, a touch smaller, not cut off
                        .lineLimit(2).minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14).padding(.vertical, ex.dir == "recall" || ex.dir == "gap" ? 10 : 13.5)
            .background(fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(edge, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(PressDown(depth: 1))
        .disabled(answered)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .animation(.easeOut(duration: 0.15), value: answered)
        .animation(.easeOut(duration: 0.12), value: selected)
    }
}

// MARK: - feedback

struct FeedbackBanner: View {
    let ex: Exercise
    let correct: Bool
    let chosen: String?
    var placed: [String] = []
    /// pinyin training wheels, as on the exercise above
    var wheels = Wheels()
    /// 5, 10, 15 … right in a row: a badge that pops in at the banner's corner (Duolingo's "5 IN A ROW")
    var inARow: Int? = nil
    @State private var bounce = false
    @State private var reported = false
    /// the Chinese this exercise said, for a report on its clip
    private var said: String { ex.sentence?.hanzi ?? ex.card.word.hanzi }
    @State private var praise = ["Nice!", "Great job!", "Excellent!", "Spot on!", "太棒了!", "对了!"].randomElement()!
    @State private var peek = false
    private let course = Course.shared
    /// The answer's pinyin: always when it's what was asked or the answer was wrong (it's the
    /// correction), else as the training wheels say.
    private var pinyinShown: Bool { ex.dir == "pinyin" || !correct || peek || wheels.shows(card: ex.card) }

    var body: some View {
        let w = ex.card.word
        let tint = correct ? Color.good : Color.again
        let lookalike: Card? = {
            guard !correct, let chosen else { return nil }
            let c = ["recall", "gap", "picture"].contains(ex.dir) ? course.cards.first { $0.word.hanzi == chosen }
                : ex.dir == "recognize" || ex.dir == "listen" ? course.cards.first { $0.word.gloss == chosen } : nil
            guard let c, CharData.shared.wordSim(w.hanzi, c.word.hanzi) >= 1.5 else { return nil }
            return c
        }()
        let diff = lookalike.flatMap { CharData.shared.difference(w.hanzi, $0.word.hanzi) }
        // what was different about a wrong answer, in one short line: the tones, or the meaning
        let note: String? = correct || diff != nil ? nil : Correction.line(ex, chosen: chosen)
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: correct ? "checkmark" : "xmark").font(.system(size: 20, weight: .heavy))
                .frame(width: 24, height: 24).padding(.top, 1)
            VStack(alignment: .leading, spacing: 0) {
                if let note {
                    Text(note).font(.nunitoXB(15.5)).fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(ex.kind == .sentence ? (correct ? "Nicely done!" : "Correct solution:")
                         : correct ? praise : diff != nil ? "So close: those two look alike!" : "Correct answer:")
                        .font(.nunitoXB(18.4))
                }
                if ex.kind == .sentence, let sent = ex.sentence {
                    sentenceAnswer(sent)
                } else if diff == nil {
                    // (with spot the difference, the right answer is in the box and in its green row)
                    wordAnswer(w)
                }
                if let diff, let other = lookalike {
                    diffBlock(diff, other: other)
                } else if note == nil, ex.kind != .sentence, Coach.sessions < 3, w.hanzi.contains(where: { CharData.shared.chars[String($0)] != nil }) {
                    Text("Tap a character to see how it's built").font(.nunito(11.5, .bold)).opacity(0.75).padding(.top, 6)
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(correct ? Color.goodSoft : Color.againSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if let n = inARow {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill").font(.system(size: 13, weight: .heavy))
                    Text("\(n) IN A ROW").font(.nunito(12.5, .black)).tracking(0.6)
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.gold, in: Capsule())
                .scaleEffect(bounce ? 1 : 0.4)
                .rotationEffect(.degrees(bounce ? -4 : -18))
                .offset(x: -10, y: -12)
                .onAppear { withAnimation(.spring(response: 0.35, dampingFraction: 0.45)) { bounce = true } }
            }
        }
        // report the clip: one tap and a reason (kept for Settings → Reported audio)
        .overlay(alignment: .bottomTrailing) {
            Menu {
                Section("Report this audio: \(said)") {
                    ForEach(AudioReports.reasons, id: \.self) { r in
                        Button(r) { AudioReports.add(said, reason: r); reported = true }
                    }
                }
            } label: {
                Image(systemName: reported ? "flag.fill" : "flag").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint.opacity(0.75)).padding(10).contentShape(Rectangle())
            }
            .accessibilityLabel("Report this audio")
            .onAppear { reported = AudioReports.has(said) }
        }
    }

    /// The word's meaning, briefly enough for the panel: its short meaning when it has one,
    /// else `en` without its asides ("to look (长 zhǎng: to grow) (…)" → "to look"), and
    /// just the first sense if that's still long.
    static func brief(_ w: Word) -> String {
        if let s = w.short, !s.isEmpty { return s }
        var out = "", depth = 0
        for ch in w.en {
            if ch == "(" { depth += 1 }
            else if ch == ")" { depth = max(0, depth - 1) }
            else if depth == 0 { out.append(ch) }
        }
        out = out.split(separator: " ").joined(separator: " ")
            .replacingOccurrences(of: " ,", with: ",").replacingOccurrences(of: " ;", with: ";")
            .trimmingCharacters(in: CharacterSet(charactersIn: " ,;"))
        if out.isEmpty { return w.gloss }
        if out.count > FeedbackBanner.longMeaning {
            let first = MemoryHook.short(out)
            if !first.isEmpty { return first }
        }
        return out
    }

    /// English longer than this goes on its own line, under the characters and pinyin.
    static let longMeaning = 28

    @ViewBuilder
    private func wordAnswer(_ w: Word) -> some View {
        let first = ex.dir == "recognize" ? "en" : ex.dir == "pinyin" || ex.dir == "type" ? "py" : "hz"
        let rest = ["hz", "py", "en"].filter { $0 != first }
        // a long meaning gets a line of its own rather than a narrow column beside the pinyin
        let apart = first != "en" && Self.brief(w).count > Self.longMeaning
        let row = apart ? rest.filter { $0 != "en" } : rest
        piece(first, w, big: true).padding(.top, 4)
        HStack(spacing: 0) {
            ForEach(Array(row.enumerated()), id: \.offset) { i, k in
                if i > 0 { Text(" · ").foregroundStyle(Color.gold) }
                piece(k, w, big: false)
            }
        }
        .font(.nunito(14.4)).padding(.top, 2)
        if apart {
            piece("en", w, big: false).padding(.top, 2)
        }
    }

    @ViewBuilder
    private func piece(_ k: String, _ w: Word, big: Bool) -> some View {
        switch k {
        case "en": Text(Self.brief(w)).font(.nunito(big ? 17.6 : 14.4)).foregroundStyle(big ? Color.ink : Color.gold)
            .fixedSize(horizontal: false, vertical: true)
        case "py":
            if big || pinyinShown {
                PinyinText(pinyin: w.pinyin, size: big ? 17.6 : 14.4, weight: .regular)
            } else {
                // a strong word's pinyin, a tap away
                Button { withAnimation(.easeOut(duration: 0.15)) { peek = true } } label: {
                    Label("pinyin", systemImage: "eye").font(.nunito(13, .bold)).foregroundStyle(Color.muted)
                }
                .buttonStyle(.plain)
            }
        default: TappableHanzi(text: w.hanzi, pinyin: w.pinyin, size: big ? 17.6 : 14.4, weight: .medium)
        }
    }

    @ViewBuilder
    private func sentenceAnswer(_ sent: Sentence) -> some View {
        let orders = sent.acceptedOrders
        let punct = sent.hanzi.last.map { "。？！".contains($0) ? String($0) : "" } ?? ""
        if !correct {
            Text(ex.toChinese ? sent.hanzi : sent.en).font(ex.toChinese ? .hanzi(17.6) : .nunito(17.6)).foregroundStyle(Color.ink).padding(.top, 4)
            if ex.toChinese { Text(sent.pinyin).font(.nunito(14.4)).foregroundStyle(Color.gold).padding(.top, 2) }
        }
        // what was heard means this (it was never on the screen)
        if ex.hearOnly { Text(sent.en).font(.nunito(14.4)).foregroundStyle(Color.ink).padding(.top, 2) }
        // the other orders that would also have been right
        let others = !ex.toChinese ? [] : correct ? orders.filter { $0 != placed } : Array(orders.dropFirst())
        if !others.isEmpty {
            Text(correct ? "ALSO CORRECT:" : "ALSO ACCEPTED:").font(.nunitoXB(13.1)).tracking(0.4).opacity(0.85).padding(.top, 8)
            ForEach(others, id: \.self) { o in
                Text(o.joined() + punct).font(.hanzi(17.6)).foregroundStyle(Color.ink).padding(.top, 4)
                Text(sent.pinyin(for: o)).font(.nunito(14.4)).foregroundStyle(Color.gold).padding(.top, 2)
            }
        }
    }

    private func diffBlock(_ d: (right: String, wrong: String, note: String), other: Card) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SPOT THE DIFFERENCE").font(.nunito(11.2, .black)).tracking(1.1).foregroundStyle(Color.again)
            HStack(spacing: 8) {
                cell(ex.card.word.hanzi, mark: d.right, en: Self.brief(ex.card.word), good: true)
                cell(other.word.hanzi, mark: d.wrong, en: Self.brief(other.word), good: false)
            }
            Text(d.note).font(.nunito(13.4)).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.top, 6)
    }

    private func cell(_ hanzi: String, mark: String, en: String, good: Bool) -> some View {
        var s = AttributedString()
        for ch in hanzi {
            var a = AttributedString(String(ch))
            if String(ch) == mark { a.foregroundColor = good ? Color.good : Color.again; a.underlineStyle = Text.LineStyle.single }
            else { a.foregroundColor = Color.ink }
            s += a
        }
        return VStack(spacing: 2) {
            Text(s).font(.hanzi(22, .bold))
            Text(en).font(.nunito(11.5, .bold)).foregroundStyle(Color.muted).lineLimit(1)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 4).padding(.horizontal, 4)
        .background(Color.bg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - the sentence builder

struct SentenceView: View {
    let ex: Exercise
    @Binding var placed: [Exercise.Tile]
    let result: Bool?
    /// pinyin training wheels: over each word while it's new, a tap away once it's strong
    var wheels = Wheels()
    /// "Can't listen now" was tapped (tap what you hear): the exercise is over, nothing shown
    var skipped = false
    /// "Can't listen now", under "tap what you hear" (nil: no such button)
    var skip: (() -> Void)? = nil
    @Environment(ProgressStore.self) private var progress
    @State private var pinyinOpen = false
    /// the words whose hidden pinyin has been shown with a tap
    @State private var peeked: Set<Int> = []
    @State private var held: Exercise.Tile?
    @State private var justHeld = false
    // dragging a tile (web: the tile follows the finger and its place in the answer
    // follows it): the tile's slot stays in the answer, empty, while a copy is carried
    @State private var drag: TileDrag?
    @State private var frames: [Int: CGRect] = [:]     // answer tiles by id, bank tiles by id + bankKey
    @State private var answerFrame: CGRect = .zero
    @State private var justDragged = false
    @State private var moves = 0
    fileprivate static let bankKey = 100_000
    private let course = Course.shared

    struct TileDrag: Equatable {
        let tile: Exercise.Tile
        var grab: CGSize            // where the finger holds the tile, from its corner
        var at: CGPoint             // the finger
        var settling = false
        var origin: CGPoint { CGPoint(x: at.x - grab.width, y: at.y - grab.height) }
    }

    /// whether a word of the sentence is itself a word not learned yet
    private func isNew(_ hanzi: String) -> Bool {
        guard let c = course.cards.first(where: { $0.word.hanzi == hanzi }) else { return false }
        return StudySession.isNewCard(progress.srs[c.id]) || (c.id == ex.card.id && ex.isNew)
    }

    var body: some View {
        let sent = ex.sentence!
        let anyNew = sent.words.contains { isNew($0.hanzi) }
        VStack(spacing: 16) {
            MascotPrompt(mood: result, sentence: !ex.toChinese,
                         long: ex.hearOnly ? false : ex.toChinese ? sent.en.count > 60 : sent.words.map(\.hanzi).joined().count > 14) {
                if ex.hearOnly {
                    // tap what you hear: only the sound, again at a tap, and slowly
                    ListenButtons(text: sent.hanzi)
                } else if ex.toChinese {
                    if anyNew { NewBadge() }
                    FlowLayout(spacing: 4, lineSpacing: 4, center: true) {
                        ForEach(Array(Hints.english(sent.en, sent.words).enumerated()), id: \.offset) { _, t in
                            if t.word == nil {
                                // as Duolingo has it: a word with nothing to show has no underline and no hint
                                Text(t.text).font(.nunito(16.3)).foregroundStyle(Color.ink).padding(.horizontal, 2)
                            } else {
                                HintChip(hanzi: t.word?.hanzi, pinyin: t.word?.pinyin, reverse: true) {
                                    Text(t.text).font(.nunito(16.3)).foregroundStyle(Color.ink)
                                        .overlay(alignment: .bottom) {
                                            Line().stroke(Color.muted.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [1.5, 3]))
                                                .frame(height: 2).offset(y: 2)
                                        }
                                }
                            }
                        }
                    }
                } else {
                    // as JIC had it: the NEW WORD tag on top, the speaker at the sentence's left, and
                    // each word with its tone-coloured pinyin over it
                    if anyNew { NewBadge() }
                    // as Duolingo has it: the sound at the bubble's left, the words beside it
                    HStack(alignment: .center, spacing: 6) {
                    BubbleSound(text: sent.hanzi)
                    FlowLayout(spacing: 2, lineSpacing: 4) {
                            ForEach(Array(sent.words.enumerated()), id: \.offset) { i, w in
                                let new = isNew(w.hanzi)
                                HintChip(hanzi: w.hanzi, pinyin: w.pinyin, phrase: Hints.phrase(sent.en, sent.words), tapped: { _ = peeked.insert(i) }) {
                                VStack(spacing: 1) {
                                    PinyinText(pinyin: w.pinyin, size: 12.5, weight: .semibold)
                                        .opacity(wheels.shows(hanzi: w.hanzi) || pinyinOpen || peeked.contains(i) ? 1 : 0)
                                    Text(w.hanzi).font(.hanzi(24.8)).foregroundStyle(new ? Color.newInk : Color.ink)
                                        .padding(.bottom, 2)
                                        .overlay(alignment: .bottom) {
                                            Line().stroke(new ? Color.newInk : Color.muted, style: StrokeStyle(lineWidth: 2, dash: [2, 3])).frame(height: 2)
                                        }
                                }
                                }
                                .padding(.horizontal, 3)
                            }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation { pinyinOpen.toggle() } }
                    }
                }
            }
            if !HintTip.used && !ex.hearOnly { Text("Tap a word for its meaning, or hold a tile").font(.nunito(12.5)).foregroundStyle(Color.muted) }
            answerArea.allowsHitTesting(!skipped)
            bank.allowsHitTesting(!skipped)
            if ex.hearOnly, let skip {
                // its place is kept once the exercise is answered, so nothing moves
                ZStack {
                    if skipped {
                        Text("No problem — no more listening this session.")
                            .font(.nunito(14, .semibold)).foregroundStyle(Color.muted)
                            .multilineTextAlignment(.center)
                    } else {
                        Button("Can't listen now") { skip() }
                            .font(.nunito(14, .bold)).foregroundStyle(Color.muted)
                            .buttonStyle(.plain)
                            .opacity(result != nil ? 0 : 1)
                            .disabled(result != nil)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 20)
            }
        }
        .coordinateSpace(.named("sentence"))
        .onPreferenceChange(TileFrames.self) { frames = $0 }
        .overlay(alignment: .topLeading) {
            // the tile being carried, over everything, a little lifted
            if let d = drag {
                tileFace(d.tile, tint: nil)
                    .scaleEffect(d.settling ? 1 : 1.08)
                    .shadow(color: .black.opacity(d.settling ? 0 : 0.18), radius: 8, y: 5)
                    .offset(x: d.origin.x, y: d.origin.y)
                    .allowsHitTesting(false)
            }
        }
        .sensoryFeedback(.selection, trigger: moves)
        .onAppear {
            #if DEBUG
            // the drag screenshot: the answer's tiles all placed, the first carried part-way
            if Launch.screen == "sentencedrag", let sent = ex.sentence {
                let words = ex.toChinese ? sent.words.map(\.hanzi) : Sentence.enWords(sent.en)
                var pool = ex.tiles
                placed = words.compactMap { w in pool.firstIndex { $0.text == w }.map { pool.remove(at: $0) } }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    guard placed.count > 1, let f = frames[placed[0].id] else { return }
                    let v = CGPoint(x: f.midX + 80, y: f.midY + 20)
                    drag = TileDrag(tile: placed[0], grab: CGSize(width: f.width / 2, height: f.height / 2), at: v)
                    moveSlot(placed[0])
                }
            }
            #endif
        }
    }

    private var rowHeight: CGFloat { ex.toChinese ? 78 : 64 }
    private var rows: Int {
        let n = ex.toChinese ? (ex.sentence?.words.count ?? 0) : Sentence.enWords(ex.sentence?.en ?? "").count
        return max(2, Int(ceil(Double(n) / Double(ex.toChinese ? 6 : 5))))
    }

    private var answerArea: some View {
        FlowLayout(spacing: 7, lineSpacing: 0, rowHeight: rowHeight) {
            ForEach(placed) { t in
                tile(t, inAnswer: true) {
                    guard result == nil else { return }
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { placed.removeAll { $0.id == t.id } }
                }
                .opacity(drag?.tile == t ? 0 : 1)
                .background(GeometryReader { g in
                    Color.clear.preference(key: TileFrames.self, value: [t.id: g.frame(in: .named("sentence"))])
                })
            }
        }
        .frame(maxWidth: .infinity, minHeight: rowHeight * CGFloat(rows), alignment: .topLeading)
        .background(GeometryReader { g in
            Color.clear
                .onAppear { answerFrame = g.frame(in: .named("sentence")) }
                .onChange(of: g.frame(in: .named("sentence"))) { _, f in answerFrame = f }
        })
        .background(alignment: .top) {
            VStack(spacing: 0) {
                ForEach(0..<rows, id: \.self) { _ in
                    Rectangle().fill(Color.line).frame(height: 2).padding(.top, rowHeight - 2)
                }
            }
        }
    }

    private var bank: some View {
        FlowLayout(spacing: 7, lineSpacing: 7, center: true) {
            ForEach(ex.tiles) { t in
                let used = placed.contains(t)
                tile(t, inAnswer: false) {
                    guard result == nil, !used else { return }
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { placed.append(t) }
                    if let say = TapToHear.tile(t, in: ex, answered: result != nil, allowed: TapToHear.allowed(progress.prefs)) {
                        Speech.shared.speak(say)
                    }
                }
                .opacity(used ? 0 : 1)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.line.opacity(used ? 0.6 : 0)))
                .background(GeometryReader { g in
                    Color.clear.preference(key: TileFrames.self, value: [t.id + Self.bankKey: g.frame(in: .named("sentence"))])
                })
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func tileFace(_ t: Exercise.Tile, tint: Color?) -> some View {
        VStack(spacing: 1) {
            // pinyin over a Chinese tile while its word is new (its place kept, so the tiles
            // stay one height); once strong, holding the tile shows it
            if let py = t.pinyin {
                Text(py).font(.nunito(11.5)).foregroundStyle(Color.muted)
                    .opacity(wheels.shows(hanzi: t.text) ? 1 : 0)
            }
            Text(t.text).font(ex.toChinese ? .hanzi(20.8, .medium) : .nunito(16.8, .semibold))
        }
        .foregroundStyle(tint ?? Color.ink)
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(tint ?? Color.line).offset(y: 2)
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.panel)
                RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(tint ?? Color.line, lineWidth: 2)
            }
        }
    }

    private func tile(_ t: Exercise.Tile, inAnswer: Bool, tap: @escaping () -> Void) -> some View {
        let tint: Color? = inAnswer ? (result == true ? .good : result == false ? .again : nil) : nil
        // a hold shows the tile's hint, and the tap its release makes is ignored (the Mac's check)
        return Button { if justHeld { justHeld = false } else if !justDragged { tap() } } label: { tileFace(t, tint: tint) }
        .buttonStyle(PressDown(depth: 2))
        .sensoryFeedback(.selection, trigger: placed.count)
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.45).onEnded { _ in
            guard drag == nil else { return }
            held = t; justHeld = true; HintTip.used = true
            // (where the release makes no tap, the next real tap still counts)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { justHeld = false }
        })
        .highPriorityGesture(
            DragGesture(minimumDistance: 8, coordinateSpace: .named("sentence"))
                .onChanged { v in dragMoved(t, v, fromBank: !inAnswer) }
                .onEnded { v in dragEnded(t, v) },
            including: result == nil ? .all : .subviews)
        .hintBubble(open: Binding(get: { held == t && (inAnswer || !placed.contains(t)) }, set: { if !$0 { held = nil } })) {
            if t.pinyin != nil {
                HintBubble(hanzi: t.text, pinyin: t.pinyin)
            } else {
                let en = ex.sentence?.en ?? ""
                let w = Hints.english(en, ex.sentence?.words ?? []).first { $0.text.lowercased() == t.text.lowercased() }?.word
                HintBubble(hanzi: w?.hanzi, pinyin: w?.pinyin, reverse: true, empty: "Not in this sentence")
            }
        }
    }
}

extension SentenceView {
    /// The finger moved with a tile: lift it (out of the bank into the answer if it
    /// was there), carry it, and move its slot to where it would drop (web: pointermove).
    fileprivate func dragMoved(_ t: Exercise.Tile, _ v: DragGesture.Value, fromBank: Bool) {
        guard result == nil else { return }
        if drag?.tile != t {
            if fromBank && placed.contains(t) { return }       // its empty place in the bank
            let inAnswer = placed.contains(t)
            let f = frames[inAnswer ? t.id : t.id + Self.bankKey] ?? CGRect(origin: v.startLocation, size: .zero)
            held = nil
            drag = TileDrag(tile: t, grab: CGSize(width: v.startLocation.x - f.minX, height: v.startLocation.y - f.minY), at: v.location)
            if !inAnswer { placed.append(t); moves += 1 }
        }
        drag?.at = v.location
        moveSlot(t)
    }

    /// Put the carried tile's slot where its middle is, among the answer's other tiles.
    fileprivate func moveSlot(_ t: Exercise.Tile) {
        guard let d = drag else { return }
        let size = frames[t.id]?.size ?? frames[t.id + Self.bankKey]?.size ?? .zero
        let mid = CGPoint(x: d.origin.x + size.width / 2, y: d.origin.y + size.height / 2)
        let others = placed.filter { $0 != t }
        var at = others.count
        for (i, o) in others.enumerated() {
            guard let r = frames[o.id] else { continue }
            let row = r.insetBy(dx: 0, dy: -12)
            if mid.y < row.minY || (mid.y <= row.maxY && mid.x < r.midX) { at = i; break }
        }
        var next = others
        next.insert(t, at: at)
        if next != placed {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) { placed = next }
            moves += 1
        }
    }

    /// Let go: dropped well below the answer, the tile goes back to the bank;
    /// anywhere else it settles into its slot (web: release).
    fileprivate func dragEnded(_ t: Exercise.Tile, _ v: DragGesture.Value) {
        guard drag?.tile == t else { return }
        justDragged = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { justDragged = false }
        let toBank = v.location.y > answerFrame.maxY + 24
        if toBank { withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { placed.removeAll { $0 == t } } }
        // glide the carried copy home, then let the real tile show
        let home = toBank ? frames[t.id + Self.bankKey] : frames[t.id]
        guard let home else { drag = nil; return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            drag = TileDrag(tile: t, grab: .zero, at: home.origin, settling: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { if drag?.tile == t && drag?.settling == true { drag = nil } }
    }
}

/// Where the sentence tiles are, for dragging.
struct TileFrames: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) { value.merge(nextValue()) { $1 } }
}

struct Line: Shape {
    func path(in r: CGRect) -> Path { Path { p in p.move(to: .init(x: r.minX, y: r.midY)); p.addLine(to: .init(x: r.maxX, y: r.midY)) } }
}

/// Lays its children out left to right, wrapping onto new lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8
    var rowHeight: CGFloat? = nil     // fixed rows, children sitting on the bottom of each
    var center = false

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews)
        let h = rows.reduce(0) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * lineSpacing
        let w = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? w, height: h)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews) {
            var x = bounds.minX + (center ? (bounds.width - row.width) / 2 : 0)
            for i in row.items {
                let s = subviews[i].sizeThatFits(.unspecified)
                let top = rowHeight != nil ? y + row.height - s.height - 9 : y + (row.height - s.height) / 2
                subviews[i].place(at: CGPoint(x: x, y: top), proposal: .unspecified)
                x += s.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row { var items: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, _ subviews: Subviews) -> [Row] {
        var rows: [Row] = [], row = Row()
        for (i, v) in subviews.enumerated() {
            let s = v.sizeThatFits(.unspecified)
            let extra = row.items.isEmpty ? s.width : row.width + spacing + s.width
            if extra > width && !row.items.isEmpty {
                rows.append(row); row = Row()
            }
            row.width = row.items.isEmpty ? s.width : row.width + spacing + s.width
            row.height = max(row.height, rowHeight ?? s.height)
            row.items.append(i)
        }
        if !row.items.isEmpty { rows.append(row) }
        return rows
    }
}

/// "Wait, don't go!": closing a session part-way asks first, as Duolingo does, with the sad panda.
struct QuitAsk: View {
    let keep: () -> Void
    let quit: () -> Void
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.35).ignoresSafeArea().onTapGesture { keep() }
            VStack(spacing: 14) {
                Image("panda-sad").resizable().scaledToFit().frame(height: 110)
                Text("Wait, don't go!").font(.nunitoXB(21)).foregroundStyle(Color.ink)
                Text("You'll lose this lesson's progress if you leave now.")
                    .font(.nunito(15.5)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
                Button(action: keep) {
                    Text("Keep learning").font(.nunitoXB(16.8)).foregroundStyle(Color.onAccent)
                        .frame(maxWidth: .infinity).padding(15).background(Color.accent, in: Capsule())
                }
                .buttonStyle(PressDown(depth: 1))
                Button(action: quit) {
                    Text("End lesson").font(.nunitoXB(15.5)).foregroundStyle(Color.again).padding(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22).padding(.top, 22).padding(.bottom, 16)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.panel).ignoresSafeArea(edges: .bottom))
            .transition(.move(edge: .bottom))
        }
    }
}

/// Type it in pinyin: the word and its meaning, and a box for its pinyin (tones optional), as
/// Duolingo's typed exercises near the end of a lesson. Return checks it.
struct TypeView: View {
    let ex: Exercise
    @Binding var typed: String
    let result: Bool?
    var submit: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        let w = ex.card.word
        VStack(spacing: 22) {
            MascotPrompt(mood: result) {
                if ex.isNew { NewBadge() }
                Text(w.hanzi).font(.hanzi(w.hanzi.count > 3 ? 32 : 44, .medium)).foregroundStyle(Color.ink)
                Text(w.gloss).font(.nunito(16)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
            }
            TextField("Type the pinyin", text: $typed)
                .font(.nunito(22, .bold)).foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.asciiCapable)
                .submitLabel(.done).onSubmit(submit)
                .focused($focused)
                .disabled(result != nil)
                .padding(.vertical, 16).padding(.horizontal, 14)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.panel))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(result == true ? Color.good : result == false ? Color.again : focused ? Color.accent : Color.line, lineWidth: 2))
            Text("Tones are optional: ni hao or ni3 hao3").font(.nunito(12.5)).foregroundStyle(Color.muted)
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focused = true } }
        .onChange(of: result) { _, r in if r != nil { focused = false } }
    }
}

/// Build the character: its meaning and pinyin, and six parts to pick from (two or three of them
/// make it). Once answered, the sum: 女 + 子 = 好.
struct BuildView: View {
    let ex: Exercise
    @Binding var picked: Set<String>
    let result: Bool?

    private var parts: [String] { ex.answer.components(separatedBy: "|") }

    var body: some View {
        let w = ex.card.word
        VStack(spacing: 18) {
            MascotPrompt(mood: result) {
                if ex.isNew { NewBadge() }
                if result == nil {
                    Text("?").font(.hanzi(44, .medium)).foregroundStyle(Color.muted.opacity(0.5))
                } else {
                    Text(parts.joined(separator: " + ") + " = " + w.hanzi).font(.hanzi(28, .medium)).foregroundStyle(Color.ink)
                }
                PinyinText(pinyin: w.pinyin, size: 18)
                Text(w.gloss).font(.nunito(16)).foregroundStyle(Color.ink).multilineTextAlignment(.center)
            }
            Text("Pick the \(parts.count == 2 ? "two" : "three") parts it's made of")
                .font(.nunito(13.5, .bold)).foregroundStyle(Color.muted)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(ex.options, id: \.self) { part in tile(part) }
            }
        }
    }

    private func tile(_ part: String) -> some View {
        let isPart = parts.contains(part)
        let on = picked.contains(part)
        let state: Bool? = result == nil ? nil : isPart ? true : on ? false : nil
        let edge: Color = state == true ? Color.good : state == false ? Color.again : on ? Color.accent : Color.line
        let fill: Color = state == true ? Color.goodSoft : state == false ? Color.againSoft : on ? Color.accentSoft : Color.panel
        let name = CharData.shared.partNames[part]?.first ?? CharData.shared.meaning(part)
        return Button {
            guard result == nil else { return }
            if on { picked.remove(part) } else if picked.count < parts.count { picked.insert(part) }
        } label: {
            VStack(spacing: 2) {
                Text(part).font(.hanzi(30, .medium)).foregroundStyle(Color.ink)
                Text(name).font(.nunito(11.5, .semibold)).foregroundStyle(Color.muted).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(edge, lineWidth: on ? 3 : 2))
        }
        .buttonStyle(PressDown(depth: 2))
        .disabled(result != nil)
    }
}
