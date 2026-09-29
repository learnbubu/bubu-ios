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
