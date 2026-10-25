import SwiftUI
import AVFoundation

/// Speaking, as WeChat voice notes (the owner, 23 Oct 2026: "we chat could be cool"): your chats with 步步, one for each
/// of the course's conversations. He sends his lines as voice notes, their words under them (转文字, as WeChat turns a
/// voice note into text); you hold 按住 说话 and say yours, and send it as a voice note of your own, the characters going
/// green as he hears them. A chat whose words you haven't learnt is there to listen to. WeChat's shape in the app's own
/// look (the owner, 23 Oct 2026: "look like WeChat, but still have our style"): cream, round photos, soft raised
/// bubbles in our greens, the round back button and count pill, a raised teal Hold to talk. Light only.
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
                .background(ChatLook.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Home.line, lineWidth: 1.5))
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
                Text("Voice chats with friends").font(.nunito(14.5, .bold)).foregroundStyle(Home.muted)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            // (clear of the panda on the right, on any phone: the longer line ran into it; the Mac, 23 Oct 2026)
            .padding(.trailing, 96)
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
            ChatGroupPhoto(members: ChatCast.members(r.d), size: 48)
                .overlay(alignment: .topTrailing) {
                    if next { Circle().fill(Color(UIColor(hex: 0xFA5151))).frame(width: 12, height: 12).offset(x: 4, y: -4) }
                }
                .opacity(r.open ? 1 : 0.55)
            VStack(alignment: .leading, spacing: 2) {
                Text(r.d.title).font(.nunito(16, .black)).foregroundStyle(Home.ink).lineLimit(1)
                Text(ChatCast.preview(r.d)).font(.hanzi(13.5)).foregroundStyle(Home.muted).lineLimit(1)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 3) {
                Text(r.d.lesson).font(.nunito(11.5, .bold)).foregroundStyle(ChatLook.faint).lineLimit(1)
                if !r.open {
                    Image(systemName: "lock.fill").font(.system(size: 12)).foregroundStyle(ChatLook.faint)
                } else if let s = record.stars(r.d.id) {
                    Text(String(repeating: "★", count: s) + String(repeating: "☆", count: 3 - s))
                        .font(.system(size: 12, weight: .bold)).foregroundStyle(Color(UIColor(hex: 0xE0A82E)))
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .overlay(alignment: .bottom) { Rectangle().fill(ChatLook.rule).frame(height: 1).padding(.leading, 74) }
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
/// A chat inside a lesson (a practice stone's, see StudySession.Item.chat): its lines, and the lesson told of each of
/// yours and of the end.
struct LessonChat {
    let turns: [Turn]
    /// your lines picked rather than said (speaking off)
    let picks: Bool
    let line: (Bool) -> Void
    let cantTalk: () -> Void
    let done: () -> Void
    /// holding to talk, or not: the lesson greys all round the chat's panel while you do
    var holding: (Bool) -> Void = { _ in }
}

struct ChatPage: View {
    let dialogueId: String
    /// in a lesson: its few lines, no bar of its own, set lines (never free), each of yours counted by the lesson
    var lesson: LessonChat? = nil
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
    /// speaking freely, judged by the tutor (FreeSpeech): the phone has Apple's on-phone model, and the chat's yours to say
    @State private var free = false
    /// the "Need help?" pop-up, with an example
    @State private var showExample = false
    /// what's heard as you speak freely
    @State private var interimText = ""
    /// the lines played: the chat's, or the lesson's few
    @State private var turns: [Turn] = []
    /// your lines picked from three, not said (in a lesson, speaking off)
    @State private var picking = false
    @State private var options: [Turn] = []
    @State private var wrongPicks: Set<String> = []
    /// the chat's end, celebrated (its confetti)
    @State private var cheer = 0
    /// the audio held for the microphone by this chat (let go of on leaving, only if it was)
    @State private var heldAudio = false
    /// the chat's visible height (a short chat fills it from the top)
    @State private var viewport: CGFloat = 0
    /// the reply card's height (it grows with a note under it)
    @State private var footHeight: CGFloat = 0
    /// the latest scroll asked for (only the last of a burst runs)
    @State private var scrollAsk = 0
    private let course = Course.shared

    struct Msg: Identifiable, Equatable {
        /// (`you` with ok nil: being judged; `tutor`: 步步's feedback on what you said freely; `thinking`: 步步 judging it)
        enum Kind: Equatable { case bubu, you(ok: Bool?), ask, tutor(SpeakingVerdict), thinking }
        let id = UUID()
        var kind: Kind
        let turn: Turn
        let seconds: Double
        var file: URL? = nil
        var marks: [SpeechScore.Mark] = []
        /// what was heard, said freely (shown under your note)
        var heard: String? = nil
    }


    var body: some View {
        VStack(spacing: 0) {
            if lesson == nil {
                VStack(spacing: 0) {
                    navBar
                    // (where the messages go under: the owner, 23 Oct 2026)
                    Rectangle().fill(Home.line).frame(height: 1).opacity(0.8)
                }
                // (greyed with the rest while you hold)
                .overlay { holdDim.opacity(holding ? 1 : 0).allowsHitTesting(false) }
            }
            ScrollViewReader { reader in
                ScrollView {
                    // (all of it laid out: lazily, messages were measured as they came into view and the chat
                    // jumped, the owner's phone, 24 Oct 2026; a chat is short)
                    VStack(spacing: 10) {
                        Text("今天").font(.hanzi(11.5, .semibold)).tracking(1.5).foregroundStyle(ChatLook.faint).padding(.top, 10)
                        ForEach(msgs) { m in
                            message(m).id(m.id)
                                // (each new message rises a little as it fades in, as WeChat's: smoother than appearing)
                                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.96, anchor: .bottom)),
                                                        removal: .opacity))
                        }
                        Color.clear.frame(height: 4).id("end")
                    }
                    .padding(.horizontal, 12).padding(.bottom, 10)
                    // (a short chat from the top, as WeChat's, and still as the card comes and goes; a long one kept at
                    // its foot: a short one sank to the middle and sprang back each turn, the owner's video, 25 Oct 2026)
                    .frame(minHeight: viewport, alignment: .top)
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewport = $0 }
                .scrollIndicators(.hidden)
                // (kept at the foot as things grow: no jumping, the owner's phone, 23 Oct 2026)
                .defaultScrollAnchor(.bottom)
                .modifier(KeepsFoot())
                .onChange(of: msgs.count) { _, _ in toEnd(reader) }
                .onChange(of: waiting) { _, _ in toEnd(reader) }
                // the reply card growing (a note under it) or the chat ending (Continue's bar): the latest kept in
                // view, not left under them (the Mac, 0.2.22)
                .onChange(of: footHeight) { _, _ in toEnd(reader) }
                .onChange(of: ended) { _, _ in toEnd(reader) }
            }
            // (holding: over the messages, the reply card left in sight, what to say: as the first, which felt like
            // WeChat; over the card too, what to say was gone; the owner, 24 Oct 2026)
            // (its own plain ground under the hold's grey, so it's greyed once, as the page is: not twice)
            .background(Home.bg)
            .overlay { if holding { recordingOverlay.zIndex(2) } }
            // the reply card. (Its room was kept between turns, against a jump, and left the chat stuck up top with a gap
            // under it while they talked: the owner, 24 Oct 2026. Now the chat keeps to its foot as the card comes and
            // goes, gliding with it, as WeChat's does: see keepsFoot.)
            ZStack(alignment: .bottom) {
                if waiting, let t = currentTurn {
                    Group { if picking { pickCard(t) } else if free { freeCard(t) } else { replyCard(t) } }
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { footHeight = $0 }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, alignment: .bottom)
            if !picking || ended { bar }
        }
        // (holding: the whole page greyed, edge to edge, the card and the button left bright on it; the owner, 25 Oct
        // 2026. Always there, only fading: put in and taken out, it rebuilt the button under the finger, the hold broke
        // and began again, and the colours flickered)
        .background {
            ZStack {
                Home.bg
                holdDim.opacity(holding ? 1 : 0)
            }
            .ignoresSafeArea()
        }
        // (its own layer over the whole chat, sized to it: in an overlay it never showed, the Mac, 0.2.22)
        .overlay {
            ZStack {
                if cheer > 0 { Confetti(count: 40).id(cheer) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
            .zIndex(10)
        }
        // (rounded in a lesson's panel; not clipped at all on its own page, or the hold's grey stopped short of the
        // status bar and the foot: the owner, 25 Oct 2026)
        .modifier(PanelClip(on: lesson != nil))
        .onChange(of: holding) { _, h in lesson?.holding(h) }
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
            guard dialogue == nil, let d = course.data.dialogues.first(where: { $0.id == dialogueId }) else { return }
            dialogue = d
            if let lesson {
                // (the lesson holds level-ups and keeps the score)
                turns = lesson.turns
                picking = lesson.picks
                // the chat before the lines you're in, already there (it's how 小雨 knows you're 马克: the owner, 24 Oct
                // 2026, "they ask for Mark's last name, but then know his first name?")
                if let first = lesson.turns.first, let at = d.turns.firstIndex(of: first) {
                    msgs = d.turns[..<at].map { Msg(kind: $0.who == "you" ? .you(ok: true) : .bubu, turn: $0, seconds: Self.seconds($0.hanzi, speaker: ChatCast.voice($0))) }
                }
                startAudio(mic: !picking)
                return
            }
            progress.holdLevelUps = true
            turns = d.turns
            listenOnly = !course.dialogueUnlocked(d) { progress.srs[$0] != nil }
            free = FreeSpeech.available && !listenOnly
            if !listenOnly { session = StudySession.chatting(progress, d) }
            startAudio(mic: !listenOnly)
        }
        .onDisappear {
            run += 1
            recognizer.end(); Speech.shared.stop(); player?.stop()
            if heldAudio { Sounds.shared.holdForRecording(false); heldAudio = false }
            guard !handedOn, lesson == nil else { return }
            progress.holdLevelUps = false; progress.showHeldLevelUp()
        }
    }

    /// The microphone asked for and the audio set for recording, once, not at every press; then the first line (not
    /// before: switching the audio over cut it off, the owner's phone, 24 Oct 2026).
    private func startAudio(mic: Bool) {
        let r = run
        Task { @MainActor in
            if mic, await Recognizer.authorize(), run == r { Sounds.shared.holdForRecording(true); heldAudio = true }
            try? await Task.sleep(for: .milliseconds(450))
            if run == r { step() }
        }
    }

    private var currentTurn: Turn? { turn < turns.count ? turns[turn] : nil }
    private var yourLines: Int { turns.filter { $0.who == "you" }.count }
    private var saidLines: Int { msgs.filter { if case .you = $0.kind { return true } else { return false } }.count }

    /// To the latest message, once, after things have settled (the reply card slid in, a card grown): a message and
    /// the card arriving together make one scroll, not two (it jumped up and down: the owner's phone, 23 Oct 2026).
    private func toEnd(_ reader: ScrollViewProxy) {
        scrollAsk += 1
        let n = scrollAsk
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard n == scrollAsk else { return }
            withAnimation(.easeOut(duration: 0.3)) { reader.scrollTo("end", anchor: .bottom) }
        }
    }

    // MARK: the chat's top, as WeChat's

    /// The app's page bar: the round back button, 步步 (online) and the conversation's name, and how many of your
    /// lines are said, in a pill.
    private var navBar: some View {
        PageBar(title: "", onBack: {
            if msgs.contains(where: { if case .you = $0.kind { return true } else { return false } }) && !ended && !listenOnly {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { quitAsk = true }
            } else { dismiss() }
        }, ground: Home.bg) {
            BarCount(text: listenOnly ? "🎧" : "\(saidLines) / \(yourLines)")
        }
        .overlay {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Circle().fill(ChatLook.online).frame(width: 8, height: 8)
                    Text(dialogue.map(ChatCast.chatName) ?? "").font(.hanzi(17, .bold)).foregroundStyle(Home.ink)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                Text(dialogue?.title ?? "").font(.nunito(11.5, .heavy)).foregroundStyle(Home.muted).lineLimit(1)
            }
            .padding(.horizontal, 110)
            .allowsHitTesting(false)
        }
    }

    // MARK: messages

    @ViewBuilder
    private func message(_ m: Msg) -> some View {
        switch m.kind {
        case .bubu:
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    ChatPhoto(who: m.turn.name, size: 40)
                    VStack(alignment: .leading, spacing: 3) {
                        if isGroup { speakerName(m.turn.name) }
                        voiceBubble(m, mine: false)
                    }
                    if playing != m.id && m.id == msgs.last(where: { $0.kind == .bubu })?.id && !waiting {
                        Circle().fill(ChatLook.red).frame(width: 7, height: 7).padding(.top, 17)
                    }
                    Spacer(minLength: 40)
                }
                transcript(m.turn).padding(.leading, 50)
            }
        case .ask:
            HStack(alignment: .top, spacing: 8) {
                ChatPhoto(who: m.turn.name, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("没听清，再说一次？").font(.hanzi(16)).foregroundStyle(Home.ink)
                    Text("I didn't catch that. Say it again?").font(.nunito(12.5, .bold)).foregroundStyle(Home.muted)
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
                .chatBubble(mine: false)
                Spacer(minLength: 40)
            }
        case .you(let ok):
            VStack(alignment: .trailing, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    Spacer(minLength: 40)
                    if let ok {
                        Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .font(.system(size: 17)).foregroundStyle(ok ? ChatLook.heard : ChatLook.red)
                            .padding(.top, 11)
                    } else {
                        ProgressView().controlSize(.small).padding(.top, 11)
                    }
                    voiceBubble(m, mine: true)
                    meAvatar
                }
                if let heard = m.heard, !heard.isEmpty {
                    Text(heard).font(.hanzi(16, .medium)).foregroundStyle(Home.ink)
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(Home.tealSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.trailing, 50)
                } else if !m.marks.isEmpty {
                    marksText(m.marks, size: 16).padding(.trailing, 50)
                } else if m.file == nil {
                    // (said for you: listening only, or a line skipped) its words, as his have
                    transcript(m.turn).padding(.trailing, 50)
                }
            }
        case .tutor(let v):
            tutorCard(v)
        case .thinking:
            HStack(alignment: .top, spacing: 8) {
                ChatPhoto(who: nil, size: 32)
                TypingDots().padding(.horizontal, 14).padding(.vertical, 12).chatBubble(mine: false)
                Spacer(minLength: 40)
            }
            .accessibilityLabel("步步 is thinking")
        }
    }

    /// 步步's feedback on what you said freely: it works (and maybe another natural way), or almost (and how to say it).
    private func tutorCard(_ v: SpeakingVerdict) -> some View {
        HStack(alignment: .top, spacing: 8) {
            ChatPhoto(who: nil, size: 32)
            VStack(alignment: .leading, spacing: 6) {
                Text("步步 · your tutor").font(.nunito(11, .heavy)).foregroundStyle(Home.muted)
                HStack(spacing: 6) {
                    Image(systemName: v.works ? "checkmark.seal.fill" : "lightbulb.fill")
                        .foregroundStyle(v.works ? ChatLook.heard : Color(UIColor(hex: 0xE0A82E)))
                    Text(v.works ? (v.spotOn ? "Spot on!" : "That works!") : "Almost").font(.nunito(15, .black)).foregroundStyle(Home.ink)
                }
                if !v.spotOn {
                    Text(v.comment).font(.nunito(13.5, .bold)).foregroundStyle(Home.ink).fixedSize(horizontal: false, vertical: true)
                }
                // the words it's about: never characters alone (the owner, 23 Oct 2026)
                ForEach(v.words, id: \.hanzi) { w in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(w.hanzi).font(.hanzi(16, .medium)).foregroundStyle(Home.ink)
                        if let py = w.pinyin { Text(py).font(.nunito(12.5, .bold)).foregroundStyle(Color(UIColor(hex: 0xB7822E))) }
                        Text("“\(w.en)”").font(.nunito(12.5, .bold)).foregroundStyle(Home.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let b = v.better {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(v.works ? "ALSO NATURAL" : "TRY SAYING").font(.nunito(10.5, .black)).tracking(1).foregroundStyle(Home.teal)
                        HStack(alignment: .top) {
                            Text(b).font(.hanzi(18, .medium)).foregroundStyle(Home.ink).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 6)
                            Button { Speech.shared.speak(b) } label: {
                                Image(systemName: "speaker.wave.2.fill").font(.system(size: 13)).foregroundStyle(Home.teal)
                                    .frame(width: 30, height: 30).background(ChatLook.card, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Hear it")
                        }
                        if let py = v.betterPinyin, !py.isEmpty {
                            Text(py).font(.nunito(12.5, .bold)).foregroundStyle(Color(UIColor(hex: 0xB7822E)))
                        }
                    }
                    .padding(10)
                    .background(Home.tealSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(12)
            .frame(maxWidth: 300, alignment: .leading)
            .background(ChatLook.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(v.works ? ChatLook.mineLip : Color(UIColor(hex: 0xF0D9A8)), lineWidth: 1.5))
            Spacer(minLength: 16)
        }
    }

    /// Who's talking now: whoever's line came last (the bar says so while you wait).
    private var talking: String { msgs.last(where: { $0.kind == .bubu })?.turn.name ?? "步步" }

    /// More than one of the cast talking: WeChat shows each one's name over their bubbles.
    private var isGroup: Bool { dialogue.map { ChatCast.members($0).count > 1 } ?? false }

    private func speakerName(_ name: String?) -> some View {
        Text(name ?? "").font(.hanzi(11.5, .medium)).foregroundStyle(Home.muted).padding(.leading, 4)
    }

    private var meAvatar: some View {
        Text("我").font(.hanzi(17, .bold)).foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(Home.teal, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 2))
    }

    /// A voice note, as WeChat draws them: as long as it is, its seconds, and the sound waves (moving while it plays).
    private func voiceBubble(_ m: Msg, mine: Bool) -> some View {
        let w = min(210, 72 + CGFloat(m.seconds) * 18)
        let on = playing == m.id
        let ink = mine ? Home.tealDark : Home.ink
        return Button { play(m) } label: {
            HStack(spacing: 6) {
                if mine {
                    Text("\(max(1, Int(m.seconds.rounded())))″").font(.nunito(15, .black)).foregroundStyle(ink)
                    Spacer(minLength: 0)
                    Image(systemName: "wave.3.left").font(.system(size: 17, weight: .bold)).foregroundStyle(on ? Home.teal : ink)
                        .symbolEffect(.variableColor.iterative.reversing, isActive: on)
                } else {
                    Image(systemName: "wave.3.right").font(.system(size: 17, weight: .bold)).foregroundStyle(on ? Home.teal : ink)
                        .symbolEffect(.variableColor.iterative.reversing, isActive: on)
                    Spacer(minLength: 0)
                    Text("\(max(1, Int(m.seconds.rounded())))″").font(.nunito(15, .black)).foregroundStyle(ink)
                }
            }
            .padding(.horizontal, 14)
            .frame(width: w, height: 42)
            .chatBubble(mine: mine)
        }
        .buttonStyle(CardPress())
        .accessibilityLabel(mine ? "Your voice message, \(Int(m.seconds.rounded())) seconds. Play it" : "步步's voice message: \(m.turn.en). Play it")
    }

    /// A line's pinyin, a space put before a name in Latin letters that runs into it ("wǒ xìngSmith").
    static func spaced(_ py: String) -> String {
        py.replacingOccurrences(of: #"(\p{Ll})(\p{Lu}[a-z])"#, with: "$1 $2", options: .regularExpression)
    }

    /// The words of his voice note (WeChat's 转文字): the characters, their pinyin, what it means.
    private func transcript(_ t: Turn) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ToneText(hanzi: t.hanzi, pinyin: t.pinyin, size: 18, weight: .medium)
            PinyinText(pinyin: Self.spaced(t.pinyin), size: 12.5, weight: .semibold)
            Text(t.en).font(.nunito(12.5, .bold)).foregroundStyle(Home.muted)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .frame(maxWidth: 270, alignment: .leading)
        .background(ChatLook.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Home.line, lineWidth: 1.5))
    }

    /// What was heard of a line: each character green if it was, grey if not.
    private func marksText(_ marks: [SpeechScore.Mark], size: CGFloat, plain: Bool = false) -> some View {
        marks.reduce(Text("")) { t, m in
            t + Text(String(m.char)).foregroundColor(m.heard == false ? ChatLook.faint : m.heard == true ? ChatLook.heard : Home.ink)
        }
        .font(.hanzi(size, .medium))
        // (plain: the characters recoloured where they stand, as on the reply card; a box there spilt over the pinyin)
        .padding(.horizontal, plain ? 0 : 11).padding(.vertical, plain ? 0 : 6)
        .background(plain ? Color.clear : Home.tealSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: your turn

    /// Speaking freely: what to say, in English, to say your own way; what's heard as you speak; help if you want it
    /// (the owner: "a pop up you press, need help?": the example's never on the card); after two tries, skip it.
    private func freeCard(_ t: Turn) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("SAY IT YOUR WAY").font(.nunito(11, .black)).tracking(1.2).foregroundStyle(Home.teal)
                Spacer()
                Button { showExample = true } label: {
                    Label("Need help?", systemImage: "lightbulb.fill")
                        .font(.nunito(12.5, .black)).foregroundStyle(Home.teal)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Home.tealSoft, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            Text(t.en).font(.nunito(20, .black)).foregroundStyle(Home.ink).fixedSize(horizontal: false, vertical: true)
            if !interimText.isEmpty {
                Text(interimText).font(.hanzi(20, .medium)).foregroundStyle(ChatLook.heard)
            } else if tries == 0 {
                Text("Any way of saying it works: 步步 will tell you how it sounds.").font(.nunito(12.5, .bold)).foregroundStyle(Home.muted)
            }
            if let note {
                Text(note).font(.nunito(13, .bold)).foregroundStyle(ChatLook.red)
            }
            if tries >= 2 {
                Button("Skip this one") { skip(t) }
                    .font(.nunito(14, .black)).foregroundStyle(Home.teal).padding(.top, 2)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Home.line).offset(y: 4)
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(ChatLook.card)
                RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Home.line, lineWidth: 1.5)
            }
        }
        .padding(.horizontal, 12).padding(.bottom, 12)
        .sheet(isPresented: $showExample) { helpSheet(t) }
    }

    /// The pop-up help: one way of saying it, to hear (slowly too), then back to say it your way.
    private func helpSheet(_ t: Turn) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ONE WAY TO SAY IT").font(.nunito(11, .black)).tracking(1.2).foregroundStyle(Home.teal)
            Text(t.en).font(.nunito(15, .bold)).foregroundStyle(Home.muted).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 2) {
                ToneText(hanzi: t.hanzi, pinyin: t.pinyin, size: 26, weight: .medium)
                PinyinText(pinyin: Self.spaced(t.pinyin), size: 15, weight: .semibold)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Home.tealSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            HStack(spacing: 10) {
                hearButton("Hear it", "speaker.wave.2.fill") { Speech.shared.speak(t.hanzi) }
                hearButton("Slowly", "tortoise.fill") { Speech.shared.speak(t.hanzi, slow: true) }
                Spacer()
                Button { showExample = false } label: {
                    Text("Got it").font(.nunito(16, .black)).foregroundStyle(.white)
                        .padding(.horizontal, 22).padding(.vertical, 11)
                        .background(Home.teal, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            Text("Say it like this, or any way of your own.").font(.nunito(12.5, .bold)).foregroundStyle(Home.muted)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Home.bg.ignoresSafeArea())
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
    }

    private func hearButton(_ label: String, _ icon: String, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Label(label, systemImage: icon).font(.nunito(14, .black)).foregroundStyle(Home.teal)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(ChatLook.card, in: Capsule())
                .overlay(Capsule().stroke(Home.line, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    /// The line to say, over the bar: green as it's heard while you hold.
    private func replyCard(_ t: Turn) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(t.free == true ? "SAY IT YOUR WAY · A VOICE MESSAGE" : "REPLY WITH A VOICE MESSAGE")
                    .font(.nunito(11, .black)).tracking(1.2).foregroundStyle(Home.teal)
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
                else { marksText(interim, size: 24, plain: true) }
            }
            PinyinText(pinyin: Self.spaced(t.pinyin), size: 14, weight: .semibold)
            Text(t.en).font(.nunito(13.5, .bold)).foregroundStyle(Home.muted)
            if let note {
                Text(note).font(.nunito(13, .bold)).foregroundStyle(ChatLook.red).padding(.top, 2)
            }
            HStack(spacing: 18) {
                if tries >= 2 {
                    Button("Skip this line") { skip(t) }
                        .font(.nunito(14, .black)).foregroundStyle(Home.teal)
                        .buttonStyle(.plain)
                }
                if lesson != nil {
                    Button("Can't talk now") { cantTalk() }
                        .font(.nunito(14, .black)).foregroundStyle(Home.muted)
                        .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Home.line).offset(y: 4)
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(ChatLook.card)
                RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Home.line, lineWidth: 1.5)
            }
        }
        .padding(.horizontal, 12).padding(.bottom, 12)
    }

    // MARK: picking (a lesson's chat, speaking off)

    /// "Can't talk now": no more speaking this lesson; this line and the rest picked.
    private func cantTalk() {
        recognizer.end()
        lesson?.cantTalk()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { picking = true; note = nil }
    }

    /// Your line among two others of yours: from this chat, else from the course's other chats.
    private func pickOptions(_ t: Turn) -> [Turn] {
        var others: [Turn] = []
        let here = (dialogue?.turns ?? turns).shuffled()
        let more = course.data.dialogues.flatMap(\.turns).shuffled()
        for o in here + more where others.count < 2 && o.who == "you" && o.free != true
            && o.hanzi != t.hanzi && !others.contains(where: { $0.hanzi == o.hanzi }) {
            others.append(o)
        }
        return (others + [t]).shuffled()
    }

    /// What to reply, in English, and three replies to tap: the right one sent as yours, a wrong one greyed out.
    private func pickCard(_ t: Turn) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TAP YOUR REPLY").font(.nunito(11, .black)).tracking(1.2).foregroundStyle(Home.teal)
            Text(t.en).font(.nunito(18, .black)).foregroundStyle(Home.ink).fixedSize(horizontal: false, vertical: true)
            ForEach(options, id: \.hanzi) { o in
                let wrong = wrongPicks.contains(o.hanzi)
                Button { picked(o, for: t) } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(o.hanzi).font(.hanzi(19, .medium)).foregroundStyle(wrong ? Home.muted : Home.ink)
                        PinyinText(pinyin: Self.spaced(o.pinyin), size: 12, weight: .semibold)
                            .opacity(wrong ? 0.4 : 1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(wrong ? Home.line.opacity(0.5) : ChatLook.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(wrong ? ChatLook.red.opacity(0.5) : Home.line, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .disabled(wrong)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Home.line).offset(y: 4)
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(ChatLook.card)
                RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Home.line, lineWidth: 1.5)
            }
        }
        .padding(.horizontal, 12).padding(.bottom, 12)
    }

    /// A reply tapped: the right one goes as your voice note (said for you); a wrong one is greyed, try another.
    private func picked(_ o: Turn, for t: Turn) {
        guard waiting else { return }
        if o.hanzi == t.hanzi {
            Sounds.shared.play("correct")
            spoke(wrongPicks.isEmpty)
            if !wrongPicks.isEmpty { misses += 1 }
            let m = Msg(kind: .you(ok: true), turn: t, seconds: Self.seconds(t.hanzi, speaker: ChatCast.voice(t)))
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { msgs.append(m) }
            play(m)
            next(after: m.seconds + 0.5)
        } else {
            Sounds.shared.play("wrong")
            withAnimation(.easeOut(duration: 0.2)) { _ = wrongPicks.insert(o.hanzi) }
        }
    }

    /// WeChat's bar: hold to talk (once it's your turn), or a word while he's talking.
    private var bar: some View {
        HStack(spacing: 10) {
            if ended && !listenOnly {
                // (the app's own raised button, its lip and its shine: it was drawn by hand here, and didn't match)
                Button { leave() } label: { Text(lesson == nil ? "Finish" : "Continue") }
                    .buttonStyle(RaisedButton(fill: Color.accent, ink: Color.onAccent))
            } else if listenOnly {
                Text(ended ? "End of the chat" : "🔒 Learn its words to reply. Listening for now")
                    .font(.nunito(14, .bold)).foregroundStyle(Home.muted)
                    .frame(maxWidth: .infinity).frame(height: 54)
            } else {
                let face = !waiting ? Home.line : cancelling ? ChatLook.red : Home.teal
                let lip = !waiting ? Color(UIColor(hex: 0xD6CFC1)) : cancelling ? Color(UIColor(hex: 0xB43A2F)) : Home.tealDark
                let shape = RoundedRectangle(cornerRadius: 17, style: .continuous)
                VStack(spacing: 0) {
                    HStack(spacing: 7) {
                        Image(systemName: holding ? (cancelling ? "xmark" : "waveform") : "mic.fill").font(.system(size: 15, weight: .black))
                        Text(holding ? (cancelling ? "松开 取消" : "松开 发送") : "按住 说话").font(.hanzi(17, .bold))
                    }
                    Text(holding ? (cancelling ? "Let go to cancel" : "Let go to send") : waiting ? "Hold to talk" : msgs.last?.kind == .thinking ? "步步 is thinking…" : "\(talking) is talking…")
                        .font(.nunito(11, .heavy)).opacity(0.8)
                }
                .foregroundStyle(waiting ? Color.white : Home.muted)
                .frame(maxWidth: .infinity).frame(height: 54)
                .background(face, in: shape)
                .offset(y: holding ? 4 : 0)
                .padding(.bottom, 4)
                .background(shape.fill(lip).padding(.top, 4))
                .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            guard waiting else { return }
                            if !pressed { pressed = true; startTalking() }
                            cancelling = v.translation.height < -70
                        }
                        // (cancelling cleared at every let-go: it stuck after a cancel, and the bar stayed red)
                        .onEnded { _ in pressed = false; if holding { stopTalking() }; cancelling = false })
                    .accessibilityLabel("Hold to talk")
                    .accessibilityAddTraits(.isButton)
            }
        }
        .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 10)
        // (no ground of its own: the page's shows through, greyed while you hold)
        .animation(.spring(response: 0.16, dampingFraction: 0.7), value: holding)
        .animation(.easeOut(duration: 0.15), value: cancelling)
    }

    /// While you hold: the chat dimmed, a green voice bubble moving with your voice, the line filling in as it's heard,
    /// and the place to slide to, to cancel.
    /// the grey over the chat while you hold
    private var holdDim: some View { Home.ink.opacity(0.42) }

    private var recordingOverlay: some View {
        ZStack {
            holdDim
            VStack(spacing: 18) {
                Waveform(level: level, bars: 15)
                    .foregroundStyle(cancelling ? Color.white : Home.tealDark)
                    .padding(.horizontal, 26).padding(.vertical, 18)
                    .chatBubble(mine: true, fill: cancelling ? ChatLook.red : nil)
                if !interimText.isEmpty {
                    Text(interimText).font(.hanzi(22, .medium)).foregroundStyle(.white)
                } else if !interim.isEmpty {
                    marksText(interim, size: 24)
                }
                Spacer().frame(height: 30)
                Image(systemName: "xmark").font(.system(size: 20, weight: .bold)).foregroundStyle(cancelling ? ChatLook.red : Color.white)
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
        guard dialogue != nil else { return }
        guard turn < turns.count else { return finish() }
        let t = turns[turn]
        if t.who == "you" && !listenOnly {
            options = pickOptions(t); wrongPicks = []
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { waiting = true }
            return
        }
        // his line, or (listening only) yours said for you
        let m = Msg(kind: t.who == "you" ? .you(ok: true) : .bubu, turn: t, seconds: Self.seconds(t.hanzi, speaker: ChatCast.voice(t)))
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { msgs.append(m) }
        play(m)
        turn += 1
        let r = run
        DispatchQueue.main.asyncAfter(deadline: .now() + m.seconds + 0.7) { if run == r { step() } }
    }

    /// How long a line's voice note is: its clip's, or about a third of a second a character.
    static func seconds(_ text: String, speaker: String? = nil) -> Double {
        if let url = Speech.clipURL(text, speaker: speaker), let p = try? AVAudioPlayer(contentsOf: url) { return p.duration }
        return 0.4 + Double(text.filter(Course.isHan).count) * 0.3
    }

    private func play(_ m: Msg) {
        player?.stop()
        if let f = m.file {
            Sounds.shared.activate()
            player = try? AVAudioPlayer(contentsOf: f)
            player?.play()
        } else {
            Speech.shared.speak(m.turn.hanzi, speaker: ChatCast.voice(m.turn))
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
        recognizer.onInterim = { alts in
            if free { interimText = alts.first ?? "" } else { interim = SpeechScore.marks(t.hanzi, alts) }
        }
        recognizer.acceptEarly = { _ in false }       // (it waits for you to let go)
        // the words to expect: the line's, and the chat's people
        var hints = (Sentence.segment(hanzi: t.hanzi, pinyin: t.pinyin)?.map(\.hanzi) ?? []) + [t.hanzi.filter(Course.isHan)]
        if let d = dialogue { hints += ChatCast.members(d) }
        hints += course.nameList
        recognizer.hints = hints
        recognizer.onResult = { alts in judge(t, alts) }
        recognizer.onError = { f in
            // (each counts as a try, so a line can always be skipped: with the microphone off, at once; the Mac, 23 Oct 2026)
            switch f {
            case .notAllowed:
                // (in a lesson: picked instead)
                if lesson != nil {
                    var t = Transaction(); t.disablesAnimations = true
                    withTransaction(t) { holding = false; pressed = false; cancelling = false; interim = []; interimText = "" }
                    cantTalk(); return
                }
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
        if free { freeJudge(t, alts) } else { judgeLine(t, alts) }
    }

    /// Said freely: your note at once (what was heard under it), 步步 thinking, then their feedback. It works: on to the
    /// next line (a moment to read it). Almost: try again (after two, the example to use and carry on). The tutor not
    /// reached: judged on the line, as before.
    private func freeJudge(_ t: Turn, _ alts: [String]) {
        let mine = Msg(kind: .you(ok: nil), turn: t, seconds: max(1, Date().timeIntervalSince(heldAt)), file: recording, heard: alts.first)
        interim = []; interimText = ""
        let before = msgs.last(where: { $0.kind == .bubu })?.turn
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            msgs.append(mine)
            msgs.append(Msg(kind: .thinking, turn: t, seconds: 0))
            // (no talking over the tutor: the card and the bar back if it's to try again)
            waiting = false
        }
        let r = run
        Task { @MainActor in
            let v = await FreeSpeech.judge(said: alts, goal: t, before: before)
            guard run == r else { return }
            withAnimation(.easeOut(duration: 0.15)) { msgs.removeAll { $0.kind == .thinking } }
            guard let v else {
                msgs.removeAll { $0.id == mine.id }
                waiting = true
                judgeLine(t, alts)
                return
            }
            if let i = msgs.firstIndex(where: { $0.id == mine.id }) { msgs[i].kind = .you(ok: v.works) }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { msgs.append(Msg(kind: .tutor(v), turn: t, seconds: 0)) }
            if v.works {
                Sounds.shared.play("correct")
                spoke(true)
                if tries > 0 { misses += 1 }
                next(after: v.spotOn ? 1.0 : v.better == nil ? 2.2 : 3.4)
            } else {
                Sounds.shared.play("wrong")
                tries += 1
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { waiting = true }
            }
        }
    }

    /// Said as the line given: heard near enough, or not (asked again).
    private func judgeLine(_ t: Turn, _ alts: [String]) {
        let ok = t.free == true ? !alts.isEmpty : SpeechScore.passes(t.hanzi, alts, keyword: nil)
        let marks = t.free == true ? [] : SpeechScore.marks(t.hanzi, alts)
        let m = Msg(kind: .you(ok: ok), turn: t, seconds: max(1, Date().timeIntervalSince(heldAt)), file: recording, marks: marks)
        interim = []
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { msgs.append(m) }
        if ok {
            Sounds.shared.play("correct")
            spoke(true)
            if tries > 0 { misses += 1 }
            next()
        } else {
            Sounds.shared.play("wrong")
            tries += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // (asked by whoever spoke last)
                let last = msgs.last(where: { $0.kind == .bubu })?.turn ?? t
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { msgs.append(Msg(kind: .ask, turn: last, seconds: 0)) }
            }
        }
    }

    private func skip(_ t: Turn) {
        spoke(false)
        misses += 1
        // (the line said for you, as a note of yours with its words, so the chat still reads through)
        let m = Msg(kind: .you(ok: false), turn: t, seconds: Self.seconds(t.hanzi, speaker: ChatCast.voice(t)))
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { msgs.append(m) }
        play(m)
        // (heard out before the next line: it was cut off)
        next(after: m.seconds + 0.5)
    }

    /// On to his next line (`after` seconds: time to read the tutor's feedback).
    private func next(after: Double = 0.9) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { waiting = false }
        tries = 0; note = nil; showExample = false; interimText = ""
        turn += 1
        let r = run
        DispatchQueue.main.asyncAfter(deadline: .now() + after) { if run == r { step() } }
    }

    /// A line of yours counted: by the chat's session, or the lesson's.
    private func spoke(_ right: Bool) {
        session?.spoke(right: right)
        lesson?.line(right)
    }

    /// The end: listening only, the chat simply ends; in a lesson, on to its next step; else its stars kept, and the
    /// lesson's done screen over it.
    private func finish() {
        // (a button to leave by, so it can be read back first, and the end marked as a lesson's: the owner, 23 Oct 2026)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { ended = true }
        guard !listenOnly else { return }
        Sounds.shared.play("complete")
        if lesson == nil { cheer += 1 }
    }

    /// Finish tapped: on to the lesson's next step, or the chat's stars kept and the done screen over it.
    private func leave() {
        if let lesson { lesson.done(); return }
        guard let d = dialogue, let s = session, !listenOnly else { dismiss(); return }
        ChatRecord.shared.finished(d.id, stars: misses == 0 ? 3 : misses <= 2 ? 2 : 1)
        s.finishFlashcards()
        handedOn = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            router.study = s
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { dismiss() }
            }
        }
    }
}

/// Speaking's colours: WeChat's shape, the app's look.
enum ChatLook {
    static let card = Color(UIColor(hex: 0xFFFDF8))
    /// your notes: a soft green, its lip a deeper one
    static let mine = Color(UIColor(hex: 0xCFEFDF))
    static let mineLip = Color(UIColor(hex: 0xA9DCC4))
    static let heard = Color(UIColor(hex: 0x1F8A6D))
    static let red = Color(UIColor(hex: 0xE0574A))
    static let online = Color(UIColor(hex: 0x3DBE7A))
    static let faint = Color(UIColor(hex: 0xA89E8C))
    static let rule = Color(UIColor(hex: 0xEFE9DD))
}

extension View {
    /// A chat bubble in the app's look: soft and raised on a lip, its corner by the photo tucked in.
    func chatBubble(mine: Bool, fill: Color? = nil) -> some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: mine ? 16 : 5,
                                           bottomTrailingRadius: mine ? 5 : 16, topTrailingRadius: 16, style: .continuous)
        return background {
            ZStack {
                shape.fill(fill == nil ? (mine ? ChatLook.mineLip : Home.line) : Color.black.opacity(0.18)).offset(y: 3)
                shape.fill(fill ?? (mine ? ChatLook.mine : ChatLook.card))
                shape.stroke(fill == nil ? (mine ? ChatLook.mineLip : Home.line) : Color.clear, lineWidth: 1.5)
            }
        }
    }
}

/// Who's who in Speaking's chats: the five of the cast you talk to, their photos (tools/art/make_chat_photos.py, from
/// their approved drawings), and a chat's members, name and preview.
enum ChatCast {
    static let photos = ["小雨": "chat-xiaoyu", "林小雨": "chat-xiaoyu", "陈明": "chat-chenming", "陈妈妈": "chat-chenmama",
                         "陈爸爸": "chat-chenbaba", "朵朵": "chat-duoduo"]
    static func photo(_ name: String?) -> String { name.flatMap { photos[$0] } ?? "chat-bubu" }

    /// The cast in a chat, in the order they first speak.
    static func members(_ d: Dialogue) -> [String] {
        var out: [String] = []
        for t in d.turns where t.who != "you" { if let n = t.name, !out.contains(n) { out.append(n) } }
        return out
    }

    /// One person: their name; a group: theirs, run together, as WeChat names a group no one has named.
    static func chatName(_ d: Dialogue) -> String {
        let m = members(d)
        return m.count <= 1 ? (m.first ?? "步步") : m.prefix(3).joined(separator: "、") + (m.count > 3 ? "…(\(m.count))" : "")
    }

    /// A chat's first line, as WeChat's list shows it ("name: line" in a group).
    static func preview(_ d: Dialogue) -> String {
        guard let t = d.turns.first else { return "" }
        return members(d).count > 1 ? "\(t.who == "you" ? "我" : t.name ?? ""): \(t.hanzi)" : t.hanzi
    }

    /// Whose voice a line is in: the cast's own; yours (Mark's), said for you, in 步步's.
    static func voice(_ t: Turn) -> String? { t.who == "you" ? nil : t.name }
}

/// A person's chat photo: round, a white ring round it.
struct ChatPhoto: View {
    var who: String? = nil
    var size: CGFloat
    var body: some View {
        Image(ChatCast.photo(who)).resizable().scaledToFill().frame(width: size, height: size)
            .background(Color(UIColor(hex: 0xFBF4E6)))
            .clipShape(Circle())
            .overlay(Circle().stroke(.white, lineWidth: size > 30 ? 2 : 1.5))
            .shadow(color: Home.ink.opacity(0.08), radius: 2, y: 1)
    }
}

/// A chat's photo in the list: the one person's, or for a group their round photos overlapping (the owner, 23 Oct 2026:
/// "instead of the box, more like this for two people", then "overlapping for 3+ too and more"): two side by side, the
/// second in front; three, two behind and one in front; four in a square; five or more, three and how many more.
struct ChatGroupPhoto: View {
    let members: [String]
    var size: CGFloat

    /// Each photo's place, as shares of the slot (its middle), from the back to the front, and its size.
    private var layout: (spots: [CGPoint], d: CGFloat) {
        switch members.count {
        case 2: return ([CGPoint(x: 0.34, y: 0.34), CGPoint(x: 0.66, y: 0.66)], 0.68)
        case 3: return ([CGPoint(x: 0.3, y: 0.32), CGPoint(x: 0.7, y: 0.32), CGPoint(x: 0.5, y: 0.7)], 0.6)
        default: return ([CGPoint(x: 0.3, y: 0.3), CGPoint(x: 0.7, y: 0.3), CGPoint(x: 0.3, y: 0.7), CGPoint(x: 0.7, y: 0.7)], 0.58)
        }
    }

    var body: some View {
        if members.count <= 1 {
            ChatPhoto(who: members.first, size: size)
        } else {
            let (spots, k) = layout
            let d = size * k
            // (five or more: the last place is how many more)
            let shown = members.count > 4 ? Array(members.prefix(3)) : members
            ZStack(alignment: .topLeading) {
                ForEach(Array(shown.enumerated()), id: \.offset) { i, n in
                    ChatPhoto(who: n, size: d)
                        .offset(x: spots[i].x * size - d / 2, y: spots[i].y * size - d / 2)
                }
                if members.count > 4 {
                    Text("+\(members.count - 3)").font(.nunito(d * 0.36, .black)).foregroundStyle(Home.teal)
                        .frame(width: d, height: d)
                        .background(Home.tealSoft, in: Circle())
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .shadow(color: Home.ink.opacity(0.08), radius: 2, y: 1)
                        .offset(x: spots[3].x * size - d / 2, y: spots[3].y * size - d / 2)
                }
            }
            .frame(width: size, height: size, alignment: .topLeading)
        }
    }
}

/// Three dots rising in turn: someone writing (步步 judging what you said).
struct TypingDots: View {
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(Home.muted).frame(width: 7, height: 7)
                        .offset(y: -3 * max(0, sin(t * 6 - Double(i) * 0.8)))
                        .opacity(0.45 + 0.55 * max(0, sin(t * 6 - Double(i) * 0.8)))
                }
            }
        }
        .frame(height: 14)
    }
}

/// A chat's scroll kept at its foot as its frame changes (the reply card coming and going), not only as messages are
/// added: the messages glide down as the card goes and up as it comes (iOS 18 on; before it, the scroll to the end does).
struct KeepsFoot: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.defaultScrollAnchor(.bottom, for: .sizeChanges)
        } else {
            content
        }
    }
}

/// A lesson's chat sits in a rounded panel; on its own page it isn't clipped (its grey reaches the screen's edges).
struct PanelClip: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View {
        if on { content.clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous)) } else { content }
    }
}

/// The hold's grey over everything but one place (a lesson's chat panel, which greys itself), in global coordinates.
struct HoleDim: View {
    let hole: CGRect
    var body: some View {
        GeometryReader { g in
            let f = g.frame(in: .global)
            Path { p in
                p.addRect(CGRect(origin: .zero, size: g.size))
                p.addRoundedRect(in: hole.offsetBy(dx: -f.minX, dy: -f.minY), cornerSize: CGSize(width: 22, height: 22), style: .continuous)
            }
            .fill(Home.ink.opacity(0.42), style: FillStyle(eoFill: true))
        }
    }
}
