import SwiftUI

/// What the avatar stands in front of on Profile: a soft disc of colour, and a few four-pointed sparkles that twinkle
/// now and then. The colour is the learner's (the avatar editor will offer the others); the sparkles are a deeper
/// shade of it.
struct AvatarBackdrop: View {
    @AppStorage("avatarBackdrop") private var hex = AvatarBackdrop.colours[0].hex
    @Environment(\.accessibilityReduceMotion) private var still

    /// the colours to choose from: each a pale disc and its sparkles
    static let colours: [(name: String, hex: String, sparkle: UInt32)] = [
        ("Jade", "DFF1E6", 0x8FCFAE),
        ("Sky", "DDEEFA", 0x8DBFE6),
        ("Peach", "FCE6DA", 0xF0AE8C),
        ("Lilac", "ECE4F7", 0xB9A3E0),
        ("Butter", "FBF0CF", 0xE8C766),
    ]
    /// where the sparkles sit (a fraction of the disc, from its middle), how big, and when each twinkles
    private static let sparkles: [(x: CGFloat, y: CGFloat, size: CGFloat, phase: Double)] = [
        (-0.38, -0.02, 0.10, 0.0), (0.37, 0.05, 0.11, 1.3), (0.30, 0.27, 0.07, 2.4), (-0.30, -0.33, 0.06, 3.1),
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
                        // (a slow breath, and every few seconds a brighter twinkle)
                        let k = still ? 1 : 0.8 + 0.2 * sin(now * 1.1 + s.phase) + 0.25 * max(0, sin(now * 0.7 + s.phase * 2) - 0.85) / 0.15
                        Sparkle()
                            .fill(Color(UIColor(hex: c.sparkle)))
                            .frame(width: d * s.size, height: d * s.size)
                            .scaleEffect(k)
                            .opacity(0.65 + 0.35 * min(1, k))
                            .offset(x: s.x * d, y: s.y * d)
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
