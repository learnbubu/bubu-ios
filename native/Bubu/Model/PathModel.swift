import CoreGraphics
import Foundation
#if DEBUG
import os
#endif

/// Where everything on the learning path goes, worked out once for a screen width
/// and a current lesson: the stones, the chapter headers, the scenery and the
/// pebble trail. The path only reads it, so moving between tabs, or any change to
/// the store that doesn't finish a lesson, costs no layout work. Same geometry as
/// the web app's phone layout (PATH_CFG.phone).
struct PathModel {
    // the web app's phone layout (PATH_CFG.phone)
    static let size: CGFloat = 74, gap: CGFloat = 143, wave: CGFloat = 106, per: CGFloat = 8, phase: CGFloat = 6
    static let hud: CGFloat = 62, bannerH: CGFloat = 72, hgap: CGFloat = 36, bubble: CGFloat = 40, pad: CGFloat = 170
    static let stoneRatio: CGFloat = 1.62

    // scenery constants, from the path composer (SC in the web app)
    static let patchW: CGFloat = 1.20, patchSquash: CGFloat = 0.66
    static let pebEvery: CGFloat = 9.2, pebSize: CGFloat = 11, pebVar: CGFloat = 0.63
    static let pebWander: CGFloat = 31, pebClear: CGFloat = 4

    struct Item { let lesson: Lesson; let index: Int; let chapter: Int?; let y: CGFloat }
    struct Pebble { let x: CGFloat; let y: CGFloat; let w: CGFloat }
    /// One stretch of the trail, drawn as one canvas.
    struct PebbleGroup { let key: Int; let pebbles: [Pebble]; let top: CGFloat; let bottom: CGFloat }
    /// A scenery piece placed on the page: centred at (x, y), `w` by `h`.
    struct Piece { let id: Int; let art: String; let x: CGFloat; let y: CGFloat; let w: CGFloat; let h: CGFloat; let flip: Bool; let behind: Bool }

    let width: CGFloat
    let current: String?
    let items: [Item]
    /// each stone's x, by index
    let xs: [CGFloat]
    /// where each chapter header is centred, by the index of its first stone
    let bannerMids: [Int: CGFloat]
    /// which side each chapter header sits on, by the index of its first stone: the banner
    /// and the pebble trail (which keeps clear of it) must agree
    let bannerRight: [Int: Bool]
    let pieces: [Piece]
    let pebbles: [PebbleGroup]
    let height: CGFloat
    /// the current stone's y (0 when every lesson is done)
    let currentY: CGFloat

    init(course: Course, width W: CGFloat, current: String?) {
        self.width = W
        self.current = current
        let items = Self.layout(course, current: current)
        self.items = items
        let xs = (0..<items.count).map { Self.nodeX($0, W, count: 64) }
        self.xs = xs
        height = (items.last?.y ?? 0) + Self.pad
        currentY = items.first { $0.lesson.id == current }?.y ?? 0
        var mids: [Int: CGFloat] = [:]
        var sides: [Int: Bool] = [:]
        for it in items where it.chapter != nil {
            mids[it.index] = Self.bannerMid(it, items: items, current: current)
            sides[it.index] = Self.bannerOnRight(it, course: course, xs: xs, W: W)
        }
        bannerMids = mids
        bannerRight = sides
        // the scenery composed in the path editor, anchored to its stone
        let kx = W / 390
        let byId = Dictionary(uniqueKeysWithValues: items.map { ($0.lesson.id, $0) })
        var pieces: [Piece] = []
        for (n, p) in course.data.pathLayout.pieces.enumerated() {
            guard let it = byId[p.stone], let a = course.data.art[p.art] else { continue }
            let w = W * p.w / 100, h = w * a.ar
            var cx = xs[it.index] + p.dx * kx
            // a panda or a landmark stands whole on the screen; only the side clusters, drawn
            // to run off their edge, may (a stone nearer the middle than the one it was
            // composed beside would otherwise push it off)
            if a.side == "any" { cx = max(w / 2, min(W - w / 2, cx)) }
            let base = it.y + p.dy
            pieces.append(Piece(id: n, art: p.art, x: cx, y: base - h / 2, w: w, h: h, flip: p.flip, behind: p.behind))
        }
        self.pieces = pieces
        pebbles = Self.trail(course, items, xs, mids, sides, W)
    }

    // MARK: geometry

    private static func layout(_ course: Course, current: String?) -> [Item] {
        var items: [Item] = [], y: CGFloat = 0, i = 0
        let bub = { (id: String) -> CGFloat in id == current ? bubble : 0 }
        for (ci, ch) in course.chapters.enumerated() {
            for (li, id) in ch.lessons.enumerated() {
                guard let lesson = course.lessonById[id] else { continue }
                if i == 0 { y = hud + 16 + bannerH + bub(id) + size / 2 }
                else if li == 0 { y += hgap + bannerH + bub(id) }
                items.append(Item(lesson: lesson, index: i, chapter: li == 0 ? ci : nil, y: y))
                y += gap; i += 1
            }
        }
        return items
    }

    /// The wave's peak over one period, for normalising it (the same for every stone).
    private static let waveNorm: CGFloat = {
        var k: CGFloat = 0
        for j in 0..<Int(per) { k = max(k, abs(sin(CGFloat(j) * 2 * .pi / per))) }
        return k < 1e-6 ? 1 : k
    }()

    static func nodeX(_ i: Int, _ W: CGFloat, count: Int) -> CGFloat {
        var k: CGFloat = waveNorm
        if count < Int(per) {
            k = 0
            for j in 0..<count { k = max(k, abs(sin(CGFloat(j) * 2 * .pi / per))) }
            if k < 1e-6 { k = 1 }
        }
        let half = size / 2 + 8
        return max(half, min(W - half, W / 2 + wave * sin((CGFloat(i) + phase) * 2 * .pi / per) / k))
    }

    /// Where a chapter header is centred: halfway between the stone above
    /// (or the HUD) and the top of its first stone, START bubble included.
    private static func bannerMid(_ it: Item, items: [Item], current: String?) -> CGFloat {
        let top = it.y - size / 2 - (it.lesson.id == current ? bubble : 0)
        let prev = it.index == 0 ? hud : items[it.index - 1].y + size / 2
        return (prev + top) / 2
    }

    /// A chapter header's side: as composed in the path editor, else across from the stones
    /// around it (right when they lean left).
    static func bannerOnRight(_ it: Item, course: Course, xs: [CGFloat], W: CGFloat) -> Bool {
        if let s = course.data.pathLayout.headers[it.lesson.id] { return s == "right" }
        return it.index > 0 && (xs[it.index - 1] + xs[it.index]) / 2 < W / 2
    }

    /// The web app's hash noise, -1…1.
    private static func noise(_ n: Double) -> CGFloat {
        let v = sin(n * 12.9898) * 43758.5453
        return CGFloat((v - floor(v)) * 2 - 1)
    }

    /// The pebble trail, laid exactly as the web app lays it: a fixed density along a
    /// smooth walk through the stones, wandering either side, and dropped wherever
    /// it would land on a stone or under a chapter header. Grouped one stretch
    /// between two stones at a time, so no single canvas is the height of the course.
    private static func trail(_ course: Course, _ items: [Item], _ x: [CGFloat], _ mids: [Int: CGFloat], _ sides: [Int: Bool], _ W: CGFloat) -> [PebbleGroup] {
        guard items.count > 1 else { return [] }
        let ys = items.map(\.y)
        let unit = size / 74
        func curve(_ t: CGFloat) -> (i: Int, x: CGFloat, y: CGFloat) {
            let f = t * CGFloat(ys.count - 1)
            let i = max(0, min(ys.count - 2, Int(floor(f))))
            var u = f - CGFloat(i); u = u * u * (3 - 2 * u)
            return (i, x[i] + (x[i + 1] - x[i]) * u, ys[i] + (ys[i + 1] - ys[i]) * u)
        }
        // headers, each on its own side of the page
        var headers: [Int: CGRect] = [:]
        for it in items where it.chapter != nil {
            let mid = mids[it.index] ?? 0
            let right = sides[it.index] ?? false
            headers[it.index] = CGRect(x: right ? W * 0.38 : 0, y: mid - bannerH / 2, width: W * 0.62, height: bannerH)
        }
        let halfW = size * stoneRatio / 2 + pebClear * unit, halfH = size / 2 + pebClear * unit
        let count = max(0, Int(((ys[ys.count - 1] - ys[0]) / (pebEvery * unit)).rounded()))
        var out: [Int: [Pebble]] = [:]
        for n in stride(from: 1, through: count, by: 1) {
            let t = CGFloat(n) / CGFloat(count + 1)
            let p = curve(t), q = curve(min(1, t + 0.002))
            let dx = q.x - p.x, dy = q.y - p.y, len = max(hypot(dx, dy), 1e-9)
            let off = pebWander * unit * noise(Double(n) * 1.7)
            let w = pebSize * unit * (1 + pebVar * noise(Double(n) * 4.3))
            let bx = p.x - dy / len * off, by = p.y + dx / len * off
            var hidden = false
            for i in max(0, p.i - 1)...min(ys.count - 1, p.i + 2) {
                let ex = (bx - x[i]) / (halfW + w / 2), ey = (by - ys[i]) / (halfH + w / 2)
                if ex * ex + ey * ey < 1 { hidden = true; break }
                if let h = headers[i], bx > h.minX - w, bx < h.maxX + w, by > h.minY - w, by < h.maxY + w { hidden = true; break }
            }
            if !hidden { out[p.i, default: []].append(Pebble(x: bx, y: by, w: w)) }
        }
        return out.keys.sorted().map { k in
            let peb = out[k]!
            return PebbleGroup(key: k, pebbles: peb, top: (peb.map(\.y).min() ?? 0) - 10, bottom: (peb.map(\.y).max() ?? 0) + 10)
        }
    }

    // MARK: what's near the screen

    /// The path is drawn only near what's on screen: the scroll offset is rounded
    /// to bands this tall, so the drawn set changes a few times a screen, not every frame.
    static let bandH: CGFloat = 400
    static func band(for offset: CGFloat) -> Int { Int(floor(max(0, offset) / bandH)) }

    /// The stretch of the page to draw for a band, with a screen and a half to spare
    /// either side so a quick flick never reaches the edge before the next band lands.
    static func window(band: Int, viewport H: CGFloat) -> ClosedRange<CGFloat> {
        let top = CGFloat(band) * bandH
        return (top - 1.5 * H)...(top + bandH + 2.5 * H)
    }

    /// The band that puts the current stone mid-screen, where the path first lands.
    func landingBand(viewport H: CGFloat) -> Int { current == nil ? 0 : Self.band(for: currentY - H / 2) }

    /// Stones, with their headers and ground, that reach into the window. A header
    /// sits up to a gap above its stone; the glow and START bubble reach ~120 above.
    func items(in r: ClosedRange<CGFloat>) -> [Item] {
        items.filter { $0.y + 160 >= r.lowerBound && $0.y - Self.gap - 160 <= r.upperBound }
    }
    func pieces(in r: ClosedRange<CGFloat>, behind: Bool) -> [Piece] {
        pieces.filter { $0.behind == behind && $0.y + $0.h / 2 >= r.lowerBound && $0.y - $0.h / 2 <= r.upperBound }
    }
    func pebbles(in r: ClosedRange<CGFloat>) -> [PebbleGroup] {
        pebbles.filter { $0.bottom >= r.lowerBound && $0.top <= r.upperBound }
    }

    /// Keeps the last model, so it's rebuilt only when the width or the current lesson changes.
    final class Cache {
        private var model: PathModel?
        private(set) var builds = 0
        func model(_ course: Course, width: CGFloat, current: String?) -> PathModel {
            if let m = model, m.width == width, m.current == current { return m }
            #if DEBUG
            let t0 = CFAbsoluteTimeGetCurrent()
            #endif
            let m = PathModel(course: course, width: width, current: current)
            #if DEBUG
            let ms = (CFAbsoluteTimeGetCurrent() - t0) * 1000
            Logger(subsystem: "com.bubu", category: "perf")
                .debug("path model built in \(ms, format: .fixed(precision: 1)) ms: \(m.items.count) stones, \(m.pebbles.count) pebble groups")
            #endif
            model = m
            builds += 1
            return m
        }
    }
}
