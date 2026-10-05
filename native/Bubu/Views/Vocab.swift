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

// MARK: - flashcards (web: startFlash)

struct FlashPage: View {
    let ids: [String]
    @Environment(Router.self) private var router
    @State private var cards: [Card] = []
    @State private var index = 0
    @State private var flipped = false
    private let course = Course.shared

    var body: some View {
        VStack(spacing: 18) {
            if !cards.isEmpty {
                let c = cards[index]
                ProgressBarShine(value: Double(index + 1) / Double(cards.count))
                ZStack {
                    face {
                        VStack(spacing: 8) {
                            Text(c.word.hanzi).font(.hanzi(c.word.hanzi.count > 3 ? 44 : 64, .medium)).foregroundStyle(Color.ink)
                                .minimumScaleFactor(0.5).lineLimit(1)
                            Text("tap to flip").font(.nunito(13)).foregroundStyle(Color.muted)
                        }
                    }
                    .opacity(flipped ? 0 : 1)
                    face {
                        VStack(spacing: 10) {
                            if let pic = Pictures.asset(c.word.hanzi) {
                                Image(pic).resizable().scaledToFit().frame(height: 70)
                            }
                            TappableHanzi(text: c.word.hanzi, pinyin: c.word.pinyin, size: 30, weight: .bold)
                            PinyinText(pinyin: c.word.pinyin, size: 26)
                            Text(c.word.pos.map { "\(c.word.en) · \($0)" } ?? c.word.en)
                                .font(.nunito(18, .semibold)).foregroundStyle(Color.ink).multilineTextAlignment(.center)
                            HStack(spacing: 10) {
                                SpeakerButton(text: c.word.hanzi, size: 22)
                                Button { Speech.shared.speak(c.word.hanzi, slow: true) } label: {
                                    Text("½×").font(.nunitoXB(15)).foregroundStyle(Color.accent).padding(6)
                                }
                                .buttonStyle(.plain)
                                if StrokeData.shared.writable(c.word.hanzi) {
                                    Button { router.push(.writingSheet(c.word.hanzi)) } label: {
                                        Image(systemName: "pencil.line").font(.system(size: 20)).foregroundStyle(Color.accent).padding(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    .opacity(flipped ? 1 : 0)
                }
                .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                .onTapGesture { withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { flipped.toggle() } }
                .gesture(DragGesture(minimumDistance: 30).onEnded { v in
                    if v.translation.width < -40 { step(1) } else if v.translation.width > 40 { step(-1) }
                })
                .sensoryFeedback(.impact(weight: .light), trigger: flipped)

                HStack(spacing: 10) {
                    round("chevron.left") { step(-1) }
                    Button("Flip") { withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { flipped.toggle() } }
                        .buttonStyle(WideButton())
                    round("chevron.right") { step(1) }
                }
            }
        }
        .padding(18)
        .frame(maxHeight: .infinity, alignment: .top)
        .navigationTitle(cards.isEmpty ? "Flashcards" : "Flashcards · \(index + 1) / \(cards.count)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { cards.shuffle(); index = 0; flipped = false } label: { Image(systemName: "shuffle") }
            }
        }
        .onAppear { if cards.isEmpty { cards = ids.compactMap { course.cardById[$0] }.shuffled() } }
    }

    private func face<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        c().frame(maxWidth: .infinity, minHeight: 320).padding(20)
            .background(Color.panel, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.line))
            .panelShadow()
    }

    private func round(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundStyle(Color.accent)
                .frame(width: 54, height: 50).background(Color.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressDown(depth: 1))
    }

    private func step(_ d: Int) {
        flipped = false
        withAnimation(.easeOut(duration: 0.2)) { index = (index + d + cards.count) % cards.count }
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
