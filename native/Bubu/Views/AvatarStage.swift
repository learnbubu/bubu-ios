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

    func makeUIView(context: Context) -> MTKView {
        let v = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        v.isOpaque = false
        v.backgroundColor = .clear
        v.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        v.colorPixelFormat = .bgra8Unorm
        v.preferredFramesPerSecond = 60
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

    init?(rig: AvatarRig, view: MTKView) {
        guard let device = view.device, let queue = device.makeCommandQueue(), let lib = device.makeDefaultLibrary(),
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
        idle = names.contains("Idle") ? "Idle" : (names.first ?? "")
        reactions = names.filter { $0 != idle && !$0.lowercased().hasPrefix("pose") }.sorted()
        playing = idle
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

    /// One of the other animations, now (tapped), if it's idling.
    func react() { if playing == idle { startReaction(CACurrentMediaTime()) } }

    private func startReaction(_ now: CFTimeInterval) {
        guard !reactions.isEmpty else { return }
        let pick = reactions.filter { $0 != last }.randomElement() ?? reactions[0]
        last = pick; playing = pick; started = now
    }

    /// What plays now, and how far in (ms): Idle for one or two of its loops, then another once, then Idle again (both
    /// start and end at rest, so they meet without a jump).
    private func direct(_ now: CFTimeInterval) -> (AvatarRig.Anim, Double) {
        var e = (now - started) * 1000
        if playing == idle, let a = rig.anims[idle], e >= a.duration * Double(idleLoops), !reactions.isEmpty {
            startReaction(now); e = 0
        } else if playing != idle, let a = rig.anims[playing], e >= a.duration {
            playing = idle; started = now; e = 0; idleLoops = Int.random(in: 1...2)
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
        let (anim, ms) = direct(CACurrentMediaTime())
        guard anim.frames > 0, !anim.mats.isEmpty else { return }
        let (mats, op) = rig.sample(anim, at: ms)
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
        var maskOf = [MTLTexture?](repeating: nil, count: n)
        if let L = rig.light {
            let shows = (0..<n).map { op[$0] > 0.01 }
            var shift = [SIMD2<Float>](repeating: .zero, count: n)
            for c in 0..<n where parts[c].cast && shows[c] {
                var x0 = Float.greatestFiniteMagnitude, y0 = x0, x1 = -x0, y1 = -x0
                for k in stride(from: 0, to: pts[c].count, by: 2) { x0 = min(x0, pts[c][k]); x1 = max(x1, pts[c][k]); y0 = min(y0, pts[c][k + 1]); y1 = max(y1, pts[c][k + 1]) }
                let dx = (x0 + x1) / 2 - L.x, dy = (y0 + y1) / 2 - L.y, d = max(1e-3, (dx * dx + dy * dy).squareRoot())
                shift[c] = SIMD2(dx / d * L.distance, dy / d * L.distance)
            }
            var jobs: [(Int, [Int])] = []
            for i in 0..<n where parts[i].receive && shows[i] {
                let ref = parts[i].as >= 0 ? parts[i].as : i
                let casters = ((ref + 1)..<max(ref + 1, n)).filter { c in c != i && parts[c].cast && shows[c] && !parts[c].skip.contains(i) && !parts[c].skip.contains(ref) }
                if !casters.isEmpty { jobs.append((i, casters)) }
            }
            let mw = max(1, Int(W) / 2), mh = max(1, Int(H) / 2)
            ensureMasks(mw, mh, count: jobs.count)
            let sigma = L.softness * s * 0.25
            for (k, job) in jobs.enumerated() where k < masks.count {
                let (i, casters) = job
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
                    frame.shift = shift[c]
                    draw(enc, c, &frame)
                }
                enc.endEncoding()
                if sigma > 0.3 {
                    MPSImageGaussianBlur(device: device, sigma: sigma).encode(commandBuffer: cb, sourceTexture: masks[k], destinationTexture: softened[k])
                    maskOf[i] = softened[k]
                } else { maskOf[i] = masks[k] }
            }
        }

        // the parts, bottom up
        guard let enc = cb.makeRenderCommandEncoder(descriptor: rpd) else { return }
        enc.setRenderPipelineState(partPipe)
        frame.shift = .zero
        for i in 0..<n where op[i] > 0.01 {
            var paint = Paint(opacity: op[i], strength: maskOf[i] == nil ? 0 : (rig.light?.strength ?? 0), viewport: SIMD2(W, H))
            enc.setFragmentTexture(maskOf[i] ?? none, index: 1)
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

    /// (as the shaders' AvatarFrame and AvatarPaint)
    private struct Frame { var scale: SIMD2<Float>; var offset: SIMD2<Float>; var shift: SIMD2<Float> }
    private struct Paint { var opacity: Float; var strength: Float; var viewport: SIMD2<Float> }
}
