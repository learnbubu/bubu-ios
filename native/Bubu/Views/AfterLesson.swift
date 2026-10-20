import SwiftUI

// The done screen's later screens, one thing each, as the after-lesson prototype (12 Oct 2026):
// the words met, the streak's lantern lighting, the quests moving on. (The first screen, how it
// went, and the buttons are DoneView's.)

/// "You learned": the session's new words (or a practice stone's words), one to a row, rising in turn.
struct LearnedStage: View {
    let title: String
    let cards: [Card]
    @State private var shown = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.nunitoXB(11.5)).tracking(1.2).foregroundStyle(Color.muted)
            Text(cards.count == 1 ? "1 new word" : "\(cards.count) new words")
                .font(.nunito(26, .black)).foregroundStyle(Color.ink).padding(.top, 2)
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { i, c in
                        row(c)
                            .opacity(i < shown ? 1 : 0)
                            .offset(y: i < shown ? 0 : 18)
                    }
                }
                .padding(.vertical, 14)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            if reduceMotion { shown = cards.count; return }
            try? await Task.sleep(for: .milliseconds(260))
            for i in 1...max(1, cards.count) {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) { shown = i }
                try? await Task.sleep(for: .milliseconds(110))
            }
        }
    }

    private func row(_ c: Card) -> some View {
        let w = c.word
        return HStack(spacing: 14) {
            Text(w.hanzi).font(.hanzi(w.hanzi.count > 2 ? 24 : 30, .semibold)).foregroundStyle(Color.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
                .frame(minWidth: 54, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                PinyinText(pinyin: w.pinyin, size: 14).lineLimit(1).minimumScaleFactor(0.7)
                Text(w.gloss).font(.nunito(14, .semibold)).foregroundStyle(Color.muted).lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
            if let pic = Pictures.asset(w.hanzi) {
                Image(pic).resizable().scaledToFit().frame(width: 34, height: 34)
            }
            SpeakerButton(text: w.hanzi, size: 16).accessibilityLabel("Hear \(w.hanzi)")
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.line, lineWidth: 1.5))
    }
}

/// The streak, when this session lit today's lantern, as the after-lesson design page (12 Oct 2026) plays it: the
/// lantern drops in on its rope from above the screen and bounces on it, hangs dull and swaying; a spark rises into
/// it and it lights (the kick swings it wider, a ring and a burst of sparks), the number rolls on; it's tugged up
/// (a whip runs down the rope), the week comes in, and a spark drops from its foot, arcs round the number and lands
/// on today, which ticks. The rope's a pendulum, the lantern on it a stiff spring and the tassel a loose one, so
/// the follow-through comes from the springs, not from timing. `finished` is called when it's all played.
struct StreakStage: View {
    let streak: Int
    /// a milestone day (3, 7, 14…): its line is told, not the week's
    var milestone = false
    var finished: () -> Void
    @Environment(ProgressStore.self) private var progress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start: Date?
    @State private var shown: Int
    @State private var lifted = false
    @State private var weekIn = false
    @State private var todayTicked = false
    @State private var lineIn = false
    @State private var sim = LanternSim()

    static let red = Color(UIColor(hex: 0xD9392F))
    // (the design page's timings, ms from the start)
    static let ignite = 650.0, mid = 840.0, roll = 859.0, grow = 1030.0, lift = 1550.0, liftFor = 420.0
    static let week = 1970.0, travel = 2270.0, travelFor = 520.0, land = 2790.0, button = 3050.0, slow = 3400.0
    /// the lantern's picture (150 × 232 in the design), the loop it hangs by 9% down it, its paper's middle 45%
    static let heroW: CGFloat = 129, heroH: CGFloat = 200

    init(streak: Int, milestone: Bool = false, finished: @escaping () -> Void) {
        self.streak = streak
        self.milestone = milestone
        self.finished = finished
        _shown = State(initialValue: max(0, streak - 1))
    }

    private func ms(_ d: Date) -> Double { start.map { d.timeIntervalSince($0) * 1000 } ?? (reduceMotion ? 99_999 : 0) }

    var body: some View {
        let week = progress.thisWeek, today = progress.today
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            TimelineView(.animation(paused: start == nil && !reduceMotion)) { ctx in lantern(ms(ctx.date)) }
                .frame(width: Self.heroW, height: Self.heroH)
                .anchorPreference(key: SparkEnds.self, value: .center) { SparkEnds(from: $0) }
                .padding(.top, 20)
            Text("\(shown)").font(.nunito(84, .black)).tracking(-2).foregroundStyle(Self.red)
                .monospacedDigit().contentTransition(.numericText(value: Double(shown)))
                .padding(.top, 22)   // (room for the tassel as it swings low, before the lift)
            Text("day streak").font(.nunito(20, .black)).foregroundStyle(Self.red).padding(.top, -6)
            weekRow(week, today: today)
                .padding(.top, 26)
                .opacity(weekIn ? 1 : 0).offset(y: weekIn ? 0 : 14)
            message(week, today: today)
                .padding(.top, 18).padding(.horizontal, 10)
                .opacity(lineIn ? 1 : 0)
            Spacer(minLength: 0)
        }
        .offset(y: lifted ? 0 : 60)
        .frame(maxWidth: .infinity)
        .overlayPreferenceValue(SparkEnds.self) { ends in
            GeometryReader { g in
                if let from = ends.from, let to = ends.to {
                    TimelineView(.animation(paused: start == nil)) { ctx in spark(ms(ctx.date), from: g[from], to: g[to], width: g.size.width) }
                }
            }
            .allowsHitTesting(false)
        }
        .task { await play() }
    }

    // MARK: the lantern on its rope

    @ViewBuilder
    private func lantern(_ t: Double) -> some View {
        let W = Self.heroW, H = Self.heroH
        let loop = CGPoint(x: W / 2, y: H * 0.09)
        let lit = t >= Self.mid
        let burst = span(t, Self.mid, 190), gr = span(t, Self.grow, 520)
        let g = lit ? (t < Self.grow ? easeOut(burst) : 1) : 0
        let s = sim.at(t)
        let flick = sin(t / 90) * 0.6 + sin(t / 53 + 1) * 0.4
        let L = easeIO(span(t, Self.lift, Self.liftFor)), heroScale = 1 - 0.12 * L
        let bob = lit ? -14 * easeOut(burst) * (1 - 0.4 * gr) - 3 * sin(t / 700) : 0
        // in from 300 pt up, overshooting and bouncing on the rope
        let drop = reduceMotion ? 1 : (t <= 0 ? 0 : 1 - exp(-t / 120) * cos(t / 78))
        let R = 300.0, th = s.rope * .pi / 180
        let dx = sin(th) * R, dy = (cos(th) - 1) * R + bob - 300 * (1 - drop)
        let taut = reduceMotion ? 0 : exp(-t / 150) * sin(t / 78) * -0.08
        let pop = 1 + 0.06 * pulse(burst)
        let mid = CGPoint(x: loop.x + dx + sin(th) * H * 0.36 * heroScale, y: loop.y + dy + cos(th) * H * 0.36 * heroScale)
        ZStack {
            // the glow behind it
            Circle()
                .fill(RadialGradient(colors: [Color(UIColor(hex: 0xFFB347)).opacity(0.6), .clear], center: .center, startRadius: 0, endRadius: 120))
                .frame(width: 240, height: 240)
                .scaleEffect((lit ? 0.6 + 0.55 * easeOut(burst) : 0.6) * (1 - 0.2 * L) * (1 + 0.04 * flick))
                .opacity(lit ? (t < Self.grow ? easeOut(burst) : 0.75 + 0.12 * flick) : 0)
                .position(mid)
            // the rope: from above the screen to the loop; a whip-wave runs down it as it's caught and pulled up
            rope(t, s: s, top: CGPoint(x: loop.x, y: -640), loop: CGPoint(x: loop.x + dx, y: loop.y + dy))
                .stroke(Color(UIColor(hex: 0xB8893A)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            // the lantern: the paper, and the tassel swinging on its own from the paper's foot
            ZStack {
                part(lit: g, top: 0.09, bottom: 0.23)
                part(lit: g, top: 0.764, bottom: 0)
                    .rotationEffect(.degrees(-12 * tanh((s.tassel - s.body) * 2.4 / 12)), anchor: UnitPoint(x: 0.5, y: 0.768))
                // its heart glowing
                Ellipse()
                    .fill(RadialGradient(colors: [Color(red: 1, green: 0.94, blue: 0.67).opacity(0.9), Color(red: 1, green: 0.78, blue: 0.35).opacity(0)], center: .center, startRadius: 0, endRadius: W * 0.3))
                    .frame(width: W * 0.56, height: H * 0.3)
                    .position(x: W / 2, y: H * 0.55)
                    .blendMode(.screen)
                    .opacity(g * (0.55 + 0.25 * flick) * (t < Self.grow ? 1 + 0.8 * pulse(burst) : 1))
            }
            .frame(width: W, height: H)
            .scaleEffect(x: heroScale * pop * (1 - taut * 0.5), y: heroScale * pop * (1 + taut), anchor: UnitPoint(x: 0.5, y: 0.09))
            .rotationEffect(.degrees(-s.body), anchor: UnitPoint(x: 0.5, y: 0.09))
            .offset(x: dx, y: dy)
            // the spark that lights it, up from below into its foot
            let sp = span(t, Self.ignite - 200, 390)
            Circle().fill(RadialGradient(colors: [.white, Color(UIColor(hex: 0xFFD36B)), Color(UIColor(hex: 0xFF8A2E)), .clear], center: .center, startRadius: 0, endRadius: 7))
                .frame(width: 14, height: 14)
                .scaleEffect(1 + 0.4 * sin(t / 40))
                .position(x: mid.x + 30 * sin(sp * 7) * (1 - sp), y: mid.y + 220 - 220 * easeIn(sp))
                .opacity(t >= Self.ignite - 200 && t < Self.mid ? 1 : 0)
            // the ring, and the sparks, as it catches
            let rg = span(t, Self.mid, 420)
            Circle().stroke(Color(UIColor(hex: 0xFFB347)), lineWidth: 6 - 5 * rg)
                .frame(width: 40, height: 40)
                .scaleEffect(0.5 + 5.5 * easeOut(rg))
                .opacity(rg > 0 && rg < 1 ? 1 - rg : 0)
                .position(mid)
            let u = span(t, Self.mid, 700)
            ForEach(0..<16, id: \.self) { i in
                let a = Double(i) / 16 * 2 * .pi + Self.jitter[i] * 0.3, d = 240 * (0.3 + Self.jitter[(i + 5) % 16] * 0.35) * easeOut(u)
                Circle().fill(i % 3 == 0 ? Self.red : Color(UIColor(hex: 0xFFC23B)))
                    .frame(width: 4 + Self.jitter[(i + 9) % 16] * 6, height: 4 + Self.jitter[(i + 9) % 16] * 6)
                    .position(x: mid.x + cos(a) * d, y: mid.y + sin(a) * d + 80 * u * u)
                    .opacity(u > 0 && u < 1 ? 1 - u : 0)
            }
        }
        .frame(width: W, height: H)
    }

    /// one band of the lantern's picture (top and bottom: how much of it is cut away), unlit with the lit over it
    private func part(lit g: Double, top: CGFloat, bottom: CGFloat) -> some View {
        let W = Self.heroW, H = Self.heroH
        return ZStack {
            Image("lantern-unlit").resizable().scaledToFill()
            Image("lantern-lit").resizable().scaledToFill().opacity(g)
        }
        .frame(width: W, height: H)
        .mask(Rectangle().frame(height: H * (1 - top - bottom)).offset(y: H * (top - bottom) / 2))
    }

    /// The rope, as a line of points from the top to the loop: bent by the whip and by the swing at its foot.
    private func rope(_ t: Double, s: LanternSim.State, top: CGPoint, loop: CGPoint) -> Path {
        let len = loop.y - top.y, n = 36
        let pulled = pulse(span(t, Self.lift - 60, Self.liftFor + 500)) * (1 - span(t, Self.lift + Self.liftFor * 0.6, 700))
        let whip = 14 * pulse(span(t, 60, 520)) + pulled * 6 + pulse(span(t, Self.mid, 700)) * 9
        var p = Path()
        for k in 0...n {
            let u = Double(k) / Double(n), y = top.y + u * len
            let wave = whip * sin(u * 10 - (t - Self.lift) / 55) * sin(.pi * u) * (0.35 + 0.65 * u)
            let foot = -s.ropeV * 0.06 * .pi / 180 * len * 0.45 * sin(.pi * u)
            let x = top.x + (loop.x - top.x) * u + wave + foot
            if k == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
        }
        return p
    }

    // MARK: the spark from the lantern's foot to today

    @ViewBuilder
    private func spark(_ t: Double, from c: CGPoint, to d: CGPoint, width: CGFloat) -> some View {
        // round the outside of the number, on whichever side has more room, then down into the badge
        let p0 = CGPoint(x: c.x, y: c.y + Self.heroH * 0.3), p3 = d, side: CGFloat = p3.x < width / 2 ? -1 : 1
        let c1 = CGPoint(x: p0.x + side * 150, y: p0.y + 30), c2 = CGPoint(x: p3.x + side * 120, y: p3.y - 110)
        let at = { (u: Double) -> CGPoint in
            let v = 1 - u, a = v * v * v, b = 3 * v * v * u, cc = 3 * v * u * u, dd = u * u * u
            return CGPoint(x: a * p0.x + b * c1.x + cc * c2.x + dd * p3.x, y: a * p0.y + b * c1.y + cc * c2.y + dd * p3.y)
        }
        let fall = { (u: Double) in easeIn(u) * 0.75 + u * 0.25 }   // (it gathers speed as it falls)
        let bu = span(t, Self.travel, Self.travelFor), live = t >= Self.travel && bu < 1
        ZStack {
            ForEach(0..<9, id: \.self) { k in
                let u = max(0, bu - Double(k + 1) * 0.035), z = CGFloat(12 - k)
                Circle().fill(k < 3 ? Color(UIColor(hex: 0xFFD36B)) : Color(UIColor(hex: 0xFF9A3D)))
                    .frame(width: z, height: z).position(at(fall(u)))
                    .opacity(live && u > 0 ? (1 - Double(k) / 9) * 0.8 : 0)
            }
            Circle()
                .fill(RadialGradient(colors: [.white, Color(UIColor(hex: 0xFFE08A)), Color(UIColor(hex: 0xFF9A3D)), .clear], center: .center, startRadius: 0, endRadius: 9))
                .frame(width: 18, height: 18)
                .shadow(color: Color(red: 1, green: 0.67, blue: 0.24).opacity(0.55), radius: 7)
                .scaleEffect(1 + 0.25 * sin(t / 35))
                .position(at(fall(bu)))
                .opacity(live ? 1 : 0)
            // a ring as it lands
            let rg = span(t, Self.land, 450)
            Circle().stroke(Color(UIColor(hex: 0xF0B03D)), lineWidth: 3)
                .frame(width: 34, height: 34).scaleEffect(1 + 1.2 * easeOut(rg))
                .position(p3).opacity(rg > 0 && rg < 1 ? 1 - rg : 0)
        }
    }

    private func weekRow(_ week: [String], today: String) -> some View {
        let names = ["M", "T", "W", "T", "F", "S", "S"]
        return HStack(spacing: 10) {
            ForEach(0..<7, id: \.self) { i in
                let d = week[i], isToday = d == today, future = d > today
                let on = isToday ? todayTicked : progress.litOn(d)
                VStack(spacing: 8) {
                    Text(names[i]).font(.nunitoXB(12)).foregroundStyle(isToday ? Self.red : Color.muted)
                    let nextOn = i < 6 && (week[i + 1] == today ? todayTicked : week[i + 1] < today && progress.litOn(week[i + 1]))
                    ZStack {
                        Circle().fill(on ? Self.red : future ? Color.line.opacity(0.6) : Color.line.opacity(0.35))
                        if isToday && !on { Circle().strokeBorder(Self.red, style: StrokeStyle(lineWidth: 2, dash: [4, 3])) }
                        if on { Image(systemName: "checkmark").font(.system(size: 13, weight: .heavy)).foregroundStyle(.white) }
                    }
                    .frame(width: 32, height: 32)
                    // days in a row join up into one pill, as Duolingo's
                    .background(alignment: .leading) {
                        if on && nextOn { Rectangle().fill(Self.red).frame(width: 42, height: 32).offset(x: 16) }
                    }
                    .scaleEffect(isToday && todayTicked ? 1 : isToday ? 0.92 : 1)
                    .anchorPreference(key: SparkEnds.self, value: .center) { isToday ? SparkEnds(to: $0) : SparkEnds() }
                }
            }
        }
    }

    @ViewBuilder
    private func message(_ week: [String], today: String) -> some View {
        let ti = week.firstIndex(of: today) ?? 0
        let allSoFar = (0..<ti).allSatisfy { progress.litOn(week[$0]) }
        let left = 6 - ti
        if milestone, let m = DoneView.milestoneWords[streak] {
            Text(m).font(.nunito(17, .heavy)).foregroundStyle(Color.ink).multilineTextAlignment(.center)
        } else if allSoFar && left == 0 {
            Text("A perfect week!").font(.nunito(16, .bold)).foregroundStyle(Color.muted)
        } else if allSoFar {
            (Text("Practise ") + Text("\(left) more day\(left == 1 ? "" : "s")").foregroundColor(Self.red) + Text(" for a perfect week!"))
                .font(.nunito(16, .bold)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
        } else {
            Text(DoneView.milestoneWords[streak] ?? (streak == 1 ? "Lantern lit. Come back tomorrow to make it two." : "Lantern lit. Keep it going tomorrow."))
                .font(.nunito(16, .bold)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
        }
    }

    /// The steps that aren't drawn from the clock (the number, the lift, the week, the tick, the line), at the
    /// design page's times; the lantern, its rope and the sparks follow the clock itself.
    private func play() async {
        if reduceMotion {
            shown = streak; lifted = true; weekIn = true; todayTicked = true; lineIn = true
            finished(); return
        }
        start = Date()
        func at(_ t: Double) async {
            let wait = t - ms(Date())
            if wait > 0 { try? await Task.sleep(for: .milliseconds(Int(wait))) }
        }
        await at(Self.mid)
        Sounds.shared.play("goal")
        await at(Self.roll)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) { shown = streak }
        await at(Self.lift)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) { lifted = true }
        await at(Self.week)
        withAnimation(.easeOut(duration: 0.3)) { weekIn = true }
        await at(Self.land)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { todayTicked = true }
        withAnimation(.easeOut(duration: 0.26)) { lineIn = true }
        await at(Self.button)
        finished()
    }

    /// (the sparks' spread: fixed, so every play looks the same)
    static let jitter: [Double] = [0.62, 0.13, 0.88, 0.41, 0.07, 0.73, 0.29, 0.95, 0.51, 0.18, 0.66, 0.34, 0.83, 0.02, 0.47, 0.71]
}

/// The lantern's swing (degrees, + to the right), stepped forward to the time asked: the rope a pendulum swinging
/// about straight down, the lantern hanging from it on a stiff spring, the tassel from the lantern on a looser one.
/// Pushed by the drop-in (it swings in from the side), the kick when it lights, the tug of the lift and a light
/// breeze at the rope's own rhythm; once the screen has settled it eases to a slow rock (the design page's lanternSim).
final class LanternSim {
    struct State { var rope = 10.0, ropeV = 0.0, body = 10.0, tassel = 10.0 }
    private var x = 0.0, ph = 0.0, r = 10.0, rv = 0.0, b = 10.0, bv = 0.0, q = 10.0, qv = 0.0
    private var kicked = false, tugged = false

    func at(_ t: Double) -> State {
        let end = max(0, t) / 1000
        if end < x { self.reset() }
        let dt = 1.0 / 240, w0 = 2 * Double.pi / 1.45, w1 = 2 * Double.pi / 2.86
        let kb = pow(2 * Double.pi / 0.32, 2), cb = 2 * 0.32 * sqrt(kb)
        let kt = pow(2 * Double.pi / 0.7, 2), ct = 2 * 0.045 * sqrt(kt)
        while x < end {
            let ms = x * 1000, k = min(1, max(0, (ms - StreakStage.slow) / 2500)), e = k * k * (3 - 2 * k)
            let wn = w0 + (w1 - w0) * e, c = 2 * 0.07 * wn
            if !kicked && ms >= StreakStage.mid { rv += 30; kicked = true }    // lighting it knocks it into a bigger swing
            if !tugged && ms >= StreakStage.lift { rv -= 8; tugged = true }    // the tug as it's pulled up
            ph += wn * 0.985 * dt
            let breeze = (17 + (4.7 - 17) * e) * sin(ph)
            let ra = -wn * wn * r - c * rv + breeze; rv += ra * dt; r += rv * dt
            let ba = kb * (r - b) - cb * bv + 0.35 * ra; bv += ba * dt; b += bv * dt
            let qa = kt * (b - q) - ct * qv + 2.4 * ba; qv += qa * dt; q += qv * dt
            x += dt
        }
        return State(rope: r, ropeV: rv, body: b, tassel: q)
    }
    private func reset() { x = 0; ph = 0; r = 10; rv = 0; b = 10; bv = 0; q = 10; qv = 0; kicked = false; tugged = false }
}

private func span(_ t: Double, _ a: Double, _ d: Double) -> Double { min(1, max(0, (t - a) / max(1, d))) }
private func easeOut(_ u: Double) -> Double { 1 - pow(1 - min(1, max(0, u)), 3) }
private func easeIn(_ u: Double) -> Double { pow(min(1, max(0, u)), 2) }
private func easeIO(_ u: Double) -> Double { let u = min(1, max(0, u)); return u < 0.5 ? 4 * u * u * u : 1 - pow(-2 * u + 2, 3) / 2 }
private func pulse(_ u: Double) -> Double { sin(.pi * min(1, max(0, u))) }

/// The spark's ends: the lantern, and today's circle in the week row.
private struct SparkEnds: PreferenceKey {
    var from: Anchor<CGPoint>? = nil
    var to: Anchor<CGPoint>? = nil
    static var defaultValue = SparkEnds()
    static func reduce(value: inout SparkEnds, nextValue: () -> SparkEnds) {
        let n = nextValue(); value.from = value.from ?? n.from; value.to = value.to ?? n.to
    }
}

/// Today's quests after a session (the owner, 14 Oct 2026: "more professional"): the pouch, how many
/// are done, and the three on one card, each bar filling from where it was when the session began;
/// a done one gets its tick, and all three, the lucky pocket.
struct QuestStage: View {
    let before: [String: Int]
    @Environment(ProgressStore.self) private var progress
    @State private var filled = -1
    @State private var bob = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let gold = Color(UIColor(hex: 0xF2B33D)), goldInk = Color(UIColor(hex: 0xB7822E))

    var body: some View {
        let quests = progress.todayQuests
        let shown = quests.enumerated().map { i, q -> Int in
            let now = min(q.target, progress.progress(of: q)), was = min(q.target, before[q.id] ?? now)
            return i <= filled ? now : was
        }
        let done = zip(quests, shown).filter { $1 >= $0.target }.count
        VStack(spacing: 0) {
            Image("quest-pouch").resizable().scaledToFit().frame(height: 104)
                .offset(y: bob ? -4 : 2)
                .shadow(color: goldInk.opacity(0.25), radius: 12, y: 8)
                .padding(.top, 6)
            Text("Daily quests").font(.nunito(28, .black)).tracking(-0.4).foregroundStyle(Home.ink).padding(.top, 14)
            Text(done == 3 ? "All three done today!" : "\(done) of 3 done today")
                .font(.nunito(15.5, .bold)).foregroundStyle(done == 3 ? goldInk : Home.muted)
                .contentTransition(.numericText(value: Double(done)))
                .padding(.top, 2)
            VStack(spacing: 0) {
                ForEach(Array(quests.enumerated()), id: \.offset) { i, q in
                    let n = shown[i], ok = n >= q.target
                    let was = min(q.target, before[q.id] ?? min(q.target, progress.progress(of: q)))
                    if i > 0 { Rectangle().fill(Home.line).frame(height: 1).padding(.leading, 66) }
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(ok ? Color.goodSoft : gold.opacity(0.18))
                            Image(systemName: ok ? "checkmark" : q.icon).font(.system(size: 17, weight: .heavy))
                                .foregroundStyle(ok ? Color.good : goldInk)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                // one size whatever the state (it shrank to fit beside "Done"): a long title wraps instead
                                Text(q.title).font(.nunito(15.5, .heavy)).foregroundStyle(Home.ink).lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 6)
                                Text(ok ? "Done" : "\(n) / \(q.target)").font(.nunito(13.5, .black)).monospacedDigit().fixedSize()
                                    .foregroundStyle(ok ? Color.good : Home.muted)
                                    .contentTransition(.numericText(value: Double(n)))
                            }
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color(UIColor(hex: 0xEFE9DD)))
                                    Capsule().fill(ok ? Color.good : gold).frame(width: g.size.width * Double(n) / Double(q.target))
                                }
                            }
                            .frame(height: 9)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 15)
                    .modifier(SuccessShine(on: ok && i <= filled && was < q.target, delay: 0.3))
                }
            }
            .homeCard(radius: 22)
            .padding(.top, 22)
            if done == 3 {
                HStack(spacing: 12) {
                    Image("pocket-jade").resizable().scaledToFit().frame(width: 34, height: 40)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Lucky pocket earned!").font(.nunito(16, .black)).foregroundStyle(Home.ink)
                        Text("Full of XP, for all three").font(.nunito(13, .bold)).foregroundStyle(Home.muted)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(gold.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(gold.opacity(0.6), lineWidth: 1.5))
                .padding(.top, 14)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .task {
            if !reduceMotion { withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { bob = true } }
            if reduceMotion { filled = 2; return }
            try? await Task.sleep(for: .milliseconds(450))
            for i in 0..<3 {
                withAnimation(.easeOut(duration: 0.56)) { filled = i }
                try? await Task.sleep(for: .milliseconds(560 + 260))
            }
        }
    }
}
