import SwiftUI

// The five-in-a-row firecracker burst and Bùbù in parts, as tuned in the effects studio (the
// owner, 6 Oct 2026). Both are drawn frame by frame from a time t (ms), the way the studio
// draws them, so its numbers carry over as they are. Art: tools/art/install_fx.py (RigArt).

private func clamp01(_ v: Double) -> Double { min(1, max(0, v)) }
private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
private func easeOut(_ t: Double) -> Double { 1 - pow(1 - t, 3) }
private func backOut(_ t: Double) -> Double { let c = 1.7; return 1 + (c + 1) * pow(t - 1, 3) + c * pow(t - 1, 2) }
/// 0..1..0 over [a, b]: up over the first `inF`, down over the last `outF`
private func envelope(_ t: Double, _ a: Double, _ b: Double, _ inF: Double = 0.2, _ outF: Double = 0.3) -> Double {
    guard t >= a, t <= b else { return 0 }
    let u = (t - a) / (b - a)
    return u < inF ? u / inF : u > 1 - outF ? (1 - u) / outF : 1
}

// MARK: - the firecracker burst

/// One string of firecrackers drops out from behind the progress bar, pops from the bottom
/// up, and a red seal stamps "五连" (five in a row) with the count under it. Placed against
/// the progress bar's frame (`bar`, in the burst's own space), as the studio placed it against
/// its phone's bar (the studio's numbers are in a 390-wide phone, its bar ending at y 78).
struct FirecrackerBurst: View {
    let n: Int
    let bar: CGRect
    @State private var start = Date()
    static let length = 2.2

    // the studio's settings (tuning/burst)
    private let strX = 324.0, strTop = 107.0, maskTop = 78.0, knot = 58.0, cracker = 18.0, count = 6, spacing = 31.0, angle = 37.0
    private let sideL = (rot: -17.0, dx: -9.0, mirror: false), sideR = (rot: 19.0, dx: 9.0, mirror: true)
    private let popScale = 2.1, popLength = 200.0
    private let seal = (x: 319.0, y: 262.0, size: 104.0, rotate: -7.0, font: 42.0, dy: -3.0, gap: -2.0)
    private let caption = (x: 319.0, y: 324.0, size: 18.0)
    private let drop = (0.0, 300.0), pops = (380.0, 780.0), stringsOut = (950.0, 210.0), sealT = (1000.0, 510.0),
                capT = (970.0, 490.0), fadeOut = (1750.0, 420.0)

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { tl in
                frame(t: tl.date.timeIntervalSince(start) * 1000, k: geo.size.width / 390)
            }
        }
        .allowsHitTesting(false)
        .onAppear { start = Date(); sounds() }
    }

    /// the studio's phone units to here
    private func X(_ x: Double, _ k: Double) -> Double { bar.minX + (x - 62) * k }
    private func Y(_ y: Double, _ k: Double) -> Double { bar.maxY + (y - maskTop) * k }

    private struct Cracker { let i: Int; let size: Double; let deg: Double; let hx: Double; let hy: Double; let mirror: Bool; let at: Double }

    private var knotAR: Double { Double(RigArt.aspect["fx-firecracker-knot-nocord"] ?? 1.48) }
    private var crackerAR: Double { Double(RigArt.aspect["fx-firecracker"] ?? 1.6) }
    private var cordTop: Double { knot * knotAR * 0.8 }

    private var crackers: [Cracker] {
        let span = max(0, pops.1 - popLength)
        return (0..<count).map { i in
            let dir = i % 2 == 1 ? 1.0 : -1.0
            let sd = dir > 0 ? sideL : sideR
            let k = count - 1 - i                                         // the bottom one pops first
            return Cracker(i: i, size: cracker, deg: dir * angle + sd.rot, hx: sd.dx,
                           hy: cordTop + 8 + Double(i) * spacing, mirror: sd.mirror,
                           at: pops.0 + (count > 1 ? Double(k) * span / Double(count - 1) : 0))
        }
    }

    private func sounds() {
        var events: [(Double, String)] = [(drop.0, "burst-drop"), (sealT.0 + sealT.1 * 0.7, "burst-stamp")]
        for c in crackers { events.append((c.at, "burst-pop\(min(count - 1 - c.i, 8))")) }
        for (at, name) in events {
            DispatchQueue.main.asyncAfter(deadline: .now() + at / 1000) { Sounds.shared.play(name) }
        }
    }

    @ViewBuilder private func frame(t: Double, k: Double) -> some View {
        let fade = 1 - clamp01((t - fadeOut.0) / fadeOut.1)
        ZStack(alignment: .topLeading) {
            strings(t: t, k: k)
                .mask(alignment: .top) { VStack(spacing: 0) { Color.clear.frame(height: max(0, bar.maxY)); Color.black } }
            sealView(t: t, k: k)
            captionView(t: t, k: k)
        }
        .opacity(fade)
    }

    private func strings(t: Double, k: Double) -> some View {
        let p = clamp01((t - drop.0) / drop.1)
        let hide = strTop + knot * knotAR * 0.8 + Double(count) * spacing + 60 - maskTop
        let dy = lerp(-hide, 0, backOut(p))
        let out = 1 - clamp01((t - stringsOut.0) / stringsOut.1)
        let x0 = X(strX, k), top = Y(strTop, k)
        let cw = knot * 28 / 398 * k
        let cord = LinearGradient(stops: [.init(color: Color(UIColor(hex: 0xE44D2C)), location: 0), .init(color: Color(UIColor(hex: 0xE44D2C)), location: 0.55),
                                          .init(color: Color(UIColor(hex: 0xCD3E23)), location: 0.55), .init(color: Color(UIColor(hex: 0xCD3E23)), location: 1)],
                                  startPoint: .leading, endPoint: .trailing)
        let cordLen = (cordTop + Double(count) * spacing + 10) * k
        return ZStack(alignment: .topLeading) {
            // the string: one cord from far up behind the bar, the knot, the firecrackers
            ZStack(alignment: .topLeading) {
                Rectangle().fill(cord).frame(width: cw, height: 400 * k + top + cordLen)
                    .position(x: x0, y: top - (400 * k + top) + (400 * k + top + cordLen) / 2)
                Image("fx-firecracker-knot-nocord").resizable().frame(width: knot * k, height: knot * knotAR * k)
                    .position(x: x0, y: top + knot * knotAR * k / 2)
                ForEach(crackers, id: \.i) { c in
                    let visible = t < c.at + popLength * 0.09
                    let w = c.size * k, h = c.size * crackerAR * k
                    Image("fx-firecracker").resizable().frame(width: w, height: h)
                        .scaleEffect(x: c.mirror ? -1 : 1, y: 1)
                        .rotationEffect(.degrees(c.deg), anchor: .top)
                        .position(x: x0 + c.hx * k, y: top + c.hy * k + h / 2)
                        .opacity(visible ? 1 : 0)
                }
            }
            .offset(y: (t < drop.0 ? -hide : dy) * k)
            .opacity(out)
            // the pops, where each firecracker hung
            ForEach(crackers, id: \.i) { c in popView(c, t: t, k: k, x0: x0, top: top) }
        }
    }

    @ViewBuilder private func popView(_ c: Cracker, t: Double, k: Double, x0: Double, top: Double) -> some View {
        let a = c.deg * .pi / 180, ch = c.size * crackerAR
        let px = x0 + (c.hx - sin(a) * ch * 0.55) * k, py = top + (c.hy + cos(a) * ch * 0.55) * k
        let L = popLength, at = c.at
        let frames: [(String, Double, Double, Double, Double, Double)] = [   // name, width, from, to (of L), fade in, fade out
            ("fx-pop-1", 22, 0, 0.2, 0.2, 0.3), ("fx-pop-2", 38, 0.14, 0.46, 0.2, 0.3), ("fx-pop-3", 34, 0.37, 1, 0.15, 0.45)]
        ZStack {
            ForEach(0..<3, id: \.self) { j in
                let f = frames[j], s = f.1 * popScale * c.size / 18 * k
                let o = envelope(t, at + L * f.2, at + L * f.3, f.4, f.5)
                let grow = j == 0 ? lerp(0.7, 1, clamp01((t - at) / (L * 0.06))) : j == 1 ? lerp(0.75, 1.05, clamp01((t - at - L * 0.14) / (L * 0.3))) : 1
                Image(f.0).resizable().frame(width: s, height: s * Double(RigArt.aspect[f.0] ?? 1))
                    .scaleEffect(grow)
                    .offset(y: j == 2 ? -10 * clamp01((t - at - L * 0.37) / (L * 0.63)) * k : 0)
                    .opacity(o)
                    .position(x: px, y: py)
            }
        }
    }

    private var sealChars: [String] {
        let cn = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
        return (n <= 10 ? [cn[n]] : Array(String(n)).map(String.init)) + ["连"]
    }

    @ViewBuilder private func sealView(t: Double, k: Double) -> some View {
        let sp = (t - sealT.0) / sealT.1, u = clamp01(sp)
        let sc = u < 0.7 ? lerp(1.8, 0.94, easeOut(u / 0.7)) : lerp(0.94, 1, (u - 0.7) / 0.3)
        let rot = u < 0.7 ? lerp(seal.rotate + 5, seal.rotate - 1, u / 0.7) : lerp(seal.rotate - 1, seal.rotate, (u - 0.7) / 0.3)
        let size = seal.size * k
        ZStack {
            Image("fx-seal").resizable().scaledToFit()
            VStack(spacing: seal.gap * k) {
                ForEach(Array(sealChars.enumerated()), id: \.offset) { _, ch in
                    Text(ch).font(.system(size: seal.font * k * (sealChars.count > 2 ? 0.7 : 1), weight: .heavy, design: .serif))
                }
            }
            .foregroundStyle(Color(UIColor(hex: 0xFFF4E6)))
            .offset(y: seal.dy * k)
        }
        .frame(width: size, height: size)
        .scaleEffect(sc).rotationEffect(.degrees(rot))
        .opacity(sp < 0 ? 0 : clamp01(u / 0.5))
        .position(x: X(seal.x, k), y: Y(seal.y, k))
    }

    @ViewBuilder private func captionView(t: Double, k: Double) -> some View {
        let cp = clamp01((t - capT.0) / capT.1)
        Text("\(n) in a row!").font(.nunito(caption.size * k, .black)).italic()
            .foregroundStyle(Color(UIColor(hex: 0xE0574A)))
            .fixedSize()
            .opacity(t < capT.0 ? 0 : cp)
            .offset(y: (1 - easeOut(cp)) * 8)
            .position(x: X(caption.x, k), y: Y(caption.y, k) + caption.size * k * 0.6)
    }
}

// MARK: - Bùbù in parts

/// Bùbù built from his parts (body, backpack, straps, arms, head, eyes, mouths), acting out
/// one of the studio's acts, then (optionally) idling. Drawn on panda-idle's 420 x 643 canvas,
/// shown `height` points tall, standing on the bottom of its frame.
struct BubuRig: View {
    enum Act: String { case cheer, double, wave, idle }
    let act: Act
    var then: Act? = nil
    var height: CGFloat = 190
    @State private var start = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // the studio's settings (tuning/rig and its defaults)
    private let squash = 0.16, jump = 110.0, headLag = 1.0, armSwing = 1.0, wiggle = 0.0
    private let laughSpeed = 0.4, laughBounce = 0.08, armLen = 1.0, packLag = 1.0
    private let breathe = 0.012, breatheMs = 2600.0, sway = 1.2, tilt = 5.0, loopMs = 4200.0
    private static let tracks: [Act: [String: (Double, Double)]] = [
        .cheer: ["crouch": (0, 150), "jump": (150, 380), "arms": (170, 760), "face": (170, 950), "mouth": (210, 860),
                 "land": (530, 220), "wiggle": (740, 520), "blink": (1650, 140)],
        .double: ["crouch": (0, 130), "hop1": (130, 280), "land1": (410, 120), "hop2": (530, 300), "land": (830, 200),
                  "arms": (140, 900), "mouth": (160, 1000), "blink": (1650, 150)],
        .wave: ["wave": (100, 1300), "tilt": (150, 1100), "mouth": (200, 900), "blink": (1500, 150)],
        .idle: ["blink": (1300, 150), "blink2": (3300, 150), "tilt": (1900, 1300)],
    ]
    static func length(_ a: Act) -> Double { a == .idle ? 4200 : (tracks[a] ?? [:]).values.map { $0.0 + $0.1 }.max() ?? 0 }

    private static let shoulderUp: [String: CGPoint] = ["L": CGPoint(x: 112, y: 312), "R": CGPoint(x: 304, y: 312)]
    private static let upOut = 0.0       // the raised arms are drawn angled out already

    var body: some View {
        let scale = height / RigArt.canvas.height
        Group {
            if reduceMotion { pose(t: 0, act: .idle) }
            else {
                TimelineView(.animation) { tl in
                    let ms = tl.date.timeIntervalSince(start) * 1000
                    if let next = then, ms > Self.length(act) {
                        pose(t: (ms - Self.length(act)).truncatingRemainder(dividingBy: next == .idle ? loopMs : Self.length(next) + 600), act: next)
                    } else { pose(t: ms, act: act) }
                }
            }
        }
        .frame(width: RigArt.canvas.width * scale, height: height)
        .onAppear { start = Date() }
    }

    // MARK: the pose at a time

    private func track(_ t: Double, _ k: String, _ a: Act) -> Double {
        guard let v = Self.tracks[a]?[k] else { return -1 }
        return (t - v.0) / v.1
    }
    private func during(_ p: Double) -> Bool { p >= 0 && p <= 1 }

    private func rigY(_ t: Double, _ a: Act) -> Double {
        var y = 0.0
        for (k, h) in [("jump", 1.0), ("hop1", 0.6), ("hop2", 0.7)] {
            let p = track(t, k, a); if p > 0 && p < 1 { y -= jump * h * sin(.pi * p) }
        }
        return y
    }

    private struct Pose {
        var sx = 1.0, sy = 1.0, rot = 0.0, y = 0.0
        var headY = 0.0, headRot = 0.0, headSX = 1.0, headSY = 1.0
        var packY = 0.0, packRot = 0.0
        var lUp = false, rUp = false, lr = 0.0, rr = 0.0
        var blink = false, laugh = false, mouthSY = 1.0
    }

    private func compute(_ t: Double, _ a: Act) -> Pose {
        var o = Pose()
        func sq(_ e: Double, _ k: Double = 1) { o.sy = 1 - squash * k * e; o.sx = 1 + squash * 0.7 * k * e }
        let c = track(t, "crouch", a)
        let firstHop = Self.tracks[a]?["jump"] ?? Self.tracks[a]?["hop1"]
        if c >= 0, let fh = firstHop, t < fh.0 { sq(sin(.pi / 2 * clamp01(c))) }
        for k in ["jump", "hop1", "hop2"] {
            let p = track(t, k, a); if p >= 0 && p < 1 { o.sy = 1 + squash * 0.8 * pow(1 - p, 2); o.sx = 1 / max(0.6, o.sy) }
        }
        for k in ["land1", "land"] {
            let p = track(t, k, a); if p >= 0 && p < 1 { sq(sin(.pi * p) * (1 - p * 0.4), k == "land1" ? 0.7 : 0.85) }
        }
        let wg = track(t, "wiggle", a); if wg > 0 && wg < 1 { o.rot += wiggle * sin(wg * .pi * 4) * (1 - wg) }
        let br = sin(2 * .pi * t / breatheMs)
        o.sy *= 1 + breathe * br; o.sx *= 1 - breathe * 0.5 * br
        let idleSway = a == .idle ? sway * sin(2 * .pi * t / (breatheMs * 2)) : 0
        o.y = rigY(t, a)
        let v = (rigY(t, a) - rigY(t - 16, a)) / 16
        let tl = track(t, "tilt", a)
        o.headY = min(24, max(-14, -v * 26 * headLag)) - breathe * 120 * br
        o.headRot = (tl > 0 && tl < 1 ? tilt * sin(.pi * tl) : 0) + idleSway
        o.headSX = 1 + (o.sx - 1) * -0.3; o.headSY = 1 + (o.sy - 1) * -0.4
        o.packY = min(26, max(-26, -v * 34 * packLag)); o.packRot = min(6, max(-6, -v * 6 * packLag))
        let ap = track(t, "arms", a), wv = track(t, "wave", a)
        o.lUp = during(ap); o.rUp = during(ap) || during(wv)
        if during(ap), let at = Self.tracks[a]?["arms"]?.0 {
            let sw = backOut(clamp01((t - at) / 160))
            let wave = sin((t - at) / 150 * .pi) * 9 * armSwing * clamp01(ap * 3) * (1 - ap * 0.5)
            o.lr = lerp(-50, 0, sw) + wave; o.rr = lerp(50, 0, sw) - wave
        }
        if during(wv), let at = Self.tracks[a]?["wave"]?.0 {
            // the waving arm stays out to the side (not behind his head), waving about 28° out
            o.rr = lerp(60, 28, backOut(clamp01((t - at) / 180))) - sin((t - at) / 170 * .pi) * 12 * armSwing
        }
        o.blink = during(track(t, "blink", a)) || during(track(t, "blink2", a))
        let mp = track(t, "mouth", a); o.laugh = during(mp)
        if o.laugh, let at = Self.tracks[a]?["mouth"]?.0 {
            o.mouthSY = 1 - laughBounce + laughBounce * abs(sin((t - at) / (110 / laughSpeed) * .pi))
        }
        return o
    }

    // MARK: drawing

    private func part(_ name: String, show: Bool = true) -> some View {
        let r = RigArt.rect[name] ?? .zero
        return Image(name).resizable().frame(width: r.width, height: r.height).offset(x: r.minX, y: r.minY).opacity(show ? 1 : 0)
    }
    private func anchor(_ name: String, _ p: CGPoint) -> UnitPoint {
        let r = RigArt.rect[name] ?? CGRect(x: 0, y: 0, width: 1, height: 1)
        return UnitPoint(x: (p.x - r.minX) / r.width, y: (p.y - r.minY) / r.height)
    }
    private func upArm(_ name: String, side: String, deg: Double, show: Bool) -> some View {
        let r = RigArt.rect[name] ?? .zero, a = anchor(name, Self.shoulderUp[side]!)
        return Image(name).resizable().frame(width: r.width, height: r.height)
            .scaleEffect(armLen, anchor: a)
            .rotationEffect(.degrees(deg), anchor: a)
            .offset(x: r.minX, y: r.minY).opacity(show ? 1 : 0)
    }

    private func pose(t: Double, act a: Act) -> some View {
        let o = compute(t, a)
        let scale = height / RigArt.canvas.height
        let unit = height / (RigArt.canvas.height * 0.62)        // the studio's phone px, here
        let pack = RigArt.rect["rig2-pack-side"] ?? .zero
        let mouth = RigArt.rect["rig-mouth-open"] ?? .zero
        return ZStack(alignment: .topLeading) {
            Image("rig2-pack-side").resizable().frame(width: pack.width, height: pack.height)
                .rotationEffect(.degrees(o.packRot), anchor: UnitPoint(x: 0.2, y: 0.1))
                .offset(x: pack.minX, y: pack.minY + o.packY)
            // the raised arms come up from behind his rounded shoulders
            upArm("rig-arm-left-up", side: "L", deg: o.lr - Self.upOut, show: o.lUp)
            upArm("rig-arm-right-up", side: "R", deg: o.rr + Self.upOut, show: o.rUp)
            // fur behind the neck, so the head can lift without a gap under it
            Ellipse().fill(Color(red: 44 / 255, green: 49 / 255, blue: 55 / 255)).frame(width: 224, height: 110).offset(x: 96, y: 200)
            // both arms down: the torso drawn with its arms on (no shoulder joints); else the torso alone
            // (waving, only the right arm up: the same torso with just its left arm drawn on)
            part("rig2-body", show: o.lUp)
            part("rig-arm-right-down", show: !o.rUp && o.lUp)
            part("rig4-torso-arms", show: !o.lUp && !o.rUp)
            part("rig4-torso-armL", show: o.rUp && !o.lUp)
            ZStack(alignment: .topLeading) {
                part("rig-head")
                part("rig-glint-open-L", show: !o.blink); part("rig-glint-open-R", show: !o.blink)
                part("rig-glint-blink-L", show: o.blink); part("rig-glint-blink-R", show: o.blink)
                part("rig-mouth-smile", show: !o.laugh)
                Image("rig-mouth-open").resizable().frame(width: mouth.width, height: mouth.height)
                    .scaleEffect(x: 1, y: o.mouthSY, anchor: .top)
                    .offset(x: mouth.minX, y: mouth.minY).opacity(o.laugh ? 1 : 0)
            }
            .frame(width: RigArt.canvas.width, height: RigArt.canvas.height, alignment: .topLeading)
            .scaleEffect(x: o.headSX, y: o.headSY, anchor: UnitPoint(x: 0.5, y: 0.45))
            .rotationEffect(.degrees(o.headRot), anchor: UnitPoint(x: 0.5, y: 0.45))
            .offset(y: o.headY)
        }
        .frame(width: RigArt.canvas.width, height: RigArt.canvas.height, alignment: .topLeading)
        .scaleEffect(x: o.sx, y: o.sy, anchor: .bottom)
        .rotationEffect(.degrees(o.rot), anchor: .bottom)
        .scaleEffect(scale, anchor: .topLeading)
        .frame(width: RigArt.canvas.width * scale, height: height, alignment: .topLeading)
        .offset(y: o.y * unit)
    }
}

// MARK: - Bùbù beside the question

/// Bùbù in the lesson's prompt, reacting to the answer (the owner's studio, 7 Oct 2026): waiting
/// he breathes and blinks, and after a while scratches his head thinking; right, a fist pump with
/// a grin and sparkles; wrong, an "oops" (eyes squeezed, a sweat drop) with his head drooping.
/// Drawn from the rig's parts on panda-idle's canvas, `height` points tall.
struct BubuMascot: View {
    var mood: Bool?          // nil: asking; true: right; false: wrong
    var height: CGFloat = 148
    @State private var since = Date()
    @State private var askedAt = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let scale = height / RigArt.canvas.height
        TimelineView(.animation(paused: reduceMotion)) { tl in
            pose(now: tl.date)
        }
        .frame(width: RigArt.canvas.width * scale, height: height)
        .onChange(of: mood) { _, m in since = Date(); if m == nil { askedAt = Date() } }
        .onAppear { since = Date(); askedAt = Date() }
    }

    private func part(_ name: String, show: Bool = true) -> some View {
        let r = RigArt.rect[name] ?? .zero
        return Image(name).resizable().frame(width: r.width, height: r.height).offset(x: r.minX, y: r.minY).opacity(show ? 1 : 0)
    }

    private func pose(now: Date) -> some View {
        let scale = height / RigArt.canvas.height
        let t = now.timeIntervalSince(since) * 1000                 // ms since the answer (or the question)
        let waited = now.timeIntervalSince(askedAt) * 1000
        let br = reduceMotion ? 0 : sin(2 * .pi * now.timeIntervalSinceReferenceDate * 1000 / 2600)
        var face: String? = nil, torso = "rig4-torso-arms", marks: [String] = []
        var y = 0.0, headRot = 0.0, headDrop = 0.0, blink = false
        switch mood {
        case true?:
            if t < 2600 { face = "rig5-head-grin"; torso = "rig5-torso-cheer-fists"; marks = ["rig5-fx-sparkles"] }
            if t < 500 { y = -13 * sin(.pi * t / 500) }
        case false?:
            if t < 2300 {
                face = "rig5-head-wince"; marks = ["rig5-fx-sweat"]
                let e = t < 350 ? 1 - pow(1 - t / 350, 3) : 1, settle = t > 1800 ? 1 - min(1, (t - 1800) / 500) : 1
                headRot = -11 * e * settle; headDrop = 8 * e * settle
            }
        case nil:
            if waited > 4000 { face = "rig5-head-think"; torso = "rig5-torso-scratch"; marks = ["rig5-fx-question"] }
            blink = Int(now.timeIntervalSinceReferenceDate * 1000) % 4200 < 140
        }
        let markIn = min(1, max(0, (t - 120) / 300))
        return ZStack(alignment: .topLeading) {
            part("rig2-pack-side")
            Ellipse().fill(Color(red: 44 / 255, green: 49 / 255, blue: 55 / 255)).frame(width: 224, height: 110).offset(x: 96, y: 200)
            ForEach(["rig4-torso-arms", "rig5-torso-cheer-fists", "rig5-torso-scratch"], id: \.self) { n in part(n, show: n == torso) }
            ZStack(alignment: .topLeading) {
                Group {
                    part("rig-head")
                    part("rig-glint-open-L", show: !blink); part("rig-glint-open-R", show: !blink)
                    part("rig-glint-blink-L", show: blink); part("rig-glint-blink-R", show: blink)
                    part("rig-mouth-smile")
                }
                .opacity(face == nil ? 1 : 0)
                ForEach(["rig5-head-grin", "rig5-head-wince", "rig5-head-think"], id: \.self) { n in part(n, show: n == face) }
                ForEach(["rig5-fx-sparkles", "rig5-fx-sweat", "rig5-fx-question"], id: \.self) { n in
                    let on = marks.contains(n)
                    part(n, show: on)
                        .scaleEffect(on ? 0.3 + 0.7 * markIn : 0.3)
                        .offset(y: 3 * sin(now.timeIntervalSinceReferenceDate * 1000 / 260) + (n == "rig5-fx-sweat" ? min(1, t / 1400) * 16 : 0))
                        .opacity(on ? markIn : 0)
                }
            }
            .frame(width: RigArt.canvas.width, height: RigArt.canvas.height, alignment: .topLeading)
            .rotationEffect(.degrees(headRot), anchor: UnitPoint(x: 0.5, y: 0.45))
            .offset(y: headDrop - 1.4 * br)
        }
        .frame(width: RigArt.canvas.width, height: RigArt.canvas.height, alignment: .topLeading)
        .scaleEffect(x: 1 - 0.006 * br, y: 1 + 0.012 * br, anchor: .bottom)
        .scaleEffect(scale, anchor: .topLeading)
        .frame(width: RigArt.canvas.width * scale, height: height, alignment: .topLeading)
        .offset(y: y * height / 148)
    }
}
