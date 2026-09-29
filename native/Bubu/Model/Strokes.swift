import SwiftUI

/// Stroke data for writing practice (Make Me a Hanzi, as the web's HanziWriter
/// uses it): each stroke's outline as an SVG path and its median line, in a
/// 1024-unit box with y pointing up and the baseline at 900.
struct CharStrokes: Codable {
    let strokes: [String]
    let medians: [[[Double]]]
    let rad: [Int]?

    var count: Int { strokes.count }
    func median(_ i: Int) -> [CGPoint] { medians[i].map { CGPoint(x: $0[0], y: $0[1]) } }

    /// The first part to show as a guide: the radical's strokes, else the first third.
    var guideStrokes: [Int] {
        if let rad, !rad.isEmpty, rad.count < count { return rad }
        return Array(0..<max(1, Int(ceil(Double(count) / 3))))
    }
}

final class StrokeData {
    static let shared = StrokeData()
    let chars: [String: CharStrokes]
    private init() {
        if let url = Bundle.main.url(forResource: "strokes", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let d = try? JSONDecoder().decode([String: CharStrokes].self, from: data) {
            chars = d
        } else {
            chars = [:]
        }
    }
    func has(_ ch: String) -> Bool { chars[ch] != nil }
    /// Every character of a word can be written (web: wordWritable).
    func writable(_ hanzi: String) -> Bool {
        let hs = hanzi.filter(Course.isHan).map(String.init)
        return !hs.isEmpty && hs.allSatisfy(has)
    }
}

// MARK: how much help writing a character gets

/// The help for writing a character, from how many times the learner has finished writing
/// it (`ProgressStore.timesWritten`, the one source of truth). It fades from a full
/// walk-through for someone who has never written it to a blank grid.
enum WriteGuidance: Int, CaseIterable {
    /// The first time: the strokes play in order, the pale outline stays, and the next
    /// stroke is highlighted (a glow, a start dot, an arrow for its direction).
    case full = 0
    /// The second time: the pale outline, no highlight until a miss on that stroke.
    case outline = 1
    /// From the third time: a blank grid; after two misses the stroke is highlighted and traced.
    case memory = 2

    init(timesWritten n: Int) { self = n <= 0 ? .full : n == 1 ? .outline : .memory }

    /// The whole character's outline, pale, under the pen.
    var showsOutline: Bool { self != .memory }
    /// The strokes play in order before the pen is given.
    var playsDemo: Bool { self == .full }
    /// Misses on the current stroke before its highlight (glow, start dot, arrow) shows.
    var highlightAfter: Int {
        switch self {
        case .full: return 0
        case .outline: return 1
        case .memory: return 2
        }
    }
    /// Misses on the current stroke before it's traced for you along its centre line.
    var traceAfter: Int {
        switch self {
        case .full: return 1
        case .outline: return 2
        case .memory: return 2
        }
    }
    func highlights(misses: Int) -> Bool { misses >= highlightAfter }
    func traces(misses: Int) -> Bool { misses >= traceAfter }

    /// The exercise's prompt.
    var label: String {
        switch self {
        case .full: return "Trace, then write it"
        case .outline: return "Write it"
        case .memory: return "Write it from memory"
        }
    }
    /// The line under the box.
    var note: String {
        switch self {
        case .full: return "Watch the strokes, then trace them. The next stroke is lit up: start at the dot."
        case .outline: return "Write over the outline. Miss a stroke and it shows where to start."
        case .memory: return "Write it from memory. A hint shows after two misses."
        }
    }
}

// MARK: drawing the glyph

/// Maps glyph space (1024 units, y up, baseline 900) into a square of `size` points.
struct GlyphSpace {
    let size: CGFloat
    var s: CGFloat { size / 1024 }
    func toView(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * s, y: (900 - p.y) * s) }
    func toGlyph(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x / s, y: 900 - p.y / s) }
    var transform: CGAffineTransform { CGAffineTransform(a: s, b: 0, c: 0, d: -s, tx: 0, ty: 900 * s) }
    /// A line through glyph points, in view space (a stroke's median).
    func polyline(_ pts: [CGPoint]) -> Path {
        Path { p in
            guard let f = pts.first else { return }
            p.move(to: toView(f))
            for q in pts.dropFirst() { p.addLine(to: toView(q)) }
        }
    }
}

enum SVGPath {
    /// The absolute M, L, Q, C and Z commands the stroke data uses.
    static func parse(_ d: String) -> Path {
        var path = Path()
        let tokens = d.replacingOccurrences(of: ",", with: " ").split(separator: " ").map(String.init)
        var i = 0, cmd = ""
        func num() -> CGFloat { defer { i += 1 }; return CGFloat(Double(tokens[i]) ?? 0) }
        func pt() -> CGPoint { let x = num(); let y = num(); return CGPoint(x: x, y: y) }
        while i < tokens.count {
            if let c = tokens[i].first, c.isLetter { cmd = String(c); i += 1; if cmd == "Z" { path.closeSubpath(); continue } }
            switch cmd {
            case "M": path.move(to: pt()); cmd = "L"
            case "L": path.addLine(to: pt())
            case "Q": let c = pt(); path.addQuadCurve(to: pt(), control: c)
            case "C": let c1 = pt(); let c2 = pt(); path.addCurve(to: pt(), control1: c1, control2: c2)
            default: i += 1
            }
        }
        return path
    }

    private static var cache: [String: Path] = [:]
    static func stroke(_ d: String) -> Path {
        if let p = cache[d] { return p }
        let p = parse(d); cache[d] = p; return p
    }
}

// MARK: checking a drawn stroke (HanziWriter's strokeMatches, ported)

enum StrokeMatch {
    /// How forgiving the check is: the web's `quiz({ leniency: 1.4 })`. The thresholds
    /// below are HanziWriter 3.7's own, so the app and the website accept the same strokes.
    static let leniency = 1.4
    static let avgDistThreshold = 350.0
    static let startEndThreshold = 250.0
    static let frechetThreshold = 0.4
    static let minLenThreshold = 0.35
    static let fitRotations = [Double.pi / 16, Double.pi / 32, 0, -Double.pi / 32, -Double.pi / 16]

    /// Does the drawn stroke (in glyph space) match stroke `n` of the character?
    static func matches(_ drawn: [CGPoint], char c: CharStrokes, stroke n: Int, leniency: Double, outlineVisible: Bool) -> Bool {
        let points = stripDuplicates(drawn)
        guard points.count >= 2 else { return false }
        var (isMatch, avgDist) = matchData(points, c.median(n), strokeNum: n, leniency: leniency, outlineVisible: outlineVisible)
        guard isMatch else { return false }
        // if a later stroke fits better, this probably wasn't meant for stroke n
        var closest = avgDist
        for later in (n + 1)..<c.count {
            let m = matchData(points, c.median(later), strokeNum: later, leniency: leniency, outlineVisible: outlineVisible)
            if m.0 && m.1 < closest { closest = m.1 }
        }
        if closest < avgDist {
            let adjust = 0.6 * (closest + avgDist) / (2 * avgDist)
            (isMatch, avgDist) = matchData(points, c.median(n), strokeNum: n, leniency: leniency * adjust, outlineVisible: outlineVisible)
        }
        return isMatch
    }

    private static func matchData(_ points: [CGPoint], _ median: [CGPoint], strokeNum: Int, leniency: Double, outlineVisible: Bool) -> (Bool, Double) {
        let avgDist = averageDistance(points, median)
        let distMod = outlineVisible || strokeNum > 0 ? 0.5 : 1
        guard avgDist <= avgDistThreshold * distMod * leniency else { return (false, avgDist) }
        let ok = startAndEnd(points, median, leniency) && direction(points, median)
            && shape(points, median, leniency) && lengthOK(points, median, leniency)
        return (ok, avgDist)
    }

    static func dist(_ a: CGPoint, _ b: CGPoint) -> Double { Double(hypot(a.x - b.x, a.y - b.y)) }

    static func stripDuplicates(_ pts: [CGPoint]) -> [CGPoint] {
        var out: [CGPoint] = []
        for p in pts where out.last != p { out.append(p) }
        return out
    }

    static func length(_ pts: [CGPoint]) -> Double {
        zip(pts, pts.dropFirst()).reduce(0) { $0 + dist($1.0, $1.1) }
    }

    static func averageDistance(_ points: [CGPoint], _ median: [CGPoint]) -> Double {
        points.reduce(0) { acc, p in acc + (median.map { dist($0, p) }.min() ?? 0) } / Double(points.count)
    }

    static func startAndEnd(_ points: [CGPoint], _ median: [CGPoint], _ leniency: Double) -> Bool {
        dist(median.first!, points.first!) <= startEndThreshold * leniency
            && dist(median.last!, points.last!) <= startEndThreshold * leniency
    }

    static func vectors(_ pts: [CGPoint]) -> [CGPoint] {
        zip(pts, pts.dropFirst()).map { CGPoint(x: $1.x - $0.x, y: $1.y - $0.y) }
    }

    static func cosine(_ a: CGPoint, _ b: CGPoint) -> Double {
        let m = Double(hypot(a.x, a.y) * hypot(b.x, b.y))
        return m == 0 ? 0 : Double(a.x * b.x + a.y * b.y) / m
    }

    static func direction(_ points: [CGPoint], _ median: [CGPoint]) -> Bool {
        let sv = vectors(median)
        let sims = vectors(points).map { e in sv.map { cosine($0, e) }.max() ?? -1 }
        guard !sims.isEmpty else { return false }
        return sims.reduce(0, +) / Double(sims.count) > 0
    }

    static func lengthOK(_ points: [CGPoint], _ median: [CGPoint], _ leniency: Double) -> Bool {
        leniency * (length(points) + 25) / (length(median) + 25) >= minLenThreshold
    }

    static func shape(_ points: [CGPoint], _ median: [CGPoint], _ leniency: Double) -> Bool {
        let a = normalize(median), b = normalize(points)
        let best = fitRotations.map { frechet(a, rotate(b, $0)) }.min() ?? .infinity
        return best <= frechetThreshold * leniency
    }

    static func rotate(_ c: [CGPoint], _ t: Double) -> [CGPoint] {
        let co = CGFloat(cos(t)), si = CGFloat(sin(t))
        return c.map { CGPoint(x: co * $0.x - si * $0.y, y: si * $0.x + co * $0.y) }
    }

    static func extend(_ p1: CGPoint, _ p2: CGPoint, _ d: Double) -> CGPoint {
        let v = CGPoint(x: p2.x - p1.x, y: p2.y - p1.y)
        let mag = Double(hypot(v.x, v.y))
        guard mag > 0 else { return p2 }
        let n = CGFloat(d / mag)
        return CGPoint(x: p2.x + n * v.x, y: p2.y + n * v.y)
    }

    /// Resample to 30 evenly spaced points.
    static func outline(_ curve: [CGPoint], _ numPoints: Int = 30) -> [CGPoint] {
        let seg = length(curve) / Double(numPoints - 1)
        var out = [curve[0]]
        var rest = Array(curve.dropFirst())
        guard seg > 0 else { return curve }
        for _ in 0..<(numPoints - 2) {
            var last = out.last!, remaining = seg
            while true {
                guard let next = rest.first else { break }
                let d = dist(last, next)
                if d < remaining { remaining -= d; last = rest.removeFirst() }
                else { out.append(extend(last, next, remaining - d)); break }
            }
            if rest.isEmpty { break }
        }
        out.append(curve.last!)
        return out
    }

    static func subdivide(_ curve: [CGPoint], _ maxLen: Double = 0.05) -> [CGPoint] {
        var out = [curve[0]]
        for p in curve.dropFirst() {
            let prev = out.last!
            let d = dist(p, prev)
            if d > maxLen {
                let n = Int(ceil(d / maxLen)), step = d / Double(n)
                for i in 0..<n { out.append(extend(p, prev, -step * Double(i + 1))) }
            } else {
                out.append(p)
            }
        }
        return out
    }

    static func normalize(_ curve: [CGPoint]) -> [CGPoint] {
        let o = outline(curve)
        let mx = o.map(\.x).reduce(0, +) / CGFloat(o.count), my = o.map(\.y).reduce(0, +) / CGFloat(o.count)
        let t = o.map { CGPoint(x: $0.x - mx, y: $0.y - my) }
        let scale = sqrt((Double(t.first!.x * t.first!.x + t.first!.y * t.first!.y)
                          + Double(t.last!.x * t.last!.x + t.last!.y * t.last!.y)) / 2)
        guard scale > 0 else { return t }
        return subdivide(t.map { CGPoint(x: $0.x / CGFloat(scale), y: $0.y / CGFloat(scale)) })
    }

    /// Discrete Fréchet distance.
    static func frechet(_ c1: [CGPoint], _ c2: [CGPoint]) -> Double {
        let long = c1.count >= c2.count ? c1 : c2, short = c1.count >= c2.count ? c2 : c1
        var prev: [Double] = []
        for i in 0..<long.count {
            var cur: [Double] = []
            for j in 0..<short.count {
                let d = dist(long[i], short[j])
                let v: Double
                if i == 0 && j == 0 { v = d }
                else if i > 0 && j == 0 { v = max(prev[0], d) }
                else if i == 0 { v = max(cur[j - 1], d) }
                else { v = max(min(prev[j], prev[j - 1], cur[j - 1]), d) }
                cur.append(v)
            }
            prev = cur
        }
        return prev.last ?? .infinity
    }
}

// MARK: the pen's ink (pure geometry, so it can be tested)

/// Smooth ink from touch samples, as Notes-style pens draw it: a quadratic curve through
/// the midpoints of successive samples, each sample its control point. The ink has no
/// corners at the samples however fast the finger moves, and it never overshoots them.
enum InkGeometry {
    enum Segment: Equatable {
        case move(CGPoint)
        case line(CGPoint)
        case quad(to: CGPoint, control: CGPoint)
    }

    static func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    /// Straight to the first midpoint, curves from midpoint to midpoint, straight to the end.
    /// One sample gives a zero-length line, which round caps draw as a dot.
    static func segments(_ pts: [CGPoint]) -> [Segment] {
        guard let first = pts.first else { return [] }
        let last = pts[pts.count - 1]
        guard pts.count > 2 else { return [.move(first), .line(last)] }
        var out: [Segment] = [.move(first), .line(midpoint(pts[0], pts[1]))]
        for i in 1..<(pts.count - 1) {
            out.append(.quad(to: midpoint(pts[i], pts[i + 1]), control: pts[i]))
        }
        out.append(.line(last))
        return out
    }

    static func path(_ pts: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        for seg in segments(pts) {
            switch seg {
            case .move(let a): path.move(to: a)
            case .line(let a): path.addLine(to: a)
            case .quad(let a, let c): path.addQuadCurve(to: a, control: c)
            }
        }
        return path
    }

    /// Samples at least `minDistance` apart, keeping the first and the last. Coalesced
    /// touches come every half point or so; the stroke check (like HanziWriter, which sees
    /// one sample a frame) wants the shape, not the finger's tremor between samples.
    static func thin(_ pts: [CGPoint], minDistance: CGFloat) -> [CGPoint] {
        guard pts.count > 2 else { return pts }
        var out: [CGPoint] = [pts[0]]
        for p in pts.dropFirst().dropLast() {
            let q = out[out.count - 1]
            if hypot(p.x - q.x, p.y - q.y) >= minDistance { out.append(p) }
        }
        let last = pts[pts.count - 1]
        // the true end, not a sample just short of it
        if out.count > 1 {
            let q = out[out.count - 1]
            if hypot(last.x - q.x, last.y - q.y) < minDistance { out.removeLast() }
        }
        out.append(last)
        return out
    }
}

// MARK: the brush (pure geometry, so it can be tested)

/// The pen's ink as a brush: a filled outline around a smoothed centre line whose width
/// follows the finger (slower is thicker, or the pressure where a touch reports one),
/// narrowing at the touch-down and at the lift, with round ends.
extension InkGeometry {
    /// One touch sample: where, when (seconds), and the pressure (0...1) if the touch reports one.
    struct Sample: Equatable {
        var point: CGPoint
        var time: TimeInterval
        var force: CGFloat? = nil
    }

    /// The brush's feel. Sizes are points at a ~340 pt box; `forBox` fits other boxes.
    struct Brush: Equatable {
        var minWidth: CGFloat = 5
        var maxWidth: CGFloat = 11
        /// At or below this speed (pt/s) the brush is at its widest; at or above `fastSpeed`, its narrowest.
        var slowSpeed: CGFloat = 120
        var fastSpeed: CGFloat = 1300
        /// The low-pass filter's time constant (s): the width follows the speed over about this long.
        var smoothing: Double = 0.06
        /// The lift: the last `endTaper` points narrow to `endTaperTo` of the width.
        var endTaper: CGFloat = 12
        var endTaperTo: CGFloat = 0.35
        /// The touch-down: the first `startTaper` points widen from `startTaperFrom` of the width.
        var startTaper: CGFloat = 8
        var startTaperFrom: CGFloat = 0.55
        /// Samples closer than this are merged (a finger's tremor between 240 Hz samples).
        var minSampleGap: CGFloat = 1
        /// The smoothed centre line's point spacing.
        var spacing: CGFloat = 2

        static let standard = Brush()

        /// For a box `side` points wide: widths, tapers and speeds scale with it, so a
        /// writing sheet's small cells get a finer brush.
        static func forBox(_ side: CGFloat) -> Brush {
            let k = max(0.5, min(1.2, side / 340))
            var b = Brush()
            b.minWidth *= k
            b.maxWidth *= k
            b.endTaper *= k
            b.startTaper *= k
            b.slowSpeed *= k
            b.fastSpeed *= k
            return b
        }
    }

    static func gap(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(b.x - a.x, b.y - a.y) }

    /// The brush's width at each sample, before the tapers: from the pressure where the
    /// touch reports one, else from the speed (slower, thicker), low-pass filtered over time
    /// so the line swells and thins smoothly instead of flickering sample to sample.
    /// Always within `minWidth...maxWidth`.
    static func widths(_ s: [Sample], brush b: Brush) -> [CGFloat] {
        guard !s.isEmpty else { return [] }
        let mid = (b.minWidth + b.maxWidth) / 2
        var w = mid
        var out: [CGFloat] = [mid]
        for i in 1..<s.count {
            let dt = max(s[i].time - s[i - 1].time, 1.0 / 480)
            let target: CGFloat
            if let f = s[i].force {
                target = b.minWidth + (b.maxWidth - b.minWidth) * max(0, min(1, f))
            } else {
                let v = gap(s[i - 1].point, s[i].point) / CGFloat(dt)
                let span = max(b.fastSpeed - b.slowSpeed, 1)
                let k = max(0, min(1, (v - b.slowSpeed) / span))
                target = b.maxWidth - (b.maxWidth - b.minWidth) * k
            }
            let a = CGFloat(1 - exp(-dt / max(b.smoothing, 0.001)))
            w += a * (target - w)
            w = max(b.minWidth, min(b.maxWidth, w))
            out.append(w)
        }
        return out
    }

    /// Samples at least `minGap` apart (with their widths), keeping the first and the true end.
    static func thin(_ pts: [CGPoint], _ ws: [CGFloat], minGap: CGFloat) -> (points: [CGPoint], widths: [CGFloat]) {
        guard let first = pts.first, ws.count == pts.count else { return ([], []) }
        var p: [CGPoint] = [first]
        var w: [CGFloat] = [ws[0]]
        for i in 1..<pts.count {
            let d = gap(p[p.count - 1], pts[i])
            if d >= minGap {
                p.append(pts[i]); w.append(ws[i])
            } else if i == pts.count - 1 && d > 0 {
                // the true end, not a sample just short of it
                if p.count > 1 { p[p.count - 1] = pts[i]; w[w.count - 1] = ws[i] } else { p.append(pts[i]); w.append(ws[i]) }
            }
        }
        return (p, w)
    }

    /// A point on the centripetal Catmull-Rom curve from p1 to p2 (t in 0...1). The
    /// centripetal kind never loops or cusps between samples, unlike the uniform one.
    static func catmullRom(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ t: CGFloat) -> CGPoint {
        func knot(_ a: CGPoint, _ b: CGPoint) -> CGFloat { max(sqrt(gap(a, b)), 1e-4) }
        let t0: CGFloat = 0
        let t1 = t0 + knot(p0, p1)
        let t2 = t1 + knot(p1, p2)
        let t3 = t2 + knot(p2, p3)
        let u = t1 + (t2 - t1) * t
        func lerp(_ a: CGPoint, _ b: CGPoint, _ ta: CGFloat, _ tb: CGFloat) -> CGPoint {
            let s = (u - ta) / (tb - ta)
            return CGPoint(x: a.x + (b.x - a.x) * s, y: a.y + (b.y - a.y) * s)
        }
        let a1 = lerp(p0, p1, t0, t1)
        let a2 = lerp(p1, p2, t1, t2)
        let a3 = lerp(p2, p3, t2, t3)
        let b1 = lerp(a1, a2, t0, t2)
        let b2 = lerp(a2, a3, t1, t3)
        return lerp(b1, b2, t1, t2)
    }

    /// The centre line through the samples as a Catmull-Rom curve, about `spacing` points
    /// apart, the widths carried along linearly. It passes through every sample.
    static func smooth(_ p: [CGPoint], _ w: [CGFloat], spacing: CGFloat) -> (points: [CGPoint], widths: [CGFloat]) {
        guard p.count > 2, w.count == p.count else { return (p, w) }
        let n = p.count
        var out: [CGPoint] = [p[0]]
        var ws: [CGFloat] = [w[0]]
        for i in 0..<(n - 1) {
            // beyond the ends, the neighbour mirrored, so the curve runs straight out of them
            let p0 = i > 0 ? p[i - 1] : CGPoint(x: 2 * p[0].x - p[1].x, y: 2 * p[0].y - p[1].y)
            let p3 = i + 2 < n ? p[i + 2] : CGPoint(x: 2 * p[n - 1].x - p[n - 2].x, y: 2 * p[n - 1].y - p[n - 2].y)
            let steps = max(1, min(16, Int((gap(p[i], p[i + 1]) / max(spacing, 0.5)).rounded(.up))))
            for k in 1...steps {
                let t = CGFloat(k) / CGFloat(steps)
                out.append(k == steps ? p[i + 1] : catmullRom(p0, p[i], p[i + 1], p3, t))
                ws.append(w[i] + (w[i + 1] - w[i]) * t)
            }
        }
        return (out, ws)
    }

    /// The distance along the line to each point.
    static func arcLengths(_ p: [CGPoint]) -> [CGFloat] {
        var out: [CGFloat] = []
        var total: CGFloat = 0
        for i in p.indices {
            if i > 0 { total += gap(p[i - 1], p[i]) }
            out.append(total)
        }
        return out
    }

    /// From `from` at x = 0 up to 1 at x ≥ 1, eased (smoothstep).
    static func ease(_ from: CGFloat, _ x: CGFloat) -> CGFloat {
        let t = max(0, min(1, x))
        return from + (1 - from) * t * t * (3 - 2 * t)
    }

    /// The tapers: the first `startTaper` points widen in from `startTaperFrom`; once lifted,
    /// the last `endTaper` points narrow to `endTaperTo`. (While the finger is down the
    /// end stays full, so the ink under it doesn't thin and swell as it moves.)
    static func taper(_ w: [CGFloat], lengths: [CGFloat], brush b: Brush, lifted: Bool) -> [CGFloat] {
        guard let total = lengths.last, lengths.count == w.count else { return w }
        return w.indices.map { (i: Int) -> CGFloat in
            var k: CGFloat = 1
            if b.startTaper > 0 { k *= ease(b.startTaperFrom, lengths[i] / b.startTaper) }
            if lifted && b.endTaper > 0 { k *= ease(b.endTaperTo, (total - lengths[i]) / b.endTaper) }
            return w[i] * k
        }
    }

    /// The brush's centre line and its final widths, from the raw samples.
    static func brushLine(_ samples: [Sample], brush b: Brush, lifted: Bool) -> (points: [CGPoint], widths: [CGFloat]) {
        guard !samples.isEmpty else { return ([], []) }
        let raw = widths(samples, brush: b)
        let thinned = thin(samples.map(\.point), raw, minGap: b.minSampleGap)
        let line = smooth(thinned.points, thinned.widths, spacing: b.spacing)
        let lengths = arcLengths(line.points)
        // a dot has no length to taper along
        guard (lengths.last ?? 0) >= 1 else { return line }
        return (line.points, taper(line.widths, lengths: lengths, brush: b, lifted: lifted))
    }

    /// A round dab of `steps` points, wound the same way as `outline` (clockwise in
    /// y-up terms, a negative shoelace area), so a non-zero fill adds them up.
    static func disc(_ c: CGPoint, radius r: CGFloat, steps: Int = 16) -> [CGPoint] {
        let n = max(steps, 3)
        return (0..<n).map { (k: Int) -> CGPoint in
            let a = 2 * CGFloat.pi * CGFloat(k) / CGFloat(n)
            return CGPoint(x: c.x + r * cos(a), y: c.y - r * sin(a))
        }
    }

    /// The brush's outline as one closed polygon: the centre line offset half the width to
    /// each side, joined by round caps. One point gives a round dab.
    static func outline(_ p: [CGPoint], _ w: [CGFloat], capSteps: Int = 8) -> [CGPoint] {
        guard let first = p.first, w.count == p.count else { return [] }
        if p.count == 1 { return disc(first, radius: w[0] / 2) }
        let n = p.count
        var tangents: [CGPoint] = []
        var lastT = CGPoint(x: 1, y: 0)
        for i in 0..<n {
            let a = p[max(0, i - 1)], b = p[min(n - 1, i + 1)]
            let d = gap(a, b)
            if d > 1e-6 { lastT = CGPoint(x: (b.x - a.x) / d, y: (b.y - a.y) / d) }
            tangents.append(lastT)
        }
        var left: [CGPoint] = []
        var right: [CGPoint] = []
        for i in 0..<n {
            let t = tangents[i], r = w[i] / 2
            let nx = -t.y, ny = t.x
            left.append(CGPoint(x: p[i].x + nx * r, y: p[i].y + ny * r))
            right.append(CGPoint(x: p[i].x - nx * r, y: p[i].y - ny * r))
        }
        let steps = max(capSteps, 2)
        func cap(_ c: CGPoint, _ t: CGPoint, _ r: CGFloat, forward: Bool) -> [CGPoint] {
            let s: CGFloat = forward ? 1 : -1
            let nx = -t.y * s, ny = t.x * s, tx = t.x * s, ty = t.y * s
            return (1..<steps).map { (k: Int) -> CGPoint in
                let phi = CGFloat.pi * CGFloat(k) / CGFloat(steps)
                return CGPoint(x: c.x + r * (nx * cos(phi) + tx * sin(phi)),
                               y: c.y + r * (ny * cos(phi) + ty * sin(phi)))
            }
        }
        var out = left
        out += cap(p[n - 1], tangents[n - 1], w[n - 1] / 2, forward: true)
        out += right.reversed()
        out += cap(p[0], tangents[0], w[0] / 2, forward: false)
        return out
    }

    /// Where the line turns tighter than the brush is wide, a corner's inner edge folds over
    /// itself: a round dab there keeps it solid.
    static func joints(_ p: [CGPoint], _ w: [CGFloat]) -> [(center: CGPoint, radius: CGFloat)] {
        guard p.count > 2, w.count == p.count else { return [] }
        var out: [(center: CGPoint, radius: CGFloat)] = []
        for i in 1..<(p.count - 1) {
            let v1 = CGPoint(x: p[i].x - p[i - 1].x, y: p[i].y - p[i - 1].y)
            let v2 = CGPoint(x: p[i + 1].x - p[i].x, y: p[i + 1].y - p[i].y)
            let m1 = hypot(v1.x, v1.y), m2 = hypot(v2.x, v2.y)
            guard m1 > 1e-6, m2 > 1e-6 else { continue }
            let c = max(-1, min(1, (v1.x * v2.x + v1.y * v2.y) / (m1 * m2)))
            let turn = acos(c)
            guard turn > 0.05 else { continue }
            // the radius of the turn here, against half the brush
            if min(m1, m2) / turn < w[i] / 2 { out.append((center: p[i], radius: w[i] / 2)) }
        }
        return out
    }

    /// Every polygon of the brush stroke: the outline, then any corner dabs.
    static func brushPolygons(_ samples: [Sample], brush b: Brush, lifted: Bool) -> [[CGPoint]] {
        let line = brushLine(samples, brush: b, lifted: lifted)
        guard !line.points.isEmpty else { return [] }
        var polys = [outline(line.points, line.widths)]
        for j in joints(line.points, line.widths) { polys.append(disc(j.center, radius: j.radius)) }
        return polys
    }

    /// The brush stroke as a path to fill (non-zero winding).
    static func brushPath(_ samples: [Sample], brush b: Brush, lifted: Bool) -> CGPath {
        let path = CGMutablePath()
        for poly in brushPolygons(samples, brush: b, lifted: lifted) where poly.count > 2 {
            path.addLines(between: poly)
            path.closeSubpath()
        }
        return path
    }

    /// The point `distance` along a polyline and the line's direction there (a unit
    /// vector): where a stroke's direction arrow sits. Nil for fewer than two distinct points.
    static func along(_ pts: [CGPoint], distance: CGFloat) -> (point: CGPoint, direction: CGPoint)? {
        guard pts.count > 1 else { return nil }
        var left = max(0, distance)
        var lastDir: CGPoint?
        for i in 1..<pts.count {
            let a = pts[i - 1], b = pts[i]
            let d = gap(a, b)
            guard d > 1e-6 else { continue }
            let dir = CGPoint(x: (b.x - a.x) / d, y: (b.y - a.y) / d)
            lastDir = dir
            if left <= d { return (CGPoint(x: a.x + dir.x * left, y: a.y + dir.y * left), dir) }
            left -= d
        }
        guard let dir = lastDir else { return nil }
        return (pts[pts.count - 1], dir)
    }
}
