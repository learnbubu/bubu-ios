import SwiftUI

/// A Study session, laid out as the web's study screen: a top bar, a card with the
/// progress bar, the prompt and the exercise, and a fixed slot at the bottom for the
/// feedback and the Continue button, so answering never moves anything.
struct StudyView: View {
    @State var session: StudySession
    var close: () -> Void
    @Environment(ProgressStore.self) private var progress

    // the current exercise's state
    @State private var picked: String?
    @State private var placed: [Exercise.Tile] = []
    @State private var feedback: Feedback?
    @State private var exerciseKey = UUID()

    struct Feedback { let correct: Bool; let chosen: String? }

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()
            if session.result != nil {
                DoneView(session: session, close: close, again: { restart(session.again()) },
                         next: { id in restart(StudySession(lessonId: id, progress: progress)) })
                    .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    topBar
                    ScrollView {
                        card.padding(.horizontal, 12).padding(.bottom, 12)
                    }
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize)
                    if case .card = session.current { bottomSlot }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: session.result != nil)
        .sensoryFeedback(trigger: feedback?.correct) { _, new in
            guard let new else { return nil }
            return new ? .success : .error
        }
    }

    private func restart(_ s: StudySession) {
        session = s
        resetExercise()
    }

    private func resetExercise() {
        picked = nil; placed = []; feedback = nil; exerciseKey = UUID()
        if let ex = session.exercise, ex.dir == "listen" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { Speech.shared.speak(ex.card.word.hanzi) }
        }
    }

    // MARK: chrome

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { close() } label: {
                Text("← Home").font(.nunito(15, .bold)).foregroundStyle(Color.ink)
                    .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            Text("Study").font(.nunito(16, .bold)).foregroundStyle(Color.ink)
            Spacer()
            if session.combo >= 3 {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill").font(.system(size: 13))
                    Text("\(session.combo)").font(.nunitoXB(14))
                }
                .foregroundStyle(session.combo >= 5 ? Color(UIColor(hex: 0xF0742F)) : Color.gold)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background((session.combo >= 5 ? Color(UIColor(hex: 0xF0742F)) : Color.gold).opacity(0.14), in: Capsule())
                .transition(.scale.combined(with: .opacity))
            }
            if progress.boostActive {
                Text("2× XP").font(.nunitoXB(12)).foregroundStyle(Color.accent)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Color.accentSoft, in: Capsule())
            }
            Text("\(min(session.stepsDone, session.sessionTotal)) / \(session.sessionTotal)")
                .font(.nunito(13, .semibold)).monospacedDigit().foregroundStyle(Color.muted)
        }
        .padding(.leading, 4).padding(.trailing, 16).padding(.top, 4).padding(.bottom, 12)
        .animation(.spring(response: 0.3), value: session.combo)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProgressBarShine(value: session.progressFraction)
            Text(promptLabel).font(.nunitoXB(21.6)).tracking(-0.2).foregroundStyle(Color.ink)
                .padding(.top, 14)
            Group {
                switch session.current {
                case .meet(let cards, let first, let left):
                    MeetView(cards: cards, first: first, left: left) { session.next(); resetExercise() }
                case .card:
                    if let ex = session.exercise {
                        if ex.kind == .sentence {
                            SentenceView(ex: ex, placed: $placed, result: feedback?.correct)
                        } else {
                            ChoiceView(ex: ex, picked: picked, answered: session.answered, isNew: ex.isNew) { choose($0) }
                        }
                    }
                case nil:
                    EmptyView()
                }
            }
            .id(exerciseKey)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
        }
        .padding(.horizontal, 12).padding(.vertical, 15)
        .panel(radius: 13)
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: exerciseKey)
    }

    private var promptLabel: String {
        if case .meet = session.current { return "New words" }
        return session.exercise?.label ?? ""
    }

    /// The reserved slot: feedback above, Continue below, fixed height.
    private var bottomSlot: some View {
        let ex = session.exercise
        let isSentence = ex?.kind == .sentence
        let ready = session.answered || (isSentence && !placed.isEmpty)
        return VStack(spacing: 10) {
            Spacer(minLength: 0)
            if let fb = feedback, let ex {
                FeedbackBanner(ex: ex, correct: fb.correct, chosen: fb.chosen)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            Button {
                if isSentence && !session.answered { checkSentence() } else { advance() }
            } label: {
                Text(isSentence && !session.answered ? "Check" : "Continue")
                    .font(.nunitoXB(17))
                    .foregroundStyle(ready ? (feedback == nil ? Color.onAccent : Color.white) : Color.muted)
                    .frame(maxWidth: .infinity).padding(14)
                    .background(ready ? (feedback.map { $0.correct ? Color.good : Color.again } ?? Color.accent) : Color.line,
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(PressDown(depth: 2))
            .disabled(!ready)
        }
        .padding(.horizontal, 16).padding(.bottom, 14)
        .frame(height: feedback == nil ? 84 : nil)
        .frame(minHeight: 84)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: feedback != nil)
    }

    // MARK: answering

    private func choose(_ option: String) {
        guard !session.answered, let ex = session.exercise else { return }
        picked = option
        let correct = option == ex.answer
        session.answer(correct)
        Sounds.shared.play(correct ? "correct" : "wrong")
        withAnimation { feedback = Feedback(correct: correct, chosen: option) }
    }

    private func checkSentence() {
        guard let ex = session.exercise, !session.answered else { return }
        let correct = ex.check(placed)
        session.answer(correct)
        Sounds.shared.play(correct ? "correct" : "wrong")
        withAnimation { feedback = Feedback(correct: correct, chosen: nil) }
    }

    private func advance() {
        withAnimation {
            session.next()
            resetExercise()
        }
        if session.result != nil { Sounds.shared.play("complete") }
    }
}

// MARK: - the progress bar

struct ProgressBarShine: View {
    var value: Double
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
        .frame(height: 6)
        .animation(.easeOut(duration: 0.3), value: value)
    }
}

// MARK: - mascot and speech bubble

struct MascotPrompt<Content: View>: View {
    var mood: Bool?          // nil: asking; true: pleased; false: sad
    @ViewBuilder var content: Content
    @State private var pop = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(mood == nil ? "panda-teacher" : mood! ? "panda-celebrate" : "panda-sad")
                .resizable().scaledToFit()
                .frame(width: 122, height: 148, alignment: .bottom)
                .shadow(color: .black.opacity(0.15), radius: 4, y: 3)
                .scaleEffect(pop ? 1.14 : 1)
            SpeechBubbleBox { content }
        }
        .frame(minHeight: 140)
        .onChange(of: mood) { _, new in
            guard new != nil else { return }
            withAnimation(.easeOut(duration: 0.17)) { pop = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.17) { withAnimation(.easeIn(duration: 0.17)) { pop = false } }
        }
    }
}

/// The white bubble with a tail on its left, pointing at Bùbù.
struct SpeechBubbleBox<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 6) { content }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.panel))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.line, lineWidth: 2))
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
    var body: some View {
        Button { Speech.shared.speak(text) } label: {
            Image(systemName: "speaker.wave.2.fill").font(.system(size: size)).foregroundStyle(Color.accent)
                .padding(4)
        }
        .buttonStyle(.plain)
    }
}

struct NewBadge: View {
    var body: some View {
        Text("NEW WORD").font(.nunito(10, .black)).tracking(1.6)
            .foregroundStyle(Color.tiles["purple"]!.ink)
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(Color.tiles["purple"]!.bg, in: Capsule())
    }
}

// MARK: - meet the new words

struct MeetView: View {
    let cards: [Card]
    let first: Bool
    let left: Int
    var done: () -> Void
    private let course = Course.shared

    var body: some View {
        let shown = Array(cards.prefix(15))
        let later = left
        let count = shown.count == 2 ? "Two" : shown.count == 3 ? "Three" : "\(shown.count)"
        let intro = (shown.count == 1 ? "A new word. Tap the speaker to hear it, then practise it."
            : "\(count) new words. Tap each speaker to hear it, then practise them.")
            + (later > 0 ? " \(later) more come\(later == 1 ? "s" : "") later in this session." : "")
        let lid = first && !cards.isEmpty && cards.allSatisfy { $0.lessonId == cards[0].lessonId } ? cards[0].lessonId : nil
        let note = lid.flatMap { course.notes(for: $0).first }
        VStack(spacing: 10) {
            NewBadge().padding(.top, 10)
            Text(intro).font(.nunito(14.4)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
            if let note {
                VStack(alignment: .leading, spacing: 6) {
                    Label { Text(note.title) } icon: { Image(systemName: "lightbulb") }
                        .font(.nunito(15, .bold)).foregroundStyle(Color.ink)
                    Text(note.body).font(.nunito(14.5)).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            VStack(spacing: 8) {
                ForEach(shown, id: \.id) { c in row(c) }
            }
            Button(shown.count == 1 ? "Practise it →" : "Practise them →", action: done)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 8)
        }
    }

    private func row(_ c: Card) -> some View {
        HStack(spacing: 12) {
            ToneText(hanzi: c.word.hanzi, pinyin: c.word.pinyin, size: 27, weight: .bold)
                .frame(minWidth: 60)
            VStack(alignment: .leading, spacing: 2) {
                PinyinText(pinyin: c.word.pinyin, size: 16)
                Text(c.word.en).font(.nunito(13.5)).foregroundStyle(Color.muted)
                ForEach(partLines(c.word.hanzi), id: \.self) { line in
                    Text(line).font(.nunito(12.5)).foregroundStyle(Color.muted)
                }
            }
            Spacer(minLength: 0)
            SpeakerButton(text: c.word.hanzi, size: 22)
        }
        .padding(.horizontal, 11).padding(.vertical, 8)
        .panel(radius: 14)
    }

    /// "好 = 女 woman + 子 child", sound parts showing their pinyin.
    private func partLines(_ hanzi: String) -> [AttributedString] {
        let cd = CharData.shared
        return hanzi.filter(Course.isHan).map(String.init)
            .filter { (cd.chars[$0]?.c?.count ?? 0) > 1 }
            .prefix(3)
            .map { ch in
                var s = AttributedString(ch)
                s.foregroundColor = .ink; s.font = .nunitoXB(12.5)
                s += AttributedString(" = ")
                for (i, part) in (cd.chars[ch]?.c ?? []).enumerated() {
                    guard let comp = part.first else { continue }
                    let sound = part.count > 1 && part[1] == "s"
                    if i > 0 { s += AttributedString(" + ") }
                    var c = AttributedString(comp)
                    c.foregroundColor = sound ? .gold : .accent; c.font = .nunitoXB(12.5)
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

/// Pinyin with each syllable in its tone colour.
struct PinyinText: View {
    let pinyin: String
    var size: CGFloat = 16
    var body: some View {
        let words = pinyin.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        var t = Text("")
        for (i, w) in words.enumerated() {
            if i > 0 { t = t + Text(" ") }
            t = t + Text(w).foregroundColor(Color.tones[toneOf(w) - 1])
        }
        return t.font(.nunito(size, .semibold))
    }
}

// MARK: - multiple choice

struct ChoiceView: View {
    let ex: Exercise
    let picked: String?
    let answered: Bool
    let isNew: Bool
    var choose: (String) -> Void
    private let course = Course.shared

    var body: some View {
        let w = ex.card.word
        VStack(spacing: 0) {
            MascotPrompt(mood: answered ? (picked == ex.answer) : nil) {
                if isNew && ex.dir != "listen" { NewBadge() }
                switch ex.dir {
                case "recall":
                    Text(w.en).font(.nunito(17, .bold)).foregroundStyle(isNew ? Color.tiles["purple"]!.ink : Color.ink)
                        .multilineTextAlignment(.center)
                    SpeakerButton(text: w.hanzi)
                case "pinyin":
                    Text(w.hanzi).font(.hanzi(w.hanzi.count > 3 ? 29 : 38, .medium)).foregroundStyle(Color.ink)
                    Text(w.en).font(.nunito(16)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
                case "listen":
                    Button { Speech.shared.speak(w.hanzi) } label: {
                        Image(systemName: "headphones").font(.system(size: 50, weight: .regular)).foregroundStyle(Color.accent)
                            .padding(6)
                    }
                    .buttonStyle(PressDown(depth: 1))
                    Button { Speech.shared.speak(w.hanzi, slow: true) } label: {
                        Label("Slower", systemImage: "tortoise.fill").font(.nunito(12, .bold)).foregroundStyle(Color.muted)
                    }
                    .buttonStyle(.plain)
                default:
                    ToneText(hanzi: w.hanzi, pinyin: w.pinyin, size: w.hanzi.count > 3 ? 29 : 38, weight: .medium)
                    SpeakerButton(text: w.hanzi)
                }
            }
            if ex.dir == "recognize" {
                PinyinText(pinyin: w.pinyin, size: 17).padding(.top, 8)
            }
            VStack(spacing: 10) {
                ForEach(ex.options, id: \.self) { opt in option(opt) }
            }
            .padding(.top, 16)
        }
    }

    private func option(_ opt: String) -> some View {
        let isAnswer = opt == ex.answer
        let state: Bool? = !answered ? nil : isAnswer ? true : opt == picked ? false : nil
        return Button { choose(opt) } label: {
            Group {
                if ex.dir == "recall" {
                    VStack(spacing: 2) {
                        Text(opt).font(.hanzi(18.4, .semibold)).foregroundStyle(Color.ink)
                        if let py = course.cards.first(where: { $0.word.hanzi == opt })?.word.pinyin {
                            Text(py).font(.nunito(13)).foregroundStyle(Color.muted)
                        }
                    }
                    .padding(.vertical, 10)
                } else {
                    Text(opt).font(ex.dir == "pinyin" ? .nunito(18.4, .bold) : .nunito(17, .bold))
                        .foregroundStyle(Color.ink).multilineTextAlignment(.center)
                        .padding(.vertical, 14)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .background(state == true ? Color.goodSoft : state == false ? Color.againSoft : Color.panel,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(state == true ? Color.good : state == false ? Color.again : Color.line, lineWidth: state == nil ? 1 : 2))
        }
        .buttonStyle(PressDown(depth: 1))
        .disabled(answered)
        .animation(.easeOut(duration: 0.15), value: answered)
    }
}

// MARK: - feedback

struct FeedbackBanner: View {
    let ex: Exercise
    let correct: Bool
    let chosen: String?
    @State private var praise = ["Nice!", "Great job!", "Excellent!", "Spot on!", "太棒了!", "对了!"].randomElement()!
    private let course = Course.shared

    var body: some View {
        let w = ex.card.word
        let tint = correct ? Color.good : Color.again
        let lookalike: Card? = {
            guard !correct, let chosen else { return nil }
            let c = ex.dir == "recall" ? course.cards.first { $0.word.hanzi == chosen }
                : ex.dir == "recognize" ? course.cards.first { $0.word.en == chosen } : nil
            guard let c, CharData.shared.wordSim(w.hanzi, c.word.hanzi) >= 1.5 else { return nil }
            return c
        }()
        let diff = lookalike.flatMap { CharData.shared.difference(w.hanzi, $0.word.hanzi) }
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: correct ? "checkmark" : "xmark").font(.system(size: 20, weight: .heavy))
                .frame(width: 24, height: 24).padding(.top, 1)
            VStack(alignment: .leading, spacing: 0) {
                Text(ex.kind == .sentence ? (correct ? "Nicely done!" : "Correct solution:")
                     : correct ? praise : diff != nil ? "Nearly! Those two look alike" : "Correct answer:")
                    .font(.nunitoXB(18.4))
                if ex.kind == .sentence, let sent = ex.sentence {
                    sentenceAnswer(sent)
                } else {
                    wordAnswer(w)
                }
                if let diff, let other = lookalike {
                    diffBlock(diff, other: other)
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(correct ? Color.goodSoft : Color.againSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func wordAnswer(_ w: Word) -> some View {
        let first = ex.dir == "recognize" ? "en" : ex.dir == "pinyin" ? "py" : "hz"
        piece(first, w, big: true).padding(.top, 4)
        HStack(spacing: 0) {
            ForEach(Array(["hz", "py", "en"].filter { $0 != first }.enumerated()), id: \.offset) { i, k in
                if i > 0 { Text(" · ").foregroundStyle(Color.gold) }
                piece(k, w, big: false)
            }
        }
        .font(.nunito(14.4)).padding(.top, 2)
    }

    @ViewBuilder
    private func piece(_ k: String, _ w: Word, big: Bool) -> some View {
        switch k {
        case "en": Text(w.en).font(.nunito(big ? 17.6 : 14.4, big ? .semibold : .regular)).foregroundStyle(big ? Color.ink : Color.gold)
        case "py": PinyinText(pinyin: w.pinyin, size: big ? 17.6 : 14.4)
        default: ToneText(hanzi: w.hanzi, pinyin: w.pinyin, size: big ? 20 : 15, weight: .medium)
        }
    }

    @ViewBuilder
    private func sentenceAnswer(_ sent: Sentence) -> some View {
        if !correct {
            Text(ex.toChinese ? sent.hanzi : sent.en).font(ex.toChinese ? .hanzi(18, .medium) : .nunito(17.6)).foregroundStyle(Color.ink).padding(.top, 4)
            if ex.toChinese { Text(sent.pinyin).font(.nunito(14.4)).foregroundStyle(Color.gold).padding(.top, 2) }
        }
        let others = ex.toChinese ? Array(sent.acceptedOrders.dropFirst()) : []
        if !others.isEmpty {
            Text(correct ? "ALSO CORRECT:" : "ALSO ACCEPTED:").font(.nunitoXB(13)).tracking(0.4).opacity(0.85).padding(.top, 8)
            ForEach(others, id: \.self) { o in
                Text(o.joined()).font(.hanzi(16)).foregroundStyle(Color.ink)
            }
        }
    }

    private func diffBlock(_ d: (right: String, wrong: String, note: String), other: Card) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SPOT THE DIFFERENCE").font(.nunito(11, .black)).tracking(1.1).foregroundStyle(Color.again)
            HStack(spacing: 8) {
                cell(ex.card.word.hanzi, mark: d.right, en: ex.card.word.en, good: true)
                cell(other.word.hanzi, mark: d.wrong, en: other.word.en, good: false)
            }
            Text(d.note).font(.nunito(13.4)).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 11).padding(.vertical, 9)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.top, 8)
    }

    private func cell(_ hanzi: String, mark: String, en: String, good: Bool) -> some View {
        var s = AttributedString()
        for ch in hanzi {
            var a = AttributedString(String(ch))
            if String(ch) == mark { a.foregroundColor = good ? .good : .again; a.underlineStyle = .single }
            else { a.foregroundColor = .ink }
            s += a
        }
        return VStack(spacing: 2) {
            Text(s).font(.hanzi(27, .bold))
            Text(en).font(.nunito(11.8, .bold)).foregroundStyle(Color.muted).lineLimit(1)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 6).padding(.horizontal, 4)
        .background(Color.bg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - the sentence builder

struct SentenceView: View {
    let ex: Exercise
    @Binding var placed: [Exercise.Tile]
    let result: Bool?
    private let course = Course.shared

    var body: some View {
        let sent = ex.sentence!
        VStack(spacing: 16) {
            MascotPrompt(mood: result) {
                if ex.toChinese {
                    Text(sent.en).font(.nunito(17, .bold)).foregroundStyle(Color.ink).multilineTextAlignment(.center)
                } else {
                    FlowLayout(spacing: 2, lineSpacing: 4) {
                        SpeakerButton(text: sent.hanzi, size: 20)
                        ForEach(Array(sent.words.enumerated()), id: \.offset) { _, w in
                            let isNew = w.hanzi.contains(ex.card.word.hanzi)
                            VStack(spacing: 1) {
                                Text(w.pinyin).font(.nunito(12.5)).foregroundStyle(isNew ? Color.tiles["purple"]!.ink : Color.muted)
                                Text(w.hanzi).font(.hanzi(24.8)).foregroundStyle(isNew ? Color.tiles["purple"]!.ink : Color.ink)
                                    .padding(.bottom, 2)
                                    .overlay(alignment: .bottom) {
                                        Line().stroke(isNew ? Color.tiles["purple"]!.ink : Color.muted, style: StrokeStyle(lineWidth: 2, dash: [2, 3])).frame(height: 2)
                                    }
                            }
                            .padding(.horizontal, 3)
                        }
                    }
                }
            }
            answerArea
            bank
        }
    }

    private var rowHeight: CGFloat { ex.toChinese ? 84 : 64 }

    private var answerArea: some View {
        FlowLayout(spacing: 8, lineSpacing: 0, rowHeight: rowHeight) {
            ForEach(placed) { t in
                tile(t, inAnswer: true) {
                    guard result == nil else { return }
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { placed.removeAll { $0.id == t.id } }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: rowHeight * 2, alignment: .topLeading)
        .background(alignment: .top) {
            VStack(spacing: 0) {
                ForEach(0..<2, id: \.self) { _ in
                    Rectangle().fill(Color.line).frame(height: 2).padding(.top, rowHeight - 2)
                }
            }
        }
    }

    private var bank: some View {
        FlowLayout(spacing: 8, lineSpacing: 8, center: true) {
            ForEach(ex.tiles) { t in
                let used = placed.contains(t)
                ZStack {
                    tile(t, inAnswer: false) {
                        guard result == nil, !used else { return }
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { placed.append(t) }
                    }
                    .opacity(used ? 0 : 1)
                }
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.line.opacity(used ? 0.6 : 0)))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func tile(_ t: Exercise.Tile, inAnswer: Bool, tap: @escaping () -> Void) -> some View {
        let tint: Color? = inAnswer ? (result == true ? .good : result == false ? .again : nil) : nil
        return Button(action: tap) {
            VStack(spacing: 1) {
                Text(t.text).font(ex.toChinese ? .hanzi(20.8, .medium) : .nunito(16.8, .semibold))
                if let py = t.pinyin { Text(py).font(.nunito(11.5)).foregroundStyle(Color.muted) }
            }
            .foregroundStyle(tint ?? Color.ink)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(tint ?? Color.line).offset(y: 2)
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.panel)
                    RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(tint ?? Color.line, lineWidth: 2)
                }
            }
        }
        .buttonStyle(PressDown(depth: 2))
        .sensoryFeedback(.selection, trigger: placed.count)
    }
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
