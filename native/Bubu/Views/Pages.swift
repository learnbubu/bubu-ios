import SwiftUI

/// The pages that slide in over a tab, as the web's full-screen sections.
enum Page: Hashable {
    case browse(String)          // a lesson's words
    case chars                   // every character in the course
    case readings                // the chapter stories
    case story(String)
    case guide(Int)              // a chapter's guidebook
    case tones                   // tone-pair trainer
    case converse                // dialogue roleplay
    case pick                    // choose words for flashcards, matching or a quiz
    case flash([String])
    case match([String])
    case avatar
    case studyChoice             // "What to study"
    case writingSheet(String)    // a word's 字帖
}

extension View {
    /// Where the pages go, with the app's look on the navigation bar.
    func pageDestinations() -> some View {
        navigationDestination(for: Page.self) { p in
            PageView(page: p)
                .toolbarBackground(Color.bg, for: .navigationBar)
                .background(Color.bg.ignoresSafeArea())
        }
    }
}

struct PageView: View {
    let page: Page
    var body: some View {
        switch page {
        case .browse(let id): BrowsePage(lessonId: id)
        case .chars: CharactersPage()
        case .readings: ReadingsPage()
        case .story(let id): StoryPage(storyId: id)
        case .guide(let ci): GuidePage(chapter: ci)
        case .tones: TonesPage()
        case .converse: ConversePage()
        case .pick: PickPage()
        case .studyChoice: StudyChoicePage()
        case .avatar: AvatarBuilderPage()
        case .writingSheet(let h): WritingSheetPage(hanzi: h)
        case .flash(let ids): FlashPage(ids: ids)
        case .match(let ids): MatchPage(ids: ids)
        default: ComingSoon(title: "Coming soon", icon: "hammer")
        }
    }
}

// MARK: - Browse: a lesson's words

struct BrowsePage: View {
    let lessonId: String
    @Environment(Router.self) private var router
    private let course = Course.shared
    var body: some View {
        let cards = course.cards(in: lessonId)
        List {
            Section {
                ForEach(cards, id: \.id) { c in
                    HStack(spacing: 12) {
                        TappableHanzi(text: c.word.hanzi, pinyin: c.word.pinyin, size: 22, weight: .bold)
                            .frame(minWidth: 56, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            PinyinText(pinyin: c.word.pinyin, size: 15, weight: .regular)
                            Text(c.word.pos.map { "\(c.word.en)  ·  \($0)" } ?? c.word.en)
                                .font(.nunito(14)).foregroundStyle(Color.ink)
                        }
                        Spacer(minLength: 0)
                        SpeakerButton(text: c.word.hanzi, size: 19)
                        if StrokeData.shared.writable(c.word.hanzi) {
                            Button { router.push(.writingSheet(c.word.hanzi)) } label: {
                                Image(systemName: "pencil.line").font(.system(size: 17)).foregroundStyle(Color.accent).padding(4)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 3)
                    .listRowBackground(Color.panel)
                }
            } header: {
                Text(course.lessonById[lessonId]?.title ?? "").font(.nunitoXB(13)).foregroundStyle(Color.accent).textCase(nil)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Browse · \(cards.count) words")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Characters: every character, shaded by how well you know it

extension Course {
    /// the words each character appears in
    static let cardsWithChar: [String: [Card]] = {
        var d: [String: [Card]] = [:]
        for c in Course.shared.cards { for ch in Set(c.word.hanzi.filter(Course.isHan).map(String.init)) { d[ch, default: []].append(c) } }
        return d
    }()
    /// every character in course order, with the lesson it first appears in
    static let allChars: [(ch: String, lesson: String)] = {
        var seen = Set<String>(), out: [(String, String)] = []
        for c in Course.shared.cards {
            for ch in c.word.hanzi.filter(Course.isHan).map(String.init) where seen.insert(ch).inserted {
                out.append((ch, Course.shared.lessonById[c.lessonId]?.title ?? ""))
            }
        }
        return out
    }()
}

extension ProgressStore {
    /// 0 not met, 1 learning, 2 getting there, 3 strong: the best of its words (web: charLevel).
    func charLevel(_ ch: String) -> Int {
        var lv = 0
        for c in Course.cardsWithChar[ch] ?? [] {
            guard let s = srs[c.id], (s.reps ?? 0) >= 1 else { continue }
            lv = max(lv, (s.interval ?? 0) >= 7 ? 3 : (s.interval ?? 0) >= 3 ? 2 : 1)
        }
        return lv
    }
    func charDue(_ ch: String) -> Bool {
        let t = now()
        return (Course.cardsWithChar[ch] ?? []).contains { (srs[$0.id]?.due).map { $0 <= t } ?? false }
    }
    var charsKnown: Int { Course.allChars.filter { charLevel($0.ch) >= 1 }.count }
}

struct CharactersPage: View {
    @Environment(ProgressStore.self) private var progress
    @State private var query = ""
    @State private var filter = "all"
    private let cd = CharData.shared

    var body: some View {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let strip = { (s: String) in Pinyin.toneless(s.lowercased()).replacingOccurrences(of: "ü", with: "v") }
        let rows = Course.allChars.compactMap { item -> (String, String, Int, Bool)? in
            let lv = progress.charLevel(item.ch), due = lv > 0 && progress.charDue(item.ch)
            if filter == "due" && !due { return nil }
            if filter == "weak" && lv != 1 { return nil }
            if filter == "new" && lv != 0 { return nil }
            if !q.isEmpty {
                let py = cd.chars[item.ch]?.p ?? "", en = cd.meaning(item.ch).lowercased()
                guard item.ch.contains(q) || strip(py).contains(strip(q)) || en.contains(q) else { return nil }
            }
            return (item.ch, item.lesson, lv, due)
        }
        let groups = Dictionary(grouping: rows, by: \.1)
        let order = rows.map(\.1).reduce(into: [String]()) { if $0.last != $1 { $0.append($1) } }
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    ForEach([("all", "All"), ("due", "Due"), ("weak", "Learning"), ("new", "Not met")], id: \.0) { f in
                        Button { filter = f.0 } label: {
                            Text(f.1).font(.nunitoXB(12.5)).foregroundStyle(filter == f.0 ? Color.onAccent : Color.muted)
                                .padding(.horizontal, 12).padding(.vertical, 5)
                                .background(filter == f.0 ? Color.accent : Color.panel, in: Capsule())
                                .overlay(Capsule().strokeBorder(filter == f.0 ? Color.accent : Color.line))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
                ForEach(order, id: \.self) { lesson in
                    Text(lesson.uppercased()).font(.nunito(11.2, .black)).tracking(1.1).foregroundStyle(Color.accent)
                        .lineLimit(1).padding(.top, 16).padding(.bottom, 7).padding(.horizontal, 2)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 54), spacing: 7)], spacing: 7) {
                        ForEach(groups[lesson] ?? [], id: \.0) { r in cell(r.0, lv: r.2, due: r.3) }
                    }
                }
                if rows.isEmpty {
                    Text("Nothing matches.").font(.nunito(15)).foregroundStyle(Color.muted).frame(maxWidth: .infinity).padding(.top, 40)
                }
                Text("Darker is stronger; a gold dot means due for review. Character breakdowns from Make Me a Hanzi (LGPL).")
                    .font(.nunito(12)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity).padding(.vertical, 24)
            }
            .padding(.horizontal, 18)
        }
        .searchable(text: $query, prompt: "Search 字, pinyin or meaning…")
        .navigationTitle("Characters")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Text("\(progress.charsKnown) / \(Course.allChars.count)").font(.nunito(13, .semibold)).foregroundStyle(Color.muted)
            }
        }
    }

    private func cell(_ ch: String, lv: Int, due: Bool) -> some View {
        let bg: Color = lv == 3 ? .good : lv == 2 ? .good.opacity(0.42) : lv == 1 ? .goodSoft : .panel
        let fg: Color = lv == 3 ? .onAccent : lv == 0 ? .muted : .ink
        return Button { CharNav.shared.open(ch) } label: {
            Text(ch).font(.hanzi(23, .bold)).foregroundStyle(fg)
                .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                .background(bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(lv >= 2 ? .clear : Color.line))
                .overlay(alignment: .topTrailing) {
                    if due { Circle().fill(Color.gold).frame(width: 7, height: 7).padding(5) }
                }
        }
        .buttonStyle(.plain)
    }
}
