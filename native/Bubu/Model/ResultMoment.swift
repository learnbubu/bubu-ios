import Foundation

/// The sticker moment a session ends on (made in the effects studio's Moments tab): which one fits
/// the session, its title in the moment's colour and a line under it. Nil when none fits: the done
/// screen then keeps its usual splash and Bùbù.
struct ResultMoment: Equatable {
    /// the moment's name in the player (moments-player.html)
    let key: String
    let title: String
    let line: String
    /// the title's colour (the studio's)
    let color: UInt32

    /// What a session did, as far as choosing its moment goes.
    struct Facts {
        var mode: StudySession.Mode = .lesson
        var answered = 0
        var accuracy = 100
        var perfect = false
        var seconds = 0
        /// the longest run of right answers
        var bestRun = 0
        var mistakes = 0
        var fixed = 0
        /// words met for the first time
        var learned = 0
        /// the hour it finished (0–23)
        var hour = 12
        var streak = 0
        /// today's fire reached a streak milestone
        var milestone = false
    }

    /// A run this long is kung fu.
    static let kungfuRun = 15
    /// Quicker than this (seconds) is speedy.
    static let speedyUnder = 120
    /// This many new words at once is brain gains.
    static let brainWords = 4

    /// The moment for a session, the rarest first: a streak milestone, every mistake fixed, every
    /// answer right, a long run, a quick one, lots of new words, then the time of day.
    static func pick(_ f: Facts) -> ResultMoment? {
        guard f.mode != .placement, f.answered >= 5 else { return nil }
        if f.milestone && f.streak >= 3 {
            return .init(key: "onfire", title: "On fire!", line: "A \(f.streak) day streak!", color: 0xF0742F)
        }
        if f.mode == .mistakes && f.fixed > 0 && f.accuracy >= 80 {
            return .init(key: "sweep", title: "Clean sweep!",
                         line: f.mistakes == 0 ? "Every mistake fixed." : "\(f.fixed) mistake\(f.fixed == 1 ? "" : "s") fixed.", color: 0x3B82F6)
        }
        if f.perfect {
            return .init(key: "flawless", title: "满分! Flawless", line: "Every answer right.", color: 0xE0574A)
        }
        if f.bestRun >= kungfuRun {
            return .init(key: "kungfu", title: "Kung fu master!", line: "\(f.bestRun) in a row. Unstoppable.", color: 0x1F8A6D)
        }
        if f.seconds > 0 && f.seconds < speedyUnder && f.accuracy >= 80 {
            return .init(key: "speedy", title: "嗖! Lightning fast", line: "That was quick: under 2 minutes!", color: 0xF0B95A)
        }
        if f.learned >= brainWords {
            return .init(key: "brain", title: "Brain gains!", line: "\(f.learned) new words in one go.", color: 0xA78BFA)
        }
        if f.hour >= 22 || f.hour < 4 {
            return .init(key: "nightowl", title: "Night owl!", line: "Learning by lantern light.", color: 0x8B9BFF)
        }
        if (5..<9).contains(f.hour) {
            return .init(key: "earlybird", title: "Early bird!", line: "Up with the sun, 早上好!", color: 0xF0742F)
        }
        return nil
    }
}
