import SwiftUI

/// The learning path: stepping stones on a gentle wave, chapter banners between them,
/// and the scenery composed in the path editor. Same geometry as the web app's phone
/// layout, so every piece lands where it was placed.
struct PathView: View {
    @Environment(ProgressStore.self) private var progress
    @State private var openLesson: Lesson?
    private let course = Course.shared

    // the web app's phone layout (PATH_CFG.phone)
    private let size: CGFloat = 74, gap: CGFloat = 143, wave: CGFloat = 106, per: CGFloat = 8, phase: CGFloat = 6
    private let hud: CGFloat = 62, bannerH: CGFloat = 72, hgap: CGFloat = 36, bubble: CGFloat = 40, pad: CGFloat = 170
    private let stoneRatio: CGFloat = 1.62

    private struct Item { let lesson: Lesson; let index: Int; let chapter: Int?; let y: CGFloat }

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let current = progress.currentLessonId
            let items = layout(current: current)
            let height = (items.last?.y ?? 0) + pad
            ScrollViewReader { reader in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        Color.clear.frame(width: W, height: height)
                        pebbles(items, W)
                        scenery(items, W, behind: true)
                        ForEach(items, id: \.lesson.id) { it in
                            if let ci = it.chapter { banner(ci, items: items, it: it, W: W, current: current) }
                            stone(it, W: W, current: current).id(it.lesson.id)
                        }
                        scenery(items, W, behind: false)
                    }
                }
                .scrollIndicators(.hidden)
                .onAppear { if let c = current, (course.lessonOrder[c] ?? 0) > 3 { reader.scrollTo(c, anchor: .center) } }
            }
            .overlay(alignment: .top) { HUD() }
            .overlay(alignment: .bottom) { ReviewButton() }
        }
        .background(Color.bg.ignoresSafeArea())
        .sheet(item: $openLesson) { LessonSheet(lesson: $0).presentationDetents([.large]).presentationDragIndicator(.visible) }
        .onAppear { if Launch.screen == "lesson" { openLesson = course.lessons.first } }
    }

    // MARK: geometry
    private func layout(current: String?) -> [Item] {
        var items: [Item] = [], y: CGFloat = 0, i = 0
        let bub = { (id: String) -> CGFloat in id == current ? bubble : 0 }
        for (ci, ch) in course.chapters.enumerated() {
            for (li, id) in ch.lessons.enumerated() {
                guard let lesson = course.lessonById[id] else { continue }
                if i == 0 { y = hud + 16 + bannerH + bub(id) + size / 2 }
                else if li == 0 { y += hgap + bannerH + bub(id) }
                items.append(Item(lesson: lesson, index: i, chapter: li == 0 ? ci : nil, y: y))
                y += gap; i += 1
            }
        }
        return items
    }

    private func nodeX(_ i: Int, _ W: CGFloat, count: Int) -> CGFloat {
        var k: CGFloat = 0
        for j in 0..<min(count, Int(per)) { k = max(k, abs(sin(CGFloat(j) * 2 * .pi / per))) }
        if k < 1e-6 { k = 1 }
        let half = size / 2 + 8
        return max(half, min(W - half, W / 2 + wave * sin((CGFloat(i) + phase) * 2 * .pi / per) / k))
    }

    // MARK: pieces
    @ViewBuilder
    private func stone(_ it: Item, W: CGFloat, current: String?) -> some View {
        let done = progress.isDone(it.lesson.id), now = it.lesson.id == current
        let state = done ? "done" : now ? "now" : "locked"
        let x = nodeX(it.index, W, count: 64)
        Button { openLesson = it.lesson } label: {
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
                if now { StartBubble().offset(y: -size / 2 - 22) }
            }
        }
        .buttonStyle(StoneStyle())
        .position(x: x, y: it.y)
    }

    @ViewBuilder
    private func banner(_ ci: Int, items: [Item], it: Item, W: CGFloat, current: String?) -> some View {
        let (d, t) = progress.chapterProgress(ci)
        let right = course.data.pathLayout.headers[it.lesson.id] == "right"
        let top: CGFloat = {
            if it.index == 0 { return hud + 8 }
            let prevBottom = items[it.index - 1].y + size / 2
            let thisTop = it.y - size / 2 - (it.lesson.id == current ? bubble : 0)
            return (prevBottom + thisTop) / 2 - bannerH / 2
        }()
        VStack(alignment: right ? .trailing : .leading, spacing: 4) {
            Text(course.chapterLabel(ci).uppercased())
                .font(.nunitoXB(11)).tracking(1.2).foregroundStyle(Color.accent)
            Text(course.chapters[ci].title)
                .font(.nunitoXB(19)).foregroundStyle(Color.ink)
                .multilineTextAlignment(right ? .trailing : .leading)
            ProgressView(value: Double(d), total: Double(max(t, 1)))
                .tint(.accent).frame(width: W * 0.55)
            Text("\(d) / \(t) lessons").font(.nunito(11, .semibold)).foregroundStyle(Color.muted)
        }
        .frame(width: W - 36, alignment: right ? .trailing : .leading)
        .position(x: W / 2, y: top + bannerH / 2)
    }

    /// The scenery composed in the path editor, anchored to its stone.
    @ViewBuilder
    private func scenery(_ items: [Item], _ W: CGFloat, behind: Bool) -> some View {
        let kx = W / 390
        let byId = Dictionary(uniqueKeysWithValues: items.map { ($0.lesson.id, $0) })
        ForEach(Array(course.data.pathLayout.pieces.enumerated()), id: \.offset) { _, p in
            if p.behind == behind, let it = byId[p.stone], let a = course.data.art[p.art] {
                let w = W * p.w / 100, h = w * a.ar
                let cx = nodeX(it.index, W, count: 64) + p.dx * kx, base = it.y + p.dy
                Image(p.art)
                    .resizable()
                    .frame(width: w, height: h)
                    .scaleEffect(x: p.flip ? -1 : 1, y: 1)
                    .position(x: cx, y: base - h / 2)
                    .allowsHitTesting(false)
            }
        }
    }

    /// A trail of small pebbles between stones.
    private func pebbles(_ items: [Item], _ W: CGFloat) -> some View {
        Canvas { ctx, _ in
            for i in 0..<max(0, items.count - 1) {
                let a = CGPoint(x: nodeX(i, W, count: 64), y: items[i].y)
                let b = CGPoint(x: nodeX(i + 1, W, count: 64), y: items[i + 1].y)
                for k in 1...5 {
                    let t = CGFloat(k) / 6
                    let wobble = sin(CGFloat(i * 7 + k) * 12.9898) * 9
                    let p = CGPoint(x: a.x + (b.x - a.x) * t + wobble, y: a.y + size / 2 + (b.y - a.y - size) * t)
                    let r = 3.2 + abs(sin(CGFloat(i + k) * 3.1)) * 2.2
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - r * 1.3, y: p.y - r, width: r * 2.6, height: r * 1.8)),
                             with: .color(Color.muted.opacity(0.28)))
                }
            }
        }
        .allowsHitTesting(false)
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

struct StartBubble: View {
    var body: some View {
        Text("START")
            .font(.nunitoXB(13)).tracking(0.8).foregroundStyle(Color.accent)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color.panel, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.line, lineWidth: 1.5))
            .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
            .phaseAnimator([0, -4]) { v, dy in v.offset(y: dy) } animation: { _ in .easeInOut(duration: 0.9) }
    }
}

/// Streak and today's XP, floating over the top of the path.
struct HUD: View {
    @Environment(ProgressStore.self) private var progress
    var body: some View {
        HStack(spacing: 8) {
            pill { Image(systemName: "flame.fill").foregroundStyle(.orange); Text("\(progress.streak)") }
            pill { Image(systemName: "star.fill").foregroundStyle(Color.gold); Text("\(progress.xpToday) XP") }
            Spacer()
        }
        .padding(.horizontal, 14).padding(.top, 4)
    }
    private func pill<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        HStack(spacing: 5, content: c)
            .font(.nunitoXB(14)).foregroundStyle(Color.ink)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.line, lineWidth: 1))
    }
}

struct ReviewButton: View {
    @Environment(ProgressStore.self) private var progress
    var body: some View {
        if progress.dueCount > 0 {
            Button {} label: {
                Label("Review \(progress.dueCount) word\(progress.dueCount == 1 ? "" : "s")", systemImage: "arrow.triangle.2.circlepath")
                    .padding(.horizontal, 8)
            }
            .buttonStyle(PrimaryButtonStyle())
            .fixedSize()
            .padding(.bottom, 12)
        }
    }
}
