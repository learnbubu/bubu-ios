import SwiftUI
import UIKit
import Speech
import AVFoundation

/// Say it out loud, as Duolingo's speaking exercise: a wide "Tap to speak" button that
/// shows a live waveform while listening (tap again to stop), then the phrase with each
/// character green if it was heard and red if it was missed. Up to two retries before it
/// counts as wrong; judged on the words, not the tones, and leniently. "Can't speak now"
/// (or no microphone) brings the word back later as something else, with no penalty.
struct SpeakView: View {
    let ex: Exercise
    let answered: Bool
    var settle: (Bool) -> Void
    var skip: () -> Void

    enum Phase { case ready, listening }
    enum Outcome { case pass, retry, fail }

    @State private var recognizer = Recognizer()
    @State private var phase: Phase = .ready
    @State private var level: CGFloat = 0
    @State private var tries = 0
    @State private var marks: [SpeechScore.Mark] = []
    @State private var heard = ""
    @State private var outcome: Outcome?
    @State private var note: String?
    @State private var mood: Bool?
    /// why speaking can't happen here (no permission, no recogniser): the exercise is skipped
    @State private var blocked: String?
    @State private var blockedBySettings = false
    @State private var skipped = false
    @Environment(\.openURL) private var openURL
    /// Retries allowed after the first go before it counts as wrong.
    static let maxRetries = 2

    var body: some View {
        let w = ex.card.word
        VStack(spacing: 8) {
            MascotPrompt(mood: mood) {
                target.font(.hanzi(ex.sayHanzi.count > 3 ? 28.8 : 38.4, .medium))
                    .multilineTextAlignment(.center)
                // hear it first, at normal speed or slowly
                SpeakerButton(text: ex.sayHanzi, withSlow: true)
            }
            PinyinText(pinyin: ex.sayPinyin, size: 23.2).multilineTextAlignment(.center)
            Text(ex.sayEn).font(.nunito(16)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
            if ex.sentence != nil {
                Text("practising \(w.hanzi) — \(w.pinyin)").font(.nunito(12.5)).foregroundStyle(Color.muted)
            }

            if let blocked {
                blockedBox(blocked)
            } else {
                if outcome != .pass && outcome != .fail && !skipped {
                    Button { tapMic() } label: { micLabel }
                        .buttonStyle(ChunkyButton(face: Color.accent, base: Color.accentDark))
                        .disabled(answered)
                        .accessibilityLabel(micName)
                        .padding(.top, 12)
                }
                if let note {
                    Text(note).font(.nunito(15)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
                }
                if let outcome, phase == .ready {
                    banner(outcome).transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if !answered {
                    Button("Can't speak now") {
                        guard !answered else { return }
                        recognizer.end()
                        note = "No problem — we'll come back to \(w.hanzi) (\(w.pinyin)) later."
                        skipped = true
                        skip()
                    }
                    .font(.nunito(14, .bold)).foregroundStyle(Color.muted)
                    .buttonStyle(.plain)
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: outcome)
        .onAppear {
            checkAvailable()
            // as Duolingo: say it first, so there's something to copy (the speaker says it again)
            if !answered { Speech.shared.autoSpeak(ex.sayHanzi) }
        }
        .onDisappear { recognizer.end() }
    }

    // MARK: pieces

    /// The phrase: plain until something's been heard, then green for each character
    /// heard and red for each missed.
    private var target: Text {
        guard !marks.isEmpty else { return Text(ex.sayHanzi).foregroundColor(.ink) }
        var t = Text("")
        for m in marks {
            let color: Color = m.heard == nil ? .ink : (m.heard == true ? .good : .again)
            t = t + Text(String(m.char)).foregroundColor(color)
        }
        return t
    }

    private var micName: String {
        phase == .listening ? "Stop listening" : outcome == .retry ? "Retry" : "Tap to speak"
    }

    @ViewBuilder
    private var micLabel: some View {
        if phase == .listening {
            HStack(spacing: 12) {
                Waveform(level: level)
                Text("Listening…")
            }
            .font(.nunitoXB(17.6)).foregroundStyle(Color.onAccent)
        } else {
            Label(micName, systemImage: "mic.fill")
                .font(.nunitoXB(17.6)).foregroundStyle(Color.onAccent)
        }
    }

    private func banner(_ o: Outcome) -> some View {
        let good = o == .pass
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: good ? "checkmark" : "xmark").font(.system(size: 20, weight: .heavy))
                .frame(width: 24, height: 24).padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(good ? "Nice!" : o == .retry ? "Not quite — try again" : "Not quite").font(.nunitoXB(18.4))
                detail(o).font(.nunito(14.4)).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(good ? Color.good : Color.again)
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(good ? Color.goodSoft : Color.againSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.top, 6)
    }

    private func detail(_ o: Outcome) -> Text {
        let said = heard.isEmpty ? "…" : heard
        switch o {
        case .pass:
            return Text("Heard “\(said)”").foregroundColor(.muted)
        case .retry:
            let left = max(0, Self.maxRetries + 1 - tries)
            return Text("Heard “\(said)”. \(left) more \(left == 1 ? "go" : "goes").").foregroundColor(.muted)
        case .fail:
            return Text("It's ").foregroundColor(.muted) + Text(ex.sayHanzi).bold().foregroundColor(.ink)
                + Text(" (\(ex.sayPinyin)). We'll practise it again.").foregroundColor(.muted)
        }
    }

    private func blockedBox(_ message: String) -> some View {
        VStack(spacing: 8) {
            Label(message, systemImage: "mic.slash.fill")
                .font(.nunito(15, .bold)).foregroundStyle(Color.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Text("No problem: we'll skip speaking for now. Tap Continue.")
                .font(.nunito(13.5)).foregroundStyle(Color.muted)
            if blockedBySettings, let url = URL(string: UIApplication.openSettingsURLString) {
                Button("Open Settings") { openURL(url) }
                    .font(.nunito(14, .bold)).foregroundStyle(Color.accent)
                    .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.top, 12)
    }

    // MARK: listening

    /// No recogniser, or the microphone or speech recognition turned off: say so, and skip
    /// the exercise without penalty (before a tap, when it's already known).
    private func checkAvailable() {
        let available = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))?.isAvailable ?? false
        let speech = SFSpeechRecognizer.authorizationStatus()
        let micDenied = AVAudioApplication.shared.recordPermission == .denied
        if speech == .denied || speech == .restricted || micDenied {
            block(Self.deniedMessage, settings: true)
        } else if !available {
            block(Self.unavailableMessage, settings: false)
        }
    }

    static let deniedMessage = "Bùbù can't use the microphone. Allow the microphone and speech recognition for Bùbù in Settings to practise speaking."
    static let unavailableMessage = "Speech recognition isn't available right now."

    private func block(_ message: String, settings: Bool) {
        recognizer.end()
        blocked = message
        blockedBySettings = settings
        note = nil
        if !answered { skip() }
    }

    private func tapMic() {
        guard !answered else { return }
        if phase == .listening {
            recognizer.settle()          // tap again: stop and mark what was heard
        } else {
            listen()
        }
    }

    private func listen() {
        guard !answered, phase == .ready, blocked == nil else { return }
        let say = ex.sayHanzi, key = ex.card.word.hanzi
        var gotResult = false
        Speech.shared.stop()             // don't hear Bùbù's own voice
        note = nil
        outcome = nil
        marks = []
        heard = ""
        level = 0
        phase = .listening
        recognizer.onLevel = { v in
            guard phase == .listening else { return }
            level = level * 0.5 + CGFloat(v) * 0.5
        }
        recognizer.onInterim = { alts in
            if !answered, let a = alts.first { note = "…" + a }
        }
        recognizer.acceptEarly = { SpeechScore.saidWhole(say, $0) }
        recognizer.onResult = { alts in
            gotResult = true
            tries += 1
            marks = SpeechScore.marks(say, alts)
            heard = alts.first ?? ""
            note = nil
            if SpeechScore.passes(say, alts, keyword: key) {
                outcome = .pass; mood = true; settle(true)
            } else if tries <= Self.maxRetries {
                outcome = .retry
            } else {
                outcome = .fail; mood = false; settle(false)
            }
        }
        // a mic failure isn't a wrong answer
        recognizer.onError = { f in
            switch f {
            case .notAllowed: block(Self.deniedMessage, settings: true)
            case .unavailable: block(Self.unavailableMessage, settings: false)
            case .noSpeech: note = "Didn't catch that — tap to try again."
            }
        }
        recognizer.onEnd = {
            phase = .ready
            level = 0
            if !gotResult && note == nil && blocked == nil { note = "Didn't catch that — tap to try again." }
        }
        recognizer.start()
    }
}

/// A wide, chunky button: the face sits on a darker base, both drawn together at the
/// same size, and the face sinks onto the base while pressed.
struct ChunkyButton: ButtonStyle {
    var face: Color
    var base: Color
    var depth: CGFloat = 4
    var height: CGFloat = 58

    func makeBody(configuration: Configuration) -> some View {
        let down = configuration.isPressed
        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(base)
                .frame(height: height)
                .offset(y: depth)
            configuration.label
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(face, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .offset(y: down ? depth : 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, depth)
        .contentShape(Rectangle())
        .animation(.spring(response: 0.18, dampingFraction: 0.7), value: down)
        .sensoryFeedback(.impact(weight: .light), trigger: down)
    }
}

/// Seven bars that rise with the microphone's level, with a gentle ripple so they move
/// even in a quiet room.
struct Waveform: View {
    var level: CGFloat
    var bars = 7

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 4) {
                ForEach(0..<bars, id: \.self) { i in
                    Capsule().frame(width: 4, height: barHeight(i, t))
                }
            }
            .frame(height: 28)
        }
        .accessibilityHidden(true)
    }

    private func barHeight(_ i: Int, _ t: TimeInterval) -> CGFloat {
        let mid = Double(bars - 1) / 2
        let centre = 1 - abs(Double(i) - mid) / Double(bars)          // middle bars taller
        let ripple = (sin(t * 7 + Double(i) * 0.9) + 1) / 2          // 0…1
        let loud = Double(min(1, max(0, level)))
        let h = 4 + centre * (5 + 19 * loud) * (0.55 + 0.45 * ripple)
        return CGFloat(min(28, h))
    }
}
