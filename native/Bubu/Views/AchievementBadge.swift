import SwiftUI

/// An achievement's badge, as Duolingo's are made but ours (the owner's mockup, 19 Oct 2026): a round coin in the
/// family's colour (a dark edge under it, a rim lit from above, the face set in), Bùbù standing in it (his legs inside
/// the face, the rest breaking out over the top, his shadow on it), the tier's number big over its foot with a thick
/// side under it, and "NEW" on one just earned. Drawn 600 × 680 and scaled to `width`.
struct AchievementBadge: View {
    let family: AchievementFamily
    let number: Int
    var isNew = false
    var locked = false
    var width: CGFloat

    var body: some View {
        let w = width, h = w * 680 / 600, u = w / 600
        let cx = w / 2, cy = h * 0.54, R = w * 0.38, rf = R - 27 * u
        let base = UIColor(hex: family.colour)
        ZStack(alignment: .topLeading) {
            // the ground's shadow, the coin's edge, its rim (lit from above), the band inside it, the face set in
            Circle().fill(Color.black.opacity(0.27)).frame(width: 2 * R, height: 2 * R).blur(radius: 8 * u).position(x: cx, y: cy + 34 * u)
            Circle().fill(Self.tone(base, 0.55)).frame(width: 2 * R, height: 2 * R).position(x: cx, y: cy + 24 * u)
            Circle().fill(LinearGradient(colors: [Self.light(base), Self.tone(base, 0.72)], startPoint: .top, endPoint: .bottom))
                .frame(width: 2 * R, height: 2 * R).position(x: cx, y: cy)
            Circle().fill(Self.tone(base, 0.7)).frame(width: 2 * (R - 22 * u), height: 2 * (R - 22 * u)).position(x: cx, y: cy)
            Circle().fill(LinearGradient(colors: [Self.tone(base, 1.08), Self.tone(base, 1)], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.8)))
                .overlay(Circle().fill(LinearGradient(colors: [Color.black.opacity(0.2), .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.14))))
                .frame(width: 2 * rf, height: 2 * rf).position(x: cx, y: cy + 5 * u)
            bubu(w: w, h: h, u: u, cx: cx, cy: cy, R: R, rf: rf, base: base)
            numeral(u: u, cx: cx, y: cy + R - 52 * u, w: w, base: base)
            if isNew {
                ZStack {
                    RoundedRectangle(cornerRadius: 14 * u).fill(Color(UIColor(hex: 0xA03026))).offset(y: 6 * u)
                    RoundedRectangle(cornerRadius: 14 * u).fill(Color(UIColor(hex: 0xD9483A)))
                    Text("NEW").font(.nunito(34 * u, .black)).foregroundStyle(Self.cream)
                }
                .frame(width: 130 * u, height: 56 * u)
                .position(x: w - 105 * u, y: 68 * u)
            }
        }
        .frame(width: w, height: h)
        .compositingGroup()
        .saturation(locked ? 0 : 1)
        .opacity(locked ? 0.45 : 1)
        .accessibilityHidden(true)
    }

    /// Bùbù (his picture, when it's in; the family's symbol until then): his legs kept inside the face.
    @ViewBuilder
    private func bubu(w: CGFloat, h: CGFloat, u: CGFloat, cx: CGFloat, cy: CGFloat, R: CGFloat, rf: CGFloat, base: UIColor) -> some View {
        if let pic = UIImage(named: family.image) {
            Image(uiImage: pic).resizable().scaledToFit()
                .frame(height: h * 0.86)
                .shadow(color: Self.tone(base, 0.45).opacity(0.45), radius: 10 * u, x: 10 * u, y: 14 * u)
                .frame(width: w, height: h, alignment: .top)
                .offset(y: h * 0.015)
                .mask(
                    ZStack(alignment: .topLeading) {
                        Rectangle().frame(width: w, height: cy - R * 0.1)
                        Circle().frame(width: 2 * rf, height: 2 * rf).position(x: cx, y: cy + 5 * u)
                    }
                    .frame(width: w, height: h, alignment: .topLeading)
                )
        } else {
            Image(systemName: family.symbol).font(.system(size: R * 0.75, weight: .bold))
                .foregroundStyle(Self.light(base))
                .shadow(color: Self.tone(base, 0.45).opacity(0.5), radius: 6 * u, x: 6 * u, y: 8 * u)
                .position(x: cx, y: cy - 12 * u)
        }
    }

    /// The tier's number: cream, outlined, a thick dark side under it.
    private func numeral(u: CGFloat, cx: CGFloat, y: CGFloat, w: CGFloat, base: UIColor) -> some View {
        let t = Text(Self.short(number)).font(.nunito(124 * u, .black))
        let r = 6 * u
        func outlined(_ c: Color) -> some View {
            ZStack { ForEach(0..<8, id: \.self) { i in
                let a = Double(i) * .pi / 4
                t.foregroundStyle(c).offset(x: r * cos(a), y: r * sin(a))
            } }
        }
        return ZStack {
            ForEach([12, 9, 6, 3], id: \.self) { k in outlined(Self.tone(base, 0.55)).offset(y: CGFloat(k) * u) }
            outlined(Self.tone(base, 0.8))
            t.foregroundStyle(LinearGradient(colors: [.white, Self.cream], startPoint: .top, endPoint: .bottom))
        }
        .lineLimit(1).minimumScaleFactor(0.5)
        .frame(width: w * 0.92)
        .position(x: cx, y: y)
    }

    static let cream = Color(UIColor(hex: 0xFFF7E2))
    static func short(_ n: Int) -> String { n >= 100_000 ? "\(n / 1000)K" : "\(n)" }
    /// the colour darker (k < 1) or lighter (k > 1)
    static func tone(_ c: UIColor, _ k: CGFloat) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(red: min(1, r * k), green: min(1, g * k), blue: min(1, b * k))
    }
    /// the colour, nearly halfway to white (the rim's lit top)
    static func light(_ c: UIColor) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(red: r + (1 - r) * 0.45, green: g + (1 - g) * 0.45, blue: b + (1 - b) * 0.45)
    }
}

/// A badge with its name and how far it's got under it: "2 of 5", or "Next: 7 days" before the first.
struct AchievementCell: View {
    @Environment(ProgressStore.self) private var progress
    let family: AchievementFamily
    var width: CGFloat

    var body: some View {
        let tier = family.tier(progress)
        let maxed = tier == family.tiers.count
        VStack(spacing: 2) {
            AchievementBadge(family: family, number: family.tiers[max(0, tier - 1)], isNew: tier > 0 && progress.isNew(family),
                             locked: tier == 0, width: width)
            Text(family.name).font(.nunito(14, .black)).foregroundStyle(Home.ink).lineLimit(1).minimumScaleFactor(0.75)
            Text(tier == 0 ? "Next: \(family.tiers[0]) \(family.unit)" : maxed ? "All \(tier) done" : "\(tier) of \(family.tiers.count)")
                .font(.nunito(12, .bold)).foregroundStyle(Home.muted).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(width: width)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(family.name), \(tier == 0 ? "not yet earned" : "tier \(tier) of \(family.tiers.count)")")
    }
}

/// Every achievement, three a row, the newest earned first: Profile's Achievements opens it.
struct AchievementsPage: View {
    @Environment(ProgressStore.self) private var progress

    var body: some View {
        let w = (UIScreen.main.bounds.width - 36 - 24) / 3
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(w), spacing: 12), count: 3), spacing: 22) {
                ForEach(progress.achievementsInOrder) { f in AchievementCell(family: f, width: w) }
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .background(Home.bg.ignoresSafeArea())
        .environment(\.colorScheme, .light)
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { progress.stampAchievements() }
    }
}
