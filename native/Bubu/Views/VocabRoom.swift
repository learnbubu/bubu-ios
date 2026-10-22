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
        .onAppear { garden = VocabGarden(progress) }
        // (looked up a moment after the typing stops, not at every letter)
        .task(id: query) {
            let q = query
            try? await Task.sleep(for: .milliseconds(140))
            guard !Task.isCancelled else { return }
            results = VocabSearch.find(q)
        }
    }

    // MARK: the room

    private var header: some View {
        ZStack(alignment: .topLeading) {
            BackPill(label: "Classroom") { dismiss() }
            Text("Vocabulary").font(.nunito(34, .black)).tracking(-0.5).foregroundStyle(Home.ink)
                .frame(maxHeight: .infinity, alignment: .bottom).padding(.leading, 2).padding(.bottom, 6)
            Image("panda-flashcards").resizable().scaledToFit().frame(width: 104)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: 4, y: 26).allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 100)
        .zIndex(1)
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
        .background(Color(UIColor(hex: 0xFFFDF8)), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(searching ? Home.teal : Home.line, lineWidth: 1.5))
        .padding(.bottom, 14)
    }

    @ViewBuilder
    private func room(_ g: VocabGarden) -> some View {
        today(g)
        section("Your words")
        HStack(spacing: 9) {
            gardenTile("🌱", g.fresh.count, "New") { flash(g.fresh, 12) }
            gardenTile("🌿", g.growing.count, "Growing") { flash(g.growing, 15) }
            gardenTile("🌸", g.blooming.count, "Blooming") { flash(g.blooming, 15) }
        }
        section("Ways to practise")
        HStack(spacing: 9) {
            way("🃏", "Flashcards", "see it, say it, flip", bg: 0xD6E9FB, lip: 0xBCD5EC) { flash(g.today, g.today.count) }
            way("🧩", "Match", "pairs against the clock", bg: 0xE5DCFA, lip: 0xCFC2EE) { router.push(.match(g.today.map(\.id))) }
            way("✅", "Quiz", "pick the right one", bg: 0xD3EEDB, lip: 0xB9DCC4) {
                router.start(StudySession.quiz(progress, cards: g.today, focuses: ["recognize", "recall", "pinyin", "listen"], tooFew: "Learn a few words first, then quiz them."))
            }
        }
        .disabled(g.today.isEmpty)
        .opacity(g.today.isEmpty ? 0.5 : 1)
    }

    /// Today's words: one tap to practise them, as flashcards.
    private func today(_ g: VocabGarden) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TODAY'S WORDS").font(.nunito(11, .black)).tracking(1.5).foregroundStyle(.white.opacity(0.72))
            Text(g.today.isEmpty ? "No words yet" : "\(g.today.count) words to practise")
                .font(.nunito(23, .black)).foregroundStyle(.white).padding(.top, 3)
            Text(g.today.isEmpty ? "Learn your first words on the path" : "the ones you're learning, and a few new")
                .font(.nunito(13.5, .bold)).foregroundStyle(.white.opacity(0.82)).padding(.top, 1)
            if !g.today.isEmpty {
                // (as many as fit on one line, then how many more)
                ViewThatFits(in: .horizontal) {
                    ForEach([6, 5, 4, 3, 2], id: \.self) { n in chips(g.today, n) }
                }
                .padding(.top, 12)
            }
            Button {
                if g.today.isEmpty { router.toPath() } else { flash(g.today, g.today.count) }
            } label: {
                Text(g.today.isEmpty ? "To the path" : "Start · about \(max(1, (g.today.count * 15 + 59) / 60)) min")
                    .font(.nunito(17, .black)).foregroundStyle(Home.teal)
            }
            .buttonStyle(LipButton(face: .white, lip: Color(UIColor(hex: 0xCFE3DC)), radius: 15, depth: 4))
            .frame(height: 50)
            .padding(.top, 14)
        }
        .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Home.tealDark).offset(y: 5)
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Home.teal)
            }
        }
        .padding(.bottom, 5)
    }

    private func chips(_ cards: [Card], _ n: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(cards.prefix(n), id: \.id) { c in
                Text(c.word.hanzi).font(.hanzi(16, .medium)).foregroundStyle(.white).lineLimit(1).fixedSize()
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            if cards.count > n {
                Text("+\(cards.count - n)").font(.nunito(13, .black)).foregroundStyle(.white).fixedSize()
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private func section(_ t: String) -> some View {
        Text(t).font(.nunito(15, .heavy)).foregroundStyle(Home.ink).padding(.top, 20).padding(.bottom, 8)
    }

    private func gardenTile(_ icon: String, _ n: Int, _ label: String, go: @escaping () -> Void) -> some View {
        Button(action: go) {
            VStack(spacing: 2) {
                Text(icon).font(.system(size: 24))
                Text("\(n)").font(.nunito(21, .black)).monospacedDigit().foregroundStyle(Home.teal)
                Text(label).font(.nunito(12, .heavy)).foregroundStyle(Home.muted)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(Color(UIColor(hex: 0xFFFDF8)), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Home.line, lineWidth: 1.5))
        }
        .buttonStyle(PressDown(depth: 2))
        .disabled(n == 0)
        .opacity(n == 0 ? 0.55 : 1)
        .accessibilityLabel("\(label) words: \(n). Practise them")
    }

    private func way(_ icon: String, _ title: String, _ sub: String, bg: UInt32, lip: UInt32, go: @escaping () -> Void) -> some View {
        Button(action: go) {
            VStack(alignment: .leading, spacing: 0) {
                Text(icon).font(.system(size: 26))
                Text(title).font(.nunito(15, .black)).foregroundStyle(Home.ink).padding(.top, 4)
                Text(sub).font(.nunito(11.5, .bold)).foregroundStyle(Home.muted).fixedSize(horizontal: false, vertical: true).padding(.top, 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 10).padding(.top, 12).padding(.bottom, 11)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(UIColor(hex: lip))).offset(y: 3)
                    RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(UIColor(hex: bg)))
                }
            }
        }
        .buttonStyle(PressDown(depth: 2))
        .fixedSize(horizontal: false, vertical: true)
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
                Text("No words match that.").font(.nunito(14, .bold)).foregroundStyle(Home.muted).padding(.top, 10)
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
                    .frame(width: 46, height: 50)
                    .background(Color(UIColor(hex: 0xFFFDF8)), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Home.line, lineWidth: 1.5))
            }
            .buttonStyle(PressDown(depth: 1))
            .accessibilityLabel("Clear your list")
            Button { router.push(.flash(course.cards.filter { picks.ids.contains($0.id) }.map(\.id))) } label: {
                Text("Practise your \(picks.ids.count) word\(picks.ids.count == 1 ? "" : "s")").font(.nunito(17, .black)).foregroundStyle(.white)
            }
            .buttonStyle(LipButton(face: Home.teal, lip: Home.tealDark, radius: 15, depth: 4))
            .frame(height: 50)
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
