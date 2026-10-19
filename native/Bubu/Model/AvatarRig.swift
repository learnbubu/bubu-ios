import Foundation

/// An avatar made in Bùbù Studio and exported for the app ("App avatar"): its parts (pictures with bend grids, bound to
/// bones), its light, and every animation baked a frame at a time (each bone's move from rest, each part's opacity).
/// The player bends each part by its bones and draws them bottom up, shaded in the light, as Studio draws them.
struct AvatarRig: Decodable {
    /// a lamp; one after the first falls only on its parts (`only`), there instead of the first or as well
    struct Light: Decodable { let x: Float; let y: Float; let distance: Float; let strength: Float; let softness: Float; var only: [Int]? = nil; var instead: Bool? = nil }
    /// points with their bones: x y pairs where they rest, four bones each (-1 none) and how much each pulls
    struct Points: Decodable { let verts: [Float]; let bones: [Int]; let weights: [Float] }
    struct Part: Decodable {
        let name: String
        /// its picture (a png in the bundle), and its grid: points where they rest (document units, x y pairs), the
        /// picture's place at each, and triangles
        let tex: String
        let verts: [Float]
        let uvs: [Float]
        let tris: [UInt32]
        /// four bones a point (an index into `bones`, -1 none) and how much each pulls it
        let bones: [Int]
        let weights: [Float]
        /// the whole bend grid's outline (only the cells round the picture are drawn): a shadow is moved away from the
        /// light from its middle, as in Studio
        let edge: Points?
        /// in the light: whether it throws a shadow, whether shadows fall on it, the parts its shadow never falls on
        /// (they meet at a joint), the parts in its shadow's way wherever they are, and a part it's shaded as (-1 none)
        let cast: Bool
        let receive: Bool
        let skip: [Int]
        let block: [Int]
        /// parts under it whose shadows fall on it all the same (a sleeve drawn under a belly)
        var from: [Int]? = nil
        let `as`: Int
    }
    /// a colour the learner chooses (hair, skin, a sweater's): the parts it recolours, its swatches, and each part's
    /// picture in each swatch (tex[swatch][k] for parts[k]; the first swatch is as drawn)
    struct Channel: Decodable { let name: String; let parts: [Int]; let swatches: [String]; let tex: [[String]] }
    struct Anim: Decodable {
        let duration: Double
        let loop: Bool
        let frames: Int
        /// frames × bones × 6 (a b c d e f: x' = a x + c y + e, y' = b x + d y + f)
        let mats: [Float]
        /// frames × parts
        let opacity: [Float]
    }
    let name: String
    let size: [Float]
    let fps: Double
    let bones: [String]
    let light: Light?
    let lights: [Light]?
    let parts: [Part]
    let channels: [Channel]?
    let anims: [String: Anim]

    /// Every lamp (the first first, if it's on), and whether lamp `l` falls on part `i`.
    var lamps: [(light: Light, first: Bool)] { (light.map { [($0, true)] } ?? []) + (lights ?? []).map { ($0, false) } }
    func falls(_ l: (light: Light, first: Bool), on i: Int) -> Bool {
        if l.first { return !(lights ?? []).contains { $0.instead == true && ($0.only ?? []).contains(i) } }
        return l.light.only.map { $0.contains(i) } ?? true
    }

    /// (each read once: changing outfit, or opening the editor, doesn't read it again)
    private static var loaded: [String: AvatarRig] = [:]
    static func load(_ name: String) -> AvatarRig? {
        if let r = loaded[name] { return r }
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url), let r = try? JSONDecoder().decode(AvatarRig.self, from: data) else { return nil }
        loaded[name] = r
        return r
    }

    /// A box in the document (x, y, w, h).
    typealias Box = (x: Float, y: Float, w: Float, h: Float)

    /// The box every outfit is shown in: the one every pose of the everyday outfit fits (all are on its skeleton, in
    /// its document's place), so he's the same size whatever he wears; what's bigger (a hood's horns, a tail) draws
    /// past it, into the stage's bleed.
    static let stageBox: Box = load(Outfit.all[0].id)?.fitAll() ?? (0, 0, 1254, 1454)
    /// Head and shoulders, for an outfit's tile: the same for every outfit, room for the dragon's horns.
    static let tileBox: Box = (168, 104, 922, 922)

    /// The box every pose of every animation fits in, a little room round it.
    func fitAll() -> Box {
        var x0 = Float.greatestFiniteMagnitude, y0 = x0, x1 = -x0, y1 = -x0
        var buf: [Float] = []
        for a in anims.values {
            for f in stride(from: 0, to: a.frames, by: 3) {
                let s = sample(a, at: Double(f) * 1000 / fps)
                for p in parts {
                    points(p, mats: s.mats, into: &buf)
                    for k in stride(from: 0, to: buf.count, by: 2) { x0 = min(x0, buf[k]); x1 = max(x1, buf[k]); y0 = min(y0, buf[k + 1]); y1 = max(y1, buf[k + 1]) }
                }
            }
        }
        guard x1 > x0, y1 > y0 else { return (0, 0, size.first ?? 1, size.last ?? 1) }
        let m = max(x1 - x0, y1 - y0) * 0.03
        return (x0 - m, y0 - m, x1 - x0 + 2 * m, y1 - y0 + 2 * m)
    }

    /// The bones' moves and the parts' opacity `ms` into an animation: between its two nearest frames (opacity steps,
    /// as blinks and swaps do).
    func sample(_ a: Anim, at ms: Double) -> (mats: [Float], opacity: [Float]) {
        let n = a.frames, nb = bones.count, np = parts.count
        var f = ms * fps / 1000
        if a.loop { f = f.truncatingRemainder(dividingBy: Double(n)); if f < 0 { f += Double(n) } } else { f = min(max(f, 0), Double(n - 1)) }
        let i = Int(f), j = a.loop ? (i + 1) % n : min(i + 1, n - 1), u = Float(f - Double(i))
        var mats = [Float](repeating: 0, count: nb * 6)
        for k in 0..<(nb * 6) { mats[k] = a.mats[i * nb * 6 + k] * (1 - u) + a.mats[j * nb * 6 + k] * u }
        let o = u < 0.5 ? i : j
        return (mats, Array(a.opacity[(o * np)..<(o * np + np)]))
    }

    /// A part's points at a pose (document units, x y pairs): each its bones' moves, weighed.
    func points(_ p: Part, mats: [Float], into out: inout [Float]) {
        bend(p.verts, p.bones, p.weights, mats: mats, into: &out)
    }
    func bend(_ verts: [Float], _ bones: [Int], _ weights: [Float], mats: [Float], into out: inout [Float]) {
        let n = verts.count / 2
        if out.count != n * 2 { out = [Float](repeating: 0, count: n * 2) }
        for v in 0..<n {
            let x = verts[v * 2], y = verts[v * 2 + 1]
            var px: Float = 0, py: Float = 0, ws: Float = 0
            for k in 0..<4 {
                let b = bones[v * 4 + k]; if b < 0 { continue }
                let w = weights[v * 4 + k], m = b * 6
                px += w * (mats[m] * x + mats[m + 2] * y + mats[m + 4])
                py += w * (mats[m + 1] * x + mats[m + 3] * y + mats[m + 5])
                ws += w
            }
            if ws < 1e-6 { px = x; py = y }
            out[v * 2] = px; out[v * 2 + 1] = py
        }
    }
}
