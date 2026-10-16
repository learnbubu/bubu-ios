import Foundation

/// An avatar made in Bùbù Studio and exported for the app ("App avatar"): its parts (pictures with bend grids, bound to
/// bones), its light, and every animation baked a frame at a time (each bone's move from rest, each part's opacity).
/// The player bends each part by its bones and draws them bottom up, shaded in the light, as Studio draws them.
struct AvatarRig: Decodable {
    struct Light: Decodable { let x: Float; let y: Float; let distance: Float; let strength: Float; let softness: Float }
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
        /// in the light: whether it throws a shadow, whether shadows fall on it, the parts its shadow never falls on
        /// (they meet at a joint), the parts in its shadow's way wherever they are, and a part it's shaded as (-1 none)
        let cast: Bool
        let receive: Bool
        let skip: [Int]
        let block: [Int]
        let `as`: Int
    }
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
    let parts: [Part]
    let anims: [String: Anim]

    static func load(_ name: String) -> AvatarRig? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AvatarRig.self, from: data)
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
        let n = p.verts.count / 2
        if out.count != n * 2 { out = [Float](repeating: 0, count: n * 2) }
        for v in 0..<n {
            let x = p.verts[v * 2], y = p.verts[v * 2 + 1]
            var px: Float = 0, py: Float = 0, ws: Float = 0
            for k in 0..<4 {
                let b = p.bones[v * 4 + k]; if b < 0 { continue }
                let w = p.weights[v * 4 + k], m = b * 6
                px += w * (mats[m] * x + mats[m + 2] * y + mats[m + 4])
                py += w * (mats[m + 1] * x + mats[m + 3] * y + mats[m + 5])
                ws += w
            }
            if ws < 1e-6 { px = x; py = y }
            out[v * 2] = px; out[v * 2 + 1] = py
        }
    }
}
