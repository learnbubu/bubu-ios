import Foundation

/// A stone's lesson is set (the owner, 24 Oct 2026: "I think it should be set, no? What if you want to go back to
/// practise it?"): every chance in it (the order, each word's kind of exercise, the wrong answers, a practice stone's
/// chat) comes from a generator seeded by the stone, so opening it again gives the same lesson, before it's done and
/// after. Reviews, one skill at a time and the shuffle button stay at chance.
///
/// A session hands its generator in while it builds (`Dice.begin` … `end`); outside one, everything is plain chance.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    /// seeded by a name: FNV-1a over its bytes (Swift's own hash changes with every launch)
    init(_ name: String) {
        var h: UInt64 = 0xcbf29ce484222325
        for b in name.utf8 { h ^= UInt64(b); h = h &* 0x100000001b3 }
        state = h
    }
    /// splitmix64
    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}

enum Dice {
    /// the generator of the session building now (nil: chance)
    nonisolated(unsafe) private static var active: SeededRNG?

    /// From here, the dice are `rng` (a session starting to build, or picking up again), till `end`.
    static func begin(_ rng: SeededRNG?) { active = rng }
    /// Chance again; the generator as it now stands, to carry on from next time.
    static func end() -> SeededRNG? { defer { active = nil }; return active }

    static func int(in r: Range<Int>) -> Int {
        if var g = active { defer { active = g }; return Int.random(in: r, using: &g) }
        return Int.random(in: r)
    }
    static func int(in r: ClosedRange<Int>) -> Int {
        if var g = active { defer { active = g }; return Int.random(in: r, using: &g) }
        return Int.random(in: r)
    }
    /// a number in 0..<1
    static func unit() -> Double {
        if var g = active { defer { active = g }; return Double.random(in: 0..<1, using: &g) }
        return Double.random(in: 0..<1)
    }
    static func shuffled<C: Collection>(_ c: C) -> [C.Element] {
        if var g = active { defer { active = g }; return c.shuffled(using: &g) }
        return c.shuffled()
    }
    static func element<C: Collection>(_ c: C) -> C.Element? {
        if var g = active { defer { active = g }; return c.randomElement(using: &g) }
        return c.randomElement()
    }
}

extension Collection {
    /// shuffled by the dice: the same each time for a set lesson, at chance otherwise
    func diced() -> [Element] { Dice.shuffled(self) }
    func dicedElement() -> Element? { Dice.element(self) }
}
