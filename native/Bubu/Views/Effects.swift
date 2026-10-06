import SwiftUI

// The lesson's celebrations, after the owner's Duolingo recording (6 Oct 2026): sparkles on a
// right answer, the combo burst every fifth in a row, and the cheer between parts of a lesson.

/// A four-point sparkle star.
struct SparkleShape: Shape {
    func path(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY), o = min(r.width, r.height) / 2, i = o * 0.26
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - o))
        p.addQuadCurve(to: CGPoint(x: c.x + o, y: c.y), control: CGPoint(x: c.x + i, y: c.y - i))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + o), control: CGPoint(x: c.x + i, y: c.y + i))
        p.addQuadCurve(to: CGPoint(x: c.x - o, y: c.y), control: CGPoint(x: c.x - i, y: c.y + i))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - o), control: CGPoint(x: c.x - i, y: c.y - i))
        p.closeSubpath()
        return p
    }
}

/// Two little sparkles that twinkle at a tile's corners as its shine passes (as Duolingo's).
struct CornerSparkles: View {
    var on: Bool
    var delay: Double = 0
    var tint: Color = .white
    @State private var a = false
    @State private var b = false

    var body: some View {
        GeometryReader { g in
            ZStack {
                SparkleShape().fill(tint).frame(width: 12, height: 12)
                    .scaleEffect(a ? 1 : 0.01).rotationEffect(.degrees(a ? 45 : 0)).opacity(a ? 1 : 0)
                    .position(x: g.size.width - 7, y: 6)
                SparkleShape().fill(tint).frame(width: 9, height: 9)
                    .scaleEffect(b ? 1 : 0.01).rotationEffect(.degrees(b ? 45 : 0)).opacity(b ? 1 : 0)
                    .position(x: 8, y: g.size.height - 6)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: on) { _, now in
            guard now else { return }
            twinkle($a, after: delay + 0.05)
            twinkle($b, after: delay + 0.18)
        }
    }

    private func twinkle(_ s: Binding<Bool>, after t: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + t) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) { s.wrappedValue = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                withAnimation(.easeIn(duration: 0.22)) { s.wrappedValue = false }
            }
        }
    }
}

/// The combo burst: a gold bolt strikes down the screen with "COMBO ×5" (every fifth in a row).
struct ComboBurst: View {
    let n: Int
    @State private var draw: CGFloat = 0
    @State private var label = false
    @State private var gone = false

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                bolt(w, h).trim(from: 0, to: draw)
                    .stroke(Color(UIColor(hex: 0x7A4A00)).opacity(0.35), style: StrokeStyle(lineWidth: 30, lineCap: .round, lineJoin: .round))
                bolt(w, h).trim(from: 0, to: draw)
                    .stroke(LinearGradient(colors: [Color(UIColor(hex: 0xFFE27A)), Color(UIColor(hex: 0xF5B03D))], startPoint: .top, endPoint: .bottom),
                            style: StrokeStyle(lineWidth: 22, lineCap: .round, lineJoin: .round))
                Text("COMBO ×\(n)")
                    .font(.nunito(34, .black)).italic()
                    .foregroundStyle(Color(UIColor(hex: 0xFFD54A)))
                    .shadow(color: Color(UIColor(hex: 0x7A4A00)), radius: 0, x: 2, y: 3)
                    .scaleEffect(label ? 1 : 0.4).opacity(label ? 1 : 0)
                    .position(x: w / 2, y: h * 0.47)
            }
            .opacity(gone ? 0 : 1)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 0.22)) { draw = 1 }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.08)) { label = true }
            withAnimation(.easeIn(duration: 0.3).delay(0.75)) { gone = true }
        }
    }

    /// A zigzag from near the top to the bottom of the screen.
    private func bolt(_ w: CGFloat, _ h: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: w * 0.30, y: h * 0.05))
        p.addLine(to: CGPoint(x: w * 0.50, y: h * 0.10))
        p.addLine(to: CGPoint(x: w * 0.36, y: h * 0.42))
        p.addLine(to: CGPoint(x: w * 0.56, y: h * 0.47))
        p.addLine(to: CGPoint(x: w * 0.40, y: h * 0.95))
        return p
    }
}

/// The cheer between parts of a lesson: the screen clears, Bùbù jumps up, cheers and drops away.
struct CheerView: View {
    let text: String
    @State private var words = false
    /// where Bùbù lands: a different happy pose each time
    @State private var land = ["panda-thumbs-up", "panda-heart", "panda-waving"].randomElement()!

    static let lines = ["Way to go!", "太棒了!", "Nice work!", "Incredible!", "做得好!", "Keep it up!"]

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()
            VStack(spacing: 22) {
                Text(text).font(.nunito(30, .black)).foregroundStyle(Color.accent)
                    .opacity(words ? 1 : 0).scaleEffect(words ? 1 : 0.7)
                PandaAct(keys: PandaAct.cheer(land: land), height: 190)
            }
            Confetti(count: 26).allowsHitTesting(false).opacity(words ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.6)) { words = true }
            withAnimation(.easeIn(duration: 0.25).delay(1.75)) { words = false }
        }
    }
}

/// Bùbù acted out with squash and stretch and pose swaps (the owner, 6 Oct 2026: the hop
/// Duolingo's owl does). A script of keyframes, eased between, with the pose changed at each
/// frame that names one; anchored at the feet so a squash sits on the ground.
struct PandaAct: View {
    struct Key {
        var t: Double
        var y: CGFloat = 0
        var sx: CGFloat = 1
        var sy: CGFloat = 1
        var rot: Double = 0
        var pose: String? = nil
    }
    let keys: [Key]
    var height: CGFloat = 190
    var loopFrom: Double? = nil      // after the last key, go back to this time (a gentle bob)
    @State private var start = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            Image(keys.compactMap(\.pose).last ?? "panda-celebrate").resizable().scaledToFit().frame(height: height)
        } else {
            TimelineView(.animation) { tl in
                let f = frame(at: tl.date.timeIntervalSince(start))
                Image(f.pose ?? "panda-celebrate").resizable().scaledToFit().frame(height: height)
                    .scaleEffect(x: f.sx, y: f.sy, anchor: .bottom)
                    .rotationEffect(.degrees(f.rot), anchor: .bottom)
                    .offset(y: f.y)
            }
        }
    }

    private func frame(at raw: Double) -> Key {
        guard let last = keys.last, let first = keys.first else { return Key(t: 0) }
        var t = raw
        if let l = loopFrom, t > last.t { t = l + (t - last.t).truncatingRemainder(dividingBy: last.t - l) }
        let pose = keys.last { $0.t <= t && $0.pose != nil }?.pose ?? keys.first { $0.pose != nil }?.pose
        if t <= first.t { var k = first; k.pose = pose; return k }
        if t >= last.t { var k = last; k.pose = pose; return k }
        let i = keys.lastIndex { $0.t <= t }!
        let a = keys[i], b = keys[i + 1]
        let u = (t - a.t) / max(0.0001, b.t - a.t)
        let e = CGFloat(u * u * (3 - 2 * u))           // smoothstep
        func mix(_ p: CGFloat, _ q: CGFloat) -> CGFloat { p + (q - p) * e }
        return Key(t: t, y: mix(a.y, b.y), sx: mix(a.sx, b.sx), sy: mix(a.sy, b.sy),
                   rot: Double(mix(CGFloat(a.rot), CGFloat(b.rot))), pose: pose)
    }

    /// The cheer: up from below, crouch, jump with a stretch (arms up mid-air), land with a
    /// squash on a happy pose, a wiggle, then down and away.
    static func cheer(land: String) -> [Key] {
        [Key(t: 0, y: 560, pose: "panda-idle"),
         Key(t: 0.28, y: -8),
         Key(t: 0.36, y: 0),
         Key(t: 0.46, sx: 1.13, sy: 0.82),                          // crouch
         Key(t: 0.62, y: -78, sx: 0.9, sy: 1.14, pose: "panda-celebrate"),
         Key(t: 0.80, y: -88, sx: 1, sy: 1, rot: -4),
         Key(t: 0.98, y: 0, sx: 0.95, sy: 1.06),
         Key(t: 1.06, sx: 1.14, sy: 0.84, pose: land),               // land
         Key(t: 1.2, sx: 0.97, sy: 1.04),
         Key(t: 1.3, rot: 6),
         Key(t: 1.42, rot: -6),
         Key(t: 1.54, rot: 4),
         Key(t: 1.64, rot: 0),
         Key(t: 1.72, sx: 1.08, sy: 0.9),                            // a dip before leaving
         Key(t: 2.0, y: 640, sx: 0.95, sy: 1.08)]
    }

    /// The done splash: a wow pops in big, then the arms go up with a bounce, then a bob.
    static let splash: [Key] = [
        Key(t: 0, y: 30, sx: 0.3, sy: 0.3, pose: "panda-surprised"),
        Key(t: 0.2, y: -16, sx: 0.92, sy: 1.14),
        Key(t: 0.32, sx: 1.12, sy: 0.86),
        Key(t: 0.44, sx: 1, sy: 1),
        Key(t: 0.58, sx: 1.1, sy: 0.88, pose: "panda-celebrate"),
        Key(t: 0.72, y: -30, sx: 0.94, sy: 1.08),
        Key(t: 0.86, y: 0, sx: 1.06, sy: 0.94),
        Key(t: 0.98, sx: 1, sy: 1),
        Key(t: 1.2, y: -6, rot: 3),
        Key(t: 1.45, y: 0, rot: -3)]
}
