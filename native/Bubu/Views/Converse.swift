import SwiftUI
import Speech

/// Roleplay a dialogue: Bùbù says their lines, you say yours (web: openConverse).
struct ConversePage: View {
    @State private var dialogue: Dialogue?
    @State private var turn = 0
    @State private var shown: [Turn] = []
    @State private var showChars = false
    @State private var listening = false
    @State private var message: Text?
    @State private var recognizer = Recognizer()
    @State private var canCheck = true
    @State private var run = 0          // bumped on every start, advance and exit: stale timers do nothing
    @State private var listenOnly = false   // a dialogue whose words you haven't met: hear it, don't say it
    @Environment(ProgressStore.self) private var progress
    private let course = Course.shared

    private func unlocked(_ d: Dialogue) -> Bool {
        course.dialogueUnlocked(d) { progress.srs[$0] != nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { reader in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // the ones you can say first; the rest locked, to listen to
                        ForEach(course.data.dialogues.filter { unlocked($0) } + course.data.dialogues.filter { !unlocked($0) }, id: \.id) { d in
                            let on = dialogue?.id == d.id, open = unlocked(d)
                            Button { start(d) } label: {
                                Text("\(open ? "" : "🔒 ")\(d.title)  ·  \(d.lesson)").font(.nunito(13.5, .bold)).lineLimit(1)
                                    .foregroundStyle(on ? Color.onAccent : open ? Color.ink : Color.muted)
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(on ? Color.accent : Color.panel, in: Capsule())
                                    .overlay(Capsule().strokeBorder(on ? Color.accent : Color.line))
                            }
                            .buttonStyle(.plain)
                            .id(d.id)
                        }
                    }
                    .padding(.horizontal, 18).padding(.vertical, 8)
                }
                .onChange(of: dialogue?.id) { _, id in withAnimation { reader.scrollTo(id, anchor: .leading) } }
            }

            ScrollViewReader { reader in
                ScrollView {
                    VStack(spacing: 10) {
                        if dialogue == nil {
                            Text("Pick a conversation to roleplay. Bùbù plays the other part; you say yours out loud. 🔒 ones use words you haven't learnt yet: you can listen to them.")
                                .font(.nunito(15)).foregroundStyle(Color.muted).multilineTextAlignment(.center).padding(.top, 40)
                        }
                        ForEach(Array(shown.enumerated()), id: \.offset) { i, t in bubble(t).id(i) }
                    }
                    .padding(.horizontal, 18).padding(.vertical, 10)
                }
                .onChange(of: shown.count) { _, n in withAnimation { reader.scrollTo(n - 1, anchor: .bottom) } }
            }

            controls
                .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 12)
                .background { Color.panel.shadow(color: .black.opacity(0.06), radius: 8, y: -3).ignoresSafeArea(edges: .bottom) }
        }
        .navigationTitle(dialogue.map { "Converse · \($0.title)" } ?? "Converse")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { canCheck = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))?.isAvailable ?? false }
        .onDisappear { recognizer.end(); run += 1; Speech.shared.stop() }
    }

    private func bubble(_ t: Turn) -> some View {
        let mine = t.who == "you"
        return HStack {
            if mine { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 3) {
                ToneText(hanzi: t.hanzi, pinyin: t.pinyin, size: 21, weight: .medium)
                PinyinText(pinyin: t.pinyin, size: 13.5, weight: .regular)
                Text(t.en).font(.nunito(13.5)).foregroundStyle(Color.muted)
                HStack(spacing: 4) {
                    SpeakerButton(text: t.hanzi, size: 16)
                    Button { Speech.shared.speak(t.hanzi, slow: true) } label: {
                        Text("½×").font(.nunitoXB(12)).foregroundStyle(Color.accent).padding(4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(mine ? Color.accentSoft : Color.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(mine ? .clear : Color.line))
            if !mine { Spacer(minLength: 40) }
        }
        .transition(.move(edge: mine ? .trailing : .leading).combined(with: .opacity))
    }

    @ViewBuilder
    private var controls: some View {
        if let d = dialogue {
            if turn >= d.turns.count {
                VStack(spacing: 8) {
                    Text("End of conversation.").font(.nunito(14.5)).foregroundStyle(Color.muted)
                    Button("↻ Start over") { start(d) }.buttonStyle(WideButton())
                }
            } else if d.turns[turn].who == "you" {
                yourTurn(d.turns[turn])
            } else {
                Text("…").font(.nunitoXB(20)).foregroundStyle(Color.muted).frame(height: 44)
            }
        } else {
            EmptyView()
        }
    }

    private func yourTurn(_ t: Turn) -> some View {
        let free = t.free ?? false
        return VStack(spacing: 8) {
            if listenOnly {
                Text("🔒 Listen only — you'll say this once you've learnt its words.")
                    .font(.nunito(13, .semibold)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
                Button("Next →") { advance(t) }.buttonStyle(WideButton())
            } else {
            Text("YOUR TURN — SAY:").font(.nunito(11.5, .black)).tracking(1).foregroundStyle(Color.muted)
            PinyinText(pinyin: t.pinyin, size: 20).multilineTextAlignment(.center)
            Text(t.en).font(.nunito(14)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
            if showChars { ToneText(hanzi: t.hanzi, pinyin: t.pinyin, size: 25, weight: .medium) }
            HStack(spacing: 8) {
                small("Hear it", "speaker.wave.2.fill") { Speech.shared.speak(t.hanzi) }
                if !showChars { small("Show characters", "character") { withAnimation { showChars = true } } }
            }
            if canCheck && !free {
                Button { listen(t) } label: {
                    Label(listening ? "Listening…" : "Speak", systemImage: listening ? "waveform" : "mic.fill")
                        .font(.nunitoXB(16.8)).foregroundStyle(Color.onAccent)
                        .frame(maxWidth: .infinity).padding(13)
                        .background(listening ? Color.again : Color.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .symbolEffect(.variableColor.iterative, isActive: listening)
                }
                .buttonStyle(PressDown(depth: 1))
                .disabled(listening)
            }
            Button(free ? "I said it →" : "Skip / I said it →") { advance(t) }
                .buttonStyle(WideButton(ghost: canCheck && !free))
            message.map { $0.font(.nunito(14)).multilineTextAlignment(.center) }
            }
        }
    }

    private func small(_ label: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon).font(.nunito(13.5, .bold)).foregroundStyle(Color.ink)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .overlay(Capsule().strokeBorder(Color.line))
        }
        .buttonStyle(.plain)
    }

    private func start(_ d: Dialogue) {
        recognizer.end()
        run += 1
        dialogue = d; turn = 0; shown = []; message = nil; showChars = false
        listenOnly = !unlocked(d)
        step()
    }

    /// Bùbù's lines play and move on by themselves; yours wait for you.
    private func step() {
        guard let d = dialogue, turn < d.turns.count else { return }
        let t = d.turns[turn]
        // listening only: your lines are said for you too
        if t.who == "you" && listenOnly { Speech.shared.speak(t.hanzi); return }
        guard t.who != "you" else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { shown.append(t) }
        Speech.shared.speak(t.hanzi, male: true)       // the other speaker has their own voice
        turn += 1
        let r = run
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { if run == r { step() } }
    }

    private func advance(_ t: Turn) {
        // only the turn on screen can move on, and only once
        guard let d = dialogue, turn < d.turns.count, d.turns[turn] == t else { return }
        recognizer.end()
        run += 1
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { shown.append(t) }
        turn += 1; message = nil; showChars = false
        step()
    }

    private func listen(_ t: Turn) {
        message = nil; listening = true
        recognizer.onInterim = { alts in if let a = alts.first { message = Text("heard: \(a)…").foregroundColor(.muted) } }
        recognizer.acceptEarly = { SpeechScore.saidWhole(t.hanzi, $0) }
        recognizer.onResult = { alts in
            let r = SpeechScore.score(t.hanzi, alts, keyword: nil)
            if r.level == .no {
                message = Text("Not quite").foregroundColor(.again).bold() + Text(" — heard “\(r.heard.isEmpty ? "…" : r.heard)”. Try again, or tap “I said it”.").foregroundColor(.muted)
                Sounds.shared.play("wrong")
            } else {
                message = Text("✓ \(r.level == .exact ? "Perfect" : "Close enough")").foregroundColor(.good).bold() + Text(" — heard “\(r.heard)”").foregroundColor(.muted)
                Sounds.shared.play("correct")
                let r0 = run
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { if run == r0 { advance(t) } }
            }
        }
        recognizer.onError = { f in
            message = Text(f == .notAllowed ? "Allow the microphone in Settings, or tap “I said it”." : "Didn't catch that — try again.").foregroundColor(.muted)
        }
        recognizer.onEnd = { listening = false }
        recognizer.start()
    }
}
