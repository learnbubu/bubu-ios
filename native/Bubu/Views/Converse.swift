import SwiftUI
import AVFoundation

/// Speaking, as WeChat voice notes (the owner, 23 Oct 2026: "we chat could be cool"): your chats with 步步, one for each
/// of the course's conversations. He sends his lines as voice notes, their words under them (转文字, as WeChat turns a
/// voice note into text); you hold 按住 说话 and say yours, and send it as a voice note of your own, the characters going
/// green as he hears them. A chat whose words you haven't learnt is there to listen to. WeChat's own look: its grey,
/// its white and green bubbles. Light only.
struct ConversePage: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var rows: [Row] = []
    @State private var record = ChatRecord.shared
    private let course = Course.shared

    struct Row: Identifiable { let d: Dialogue; let open: Bool; var id: String { d.id } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                if rows.isEmpty { ProgressView().frame(maxWidth: .infinity).padding(.top, 60) }
                LazyVStack(spacing: 0) {
                    ForEach(rows) { r in
                        Button { router.push(.chat(r.d.id)) } label: { row(r) }
                            .buttonStyle(CardPress())
                    }
                }
                .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Home.line, lineWidth: 1.5))
            }
            .padding(.horizontal, 18).padding(.top, 4).padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Home.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .environment(\.colorScheme, .light)
        .onAppear {
            // (worked out once: whether each is yours to say looks through its words)
            let met = { (id: String) in progress.srs[id] != nil }
            let all = course.data.dialogues.map { Row(d: $0, open: course.dialogueUnlocked($0) { met($0) }) }
            rows = all.filter(\.open) + all.filter { !$0.open }
        }
    }

    private var header: some View {
        ZStack(alignment: .topLeading) {
            BackPill(label: "Classroom") { dismiss() }
            VStack(alignment: .leading, spacing: 2) {
                Text("Speaking").font(.nunito(34, .black)).tracking(-0.5).foregroundStyle(Home.ink)
                Text("Chat with 步步 in voice messages").font(.nunito(14.5, .bold)).foregroundStyle(Home.muted)
            }
            .frame(maxHeight: .infinity, alignment: .bottom).padding(.leading, 2).padding(.bottom, 12)
            Image("panda-speaking").resizable().scaledToFit().frame(height: 100)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.bottom, 8).allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 124)
    }

    /// A chat in the list, as WeChat's: his photo, the conversation's name, its first line, and on the right its lesson
    /// and how it went (stars), a red dot on the next one to have, or a lock.
    private func row(_ r: Row) -> some View {
        let next = r.open && !record.done(r.d.id) && rows.first(where: { $0.open && !record.done($0.d.id) })?.id == r.id
        return HStack(spacing: 12) {
            Image("chat-bubu").resizable().scaledToFill().frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if next { Circle().fill(Color(UIColor(hex: 0xFA5151))).frame(width: 12, height: 12).offset(x: 4, y: -4) }
                }
                .opacity(r.open ? 1 : 0.55)
            VStack(alignment: .leading, spacing: 2) {
                Text(r.d.title).font(.nunito(16, .black)).foregroundStyle(Home.ink).lineLimit(1)
                Text(r.d.turns.first?.hanzi ?? "").font(.hanzi(13.5)).foregroundStyle(Home.muted).lineLimit(1)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 3) {
                Text(r.d.lesson).font(.nunito(11.5, .bold)).foregroundStyle(Color(UIColor(hex: 0xA6A6A6))).lineLimit(1)
                if !r.open {
                    Image(systemName: "lock.fill").font(.system(size: 12)).foregroundStyle(Color(UIColor(hex: 0xB8B8B8)))
                } else if let s = record.stars(r.d.id) {
                    Text(String(repeating: "★", count: s) + String(repeating: "☆", count: 3 - s))
                        .font(.system(size: 12, weight: .bold)).foregroundStyle(Color(UIColor(hex: 0xE0A82E)))
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .overlay(alignment: .bottom) { Rectangle().fill(Color(UIColor(hex: 0xEFEFEF))).frame(height: 1).padding(.leading, 74) }
        .contentShape(Rectangle())
        .accessibilityLabel("\(r.d.title)\(r.open ? "" : ", locked: listen only")")
    }
}

/// How your chats went, kept between launches: which are done, and the most stars each got.
@Observable
final class ChatRecord {
    static let shared = ChatRecord()
    private static let key = "bubu.chats"
    private var best: [String: Int]
    init() { best = (UserDefaults.standard.dictionary(forKey: Self.key) as? [String: Int]) ?? [:] }
    func done(_ id: String) -> Bool { best[id] != nil }
    func stars(_ id: String) -> Int? { best[id] }
    func finished(_ id: String, stars: Int) {
        best[id] = max(best[id] ?? 0, stars)
        if !Launch.underTests { UserDefaults.standard.set(best, forKey: Self.key) }
    }
}

// MARK: - a chat

/// A chat with 步步: his voice notes play one by one, each with its words under it; then your turn, the line to say on a
/// card above the bar. Hold 按住 说话 and say it: the characters go green as they're heard; let go to send it (slide up to
/// cancel). Heard, it goes as your voice note (tap to hear yourself) and he carries on; not, he asks again, and after
/// two tries you can skip it. Kept as a session (StudySession.chatting): each line counts, and the chat ends on the
/// lesson's done screen.
struct ChatPage: View {
    let dialogueId: String
    @Environment(ProgressStore.self) private var progress
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var dialogue: Dialogue?
    @State private var listenOnly = false
    @State private var session: StudySession?
    @State private var msgs: [Msg] = []
    @State private var turn = 0
    @State private var waiting = false          // your turn: the reply card and the bar
    @State private var playing: UUID?
    @State private var tries = 0
    @State private var misses = 0               // lines not said first time (the stars)
    @State private var recognizer = Recognizer()
    @State private var holding = false
    /// a finger on the button (one hold, one message, however long)
    @State private var pressed = false
    @State private var cancelling = false
    @State private var heldAt = Date()
    @State private var level: CGFloat = 0
    @State private var interim: [SpeechScore.Mark] = []
    @State private var recording: URL?
    @State private var note: String?
    @State private var player: AVAudioPlayer?
    @State private var run = 0
    @State private var quitAsk = false
    @State private var handedOn = false
    @State private var ended = false
    private let course = Course.shared

    struct Msg: Identifiable, Equatable {
        enum Kind: Equatable { case bubu, you(ok: Bool), ask }
        let id = UUID()
        let kind: Kind
        let turn: Turn
        let seconds: Double
        var file: URL? = nil
        var marks: [SpeechScore.Mark] = []
    }

    static let wxBg = Color(UIColor(hex: 0xEDEDED))
    static let wxGreen = Color(UIColor(hex: 0x95EC69))

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollViewReader { reader in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        Text("今天").font(.nunito(12, .bold)).foregroundStyle(Color(UIColor(hex: 0x9A9A9A))).padding(.top, 10)
                        ForEach(msgs) { m in message(m).id(m.id) }
                        Color.clear.frame(height: 4).id("end")
                    }
                    .padding(.horizontal, 12).padding(.bottom, 10)
                }
                .scrollIndicators(.hidden)
                .onChange(of: msgs.count) { _, _ in withAnimation(.easeOut(duration: 0.25)) { reader.scrollTo("end", anchor: .bottom) } }
                .onChange(of: waiting) { _, _ in withAnimation(.easeOut(duration: 0.25)) { reader.scrollTo("end", anchor: .bottom) } }
            }
            .overlay { if holding { recordingOverlay } }
            if waiting, let t = currentTurn { replyCard(t).transition(.move(edge: .bottom).combined(with: .opacity)) }
            bar
        }
        .background(Self.wxBg.ignoresSafeArea())
        .overlay {
            if quitAsk {
                QuitAsk(keep: { withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { quitAsk = false } },
                        quit: { quitAsk = false; dismiss() },
                        line: "Your lines so far are saved, but you'll miss the end of the chat and its XP.", end: "End chat")
                    .transition(.opacity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .environment(\.colorScheme, .light)
        .sensoryFeedback(.impact(weight: .medium), trigger: holding) { _, on in on }
        .onAppear {
            progress.holdLevelUps = true
            guard dialogue == nil, let d = course.data.dialogues.first(where: { $0.id == dialogueId }) else { return }
            dialogue = d
            listenOnly = !course.dialogueUnlocked(d) { progress.srs[$0] != nil }
            if !listenOnly { session = StudySession.chatting(progress, d) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { step() }
        }
        .onDisappear {
            run += 1
            recognizer.end(); Speech.shared.stop(); player?.stop()
            guard !handedOn else { return }
            progress.holdLevelUps = false; progress.showHeldLevelUp()
        }
    }

    private var currentTurn: Turn? { dialogue.flatMap { turn < $0.turns.count ? $0.turns[turn] : nil } }
    private var yourLines: Int { dialogue?.turns.filter { $0.who == "you" }.count ?? 0 }
    private var saidLines: Int { msgs.filter { if case .you = $0.kind { return true } else { return false } }.count }

    // MARK: the chat's top, as WeChat's

    private var navBar: some View {
        ZStack {
            VStack(spacing: 0) {
                Text("步步").font(.hanzi(17, .semibold)).foregroundStyle(Color.black)
                Text(dialogue?.title ?? "").font(.nunito(11.5, .bold)).foregroundStyle(Color(UIColor(hex: 0x8A8A8A))).lineLimit(1)
            }
            .padding(.horizontal, 80)
            HStack {
                Button {
                    if msgs.contains(where: { if case .you = $0.kind { return true } else { return false } }) && !ended && !listenOnly {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { quitAsk = true }
                    } else { dismiss() }
                } label: {
                    Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold)).foregroundStyle(Color.black)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                Spacer()
                Text(listenOnly ? "🔒" : "\(saidLines) / \(yourLines)").font(.nunito(13, .heavy)).monospacedDigit()
                    .foregroundStyle(Color(UIColor(hex: 0x8A8A8A))).padding(.trailing, 10)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 50)
        .background(Self.wxBg)
        .overlay(alignment: .bottom) { Rectangle().fill(Color(UIColor(hex: 0xDCDCDC))).frame(height: 0.5) }
    }

    // MARK: messages

    @ViewBuilder
    private func message(_ m: Msg) -> some View {
        switch m.kind {
        case .bubu:
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    avatar
                    voiceBubble(m, mine: false)
                    if playing != m.id && m.id == msgs.last(where: { $0.kind == .bubu })?.id && !waiting {
                        Circle().fill(Color(UIColor(hex: 0xFA5151))).frame(width: 7, height: 7).padding(.top, 17)
                    }
                    Spacer(minLength: 40)
                }
                transcript(m.turn).padding(.leading, 50)
            }
        case .ask:
            HStack(alignment: .top, spacing: 8) {
                avatar
                VStack(alignment: .leading, spacing: 2) {
                    Text("没听清，再说一次？").font(.hanzi(16)).foregroundStyle(Color.black)
                    Text("I didn't catch that. Say it again?").font(.nunito(12.5, .bold)).foregroundStyle(Color(UIColor(hex: 0x8A8A8A)))
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Color.white, in: BubbleTail(left: true))
                Spacer(minLength: 40)
            }
        case .you(let ok):
            VStack(alignment: .trailing, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    Spacer(minLength: 40)
                    Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.system(size: 17)).foregroundStyle(ok ? Color(UIColor(hex: 0x1F8A6D)) : Color(UIColor(hex: 0xFA5151)))
                        .padding(.top, 11)
                    voiceBubble(m, mine: true)
                    meAvatar
                }
                if !m.marks.isEmpty {
                    marksText(m.marks, size: 16).padding(.trailing, 50)
                } else if m.file == nil {
                    // (said for you: listening only, or a line skipped) its words, as his have
                    transcript(m.turn).padding(.trailing, 50)
                }
            }
        }
    }

    private var avatar: some View {
        Image("chat-bubu").resizable().scaledToFill().frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var meAvatar: some View {
        Text("我").font(.hanzi(17, .semibold)).foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(Home.teal, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    /// A voice note, as WeChat draws them: as long as it is, its seconds, and the sound waves (moving while it plays).
    private func voiceBubble(_ m: Msg, mine: Bool) -> some View {
        let w = min(210, 72 + CGFloat(m.seconds) * 18)
        let on = playing == m.id
        return Button { play(m) } label: {
            HStack(spacing: 6) {
                if mine {
                    Text("\(max(1, Int(m.seconds.rounded())))″").font(.nunito(15, .bold)).foregroundStyle(Color.black)
                    Spacer(minLength: 0)
                    Image(systemName: "wave.3.left").font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.black)
                        .symbolEffect(.variableColor.iterative.reversing, isActive: on)
                } else {
                    Image(systemName: "wave.3.right").font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.black)
                        .symbolEffect(.variableColor.iterative.reversing, isActive: on)
                    Spacer(minLength: 0)
                    Text("\(max(1, Int(m.seconds.rounded())))″").font(.nunito(15, .bold)).foregroundStyle(Color.black)
                }
            }
            .padding(.horizontal, 13)
            .frame(width: w, height: 40)
            .background(mine ? Self.wxGreen : Color.white, in: BubbleTail(left: !mine))
        }
        .buttonStyle(CardPress())
        .accessibilityLabel(mine ? "Your voice message, \(Int(m.seconds.rounded())) seconds. Play it" : "步步's voice message: \(m.turn.en). Play it")
    }

    /// The words of his voice note (WeChat's 转文字): the characters, their pinyin, what it means.
    private func transcript(_ t: Turn) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ToneText(hanzi: t.hanzi, pinyin: t.pinyin, size: 18, weight: .medium)
            PinyinText(pinyin: t.pinyin, size: 12.5, weight: .semibold)
            Text(t.en).font(.nunito(12.5, .bold)).foregroundStyle(Color(UIColor(hex: 0x8A8A8A)))
        }
        .padding(.horizontal, 11).padding(.vertical, 8)
        .frame(maxWidth: 270, alignment: .leading)
        .background(Color.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(alignment: .leading) { Rectangle().fill(Home.teal).frame(width: 3).clipShape(Capsule()) }
    }

    /// What was heard of a line: each character green if it was, grey if not.
    private func marksText(_ marks: [SpeechScore.Mark], size: CGFloat) -> some View {
        marks.reduce(Text("")) { t, m in
            t + Text(String(m.char)).foregroundColor(m.heard == false ? Color(UIColor(hex: 0xB0B0B0)) : m.heard == true ? Color(UIColor(hex: 0x1F8A6D)) : Color.black)
        }
        .font(.hanzi(size, .medium))
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    // MARK: your turn

    /// The line to say, over the bar: green as it's heard while you hold.
    private func replyCard(_ t: Turn) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(t.free == true ? "SAY IT YOUR WAY · A VOICE MESSAGE" : "REPLY WITH A VOICE MESSAGE")
                    .font(.nunito(11, .black)).tracking(1.2).foregroundStyle(Color(UIColor(hex: 0x8A8A8A)))
                Spacer()
                Button { Speech.shared.speak(t.hanzi) } label: {
                    Image(systemName: "speaker.wave.2.fill").font(.system(size: 14)).foregroundStyle(Home.teal)
                        .frame(width: 32, height: 32).background(Home.tealSoft, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Hear it")
            }
            Group {
                if interim.isEmpty { ToneText(hanzi: t.hanzi, pinyin: t.pinyin, size: 24, weight: .medium) }
                else { marksText(interim, size: 24).padding(-10) }
            }
            PinyinText(pinyin: t.pinyin, size: 14, weight: .semibold)
            Text(t.en).font(.nunito(13.5, .bold)).foregroundStyle(Color(UIColor(hex: 0x6A6A6A)))
            if let note {
                Text(note).font(.nunito(13, .bold)).foregroundStyle(Color(UIColor(hex: 0xE0574A))).padding(.top, 2)
            }
            if tries >= 2 {
                Button("Skip this line") { skip(t) }
                    .font(.nunito(14, .black)).foregroundStyle(Home.teal).padding(.top, 4)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .padding(.horizontal, 10).padding(.bottom, 8)
    }

    /// WeChat's bar: hold to talk (once it's your turn), or a word while he's talking.
    private var bar: some View {
        HStack(spacing: 10) {
            if listenOnly {
                Text(ended ? "End of the chat" : "🔒 Learn its words to reply. Listening for now")
                    .font(.nunito(14, .bold)).foregroundStyle(Color(UIColor(hex: 0x8A8A8A)))
                    .frame(maxWidth: .infinity).frame(height: 44)
            } else {
                Text(holding ? (cancelling ? "松开 取消" : "松开 发送") : "按住 说话")
                    .font(.hanzi(16, .semibold)).foregroundStyle(Color.black.opacity(waiting ? 1 : 0.35))
                    .overlay(alignment: .bottom) {
                        Text(holding ? (cancelling ? "Let go to cancel" : "Let go to send") : waiting ? "Hold to talk" : "步步 is talking…")
                            .font(.nunito(10.5, .bold)).foregroundStyle(Color(UIColor(hex: 0x8A8A8A))).fixedSize().offset(y: 14)
                    }
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity).frame(height: holding ? 58 : 46)
                    .background(holding ? Color(UIColor(hex: 0xC6C6C6)) : Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            guard waiting else { return }
                            if !pressed { pressed = true; startTalking() }
                            cancelling = v.translation.height < -70
                        }
                        .onEnded { _ in pressed = false; if holding { stopTalking() } })
                    .accessibilityLabel("Hold to talk")
                    .accessibilityAddTraits(.isButton)
            }
        }
        .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 10)
        .background(Color(UIColor(hex: 0xF7F7F7)).ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(Color(UIColor(hex: 0xDCDCDC))).frame(height: 0.5) }
        .animation(.easeOut(duration: 0.15), value: holding)
    }

    /// While you hold: the chat dimmed, a green voice bubble moving with your voice, the line filling in as it's heard,
    /// and the place to slide to, to cancel.
    private var recordingOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)
            VStack(spacing: 18) {
                Waveform(level: level, bars: 15)
                    .foregroundStyle(Color(UIColor(hex: 0x2A2A2A)))
                    .padding(.horizontal, 26).padding(.vertical, 18)
                    .background(cancelling ? Color(UIColor(hex: 0xFA5151)) : Self.wxGreen, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                if !interim.isEmpty {
                    marksText(interim, size: 24)
                }
                Spacer().frame(height: 30)
                Image(systemName: "xmark").font(.system(size: 20, weight: .bold)).foregroundStyle(cancelling ? Color.black : Color.white)
                    .frame(width: 68, height: 68)
                    .background(cancelling ? Color.white : Color.white.opacity(0.22), in: Circle())
                Text(cancelling ? "Let go to cancel" : "Slide up here to cancel").font(.nunito(12.5, .bold)).foregroundStyle(.white)
            }
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    // MARK: the flow

    /// His lines play one after another, each as a voice note; at yours it waits for you.
    private func step() {
        guard let d = dialogue else { return }
        guard turn < d.turns.count else { return finish() }
        let t = d.turns[turn]
        if t.who == "you" && !listenOnly {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { waiting = true }
            return
        }
        // his line, or (listening only) yours said for you
        let m = Msg(kind: t.who == "you" ? .you(ok: true) : .bubu, turn: t, seconds: Self.seconds(t.hanzi))
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { msgs.append(m) }
        play(m)
        turn += 1
        let r = run
        DispatchQueue.main.asyncAfter(deadline: .now() + m.seconds + 0.7) { if run == r { step() } }
    }

    /// How long a line's voice note is: its clip's, or about a third of a second a character.
    static func seconds(_ text: String) -> Double {
        if let url = Speech.clipURL(text), let p = try? AVAudioPlayer(contentsOf: url) { return p.duration }
        return 0.4 + Double(text.filter(Course.isHan).count) * 0.3
    }

    private func play(_ m: Msg) {
        player?.stop()
        if let f = m.file {
            Sounds.shared.activate()
            player = try? AVAudioPlayer(contentsOf: f)
            player?.play()
        } else {
            Speech.shared.speak(m.turn.hanzi)
        }
        playing = m.id
        let id = m.id
        DispatchQueue.main.asyncAfter(deadline: .now() + m.seconds + 0.1) { if playing == id { playing = nil } }
    }

    private func startTalking() {
        guard let t = currentTurn else { return }
        Speech.shared.stop(); player?.stop()
        holding = true; cancelling = false; interim = []; note = nil; level = 0; heldAt = Date()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("bubu-say-\(UUID().uuidString).caf")
        recording = url
        recognizer.recordTo = url
        recognizer.settlesOnPause = false
        recognizer.onLevel = { level = CGFloat($0) }
        recognizer.onInterim = { alts in interim = SpeechScore.marks(t.hanzi, alts) }
        recognizer.acceptEarly = { _ in false }       // (it waits for you to let go)
        recognizer.onResult = { alts in judge(t, alts) }
        recognizer.onError = { f in
            // (each counts as a try, so a line can always be skipped: with the microphone off, at once; the Mac, 23 Oct 2026)
            switch f {
            case .notAllowed:
                note = "No problem: skip it for now, or allow the microphone and speech recognition in Settings to talk."
                tries = max(tries, 2)
            case .unavailable:
                note = "Speech recognition isn't available right now. Try again in a moment."
                tries += 1
            case .noSpeech:
                guard !cancelling else { return }
                note = "I didn't hear anything. Hold the button and speak."
                tries += 1
            }
        }
        recognizer.onEnd = { withAnimation(.easeOut(duration: 0.15)) { holding = false } }
        recognizer.start()
    }

    private func stopTalking() {
        if cancelling {
            recognizer.onResult = { _ in }
            recognizer.end()
            interim = []
        } else {
            recognizer.settle()
        }
    }

    private func judge(_ t: Turn, _ alts: [String]) {
        let ok = t.free == true ? !alts.isEmpty : SpeechScore.passes(t.hanzi, alts, keyword: nil)
        let marks = t.free == true ? [] : SpeechScore.marks(t.hanzi, alts)
        let m = Msg(kind: .you(ok: ok), turn: t, seconds: max(1, Date().timeIntervalSince(heldAt)), file: recording, marks: marks)
        interim = []
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { msgs.append(m) }
        if ok {
            Sounds.shared.play("correct")
            session?.spoke(right: true)
            if tries > 0 { misses += 1 }
            next()
        } else {
            Sounds.shared.play("wrong")
            tries += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { msgs.append(Msg(kind: .ask, turn: t, seconds: 0)) }
            }
        }
    }

    private func skip(_ t: Turn) {
        session?.spoke(right: false)
        misses += 1
        // (the line said for you, as a note of yours with its words, so the chat still reads through)
        let m = Msg(kind: .you(ok: false), turn: t, seconds: Self.seconds(t.hanzi))
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { msgs.append(m) }
        play(m)
        next()
    }

    /// On to his next line.
    private func next() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { waiting = false }
        tries = 0; note = nil
        turn += 1
        let r = run
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { if run == r { step() } }
    }

    /// The end: listening only, the chat simply ends; else its stars kept, and the lesson's done screen over it.
    private func finish() {
        ended = true
        guard let d = dialogue, let s = session, !listenOnly else { return }
        ChatRecord.shared.finished(d.id, stars: misses == 0 ? 3 : misses <= 2 ? 2 : 1)
        s.finishFlashcards()
        handedOn = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            router.study = s
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { dismiss() }
            }
        }
    }
}

/// A chat bubble with WeChat's little point by the photo.
struct BubbleTail: Shape {
    var left: Bool
    func path(in r: CGRect) -> Path {
        var p = Path(roundedRect: r, cornerRadius: 5, style: .continuous)
        let y: CGFloat = 20, h: CGFloat = 6
        if left {
            p.move(to: CGPoint(x: r.minX, y: y - h)); p.addLine(to: CGPoint(x: r.minX - 6, y: y)); p.addLine(to: CGPoint(x: r.minX, y: y + h))
        } else {
            p.move(to: CGPoint(x: r.maxX, y: y - h)); p.addLine(to: CGPoint(x: r.maxX + 6, y: y)); p.addLine(to: CGPoint(x: r.maxX, y: y + h))
        }
        p.closeSubpath()
        return p
    }
}
