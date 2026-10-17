import SwiftUI
import MetalKit
import MetalPerformanceShaders

/// The avatar, alive: Studio's rig drawn natively (Metal), idling, and now and then (or when tapped) playing one of its
/// other animations once before idling again.
struct AvatarStage: UIViewRepresentable {
    var name = "relaxed"

    final class Coordinator: NSObject {
        var renderer: AvatarRenderer?
        @objc func tap() { renderer?.react() }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }

    /// (draws only while it's on screen: off it, under another tab or a cover, it rests)
    final class View: MTKView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            isPaused = window == nil || delegate == nil
            (delegate as? AvatarRenderer)?.rest(isPaused)
        }
    }

    func makeUIView(context: Context) -> MTKView {
        let v = View(frame: .zero, device: MTLCreateSystemDefaultDevice())
        v.isOpaque = false
        v.backgroundColor = .clear
        v.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        v.colorPixelFormat = .bgra8Unorm
        v.preferredFramesPerSecond = 60   // (baked at 30: every other frame drawn between two, so it moves smoothly)
        if let rig = AvatarRig.load(name), let r = AvatarRenderer(rig: rig, view: v) {
            context.coordinator.renderer = r
            v.delegate = r
        }
        v.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap)))
        v.isAccessibilityElement = true
        v.accessibilityLabel = "Your avatar"
        return v
    }
    func updateUIView(_ v: MTKView, context: Context) {}
    static func dismantleUIView(_ v: MTKView, coordinator: Coordinator) { v.isPaused = true; v.delegate = nil }
}

/// Draws an AvatarRig, as Studio does: each part bent by its bones, bottom up; in the light, each part's shadow (the
/// parts above it that cast, each moved away from the lamp, less where what blocks it is, softened) laid on its own
/// colour. And it directs: Idle round and round, another animation now and then.
final class AvatarRenderer: NSObject, MTKViewDelegate {
    let rig: AvatarRig
    private let device: MTLDevice, queue: MTLCommandQueue
    private let partPipe: MTLRenderPipelineState, maskPipe: MTLRenderPipelineState, blockPipe: MTLRenderPipelineState
    private let noStencil: MTLDepthStencilState, mark: MTLDepthStencilState, outside: MTLDepthStencilState
    private var textures: [MTLTexture] = []
    private var uvBufs: [MTLBuffer] = [], idxBufs: [MTLBuffer] = [], posBufs: [MTLBuffer] = []
    private var pts: [[Float]]
    private var edgePts: [Float] = []
    private let none: MTLTexture
    private var masks: [MTLTexture] = [], softened: [MTLTexture] = [], stencil: MTLTexture?, maskSize = (w: 0, h: 0)
    /// the part of the document it shows (every pose of every animation fits)
    private var frameRect = (x: Float(0), y: Float(0), w: Float(1), h: Float(1))

    // directing
    private let idle: String
    private let reactions: [String]
    private var playing: String
    private var started = CACurrentMediaTime()
    private var idleLoops = 1
    private var last: String?
    private var restedAt: CFTimeInterval?
    /// how much quicker than in Studio the other animations play (Idle plays as made)
    private let reactionSpeed = 1.25
    /// what played before the last change, and how far in it was then: for a moment after a change the two are blended,
    /// so one animation flows into the next even where their poses don't meet (Idle doesn't start at rest; a tap
    /// interrupts it anywhere)
    private var before: (name: String, at: Double)?
    private var changedAt: CFTimeInterval = 0
    private let blendTime = 0.6

    init?(rig: AvatarRig, view: MTKView) {
        guard let device = view.device, let queue = device.makeCommandQueue(), let lib = try? device.makeLibrary(source: Self.shaders, options: nil),
              let vfn = lib.makeFunction(name: "avatar_vertex"), let part = lib.makeFunction(name: "avatar_part"),
              let sil = lib.makeFunction(name: "avatar_silhouette"), let blk = lib.makeFunction(name: "avatar_blocker") else { return nil }
        self.rig = rig; self.device = device; self.queue = queue
        func pipe(_ f: MTLFunction, _ fmt: MTLPixelFormat, stencil: Bool, write: Bool, union: Bool) -> MTLRenderPipelineState? {
            let d = MTLRenderPipelineDescriptor()
            d.vertexFunction = vfn; d.fragmentFunction = f
            let c = d.colorAttachments[0]!
            c.pixelFormat = fmt
            c.writeMask = write ? .all : []
            c.isBlendingEnabled = write
            c.sourceRGBBlendFactor = .one; c.sourceAlphaBlendFactor = .one
            c.destinationRGBBlendFactor = union ? .oneMinusSourceColor : .oneMinusSourceAlpha
            c.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            if stencil { d.stencilAttachmentPixelFormat = .stencil8 }
            return try? device.makeRenderPipelineState(descriptor: d)
        }
        guard let pp = pipe(part, view.colorPixelFormat, stencil: false, write: true, union: false),
              let mp = pipe(sil, .r8Unorm, stencil: true, write: true, union: true),
              let bp = pipe(blk, .r8Unorm, stencil: true, write: false, union: false) else { return nil }
        partPipe = pp; maskPipe = mp; blockPipe = bp
        func stencilState(_ cmp: MTLCompareFunction?, replace: Bool) -> MTLDepthStencilState? {
            let d = MTLDepthStencilDescriptor()
            if let cmp {
                let s = MTLStencilDescriptor()
                s.stencilCompareFunction = cmp
                s.depthStencilPassOperation = replace ? .replace : .keep
                s.readMask = 0xFF; s.writeMask = replace ? 0xFF : 0
                d.frontFaceStencil = s; d.backFaceStencil = s
            }
            return device.makeDepthStencilState(descriptor: d)
        }
        guard let n0 = stencilState(nil, replace: false), let m0 = stencilState(.always, replace: true), let o0 = stencilState(.notEqual, replace: false) else { return nil }
        noStencil = n0; mark = m0; outside = o0
        let nd = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: 1, height: 1, mipmapped: false)
        guard let nt = device.makeTexture(descriptor: nd) else { return nil }
        var zero: UInt8 = 0
        nt.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: &zero, bytesPerRow: 1)
        none = nt
        pts = rig.parts.map { [Float](repeating: 0, count: $0.verts.count) }

        let names = Array(rig.anims.keys)
        let idleName = names.contains("Idle") ? "Idle" : (names.first ?? "")
        idle = idleName
        reactions = names.filter { $0 != idleName && !$0.lowercased().hasPrefix("pose") }.sorted()
        playing = idleName
        super.init()

        // the parts' pictures and grids
        for p in rig.parts {
            guard let t = Self.texture(p.tex, device: device, queue: queue),
                  let uv = device.makeBuffer(bytes: p.uvs, length: max(4, p.uvs.count * 4)),
                  let ix = device.makeBuffer(bytes: p.tris, length: max(4, p.tris.count * 4)),
                  let ps = device.makeBuffer(length: max(4, p.verts.count * 4), options: .storageModeShared) else { return nil }
            textures.append(t); uvBufs.append(uv); idxBufs.append(ix); posBufs.append(ps)
        }
        frameRect = fitAll()
        view.depthStencilPixelFormat = .invalid
    }

    /// A png from the bundle, premultiplied, with mipmaps (it's drawn smaller than it was made).
    private static func texture(_ file: String, device: MTLDevice, queue: MTLCommandQueue) -> MTLTexture? {
        let base = (file as NSString).deletingPathExtension, ext = (file as NSString).pathExtension
        guard let url = Bundle.main.url(forResource: base, withExtension: ext), let img = UIImage(contentsOfFile: url.path)?.cgImage else { return nil }
        let w = img.width, h = img.height
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &bytes, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: w, height: h, mipmapped: true)
        d.usage = [.shaderRead]
        guard let t = device.makeTexture(descriptor: d) else { return nil }
        t.replace(region: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0, withBytes: bytes, bytesPerRow: w * 4)
        if let cb = queue.makeCommandBuffer(), let blit = cb.makeBlitCommandEncoder() {
            blit.generateMipmaps(for: t); blit.endEncoding(); cb.commit(); cb.waitUntilCompleted()
        }
        return t
    }

    /// The box every pose of every animation fits in, a little room round it.
    private func fitAll() -> (x: Float, y: Float, w: Float, h: Float) {
        var x0 = Float.greatestFiniteMagnitude, y0 = x0, x1 = -x0, y1 = -x0
        var buf: [Float] = []
        for a in rig.anims.values {
            for f in stride(from: 0, to: a.frames, by: 3) {
                let s = rig.sample(a, at: Double(f) * 1000 / rig.fps)
                for p in rig.parts {
                    rig.points(p, mats: s.mats, into: &buf)
                    for k in stride(from: 0, to: buf.count, by: 2) { x0 = min(x0, buf[k]); x1 = max(x1, buf[k]); y0 = min(y0, buf[k + 1]); y1 = max(y1, buf[k + 1]) }
                }
            }
        }
        guard x1 > x0, y1 > y0 else { return (0, 0, rig.size.first ?? 1, rig.size.last ?? 1) }
        let m = max(x1 - x0, y1 - y0) * 0.03
        return (x0 - m, y0 - m, x1 - x0 + 2 * m, y1 - y0 + 2 * m)
    }

    // MARK: directing

    /// Resting (off screen) and back: the time away doesn't count, so it carries on just where it stopped.
    func rest(_ on: Bool) {
        let now = CACurrentMediaTime()
        if on { if restedAt == nil { restedAt = now } } else if let t = restedAt { started += now - t; changedAt += now - t; restedAt = nil }
    }
    /// One of the other animations, now (tapped), if it's idling.
    func react() { if playing == idle { startReaction(CACurrentMediaTime()) } }

    private func speed(_ name: String) -> Double { name == idle ? 1 : reactionSpeed }
    private func elapsed(_ now: CFTimeInterval) -> Double { (now - started) * 1000 * speed(playing) }

    private func change(to name: String, _ now: CFTimeInterval) {
        var at = elapsed(now)
        if playing != idle, let a = rig.anims[playing] { at = min(at, a.duration - 0.01) }   // (a reaction ends where it ends)
        before = (playing, at); changedAt = now
        playing = name; started = now
    }

    private func startReaction(_ now: CFTimeInterval) {
        guard !reactions.isEmpty else { return }
        let pick = reactions.filter { $0 != last }.randomElement() ?? reactions[0]
        last = pick; change(to: pick, now)
    }

    /// What plays now, and how far in (ms): Idle for one or two of its loops, then another once, then Idle again (both
    /// start and end at rest, so they meet without a jump).
    private func direct(_ now: CFTimeInterval) -> (AvatarRig.Anim, Double) {
        // (for checking against Studio: launched with -avatarAt Name:ms it holds that frame)
        if let hold = UserDefaults.standard.string(forKey: "avatarAt"), let c = hold.lastIndex(of: ":"),
           let a = rig.anims[String(hold[..<c])], let ms = Double(hold[hold.index(after: c)...]) { before = nil; return (a, ms) }
        var e = elapsed(now)
        if playing == idle, let a = rig.anims[idle], e >= a.duration * Double(idleLoops), !reactions.isEmpty {
            startReaction(now); e = 0
        } else if playing != idle, let a = rig.anims[playing], e >= a.duration {
            change(to: idle, now); e = 0; idleLoops = Int.random(in: 1...2)
        }
        guard let a = rig.anims[playing] ?? rig.anims.values.first else { return (AvatarRig.Anim(duration: 1, loop: true, frames: 1, mats: [], opacity: []), 0) }
        return (a, e)
    }

    // MARK: drawing

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    private func ensureMasks(_ w: Int, _ h: Int, count: Int) {
        if maskSize.w != w || maskSize.h != h { masks = []; softened = []; stencil = nil; maskSize = (w, h) }
        let md = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: w, height: h, mipmapped: false)
        md.usage = [.renderTarget, .shaderRead, .shaderWrite]; md.storageMode = .private
        while masks.count < count, let a = device.makeTexture(descriptor: md), let b = device.makeTexture(descriptor: md) { masks.append(a); softened.append(b) }
        if stencil == nil {
            let sd = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .stencil8, width: w, height: h, mipmapped: false)
            sd.usage = [.renderTarget]; sd.storageMode = .private
            stencil = device.makeTexture(descriptor: sd)
        }
    }

    func draw(in view: MTKView) {
        guard let rpd = view.currentRenderPassDescriptor, let drawable = view.currentDrawable, let cb = queue.makeCommandBuffer() else { return }
        let now = CACurrentMediaTime()
        let (anim, ms) = direct(now)
        guard anim.frames > 0, !anim.mats.isEmpty else { return }
        var (mats, op) = rig.sample(anim, at: ms)
        // just after a change: blended from what played before (it carrying on, eased out as the new one eases in)
        if let b = before, let ba = rig.anims[b.name] {
            let t = (now - changedAt) / blendTime
            if t >= 1 { before = nil } else {
                var at = b.at + (now - changedAt) * 1000 * speed(b.name)
                if b.name != idle { at = min(at, ba.duration - 0.01) }
                let old = rig.sample(ba, at: at).mats, w = Float(t * t * (3 - 2 * t))
                for k in 0..<mats.count { mats[k] = old[k] * (1 - w) + mats[k] * w }
            }
        }
        let parts = rig.parts, n = parts.count
        // every part bent to this pose
        for i in 0..<n {
            rig.points(parts[i], mats: mats, into: &pts[i])
            pts[i].withUnsafeBytes { posBufs[i].contents().copyMemory(from: $0.baseAddress!, byteCount: $0.count) }
        }
        // the document's box, fitted in the view
        let W = Float(view.drawableSize.width), H = Float(view.drawableSize.height)
        guard W > 0, H > 0 else { return }
        let fr = frameRect, s = min(W / fr.w, H / fr.h)
        let ox = (W - fr.w * s) / 2 - fr.x * s, oy = (H - fr.h * s) / 2 - fr.y * s
        var frame = Frame(scale: SIMD2(2 * s / W, -2 * s / H), offset: SIMD2(ox / W * 2 - 1, 1 - oy / H * 2), shift: .zero)

        // the shadows: a mask a part that receives, from the parts above it that cast
        // (two at most on a part: each with how dark it is)
        var maskOf = [[(MTLTexture, Float)]](repeating: [], count: n)
        let lamps = rig.lamps
        if !lamps.isEmpty {
            let shows = (0..<n).map { op[$0] > 0.01 }
            var middle = [SIMD2<Float>](repeating: .zero, count: n)
            for c in 0..<n where parts[c].cast && shows[c] {
                // (its middle: of its whole grid's outline, as Studio measures it)
                if let e = parts[c].edge { rig.bend(e.verts, e.bones, e.weights, mats: mats, into: &edgePts) } else { edgePts = pts[c] }
                var x0 = Float.greatestFiniteMagnitude, y0 = x0, x1 = -x0, y1 = -x0
                for k in stride(from: 0, to: edgePts.count, by: 2) { x0 = min(x0, edgePts[k]); x1 = max(x1, edgePts[k]); y0 = min(y0, edgePts[k + 1]); y1 = max(y1, edgePts[k + 1]) }
                middle[c] = SIMD2((x0 + x1) / 2, (y0 + y1) / 2)
            }
            // each caster's shadow moved away from a lamp, from its middle
            func shift(_ c: Int, _ L: AvatarRig.Light) -> SIMD2<Float> {
                let dx = middle[c].x - L.x, dy = middle[c].y - L.y, d = max(1e-3, (dx * dx + dy * dy).squareRoot())
                return SIMD2(dx / d * L.distance, dy / d * L.distance)
            }
            var jobs: [(Int, Int, [Int])] = []
            for (li, lamp) in lamps.enumerated() { for i in 0..<n where parts[i].receive && shows[i] && rig.falls(lamp, on: i) {
                // (part of another: shaded as one surface with it, but only by what's above both, so an ear's flap
                // over the hair takes no shadow from the hair it covers)
                let ref = parts[i].as >= 0 ? parts[i].as : i, above = max(ref, i) + 1
                let casters = (above..<max(above, n)).filter { c in c != i && parts[c].cast && shows[c] && !parts[c].skip.contains(i) && !parts[c].skip.contains(ref) }
                if !casters.isEmpty && maskOf[i].count + jobs.filter({ $0.0 == i }).count < 2 { jobs.append((i, li, casters)) }
            } }
            let mw = max(1, Int(W)), mh = max(1, Int(H))   // (as sharp as the screen: at half, a shadow's edge stepped, and slivers showed at the armpits)
            ensureMasks(mw, mh, count: jobs.count)
            for (k, job) in jobs.enumerated() where k < masks.count {
                let (i, li, casters) = job, L = lamps[li].light, sigma = L.softness * s * 0.5
                let pd = MTLRenderPassDescriptor()
                pd.colorAttachments[0].texture = masks[k]; pd.colorAttachments[0].loadAction = .clear
                pd.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0); pd.colorAttachments[0].storeAction = .store
                pd.stencilAttachment.texture = stencil; pd.stencilAttachment.loadAction = .clear; pd.stencilAttachment.clearStencil = 0; pd.stencilAttachment.storeAction = .dontCare
                guard let enc = cb.makeRenderCommandEncoder(descriptor: pd) else { continue }
                for (ci, c) in casters.enumerated() {
                    let blocks = parts[c].block.filter { $0 >= 0 && $0 < n && shows[$0] }
                    let ref = UInt32(ci % 255 + 1)
                    if !blocks.isEmpty {
                        // what's in this caster's way, marked; the caster drawn only outside it
                        enc.setRenderPipelineState(blockPipe); enc.setDepthStencilState(mark); enc.setStencilReferenceValue(ref)
                        frame.shift = .zero
                        for b in blocks { draw(enc, b, &frame) }
                        enc.setDepthStencilState(outside)
                    } else { enc.setDepthStencilState(noStencil) }
                    enc.setRenderPipelineState(maskPipe); enc.setStencilReferenceValue(ref)
                    frame.shift = shift(c, L)
                    draw(enc, c, &frame)
                }
                enc.endEncoding()
                if sigma > 0.3 {
                    MPSImageGaussianBlur(device: device, sigma: sigma).encode(commandBuffer: cb, sourceTexture: masks[k], destinationTexture: softened[k])
                    maskOf[i].append((softened[k], L.strength))
                } else { maskOf[i].append((masks[k], L.strength)) }
            }
        }

        // the parts, bottom up
        guard let enc = cb.makeRenderCommandEncoder(descriptor: rpd) else { return }
        enc.setRenderPipelineState(partPipe)
        frame.shift = .zero
        for i in 0..<n where op[i] > 0.01 {
            let m = maskOf[i]
            var paint = Paint(opacity: op[i], strength: m.count > 0 ? m[0].1 : 0, strength2: m.count > 1 ? m[1].1 : 0, viewport: SIMD2(W, H))
            enc.setFragmentTexture(m.count > 0 ? m[0].0 : none, index: 1)
            enc.setFragmentTexture(m.count > 1 ? m[1].0 : none, index: 2)
            enc.setFragmentBytes(&paint, length: MemoryLayout<Paint>.stride, index: 0)
            draw(enc, i, &frame)
        }
        enc.endEncoding()
        cb.present(drawable)
        cb.commit()
    }

    private func draw(_ enc: MTLRenderCommandEncoder, _ i: Int, _ frame: inout Frame) {
        enc.setVertexBuffer(posBufs[i], offset: 0, index: 0)
        enc.setVertexBuffer(uvBufs[i], offset: 0, index: 1)
        enc.setVertexBytes(&frame, length: MemoryLayout<Frame>.stride, index: 2)
        enc.setFragmentTexture(textures[i], index: 0)
        let count = rig.parts[i].tris.count
        if count > 0 { enc.drawIndexedPrimitives(type: .triangle, indexCount: count, indexType: .uint32, indexBuffer: idxBufs[i], indexBufferOffset: 0) }
    }

    /// The avatar player's drawing: parts bent on the CPU, drawn here bottom up; the light's shadows made per part (the
    /// shapes of the parts above it that cast, moved from the lamp, into one mask), then laid on the part's own colour.
    /// (compiled on the phone when the player starts, so building the app needs no Metal toolchain)
    private static let shaders = #"""
#include <metal_stdlib>
using namespace metal;

/// document units -> clip space; `shift` moves a caster's shape away from the lamp (document units)
struct AvatarFrame { float2 scale; float2 offset; float2 shift; };
/// a part's opacity, how dark its shadow is, and the drawable's size (to find its place in the shadow mask)
struct AvatarPaint { float opacity; float strength; float strength2; float2 viewport; };

struct AvatarVOut { float4 pos [[position]]; float2 uv; };

vertex AvatarVOut avatar_vertex(const device float2 *pos [[buffer(0)]], const device float2 *uv [[buffer(1)]],
                                constant AvatarFrame &f [[buffer(2)]], uint vid [[vertex_id]]) {
    AvatarVOut o;
    o.pos = float4((pos[vid] + f.shift) * f.scale + f.offset, 0, 1);
    o.uv = uv[vid];
    return o;
}

/// a part: its picture (premultiplied), darkened where the shadow mask says, at its opacity
fragment float4 avatar_part(AvatarVOut in [[stage_in]], texture2d<float> tex [[texture(0)]], texture2d<float> mask [[texture(1)]],
                            texture2d<float> mask2 [[texture(2)]], constant AvatarPaint &p [[buffer(0)]]) {
    constexpr sampler s(filter::linear, mip_filter::linear, address::clamp_to_edge);
    float4 c = tex.sample(s, in.uv);
    float2 at = in.pos.xy / p.viewport;
    c.rgb *= (1.0 - p.strength * mask.sample(s, at).r) * (1.0 - p.strength2 * mask2.sample(s, at).r);   // (each light's shadow over the last)
    return c * p.opacity;
}

/// a caster's shape, white where it's drawn (into a shadow mask)
fragment float4 avatar_silhouette(AvatarVOut in [[stage_in]], texture2d<float> tex [[texture(0)]]) {
    constexpr sampler s(filter::linear, mip_filter::linear, address::clamp_to_edge);
    float a = tex.sample(s, in.uv).a;
    return float4(a, a, a, a);
}

/// a part in a caster's way: only marks the stencil where it's drawn
fragment float4 avatar_blocker(AvatarVOut in [[stage_in]], texture2d<float> tex [[texture(0)]]) {
    constexpr sampler s(filter::linear, mip_filter::linear, address::clamp_to_edge);
    if (tex.sample(s, in.uv).a < 0.03) discard_fragment();   // (all of it, to its faintest edge: else a sliver of shadow showed past it, at the armpits)
    return float4(0);
}
"""#

    /// (as the shaders' AvatarFrame and AvatarPaint)
    private struct Frame { var scale: SIMD2<Float>; var offset: SIMD2<Float>; var shift: SIMD2<Float> }
    private struct Paint { var opacity: Float; var strength: Float; var strength2: Float; var viewport: SIMD2<Float> }
}
