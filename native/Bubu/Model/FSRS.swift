import Foundation

/// One word's review history. Same fields and units as the web app's localStorage
/// record (times are milliseconds since 1970), so progress can move between the two.
struct SRSRecord: Codable, Equatable {
    var ease: Double?
    var interval: Double?      // days
    var due: Double?           // ms
    var reps: Int?
    var S: Double?             // FSRS stability, days
    var D: Double?             // FSRS difficulty, 1–10
    var last: Double?          // ms
    var lapses: Int?
    var known: Bool?           // answered right at least once
    var prod: Bool?            // produced it (recall, write, speak) at least once
    var miss: Miss?            // the last mistake, until it's put right

    /// Where a mistake happened: the exercise, when, and in which session.
    struct Miss: Codable, Equatable { var d: String; var at: Double; var s: Double }

    init(ease: Double? = nil, interval: Double? = nil, due: Double? = nil, reps: Int? = nil,
         S: Double? = nil, D: Double? = nil, last: Double? = nil, lapses: Int? = nil) {
        self.ease = ease; self.interval = interval; self.due = due; self.reps = reps
        self.S = S; self.D = D; self.last = last; self.lapses = lapses
    }

    // Lenient decoding: the web app wrote whatever JavaScript numbers it had, and a
    // single odd field must never cost someone their whole history.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func num(_ k: CodingKeys) -> Double? {
            if let d = try? c.decodeIfPresent(Double.self, forKey: k) { return d }
            if let s = try? c.decodeIfPresent(String.self, forKey: k) { return Double(s) }
            return nil
        }
        ease = num(.ease); interval = num(.interval); due = num(.due)
        let int = { (d: Double?) -> Int? in d.flatMap { $0.isFinite ? Int(exactly: $0.rounded()) : nil } }
        reps = int(num(.reps)); S = num(.S); D = num(.D)
        last = num(.last); lapses = int(num(.lapses))
        known = try? c.decodeIfPresent(Bool.self, forKey: .known)
        prod = try? c.decodeIfPresent(Bool.self, forKey: .prod)
        miss = try? c.decodeIfPresent(Miss.self, forKey: .miss)
    }
}

enum Grade: Int, Codable { case again = 1, hard = 2, good = 3, easy = 4 }

/// FSRS-5 with the default weights: a port of the web app's scheduler, line for line.
enum FSRS {
    static let w: [Double] = [0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046, 1.54575, 0.1192,
                              1.01925, 1.9395, 0.11, 0.29605, 2.2698, 0.2315, 2.9898, 0.51655, 0.6621]
    static let decay = -0.5, factor = 19.0 / 81.0, retention = 0.9
    static let day = 86_400_000.0

    static func clampD(_ d: Double) -> Double { min(10, max(1, d)) }
    static func d0(_ g: Double) -> Double { clampD(w[4] - exp(w[5] * (g - 1)) + 1) }
    static func r(days: Double, S: Double) -> Double { pow(1 + factor * days / S, decay) }
    static func interval(S: Double) -> Double { S / factor * (pow(retention, 1 / decay) - 1) }
    static func nextD(_ D: Double, _ g: Double) -> Double {
        let d = D - w[6] * (g - 3) * (10 - D) / 9
        return clampD(w[7] * d0(4) + (1 - w[7]) * d)
    }
    static func recall(D: Double, S: Double, R: Double, g: Double) -> Double {
        S * (exp(w[8]) * (11 - D) * pow(S, -w[9]) * (exp(w[10] * (1 - R)) - 1)
             * (g == 2 ? w[15] : 1) * (g == 4 ? w[16] : 1) + 1)
    }
    static func forget(D: Double, S: Double, R: Double) -> Double {
        min(S, w[11] * pow(D, -w[12]) * (pow(S + 1, w[13]) - 1) * exp(w[14] * (1 - R)))
    }

    /// The next state after a review. `random` is injectable so tests are exact.
    static func schedule(_ record: SRSRecord?, grade: Grade, now: Double,
                         random: () -> Double = { Double.random(in: 0..<1) }) -> SRSRecord {
        var s = record ?? SRSRecord(ease: 2.4, interval: 0, due: 0, reps: 0)
        let g = Double(grade.rawValue)
        // a word reviewed under the old scheduler: interval ≈ stability, ease → difficulty
        if s.S == nil && (s.reps ?? 0) >= 1 {
            s.S = max(0.5, (s.interval ?? 0) > 0 ? s.interval! : 1)
            s.D = clampD(5 + (2.4 - (s.ease ?? 2.4)) * 4.4)
            s.last = s.last ?? max(0, (s.due ?? now) - (s.interval ?? 0) * day)
        }
        if s.S == nil {                                    // first ever review
            s.S = w[grade.rawValue - 1]; s.D = d0(g)
        } else {
            let days = s.last.map { (now - $0) / day } ?? 0
            if days < 0.5 {                                // again the same day
                s.S = s.S! * exp(w[17] * (g - 3 + w[18]))
            } else {
                let R = r(days: days, S: s.S!)
                s.S = grade == .again ? forget(D: s.D!, S: s.S!, R: R) : recall(D: s.D!, S: s.S!, R: R, g: g)
            }
            s.D = nextD(s.D!, g)
        }
        s.S = max(0.1, s.S!); s.last = now
        if grade == .again {
            s.reps = 0; s.interval = 0
            s.lapses = (s.lapses ?? 0) + 1                 // powers "trouble words"
            s.due = now + 60_000                           // back in about a minute
        } else {
            s.reps = (s.reps ?? 0) + 1
            // a touch of fuzz so words learnt together don't all fall due the same day
            let iv = interval(S: s.S!), fuzz = iv > 3 ? 1 + (random() - 0.5) * 0.1 : 1
            s.interval = Double(max(1, min(365, Int((iv * fuzz).rounded()))))
            s.due = now + s.interval! * day
        }
        return s
    }
}
