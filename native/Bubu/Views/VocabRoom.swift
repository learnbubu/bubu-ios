import SwiftUI

/// The Classroom's Vocabulary (the owner's board G, 22 Oct 2026): one big Start on today's words, chosen for you
/// (no picking first); your words as a garden, new, growing and blooming, each a tap from practice; three ways to
/// practise on today's words; and a search, in English, 汉字 or pinyin, for words you'd like to practise, put on
/// your own list. Light only, as the Classroom.
///
/// Quick to open: the garden and today's words are worked out once as it appears (a pass over the words, not a
/// view per word), and the search looks through a ready-made index, only once you've typed, a few dozen rows at most.
struct VocabRoom: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var picks = Picks.shared
    @State private var garden: VocabGarden?
    @State private var query = ""
    @State private var results: [Card] = []
    /// the typing the results are for
    @State private var resultsFor = ""
    @FocusState private var searching: Bool
    private let course = Course.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                searchField
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    if let g = garden { room(g) } else { ProgressView().frame(maxWidth: .infinity).padding(.top, 60) }
                } else {
                    searchResults
                }
            }
            .padding(.horizontal, 18).padding(.top, 4).padding(.bottom, picks.ids.isEmpty ? 24 : 96)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .overlay(alignment: .bottom) { if !picks.ids.isEmpty { myList } }
        .background(Home.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .environment(\.colorScheme, .light)
        .onAppear {
            garden = VocabGarden(progress)
            // (the search's index made now, off the main thread, not at the first letter typed: the first search
            // said "No words match" for a second while it was made)
            Task.detached(priority: .utility) { VocabSearch.warm() }
        }
        // (looked up a moment after the typing stops, not at every letter; the results say which typing they're for,
        // so an old search's are never taken for this one's)
        .task(id: query) {
            let q = query
            try? await Task.sleep(for: .milliseconds(140))
            guard !Task.isCancelled else { return }
            let found = await Task.detached(priority: .userInitiated) { VocabSearch.find(q) }.value
            guard !Task.isCancelled, q == query else { return }
            results = found; resultsFor = q
        }
    }

    // MARK: the room

    private var header: some View {
        ZStack(alignment: .topLeading) {
            BackPill(label: "Classroom") { dismiss() }
            Text("Vocabulary").font(.nunito(34, .black)).tracking(-0.5).foregroundStyle(Home.ink)
                .frame(maxHeight: .infinity, alignment: .bottom).padding(.leading, 2).padding(.bottom, 6)
            // (inside the header, his feet on its foot: hung below it, he covered the search field's end; the Mac,
            // 22 Oct 2026)
            Image("panda-flashcards").resizable().scaledToFit().frame(height: 94)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.bottom, 4).allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 100)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 15, weight: .bold)).foregroundStyle(Home.muted)
            TextField("Find a word: English, 汉字 or pinyin", text: $query)
                .font(.nunito(15.5, .bold)).foregroundStyle(Home.ink)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .focused($searching).submitLabel(.search)
            if !query.isEmpty {
                Button { query = ""; searching = false } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 17)).foregroundStyle(Home.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).frame(height: 46)
        .background(Color(UIColor(hex: 0xFFFDF8)), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(searching ? Home.teal : Home.line, lineWidth: 1.5))
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private func room(_ g: VocabGarden) -> some View {
        today(g)
        section("Your words")
        // the Classroom's catch-up cells
        HStack(spacing: 8) {
            cell(g.fresh.count, "New", art: "vocab-seed", icon: "🌱", ink: 0x1F7A6C) { flash(g.fresh, 12) }
            cell(g.growing.count, "Growing", art: "vocab-grow", icon: "🌿", ink: 0xB7822E) { flash(g.growing, 15) }
            cell(g.blooming.count, "Blooming", art: "vocab-bloom", icon: "🌸", ink: 0xD9608A) { flash(g.blooming, 15) }
        }
        section("Ways to practise")
        // the Classroom's tiles
        HStack(spacing: 11) {
            tile(Self.art("vocab-flash", or: "class-vocab"), "Flashcards", bg: 0xD6E9FB) { flash(g.today, g.today.count) }
            tile(Self.art("vocab-match", or: "class-chars"), "Match", bg: 0xFCEBB8) { router.push(.match(g.today.map(\.id))) }
            tile("class-quiz", "Quiz", bg: 0xE5DCFA) {
                router.start(StudySession.quiz(progress, cards: g.today, focuses: ["recognize", "recall", "pinyin", "listen"], tooFew: "Learn a few words first, then quiz them."))
            }
        }
        .disabled(g.today.isEmpty)
        .opacity(g.today.isEmpty ? 0.5 : 1)
    }

    /// Today's words, as Home's Up next card: its kicker, title and line, a bar (how many of the words you've reached
    /// you've learnt), and its one raised button.
    private func today(_ g: VocabGarden) -> some View {
        let reached = g.fresh.count + g.growing.count + g.blooming.count
        let learnt = g.growing.count + g.blooming.count
        return VStack(alignment: .leading, spacing: 0) {
            Text("Today's words").font(.nunito(12, .black)).tracking(1.4).textCase(.uppercase).foregroundStyle(Home.teal)
            Text(g.today.isEmpty ? "No words yet" : "\(g.today.count) words to practise")
                .font(.nunito(25, .black)).tracking(-0.3).foregroundStyle(Home.ink).padding(.top, 4)
            Text(g.today.isEmpty ? "Learn your first words on the path" : "The ones you're learning, and a few new")
                .font(.nunito(15.5, .bold)).foregroundStyle(Home.muted)
            if !g.today.isEmpty {
                // (as many as fit on one line, then how many more)
                ViewThatFits(in: .horizontal) {
                    ForEach([6, 5, 4, 3, 2], id: \.self) { n in chips(g.today, n) }
                }
                .padding(.top, 11)
            }
            HStack(spacing: 10) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(UIColor(hex: 0xD3DED8)))
                        Capsule().fill(Home.teal).frame(width: geo.size.width * (reached == 0 ? 0 : Double(learnt) / Double(reached)))
                    }
                }
                .frame(height: 10)
                Text("\(learnt) / \(reached) learnt").font(.nunito(12.5, .heavy)).monospacedDigit().foregroundStyle(Home.muted).fixedSize()
            }
            .padding(.top, 13)
            Button {
                if g.today.isEmpty { router.toPath() } else { flash(g.today, g.today.count) }
            } label: {
                Text(g.today.isEmpty ? "To the path →" : "Start flashcards →").font(.nunito(18, .black)).foregroundStyle(.white)
            }
            .buttonStyle(LipButton(face: Home.teal, lip: Home.tealDark, radius: 17, depth: 4))
            .frame(height: 56)
            .padding(.top, 15)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 17).padding(.top, 15).padding(.bottom, 17)
        .background(alignment: .topTrailing) {
            // a garden bed in the corner, as Up next's hills: to the right, faded out towards the bottom
            if UIImage(named: "vocab-bed") != nil {
                GeometryReader { geo in
                    Image("vocab-bed").resizable().scaledToFit()
                        .frame(width: geo.size.width * 0.55)
                        .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.55), .init(color: .clear, location: 1)],
                                             startPoint: .top, endPoint: .bottom))
                        .opacity(0.6)
                        .offset(x: 2, y: 4)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .allowsHitTesting(false)
            }
        }
        .background(LinearGradient(colors: [Color(UIColor(hex: 0xEEF7F2)), Color(UIColor(hex: 0xE2EFE8))], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color(UIColor(hex: 0xD7E8DF)), lineWidth: 1))
        .shadow(color: Color(UIColor(hex: 0x1E463C)).opacity(0.08), radius: 8, y: 6)
    }

    private func chips(_ cards: [Card], _ n: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(cards.prefix(n), id: \.id) { c in
                Text(c.word.hanzi).font(.hanzi(16, .medium)).foregroundStyle(Home.ink).lineLimit(1).fixedSize()
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            if cards.count > n {
                Text("+\(cards.count - n)").font(.nunito(13, .black)).foregroundStyle(Home.teal).fixedSize()
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private func section(_ t: String) -> some View {
        Text(t).font(.nunito(15, .heavy)).foregroundStyle(Home.ink).padding(.top, 18).padding(.bottom, 8)
    }

    /// A catch-up cell, as the Classroom's: the number in its colour, its name under it.
    /// (its picture, when it's in; the emoji until then)
    private func cell(_ n: Int, _ label: String, art: String, icon: String, ink: UInt32, go: @escaping () -> Void) -> some View {
        let pic = UIImage(named: art) != nil
        return Button(action: go) {
            VStack(spacing: 0) {
                if pic { Image(art).resizable().scaledToFit().frame(height: 34).padding(.bottom, 2) }
                Text("\(n)").font(.nunito(21, .black)).monospacedDigit().foregroundStyle(Color(UIColor(hex: ink)))
                Text(pic ? label : "\(icon) \(label)").font(.nunito(11, .heavy)).foregroundStyle(Home.muted).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 8).padding(.horizontal, 6)
            .background(Color(UIColor(hex: 0xFFFDF8)), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Home.line, lineWidth: 1.5))
        }
        .buttonStyle(PressDown(depth: 2))
        .disabled(n == 0)
        .opacity(n == 0 ? 0.55 : 1)
        .accessibilityLabel("\(label) words: \(n). Practise them")
    }

    /// A picture, or the one standing in for it until it's in.
    static func art(_ name: String, or stand: String) -> String { UIImage(named: name) != nil ? name : stand }

    /// A practice tile, as the Classroom's: its picture above, its name on a pale band along the bottom.
    private func tile(_ art: String, _ title: String, bg: UInt32, go: @escaping () -> Void) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous), h: CGFloat = 106
        return Button(action: go) {
            VStack(spacing: 0) {
                Image(art).resizable().scaledToFit()
                    .frame(height: h * 0.64 * 0.86)
                    .padding(.top, h * 0.07).padding(.horizontal, 8)
                Spacer(minLength: 0)
                Text(title).font(.nunito(14.5, .black)).foregroundStyle(Home.ink).lineLimit(1).minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity).padding(.top, 6).padding(.bottom, 7)
                    .background(Color(UIColor(hex: 0xFFFDF8)).opacity(0.62))
            }
            .frame(maxWidth: .infinity).frame(height: h)
            .background(Color(UIColor(hex: bg)))
            .clipShape(shape)
            .background(shape.fill(.black.opacity(0.08)).offset(y: 4))
            .contentShape(shape)
        }
        .buttonStyle(PressDown(depth: 2))
    }

    private func flash(_ cards: [Card], _ n: Int) {
        let pick = Array(cards.prefix(n))
        guard !pick.isEmpty else { return }
        router.push(.flash(pick.map(\.id)))
    }

    // MARK: searching

    private var searchResults: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            if results.isEmpty {
                // (only once this typing's been looked up)
                if resultsFor == query {
                    VStack(spacing: 6) {
                        if UIImage(named: "panda-searching") != nil {
                            Image("panda-searching").resizable().scaledToFit().frame(height: 130)
                        }
                        Text("No words match that.").font(.nunito(15, .heavy)).foregroundStyle(Home.ink)
                        Text("Try English, 汉字 or pinyin").font(.nunito(13, .bold)).foregroundStyle(Home.muted)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 24)
                }
            } else {
                Text("Tap ＋ to put a word on your list").font(.nunito(12.5, .bold)).foregroundStyle(Home.muted).padding(.bottom, 8)
                ForEach(results, id: \.id) { c in resultRow(c) }
            }
        }
    }

    private func resultRow(_ c: Card) -> some View {
        let on = picks.ids.contains(c.id)
        return HStack(spacing: 12) {
            Text(stage(c)).font(.system(size: 18)).frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(c.word.hanzi).font(.hanzi(20, .medium)).foregroundStyle(Home.ink)
                    Text(c.word.pinyin).font(.nunito(13.5, .bold)).foregroundStyle(Color(UIColor(hex: 0xB7822E))).lineLimit(1)
                }
                Text(c.word.gloss).font(.nunito(13.5, .bold)).foregroundStyle(Home.muted).lineLimit(1)
            }
            Spacer(minLength: 0)
            SpeakerButton(text: c.word.hanzi, size: 18)
            Button {
                if on { picks.ids.remove(c.id) } else { picks.ids.insert(c.id) }
            } label: {
                Image(systemName: on ? "checkmark" : "plus").font(.system(size: 15, weight: .black))
                    .foregroundStyle(on ? .white : Home.teal)
                    .frame(width: 36, height: 36)
                    .background(on ? Home.teal : Home.tealSoft, in: Circle())
            }
            .buttonStyle(PressDown(depth: 1))
            .accessibilityLabel(on ? "On your list: take it off" : "Put it on your list")
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) { Rectangle().fill(Home.line).frame(height: 1) }
    }

    /// 🌱 not learnt yet, 🌿 growing, 🌸 blooming (well learnt)
    private func stage(_ c: Card) -> String {
        if progress.isMastered(c.id) { return "🌸" }
        return (progress.srs[c.id]?.reps ?? 0) > 0 ? "🌿" : "🌱"
    }

    /// Your list, from the search: practise it, or let it go.
    private var myList: some View {
        HStack(spacing: 10) {
            Button { picks.ids.removeAll() } label: {
                Image(systemName: "xmark").font(.system(size: 14, weight: .black)).foregroundStyle(Home.muted)
                    .frame(width: 50, height: 52)
                    .background(Color(UIColor(hex: 0xFFFDF8)), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Home.line, lineWidth: 1.5))
            }
            .buttonStyle(PressDown(depth: 1))
            .accessibilityLabel("Clear your list")
            Button { router.push(.flash(course.cards.filter { picks.ids.contains($0.id) }.map(\.id))) } label: {
                Text("Practise your \(picks.ids.count) word\(picks.ids.count == 1 ? "" : "s")").font(.nunito(17, .black)).foregroundStyle(.white)
            }
            .buttonStyle(LipButton(face: Home.teal, lip: Home.tealDark, radius: 17, depth: 4))
            .frame(height: 56)
        }
        .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 12)
        .background(Home.bg.shadow(color: .black.opacity(0.06), radius: 8, y: -3).ignoresSafeArea(edges: .bottom))
    }
}

/// Your words, sorted for the room once as it opens: 🌱 new (in the lessons you've reached, not learnt yet),
/// 🌿 growing (learnt, not yet well), 🌸 blooming (well learnt), and today's dozen to practise: those falling due,
/// the shakiest of the growing ones, and a few new from where you are.
struct VocabGarden {
    let fresh: [Card], growing: [Card], blooming: [Card], today: [Card]

    init(_ p: ProgressStore) {
        let course = Course.shared
        let here = p.currentLessonId.flatMap { course.lessonOrder[$0] } ?? .max
        var fresh: [Card] = [], growing: [Card] = [], blooming: [Card] = []
        for c in course.cards where !c.isSentence {
            if p.isMastered(c.id) { blooming.append(c) }
            else if (p.srs[c.id]?.reps ?? 0) > 0 { growing.append(c) }
            else if (course.lessonOrder[c.lessonId] ?? .max) <= here { fresh.append(c) }
        }
        // (the shakiest first: the ones forgotten most, then the least sure)
        growing.sort { a, b in
            let sa = p.srs[a.id], sb = p.srs[b.id]
            if (sa?.lapses ?? 0) != (sb?.lapses ?? 0) { return (sa?.lapses ?? 0) > (sb?.lapses ?? 0) }
            return (sa?.ease ?? 2.4) < (sb?.ease ?? 2.4)
        }
        // (newest learnt first among the new: the lesson you're on, then the ones just before it)
        fresh.sort { (course.lessonOrder[$0.lessonId] ?? 0) > (course.lessonOrder[$1.lessonId] ?? 0) }
        self.fresh = fresh; self.growing = growing; self.blooming = blooming.shuffled()

        var today: [Card] = [], seen = Set<String>()
        func take(_ cs: [Card], _ n: Int) { for c in cs where today.count < n && !c.isSentence && seen.insert(c.id).inserted { today.append(c) } }
        take(p.dueReviewCards(), 6)
        take(growing, 9)
        take(fresh, 12)
        take(growing, 12)
        self.today = today.shuffled()
    }
}

/// Finding words as you type, in English, 汉字 or pinyin (with or without tones and spaces): a ready-made index of
/// every word, and the best matches first (the whole word, then its start, then anywhere in it).
enum VocabSearch {
    private struct Entry { let card: Card; let han: String; let en: [String]; let py: String; let pyJoined: String }
    private static let index: [Entry] = {
        var seen = Set<String>()
        return Course.shared.cards.compactMap { c in
            guard !c.isSentence, seen.insert(c.word.hanzi + "|" + c.word.en).inserted else { return nil }
            let py = Pinyin.toneless(c.word.pinyin).lowercased()
            let en = c.word.en.lowercased().split(whereSeparator: { !$0.isLetter && $0 != "'" }).map(String.init)
            return Entry(card: c, han: c.word.hanzi, en: en, py: py, pyJoined: py.replacingOccurrences(of: " ", with: ""))
        }
    }()

    /// Makes the index (it's made once).
    static func warm() { _ = index.count }

    static func find(_ raw: String, limit: Int = 40) -> [Card] {
        let q = raw.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        let han = q.contains(where: Course.isHan)
        let qp = Pinyin.toneless(q).lowercased(), qj = qp.replacingOccurrences(of: " ", with: "")
        var scored: [(Int, Card)] = []
        for e in index {
            var s = 0
            if han {
                if e.han == q { s = 100 } else if e.han.hasPrefix(q) { s = 80 } else if e.han.contains(q) { s = 50 }
            } else {
                // English: a whole word in its meaning first ("eat" finds 吃 before "beat")
                if e.en.contains(q) { s = 90 } else if e.en.contains(where: { $0.hasPrefix(q) }) { s = 60 }
                else if q.count >= 3, e.en.joined(separator: " ").contains(q) { s = 30 }
                // pinyin, its tones optional
                if e.py == qp || e.pyJoined == qj { s = max(s, 95) } else if e.pyJoined.hasPrefix(qj) { s = max(s, 70) }
            }
            if s > 0 { scored.append((s - min(e.han.count, 6), e.card)) }
        }
        return scored.sorted { $0.0 > $1.0 }.prefix(limit).map(\.1)
    }
}
