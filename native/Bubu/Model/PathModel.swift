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
    /// A scenery piece placed on the page: centred at (x, y), `w` by `h`. `ground`: a panda the
    /// path planted itself, standing on a little patch of the stones' ground.
    struct Piece { let id: Int; let art: String; let x: CGFloat; let y: CGFloat; let w: CGFloat; let h: CGFloat; let flip: Bool; let behind: Bool; var ground: Bool = false }

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
        let (pieces, _) = Self.composed(course, items, xs, W)
        // past the last composed stone, the path plants itself, as the JIC edition did. That
        // doesn't depend on the current lesson, so it's planted once a width (it's the slow part);
        // a current lesson that starts a chapter moves every stone after it down by its START
        // bubble, and the planted pieces from there down move with them
        let planted = Self.planted(course, W)
        var shift: (from: CGFloat, by: CGFloat)?
        if let cur = items.first(where: { $0.lesson.id == current }), cur.chapter != nil, cur.index < planted.ys.count {
            let by = cur.y - planted.ys[cur.index]
            if by != 0 { shift = (planted.ys[cur.index] - Self.gap / 2, by) }
        }
        self.pieces = pieces + planted.pieces.map { p in
            guard let s = shift, p.y + p.h / 2 > s.from else { return p }
            var q = Piece(id: p.id, art: p.art, x: p.x, y: p.y + s.by, w: p.w, h: p.h, flip: p.flip, behind: p.behind)
            q.ground = p.ground
            return q
        }
        pebbles = Self.trail(course, items, xs, mids, sides, W)
    }

    /// The scenery composed in the path editor, anchored to its stone, and the last stone it's on.
    private static func composed(_ course: Course, _ items: [Item], _ xs: [CGFloat], _ W: CGFloat) -> ([Piece], Int) {
        let kx = W / 390
        let byId = Dictionary(uniqueKeysWithValues: items.map { ($0.lesson.id, $0) })
        var pieces: [Piece] = []
        var composedUntil = -1
        for (n, p) in course.data.pathLayout.pieces.enumerated() {
            guard let it = byId[p.stone], let a = course.data.art[p.art] else { continue }
            composedUntil = max(composedUntil, it.index)
            let w = W * p.w / 100, h = w * a.ar
            var cx = xs[it.index] + p.dx * kx
            // a panda or a landmark stands whole on the screen; only the side clusters, drawn
            // to run off their edge, may (a stone nearer the middle than the one it was
            // composed beside would otherwise push it off)
            if a.side == "any" { cx = max(w / 2, min(W - w / 2, cx)) }
            let base = it.y + p.dy
            pieces.append(Piece(id: n, art: p.art, x: cx, y: base - h / 2, w: w, h: h, flip: p.flip, behind: p.behind))
        }
        return (pieces, composedUntil)
    }

    /// The planted scenery for a width, laid out with no current lesson, and the stones' y it
    /// was planted against. Kept, one per width.
    private static func planted(_ course: Course, _ W: CGFloat) -> (pieces: [Piece], ys: [CGFloat]) {
        if let hit = plantedCache.get(W) { return hit }
        let items = layout(course, current: nil)
        let xs = (0..<items.count).map { nodeX($0, W, count: 64) }
        var mids: [Int: CGFloat] = [:], sides: [Int: Bool] = [:]
        for it in items where it.chapter != nil {
            mids[it.index] = bannerMid(it, items: items, current: nil)
            sides[it.index] = bannerOnRight(it, course: course, xs: xs, W: W)
        }
        let (pieces, until) = composed(course, items, xs, W)
        let out = (pieces: bands(course, items, xs, mids, sides, W, composed: pieces, after: until,
                                 firstId: course.data.pathLayout.pieces.count),
                   ys: items.map(\.y))
        plantedCache.set(W, out)
        return out
    }

    /// Plants a width's scenery ahead of time (off the main thread, at launch).
    static func warm(_ course: Course, width W: CGFloat) { _ = planted(course, W) }

    private final class PlantedCache: @unchecked Sendable {
        private var byWidth: [CGFloat: (pieces: [Piece], ys: [CGFloat])] = [:]
        private let lock = NSLock()
        func get(_ W: CGFloat) -> (pieces: [Piece], ys: [CGFloat])? { lock.lock(); defer { lock.unlock() }; return byWidth[W] }
        func set(_ W: CGFloat, _ v: (pieces: [Piece], ys: [CGFloat])) { lock.lock(); byWidth[W] = v; lock.unlock() }
    }
    private static let plantedCache = PlantedCache()

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

    // MARK: automatic scenery

    /* The JIC edition's automatic bands (renderPath in the web app). The path composer's
       arrangement covers five stones on a 390x844 screen; past the last hand-composed
       piece it repeats down the path, one band per five stones. Each band gets a panda
       first, then the template's three slots, each slot rotating through its family so
       the path doesn't repeat. Collisions are judged on where a piece is painted (the
       measured strips in `slabs`), not its bounding box: a piece that would run into a
       stone, a header or other scenery slides up or down the path to the nearest clear
       stretch, then tries the mirrored side, then a little smaller, else is left out. */

    static let bandLessons = 5
    private static let bandTop: CGFloat = 200       // where the first stone sat in the composer
    private static let bandHeight: CGFloat = 844    // the screen the arrangement was composed on

    /// A slot of the composed band, as percentages of the 390x844 screen; `y` is the piece's base.
    private struct Slot { let art: String; let x: CGFloat; let y: CGFloat; let w: CGFloat; let family: [String] }

    /// The JIC edition's families: its choices, so the path matches it band for band.
    private static let landmarks = ["cluster-right-temple", "land-torii", "land-pagoda", "land-pavilion", "land-house", "land-bridge", "land-waterfall", "land-cliff"]
    private static let leftFoliage = ["cluster-left-bamboo", "fol-bamboo", "fol-pine", "fol-blossom", "fol-banana", "fol-oak"]
    private static let rightFoliage = ["cluster-right-bamboo", "fol-bamboo", "fol-pine", "fol-blossom", "fol-banana", "fol-oak"]
    private static let template: [Slot] = [
        Slot(art: "cluster-right-temple", x: 69, y: 35.6, w: 65, family: landmarks),
        Slot(art: "cluster-left-bamboo", x: 26.7, y: 98.2, w: 66, family: leftFoliage),
        Slot(art: "cluster-right-bamboo", x: 98, y: 112, w: 44, family: rightFoliage),
    ]
    /// Where the band's panda stands, and its size (the web's PANDA).
    private static let pandaX: CGFloat = 79.2, pandaY: CGFloat = 50.8, pandaW: CGFloat = 22, pandaAR: CGFloat = 831.0 / 614.0

    /// Where each piece is actually painted: ten strips top to bottom, each the opaque extent
    /// as a fraction of the width. Measured from the artwork (the web's SLABS).
    private static let slabs: [String: [[CGFloat]]] = [
        "cluster-left-bamboo": [[0.0, 0.306], [0.0, 0.346], [0.0, 0.352], [0.0, 0.427], [0.0, 0.499], [0.0, 0.596], [0.0, 0.598], [0.0, 0.605], [0.0, 0.932], [0.0, 1.0]],
        "cluster-left-waterfall": [[0.0, 0.307], [0.0, 0.378], [0.0, 0.505], [0.0, 0.465], [0.0, 0.39], [0.0, 0.5], [0.0, 0.594], [0.0, 0.704], [0.0, 0.967], [0.0, 0.999]],
        "cluster-left-bridge": [[0.0, 0.285], [0.0, 0.511], [0.0, 0.511], [0.0, 0.52], [0.0, 0.478], [0.0, 0.532], [0.0, 0.69], [0.0, 0.913], [0.0, 0.95], [0.0, 1.0]],
        "cluster-left-steps": [[0.0, 0.309], [0.0, 0.481], [0.0, 0.512], [0.0, 0.373], [0.0, 0.462], [0.0, 0.524], [0.0, 0.595], [0.0, 0.772], [0.0, 0.962], [0.0, 1.0]],
        "land-bridge-red": [[0.129, 0.74], [0.09, 0.763], [0.041, 0.856], [0.041, 0.888], [0.088, 0.958], [0.057, 0.991], [0.007, 0.998], [0.0, 0.998], [0.006, 1.0], [0.073, 0.949]],
        "land-pavilion-pond": [[0.447, 0.659], [0.38, 0.698], [0.239, 0.864], [0.139, 0.862], [0.098, 0.879], [0.091, 0.94], [0.061, 0.977], [0.017, 0.998], [0.0, 1.0], [0.122, 0.924]],
        "land-hall": [[0.585, 0.75], [0.177, 0.776], [0.101, 0.874], [0.063, 0.899], [0.028, 0.916], [0.031, 0.965], [0.043, 0.989], [0.006, 0.998], [0.0, 0.999], [0.01, 0.966]],
        "cluster-right-temple": [[0.735, 1.0], [0.641, 1.0], [0.423, 1.0], [0.332, 1.0], [0.278, 1.0], [0.185, 1.0], [0.06, 1.0], [0.0, 1.0], [0.149, 1.0], [0.48, 1.0]],
        "cluster-right-bamboo": [[0.718, 0.989], [0.668, 1.0], [0.618, 1.0], [0.638, 1.0], [0.707, 1.0], [0.627, 1.0], [0.618, 1.0], [0.449, 1.0], [0.38, 1.0], [0.0, 1.0]],
        "panda-walking": [[0.143, 0.893], [0.117, 0.926], [0.131, 0.986], [0.119, 0.995], [0.048, 0.969], [0.0, 0.995], [0.0, 1.0], [0.067, 0.8], [0.045, 0.94], [0.048, 0.94]],
        "fol-bamboo": [[0.081, 0.433], [0.0, 0.473], [0.0, 0.544], [0.0, 0.528], [0.0, 0.576], [0.0, 0.57], [0.0, 0.5], [0.0, 0.746], [0.0, 0.878], [0.0, 1.0]],
        "fol-pine": [[0.011, 0.375], [0.0, 0.569], [0.0, 0.618], [0.0, 0.759], [0.0, 0.768], [0.0, 0.506], [0.0, 0.536], [0.0, 0.718], [0.0, 0.943], [0.0, 1.0]],
        "fol-blossom": [[0.005, 0.335], [0.0, 0.463], [0.0, 0.728], [0.0, 0.817], [0.0, 0.667], [0.0, 0.618], [0.0, 0.434], [0.0, 0.669], [0.0, 0.712], [0.0, 1.0]],
        "fol-banana": [[0.235, 0.434], [0.014, 0.418], [0.014, 0.676], [0.0, 0.646], [0.0, 0.716], [0.0, 0.717], [0.0, 0.58], [0.0, 0.747], [0.0, 0.899], [0.0, 1.0]],
        "land-torii": [[0.587, 0.791], [0.161, 0.919], [0.175, 0.948], [0.209, 1.0], [0.213, 0.999], [0.097, 0.937], [0.046, 0.93], [0.016, 0.924], [0.012, 0.94], [0.0, 0.94]],
        "land-pagoda": [[0.551, 0.581], [0.49, 0.639], [0.38, 0.885], [0.359, 0.944], [0.215, 0.981], [0.159, 0.989], [0.115, 1.0], [0.06, 0.988], [0.021, 0.993], [0.0, 0.994]],
        "land-pavilion": [[0.545, 0.795], [0.478, 0.918], [0.415, 0.926], [0.129, 0.964], [0.051, 0.958], [0.018, 0.958], [0.022, 0.976], [0.009, 1.0], [0.0, 0.98], [0.056, 0.873]],
        "land-house": [[0.577, 0.798], [0.172, 0.833], [0.149, 0.864], [0.078, 0.924], [0.046, 0.969], [0.033, 1.0], [0.044, 0.998], [0.04, 0.977], [0.0, 0.995], [0.002, 0.995]],
        "fol-oak": [[0.052, 0.425], [0.0, 0.625], [0.016, 0.675], [0.0, 0.782], [0.0, 0.796], [0.0, 0.501], [0.0, 0.552], [0.0, 0.696], [0.0, 0.937], [0.0, 1.0]],
        "land-bridge": [[0.478, 0.821], [0.419, 0.931], [0.365, 0.959], [0.311, 0.976], [0.165, 0.968], [0.105, 0.986], [0.041, 0.988], [0.001, 0.999], [0.0, 0.997], [0.009, 0.893]],
        "land-waterfall": [[0.452, 0.964], [0.341, 1.0], [0.294, 1.0], [0.296, 1.0], [0.261, 1.0], [0.167, 1.0], [0.11, 1.0], [0.046, 1.0], [0.0, 1.0], [0.269, 1.0]],
        "grass-1": [[0.167, 0.309], [0.189, 0.394], [0.215, 0.454], [0.0, 0.994], [0.022, 0.984], [0.102, 0.904], [0.169, 0.843], [0.032, 1.0], [0.084, 0.976], [0.163, 0.845]],
        "grass-2": [[0.194, 0.305], [0.224, 0.364], [0.25, 0.732], [0.271, 0.702], [0.29, 0.663], [0.0, 0.632], [0.054, 1.0], [0.091, 0.897], [0.076, 0.792], [0.151, 0.729]],
        "grass-3": [[0.168, 0.344], [0.213, 0.434], [0.255, 0.934], [0.29, 0.922], [0.317, 0.863], [0.078, 0.818], [0.0, 0.785], [0.137, 1.0], [0.164, 0.92], [0.228, 0.858]],
        "land-cliff": [[0.0, 0.287], [0.0, 0.367], [0.0, 0.372], [0.0, 0.405], [0.0, 0.537], [0.0, 0.588], [0.0, 0.683], [0.0, 0.758], [0.0, 0.915], [0.0, 1.0]],
        "panda-celebrate": [[0.17, 0.952], [0.059, 0.947], [0.061, 1.0], [0.065, 0.984], [0.0, 0.972], [0.089, 0.986], [0.212, 0.851], [0.218, 0.838], [0.242, 0.79], [0.291, 0.505]],
        "panda-idle": [[0.077, 0.914], [0.077, 0.912], [0.107, 0.893], [0.107, 0.893], [0.118, 0.954], [0.035, 0.998], [0.0, 1.0], [0.002, 0.979], [0.167, 0.824], [0.139, 0.856]],
        "panda-peek": [[0.139, 0.728], [0.06, 0.734], [0.052, 0.728], [0.056, 0.954], [0.11, 0.998], [0.1, 1.0], [0.1, 0.996], [0.102, 0.975], [0.023, 0.942], [0.0, 0.888]],
        "panda-sad": [[0.188, 0.816], [0.107, 0.897], [0.109, 0.897], [0.135, 0.84], [0.137, 0.893], [0.176, 0.911], [0.145, 0.927], [0.014, 0.99], [0.0, 1.0], [0.012, 0.986]],
        "panda-teacher": [[0.036, 0.62], [0.008, 0.994], [0.026, 1.0], [0.073, 0.923], [0.032, 0.899], [0.006, 0.824], [0.0, 0.691], [0.032, 0.691], [0.119, 0.683], [0.081, 0.733]],
        "panda-waving": [[0.087, 0.741], [0.077, 0.939], [0.123, 1.0], [0.123, 0.998], [0.032, 0.956], [0.004, 0.838], [0.0, 0.78], [0.046, 0.78], [0.182, 0.78], [0.152, 0.808]],
        "panda-reading": [[0.054, 0.892], [0.052, 0.89], [0.11, 0.871], [0.104, 0.876], [0.116, 0.959], [0.035, 0.985], [0.0, 1.0], [0.002, 0.985], [0.015, 0.988], [0.033, 0.969]],
        "panda-baozi": [[0.088, 0.865], [0.066, 0.865], [0.088, 0.864], [0.125, 0.869], [0.131, 0.891], [0.133, 0.943], [0.103, 0.969], [0.045, 0.969], [0.0, 1.0], [0.002, 0.994]],
        "panda-writing": [[0.277, 0.805], [0.277, 0.818], [0.248, 0.8], [0.248, 0.777], [0.209, 0.838], [0.186, 0.891], [0.098, 0.918], [0.002, 0.998], [0.0, 1.0], [0.035, 0.968]],
        "panda-listening": [[0.05, 0.721], [0.029, 0.891], [0.09, 1.0], [0.003, 0.967], [0.0, 0.888], [0.01, 0.913], [0.093, 0.922], [0.01, 0.933], [0.002, 0.927], [0.026, 0.843]],
        "panda-puzzled": [[0.331, 1.0], [0.036, 0.96], [0.036, 0.882], [0.002, 0.806], [0.0, 0.832], [0.034, 0.876], [0.192, 0.896], [0.184, 0.89], [0.188, 0.776], [0.152, 0.824]],
        "panda-sleeping": [[0.288, 0.583], [0.091, 0.655], [0.0, 0.9], [0.086, 0.886], [0.083, 0.809], [0.134, 0.878], [0.122, 0.905], [0.063, 0.935], [0.043, 0.992], [0.097, 1.0]],
    ]

    /// A rectangle on the page, by its edges.
    private struct Box {
        let x0: CGFloat, x1: CGFloat, y0: CGFloat, y1: CGFloat
        var header = false
        func overlaps(_ b: Box, pad: CGFloat) -> Bool {
            x0 < b.x1 + pad && x1 > b.x0 - pad && y0 < b.y1 + pad && y1 > b.y0 - pad
        }
    }
    /// Scenery already planted: its whole box, checked first, and the strips it paints.
    private struct Claim { let box: Box; let strips: [Box] }

    /// Things filed by the stretch of page they cover, so a search looks only near itself
    /// and planting the whole path stays linear in its length.
    private struct Grid<T> {
        static var cell: CGFloat { 256 }
        private var cells: [Int: [T]] = [:]
        mutating func add(_ t: T, _ y0: CGFloat, _ y1: CGFloat) {
            for c in Self.span(y0, y1) { cells[c, default: []].append(t) }
        }
        /// Everything filed anywhere in y0…y1 (something spanning two cells comes back twice,
        /// which a collision check doesn't mind).
        func near(_ y0: CGFloat, _ y1: CGFloat) -> [T] {
            var out: [T] = []
            for c in Self.span(y0, y1) { if let ts = cells[c] { out.append(contentsOf: ts) } }
            return out
        }
        private static func span(_ y0: CGFloat, _ y1: CGFloat) -> ClosedRange<Int> {
            Int(floor(y0 / cell))...Int(floor(max(y0, y1) / cell))
        }
    }

    /// The strips a piece paints when its top-left is at (x0, y0), mirrored if flipped.
    private static func strips(_ art: String, _ x0: CGFloat, _ y0: CGFloat, _ w: CGFloat, _ h: CGFloat, _ mirrored: Bool) -> [Box] {
        guard let sl = slabs[art], !sl.isEmpty else { return [Box(x0: x0, x1: x0 + w, y0: y0, y1: y0 + h)] }
        let n = CGFloat(sl.count)
        return sl.enumerated().map { r, sb in
            let l = mirrored ? 1 - sb[1] : sb[0], rr = mirrored ? 1 - sb[0] : sb[1]
            return Box(x0: x0 + l * w, x1: x0 + rr * w, y0: y0 + h * CGFloat(r) / n, y1: y0 + h * CGFloat(r + 1) / n)
        }
    }

    /// Plants scenery clear of the stones, the headers and what's already planted (the web's
    /// fits / settle / claim). The template was composed with foliage touching the stones, so
    /// stones get no margin; header text and other scenery get a little.
    private struct Planter {
        static var stonePad: CGFloat { 0 }
        static var headerPad: CGFloat { 4 }
        static var sceneryPad: CGFloat { 4 }
        let obstacles: Grid<Box>
        let top: CGFloat, end: CGFloat
        private var taken = Grid<Claim>()

        init(obstacles: Grid<Box>, top: CGFloat, end: CGFloat) {
            self.obstacles = obstacles; self.top = top; self.end = end
        }

        /// The composed spot first, then stepping away from it down and up the path, 12 points
        /// at a time, as far as `reach`. The base it settles on, or nil if nowhere is clear.
        /// `asComposed`: only the stones and headers can turn it away.
        func settle(_ art: String, _ cx: CGFloat, _ base: CGFloat, _ w: CGFloat, _ h: CGFloat, _ mirrored: Bool,
                    reach: CGFloat, asComposed: Bool = false) -> CGFloat? {
            let pad = Planter.headerPad + Planter.sceneryPad
            let lo = base - h - reach - pad, hi = base + reach + pad
            let obs = obstacles.near(lo, hi)
            let tk = asComposed ? [] : taken.near(lo, hi)
            let shape = PathModel.strips(art, 0, 0, w, h, mirrored)
            var d: CGFloat = 0
            while d <= reach {
                let signs: [CGFloat] = d > 0 ? [1, -1] : [1]
                for sgn in signs {
                    let y0 = base - h + sgn * d
                    if fits(shape, cx - w / 2, y0, w, h, obs, tk) { return y0 + h }
                }
                d += 12
            }
            return nil
        }

        private func fits(_ shape: [Box], _ x0: CGFloat, _ y0: CGFloat, _ w: CGFloat, _ h: CGFloat, _ obs: [Box], _ tk: [Claim]) -> Bool {
            if y0 < top || y0 + h > end { return false }
            let whole = Box(x0: x0, x1: x0 + w, y0: y0, y1: y0 + h)
            for o in obs {
                let pad = o.header ? Planter.headerPad : Planter.stonePad
                guard whole.overlaps(o, pad: pad) else { continue }
                for s in shape where Box(x0: s.x0 + x0, x1: s.x1 + x0, y0: s.y0 + y0, y1: s.y1 + y0).overlaps(o, pad: pad) { return false }
            }
            for t in tk {
                guard whole.overlaps(t.box, pad: Planter.sceneryPad) else { continue }
                for s in shape {
                    let sp = Box(x0: s.x0 + x0, x1: s.x1 + x0, y0: s.y0 + y0, y1: s.y1 + y0)
                    for ts in t.strips where sp.overlaps(ts, pad: Planter.sceneryPad) { return false }
                }
            }
            return true
        }

        /// Marks where a piece, standing on `base`, paints.
        mutating func claim(_ art: String, _ cx: CGFloat, _ base: CGFloat, _ w: CGFloat, _ h: CGFloat, _ mirrored: Bool) {
            let x0 = cx - w / 2, y0 = base - h
            taken.add(Claim(box: Box(x0: x0, x1: x0 + w, y0: y0, y1: y0 + h),
                            strips: PathModel.strips(art, x0, y0, w, h, mirrored)), y0, base)
        }
    }

    /// The automatic scenery, one band per five stones after the last composed one.
    private static func bands(_ course: Course, _ items: [Item], _ xs: [CGFloat], _ mids: [Int: CGFloat], _ sides: [Int: Bool],
                              _ W: CGFloat, composed: [Piece], after composedUntil: Int, firstId: Int) -> [Piece] {
        guard let last = items.last, composedUntil < items.count - 1 else { return [] }
        let art = course.data.art
        // everything scenery keeps out of: the stones, and the headers, each on its own side
        var obstacles = Grid<Box>()
        for it in items {
            let x = xs[it.index], hw = size * stoneRatio / 2
            obstacles.add(Box(x0: x - hw, x1: x + hw, y0: it.y - size / 2, y1: it.y + size / 2), it.y - size / 2, it.y + size / 2)
            if it.chapter != nil, let mid = mids[it.index] {
                let right = sides[it.index] ?? false
                obstacles.add(Box(x0: right ? W * 0.38 : 0, x1: right ? W : W * 0.62, y0: mid - bannerH / 2, y1: mid + bannerH / 2, header: true),
                              mid - bannerH / 2, mid + bannerH / 2)
            }
        }
        // nothing under the HUD, nothing below the last stone
        var planter = Planter(obstacles: obstacles, top: hud + 8, end: last.y + size * 0.9)
        for c in composed { planter.claim(c.art, c.x, c.y + c.h / 2, c.w, c.h, c.flip) }

        let scale = gap / 143                        // the spacing it was composed at
        var out: [Piece] = []
        for b in 0...((items.count - 1) / bandLessons) {
            let first = b * bandLessons
            if first <= composedUntil { continue }   // composed by hand: leave it be
            let anchor = items[first].y - bandTop * scale
            let span = bandHeight * scale

            // The panda goes first: it matters more than the planting. As composed if that's
            // clear, otherwise beside one of the band's stones, on the open side, about a
            // stone's width away from it.
            if art["panda-walking"] != nil {
                let pw = W * pandaW / 100, ph = pw * pandaAR
                let tx = W * pandaX / 100, tb = anchor + bandHeight * pandaY / 100 * scale
                var spot: (x: CGFloat, base: CGFloat)?
                if let y = planter.settle("panda-walking", tx, tb, pw, ph, tx > W / 2, reach: b == 0 ? 0 : gap * 0.5, asComposed: b == 0)
                    ?? planter.settle("panda-walking", tx, tb, pw, ph, tx > W / 2, reach: gap * 0.5) {
                    spot = (tx, y)
                } else {
                    for k in [1, 3, 0, 2, 4] {
                        let i = first + k
                        guard i < items.count else { continue }
                        let side: CGFloat = xs[i] < W / 2 ? 1 : -1
                        let edge = xs[i] + side * size * stoneRatio / 2
                        let cx = max(pw / 2 + 4, min(W - pw / 2 - 4, edge + side * (size * 0.9 + pw / 2)))
                        if abs(cx - edge) - pw / 2 < size * 0.4 { continue }      // too tight a fit
                        if let yb = planter.settle("panda-walking", cx, items[i].y + size * 1.16, pw, ph, cx > W / 2, reach: gap * 0.35) {
                            spot = (cx, yb); break
                        }
                    }
                }
                if let s = spot {
                    out.append(Piece(id: firstId + out.count, art: "panda-walking", x: s.x, y: s.base - ph / 2, w: pw, h: ph,
                                     flip: s.x > W / 2, behind: false, ground: true))
                    planter.claim("panda-walking", s.x, s.base, pw, ph, s.x > W / 2)
                }
            }

            for (k, slot) in template.enumerated() {
                let base = anchor + bandHeight * slot.y / 100 * scale
                // the first band is the template as composed; after that each slot rotates
                // through its family, the two foliage slots out of step
                let name = b == 0 ? slot.art : slot.family[(b * 5 + k * 7) % slot.family.count]
                guard let a = art[name] else { continue }
                let aw = CGFloat(a.w), ar = CGFloat(a.ar), standsWhole = a.side == "any"
                let slotRight = slot.x > 50
                var cw: CGFloat = 0, ch: CGFloat = 0, cx: CGFloat = 0, flipped = false
                var y: CGFloat?
                if b == 0 {                              // exactly as composed, if the stones allow
                    cw = W * aw / 100; ch = cw * ar; cx = W * slot.x / 100
                    y = planter.settle(name, cx, base, cw, ch, false, reach: 0, asComposed: true)
                }
                // full size on the composed side, then mirrored, then a little smaller,
                // anywhere in the band
                if y == nil {
                    search: for s in [1, 0.85, 0.72] as [CGFloat] {
                        cw = W * aw / 100 * s; ch = cw * ar
                        for mirrored in [false, true] {
                            // the slot's outer edge stays where it was composed, so a piece in
                            // it keeps the same overhang off the side of the screen
                            let full = W * slot.w / 100, x0 = W * slot.x / 100
                            let outer = slotRight ? x0 + full / 2 - cw / 2 : x0 - full / 2 + cw / 2
                            cx = mirrored ? W - outer : outer
                            // a landmark stands whole on the screen, as the composed ones do
                            if standsWhole { cx = max(cw / 2, min(W - cw / 2, cx)) }
                            let onRight = slotRight != mirrored
                            flipped = standsWhole ? mirrored : (onRight != (a.side == "right"))
                            y = planter.settle(name, cx, base, cw, ch, flipped, reach: span * 0.6)
                            if y != nil { break search }
                        }
                    }
                }
                guard let yb = y else { continue }         // no room for it in this band
                out.append(Piece(id: firstId + out.count, art: name, x: cx, y: yb - ch / 2, w: cw, h: ch, flip: flipped, behind: true))
                planter.claim(name, cx, yb, cw, ch, flipped)
            }
        }
        return out
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
