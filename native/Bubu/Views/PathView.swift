import SwiftUI

/// The learning path: stepping stones on a gentle wave, chapter banners between them,
/// and the scenery composed in the path editor. Same geometry as the web app's phone
/// layout, so every piece lands where it was placed.
struct PathView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(Router.self) private var router
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
                        grounds(items, W)
                        scenery(items, W, behind: true)
                        pebbles(items, W, current: current)
                        ForEach(items, id: \.lesson.id) { it in
                            if let ci = it.chapter { banner(ci, items: items, it: it, W: W, current: current) }
                            stone(it, W: W, current: current)
                        }
                        scenery(items, W, behind: false)
                        // a marker at the current stone, for the scroll to land on: positioned
                        // views all report the full canvas as their frame, so they can't be targets
                        VStack(spacing: 0) {
                            Color.clear.frame(height: max(0, (items.first { $0.lesson.id == current }?.y ?? 0)))
                            Color.clear.frame(width: 1, height: 1).id("current")
                        }
                        .allowsHitTesting(false)
                    }
                }
                .scrollIndicators(.hidden)
                // land on the current lesson, as the web does on every render
                .onAppear { if current != nil { reader.scrollTo("current", anchor: .center) } }
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
            }
        }
        .buttonStyle(StoneStyle())
        .position(x: x, y: it.y)
    }

    @ViewBuilder
    private func banner(_ ci: Int, items: [Item], it: Item, W: CGFloat, current: String?) -> some View {
        let (d, t) = progress.chapterProgress(ci)
        let right = course.data.pathLayout.headers[it.lesson.id] == "right"
        let mid = bannerMid(it, items: items, current: current)
        VStack(alignment: right ? .trailing : .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(course.chapterLabel(ci).uppercased())
                    .font(.nunitoXB(10)).tracking(1.3).foregroundStyle(Color.accent)
                GuidePill()
            }
            Text(course.chapters[ci].title)
                .font(.nunitoXB(18)).tracking(-0.2).foregroundStyle(Color.ink)
                .multilineTextAlignment(right ? .trailing : .leading)
                .padding(.top, 2)
            Bar(value: Double(d) / Double(max(t, 1)))
                .scaleEffect(x: right ? -1 : 1)
                .padding(.top, 8).padding(.bottom, 5)
            Text("\(d) / \(t) lessons").font(.nunito(11, .bold)).foregroundStyle(Color.muted)
        }
        .padding(.horizontal, 18)
        .frame(width: W * 0.62, alignment: right ? .trailing : .leading)
        .position(x: right ? W * 0.69 : W * 0.31, y: mid)
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

    /// Where a chapter header is centred: halfway between the stone above
    /// (or the HUD) and the top of its first stone, START bubble included.
    private func bannerMid(_ it: Item, items: [Item], current: String?) -> CGFloat {
        let top = it.y - size / 2 - (it.lesson.id == current ? bubble : 0)
        let prev = it.index == 0 ? hud : items[it.index - 1].y + size / 2
        return (prev + top) / 2
    }

    // MARK: scenery constants, from the path composer (SC in the web app)
    private let patchW: CGFloat = 1.20, patchSquash: CGFloat = 0.66
    private let pebEvery: CGFloat = 9.2, pebSize: CGFloat = 11, pebVar: CGFloat = 0.63
    private let pebWander: CGFloat = 31, pebClear: CGFloat = 4

    /// The web app's hash noise, -1…1.
    private func noise(_ n: Double) -> CGFloat {
        let v = sin(n * 12.9898) * 43758.5453
        return CGFloat((v - floor(v)) * 2 - 1)
    }

    /// Cleared earth under each stone, so it reads as resting on the ground.
    private func grounds(_ items: [Item], _ W: CGFloat) -> some View {
        let w = size * stoneRatio * patchW
        return ForEach(items, id: \.lesson.id) { it in
            GroundPatch(shape: it.index % 4)
                .frame(width: w, height: w * patchSquash)
                .position(x: nodeX(it.index, W, count: 64), y: it.y + size * 0.14)
                .allowsHitTesting(false)
        }
    }

    private struct Pebble { let x: CGFloat; let y: CGFloat; let w: CGFloat }

    /// The pebble trail, laid exactly as the web app lays it: a fixed density along a
    /// smooth walk through the stones, wandering either side, and dropped wherever
    /// it would land on a stone or under a chapter header. Drawn one segment per
    /// canvas so no single layer is the height of the whole course.
    private func trail(_ items: [Item], _ W: CGFloat, current: String?) -> [Int: [Pebble]] {
        guard items.count > 1 else { return [:] }
        let x = (0..<items.count).map { nodeX($0, W, count: 64) }
        let ys = items.map(\.y)
        let unit = size / 74
        func curve(_ t: CGFloat) -> (i: Int, x: CGFloat, y: CGFloat) {
            let f = t * CGFloat(ys.count - 1)
            let i = max(0, min(ys.count - 2, Int(floor(f))))
            var u = f - CGFloat(i); u = u * u * (3 - 2 * u)
            return (i, x[i] + (x[i + 1] - x[i]) * u, ys[i] + (ys[i + 1] - ys[i]) * u)
        }
        // headers, each on its own side of the page
        var headers: [Int: CGRect] = [:]
        for it in items where it.chapter != nil {
            let mid = bannerMid(it, items: items, current: current)
            let right = course.data.pathLayout.headers[it.lesson.id].map { $0 == "right" }
                ?? (it.index > 0 && (x[it.index - 1] + x[it.index]) / 2 < W / 2)
            headers[it.index] = CGRect(x: right ? W * 0.38 : 0, y: mid - bannerH / 2, width: W * 0.62, height: bannerH)
        }
        let halfW = size * stoneRatio / 2 + pebClear * unit, halfH = size / 2 + pebClear * unit
        let count = max(0, Int(((ys[ys.count - 1] - ys[0]) / (pebEvery * unit)).rounded()))
        var out: [Int: [Pebble]] = [:]
        for n in stride(from: 1, through: count, by: 1) {
            let t = CGFloat(n) / CGFloat(count + 1)
            let p = curve(t), q = curve(min(1, t + 0.002))
            let dx = q.x - p.x, dy = q.y - p.y, len = max(hypot(dx, dy), 1e-9)
            let off = pebWander * unit * noise(Double(n) * 1.7)
            let w = pebSize * unit * (1 + pebVar * noise(Double(n) * 4.3))
            let bx = p.x - dy / len * off, by = p.y + dx / len * off
            var hidden = false
            for i in max(0, p.i - 1)...min(ys.count - 1, p.i + 2) {
                let ex = (bx - x[i]) / (halfW + w / 2), ey = (by - ys[i]) / (halfH + w / 2)
                if ex * ex + ey * ey < 1 { hidden = true; break }
                if let h = headers[i], bx > h.minX - w, bx < h.maxX + w, by > h.minY - w, by < h.maxY + w { hidden = true; break }
            }
            if !hidden { out[p.i, default: []].append(Pebble(x: bx, y: by, w: w)) }
        }
        return out
    }

    private func pebbles(_ items: [Item], _ W: CGFloat, current: String?) -> some View {
        let groups = trail(items, W, current: current)
        return ForEach(groups.keys.sorted(), id: \.self) { i in
            let peb = groups[i]!
            let top = (peb.map(\.y).min() ?? 0) - 10, bottom = (peb.map(\.y).max() ?? 0) + 10
            Canvas { ctx, _ in
                let img = ctx.resolve(Image("stone-locked-4"))
                for p in peb {
                    let w = max(3, p.w), h = max(2, p.w * 0.62)
                    ctx.draw(img, in: CGRect(x: p.x - w / 2, y: p.y - top - h / 2, width: w, height: h))
                }
            }
            .frame(width: W, height: bottom - top)
            .position(x: W / 2, y: (top + bottom) / 2)
            .allowsHitTesting(false)
        }
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
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "lightbulb").font(.system(size: 10, weight: .bold))
            Text("GUIDE").font(.nunitoXB(10)).tracking(0.6)
        }
        .foregroundStyle(Color.gold)
        .padding(.leading, 6).padding(.trailing, 8).padding(.vertical, 2)
        .background(Color.gold.opacity(0.14), in: Capsule())
    }
}

/// Streak, the daily-goal ring and settings, floating over the top of the path.
struct HUD: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(Router.self) private var router
    var body: some View {
        let xp = progress.xpToday, goal = progress.dailyGoal, done = xp >= goal
        HStack(spacing: 8) {
            pill {
                Image(systemName: "flame.fill").font(.system(size: 14))
                Text("\(progress.streak)")
            }
            pill(tint: done ? .good : .accent, border: done ? .good : .line) {
                ZStack {
                    Circle().stroke(done ? Color.goodSoft : Color.line, lineWidth: 3)
                    Circle().trim(from: 0, to: min(1, Double(xp) / Double(goal)))
                        .stroke(done ? Color.good : Color.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.5), value: xp)
                }
                .frame(width: 15, height: 15).padding(2)
                Text("\(min(xp, goal))/\(goal)")
            }
            Spacer()
            Button { router.tab = .settings } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 17)).foregroundStyle(Color.accent)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.line).offset(y: 1))
                    .background(Circle().fill(Color.panel).overlay(Circle().strokeBorder(Color.line, lineWidth: 2)))
            }
            .buttonStyle(PressDown(depth: 1))
        }
        .padding(.horizontal, 14).padding(.top, 10)
    }
    private func pill<C: View>(tint: Color = .accent, border: Color = .line, @ViewBuilder _ c: () -> C) -> some View {
        HStack(spacing: 5, content: c)
            .font(.nunitoXB(14)).foregroundStyle(tint)
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background {
                ZStack {
                    Capsule().fill(border).offset(y: 1)
                    Capsule().fill(Color.panel)
                    Capsule().strokeBorder(border, lineWidth: 2)
                }
            }
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
