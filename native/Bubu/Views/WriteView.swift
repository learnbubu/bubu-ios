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
    @Environment(ProgressStore.self) private var progress
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
                WritingBox(char: ch, size: side, stage: stage, checking: progress.prefs.checkStrokes) {
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

    var checking = true
    @State private var freeInk: [[CGPoint]] = []
    @State private var stroking = false

    init(char: String, size: CGFloat, stage: Int, checking: Bool = true, animate: Bool = true, complete: @escaping () -> Void) {
        self.char = char; self.size = size; self.stage = stage; self.checking = checking; self.complete = complete
        _intro = State(initialValue: stage == 0 && animate)
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
                // free tracing: every stroke stays
                Path { p in for s in freeInk { if let f = s.first { p.move(to: f); s.dropFirst().forEach { p.addLine(to: $0) } } } }
                    .stroke(Color.accent, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
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
                // a new stroke: whatever a cancelled one left behind goes
                if !stroking { stroking = true; ink = [] }
                ink.append(v.location)
            }
            .onEnded { _ in stroking = false; check() })
        .sensoryFeedback(.impact(weight: .light), trigger: drawn)
        .sensoryFeedback(.error, trigger: misses) { _, n in n > 0 }
        .sensoryFeedback(.success, trigger: done) { _, n in n }
        .overlay(alignment: .bottomTrailing) {
            if !checking && !freeInk.isEmpty {
                HStack(spacing: 6) {
                    Button { _ = freeInk.popLast() } label: { Image(systemName: "arrow.uturn.backward") }
                    Button { freeInk = [] } label: { Image(systemName: "xmark") }
                }
                .font(.system(size: 15, weight: .bold)).foregroundStyle(Color.muted)
                .buttonStyle(.bordered).padding(8)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if !checking && !done {
                Button("Done") { withAnimation { done = true }; complete() }
                    .font(.nunitoXB(14)).foregroundStyle(Color.onAccent)
                    .padding(.horizontal, 14).padding(.vertical, 7).background(Color.accent, in: Capsule())
                    .padding(8)
            }
        }
    }

    private func strokes(_ d: CharStrokes, _ idx: [Int], _ color: Color) -> some View {
        Path { p in for i in idx where i < d.count { p.addPath(SVGPath.stroke(d.strokes[i]), transform: space.transform) } }
            .fill(color)
    }

    private func check() {
        if !checking { if !ink.isEmpty { freeInk.append(ink); ink = [] }; return }
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
        TimelineView(.animation(paused: reported)) { tl in
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

/// A writing sheet (字帖) for a word, as the web's: a tab per character, the character
/// with its strokes to watch, and a 4 × 4 grid, the top row to trace, the rest from memory.
struct WritingSheetPage: View {
    let hanzi: String
    @State private var index = 0
    @State private var round = 0
    @State private var animating = false
    private let course = Course.shared

    var body: some View {
        let chars = hanzi.filter(Course.isHan).map(String.init).filter(StrokeData.shared.has)
        let word = course.cards.first { $0.word.hanzi == hanzi }?.word
        ScrollView {
            if chars.isEmpty {
                Text("No stroke data for this word yet.").font(.nunito(15)).foregroundStyle(Color.muted).padding(.top, 40)
            } else {
                let ch = chars[min(index, chars.count - 1)]
                VStack(alignment: .leading, spacing: 14) {
                    if chars.count > 1 {
                        HStack(spacing: 8) {
                            ForEach(Array(chars.enumerated()), id: \.offset) { i, c in
                                Button { index = i; round += 1 } label: {
                                    Text(c).font(.hanzi(22, .bold)).foregroundStyle(i == index ? Color.onAccent : Color.ink)
                                        .frame(width: 46, height: 46)
                                        .background(i == index ? Color.accent : Color.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.line))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    HStack(spacing: 14) {
                        GlyphAnimation(char: ch, size: 96, loops: 1).id("\(ch)-\(round)-big")
                            .onTapGesture { round += 1 }
                        VStack(alignment: .leading, spacing: 3) {
                            PinyinText(pinyin: word?.pinyin ?? (CharData.shared.chars[ch]?.p ?? ""), size: 18)
                            Text(word?.en ?? CharData.shared.meaning(ch)).font(.nunito(15)).foregroundStyle(Color.ink)
                            Text("笔画 (strokes): \(StrokeData.shared.chars[ch]?.count ?? 0)").font(.nunito(13)).foregroundStyle(Color.muted)
                            let ex = examples(ch)
                            if !ex.isEmpty {
                                Text("组词: " + ex.map { "\($0.word.hanzi) (\($0.word.pinyin))" }.joined(separator: "，"))
                                    .font(.nunito(13)).foregroundStyle(Color.muted)
                            }
                        }
                    }
                    GeometryReader { g in
                        let cell = floor(g.size.width / 4)
                        VStack(spacing: 0) {
                            ForEach(0..<4, id: \.self) { r in
                                HStack(spacing: 0) {
                                    ForEach(0..<4, id: \.self) { c in
                                        WritingBox(char: ch, size: cell, stage: r == 0 ? 0 : 2, animate: r == 0 && c == 0) {}
                                    }
                                }
                            }
                        }
                        .id("\(ch)-\(round)")
                    }
                    .aspectRatio(1, contentMode: .fit)
                    Text("Trace the top row; write the rest from memory. Wrong strokes won't register; a hint appears after a few misses.")
                        .font(.nunito(13)).foregroundStyle(Color.muted)
                    Button { round += 1 } label: { Label("Clear the sheet", systemImage: "arrow.counterclockwise") }
                        .buttonStyle(WideButton(ghost: true))
                }
                .padding(18)
            }
        }
        .navigationTitle("Writing sheet · \(hanzi)")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Other words with this character (web: exampleWords).
    private func examples(_ ch: String) -> [Card] {
        var seen = Set<String>(), out: [Card] = []
        for c in course.cards where c.word.hanzi != hanzi && c.word.hanzi.count > 1 && c.word.hanzi.contains(ch) && seen.insert(c.word.hanzi).inserted {
            out.append(c); if out.count >= 4 { break }
        }
        return out
    }
}
