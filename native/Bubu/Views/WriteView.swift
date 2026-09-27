import SwiftUI

/// Writing practice, as the web's phone layout: one big box per character, the
/// help fading as the word is learnt. New: the strokes play, then you trace.
/// Learning: the first part is shown. Known: a blank box. A stroke only counts
/// if it matches, in order; a hint flashes after a few misses.
struct WriteView: View {
    let ex: Exercise
    let answered: Bool
    var done: () -> Void

    @State private var index = 0
    @State private var finishedChars = 0
    private var chars: [String] { ex.card.word.hanzi.filter(Course.isHan).map(String.init) }

    static let stageInfo: [(chip: String, note: String, hint: Int)] = [
        ("New", "Watch the strokes, then trace over them.", 1),
        ("Learning", "The first part is shown. Write the whole character.", 2),
        ("From memory", "Write it from memory. A hint shows after a few misses.", 3),
    ]

    var body: some View {
        let w = ex.card.word, ch = chars[min(index, chars.count - 1)]
        let stage = ex.writeStage
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                if stage == 0 { GlyphAnimation(char: ch, size: 50, loops: 2).id(ch) } else { PeekBox(char: ch, size: 50) }
                VStack(alignment: .leading, spacing: 1) {
                    PinyinText(pinyin: w.pinyin, size: 18.4)
                    Text(w.en + (chars.count > 1 ? "  ·  \(index + 1)/\(chars.count)" : ""))
                        .font(.nunito(14.4)).foregroundStyle(Color.muted).lineLimit(2)
                }
                Spacer(minLength: 0)
                SpeakerButton(text: w.hanzi)
            }
            GeometryReader { g in
                let side = min(g.size.width - 8, 460)
                WritingBox(char: ch, size: side, stage: stage) {
                    finishedChars = index + 1
                    if index == chars.count - 1 { done() }
                }
                .id("\(ch)-\(index)")
                .frame(maxWidth: .infinity)
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 468)
            Text(Self.stageInfo[stage].note).font(.nunito(13.5)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
            if finishedChars > index && index < chars.count - 1 {
                Button("Next character (\(index + 1)/\(chars.count)) →") { withAnimation { index += 1 } }
                    .buttonStyle(WideButton())
            }
        }
    }
}

/// A 田字格 practice square: dashed centre lines and diagonals.
struct GridSquare: View {
    var body: some View {
        GeometryReader { g in
            let s = g.size.width
            Path { p in
                p.move(to: .init(x: s / 2, y: 0)); p.addLine(to: .init(x: s / 2, y: s))
                p.move(to: .init(x: 0, y: s / 2)); p.addLine(to: .init(x: s, y: s / 2))
                p.move(to: .zero); p.addLine(to: .init(x: s, y: s))
                p.move(to: .init(x: s, y: 0)); p.addLine(to: .init(x: 0, y: s))
            }
            .stroke(Color.line, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.line, lineWidth: 1.5))
    }
}

/// One character to write, stroke by stroke.
struct WritingBox: View {
    let char: String
    let size: CGFloat
    let stage: Int
    var complete: () -> Void

    @State private var current = 0
    @State private var ink: [CGPoint] = []
    @State private var misses = 0
    @State private var inkMissed = false
    @State private var hint = false
    @State private var intro: Bool
    @State private var done = false
    @State private var drawn = 0

    init(char: String, size: CGFloat, stage: Int, complete: @escaping () -> Void) {
        self.char = char; self.size = size; self.stage = stage; self.complete = complete
        _intro = State(initialValue: stage == 0)
    }

    private var data: CharStrokes? { StrokeData.shared.chars[char] }
    private var space: GlyphSpace { GlyphSpace(size: size) }

    var body: some View {
        ZStack {
            GridSquare()
            if let d = data {
                // the help for this stage
                if stage == 0 { strokes(d, Array(0..<d.count), Color.line) }
                if stage == 1 { strokes(d, d.guideStrokes, Color.line.opacity(0.8)) }
                if intro { GlyphAnimation(char: char, size: size, loops: 1) { withAnimation { intro = false } } }
                // strokes written so far, and the hint
                strokes(d, Array(0..<current), Color.accent)
                if hint && current < d.count {
                    strokes(d, [current], Color.accent.opacity(0.45)).transition(.opacity)
                }
                // the pen
                Path { p in if let f = ink.first { p.move(to: f); ink.dropFirst().forEach { p.addLine(to: $0) } } }
                    .stroke(inkMissed ? Color.again : Color.accent, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                if done {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 30)).foregroundStyle(Color.good)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(8)
                        .transition(.scale.combined(with: .opacity))
                }
            } else {
                Text(char).font(.hanzi(size * 0.7))
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { v in
                guard !intro, !done, data != nil else { return }
                if inkMissed { ink = []; inkMissed = false }
                ink.append(v.location)
            }
            .onEnded { _ in check() })
        .sensoryFeedback(.impact(weight: .light), trigger: drawn)
        .sensoryFeedback(.error, trigger: misses) { _, n in n > 0 }
        .sensoryFeedback(.success, trigger: done) { _, n in n }
    }

    private func strokes(_ d: CharStrokes, _ idx: [Int], _ color: Color) -> some View {
        Path { p in for i in idx where i < d.count { p.addPath(SVGPath.stroke(d.strokes[i]), transform: space.transform) } }
            .fill(color)
    }

    private func check() {
        guard let d = data, !done, !ink.isEmpty else { return }
        let glyph = ink.map(space.toGlyph)
        if StrokeMatch.matches(glyph, char: d, stroke: current, leniency: 1.4, outlineVisible: stage == 0) {
            withAnimation(.easeOut(duration: 0.2)) {
                current += 1; ink = []; hint = false; misses = 0
            }
            drawn += 1
            if current == d.count {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { done = true }
                complete()
            }
        } else {
            inkMissed = true
            misses += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { if inkMissed { withAnimation { ink = []; inkMissed = false } } }
            if misses >= WriteView.stageInfo[stage].hint {
                withAnimation(.easeInOut(duration: 0.3)) { hint = true }
            }
        }
    }
}

/// The strokes drawn one after another, in order, as HanziWriter animates them.
struct GlyphAnimation: View {
    let char: String
    let size: CGFloat
    var loops = 1
    var finished: (() -> Void)? = nil
    @State private var start = Date()
    @State private var reported = false

    private let perStroke = 0.55, gap = 0.12, pause = 0.6

    var body: some View {
        let d = StrokeData.shared.chars[char]
        let sp = GlyphSpace(size: size)
        TimelineView(.animation) { tl in
            let n = d?.count ?? 0
            let one = Double(n) * (perStroke + gap) + pause
            let raw = tl.date.timeIntervalSince(start)
            let loop = min(Double(loops - 1), floor(raw / one))
            let t = raw >= one * Double(loops) ? one : raw - loop * one
            ZStack {
                if let d {
                    ForEach(0..<n, id: \.self) { i in
                        let p = max(0, min(1, (t - Double(i) * (perStroke + gap)) / perStroke))
                        Path { $0.addPath(SVGPath.stroke(d.strokes[i]), transform: sp.transform) }
                            .fill(Color.accent)
                            .mask(medianPath(d.median(i), sp).trim(from: 0, to: p)
                                .stroke(style: StrokeStyle(lineWidth: 150 * sp.s, lineCap: .round, lineJoin: .round)))
                    }
                }
            }
            .onChange(of: raw >= one * Double(loops)) { _, over in
                if over && !reported { reported = true; finished?() }
            }
        }
        .frame(width: size, height: size)
        .background { if size < 100 { GridSquare() } }
        .contentShape(Rectangle())
        .onTapGesture { start = Date(); reported = false }
    }

    private func medianPath(_ pts: [CGPoint], _ sp: GlyphSpace) -> Path {
        Path { p in
            guard let f = pts.first else { return }
            p.move(to: sp.toView(f))
            pts.dropFirst().forEach { p.addLine(to: sp.toView($0)) }
        }
    }
}

/// Stage 1 and 2: a small box that shows the character's strokes for a moment.
struct PeekBox: View {
    let char: String
    let size: CGFloat
    @State private var open = false
    var body: some View {
        Button { open = true; DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) { open = false } } label: {
            ZStack {
                if open { GlyphAnimation(char: char, size: size, loops: 1) }
                else {
                    VStack(spacing: 1) {
                        Image(systemName: "eye").font(.system(size: 15))
                        Text("Peek").font(.nunito(11, .bold))
                    }
                    .foregroundStyle(Color.muted)
                    .frame(width: size, height: size)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.line, lineWidth: 1.5))
                }
            }
        }
        .buttonStyle(.plain)
    }
}
