import SwiftUI

/// Writing practice, as the web's phone layout: one big box per character, the help
/// fading as each character is written (`WriteGuidance`, from `ProgressStore.timesWritten`).
/// The first time the strokes play, then you trace with the next stroke lit up; the second,
/// the outline stays; from the third, a blank box. A stroke only counts if it matches, in
/// order; the stroke is shown after a miss or two. "Show me" plays the strokes again.
struct WriteView: View {
    let ex: Exercise
    let answered: Bool
    var done: () -> Void

    @State private var index = 0
    @State private var finishedChars = 0
    @State private var replay = 0
    /// Times each character had been written when the exercise opened: its help holds for
    /// the whole exercise, though finishing a character counts straight away.
    @State private var timesAtStart: [String: Int]? = nil
    @Environment(ProgressStore.self) private var progress
    private var chars: [String] { ex.card.word.hanzi.filter(Course.isHan).map(String.init) }

    private func guidance(_ ch: String) -> WriteGuidance {
        WriteGuidance(timesWritten: timesAtStart?[ch] ?? progress.timesWritten(ch))
    }

    var body: some View {
        let w = ex.card.word, ch = chars[min(index, chars.count - 1)]
        let level = guidance(ch)
        VStack(spacing: 10) {
            HStack(spacing: 12) {
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
                WritingBox(char: ch, size: side, level: level, checking: progress.prefs.checkStrokes, replay: replay) {
                    progress.recordWritten(ch)
                    finishedChars = index + 1
                    if index == chars.count - 1 { done() }
                }
                .id("\(ch)-\(index)")
                .frame(maxWidth: .infinity)
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 468)
            HStack(alignment: .center, spacing: 10) {
                Text(level.note).font(.nunito(13.5)).foregroundStyle(Color.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { replay += 1 } label: {
                    Label("Show me", systemImage: "play.circle.fill")
                        .font(.nunito(13.5, .bold)).foregroundStyle(Color.accent)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.accent.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .fixedSize()
            }
            if finishedChars > index && index < chars.count - 1 {
                Button("Next character (\(index + 1)/\(chars.count)) →") { withAnimation { index += 1 } }
                    .buttonStyle(WideButton())
            }
        }
        .onAppear {
            if timesAtStart == nil {
                var t: [String: Int] = [:]
                for c in chars where t[c] == nil { t[c] = progress.timesWritten(c) }
                timesAtStart = t
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

/// One character to write, stroke by stroke, as the web's HanziWriter quiz: the pen draws
/// on a UIKit surface (`InkCanvas`); a right stroke's ink fades as the real stroke draws in,
/// a wrong one flashes red and goes; the help follows `WriteGuidance` (the strokes played
/// first, the pale outline, the next stroke lit up, a trace after misses); the finished
/// character lights up once before the tick.
struct WritingBox: View {
    let char: String
    let size: CGFloat
    var checking = true
    /// Bumped by "Show me": the strokes play again.
    var replay = 0
    var complete: () -> Void

    /// The help, fixed when the box appears (finishing the character counts at once).
    @State private var level: WriteGuidance
    @State private var current = 0
    /// Misses on the current stroke.
    @State private var misses = 0
    @State private var intro: Bool
    @State private var finishing = false
    @State private var glow = false
    @State private var done = false
    @State private var drawn = 0
    /// Free tracing: the brush outlines of every stroke, kept.
    @State private var freeInk: [Path] = []

    init(char: String, size: CGFloat, level: WriteGuidance, checking: Bool = true, replay: Int = 0,
         animate: Bool = true, complete: @escaping () -> Void) {
        self.char = char
        self.size = size
        self.checking = checking
        self.replay = replay
        self.complete = complete
        _level = State(initialValue: level)
        _intro = State(initialValue: level.playsDemo && animate)
    }

    private var data: CharStrokes? { StrokeData.shared.chars[char] }
    private var space: GlyphSpace { GlyphSpace(size: size) }
    /// Waiting for the current stroke (not playing the strokes, not finished).
    private func waiting(_ d: CharStrokes) -> Bool { checking && !intro && !done && !finishing && current < d.count }

    var body: some View {
        ZStack {
            GridSquare()
            if let d = data {
                // the whole character, pale, under the pen
                if level.showsOutline { strokes(d, Array(0..<d.count), Color.line) }
                // the next stroke lit up: a glow, a dot where it starts, an arrow its way
                if waiting(d) && level.highlights(misses: misses) {
                    guide(d, current)
                        .id("guide-\(current)")
                        .transition(.opacity)
                }
                // the hint: the next stroke traced along its centre line, again at each further miss
                if waiting(d) && level.traces(misses: misses) {
                    reveal(d, current, Color.accent.opacity(0.42), duration: 0.6)
                        .id("hint-\(current)-\(misses)")
                        .transition(.opacity)
                }
                // strokes written so far: each draws in as it's accepted
                ForEach(0..<current, id: \.self) { i in
                    reveal(d, i, Color.accent, duration: 0.3)
                }
                // the finish: the whole character lights up once
                strokes(d, Array(0..<d.count), Color.good)
                    .opacity(glow ? 1 : 0)
                    .allowsHitTesting(false)
                // the strokes played in order (the first time, and "Show me")
                if intro {
                    GlyphAnimation(char: char, size: size, loops: 1) {
                        withAnimation(.easeOut(duration: 0.25)) { intro = false }
                    }
                    .transition(.opacity)
                }
                // free tracing: every stroke stays
                Path { p in for s in freeInk { p.addPath(s) } }
                    .fill(Color.accent)
                    .allowsHitTesting(false)
                // the pen
                InkCanvas(enabled: !intro && !done && !finishing, brush: .forBox(size)) { finishStroke($0) }
                if done {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 30)).foregroundStyle(Color.good)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(8)
                        .transition(.scale.combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            } else {
                Text(char).font(.hanzi(size * 0.7))
            }
        }
        .frame(width: size, height: size)
        .sensoryFeedback(.impact(weight: .light), trigger: drawn)
        .sensoryFeedback(.error, trigger: misses) { _, n in n > 0 }
        .sensoryFeedback(.success, trigger: done) { _, n in n }
        .onChange(of: replay) { _, _ in
            withAnimation(.easeOut(duration: 0.2)) { intro = true }
        }
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

    /// Stroke `i` drawn in along its median. The mask is as wide as HanziWriter's (200 units).
    private func reveal(_ d: CharStrokes, _ i: Int, _ color: Color, duration: Double) -> StrokeReveal {
        let sp = space
        let outline = Path { p in p.addPath(SVGPath.stroke(d.strokes[i]), transform: sp.transform) }
        return StrokeReveal(outline: outline, median: sp.polyline(d.median(i)),
                            width: 200 * sp.s, color: color, duration: duration)
    }

    /// Stroke `i` lit up, with where it starts and which way it goes.
    private func guide(_ d: CharStrokes, _ i: Int) -> StrokeGuide {
        let sp = space
        let outline = Path { p in p.addPath(SVGPath.stroke(d.strokes[i]), transform: sp.transform) }
        return StrokeGuide(outline: outline, median: d.median(i).map(sp.toView), size: size)
    }

    /// A finished stroke from the pen, in view space. The answer says how its ink leaves.
    private func finishStroke(_ stroke: InkCanvas.Stroke) -> InkCanvas.Verdict {
        guard let d = data, !done, !finishing else { return .dropped }
        let points = stroke.points
        if !checking {
            guard !points.isEmpty else { return .dropped }
            freeInk.append(Path(stroke.outline))
            return .kept
        }
        guard current < d.count else { return .dropped }
        // a tap isn't a stroke, and isn't a miss (HanziWriter ignores one too)
        guard StrokeMatch.length(points) >= 2 else { return .dropped }
        let glyph = InkGeometry.thin(points, minDistance: 2).map(space.toGlyph)
        if StrokeMatch.matches(glyph, char: d, stroke: current, leniency: StrokeMatch.leniency, outlineVisible: level.showsOutline) {
            current += 1
            drawn += 1
            withAnimation(.easeOut(duration: 0.2)) { misses = 0 }
            if current == d.count { finish() }
            return .accepted
        }
        withAnimation(.easeInOut(duration: 0.3)) { misses += 1 }
        return .rejected
    }

    /// The last stroke draws in, the whole character lights up once (HanziWriter's
    /// highlightOnComplete), then the tick and the success flow.
    private func finish() {
        finishing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.18)) { glow = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                withAnimation(.easeIn(duration: 0.35)) { glow = false }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { done = true }
                complete()
            }
        }
    }
}

/// The next stroke lit up for someone learning it: its outline tinted with a soft,
/// breathing glow, a dot where it starts, and a short line from the dot along its centre
/// line to an arrowhead, the way to draw it.
struct StrokeGuide: View {
    let outline: Path
    /// The stroke's centre line in view space, from where it starts.
    let median: [CGPoint]
    let size: CGFloat
    var color: Color = .accent
    @State private var breathe = false

    var body: some View {
        let lengths = InkGeometry.arcLengths(median)
        let total = lengths.last ?? 0
        let reach = min(total * 0.45, max(size * 0.14, 14))
        let arrow = InkGeometry.along(median, distance: reach)
        let dot = max(7, size * 0.03)
        let head = max(5, size * 0.03)
        let line = max(1.5, size * 0.007)
        ZStack {
            outline.fill(color.opacity(0.4))
                .blur(radius: max(2, size * 0.016))
                .opacity(breathe ? 0.9 : 0.4)
            outline.fill(color.opacity(0.18))
            if let a = arrow, let s = median.first {
                Path { p in
                    p.move(to: s)
                    for (q, l) in zip(median, lengths).dropFirst() where l < reach { p.addLine(to: q) }
                    p.addLine(to: a.point)
                }
                .stroke(color.opacity(0.85), style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
                Path { p in
                    let back = CGPoint(x: a.point.x - a.direction.x * head, y: a.point.y - a.direction.y * head)
                    let nx = -a.direction.y * head * 0.7, ny = a.direction.x * head * 0.7
                    p.move(to: CGPoint(x: back.x + nx, y: back.y + ny))
                    p.addLine(to: a.point)
                    p.addLine(to: CGPoint(x: back.x - nx, y: back.y - ny))
                }
                .stroke(color, style: StrokeStyle(lineWidth: line * 1.4, lineCap: .round, lineJoin: .round))
            }
            if let s = median.first {
                Circle().fill(color)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 1.5))
                    .frame(width: dot, height: dot)
                    .position(s)
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { breathe = true }
        }
    }
}

/// One stroke of a character drawn in along its centre line, as HanziWriter reveals a
/// stroke; once in, it's the whole outline, unmasked.
struct StrokeReveal: View {
    let outline: Path
    let median: Path
    let width: CGFloat
    let color: Color
    var duration = 0.3
    @State private var progress: CGFloat = 0
    @State private var full = false

    var body: some View {
        outline.fill(color)
            .mask {
                if full {
                    Rectangle()
                } else {
                    median.trim(from: 0, to: progress)
                        .stroke(style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
                }
            }
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeOut(duration: duration)) { progress = 1 } completion: { full = true }
            }
    }
}

/// The strokes drawn one after another, in order, as HanziWriter animates them, at a calm
/// pace (half a second a stroke). The clock starts when the view is really on screen (a
/// `task`, not the view's creation, and not an `onChange`, which never sees the first
/// value), so the first playing isn't missed. Tap to play it again.
struct GlyphAnimation: View {
    let char: String
    let size: CGFloat
    var loops = 1
    var finished: (() -> Void)? = nil
    @State private var start: Date? = nil
    @State private var over = false
    @State private var run = 0

    static let perStroke = 0.5, gap = 0.15, pause = 0.6

    /// Seconds for one playing of `n` strokes and the pause after them.
    static func duration(strokes n: Int) -> Double { Double(n) * (perStroke + gap) + pause }

    var body: some View {
        let d = StrokeData.shared.chars[char]
        let sp = GlyphSpace(size: size)
        let n = d?.count ?? 0
        let one = Self.duration(strokes: n)
        let plays = max(1, loops)
        TimelineView(.animation(paused: over || start == nil)) { tl in
            let raw = start.map { tl.date.timeIntervalSince($0) } ?? 0
            let loop = max(0, min(Double(plays - 1), floor(raw / one)))
            let t = over || raw >= one * Double(plays) ? one : raw - loop * one
            ZStack {
                if let d {
                    ForEach(0..<n, id: \.self) { i in
                        let p = max(0, min(1, (t - Double(i) * (Self.perStroke + Self.gap)) / Self.perStroke))
                        Path { $0.addPath(SVGPath.stroke(d.strokes[i]), transform: sp.transform) }
                            .fill(Color.accent)
                            .mask(medianPath(d.median(i), sp).trim(from: 0, to: p)
                                .stroke(style: StrokeStyle(lineWidth: 150 * sp.s, lineCap: .round, lineJoin: .round)))
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .background { if size < 100 { GridSquare() } }
        .contentShape(Rectangle())
        .onTapGesture { run += 1 }
        .task(id: run) {
            over = false
            start = Date()
            try? await Task.sleep(nanoseconds: UInt64(one * Double(plays) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            over = true
            finished?()
        }
    }

    private func medianPath(_ pts: [CGPoint], _ sp: GlyphSpace) -> Path {
        Path { p in
            guard let f = pts.first else { return }
            p.move(to: sp.toView(f))
            pts.dropFirst().forEach { p.addLine(to: sp.toView($0)) }
        }
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
                                        WritingBox(char: ch, size: cell, level: r == 0 ? .full : .memory, animate: r == 0 && c == 0) {}
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
