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
    @State private var up = false
    @State private var wiggle = false
    @State private var words = false
    @State private var away = false

    static let lines = ["Way to go!", "太棒了!", "Nice work!", "Incredible!", "做得好!", "Keep it up!"]

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()
            VStack(spacing: 22) {
                Text(text).font(.nunito(30, .black)).foregroundStyle(Color.accent)
                    .opacity(words ? 1 : 0).scaleEffect(words ? 1 : 0.7)
                Image("panda-celebrate").resizable().scaledToFit().frame(height: 190)
                    .rotationEffect(.degrees(wiggle ? -7 : 7))
                    .offset(y: away ? 700 : up ? 0 : 520)
            }
            Confetti(count: 26).allowsHitTesting(false).opacity(words ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.62)) { up = true }
            withAnimation(.easeInOut(duration: 0.2).repeatCount(4, autoreverses: true).delay(0.3)) { wiggle = true }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.25)) { words = true }
            withAnimation(.easeIn(duration: 0.3).delay(1.25)) { away = true; words = false }
        }
    }
}
