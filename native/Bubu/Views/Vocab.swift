import SwiftUI
import Observation

/// The words you've picked for flashcards, matching or a quiz, kept while the app runs.
@Observable
final class Picks {
    static let shared = Picks()
    var ids: Set<String> = []
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
/// marked to come back soon) or Got it. Each answer counts as a review.
struct FlashPage: View {
    let ids: [String]
    @Environment(ProgressStore.self) private var progress
    @Environment(\.dismiss) private var dismiss
    @State private var queue: [Card] = []
    @State private var total = 0
    @State private var flipped = false
    @State private var example: Sentence?
    /// the ones put back once already (they're not put back again)
    @State private var again = Set<String>()
    @State private var got = 0
    @State private var combo = 0
    @State private var finished = false
    @State private var xp = 0
    @State private var started = Date()
    @State private var seconds = 0
    private let course = Course.shared

    var body: some View {
        VStack(spacing: 0) {
            topBar
            if finished { end } else if let c = queue.first { card(c).id(c.id + "\(queue.count)") }
        }
        .padding(.horizontal, 16).padding(.bottom, 12)
        .background(Color.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        // (the whole screen, as a lesson's)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            guard queue.isEmpty, !finished else { return }
            queue = ids.compactMap { course.cardById[$0] }.shuffled()
            total = queue.count
            started = Date()
            pickExample()
        }
    }

    /// As a lesson's: close, the progress bar.
    private var topBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 22, weight: .heavy)).foregroundStyle(Color.muted)
                    .frame(width: 36, height: 36).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            ProgressBarShine(value: finished ? 1 : Double(got) / Double(max(total, 1)), height: 16, combo: combo)
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
        progress.review(c.id, gotIt ? .good : .again)
        progress.recordReview()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            queue.removeFirst()
            if gotIt { got += 1; combo += 1 } else {
                combo = 0
                // (it comes round again, a few cards on, once)
                if again.insert(c.id).inserted { queue.insert(c, at: min(queue.count, 3)) } else { got += 1 }
            }
            flipped = false
        }
        if queue.isEmpty { finish() }
        pickExample()
    }

    /// The end: XP for the words (one each, and one more for each known first time), as a lesson's done screen.
    private func finish() {
        seconds = max(1, Int(Date().timeIntervalSince(started)))
        xp = progress.earnXP(total + (total - again.count)).earned
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { finished = true }
    }

    private func pickExample() {
        guard let c = queue.first else { example = nil; return }
        example = course.sentences(for: c).filter { $0.hanzi.count <= 16 }.min { $0.hanzi.count < $1.hanzi.count }
    }

    private var end: some View {
        let known = total == 0 ? 100 : (total - again.count) * 100 / total
        return VStack(spacing: 0) {
            Spacer(minLength: 10)
            Image("panda-flashcards").resizable().scaledToFit().frame(maxHeight: 240)
            Text("Cards done!").font(.nunito(28, .black)).tracking(-0.4).foregroundStyle(Color.gold).padding(.top, 8)
            Text("You went through \(total) word\(total == 1 ? "" : "s")").font(.nunito(15, .bold)).foregroundStyle(Color.ink).padding(.top, 2)
            // the done screen's tiles
            HStack(spacing: 10) {
                XPTile(steps: [.init(label: "Total XP", value: xp, tint: Color(light: 0xF0A92E, dark: 0xF5B03D))], delay: 0.2)
                DoneTile(value: seconds, format: { String(format: "%d:%02d", $0 / 60, $0 % 60) }, label: "Time", icon: "clock.fill", tint: .accent, delay: 0.42)
                DoneTile(value: known, format: { "\($0)%" }, label: "Knew them", icon: "checkmark.circle.fill", tint: .good, delay: 0.64)
            }
            .padding(.top, 22)
            Spacer(minLength: 16)
            Button("Continue") { dismiss() }.buttonStyle(WideButton())
                .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.success, trigger: finished)
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
