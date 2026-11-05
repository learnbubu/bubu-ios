import Foundation

/// An avatar made in Bùbù Studio and exported for the app ("App avatar"): its parts (pictures with bend grids, bound to
/// bones), its light, and every animation baked a frame at a time (each bone's move from rest, each part's opacity).
/// The player bends each part by its bones and draws them bottom up, shaded in the light, as Studio draws them.
///
/// Version 2 (5 Nov 2026, the turnaround Bùbù: puppet-pinned limbs, five views): a part can instead be a `mesh`, its points
/// baked a frame at a time into the animation's `points` file (int16 tenths of a unit: frames x the mesh parts in order x
/// their points x (x, y)); a view not shown is its parts at opacity 0. tools/art/avatar_replay.py plays the same files.
struct AvatarRig: Decodable {
    /// a lamp; one after the first falls only on its parts (`only`), there instead of the first or as well
    struct Light: Decodable { let x: Float; let y: Float; let distance: Float; let strength: Float; let softness: Float; var only: [Int]? = nil; var instead: Bool? = nil }
    /// points with their bones: x y pairs where they rest, four bones each (-1 none) and how much each pulls
    struct Points: Decodable { let verts: [Float]; let bones: [Int]; let weights: [Float] }
    struct Part: Decodable {
        /// "skin" (bent by its bones; version 1's only kind) or "mesh" (its points baked in each animation)
        var kind: String? = nil
        var isMesh: Bool { kind == "mesh" }
        let name: String
        /// its picture (a png in the bundle), and its grid: points where they rest (document units, x y pairs), the
        /// picture's place at each, and triangles
        let tex: String
        let verts: [Float]
        let uvs: [Float]
        let tris: [UInt32]
        /// four bones a point (an index into `bones`, -1 none) and how much each pulls it (a skin part's)
        var bones: [Int]? = nil
        var weights: [Float]? = nil
        /// a mesh part's outline: its points' indexes (a shadow is moved away from the light from their middle)
        var rim: [Int]? = nil
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
        /// the mesh parts' points, a file beside it (version 2)
        var points: String? = nil
    }
    let name: String
    var version: Int? = nil
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

    /// the mesh parts' baked points, by file (read with the rig), and where each mesh part's are in a frame's (an offset
    /// into a frame's points, in int16s; nil for a skin part), and how many a frame has
    private(set) var baked: [String: [Int16]] = [:]
    private(set) var meshAt: [Int?] = []
    private(set) var meshPer = 0

    private enum CodingKeys: String, CodingKey { case name, version, size, fps, bones, light, lights, parts, channels, anims }

    /// (each read once: changing outfit, or opening the editor, doesn't read it again)
    private static var loaded: [String: AvatarRig] = [:]
    static func load(_ name: String) -> AvatarRig? {
        if let r = loaded[name] { return r }
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url), var r = try? JSONDecoder().decode(AvatarRig.self, from: data) else { return nil }
        guard r.readPoints({ file in
            let base = (file as NSString).deletingPathExtension, ext = (file as NSString).pathExtension
            return Bundle.main.url(forResource: base, withExtension: ext).flatMap { try? Data(contentsOf: $0) }
        }) else { return nil }
        loaded[name] = r
        return r
    }

    /// Reads every animation's baked points (`file` gives a file's bytes), and lays out where each mesh part's are in a
    /// frame. False if one is missing or the wrong size.
    mutating func readPoints(_ file: (String) -> Data?) -> Bool {
        var at = 0
        meshAt = parts.map { p -> Int? in
            guard p.isMesh else { return nil }
            defer { at += p.verts.count }
            return at
        }
        meshPer = at
        for a in anims.values {
            guard let f = a.points else { continue }
            guard let d = file(f), d.count == a.frames * meshPer * 2 else { return false }
            baked[f] = d.withUnsafeBytes { Array($0.bindMemory(to: Int16.self)) }   // (little-endian, as the phone is)
        }
        return meshAt.allSatisfy { $0 == nil } || anims.values.allSatisfy { baked[$0.points ?? ""] != nil }
    }

    /// A calm moment to show him still (an outfit's tile): Idle, in the middle of its longest stretch with his eyes
    /// open (no part that closes them showing), so a tile never catches him mid-blink or mid-sway.
    func stillFrame() -> (anim: Anim, ms: Double)? {
        guard let a = anims["Idle"] ?? anims.values.first, a.frames > 0 else { return nil }
        let closed = parts.indices.filter { parts[$0].name.lowercased().contains("closed") }
        var best = (start: 0, len: 0), run = (start: 0, len: 0)
        for f in 0..<a.frames {
            let open = closed.allSatisfy { a.opacity[f * parts.count + $0] < 0.5 }
            if open { run.len += 1; if run.len > best.len { best = run } } else { run = (f + 1, 0) }
        }
        return (a, Double(best.start + best.len / 2) * 1000 / fps)
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
                let ms = Double(f) * 1000 / fps, s = sample(a, at: ms)
                for i in parts.indices {
                    // (version 2: only what shows; a view not shown is its parts hidden, and they'd widen the box)
                    if (version ?? 1) >= 2 && s.opacity[i] < 0.01 { continue }
                    points(i, a, at: ms, mats: s.mats, into: &buf)
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
        let nb = bones.count, np = parts.count
        let (i, j, u) = frames(a, at: ms)
        var mats = [Float](repeating: 0, count: nb * 6)
        if a.mats.count >= (max(i, j) + 1) * nb * 6 {
            for k in 0..<(nb * 6) { mats[k] = a.mats[i * nb * 6 + k] * (1 - u) + a.mats[j * nb * 6 + k] * u }
        }
        let o = u < 0.5 ? i : j
        return (mats, Array(a.opacity[(o * np)..<(o * np + np)]))
    }

    /// A part's points at a pose (document units, x y pairs): a skin part's each its bones' moves, weighed; a mesh part's
    /// as baked, `ms` into the animation (between its two nearest frames).
    func points(_ i: Int, _ a: Anim, at ms: Double, mats: [Float], into out: inout [Float]) {
        let p = parts[i]
        if p.isMesh { meshPoints(i, a, at: ms, into: &out) } else { bend(p.verts, p.bones ?? [], p.weights ?? [], mats: mats, into: &out) }
    }

    /// Where an animation is at `ms`: its two nearest frames and how far between them.
    func frames(_ a: Anim, at ms: Double) -> (i: Int, j: Int, u: Float) {
        let n = a.frames
        var f = ms * fps / 1000
        if a.loop { f = f.truncatingRemainder(dividingBy: Double(n)); if f < 0 { f += Double(n) } } else { f = min(max(f, 0), Double(n - 1)) }
        let i = Int(f)
        return (i, a.loop ? (i + 1) % n : min(i + 1, n - 1), Float(f - Double(i)))
    }

    /// A mesh part's baked points `ms` into an animation (document units, x y pairs); its points at rest if it has none.
    func meshPoints(_ i: Int, _ a: Anim, at ms: Double, into out: inout [Float]) {
        let p = parts[i], n = p.verts.count
        if out.count != n { out = [Float](repeating: 0, count: n) }
        guard let off = meshAt[i], let file = a.points, let b = baked[file], a.frames > 0 else { for k in 0..<n { out[k] = p.verts[k] }; return }
        let (fi, fj, u) = frames(a, at: ms), oi = fi * meshPer + off, oj = fj * meshPer + off
        for k in 0..<n { out[k] = (Float(b[oi + k]) * (1 - u) + Float(b[oj + k]) * u) / 10 }
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
