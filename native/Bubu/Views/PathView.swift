import SwiftUI

/// The learning path: stepping stones on a gentle wave, chapter banners between them,
/// and the scenery composed in the path editor. Same geometry as the web app's phone
/// layout, so every piece lands where it was placed.
///
/// Built for speed: the layout is worked out once (`PathModel`) and kept until the
/// width or the current lesson changes, only the stretch near the screen is drawn,
/// and the body reads nothing from the store but which lessons are done, so a quest
/// counter or XP changing elsewhere doesn't redo the path.
struct PathView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(Router.self) private var router
    private let course = Course.shared
    @State private var cache = PathModel.Cache()
    /// the scroll band the drawn stretch is centred on (nil until the first scroll report)
    @State private var band: Int?
    /// the lesson the path last scrolled to, so coming back to the tab doesn't jump
    @State private var landedOn: String??

    private let size = PathModel.size, stoneRatio = PathModel.stoneRatio
    private typealias Item = PathModel.Item

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width, H = geo.size.height
            let current = progress.currentLessonId
            let model = cache.model(course, width: W, current: current)
            let win = PathModel.window(band: band ?? model.landingBand(viewport: H), viewport: H)
            ScrollViewReader { reader in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        Color.clear.frame(width: W, height: model.height)
                        grounds(model, win)
                        scenery(model, win, behind: true)
                        pebbles(model, win)
                        ForEach(model.items(in: win), id: \.lesson.id) { it in
                            if let ci = it.chapter { banner(ci, model: model, it: it, W: W) }
                            stone(it, W: W, current: current)
                        }
                        scenery(model, win, behind: false)
                        // a marker at the current stone, for the scroll to land on: positioned
                        // views all report the full canvas as their frame, so they can't be targets
                        VStack(spacing: 0) {
                            Color.clear.frame(height: max(0, model.currentY))
                            Color.clear.frame(width: 1, height: 1).id("current")
                        }
                        .allowsHitTesting(false)
                    }
                    .background {
                        GeometryReader { g in
                            Color.clear.preference(key: PathOffsetKey.self, value: -g.frame(in: .named("path")).minY)
                        }
                    }
                }
                .coordinateSpace(name: "path")
                .scrollIndicators(.hidden)
                .onPreferenceChange(PathOffsetKey.self) { y in
                    let b = PathModel.band(for: y)
                    if b != band { band = b }
                }
                // land on the current lesson the first time, and again when it moves on;
                // not on every visit to the tab, which would throw away where you'd scrolled
                .onAppear { land(reader, current) }
                .onChange(of: current) { _, c in land(reader, c) }
            }
            .overlay(alignment: .bottom) {
                // the web's bottom fade: solid for a few points, gone by 76
                LinearGradient(stops: [.init(color: .bg, location: 0), .init(color: .bg, location: 0.09),
                                       .init(color: .bg.opacity(0), location: 1)], startPoint: .bottom, endPoint: .top)
                    .frame(height: 76).allowsHitTesting(false)
            }
            .overlay(alignment: .top) { HUD() }
            .overlay(alignment: .bottom) { ReviewButton() }
        }
        .background(Color.bg.ignoresSafeArea())
    }

    private func land(_ reader: ScrollViewProxy, _ current: String?) {
        guard landedOn != .some(current) else { return }
        landedOn = .some(current)
        if current != nil { reader.scrollTo("current", anchor: .center) }
    }

    private func nodeX(_ i: Int, _ W: CGFloat, count: Int) -> CGFloat { PathModel.nodeX(i, W, count: count) }

    // MARK: pieces
    @ViewBuilder
    private func stone(_ it: Item, W: CGFloat, current: String?) -> some View {
        let done = progress.isDone(it.lesson.id), now = it.lesson.id == current
        let state = done ? "done" : now ? "now" : "locked"
        let x = nodeX(it.index, W, count: 64)
        Button { router.lesson = it.lesson } label: {
            ZStack {
                if now {
                    Circle().fill(Color.accent.opacity(0.28)).frame(width: size * 2.2, height: size * 1.5).blur(radius: 18)
                        .phaseAnimator([0.9, 1.08]) { v, s in v.scaleEffect(s) } animation: { _ in .easeInOut(duration: 1.1) }
                }
                Image("stone-\(state)-\(it.index % 5)")
                    .resizable()
                    .frame(width: size * stoneRatio, height: size)
                    .shadow(color: .black.opacity(0.2), radius: 3, y: 3)
                Text(course.hero[it.lesson.id] ?? "")
                    .font(.brush(35))
                    .foregroundStyle(done || now ? Color.onAccent : Color.todoHero)
                    .shadow(color: .black.opacity(done || now ? 0.3 : 0), radius: 0, y: -1.5)
                    .shadow(color: .white.opacity(done || now ? 0.2 : 0.5), radius: 0, y: 1.5)
                    .offset(y: -7.5)
                if now { StartBubble().offset(y: -size / 2 - 18) }
                if now { StepBadge(lessonId: it.lesson.id).offset(x: size * 0.66, y: size * 0.3) }
            }
        }
        .buttonStyle(StoneStyle())
        .position(x: x, y: it.y)
    }

    @ViewBuilder
    private func banner(_ ci: Int, model: PathModel, it: Item, W: CGFloat) -> some View {
        let (d, t) = progress.chapterProgress(ci)
        let right = course.data.pathLayout.headers[it.lesson.id] == "right"
        let mid = model.bannerMids[it.index] ?? it.y
        VStack(alignment: right ? .trailing : .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(course.chapterLabel(ci).uppercased())
                    .font(.nunitoXB(10)).tracking(1.3).foregroundStyle(Color.accent)
                GuidePill(chapter: ci)
            }
            Text(course.chapters[ci].title)
                .font(.nunitoXB(18)).tracking(-0.2).foregroundStyle(Color.ink)
                .multilineTextAlignment(right ? .trailing : .leading)
                .padding(.top, 2)
            Bar(value: Double(d) / Double(max(t, 1)))
                .scaleEffect(x: right ? -1 : 1)
                .padding(.top, 8).padding(.bottom, 5)
            HStack(spacing: 8) {
                Text("\(d) / \(t) lessons").font(.nunito(11, .bold)).foregroundStyle(Color.muted)
                // a finished chapter ends in its story
                if d == t, let story = course.storyFor(chapter: ci) { StoryPill(storyId: story.id) }
            }
        }
        .padding(.horizontal, 18)
        .frame(width: W * 0.62, alignment: right ? .trailing : .leading)
        .position(x: right ? W * 0.69 : W * 0.31, y: mid)
    }

    /// The scenery composed in the path editor, anchored to its stone.
    private func scenery(_ model: PathModel, _ win: ClosedRange<CGFloat>, behind: Bool) -> some View {
        ForEach(model.pieces(in: win, behind: behind), id: \.id) { p in
            Image(p.art)
                .resizable()
                .frame(width: p.w, height: p.h)
                .scaleEffect(x: p.flip ? -1 : 1, y: 1)
                .position(x: p.x, y: p.y)
                .allowsHitTesting(false)
        }
    }

    /// Cleared earth under each stone, so it reads as resting on the ground.
    private func grounds(_ model: PathModel, _ win: ClosedRange<CGFloat>) -> some View {
        let w = size * stoneRatio * PathModel.patchW
        return ForEach(model.items(in: win), id: \.lesson.id) { it in
            GroundPatch(shape: it.index % 4)
                .frame(width: w, height: w * PathModel.patchSquash)
                .position(x: model.xs[it.index], y: it.y + size * 0.14)
                .allowsHitTesting(false)
        }
    }

    /// The pebble trail (see `PathModel.trail`), one canvas per stretch between stones.
    private func pebbles(_ model: PathModel, _ win: ClosedRange<CGFloat>) -> some View {
        let W = model.width
        return ForEach(model.pebbles(in: win), id: \.key) { g in
            Canvas { ctx, _ in
                let img = ctx.resolve(Image("stone-locked-4"))
                for p in g.pebbles {
                    let w = max(3, p.w), h = max(2, p.w * 0.62)
                    ctx.draw(img, in: CGRect(x: p.x - w / 2, y: p.y - g.top - h / 2, width: w, height: h))
                }
            }
            .frame(width: W, height: g.bottom - g.top)
            .position(x: W / 2, y: (g.top + g.bottom) / 2)
            .allowsHitTesting(false)
        }
    }
}

private struct PathOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// "Read the story" under a finished chapter. Its own view, so the read/unread
/// check (the whole activity record) is watched here and not by the whole path.
struct StoryPill: View {
    let storyId: String
    @Environment(ProgressStore.self) private var progress
    @Environment(Router.self) private var router
    var body: some View {
        let read = progress.readDone(storyId)
        Button { router.push(.story(storyId)) } label: {
            Label(read ? "Read again" : "Read the story", systemImage: "book.fill")
                .font(.nunitoXB(11)).foregroundStyle(read ? Color.muted : Color.onAccent)
                .padding(.horizontal, 9).padding(.vertical, 3)
                .background(read ? Color.line : Color.accent, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// The irregular oval of cleared ground under a stone (the web's .pground g0–g3).
struct GroundPatch: View {
    let shape: Int
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        BlobShape(radii: BlobShape.presets[shape % 4])
            .fill(scheme == .dark ? Color(UIColor(hex: 0x24384F)).opacity(0.19)
                                  : Color(UIColor(hex: 0xE6DCC6)).opacity(0.33))
    }
}

/// A CSS `border-radius: a b c d / e f g h` shape, in percent.
struct BlobShape: Shape {
    let radii: [CGFloat]    // tl, tr, br, bl horizontal, then tl, tr, br, bl vertical
    static let presets: [[CGFloat]] = [
        [62, 38, 55, 45, 48, 62, 38, 52], [38, 62, 42, 58, 60, 40, 60, 40],
        [55, 45, 66, 34, 40, 58, 42, 60], [45, 55, 36, 64, 63, 42, 58, 37],
    ]
    func path(in r: CGRect) -> Path {
        let W = r.width, H = r.height, k: CGFloat = 0.5523
        let h = radii[0..<4].map { $0 / 100 * W }, v = radii[4..<8].map { $0 / 100 * H }
        var p = Path()
        p.move(to: CGPoint(x: r.minX + h[0], y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - h[1], y: r.minY))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.minY + v[1]),
                   control1: CGPoint(x: r.maxX - h[1] * (1 - k), y: r.minY),
                   control2: CGPoint(x: r.maxX, y: r.minY + v[1] * (1 - k)))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - v[2]))
        p.addCurve(to: CGPoint(x: r.maxX - h[2], y: r.maxY),
                   control1: CGPoint(x: r.maxX, y: r.maxY - v[2] * (1 - k)),
                   control2: CGPoint(x: r.maxX - h[2] * (1 - k), y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + h[3], y: r.maxY))
        p.addCurve(to: CGPoint(x: r.minX, y: r.maxY - v[3]),
                   control1: CGPoint(x: r.minX + h[3] * (1 - k), y: r.maxY),
                   control2: CGPoint(x: r.minX, y: r.maxY - v[3] * (1 - k)))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + v[0]))
        p.addCurve(to: CGPoint(x: r.minX + h[0], y: r.minY),
                   control1: CGPoint(x: r.minX, y: r.minY + v[0] * (1 - k)),
                   control2: CGPoint(x: r.minX + h[0] * (1 - k), y: r.minY))
        p.closeSubpath()
        return p
    }
}

struct StoneStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .offset(y: configuration.isPressed ? 2 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .medium), trigger: configuration.isPressed)
    }
}

/// Which step of a many-step lesson you're on, "1/2", tucked against the current
/// stone's edge like a coin; nothing for a one-step lesson.
struct StepBadge: View {
    let lessonId: String
    @Environment(ProgressStore.self) private var progress
    var body: some View {
        let s = StudySession.lessonSteps(lessonId, progress)
        if s.total > 1 {
            Text("\(s.step)/\(s.total)")
                .font(.nunito(12, .black)).monospacedDigit().foregroundStyle(Color.accent)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background {
                    ZStack {
                        Capsule().fill(Color.line).offset(y: 2)
                        Capsule().fill(Color.panel)
                        Capsule().strokeBorder(Color.line, lineWidth: 2)
                    }
                }
                .accessibilityLabel("Step \(s.step) of \(s.total)")
        }
    }
}

/// The white START tag over the current stone, with its little pointer and a
/// hard bottom edge, bobbing gently.
struct StartBubble: View {
    var body: some View {
        Text("START")
            .font(.nunito(12, .black)).tracking(0.5).foregroundStyle(Color.accent)
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background {
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.line).offset(y: 3)
                    Rectangle().fill(Color.panel).frame(width: 9, height: 9)
                        .overlay(alignment: .bottomTrailing) {
                            Path { p in p.move(to: .init(x: 9, y: 0)); p.addLine(to: .init(x: 9, y: 9)); p.addLine(to: .init(x: 0, y: 9)) }
                                .stroke(Color.line, lineWidth: 2)
                        }
                        .rotationEffect(.degrees(45)).offset(y: 5)
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.panel)
                    RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.line, lineWidth: 2)
                }
            }
            .phaseAnimator([0, -3]) { v, dy in v.offset(y: dy) } animation: { _ in .easeInOut(duration: 0.9) }
    }
}

/// The GUIDE tag beside a chapter's name.
struct GuidePill: View {
    let chapter: Int
    @Environment(Router.self) private var router
    var body: some View {
        Button { router.push(.guide(chapter)) } label: {
            HStack(spacing: 3) {
                Image(systemName: "lightbulb").font(.system(size: 10, weight: .bold))
                Text("GUIDE").font(.nunitoXB(10)).tracking(0.6)
            }
            .foregroundStyle(Color.gold)
            .padding(.leading, 6).padding(.trailing, 8).padding(.vertical, 2)
            .background(Color.gold.opacity(0.14), in: Capsule())
            .contentShape(Rectangle().inset(by: -8))
        }
        .buttonStyle(.plain)
    }
}

/// Streak, coins and buns in one bar across the top of the path (web: .hud-bar).
/// The flame opens Profile, the coins the shop, the buns the buns sheet.
struct HUD: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(Router.self) private var router
    var body: some View {
        let lit = progress.litOn(progress.today), plus = progress.isPlus, n = progress.buns
        HStack(spacing: 0) {
            segment("Streak, view progress") { router.tab = .profile } label: {
                Image(systemName: "flame.fill").font(.system(size: 16))
                Text("\(progress.streak)")
            }
            .foregroundStyle(lit ? Color.ember : Color.muted)
            divider
            segment("Coins, open the shop") { Moments.shared.show(.shop) } label: {
                CoinIcon(size: 20)
                Text("\(progress.coins)").foregroundStyle(Color.gold)
            }
            divider
            segment("Buns") { Moments.shared.show(.buns(.init(ctx: .hud))) } label: {
                BunIcon(width: 24)
                Text(plus ? "∞" : "\(n)").foregroundStyle(!plus && n <= 1 ? Color.again : Color.bunBrown)
            }
        }
        .fixedSize(horizontal: false, vertical: true)     // the dividers take the bar's height, no more
        .padding(2)
        .background {
            ZStack {
                Capsule().fill(Color.line).offset(y: 1)
                Capsule().fill(Color.panel)
                Capsule().strokeBorder(Color.line, lineWidth: 2)
            }
        }
        .padding(.horizontal, 14).padding(.top, 10)
    }

    private var divider: some View { Rectangle().fill(Color.line).frame(width: 2) }

    private func segment<L: View>(_ label: String, _ action: @escaping () -> Void, @ViewBuilder label content: () -> L) -> some View {
        Button(action: action) {
            HStack(spacing: 6, content: content)
                .font(.nunito(15, .black)).monospacedDigit()
                .frame(maxWidth: .infinity).padding(.vertical, 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressDown(depth: 1))
        .accessibilityLabel(label)
    }
}

struct ReviewButton: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(Router.self) private var router
    var body: some View {
        if progress.dueCount == 0 && progress.currentLessonId == nil {
            Text("Course complete — all caught up").font(.nunitoXB(15)).foregroundStyle(Color.good)
                .padding(.horizontal, 18).padding(.vertical, 11)
                .background(Color.goodSoft, in: Capsule())
                .padding(.bottom, 12)
        } else if progress.dueCount > 0 {
            Button { router.start(StudySession.review(progress)) } label: {
                Label("Review \(progress.dueCount) word\(progress.dueCount == 1 ? "" : "s")", systemImage: "arrow.triangle.2.circlepath")
                    .padding(.horizontal, 8)
            }
            .buttonStyle(PrimaryButtonStyle())
            .fixedSize()
            .padding(.bottom, 12)
        }
    }
}
