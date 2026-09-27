import SwiftUI
import Speech

/// Say it out loud, as the web's speak card: tap the mic and say the phrase; it's
/// marked right if what was heard matches or comes close, with a second go before
/// it counts as wrong. "Can't speak now" brings the word back later, no penalty.
struct SpeakView: View {
    let ex: Exercise
    let answered: Bool
    var settle: (Bool) -> Void
    var skip: () -> Void

    @State private var recognizer = Recognizer()
    @State private var listening = false
    @State private var tries = 0
    @State private var message: Text?
    @State private var mood: Bool?
    @State private var canCheck = true
    private let maxTries = 2

    var body: some View {
        let w = ex.card.word
        VStack(spacing: 8) {
            MascotPrompt(mood: mood) {
                Text(ex.sayHanzi).font(.hanzi(ex.sayHanzi.count > 3 ? 28.8 : 38.4, .medium))
                    .foregroundStyle(Color.ink).multilineTextAlignment(.center)
                SpeakerButton(text: ex.sayHanzi)
            }
            PinyinText(pinyin: ex.sayPinyin, size: 23.2).multilineTextAlignment(.center)
            Text(ex.sayEn).font(.nunito(16)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
            if ex.sentence != nil {
                Text("practising \(w.hanzi) — \(w.pinyin)").font(.nunito(12.5)).foregroundStyle(Color.muted)
            }

            if canCheck {
                Button { listen() } label: {
                    Label(listening ? "Listening…" : "Tap and say it", systemImage: listening ? "waveform" : "mic.fill")
                        .font(.nunitoXB(16.8)).foregroundStyle(Color.onAccent)
                        .padding(.horizontal, 24).padding(.vertical, 13)
                        .background(listening ? Color.again : Color.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .symbolEffect(.variableColor.iterative, isActive: listening)
                }
                .buttonStyle(PressDown(depth: 4))
                .background((listening ? Color.again : Color.accentDark).opacity(listening ? 0.5 : 1),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous).offset(y: 4))
                .scaleEffect(listening ? 1.03 : 1)
                .animation(listening ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true) : .default, value: listening)
                .disabled(answered || listening)
                .padding(.top, 10)

                message.map { $0.font(.nunito(15)).multilineTextAlignment(.center).padding(.top, 4) }

                Button("Can't speak now") {
                    guard !answered else { return }
                    recognizer.end()
                    message = Text("No problem — it's ") + Text(w.hanzi).bold() + Text(" (\(w.pinyin)). We'll come back to it.")
                    skip()
                }
                .font(.nunito(14, .bold)).foregroundStyle(Color.muted)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.line, lineWidth: 1))
                .disabled(answered)
                .padding(.top, 6)
            } else {
                // no recogniser here (or it's not allowed): keep the practice, self-marked
                Text("Say it aloud, then mark yourself.").font(.nunito(12.8)).foregroundStyle(Color.muted).padding(.top, 8)
                Button { guard !answered else { return }; message = ok("✓ Nice"); mood = true; settle(true) } label: {
                    Label("I said it", systemImage: "speaker.wave.2.fill")
                        .font(.nunitoXB(16.8)).foregroundStyle(Color.onAccent)
                        .padding(.horizontal, 24).padding(.vertical, 13)
                        .background(Color.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(PressDown(depth: 4))
                .background(Color.accentDark, in: RoundedRectangle(cornerRadius: 14, style: .continuous).offset(y: 4))
                .disabled(answered)
                message.map { $0.font(.nunito(15)).padding(.top, 4) }
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear { canCheck = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))?.isAvailable ?? false }
        .onDisappear { recognizer.end() }
    }

    private func ok(_ t: String) -> Text { Text(t).foregroundColor(.good).bold() }
    private func bad(_ t: String) -> Text { Text(t).foregroundColor(.again).bold() }
    private func quiet(_ t: String) -> Text { Text(t).foregroundColor(.muted) }

    private func listen() {
        guard !answered, !listening else { return }
        let say = ex.sayHanzi, key = ex.card.word.hanzi
        var gotResult = false
        message = nil
        listening = true
        recognizer.onInterim = { alts in if !answered, let a = alts.first { message = quiet("…" + a) } }
        recognizer.acceptEarly = { SpeechScore.saidWhole(say, $0) }
        recognizer.onResult = { alts in
            gotResult = true
            tries += 1
            let r = SpeechScore.score(say, alts, keyword: key)
            switch r.level {
            case .exact:
                message = ok("✓ Perfect"); mood = true; settle(true)
            case .close:
                message = ok("✓ Got it") + quiet(" — heard “\(r.heard)”"); mood = true; settle(true)
            case .no where tries < maxTries:
                message = quiet("Heard “\(r.heard.isEmpty ? "…" : r.heard)” — give it one more go.")
            case .no:
                message = bad("Not quite") + quiet(" — heard “\(r.heard.isEmpty ? "…" : r.heard)”. It's ")
                    + Text(say).bold().foregroundColor(.ink) + quiet(" (\(ex.sayPinyin)).")
                mood = false; settle(false)
            }
        }
        // a mic failure isn't a wrong answer: let them try again
        recognizer.onError = { f in
            switch f {
            case .notAllowed: message = bad("Allow the microphone and speech recognition in Settings to use this.")
            default: message = quiet("Didn't catch that — tap and try again.")
            }
        }
        recognizer.onEnd = {
            listening = false
            if !gotResult && message == nil { message = quiet("Didn't catch that — tap and try again.") }
        }
        recognizer.start()
    }
}
