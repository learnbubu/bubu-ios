import SwiftUI

// Characters, in two levels (the owner, 25 Oct 2026: "super complex, laggy and not very user friendly"; then, "once
// you know even more will be hard?"): the front is what's due today and your books, each a row with its progress, the
// same short page at 50 characters or 1,500; a book opens to its chapters' characters. Every character's level is
// worked out once as a page opens, not at every redraw (the old page scored all 1,620 at each keystroke), and only the
// rows on screen are drawn.

/// Where each character first comes in the course: its chapter and its book.
enum CharIndex {
    struct Entry { let ch: String; let chapter: Int; let book: String; let pinyin: String }
    static let entries: [Entry] = {
        let course = Course.shared
        return Course.allChars.compactMap { item in
            guard let card = Course.cardsWithChar[item.ch]?.first, let ci = course.chapterOf[card.lessonId] else { return nil }
            return Entry(ch: item.ch, chapter: ci, book: course.chapters[ci].unit, pinyin: reading(item.ch, in: card))
        }
    }()
    static let pinyin: [String: String] = Dictionary(entries.map { ($0.ch, $0.pinyin) }, uniquingKeysWith: { a, _ in a })

    /// A character's reading as the course has it: its syllable in the first word it comes in (呢 is "ne" there, "né"
    /// in the dictionary: the Mac, 0.2.33), else the dictionary's.
    static func reading(_ ch: String, in card: Card) -> String {
        let han = card.word.hanzi.filter(Course.isHan).map(String.init), ss = Pinyin.syllables(card.word.pinyin)
        if han.count == ss.count, let i = han.firstIndex(of: ch) { return ss[i].lowercased() }
        return CharData.shared.chars[ch]?.p ?? ""
    }
    /// the books in course order
    static let books: [String] = entries.map(\.book).reduce(into: []) { if !$0.contains($1) { $0.append($1) } }
    static let byBook: [String: [Entry]] = Dictionary(grouping: entries, by: \.book)
}

/// Every character's level and whether it's due, worked out once (see ProgressStore.charLevel).
struct CharStats {
    var level: [String: Int] = [:]
    var due: Set<String> = []
    static func now(_ p: ProgressStore, _ entries: [CharIndex.Entry] = CharIndex.entries) -> CharStats {
        var s = CharStats()
        for e in entries {
            let lv = p.charLevel(e.ch)
            s.level[e.ch] = lv
            if lv > 0 && p.charDue(e.ch) { s.due.insert(e.ch) }
        }
        return s
    }
    func lv(_ ch: String) -> Int { level[ch] ?? 0 }
}

// MARK: - the front: today, and your books

struct CharactersPage: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(Router.self) private var router
    @State private var stats = CharStats()
    @State private var searching = false
    @State private var query = ""

    var body: some View {
        let met = stats.level.values.filter { $0 > 0 }.count
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if searching {
                    SearchField(text: $query, prompt: "Search 字, pinyin or meaning", autofocus: true).padding(.bottom, 12)
                }
                if searching && !query.trimmingCharacters(in: .whitespaces).isEmpty {
                    CharResults(query: query, stats: stats)
                } else {
                    dueCard.padding(.bottom, 18)
                    Text("YOUR BOOKS · \(met) OF \(CharIndex.entries.count)")
                        .font(.nunito(11.5, .black)).tracking(1.1).foregroundStyle(Color.muted)
                        .padding(.horizontal, 2).padding(.bottom, 8)
                    LazyVStack(spacing: 9) {
                        ForEach(CharIndex.books, id: \.self) { b in bookRow(b) }
                    }
                    Text("Character breakdowns from Make Me a Hanzi (LGPL).")
                        .font(.nunito(12)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity).padding(.vertical, 22)
                }
            }
            .padding(.horizontal, 18).padding(.top, 4)
        }
        .scrollDismissesKeyboard(.interactively)
        .pageBar("Characters") {
            Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { searching.toggle(); if !searching { query = "" } } } label: {
                Image(systemName: searching ? "xmark" : "magnifyingglass").font(.system(size: 16, weight: .bold)).foregroundStyle(Color.ink)
                    .frame(width: 40, height: 40).background(PageBar<EmptyView>.pill, in: Circle())
                    .overlay(Circle().stroke(Color.line, lineWidth: 1.5))
            }
            .buttonStyle(PressDown(depth: 2))
            .accessibilityLabel(searching ? "Close the search" : "Search the characters")
        }
        .onAppear { stats = CharStats.now(progress) }
    }

    /// Today's due characters: a few of them, and one button to practise them all.
    private var dueCard: some View {
        let due = CharIndex.entries.filter { stats.due.contains($0.ch) }.map(\.ch)
        return VStack(alignment: .leading, spacing: 10) {
            if due.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 26)).foregroundStyle(Color.good)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Nothing due today").font(.nunito(17, .black)).foregroundStyle(Color.ink)
                        Text("Every character you've met is fresh. Come back tomorrow.").font(.nunito(13, .semibold)).foregroundStyle(Color.muted)
                    }
                }
            } else {
                Text("\(due.count) due today").font(.nunito(18, .black)).foregroundStyle(Color.ink)
                HStack(spacing: 6) {
                    ForEach(due.prefix(5), id: \.self) { ch in
                        Text(ch).font(.hanzi(21, .bold)).foregroundStyle(Color.ink)
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                            .background(Color.goldSoft, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Color.gold.opacity(0.45), lineWidth: 1.5))
                    }
                    if due.count > 5 {
                        Text("+\(due.count - 5)").font(.nunito(14, .black)).foregroundStyle(Color.muted)
                            .frame(maxWidth: .infinity).padding(.vertical, 9)
                    }
                }
                Button { router.start(Self.practice(progress, due: Set(due))) } label: { Text("Practise them") }
                    .buttonStyle(RaisedButton(fill: Color.accent, ink: Color.onAccent))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.line, lineWidth: 1.5))
        .background(Color.line, in: RoundedRectangle(cornerRadius: 18, style: .continuous).offset(y: 4))
    }

    /// A book: its name, how many of its characters you've met, and what's due; a book not reached yet, quietly.
    private func bookRow(_ b: String) -> some View {
        let entries = CharIndex.byBook[b] ?? []
        let met = entries.filter { stats.lv($0.ch) > 0 }.count
        let due = entries.filter { stats.due.contains($0.ch) }.count
        let started = met > 0
        return Button { router.push(.charBook(b)) } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(b).font(.hanzi(18, .heavy)).foregroundStyle(Color.ink)
                    Spacer(minLength: 6)
                    if due > 0 {
                        Text("\(due) due").font(.nunito(12.5, .black)).foregroundStyle(Color.gold)
                            .padding(.horizontal, 8).padding(.vertical, 3).background(Color.goldSoft, in: Capsule())
                    }
                    Image(systemName: started ? "chevron.right" : "lock.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.muted)
                }
                if started {
                    ProgressBarShine(value: max(0.03, Double(met) / Double(max(1, entries.count))), height: 10)
                    Text("\(met) / \(entries.count) characters").font(.nunito(12.5, .bold)).foregroundStyle(Color.muted)
                } else {
                    Text("\(entries.count) characters to come").font(.nunito(12.5, .bold)).foregroundStyle(Color.muted)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(Tile3D(fill: Color.panel, edge: Color.line, radius: 16))
        .disabled(!started)
        .opacity(started ? 1 : 0.6)
    }

    /// A session on the characters due: their words that are due, up to twenty.
    static func practice(_ p: ProgressStore, due: Set<String>) -> StudySession? {
        let t = p.now()
        var seen = Set<String>()
        let cards = Course.shared.cards.filter { c in
            !c.isSentence && (p.srs[c.id]?.due).map { $0 <= t } == true
                && c.word.hanzi.contains { due.contains(String($0)) } && seen.insert(c.id).inserted
        }
        guard !cards.isEmpty else { Moments.shared.toast("Nothing due yet - come back later."); return nil }
        return StudySession(lessonId: "", progress: p, cards: Array(cards.prefix(20)), mode: .review, title: "Characters")
    }
}

// MARK: - a book: its chapters' characters

struct CharBookPage: View {
    let book: String
    @Environment(ProgressStore.self) private var progress
    @State private var stats = CharStats()
    @State private var show = "all"
    private let course = Course.shared

    var body: some View {
        let entries = CharIndex.byBook[book] ?? []
        let chapters = entries.map(\.chapter).reduce(into: [Int]()) { if !$0.contains($1) { $0.append($1) } }
        let met = entries.filter { stats.lv($0.ch) > 0 }.count
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                tabs.padding(.bottom, 6)
                ForEach(chapters, id: \.self) { ci in chapter(ci, entries.filter { $0.chapter == ci }) }
                Text("A green edge is a character you know well; a gold dot, one due for review.")
                    .font(.nunito(12)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity).padding(.vertical, 22)
            }
            .padding(.horizontal, 18).padding(.top, 4)
        }
        .pageBar(book) { BarCount(text: "\(met) / \(entries.count)") }
        .onAppear { stats = CharStats.now(progress, entries) }
    }

    private func passes(_ ch: String) -> Bool {
        let lv = stats.lv(ch)
        switch show {
        case "due": return stats.due.contains(ch)
        case "learning": return lv == 1 || lv == 2
        case "known": return lv == 3
        default: return true
        }
    }

    private var tabs: some View {
        HStack(spacing: 3) {
            ForEach([("all", "All"), ("due", "Due"), ("learning", "Learning"), ("known", "Known")], id: \.0) { t in
                Button { withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) { show = t.0 } } label: {
                    Text(t.1).font(.nunito(13.5, .black)).foregroundStyle(show == t.0 ? Color.ink : Color.muted)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background {
                            if show == t.0 {
                                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.panel)
                                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.line.opacity(0.7), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    /// A chapter: its characters (those not met yet, faint), or, not reached, one line; filtered, only what passes.
    @ViewBuilder
    private func chapter(_ ci: Int, _ entries: [CharIndex.Entry]) -> some View {
        let reached = entries.contains { stats.lv($0.ch) > 0 }
        let shown = entries.filter { passes($0.ch) }
        let n = course.chapters[0...ci].filter { $0.unit == book }.count
        if show == "all" || !shown.isEmpty {
            Text("CHAPTER \(n) · \(course.chapters[ci].title.uppercased())")
                .font(.nunito(11.2, .black)).tracking(1.0).foregroundStyle(Color.accent).lineLimit(1)
                .padding(.top, 16).padding(.bottom, 8).padding(.horizontal, 2)
            if show == "all" && !reached {
                Text("\(entries.count) characters · learn them on the path").font(.nunito(13, .bold)).foregroundStyle(Color.muted)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14).padding(.vertical, 11)
                    .background(Color.line.opacity(0.45), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                CharGrid(chars: shown.map(\.ch), stats: stats)
            }
        }
    }
}

// MARK: - pieces

/// Characters as raised tiles, five across: the character, its pinyin, its strength on its edge, a gold dot when due.
struct CharGrid: View {
    let chars: [String]
    let stats: CharStats
    private let cd = CharData.shared
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 5), spacing: 9) {
            ForEach(chars, id: \.self) { ch in tile(ch) }
        }
    }
    private func tile(_ ch: String) -> some View {
        let lv = stats.lv(ch)
        let edge: Color = lv == 3 ? .good : lv == 2 ? .good.opacity(0.55) : .line
        return Button {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            CharNav.shared.open(ch)
        } label: {
            VStack(spacing: 1) {
                Text(ch).font(.hanzi(22, .bold)).foregroundStyle(lv == 0 ? Color.muted : Color.ink)
                Text(CharIndex.pinyin[ch] ?? cd.chars[ch]?.p ?? "").font(.nunito(10.5, .bold)).foregroundStyle(Color.muted).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 7)
            .overlay(alignment: .topTrailing) {
                if stats.due.contains(ch) { Circle().fill(Color.gold).frame(width: 7, height: 7).padding(5) }
            }
        }
        .buttonStyle(Tile3D(fill: lv == 0 ? Color.bg : Color.panel, edge: edge, radius: 12, lip: 3, line: lv >= 2 ? 2 : 1.5))
        .opacity(lv == 0 ? 0.7 : 1)
    }
}

/// Search across every character: what's typed, as characters, toneless pinyin or meaning (after a pause in the typing).
struct CharResults: View {
    let query: String
    let stats: CharStats
    @State private var hits: [String] = []
    private let cd = CharData.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if hits.isEmpty {
                Text("Nothing matches.").font(.nunito(15)).foregroundStyle(Color.muted).frame(maxWidth: .infinity).padding(.top, 30)
            } else {
                Text("\(hits.count) FOUND").font(.nunito(11.5, .black)).tracking(1.1).foregroundStyle(Color.muted).padding(.horizontal, 2)
                CharGrid(chars: hits, stats: stats)
            }
        }
        .task(id: query) {
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            let strip = { (s: String) in Pinyin.toneless(s.lowercased()).replacingOccurrences(of: "ü", with: "v") }
            let q = query.trimmingCharacters(in: .whitespaces).lowercased(), sq = strip(q)
            hits = Array(CharIndex.entries.lazy.filter { e in
                e.ch.contains(q) || strip(e.pinyin).contains(sq) || strip(cd.chars[e.ch]?.p ?? "").contains(sq) || cd.meaning(e.ch).lowercased().contains(q)
            }.map(\.ch).prefix(80))
        }
    }
}
