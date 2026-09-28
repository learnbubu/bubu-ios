import SwiftUI
import Observation

/// Home, as the web has it: greeting over the temple scenery, the streak card
/// with Bùbù peeking up, daily quests, Continue learning, and practice.
struct HomeView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(Router.self) private var router
    @State private var scroll = HomeScroll()
    private let course = Course.shared

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width, top = geo.safeAreaInsets.top
            ZStack(alignment: .top) {
                Color.bg.ignoresSafeArea()
                HomeScenery(scroll: scroll, W: W, top: top)
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        GeometryReader { g in
                            Color.clear.preference(key: ScrollYKey.self, value: g.frame(in: .named("home")).minY)
                        }
                        .frame(height: 0)
                        header
                        streakCard.padding(.top, 14)
                        questCard.padding(.top, 8)
                        if progress.boostActive { BoostPill().padding(.top, 14) }
                        continueSection
                        Text("Practice").font(.nunitoXB(17)).foregroundStyle(Color.ink)
                            .padding(.top, 20).padding(.bottom, 10).padding(.horizontal, 2)
                        hub
                        tiles.padding(.top, 10)
                        Button { router.push(.studyChoice) } label: {
                            HStack {
                                Text("What to study").font(.nunito(17)).foregroundStyle(Color.ink)
                                Spacer()
                                let nL = progress.selectedLessons.count, nF = progress.selectedFocuses.count
                                Text("\(nL == Course.shared.lessons.count ? "all lessons" : "\(nL) lesson\(nL == 1 ? "" : "s")"), \(nF) focus\(nF == 1 ? "" : "es")")
                                    .font(.nunito(13)).foregroundStyle(Color.muted)
                                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.muted)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 15).panel(radius: 16)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 10)
                        Color.clear.frame(height: 150)
                    }
                    .padding(.horizontal, 18)
                }
                .coordinateSpace(name: "home")
                // the scenery drifts as the page scrolls: the offset goes to a box that only the
                // scenery reads, so scrolling redraws the scenery each frame, not all of Home
                .onPreferenceChange(ScrollYKey.self) { y in
                    let up = min(0, y)
                    if scroll.up != up { scroll.up = up }
                }
                .onAppear { progress.ensureQuests() }
                .scrollIndicators(.hidden)
            }
        }
    }

    // MARK: greeting
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("步步").font(.hanzi(20, .heavy)).foregroundStyle(Color.ink)
                Text("Bùbù").font(.nunitoXB(19)).foregroundStyle(Color.accent)
            }
            .padding(.top, 6).padding(.bottom, 18)
            Text(greeting).font(.nunitoXB(28)).tracking(-0.3).foregroundStyle(Color.ink)
            Text("A little progress goes a long way.").font(.nunito(15, .semibold)).foregroundStyle(Color.muted)
                .padding(.top, 4)
        }
        .padding(.horizontal, 2)
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        let part = h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
        return progress.name.isEmpty ? "\(part)!" : "\(part), \(progress.name)!"
    }

    // MARK: streak
    private var streakCard: some View {
        let streak = progress.streak
        let out = progress.outSince
        let lit = progress.litOn(progress.today) && out == nil
        // from six in the evening an unlit day with a streak behind it is at risk
        let hoursLeft = 24 - Calendar.current.component(.hour, from: Date())
        let risk = out == nil && !lit && streak > 0 && hoursLeft <= 6
        let askable = out != nil && progress.embers > 0 && !progress.prefs.autoRelight
        let bubble = out != nil ? (askable ? "Relight it?" : "Went out")
            : risk ? "\(hoursLeft)h left to keep it" : lit ? "Done for today!"
            : streak > 0 ? "Keep it lit!" : "Let's start!"
        return VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                HStack(spacing: 13) {
                    FlameIcon(lit: lit, size: 42)
                        .shadow(color: lit ? Color(UIColor(hex: 0xF08A7A)).opacity(0.55) : .clear, radius: 10)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(out?.lost ?? streak)").font(.nunitoXB(34)).tracking(-0.6).foregroundStyle(out != nil ? Color.muted : Color.ink)
                        Text("day streak").font(.nunito(14, .bold)).foregroundStyle(Color.muted)
                        Label("\(progress.embers)", systemImage: "flame").font(.nunitoXB(11.5)).foregroundStyle(Color.gold)
                            .padding(.top, 2)
                    }
                    Spacer()
                }
                .frame(minHeight: 118)
                .padding(.top, 12).padding(.horizontal, 2)

                Image("home-peek").resizable().scaledToFit().frame(height: 92)
                    .offset(x: -64, y: 118 + 12 - 92 + 6)
                    .allowsHitTesting(false)
                Button {
                    if askable, let o = out { Moments.shared.show(.askRelight(lost: o.lost, embers: progress.embers)) }
                    else if risk, let id = progress.currentLessonId { router.start(StudySession.lesson(id, progress)) }
                } label: {
                    SpeechBubble(text: bubble, hot: askable || risk)
                        .phaseAnimator(risk ? [0.0, -3.0] : [0.0]) { v, y in v.offset(y: y) } animation: { _ in .easeInOut(duration: 1.1) }
                }
                .buttonStyle(.plain)
                .padding(.top, 13).padding(.trailing, 16)
            }
            .clipped()
            WeekStrip()
                .padding(.top, 10)
                .overlay(alignment: .top) { Rectangle().fill(Color.line).frame(height: 1) }
        }
        .padding(.horizontal, 14).padding(.bottom, 12)
        .panel().panelShadow()
    }

    // MARK: quests
    private var questCard: some View {
        let quests = progress.todayQuests
        let done = quests.filter { progress.questDone($0) || progress.progress(of: $0) >= $0.target }.count
        let opened = done == 3 && progress.chestOpened
        return VStack(spacing: 0) {
            HStack {
                Text("Daily quests").font(.nunitoXB(15)).foregroundStyle(Color.ink)
                Spacer()
                Text(done == 3 ? (opened ? "Pocket opened" : "3/3") : "\(done)/3").font(.nunitoXB(12.5)).foregroundStyle(done == 3 ? Color.gold : Color.muted)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(Color.accentSoft, in: Capsule())
            }
            .padding(.bottom, opened ? 8 : 2)
            if !opened { ForEach(Array(quests.enumerated()), id: \.offset) { i, q in
                let n = min(q.target, progress.progress(of: q)), ok = n >= q.target
                HStack(spacing: 10) {
                    Image(systemName: ok ? "checkmark" : q.icon).font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ok ? Color.good : Color.accent)
                        .frame(width: 30, height: 30)
                        .background(ok ? Color.goodSoft : Color.accentSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(q.title).font(.nunito(14, .bold)).foregroundStyle(Color.ink).lineLimit(1)
                        Bar(value: Double(n) / Double(q.target), fill: ok ? .good : .accent)
                    }
                    Text(ok ? "Done" : "\(n)/\(q.target)").font(.nunitoXB(13)).monospacedDigit()
                        .foregroundStyle(ok ? Color.good : Color.muted)
                        .frame(minWidth: 40, alignment: .trailing)
                }
                .padding(.vertical, 8)
                .overlay(alignment: .top) { if i > 0 { Rectangle().fill(Color.line).frame(height: 1) } }
            } }
        }
        .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 4)
        .panel()
    }

    // MARK: continue
    @ViewBuilder
    private var continueSection: some View {
        Button { router.tab = .learn } label: {
            HStack {
                Text("Continue learning").font(.nunitoXB(17)).foregroundStyle(Color.ink)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.muted)
            }
        }
        .buttonStyle(.plain)
        .padding(.top, 20).padding(.horizontal, 2)

        if progress.currentLessonId == nil {
            // every lesson done: the card starts a review instead
            Button { router.start(StudySession.review(progress)) } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text("COURSE COMPLETE").font(.nunito(12.5, .bold)).foregroundStyle(Color.muted)
                    Text("You've finished every lesson").font(.nunitoXB(20)).foregroundStyle(Color.ink)
                    Text("Keep your words sharp with a review.").font(.nunito(13.5, .semibold)).foregroundStyle(Color.muted)
                    Text("Review your words").font(.nunito(13, .bold)).foregroundStyle(Color.accent).padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(16)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "checkmark").font(.system(size: 19, weight: .bold)).foregroundStyle(Color.onAccent)
                        .frame(width: 46, height: 46).background(Color.accent, in: Circle()).padding(14)
                }
                .panel().panelShadow()
            }
            .buttonStyle(PressDown(depth: 2)).padding(.top, 10)
        }
        if let id = progress.currentLessonId, let lesson = course.lessonById[id], let ci = course.chapterOf[id] {
            let cards = course.cards(in: id)
            let learned = cards.filter { (progress.srs[$0.id]?.reps ?? 0) >= 1 }.count
            let parts = lesson.nameParts
            Button { router.tab = .learn; router.start(StudySession.lesson(lesson.id, progress)) } label: {
                VStack(alignment: .leading, spacing: 0) {
                    Text(course.chapterLabel(ci).uppercased()).font(.nunito(12.5, .bold)).foregroundStyle(Color.muted)
                    Text(parts.hanzi).font(.hanzi(21, .heavy)).foregroundStyle(Color.ink)
                        .shadow(color: Color.panel, radius: 6).padding(.top, 3).padding(.bottom, 1)
                    if !parts.en.isEmpty {
                        Text(parts.en).font(.nunito(13.5, .semibold)).foregroundStyle(Color.muted)
                    }
                    Bar(value: lesson.isPractice || cards.isEmpty ? 0 : Double(learned) / Double(cards.count), height: 8)
                        .padding(.top, 12).padding(.bottom, 7)
                    Text(lesson.isPractice ? "No new words · practise what you know" : "\(learned) / \(cards.count) words learned")
                        .font(.nunito(13, .bold)).foregroundStyle(Color.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 110)
                .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 14)
                .background(alignment: .trailing) {
                    GeometryReader { g in
                        Image("home-card").resizable().scaledToFill()
                            .frame(height: g.size.height * 1.53)
                            .frame(width: g.size.width * 0.67, height: g.size.height, alignment: .trailing)
                            .offset(x: 19)
                            .clipped()
                            .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.7)],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "chevron.right").font(.system(size: 19, weight: .bold)).foregroundStyle(Color.onAccent)
                        .frame(width: 46, height: 46)
                        .background(Color.accent, in: Circle())
                        .shadow(color: .black.opacity(0.35), radius: 8, y: 6)
                        .padding(14)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .panel().panelShadow()
            }
            .buttonStyle(PressDown(depth: 2))
            .padding(.top, 10)
        }
    }

    // MARK: practice
    private var hub: some View {
        let mistakes = progress.mistakeCount, due = progress.dueCount, weak = progress.weakCount
        return VStack(spacing: 0) {
            Button { router.start(StudySession.mistakes(progress)) } label: {
                hubRow("xmark", "Fix your mistakes",
                       mistakes > 0 ? "\(mistakes) word\(mistakes == 1 ? "" : "s") to get right again" : "Nothing to fix. Mistakes you make land here",
                       mistakes, ink: .again, soft: .againSoft)
            }
            Button { router.start(StudySession.review(progress)) } label: {
                hubRow("arrow.counterclockwise", "Review",
                       due > 0 ? "\(due) word\(due == 1 ? "" : "s") ready to review" : "All caught up",
                       due, ink: .accent, soft: .accentSoft, first: false)
            }
            Button { router.start(StudySession.trouble(progress)) } label: {
                hubRow("scope", "Weak words", weak > 0 ? "\(weak) word\(weak == 1 ? "" : "s") you often miss" : "No weak words yet",
                       weak, ink: .gold, soft: Color.gold.opacity(0.18), first: false)
            }
        }
        .buttonStyle(.plain)
        .panel(radius: 18).panelShadow()
    }

    private func hubRow(_ icon: String, _ title: String, _ sub: String, _ n: Int, ink: Color, soft: Color, first: Bool = true) -> some View {
        let empty = n == 0
        return HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                .foregroundStyle(empty ? Color.muted : ink)
                .frame(width: 36, height: 36)
                .background(empty ? Color.muted.opacity(0.12) : soft, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.nunitoXB(15)).foregroundStyle(empty ? Color.muted : Color.ink)
                Text(sub).font(.nunito(12, .semibold)).foregroundStyle(Color.muted).lineLimit(1)
            }
            Spacer(minLength: 0)
            if n > 0 {
                Text("\(n)").font(.nunito(13, .black)).foregroundStyle(.white)
                    .padding(.horizontal, 8).frame(minWidth: 26, minHeight: 26)
                    .background(ink, in: Capsule())
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .overlay(alignment: .top) { if !first { Rectangle().fill(Color.line).frame(height: 1) } }
    }

    private struct Tile: Identifiable { let id: String; let icon: String; let title: String; let sub: String; let color: String }

    private var tiles: some View {
        let fresh = course.data.readings.filter { progress.chapterDone($0.chapter) && !progress.readDone($0.id) }.count
        let known = Set(progress.srs.filter { ($0.value.reps ?? 0) > 0 }.keys.compactMap { course.cardById[$0] }
            .flatMap { $0.word.hanzi.filter(Course.isHan) }).count
        let list = [
            Tile(id: "listen", icon: "headphones", title: "Listening", sub: "Train your ear", color: "red"),
            Tile(id: "pick", icon: "square.stack.3d.up", title: "Vocabulary", sub: "Build your words", color: "blue"),
            Tile(id: "speak", icon: "mic", title: "Speaking", sub: "Practice out loud", color: "green"),
            Tile(id: "write", icon: "pencil", title: "Writing", sub: "Master the strokes", color: "yellow"),
            Tile(id: "quiz", icon: "checklist", title: "Quiz", sub: "Multiple choice", color: "purple"),
            Tile(id: "chars", icon: "字", title: "Characters", sub: "\(known) known", color: "teal"),
            Tile(id: "read", icon: "book", title: "Reading", sub: fresh > 0 ? "\(fresh) new \(fresh > 1 ? "stories" : "story")" : "Chapter stories", color: "orange"),
            Tile(id: "tones", icon: "music.note", title: "Tones", sub: "Hear the pairs", color: "pink"),
        ]
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(list) { t in
                let c = Color.tiles[t.color]!
                Button { router.practice(t.id, progress) } label: {
                    HStack(spacing: 10) {
                        Group {
                            if t.icon == "字" { Text("字").font(.hanzi(22, .bold)) }
                            else { Image(systemName: t.icon).font(.system(size: 22, weight: .medium)) }
                        }
                        .foregroundStyle(c.ink).frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.title).font(.nunitoXB(15)).foregroundStyle(Color.ink)
                            Text(t.sub).font(.nunito(11, .semibold)).foregroundStyle(Color.muted).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 12).padding(.trailing, 10).padding(.vertical, 12)
                    .frame(minHeight: 66)
                    .background(c.bg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(PressDown(depth: 2))
            }
        }
    }
}

/// How far Home has scrolled up from its top (0 or less, in points). A class, so writing it
/// redraws only the scenery that reads it, not all of Home.
@Observable
final class HomeScroll {
    var up: CGFloat = 0
}

/// The scenery behind Home, drifting slower than the page as on the web.
private struct HomeScenery: View {
    let scroll: HomeScroll
    let W: CGFloat
    let top: CGFloat
    var body: some View {
        let up = scroll.up
        ZStack(alignment: .topLeading) {
            Image("home-cloud-a").resizable().frame(width: W * 0.42, height: W * 0.42 * 0.3855)
                .offset(x: W * 0.133, y: top - 36 + up * 0.1)
            Image("home-temple").resizable().frame(width: W * 0.70, height: W * 0.70 * 0.5869)
                .opacity(0.95)
                .offset(x: W * 0.329, y: top - 24 + up * 0.28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .bottom) {
            Image("home-bottom").resizable().frame(width: W * 1.5, height: W * 1.5 * 338 / 1200)
                .offset(y: 14)
        }
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
    }
}

private struct ScrollYKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// The streak card's speech bubble, tail pointing down at Bùbù; orange when it wants you.
struct SpeechBubble: View {
    let text: String
    var hot = false
    var body: some View {
        let bg = hot ? Color(UIColor(hex: 0xF0742F)) : Color.accentSoft
        Text(text).font(.nunitoXB(13)).foregroundStyle(hot ? Color.white : Color.accent).lineLimit(1)
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background(bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                Triangle().fill(bg).frame(width: 12, height: 6).offset(x: 15, y: 5)
            }
    }
}

/// Double XP after a lesson, counting down (web: renderBoost).
struct BoostPill: View {
    @Environment(ProgressStore.self) private var progress
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let left = max(0, Int((progress.boostUntil - progress.now()) / 1000))
            (Text("2×").font(.nunito(14, .black)) + Text(" XP · \(left / 60):\(String(format: "%02d", left % 60))").font(.nunito(14, .bold)))
                .monospacedDigit().foregroundStyle(Color.gold)
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(Color.accentSoft, in: Capsule())
        }
    }
}

struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in p.move(to: .init(x: r.minX, y: r.minY)); p.addLine(to: .init(x: r.maxX, y: r.minY)); p.addLine(to: .init(x: r.midX, y: r.maxY)); p.closeSubpath() }
    }
}
