import SwiftUI

/// What the avatar stands in front of on Profile: a soft disc of colour, and a few four-pointed sparkles that twinkle
/// now and then. The colour is the learner's (chosen in the avatar editor); the sparkles are a deeper shade of it.
struct AvatarBackdrop: View {
    /// its colour (one of `colours`, by hex)
    var hex: String
    @Environment(\.accessibilityReduceMotion) private var still

    /// the colours to choose from: each a pale disc and its sparkles
    static let colours: [(name: String, hex: String, sparkle: UInt32)] = [
        ("Jade", "DFF1E6", 0x8FCFAE),
        ("Sky", "DDEEFA", 0x8DBFE6),
        ("Peach", "FCE6DA", 0xF0AE8C),
        ("Lilac", "ECE4F7", 0xB9A3E0),
        ("Butter", "FBF0CF", 0xE8C766),
    ]
    /// where the sparkles sit (a fraction of the disc, from its middle), how big, how long each one's twinkle takes
    /// (s), and where in it each starts (0-1: so they don't twinkle together)
    private static let sparkles: [(x: CGFloat, y: CGFloat, size: CGFloat, period: Double, phase: Double)] = [
        (-0.38, -0.02, 0.10, 2.6, 0.0), (0.37, 0.05, 0.11, 3.1, 0.45), (0.30, 0.29, 0.07, 2.2, 0.7),
        (-0.30, -0.33, 0.06, 2.8, 0.25), (0.33, -0.30, 0.05, 2.4, 0.85), (-0.36, 0.28, 0.05, 3.4, 0.6),
    ]

    var body: some View {
        let c = Self.colours.first { $0.hex == hex } ?? Self.colours[0]
        GeometryReader { g in
            let d = min(g.size.width, g.size.height)
            TimelineView(.animation(minimumInterval: 1 / 30, paused: still)) { t in
                let now = t.date.timeIntervalSinceReferenceDate
                ZStack {
                    Circle().fill(Color(UIColor(hex: UInt32(c.hex, radix: 16) ?? 0xDFF1E6)))
                    ForEach(Self.sparkles.indices, id: \.self) { i in
                        let s = Self.sparkles[i]
                        // (each twinkles in turn: grows from small, turning a little, bright at its biggest, and
                        // shrinks away again; and drifts gently up and down)
                        let u = (now / s.period + s.phase).truncatingRemainder(dividingBy: 1)
                        let pop = still ? 1 : pow(sin(.pi * u), 2)
                        Sparkle()
                            .fill(Color(UIColor(hex: c.sparkle)))
                            .frame(width: d * s.size, height: d * s.size)
                            .scaleEffect(still ? 1 : 0.35 + 0.85 * pop)
                            .rotationEffect(.degrees(still ? 0 : 40 * (u - 0.5)))
                            .opacity(still ? 0.9 : 0.25 + 0.75 * pop)
                            .offset(x: s.x * d, y: s.y * d + (still ? 0 : CGFloat(sin(now * 0.9 + s.phase * 6)) * d * 0.012))
                    }
                }
                .frame(width: d, height: d)
                .position(x: g.size.width / 2, y: g.size.height / 2)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A four-pointed sparkle: its points joined by curves bowed in to the middle.
struct Sparkle: Shape {
    func path(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY), w = r.width / 2, h = r.height / 2
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - h))
        p.addQuadCurve(to: CGPoint(x: c.x + w, y: c.y), control: c)
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + h), control: c)
        p.addQuadCurve(to: CGPoint(x: c.x - w, y: c.y), control: c)
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - h), control: c)
        return p
    }
}
