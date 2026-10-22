import SwiftUI
import Observation

/// The words you've picked for flashcards, matching or a quiz (Vocabulary's search puts them on your list), kept
/// between launches.
@Observable
final class Picks {
    static let shared = Picks()
    private static let key = "bubu.picks"
    var ids: Set<String> {
        didSet { if !Launch.underTests { UserDefaults.standard.set(Array(ids).sorted(), forKey: Self.key) } }
    }
    init() {
        // (words no longer in the course are let go)
        let saved = Launch.underTests ? [] : UserDefaults.standard.stringArray(forKey: Self.key) ?? []
        ids = Set(saved.filter { Course.shared.cardById[$0] != nil })
    }
}

// MARK: - pick words (web: renderPicker)

struct PickPage: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(Router.self) private var router
    @State private var picks = Picks.shared
    @State private var query = ""
    private let course = Course.shared

    var body: some View {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let qp = Pinyin.toneless(q), qpNoSpace = qp.replacingOccurrences(of: " ", with: "")
        let match = { (c: Card) -> Bool in
            if q.isEmpty { return true }
            if c.word.hanzi.contains(q) || c.word.en.lowercased().contains(q) { return true }
            let py = Pinyin.toneless(c.word.pinyin).lowercased()
            return py.contains(qp) || py.replacingOccurrences(of: " ", with: "").contains(qpNoSpace)
        }
        let cards = course.cards.filter(match)
        let lessons = cards.map(\.lessonId).reduce(into: [String]()) { if $0.last != $1 { $0.append($1) } }
        let byLesson = Dictionary(grouping: cards, by: \.lessonId)
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    preset("＋ Current lesson") { course.cards.filter { $0.lessonId == progress.currentLessonId }.forEach { picks.ids.insert($0.id) } }
                    preset("＋ Still learning") { course.cards.filter { progress.srs[$0.id] != nil && !progress.isMastered($0.id) }.forEach { picks.ids.insert($0.id) } }
                    preset("＋ Due for review") { progress.dueReviewCards().forEach { picks.ids.insert($0.id) } }
                    preset("✕ Clear") { picks.ids.removeAll() }
                }
                .padding(.horizontal, 18).padding(.vertical, 8)
            }
            List {
                ForEach(lessons, id: \.self) { lid in
                    Section {
                        ForEach(byLesson[lid] ?? [], id: \.id) { c in
                            let on = picks.ids.contains(c.id)
                            Button {
                                if on { picks.ids.remove(c.id) } else { picks.ids.insert(c.id) }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20)).foregroundStyle(on ? Color.accent : Color.line)
                                    Group {
                                        if let pic = Pictures.asset(c.word.hanzi) { Image(pic).resizable().scaledToFit() }
                                        else { Color.clear }
                                    }
                                    .frame(width: 28, height: 28)
                                    Text(c.word.hanzi).font(.hanzi(19, .medium)).foregroundStyle(Color.ink).frame(minWidth: 48, alignment: .leading)
                                    Text(c.word.pinyin).font(.nunito(13.5)).foregroundStyle(Color.gold).lineLimit(1)
                                    Text(c.word.en).font(.nunito(13.5)).foregroundStyle(Color.muted).lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.panel)
                        }
                    } header: {
                        HStack {
                            Text(course.lessonById[lid]?.name ?? "").font(.nunitoXB(12.5)).foregroundStyle(Color.accent).textCase(nil).lineLimit(1)
                            Spacer()
                            Button("all") {
                                let group = (byLesson[lid] ?? []).map(\.id)
                                if group.allSatisfy(picks.ids.contains) { group.forEach { picks.ids.remove($0) } } else { picks.ids.formUnion(group) }
                            }
                            .font(.nunitoXB(12.5)).foregroundStyle(Color.accent).textCase(nil)
                        }
                    }
                }
                if cards.isEmpty { Text("No words match that search.").font(.nunito(14)).foregroundStyle(Color.muted) }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)

            let picked = course.cards.filter { picks.ids.contains($0.id) }
            HStack(spacing: 8) {
                action("Flashcards", "rectangle.on.rectangle") { router.push(.flash(picked.map(\.id))) }
                action("Match", "square.grid.2x2") { router.push(.match(picked.map(\.id))) }
                action("Quiz", "checklist") { router.start(StudySession.quiz(progress, cards: picked, focuses: ["recognize", "recall", "pinyin", "listen"], tooFew: "Pick at least 3 words to quiz.")) }
            }
            .disabled(picked.isEmpty)
            .opacity(picked.isEmpty ? 0.5 : 1)
            .padding(.horizontal, 18).padding(.vertical, 10)
            .background { Color.panel.shadow(color: .black.opacity(0.06), radius: 8, y: -3).ignoresSafeArea(edges: .bottom) }
        }
        .searchable(text: $query, prompt: "Search 汉字, pinyin or English")
        .navigationTitle("Pick words")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Text("\(picks.ids.count) chosen").font(.nunito(13, .semibold)).foregroundStyle(Color.muted)
            }
        }
    }

    private func preset(_ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.nunito(13.5, .bold)).foregroundStyle(Color.accent)
                .padding(.horizontal, 12).padding(.vertical, 7).background(Color.accentSoft, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func action(_ label: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                Text(label).font(.nunitoXB(13))
            }
            .foregroundStyle(Color.onAccent).frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(Color.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressDown(depth: 1))
    }
}

// MARK: - flashcards

/// Flashcards, simpler (the owner's board G, 22 Oct 2026), in the lessons' own look (the owner: "make sure the style
/// of the vocab matches the rest of how the app works"): their close, progress bar (gold with a combo of Got its),
/// raised card and buttons, and the done screen's tiles at the end, with XP. One word big, its picture, pinyin and
/// sound; tap and it turns to what it means and a sentence with it; then Still learning (it comes round again, once,
/// marked to come back soon) or Got it. Each answer counts as a review, and the cards are kept as a session
/// (StudySession.flashcards), so they have a lesson's effects (the owner: "has all our normal effects too?"): its
/// right and wrong sounds and taps, the run's sound and firecrackers every fifth, XP and quests, and its done screen
/// (the moment, the streak's lantern, the pockets, a level reached).
struct FlashPage: View {
    let ids: [String]
    @Environment(ProgressStore.self) private var progress
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var session: StudySession?
    /// the run's firecrackers, out from behind the bar
    @State private var burst: Int?
    @State private var barFrame: CGRect = .zero
    /// the last answer, for its tap (right or wrong)
    @State private var lastGot: Bool?
    @State private var answers = 0
    /// the done screen has the session now (it lets a level reached show)
    @State private var handedOn = false
    /// "Wait, don't go!", as a lesson's close asks once something's answered
    @State private var quitAsk = false
    @State private var queue: [Card] = []
    @State private var total = 0
    @State private var flipped = false
    @State private var example: Sentence?
    /// the ones put back once already (they're not put back again)
    @State private var again = Set<String>()
    @State private var got = 0
    private let course = Course.shared

    private var combo: Int { session?.combo ?? 0 }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                topBar
                if let c = queue.first { card(c).id(c.id + "\(queue.count)") }
            }
            .padding(.horizontal, 16).padding(.bottom, 12)
            if let n = burst {
                FirecrackerBurst(n: n, bar: barFrame).id(n).ignoresSafeArea().allowsHitTesting(false)
            }
            if quitAsk {
                QuitAsk(keep: { withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { quitAsk = false } },
                        quit: { quitAsk = false; dismiss() },
                        line: "Your cards so far are saved, but you'll miss the end of the set and its XP.", end: "End flashcards")
                    .transition(.opacity).zIndex(20)
            }
        }
        .background(Color.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        // (the whole screen, as a lesson's)
        .toolbar(.hidden, for: .tabBar)
        .sensoryFeedback(trigger: answers) { _, _ in lastGot.map { $0 ? .success : .error } }
        // every fifth Got it in a row: the burst, as a lesson's
        .onChange(of: combo) { old, n in
            guard n > old, n >= StudySession.comboAt, n % StudySession.comboAt == 0, !reduceMotion else { return }
            burst = n
            DispatchQueue.main.asyncAfter(deadline: .now() + FirecrackerBurst.length) { if burst == n { burst = nil } }
        }
        .onAppear {
            // (a level reached waits for the done screen, as in a lesson)
            progress.holdLevelUps = true
            guard queue.isEmpty, session == nil else { return }
            queue = ids.compactMap { course.cardById[$0] }.shuffled()
            total = queue.count
            session = StudySession.flashcards(progress, cards: queue)
            pickExample()
            say()
        }
        .onDisappear {
            guard !handedOn else { return }
            progress.holdLevelUps = false; progress.showHeldLevelUp()
        }
    }

    /// As a lesson's: close, the progress bar.
    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                if answers == 0 { dismiss() } else { withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { quitAsk = true } }
            } label: {
                Image(systemName: "xmark").font(.system(size: 22, weight: .heavy)).foregroundStyle(Color.muted)
                    .frame(width: 36, height: 36).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            ProgressBarShine(value: Double(got) / Double(max(total, 1)), height: 16, combo: combo)
                .background(GeometryReader { g in
                    Color.clear.onAppear { barFrame = g.frame(in: .global) }
                        .onChange(of: g.frame(in: .global)) { _, f in barFrame = f }
                })
            // as a lesson's: double XP on, and the buns while they're being earned back
            if progress.boostActive {
                HStack(spacing: 1) {
                    Image(systemName: "bolt.fill").font(.system(size: 12, weight: .black))
                    Text("2×").font(.nunito(14, .black))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 7).padding(.vertical, 4)
                .background(Color.gold, in: Capsule())
            }
            if let s = session, s.earnsBuns, progress.buns < ProgressStore.bunsMax {
                BunRow(n: progress.isPlus ? ProgressStore.bunsMax : progress.bunState.n, plus: progress.isPlus, bump: s.bunsEarned)
            }
        }
        .padding(.top, 8).padding(.bottom, 4)
    }

    private func card(_ c: Card) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return VStack(spacing: 0) {
            Text(flipped ? "What it means" : "Do you know this word?").font(.nunito(25, .black)).tracking(-0.4).foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 18)
                .contentTransition(.opacity)
            Button { withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { flipped.toggle() } } label: {
                ZStack {
                    VStack(spacing: 4) {
                        if let pic = Pictures.asset(c.word.hanzi) {
                            Image(pic).resizable().scaledToFit().frame(height: 96).padding(.bottom, 8)
                        }
                        Text(c.word.hanzi).font(.hanzi(c.word.hanzi.count > 3 ? 46 : 64, .medium)).foregroundStyle(Color.ink)
                            .minimumScaleFactor(0.5).lineLimit(1)
                        PinyinText(pinyin: c.word.pinyin, size: 20, weight: .heavy)
                    }
                    .opacity(flipped ? 0 : 1)
                    meaning(c)
                        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                        .opacity(flipped ? 1 : 0)
                }
                .padding(22)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // raised, as the answer tiles: the panel on a lip of the line's colour
                .background(Color.panel, in: shape)
                .overlay(shape.strokeBorder(Color.line, lineWidth: 2))
                .padding(.bottom, 5)
                .background(shape.fill(Color.line).padding(.top, 5))
                .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
            }
            .buttonStyle(.plain)
            .overlay(alignment: .topTrailing) { SpeakerButton(text: c.word.hanzi, size: 22).padding(14) }
            .overlay(alignment: .bottom) {
                Text(flipped ? "TAP TO TURN IT BACK" : "TAP TO SEE WHAT IT MEANS").font(.nunitoXB(12)).tracking(1)
                    .foregroundStyle(Color.muted).padding(.bottom, 20).allowsHitTesting(false)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: flipped)
            .padding(.top, 14)
            .frame(maxHeight: 440)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))

            Spacer(minLength: 18)
            HStack(spacing: 10) {
                Button("Still learning") { answer(c, gotIt: false) }.buttonStyle(WideButton(ghost: true))
                Button("Got it") { answer(c, gotIt: true) }.buttonStyle(WideButton())
            }
            .padding(.bottom, 6)
        }
        .frame(maxHeight: .infinity)
    }

    /// The back: what it means, and a sentence with it.
    private func meaning(_ c: Card) -> some View {
        VStack(spacing: 6) {
            Text(c.word.hanzi).font(.hanzi(28, .medium)).foregroundStyle(Color.muted).lineLimit(1).minimumScaleFactor(0.5)
            Text(c.word.en).font(.nunito(26, .black)).foregroundStyle(Color.ink).multilineTextAlignment(.center)
                .minimumScaleFactor(0.6).lineLimit(3)
            if let pos = c.word.pos {
                Text(pos).font(.nunito(13, .bold)).foregroundStyle(Color.muted)
            }
            if let s = example {
                VStack(spacing: 3) {
                    Text(s.hanzi).font(.hanzi(18)).foregroundStyle(Color.ink).multilineTextAlignment(.center)
                    Text(s.en).font(.nunito(13.5, .bold)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
                }
                .padding(.top, 14)
            }
        }
    }

    private func answer(_ c: Card, gotIt: Bool) {
        session?.flashcard(c, gotIt: gotIt)
        Sounds.shared.play(gotIt ? "correct" : "wrong")
        lastGot = gotIt; answers += 1
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            queue.removeFirst()
            if gotIt { got += 1 } else {
                // (it comes round again, a few cards on, once)
                if again.insert(c.id).inserted { queue.insert(c, at: min(queue.count, 3)) } else { got += 1 }
            }
            flipped = false
        }
        if queue.isEmpty { finish() }
        pickExample()
        say()
    }

    /// The next word said as it comes up, as a lesson says its prompts (when they're set to play).
    private func say() {
        guard let c = queue.first, progress.prefs.playsAutomatically else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if queue.first?.id == c.id && !flipped { Speech.shared.speak(c.word.hanzi) }
        }
    }

    /// The end, as a lesson's: its done screen, over everything (the moment, XP, the streak, quests, pockets).
    private func finish() {
        guard let s = session else { dismiss(); return }
        s.finishFlashcards()
        handedOn = true
        // the done screen slides up over the last card, and the page goes from under it once it's covered (closed
        // first, the room showed for half a second before it: the Mac, 22 Oct 2026)
        router.study = s
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { dismiss() }
        }
    }

    private func pickExample() {
        guard let c = queue.first else { example = nil; return }
        example = course.sentences(for: c).filter { $0.hanzi.count <= 16 }.min { $0.hanzi.count < $1.hanzi.count }
    }
}

// MARK: - matching (web: startMatch)

struct MatchPage: View {
    let ids: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var queue: [Card] = []
    @State private var tiles: [Tile] = []
    @State private var first: Tile?
    @State private var matched: Set<Tile> = []
    @State private var missed: Set<Tile> = []
    @State private var total = 0
    @State private var done = 0
    @State private var message = "Tap a character, then its meaning."
    @State private var finished = false
    private let course = Course.shared

    struct Tile: Hashable { let id: String; let han: Bool; let text: String }

    var body: some View {
        VStack(spacing: 14) {
            if finished {
                Spacer()
                Image("done-panda").resizable().scaledToFit().frame(width: 150)
                Text("Matching done").font(.nunito(16.8, .bold)).foregroundStyle(Color.ink)
                Text("\(total) pair\(total == 1 ? "" : "s") matched").font(.nunitoXB(20)).foregroundStyle(Color.accent)
                Spacer()
                Button { start() } label: { Label("Again", systemImage: "shuffle") }.buttonStyle(WideButton())
                Button("Done") { dismiss() }.buttonStyle(WideButton(ghost: true))
            } else {
                ProgressBarShine(value: total == 0 ? 0 : Double(done) / Double(total))
                Text(message).font(.nunito(14.5)).foregroundStyle(Color.muted)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(tiles, id: \.self) { t in tile(t) }
                }
                Spacer()
            }
        }
        .padding(18)
        .navigationTitle("Match · \(done) / \(total)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if total == 0 { start() } }
    }

    private func tile(_ t: Tile) -> some View {
        let isMatched = matched.contains(t), isMiss = missed.contains(t), sel = first == t
        return Button { tap(t) } label: {
            Text(t.text).font(t.han ? .hanzi(24, .medium) : .nunito(14.5, .semibold))
                .foregroundStyle(isMatched ? Color.good : Color.ink).multilineTextAlignment(.center)
                .lineLimit(3).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 62).padding(8)
                .background(isMatched ? Color.goodSoft : isMiss ? Color.againSoft : sel ? Color.accentSoft : Color.panel,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isMatched ? Color.good : isMiss ? Color.again : sel ? Color.accent : Color.line, lineWidth: sel ? 2 : 1))
                .offset(x: isMiss ? -4 : 0)
                .opacity(isMatched ? 0.55 : 1)
        }
        .buttonStyle(PressDown(depth: 1))
        .disabled(isMatched)
        .animation(isMiss ? .default.repeatCount(3, autoreverses: true).speed(4) : .easeOut(duration: 0.2), value: isMiss)
    }

    private func start() {
        // one card per meaning, so every meaning tile has exactly one right partner
        var seen = Set<String>()
        let uniq = ids.compactMap { course.cardById[$0] }.shuffled().filter { seen.insert($0.word.en).inserted }
        guard uniq.count >= 3 else { Moments.shared.toast("Pick at least 3 words with different meanings to match."); dismiss(); return }
        queue = uniq; total = uniq.count; done = 0; finished = false
        nextRound()
    }

    private func nextRound() {
        let round = Array(queue.prefix(6)); queue.removeFirst(round.count)
        matched = []; missed = []; first = nil
        tiles = round.flatMap { [Tile(id: $0.id, han: true, text: $0.word.hanzi), Tile(id: $0.id, han: false, text: $0.word.en)] }.shuffled()
        message = "Tap a character, then its meaning."
    }

    private func tap(_ t: Tile) {
        guard !matched.contains(t) else { return }
        guard let a = first else { first = t; return }
        if a == t { first = nil; return }
        first = nil
        if a.id == t.id && a.han != t.han {
            withAnimation { matched.formUnion([a, t]) }
            Sounds.shared.play("correct")
            if let c = course.cardById[t.id] { Speech.shared.speak(c.word.hanzi) }
            done += 1
            if matched.count == tiles.count {
                if queue.isEmpty {
                    Sounds.shared.play("complete")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { withAnimation { finished = true } }
                } else {
                    message = "Nice — next set…"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { withAnimation { nextRound() } }
                }
            }
        } else {
            Sounds.shared.play("wrong")
            missed = [a, t]
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { missed = [] }
        }
    }
}
