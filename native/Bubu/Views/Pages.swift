import SwiftUI

/// The pages that slide in over a tab, as the web's full-screen sections.
enum Page: Hashable {
    case browse(String)          // a lesson's words
    case chars                   // every character in the course: today's, and your books
    case charBook(String)        // a book's characters, by chapter (its name: "起步 1")
    case readings                // the chapter stories
    case story(String)
    case guide(Int)              // a chapter's guidebook
    case tones                   // tone-pair trainer
    case converse                // dialogue roleplay
    case chat(String)            // a chat with 步步 (Speaking), a dialogue's id
    case vocab                   // the Classroom's Vocabulary: today's words, your garden, a search
    case pick                    // choose words for flashcards, matching or a quiz
    case flash([String])
    case match([String])
    case avatar
    case writingSheet(String)    // a word's 字帖
    case classroom               // the practice tiles, behind Home's board
    case quests                  // today's three, behind Home's Daily quests
    case activity                // your learning activity, from Profile
    case achievements            // every achievement, from Profile
}

extension EnvironmentValues {
    /// Back a page in the Classroom's slide-over (Router.cover): its last page, or the slide-over itself. Nil elsewhere.
    @Entry var coverBack: (() -> Void)? = nil
}

/// The Classroom's slide-over: one of its rooms (Characters, Tones, Vocabulary…) over everything, the tab bar too,
/// slid in from the side and out again, with its own pages. (Pushed on Home's stack they kept the tab bar, or hid it
/// and iOS brought it back only after the way back had finished; the owner, 26 Oct 2026, "all the classroom … from
/// the side … none have the UI at the bottom".) A swipe from the left edge goes back, as a pushed page's.
struct CoverHost: View {
    let root: Page
    @Environment(Router.self) private var router
    @State private var drag: CGFloat = 0

    var body: some View {
        @Bindable var r = router
        GeometryReader { g in
            NavigationStack(path: $r.coverPath) {
                PageView(page: root).toolbar(.hidden, for: .navigationBar).pageDestinations()
                    .background(Color.bg.ignoresSafeArea())
            }
            .environment(\.coverBack, { router.coverBack() })
            // (a room that fits doesn't scroll at all: the owner, 26 Oct 2026, "non scrollable the page unless necessary")
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .offset(x: drag)
            .overlay(alignment: .leading) {
                // the edge swipe back, on the room itself (its own pages have the stack's)
                if router.coverPath.isEmpty {
                    Color.clear.frame(width: 22).contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 8, coordinateSpace: .global)
                            .onChanged { drag = max(0, $0.translation.width) }
                            .onEnded { v in
                                if v.translation.width > g.size.width * 0.33 || v.predictedEndTranslation.width > g.size.width * 0.6 {
                                    router.coverBack()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { drag = 0 }
                                } else {
                                    withAnimation(Router.slide) { drag = 0 }
                                }
                            })
                }
            }
        }
        .shadow(color: .black.opacity(0.12), radius: 12, x: -4)
    }
}

extension View {
    /// Where the pages go, with the app's look on the navigation bar.
    func pageDestinations() -> some View {
        navigationDestination(for: Page.self) { p in
            PageView(page: p)
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
        case .charBook(let b): CharBookPage(book: b)
        case .readings: ReadingsPage()
        case .story(let id): StoryPage(storyId: id)
        case .guide(let ci): GuidePage(chapter: ci)
        case .tones: TonesPage()
        case .converse: ConversePage()
        case .chat(let id): ChatPage(dialogueId: id)
        case .vocab: VocabRoom()
        case .pick: PickPage()
        case .avatar: AvatarBuilderPage()
        case .writingSheet(let h): WritingSheetPage(hanzi: h)
        case .flash(let ids): FlashPage(ids: ids)
        case .match(let ids): MatchPage(ids: ids)
        case .classroom: ClassroomPage()
        case .quests: QuestsPage()
        case .activity: ActivityPage()
        case .achievements: AchievementsPage()
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
        .pageBar("Browse") { BarCount(text: "\(cards.count) words") }
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

// (the Characters pages: CharactersPage.swift)
