import SwiftUI
import Observation

/// Home as the studio has it (the owner's Home tab, 13 Oct 2026): the lantern, coins and buns along the top,
/// Up next over the hills, Daily quests with the pouch, the Classroom board (Bùbù teaching, placed in the
/// Layer editor) whose button opens the Classroom, and the word of the day. Light only for now.
struct HomeView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(Router.self) private var router
    private let course = Course.shared

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width, H = geo.size.height
            // everything on one screen, no scrolling (the owner, 14 Oct 2026): the board takes what's left
            // (the board gives way, not the words: 470 the rest's room, with the button and the word of the day at
            // their own heights; the Mac, the word's characters shrank to 19 pt at 455)
            let rest = H - 470
            let boardW = min(W - 28, max(180, rest * HomeArt.frame.width / HomeArt.frame.height))
            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 8).frame(maxHeight: 13)
                upNext
                Spacer(minLength: 8).frame(maxHeight: 12)
                questCard
                Spacer(minLength: 8).frame(maxHeight: 15)
                ClassroomBoard(width: boardW) { router.push(.classroom) }
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 6).frame(maxHeight: 21)
                wordOfTheDay
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18).padding(.top, 6)
            .frame(width: W, height: H, alignment: .top)
            .background(Home.bg.ignoresSafeArea())
            .onAppear { progress.ensureQuests() }
        }
        .environment(\.colorScheme, .light)
    }

    // MARK: the top bar: the wordmark, then the lantern (the streak), coins and buns
    private var topBar: some View {
        let out = progress.outSince
        let lit = progress.litOn(progress.today) && out == nil
        let askable = out != nil && progress.embers > 0 && !progress.prefs.autoRelight
        return HStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("步步").font(.hanzi(23, .black)).foregroundStyle(Home.ink)
                Text("Bùbù").font(.nunito(22, .black)).foregroundStyle(Home.teal)
            }
            Spacer(minLength: 4)
            Button {
                if askable, let o = out { Moments.shared.show(.askRelight(lost: o.lost, embers: progress.embers)) }
                else { router.tab = .profile }
            } label: {
                chip(lit ? "chip-lantern-lit" : "chip-lantern-unlit", "\(out?.lost ?? progress.streak)",
                     ink: lit ? 0xD9392F : 0xB9B0A1, bg: lit ? 0xFCE9E3 : 0xF3ECDF, edge: lit ? 0xF5D3C8 : 0xEADFCB)
            }
            .buttonStyle(.plain)
            chip("coin", "\(progress.coins)", ink: 0xA86D16)
            chip("bun", progress.isPlus ? "∞" : "\(progress.buns)", ink: 0x9A6B3A)
        }
    }

    private func chip(_ image: String, _ text: String, ink: UInt32, bg: UInt32 = 0xF3ECDF, edge: UInt32 = 0xEADFCB) -> some View {
        HStack(spacing: 4) {
            Image(image).resizable().scaledToFit().frame(height: 24)
            Text(text).font(.nunito(16, .black)).monospacedDigit().foregroundStyle(Color(UIColor(hex: ink)))
        }
        .padding(.leading, 6).padding(.trailing, 10).frame(height: 36)
        .background(Color(UIColor(hex: bg)), in: Capsule())
        .overlay(Capsule().stroke(Color(UIColor(hex: edge)), lineWidth: 1))
    }

    // MARK: Up next: the lesson you're on, over the hills
    @ViewBuilder
    private var upNext: some View {
        let id = progress.currentLessonId
        let lesson = id.flatMap { course.lessonById[$0] }
        let ci = id.flatMap { course.chapterOf[$0] }
        let cards = id.map { course.cards(in: $0) } ?? []
        let learned = cards.filter { (progress.srs[$0.id]?.reps ?? 0) >= 1 }.count
        let started = learned > 0
        let chapter = ci.map { course.chapterLabel($0).components(separatedBy: " · ").last ?? "" } ?? ""
        let kicker = lesson == nil ? "Course complete" : "Up next · \(chapter)"
        let progressShare: Double = cards.isEmpty ? 0 : Double(learned) / Double(cards.count)
        let action = lesson == nil ? "Review your words" : started ? "Continue lesson" : "Start lesson"
        VStack(alignment: .leading, spacing: 0) {
                Text(kicker)
                    .font(.nunito(12, .black)).tracking(1.4).textCase(.uppercase).foregroundStyle(Home.teal)
                Text(lesson?.nameParts.hanzi ?? "复习").font(.hanzi(27, .black)).foregroundStyle(Home.ink).padding(.top, 4)
                Text(lesson.map { $0.nameParts.en } ?? "Keep your words sharp with a review").font(.nunito(15.5, .bold)).foregroundStyle(Home.muted)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(UIColor(hex: 0xD3DED8)))
                        Capsule().fill(Home.teal).frame(width: g.size.width * progressShare)
                    }
                }
                .frame(height: 10).padding(.top, 13)
                // the card's one button: it presses down onto its lip, as the app's others (the whole card did).
                // A lesson: to the path, at its stone, to start it there (not straight into it); all done: a review
                Button {
                    if lesson != nil { router.toPath() } else { router.start(StudySession.review(progress)) }
                } label: {
                    Text(action)
                }
                // (the app's raised button, as every other: it was its own, in another case with an arrow; the Mac's audit)
                .buttonStyle(RaisedButton(fill: Home.teal, ink: .white, edge: nil))
                // (its own height kept: Home fits one screen and squeezed it, and its label shrank to 13 pt; the Mac)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 15)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 17).padding(.top, 15).padding(.bottom, 17)
            .background(alignment: .topTrailing) {
                // the hills, as placed in the studio: to the right, faded out towards the bottom
                GeometryReader { g in
                    Image("home-hills").resizable().scaledToFit()
                        .frame(width: g.size.width * 0.59)
                        .scaleEffect(x: 1, y: 0.9, anchor: .bottom)
                        .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.55), .init(color: .clear, location: 1)],
                                             startPoint: .top, endPoint: .bottom))
                        .opacity(0.6)
                        .offset(x: 2, y: -3)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .allowsHitTesting(false)
            }
            .background(LinearGradient(colors: [Color(UIColor(hex: 0xEEF7F2)), Color(UIColor(hex: 0xE2EFE8))], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color(UIColor(hex: 0xD7E8DF)), lineWidth: 1))
            // double XP after a lesson: a badge in the card's corner (it pushed the page down as a row), gone at 0:00
            .overlay(alignment: .topTrailing) { BoostBadge().padding(12) }
            .shadow(color: Color(UIColor(hex: 0x1E463C)).opacity(0.08), radius: 8, y: 6)
    }

    // MARK: Daily quests: the pouch, how many are done, the next one; tap for all three, on a page of their own
    private var questCard: some View {
        let quests = progress.todayQuests
        let n = { (q: Quest) in min(q.target, progress.questDone(q) ? q.target : progress.progress(of: q)) }
        let done = quests.filter { n($0) >= $0.target }.count
        let next = quests.first { n($0) < $0.target }
        return Button { router.push(.quests) } label: {
            HStack(spacing: 13) {
                Image("quest-pouch").resizable().scaledToFit().frame(height: 50)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Daily quests").font(.nunito(17, .black)).foregroundStyle(Home.ink)
                        Spacer()
                        Text("\(done)/3").font(.nunito(15, .black)).foregroundStyle(Home.muted)
                    }
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(UIColor(hex: 0xE7E2D8)))
                            Capsule().fill(Color(UIColor(hex: 0xF2B33D))).frame(width: g.size.width * Double(done) / 3)
                        }
                    }
                    .frame(height: 10)
                    Text(next.map { "Next: \($0.title) · \(n($0)) / \($0.target)" } ?? (progress.chestOpened ? "All done · pocket opened" : "All done · open your pocket!"))
                        .font(.nunito(13, .bold)).foregroundStyle(Home.muted).lineLimit(1)
                }
                Image(systemName: "chevron.right").font(.system(size: 15, weight: .heavy)).foregroundStyle(Home.muted)
            }
            .padding(.leading, 12).padding(.trailing, 14).padding(.vertical, 12)
            .background(Color(UIColor(hex: 0xFFFDF8)), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Home.line, lineWidth: 1))
        }
        .buttonStyle(CardPress())
    }

    // MARK: word of the day: one of your words, a new one each day
    private var wordOfTheDay: some View {
        let w = dailyWord
        return HStack(spacing: 13) {
            // (36: chosen, not left to the squeeze: it showed at 19 pt squeezed, then 42 at its full 44 beside a small label)
            Text(w.hanzi).font(.hanzi(36, .black)).foregroundStyle(Home.ink).lineLimit(1).minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, 13)
                .overlay(alignment: .trailing) { Rectangle().fill(Home.line).frame(width: 1) }
            VStack(alignment: .leading, spacing: 1) {
                Text("WORD OF THE DAY").font(.nunito(11, .black)).tracking(1.2).foregroundStyle(Color(UIColor(hex: 0xA86D16)))
                Text(w.pinyin).font(.nunito(18, .black)).foregroundStyle(Home.teal)
                Text(w.gloss).font(.nunito(15, .bold)).foregroundStyle(Home.muted).lineLimit(1)
            }
            Spacer(minLength: 4)
            Button { Speech.shared.speak(w.hanzi) } label: {
                Image(systemName: "speaker.wave.2.fill").font(.system(size: 19, weight: .semibold)).foregroundStyle(Home.teal)
                    .frame(width: 48, height: 48).background(Home.tealSoft, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hear it")
        }
        .padding(.vertical, 12).padding(.horizontal, 2)
        .overlay(alignment: .top) { Rectangle().fill(Home.line).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Home.line).frame(height: 1) }
    }

    /// One of the words you've learned (else from the lesson you're on), the same all day; 加油 to begin with.
    private var dailyWord: Word {
        let learned = course.cards.filter { (progress.srs[$0.id]?.reps ?? 0) >= 1 }.map(\.word)
        let pool = learned.isEmpty ? (progress.currentLessonId.map { course.cards(in: $0).map(\.word) } ?? []) : learned
        guard !pool.isEmpty, learned.count >= 3 else { return Word(hanzi: "加油", pinyin: "jiāyóu", pos: nil, en: "Keep going!") }
        let day = Int(Date().timeIntervalSince1970 / 86400)
        return pool[(day * 7919) % pool.count]
    }
}

/// Home's and the Classroom's colours (the studio's; light only for now).
enum Home {
    static let bg = Color(UIColor(hex: 0xF8F4EC))
    static let ink = Color(UIColor(hex: 0x1B2A33))
    static let muted = Color(UIColor(hex: 0x5F6E7E))
    static let line = Color(UIColor(hex: 0xE7E1D5))
    static let teal = Color(UIColor(hex: 0x1F7A6C))
    static let tealDark = Color(UIColor(hex: 0x14594F))
    static let tealSoft = Color(UIColor(hex: 0xE3F1EB))
}

/// The Classroom board: Bùbù teaching at the chalkboard, as set up in the studio's Layer editor (HomeArt):
/// his head and pointer swing, he blinks, the chalk mark twinkles, and the button opens the Classroom.
struct ClassroomBoard: View {
    let width: CGFloat
    let open: () -> Void
    @Environment(\.accessibilityReduceMotion) private var still

    var body: some View {
        let k = width / HomeArt.frame.width, h = HomeArt.frame.height * k
        TimelineView(.animation(paused: still)) { tl in
            let t = still ? 0 : tl.date.timeIntervalSinceReferenceDate
            ZStack(alignment: .topLeading) {
                ForEach(Array(HomeArt.pieces.enumerated()), id: \.offset) { _, p in
                    if Self.shows(p, t) {
                        Image(p.image).resizable().interpolation(.high)
                            .frame(width: width, height: h)
                            .rotationEffect(.degrees(p.swing * sin(2 * .pi * (t / p.period + p.phase))),
                                            anchor: UnitPoint(x: p.pivot.x / HomeArt.frame.width, y: p.pivot.y / HomeArt.frame.height))
                            .offset(y: -abs(p.bob * sin(.pi * (t / p.period + p.phase))) * k)
                    }
                }
                ForEach(Array(HomeArt.marks.enumerated()), id: \.offset) { _, m in
                    let tw = 0.5 - 0.5 * cos(2 * .pi * t / 2.2)
                    Image(m.image).resizable().scaledToFit()
                        .frame(width: width * m.w / 100)
                        .scaleEffect(0.9 + 0.18 * tw)
                        .rotationEffect(.degrees(m.r))
                        .opacity(0.55 + 0.45 * tw)
                        .offset(x: width * m.x / 100, y: h * m.y / 100)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: width, height: h, alignment: .topLeading)
        }
        .overlay(alignment: .topLeading) {
            let b = HomeArt.button
            let h = b.height * k
            Button(action: open) {
                Text("Let's practise").font(.nunito(h * 74 / 83 * 36 / 74, .black)).foregroundStyle(Home.teal)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .buttonStyle(LipButton(face: Color(UIColor(hex: 0xFFF7E6)), lip: Color(UIColor(hex: 0xE2D3B4)), radius: h * 22 / 83, depth: h * 9 / 83))
                .frame(width: b.width * k, height: b.height * k)
                .offset(x: b.minX * k, y: b.minY * k)
        }
        .frame(width: width, height: h)
        .accessibilityElement(children: .contain)
    }

    /// A piece that blinks: a positive blink hides it for the blink, a negative one shows it only then (the studio's edBlinkOn).
    static func shows(_ p: HomeArt.Piece, _ t: Double) -> Bool {
        guard p.blink != 0 else { return true }
        let every = abs(p.blink), n = floor(t / every), u = t - n * every, d = 0.15
        let open = !(u < d) && !(Int(n) % 3 == 2 && u > 0.26 && u < 0.26 + d)
        return p.blink > 0 ? open : !open
    }
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

/// Double XP, counting down, as a badge in Up next's corner; nothing once it runs out.
private struct BoostBadge: View {
    @Environment(ProgressStore.self) private var progress
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let left = Int((progress.boostUntil - progress.now()) / 1000)
            if left > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "bolt.fill").font(.system(size: 11, weight: .heavy))
                    Text("2× · \(left / 60):\(String(format: "%02d", left % 60))").font(.nunito(13, .black)).monospacedDigit()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(Color(UIColor(hex: 0xB7822E)), in: Capsule())
            }
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
