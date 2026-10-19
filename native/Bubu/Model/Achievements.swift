import Foundation

/// The achievements (docs/achievements.md): families that level up, each counting one thing you do, each tier a
/// threshold. Bùbù doing the family's thing is its picture (`achv-<id>.png`, Codex's, cut out: tools/art); until it
/// arrives, the family's symbol stands in.
struct AchievementFamily: Identifiable {
    let id: String
    let name: String
    /// what it counts, for "Next: 200 days"
    let unit: String
    let tiers: [Int]
    /// the badge's colour
    let colour: UInt32
    /// (stands in for Bùbù until his picture is in)
    let symbol: String
    let count: (ProgressStore) -> Int

    var image: String { "achv-\(id)" }
    /// How many tiers are reached (0: none yet).
    func tier(_ p: ProgressStore) -> Int { let n = count(p); return tiers.filter { n >= $0 }.count }

    static let all: [AchievementFamily] = [
        .init(id: "lantern-keeper", name: "Lantern Keeper", unit: "days", tiers: [7, 30, 100, 200, 365], colour: 0xD65640,
              symbol: "flame.fill") { $0.bestStreak },
        .init(id: "step-by-step", name: "Step by Step", unit: "lessons", tiers: [10, 50, 150, 400, 1000], colour: 0x2C9680,
              symbol: "figure.walk") { $0.done.count },
        .init(id: "word-garden", name: "Word Garden", unit: "words", tiers: [50, 250, 750, 1500, 3000], colour: 0x6FA35A,
              symbol: "leaf.fill") { $0.wordsLearned },
        .init(id: "brush-and-ink", name: "Brush and Ink", unit: "characters", tiers: [25, 100, 300, 700, 1500], colour: 0x7D7A74,
              symbol: "paintbrush.pointed.fill") { $0.charsKnown },
        .init(id: "copybook", name: "Copybook", unit: "characters written", tiers: [10, 100, 300, 1000, 3000], colour: 0xC9A15E,
              symbol: "pencil.and.scribble") { ($0.activity.written ?? [:]).values.reduce(0, +) },
        .init(id: "mountain-climber", name: "Mountain Climber", unit: "XP", tiers: [1000, 5000, 15000, 40000, 100_000], colour: 0x3E8E6E,
              symbol: "mountain.2.fill") { $0.xpTotal },
        .init(id: "storyteller", name: "Storyteller", unit: "stories", tiers: [1, 5, 15, 40, 76], colour: 0xE08A3C,
              symbol: "scroll.fill") { $0.activity.readsDone.count },
        .init(id: "seal-collector", name: "Seal Collector", unit: "chapters", tiers: [1, 5, 15, 30, 61], colour: 0xC0563B,
              symbol: "seal.fill") { p in (0..<Course.shared.chapters.count).filter(p.chapterDone).count },
        .init(id: "lucky-pockets", name: "Lucky Pockets", unit: "red pockets", tiers: [5, 25, 75, 150, 365], colour: 0xD9A43A,
              symbol: "envelope.fill") { $0.activity.chests },
        .init(id: "pathfinder", name: "Pathfinder", unit: "quests", tiers: [10, 50, 150, 400, 1000], colour: 0xA0703F,
              symbol: "safari.fill") { $0.activity.questMonths.values.reduce(0, +) },
        .init(id: "rekindled", name: "Rekindled", unit: "days relit", tiers: [1, 3, 10], colour: 0xE59A3A,
              symbol: "sparkles") { $0.activity.relit.values.filter { $0 }.count },
        .init(id: "flawless", name: "Flawless", unit: "flawless lessons", tiers: [1, 10, 50], colour: 0x4FA58C,
              symbol: "checkmark.seal.fill") { $0.moments("flawless") },
        .init(id: "night-owl", name: "Night Owl", unit: "late lessons", tiers: [1, 10, 50], colour: 0x4A5F9E,
              symbol: "moon.stars.fill") { $0.moments("nightowl") },
        .init(id: "early-bird", name: "Early Bird", unit: "early lessons", tiers: [1, 10, 50], colour: 0xEE8A3E,
              symbol: "sunrise.fill") { $0.moments("earlybird") },
        .init(id: "lightning-fast", name: "Lightning Fast", unit: "quick lessons", tiers: [1, 10, 50], colour: 0x4E9AC7,
              symbol: "bolt.fill") { $0.moments("speedy") },
        .init(id: "kung-fu-master", name: "Kung Fu Master", unit: "long runs", tiers: [1, 10, 50], colour: 0xB8433A,
              symbol: "figure.martial.arts") { $0.moments("kungfu") },
        .init(id: "dressed-up", name: "Dressed Up", unit: "outfit", tiers: [1], colour: 0x2E9E62,
              symbol: "hanger") { $0.activity.dressedUp == nil ? 0 : 1 },
    ]
}

extension ProgressStore {
    /// Words met at least once.
    var wordsLearned: Int { Course.shared.cards.filter { (srs[$0.id]?.reps ?? 0) >= 1 }.count }
    /// Lessons that ended on this moment (its key: "flawless", "nightowl"...).
    func moments(_ key: String) -> Int { activity.moments?[key] ?? 0 }

    /// The day a family's tier was first reached ("<family>-<tier>").
    func earned(_ f: AchievementFamily, _ tier: Int) -> String? { tier > 0 ? activity.achv["\(f.id)-\(tier)"] : nil }
    /// Every tier reached, stamped with the day it was first seen (for "NEW" and the newest first).
    func stampAchievements() {
        for f in AchievementFamily.all { let t = f.tier(self); if t > 0 { for k in 1...t { stampAchievement("\(f.id)-\(k)") } } }
    }
    /// Just earned: its tier reached today or yesterday.
    func isNew(_ f: AchievementFamily) -> Bool {
        guard let d = earned(f, f.tier(self)) else { return false }
        return d >= ProgressStore.dayKey(now() - 86_400_000)
    }
    /// Every family: the newest earned first, then the ones not yet begun, the nearest first.
    var achievementsInOrder: [AchievementFamily] {
        let fs = AchievementFamily.all
        let got = fs.filter { $0.tier(self) > 0 }.sorted { (earned($0, $0.tier(self)) ?? "") > (earned($1, $1.tier(self)) ?? "") }
        let rest = fs.filter { $0.tier(self) == 0 }.sorted { Double($0.count(self)) / Double($0.tiers[0]) > Double($1.count(self)) / Double($1.tiers[0]) }
        return got + rest
    }
}
