import SwiftUI

/// "What to study": which skills a session mixes, and which lessons the Classroom's practice draws on
/// (web: #studyPanel, renderFocuses). In the Home and Classroom look (the owner, 14 Oct 2026): four
/// ways to practise, the seven skills folded away under them, and the lessons by chapter (one card each,
/// opened for its units) instead of every stone in one long list. Light only for now.
struct StudyChoicePage: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.dismiss) private var dismiss
    @State private var skillsOpen = false
    @State private var open: Set<Int> = []
    private let course = Course.shared

    static let focuses: [(key: String, icon: String, name: String, desc: String)] = [
        ("recognize", "eye", "Read characters", "See 汉字, recall the meaning"),
        ("recall", "character.cursor.ibeam", "Recall from English", "English → produce the 汉字"),
        ("pinyin", "character.textbox", "Pinyin", "Pick the correct pinyin — tones matter"),
        ("listen", "headphones", "Listen", "Hear it, then pick what it means"),
        ("write", "pencil", "Write it", "Draw the character stroke by stroke"),
        ("sentence", "square.stack.3d.up", "Build sentences", "Tap word tiles to assemble a sentence"),
        ("speak", "mic", "Speak it", "Say the word aloud and get it checked"),
    ]
    static let presets: [(name: String, icon: String, keys: [String])] = [
        ("Everything", "sparkles", ["recognize", "recall", "pinyin", "listen", "write", "sentence", "speak"]),
        ("Reading", "eye", ["recognize", "recall", "pinyin"]),
        ("Writing", "pencil", ["write", "recognize"]),
        ("Speaking", "mic", ["speak", "pinyin", "listen"]),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Button { dismiss() } label: {
                    Text("‹ Classroom").font(.nunito(14, .black)).foregroundStyle(Home.teal).padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                Text("What to study").font(.nunito(32, .black)).tracking(-0.5).foregroundStyle(Home.ink)
                    .padding(.top, -4)
                heading("Practise")
                practise
                HStack(alignment: .firstTextBaseline) {
                    heading("Lessons")
                    Spacer()
                    Text(lessonSummary).font(.nunito(13, .bold)).foregroundStyle(Home.muted)
                }
                .padding(.top, 6)
                quickPicks
                VStack(spacing: 10) {
                    ForEach(Array(course.chapters.enumerated()), id: \.offset) { ci, ch in chapterCard(ci, ch) }
                }
            }
            .padding(.horizontal, 18).padding(.top, 4).padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background(Home.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .environment(\.colorScheme, .light)
    }

    private func heading(_ t: String) -> some View {
        Text(t.uppercased()).font(.nunito(12, .black)).tracking(1.3).foregroundStyle(Home.teal)
    }

    private func card<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        c()
            .background(Color(UIColor(hex: 0xFFFDF8)), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Home.line, lineWidth: 1.5))
    }

    // MARK: what to practise: four ways, the skills folded away under them
    private var practise: some View {
        let on = progress.selectedFocuses
        return card {
            VStack(spacing: 0) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(Self.presets, id: \.name) { p in
                        let active = Set(p.keys) == on
                        Button { setFocuses(Set(p.keys)) } label: {
                            HStack(spacing: 8) {
                                Image(systemName: p.icon).font(.system(size: 15, weight: .bold))
                                Text(p.name).font(.nunito(15, .black))
                                Spacer(minLength: 0)
                                if active { Image(systemName: "checkmark").font(.system(size: 13, weight: .heavy)) }
                            }
                            .foregroundStyle(active ? .white : Home.ink)
                            .padding(.horizontal, 12).frame(height: 44)
                            .background(active ? Home.teal : Home.bg, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(active ? Color.clear : Home.line, lineWidth: 1.5))
                        }
                        .buttonStyle(PressDown(depth: 1))
                    }
                }
                .padding(12)
                Rectangle().fill(Home.line).frame(height: 1)
                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { skillsOpen.toggle() } } label: {
                    HStack {
                        Text("Choose skills").font(.nunito(14.5, .heavy)).foregroundStyle(Home.ink)
                        Spacer()
                        Text("\(on.count) of \(Self.focuses.count) on").font(.nunito(13, .bold)).foregroundStyle(Home.muted)
                        Image(systemName: "chevron.down").font(.system(size: 11, weight: .heavy)).foregroundStyle(Home.muted)
                            .rotationEffect(.degrees(skillsOpen ? 180 : 0))
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if skillsOpen {
                    VStack(spacing: 0) {
                        ForEach(Self.focuses, id: \.key) { f in skillRow(f, on: on) }
                    }
                    .padding(.horizontal, 14).padding(.bottom, 6)
                    .transition(.opacity)
                }
            }
        }
    }

    private func skillRow(_ f: (key: String, icon: String, name: String, desc: String), on: Set<String>) -> some View {
        Toggle(isOn: Binding(get: { on.contains(f.key) }, set: { v in
            var s = on
            if v { s.insert(f.key) } else {
                guard s.count > 1 else { Moments.shared.toast("Keep at least one skill switched on."); return }
                s.remove(f.key)
            }
            setFocuses(s)
        })) {
            HStack(spacing: 11) {
                Image(systemName: f.icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(Home.teal).frame(width: 22)
                VStack(alignment: .leading, spacing: 0) {
                    Text(f.name).font(.nunito(14.5, .heavy)).foregroundStyle(Home.ink)
                    Text(f.desc).font(.nunito(12, .semibold)).foregroundStyle(Home.muted).lineLimit(1).minimumScaleFactor(0.85)
                }
            }
        }
        .tint(Home.teal)
        .padding(.vertical, 7)
    }

    // MARK: lessons: quick choices, then a card for each chapter
    private var lessonSummary: String {
        let all = course.lessons.count, n = progress.selectedLessons.count
        return n == all ? "All lessons" : "\(chapterCount) chapter\(chapterCount == 1 ? "" : "s") chosen"
    }

    private var chapterCount: Int {
        let s = progress.selectedLessons
        return course.chapters.filter { $0.lessons.contains(where: s.contains) }.count
    }

    /// The chapter you're on (the last one, once the course is done).
    private var currentChapter: Int {
        progress.currentLessonId.flatMap { course.chapterOf[$0] } ?? course.chapters.count - 1
    }

    private var quickPicks: some View {
        let s = progress.selectedLessons, cur = currentChapter
        let soFar = Set(course.chapters.prefix(cur + 1).flatMap(\.lessons))
        let here = Set(course.chapters[cur].lessons)
        let picks: [(String, Set<String>)] = [("All lessons", Set(course.lessons.map(\.id))), ("Up to now", soFar), ("This chapter", here)]
        return HStack(spacing: 8) {
            ForEach(picks, id: \.0) { name, ids in
                let active = s == ids
                Button { set(ids) } label: {
                    Text(name).font(.nunito(13.5, .heavy)).lineLimit(1).minimumScaleFactor(0.85)
                        .foregroundStyle(active ? .white : Home.ink)
                        .frame(maxWidth: .infinity).frame(height: 36)
                        .background(active ? Home.teal : Color(UIColor(hex: 0xFFFDF8)), in: Capsule())
                        .overlay(Capsule().stroke(active ? Color.clear : Home.line, lineWidth: 1.5))
                }
                .buttonStyle(PressDown(depth: 1))
            }
        }
    }

    private func chapterCard(_ ci: Int, _ ch: Chapter) -> some View {
        let s = progress.selectedLessons
        let ids = ch.lessons, on = ids.filter(s.contains).count
        let cards = ids.flatMap { course.cards(in: $0) }
        let due = cards.filter { (progress.srs[$0.id]?.due).map { $0 <= progress.now() } ?? false }.count
        // words learned (met at least once): "mastered" (a week's interval, and produced) left every bar empty
        let mastered = cards.filter { (progress.srs[$0.id]?.reps ?? 0) >= 1 }.count
        // how far through the chapter: its words learned, or its lessons done when that's further
        // (a chapter skipped past by a placement has its lessons done but no words met yet)
        let share = max(cards.isEmpty ? 0 : Double(mastered) / Double(cards.count),
                        Double(ids.filter(progress.isDone).count) / Double(max(1, ids.count)))
        let ahead = ci > currentChapter
        let isOpen = open.contains(ci)
        let label = course.chapterLabel(ci)
        return card {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button { set(on == ids.count ? s.subtracting(ids) : s.union(ids)) } label: {
                        Image(systemName: on == ids.count ? "checkmark.circle.fill" : on > 0 ? "minus.circle.fill" : "circle")
                            .font(.system(size: 24)).foregroundStyle(on > 0 ? Home.teal : Home.line)
                    }
                    .buttonStyle(.plain)
                    Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { if isOpen { open.remove(ci) } else { open.insert(ci) } } } label: {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(label.uppercased()).font(.nunito(11, .black)).tracking(1).foregroundStyle(Home.muted)
                                Text(ch.title).font(.nunito(16, .black)).foregroundStyle(Home.ink).lineLimit(1).minimumScaleFactor(0.8)
                                GeometryReader { g in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color(UIColor(hex: 0xE7E2D8)))
                                        Capsule().fill(Color.good).frame(width: g.size.width * share)
                                    }
                                }
                                .frame(height: 5).padding(.top, 3)
                            }
                            VStack(alignment: .trailing, spacing: 2) {
                                // the tick says it's chosen; a count only when part of it is (an "n/n" beside
                                // the bar read as progress: the Mac's check of 0.1.81)
                                if on > 0 && on < ids.count {
                                    Text("\(on) of \(ids.count)").font(.nunito(13, .black)).monospacedDigit().foregroundStyle(Home.muted)
                                }
                                if due > 0 { Text("\(due) due").font(.nunito(12, .heavy)).foregroundStyle(Color(UIColor(hex: 0xB7822E))) }
                                else if ahead { Text("Ahead").font(.nunito(12, .heavy)).foregroundStyle(Home.muted.opacity(0.7)) }
                            }
                            Image(systemName: "chevron.down").font(.system(size: 12, weight: .heavy)).foregroundStyle(Home.muted)
                                .rotationEffect(.degrees(isOpen ? 180 : 0))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                if isOpen {
                    VStack(spacing: 0) {
                        ForEach(units(ch), id: \.name) { u in unitRow(u.name, u.title, u.ids) }
                    }
                    .padding(.horizontal, 14).padding(.bottom, 8)
                    .transition(.opacity)
                }
            }
        }
        .opacity(ahead && on == 0 ? 0.75 : 1)
    }

    /// A chapter's lessons as units, one row each: the stones that share a name ("U4.4" twice) are one.
    private func units(_ ch: Chapter) -> [(name: String, title: String, ids: [String])] {
        var out: [(name: String, title: String, ids: [String])] = []
        for id in ch.lessons {
            guard let l = course.lessonById[id] else { continue }
            let head = l.title.components(separatedBy: " · ").first ?? l.title
            let name = l.isPractice ? "Practice" : (head.split(separator: " ").last.map(String.init) ?? head)
            let title = l.isPractice ? "Review stone" : l.nameParts.hanzi
            if let i = out.firstIndex(where: { $0.name == name && $0.title == title }) { out[i].ids.append(id) }
            else { out.append((name, title, [id])) }
        }
        return out
    }

    private func unitRow(_ name: String, _ title: String, _ ids: [String]) -> some View {
        let s = progress.selectedLessons, on = ids.allSatisfy(s.contains)
        return Button { set(on ? s.subtracting(ids) : s.union(ids)) } label: {
            HStack(spacing: 10) {
                Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.system(size: 19)).foregroundStyle(on ? Home.teal : Home.line)
                Text(name).font(.nunito(12, .black)).foregroundStyle(Home.teal)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Home.tealSoft, in: Capsule())
                Text(title).font(.hanzi(15, .semibold)).foregroundStyle(Home.ink).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .overlay(alignment: .top) { Rectangle().fill(Home.line).frame(height: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func setFocuses(_ s: Set<String>) {
        progress.prefs.focuses = StudySession.allDirs.filter(s.contains)
    }

    /// Choose these lessons (in the course's order); at least one stays chosen.
    private func set(_ s: Set<String>) {
        guard !s.isEmpty else { Moments.shared.toast("Keep at least one lesson chosen."); return }
        progress.prefs.lessons = course.lessons.map(\.id).filter(s.contains)
    }
}
