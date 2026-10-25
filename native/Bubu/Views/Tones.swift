import SwiftUI

extension Pinyin {
    /// Every valid syllable, as the web's PY_SYL.
    static let syllableSet: Set<String> = {
        let initials = ["", "b", "p", "m", "f", "d", "t", "n", "l", "g", "k", "h", "j", "q", "x", "zh", "ch", "sh", "r", "z", "c", "s", "y", "w"]
        let finals = ["a", "o", "e", "ê", "ai", "ei", "ao", "ou", "an", "en", "ang", "eng", "ong", "er",
                      "i", "ia", "ie", "iao", "iu", "ian", "in", "iang", "ing", "iong",
                      "u", "ua", "uo", "uai", "ui", "uan", "un", "uang", "ueng",
                      "ü", "üe", "üan", "ün", "v", "ve", "van", "vn"]
        var set = Set<String>()
        for i in initials { for f in finals { set.insert(i + f) } }
        ["a", "o", "e", "ê", "ai", "ei", "ao", "ou", "an", "en", "ang", "eng", "er", "yi", "wu", "yu", "ye", "yue", "yuan", "yun", "yin", "ying",
         "n", "ng", "m", "hm", "hng", "lo", "yo", "ju", "qu", "xu", "jue", "xue", "que", "juan", "xuan", "quan", "jun", "xun", "qun",
         "nü", "nüe", "lü", "lüe", "nv", "nve", "lv", "lve"].forEach { set.insert($0) }
        return set
    }()

    /// A run of pinyin letters cut into syllables, longest match first (web: splitPySyllables).
    static func split(_ run: String) -> [String]? {
        let chars = Array(run)
        let base = chars.map { String(decode[$0]?.0 ?? $0).lowercased() }
        var i = 0, cuts = [0]
        while i < chars.count {
            var matched = 0
            for len in stride(from: min(6, chars.count - i), through: 1, by: -1) where syllableSet.contains(base[i..<i + len].joined()) {
                matched = len; break
            }
            if matched == 0 { return nil }
            i += matched; cuts.append(i)
        }
        return zip(cuts, cuts.dropFirst()).map { String(chars[$0..<$1]) }
    }

    /// Every syllable in a pinyin string (web: sylls).
    static func syllables(_ py: String) -> [String] {
        let letters = CharacterSet.letters
        return py.components(separatedBy: CharacterSet(charactersIn: " ,.!?;:'’-").union(.whitespaces))
            .filter { !$0.isEmpty }
            .flatMap { run -> [String] in
                let clean = String(run.unicodeScalars.filter { letters.contains($0) })
                if clean.isEmpty { return [] }
                if clean.first?.isUppercase == true { return [clean] }   // a name: leave it whole
                return split(clean) ?? [clean]
            }
    }
}

/// The pitch of a tone pair, drawn on the classic 1–5 scale (web: pairSvg).
struct TonePairShape: View {
    let pair: (Int, Int)
    var body: some View {
        Canvas { ctx, size in
            let sx = size.width / 70, sy = size.height / 36
            func y(_ v: CGFloat) -> CGFloat { (30 - v * 5 + 3) * sy }
            for (k, t) in [pair.0, pair.1].enumerated() {
                let x0 = CGFloat(k * 36) + 3
                let colour = Color.tones[t - 1]
                var p = Path()
                switch t {
                case 1: p.move(to: .init(x: x0 * sx, y: y(5))); p.addLine(to: .init(x: (x0 + 26) * sx, y: y(5)))
                case 2: p.move(to: .init(x: x0 * sx, y: y(3))); p.addLine(to: .init(x: (x0 + 26) * sx, y: y(5)))
                case 3:
                    p.move(to: .init(x: x0 * sx, y: y(2)))
                    p.addQuadCurve(to: .init(x: (x0 + 14) * sx, y: y(1)), control: .init(x: (x0 + 10) * sx, y: y(0.2)))
                    p.addQuadCurve(to: .init(x: (x0 + 26) * sx, y: y(4)), control: .init(x: (x0 + 18) * sx, y: y(1.8)))
                case 4: p.move(to: .init(x: x0 * sx, y: y(5))); p.addLine(to: .init(x: (x0 + 26) * sx, y: y(1)))
                default:
                    ctx.fill(Path(ellipseIn: CGRect(x: (x0 + 8) * sx - 3.2, y: y(2) - 3.2, width: 6.4, height: 6.4)), with: .color(colour))
                    continue
                }
                ctx.stroke(p, with: .color(colour), style: StrokeStyle(lineWidth: 4.2, lineCap: .round))
            }
        }
        .aspectRatio(70 / 36, contentMode: .fit)
    }
}

/// Your ear for tones, kept: how often each tone (and each pair) has been heard right. ("2" a single tone, "2+3" a pair.)
enum ToneRecord {
    static let key = "bubu.tones"
    static func load() -> [String: [Int]] {
        guard !Launch.underTests, let d = UserDefaults.standard.data(forKey: key),
              let m = try? JSONDecoder().decode([String: [Int]].self, from: d) else { return [:] }
        return m
    }
    static func add(_ k: String, right: Bool) {
        guard !Launch.underTests else { return }
        var m = load()
        var v = m[k] ?? [0, 0]
        v[0] += right ? 1 : 0; v[1] += 1
        m[k] = v
        if let d = try? JSONEncoder().encode(m) { UserDefaults.standard.set(d, forKey: key) }
    }
    /// how often it's right (nil: fewer than three tries)
    static func share(_ m: [String: [Int]], _ k: String) -> Double? {
        guard let v = m[k], v[1] >= 3 else { return nil }
        return Double(v[0]) / Double(v[1])
    }
}

/// The tone trainer (the owner, 25 Oct 2026: "any way we could improve on it?"): in the lessons' look (raised tiles,
/// the shiny bar and its run, the feedback over the foot, the button pinned at the bottom). Its home is your four tones
/// (how often you hear each right, an example to hear), the pairs that trip you up, and single tones or pairs. A round:
/// hear a word, pick each syllable's tone in turn (no guessing from four whole answers), check; then its pitch line
/// draws in its tones' colours as it's said again. Rounds lean on the pairs you miss.
struct TonesPage: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.dismiss) private var dismiss
    private let course = Course.shared
    static let rounds = 10
    static let names = [1: "high", 2: "rising", 3: "dipping", 4: "falling", 5: "light"]
    static let short = [1: "high", 2: "rising", 3: "dip", 4: "falling"]
    /// each tone's example to hear, as the primer's: 妈 麻 马 骂
    static let examples: [(hanzi: String, pinyin: String, en: String)] = [("妈", "mā", "mother"), ("麻", "má", "numb"), ("马", "mǎ", "horse"), ("骂", "mà", "to scold")]

    /// (Tricky is gone: Pairs already leans on the ones you miss, and 3+3 words come up in it; the owner, 25 Oct 2026)
    enum Level: String { case single, pairs }
    struct Q { let card: Card; let tones: [Int]; let sandhi: Bool }

    @State private var record: [String: [Int]] = [:]
    @State private var level: Level = .pairs
    @State private var playing = false            // the rounds, or the home
    @State private var qs: [Q] = []
    @State private var index = 0
    @State private var picks: [Int?] = []
    @State private var checked: Bool?             // nil: answering; else right or wrong
    @State private var right = 0
    @State private var combo = 0
    @State private var misses: [String: Int] = [:]
    @State private var finished = false
    @State private var xp = 0
    @State private var sounding = false           // the word playing (the listening bars move)
    @State private var drawn: Double = 0          // the pitch line drawn, 0…1
    @State private var barFrame: CGRect = .zero
    @State private var burst: Int?

    /// A word's two tones, when what you hear matches what's written (no 3+3, 不 or 一).
    static func pair(_ c: Card) -> [Int]? {
        let han = c.word.hanzi.filter(Course.isHan), ss = Pinyin.syllables(c.word.pinyin)
        guard han.count == 2, ss.count == 2, !c.word.hanzi.contains("不"), !c.word.hanzi.contains("一") else { return nil }
        let a = toneOf(ss[0]), b = toneOf(ss[1])
        if a == 5 || b == 5 || (a == 3 && b == 3) { return nil }
        return [a, b]
    }
    /// a one-character word's tone (1–4)
    static func single(_ c: Card) -> Int? {
        let han = c.word.hanzi.filter(Course.isHan), ss = Pinyin.syllables(c.word.pinyin)
        guard han.count == 1, ss.count == 1 else { return nil }
        let t = toneOf(ss[0])
        return (1...4).contains(t) ? t : nil
    }
    /// a 3+3 word, said 2+3 (the first dip rises)
    static func sandhi(_ c: Card) -> Bool {
        let han = c.word.hanzi.filter(Course.isHan), ss = Pinyin.syllables(c.word.pinyin)
        return han.count == 2 && ss.count == 2 && toneOf(ss[0]) == 3 && toneOf(ss[1]) == 3
    }

    var body: some View {
        Group {
            if finished { results }
            else if playing && index < qs.count { roundView(qs[index]) }
            else { home }
        }
        .background(Color.bg.ignoresSafeArea())
        .overlay { if let n = burst { FirecrackerBurst(n: n, bar: barFrame).id(n).ignoresSafeArea().allowsHitTesting(false) } }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear { record = ToneRecord.load(); if record.isEmpty { level = .single } }
    }

    // MARK: home: your four tones, the pairs to work on, single or pairs

    /// The tones home (the owner, 25 Oct 2026: the grid confused; then, less empty space): four cards, one a tone, its
    /// shape, how often you hear it right and an example to tap and hear (the quick reference "How tones work" was);
    /// the few pairs that trip you up; Single tones or Pairs; Practise pinned at the foot.
    private var home: some View {
        // (in steps, typed: as one chain it was too much for the compiler, the Mac's build of 0.2.36)
        var keys: [String] = []
        for a in 1...4 { for b in 1...4 where !(a == 3 && b == 3) { keys.append("\(a)+\(b)") } }
        var shares: [(String, Double)] = []
        for k in keys { if let v = ToneRecord.share(record, k), v < 0.85 { shares.append((k, v)) } }
        let weak: [(String, Double)] = Array(shares.sorted { $0.1 < $1.1 }.prefix(3))
        let pairsTried = record.keys.contains { $0.contains("+") }
        return VStack(spacing: 0) {
            PageBar(title: "Tones") { EmptyView() }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("YOUR FOUR TONES · TAP TO HEAR").font(.nunito(11.5, .black)).tracking(1.1).foregroundStyle(Color.muted).padding(.horizontal, 2)
                    VStack(spacing: 10) {
                        HStack(spacing: 10) { toneCard(1); toneCard(2) }
                        HStack(spacing: 10) { toneCard(3); toneCard(4) }
                    }
                    Text("PAIRS TO WORK ON").font(.nunito(11.5, .black)).tracking(1.1).foregroundStyle(Color.muted)
                        .padding(.horizontal, 2).padding(.top, 8)
                    if weak.isEmpty {
                        Text(pairsTried ? "None trip you up just now. Nice ear!" : "Practise a few rounds of pairs, and the ones that trip you up show here.")
                            .font(.nunito(13.5, .semibold)).foregroundStyle(Color.muted)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14).padding(.vertical, 12)
                            .background(Color.line.opacity(0.45), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else {
                        ForEach(weak, id: \.0) { w in
                            let ab = w.0.split(separator: "+").compactMap { Int($0) }
                            HStack(spacing: 12) {
                                TonePairShape(pair: (ab[0], ab[1])).frame(width: 58)
                                Text("\(Self.names[ab[0]]!) + \(Self.names[ab[1]]!)").font(.nunito(14.5, .heavy)).foregroundStyle(Color.ink)
                                Spacer(minLength: 4)
                                Text("\(Int((w.1 * 100).rounded()))%").font(.nunito(14, .black)).foregroundStyle(Self.shade(w.1))
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(Color.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.line, lineWidth: 1.5))
                        }
                    }
                    levelSwitch.padding(.top, 8)
                }
                .padding(.horizontal, 18).padding(.top, 4).padding(.bottom, 12)
            }
            Button { start() } label: { Text("Practise · \(Self.rounds) rounds") }
                .buttonStyle(RaisedButton(fill: Color.accent, ink: Color.onAccent))
                .padding(.horizontal, 18).padding(.bottom, 14)
        }
    }

    /// green when heard well, gold getting there, red when it trips you up
    static func shade(_ s: Double) -> Color { s >= 0.85 ? .good : s >= 0.65 ? .gold : .again }

    /// A tone's card: its shape, how often you hear it right, its example to tap and hear, a bar.
    private func toneCard(_ t: Int) -> some View {
        let s = ToneRecord.share(record, "t\(t)") ?? ToneRecord.share(record, "\(t)")
        let ex = Self.examples[t - 1]
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                ToneShape(tone: t).frame(width: 44, height: 24)
                Spacer()
                Text(s.map { "\(Int(($0 * 100).rounded()))%" } ?? "–").font(.nunito(14, .black)).foregroundStyle(s.map(Self.shade) ?? Color.muted)
            }
            Text(Self.names[t]!.capitalized).font(.nunito(16, .black)).foregroundStyle(Color.ink)
            Button { Speech.shared.speak(ex.hanzi) } label: {
                HStack(spacing: 6) {
                    Text(ex.hanzi).font(.hanzi(21, .bold)).foregroundStyle(Color.ink)
                    Text("\(ex.pinyin) · \(ex.en)").font(.nunito(12, .bold)).foregroundStyle(Color.muted).lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 2)
                    Image(systemName: "speaker.wave.2.fill").font(.system(size: 13)).foregroundStyle(Color.accent)
                }
                .padding(.horizontal, 9).padding(.vertical, 6)
                .background(Color.bg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(PressDown(depth: 1))
            .accessibilityLabel("Hear \(ex.hanzi), \(ex.pinyin)")
            Bar(value: s ?? 0, height: 7, fill: s.map(Self.shade) ?? Color.line)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.line, lineWidth: 1.5))
        .background(Color.line, in: RoundedRectangle(cornerRadius: 16, style: .continuous).offset(y: 3))
    }

    /// Single tones or Pairs
    private var levelSwitch: some View {
        HStack(spacing: 3) {
            ForEach([(Level.single, "Single tones"), (Level.pairs, "Pairs")], id: \.0) { l in
                Button { withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) { level = l.0 } } label: {
                    Text(l.1).font(.nunito(14, .black)).foregroundStyle(level == l.0 ? Color.ink : Color.muted)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background {
                            if level == l.0 {
                                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.panel)
                                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.line.opacity(0.7), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    // MARK: the rounds

    private func start() {
        let met = { (c: Card) in progress.srs[c.id] != nil || progress.isDone(c.lessonId) }
        let words = course.cards.filter { !$0.isSentence }
        var seen = Set<String>()
        func pool(_ f: (Card) -> Q?) -> [Q] {
            let all = words.compactMap(f).filter { seen.insert($0.card.word.hanzi).inserted }
            let known = all.filter { met($0.card) }
            return known.count >= 6 ? known : all.filter { course.chapters.prefix(2).flatMap(\.lessons).contains($0.card.lessonId) } + known
        }
        var candidates: [Q]
        switch level {
        case .single: candidates = pool { c in Self.single(c).map { Q(card: c, tones: [$0], sandhi: false) } }
        case .pairs:
            // (3+3 words among them, heard rising then dipping, with why)
            candidates = pool { c in
                if Self.sandhi(c) { return Q(card: c, tones: [2, 3], sandhi: true) }
                return Self.pair(c).map { Q(card: c, tones: $0, sandhi: false) }
            }
        }
        guard !candidates.isEmpty else { Moments.shared.toast("Learn a few more words first."); return }
        // (leaning on what's missed: a pattern's weight 1, up to 4 when it's mostly wrong)
        let weight = { (q: Q) -> Double in
            let k = q.tones.count == 1 ? "\(q.tones[0])" : "\(q.tones[0])+\(q.tones[1])"
            return 1 + 3 * (1 - (ToneRecord.share(record, k) ?? 0.6))
        }
        var picked: [Q] = [], bag = candidates
        while picked.count < Self.rounds {
            if bag.isEmpty { bag = candidates }
            let total = bag.map(weight).reduce(0, +)
            var r = Double.random(in: 0..<total), i = 0
            while i < bag.count - 1 { r -= weight(bag[i]); if r < 0 { break }; i += 1 }
            picked.append(bag.remove(at: i))
        }
        qs = picked; index = 0; right = 0; combo = 0; misses = [:]; finished = false
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { playing = true }
        prepare()
    }

    private func prepare() {
        guard index < qs.count else { return }
        picks = Array(repeating: nil, count: qs[index].tones.count)
        checked = nil; drawn = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { say() }
    }

    /// the word said; after checking, its pitch line draws as it's said
    private func say(slow: Bool = false) {
        guard index < qs.count else { return }
        let q = qs[index], secs = max(0.6, ChatPage.seconds(q.card.word.hanzi)) * (slow ? 1.6 : 1)
        Speech.shared.speak(q.card.word.hanzi, slow: slow)
        sounding = true
        DispatchQueue.main.asyncAfter(deadline: .now() + secs) { sounding = false }
        if checked != nil {
            drawn = 0
            withAnimation(.easeInOut(duration: secs)) { drawn = 1 }
        }
    }

    private func roundView(_ q: Q) -> some View {
        let ready = !picks.contains { $0 == nil }
        return VStack(spacing: 0) {
            // the lessons' bar: close, the shiny progress with its run
            HStack(spacing: 12) {
                Button { withAnimation { playing = false } } label: {
                    Image(systemName: "xmark").font(.system(size: 22, weight: .heavy)).foregroundStyle(Color.muted)
                        .frame(width: 36, height: 36).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
                ProgressBarShine(value: Double(index + (checked != nil ? 1 : 0)) / Double(qs.count), height: 16, combo: combo)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { barFrame = $0 }
            }
            .padding(.leading, 10).padding(.trailing, 18).padding(.top, 14).padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 14) {
                Text(q.tones.count == 1 ? "Which tone do you hear?" : "Which tones do you hear?")
                    .font(.nunito(25, .black)).tracking(-0.4).foregroundStyle(Color.ink)
                    .padding(.top, 6)
                listenCard(q)
                if q.tones.count == 1 {
                    // (one syllable: the four tones big, two by two, filling the room over Check: the Mac, 0.2.34)
                    VStack(spacing: 10) {
                        HStack(spacing: 10) { toneTile(1, slot: 0, answer: q.tones[0], big: true); toneTile(2, slot: 0, answer: q.tones[0], big: true) }
                        HStack(spacing: 10) { toneTile(3, slot: 0, answer: q.tones[0], big: true); toneTile(4, slot: 0, answer: q.tones[0], big: true) }
                    }
                } else {
                    ForEach(Array(q.tones.indices), id: \.self) { k in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(k == 0 ? "FIRST" : "SECOND").font(.nunito(11.5, .black)).tracking(1.1).foregroundStyle(Color.muted)
                            HStack(spacing: 8) { ForEach(1...4, id: \.self) { t in toneTile(t, slot: k, answer: q.tones[k]) } }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .frame(maxHeight: .infinity, alignment: .top)

            // the foot: the button, pinned; the feedback slides up over it, as the lessons'
            ZStack(alignment: .bottom) {
                Color.clear.frame(height: 84)
                    .overlay(alignment: .bottom) {
                        if let ok = checked {
                            feedback(q, ok: ok)
                                .background(alignment: .top) {
                                    Rectangle().fill(ok ? Color.goodSoft : Color.againSoft)
                                        .padding(.horizontal, -30).padding(.bottom, -260)
                                        .ignoresSafeArea(edges: .bottom)
                                }
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.bottom, 79)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                Button { if checked == nil { check(q) } else { advance() } } label: {
                    Text(checked == nil ? "Check" : index + 1 < qs.count ? "Continue" : "See results")
                }
                .buttonStyle(RaisedButton(fill: checked == false ? Color.again : checked == true ? Color.good : ready ? Color.accent : Color.line,
                                          ink: ready || checked != nil ? Color.onAccent : Color.muted,
                                          sweep: ready || checked != nil, lip: ready || checked != nil ? 5 : 0))
                .disabled(!ready && checked == nil)
                .padding(.bottom, 14)
            }
            // (the button's edges with the content's)
            .padding(.horizontal, 18)
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: checked != nil)
        }
    }

    /// Hear it (and slowly): bars move as it plays; once checked, its pitch line, drawn in its tones' colours.
    private func listenCard(_ q: Q) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                Button { say() } label: {
                    Image(systemName: "speaker.wave.2.fill").font(.system(size: 28, weight: .semibold)).foregroundStyle(Color.onAccent)
                        .frame(width: 74, height: 74).background(Color.accent, in: Circle())
                }
                .buttonStyle(PressDown(depth: 4))
                .background(Circle().fill(Color.accentDark).offset(y: 4))
                .padding(.bottom, 4)
                .accessibilityLabel("Hear it")
                Button { say(slow: true) } label: {
                    Image(systemName: "tortoise.fill").font(.system(size: 17)).foregroundStyle(Color.accent)
                        .frame(width: 48, height: 48).background(Color.panel, in: Circle())
                        .overlay(Circle().strokeBorder(Color.line, lineWidth: 1.5))
                }
                .buttonStyle(PressDown(depth: 2))
                .accessibilityLabel("Hear it slowly")
            }
            ZStack {
                if checked != nil {
                    PitchLine(tones: q.tones, drawn: drawn).frame(height: 62)
                } else {
                    Waveform(level: sounding ? 0.85 : 0.08, bars: 21).foregroundStyle(Color.accent.opacity(0.55)).frame(height: 44)
                        .animation(.easeInOut(duration: 0.2), value: sounding)
                }
            }
            .frame(height: 64)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14).padding(.horizontal, 16)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.line, lineWidth: 1.5))
        .background(Color.line, in: RoundedRectangle(cornerRadius: 20, style: .continuous).offset(y: 4))
    }

    /// a tone to pick for one syllable: its pitch shape and its name; once checked, the right one green, a wrong pick red
    private func toneTile(_ t: Int, slot: Int, answer: Int, big: Bool = false) -> some View {
        let on = picks.indices.contains(slot) && picks[slot] == t
        let state: Bool? = checked == nil ? nil : t == answer ? true : on ? false : nil
        let fill: Color = state == true ? .goodSoft : state == false ? .againSoft : on ? .accentSoft : .panel
        let edge: Color = state == true ? .good : state == false ? .again : on ? .accent : .line
        return Button {
            guard checked == nil else { return }
            withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) { picks[slot] = t }
        } label: {
            VStack(spacing: big ? 8 : 5) {
                ToneShape(tone: t).frame(width: big ? 76 : 46, height: big ? 42 : 26)
                Text(big ? Self.names[t]! : Self.short[t]!).font(.nunito(big ? 16 : 13, .heavy)).foregroundStyle(Color.ink)
            }
            .frame(maxWidth: .infinity).padding(.vertical, big ? 26 : 14)
        }
        .buttonStyle(Tile3D(fill: fill, edge: edge, radius: 14))
        .sensoryFeedback(.selection, trigger: on)
    }

    private func feedback(_ q: Q, ok: Bool) -> some View {
        let tint = ok ? Color.good : Color.again
        let shape = q.tones.map { Self.names[$0]! }.joined(separator: ", then ")
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 10) {
                Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill").font(.system(size: 28, weight: .bold))
                    .symbolRenderingMode(.palette).foregroundStyle(Color.white, tint)
                Text(ok ? ["对了!", "Nice ear!", "Spot on!", "Great job!"][index % 4] : "Correct answer:").font(.nunito(23, .black))
                Spacer(minLength: 0)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TappableHanzi(text: q.card.word.hanzi, pinyin: q.card.word.pinyin, size: 26, weight: .bold)
                PinyinText(pinyin: q.card.word.pinyin, size: 16, weight: .bold)
                Text("· \(FeedbackBanner.brief(q.card.word))").font(.nunito(15, .semibold)).lineLimit(1)
            }
            .padding(.leading, 38)
            Text(q.sandhi ? "Written dip + dip, said rising then dipping: two dips in a row, the first rises." : String(shape.prefix(1)).uppercased() + String(shape.dropFirst()))
                .font(.nunito(14, .bold)).opacity(0.85).padding(.leading, 38).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 2).padding(.top, 16).padding(.bottom, 6)
        .overlay(alignment: .topTrailing) {
            if ok && combo >= 5 && combo % 5 == 0 {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill").font(.system(size: 13, weight: .heavy))
                    Text("\(combo) IN A ROW").font(.nunito(12.5, .black)).tracking(0.6)
                }
                .foregroundStyle(Color.white).padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.gold, in: Capsule()).rotationEffect(.degrees(-4)).offset(x: -10, y: -12)
            }
        }
    }

    private func check(_ q: Q) {
        let ok = picks.compactMap { $0 } == q.tones
        let k = q.tones.count == 1 ? "\(q.tones[0])" : (q.sandhi ? "3+3" : "\(q.tones[0])+\(q.tones[1])")
        ToneRecord.add(k, right: ok)
        // (each syllable's tone on its own too, single or pair: the four tones' cards)
        for (i, t) in q.tones.enumerated() { ToneRecord.add("t\(t)", right: picks.indices.contains(i) && picks[i] == t) }
        record = ToneRecord.load()
        if ok {
            right += 1; combo += 1
            if combo % 5 == 0 {
                burst = combo
                let n = combo
                DispatchQueue.main.asyncAfter(deadline: .now() + FirecrackerBurst.length) { if burst == n { burst = nil } }
            }
        } else { combo = 0; misses[k, default: 0] += 1 }
        Sounds.shared.play(ok ? "correct" : "wrong")
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { checked = ok }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { say() }
    }

    private func advance() {
        if index + 1 < qs.count {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { index += 1 }
            prepare()
        } else {
            xp = right * 2 + 10
            progress.earnXP(xp)
            Sounds.shared.play("complete")
            withAnimation(.easeInOut(duration: 0.25)) { finished = true }
        }
    }

    // MARK: the end

    private var results: some View {
        let accuracy = qs.isEmpty ? 0 : Int((Double(right) / Double(qs.count) * 100).rounded())
        let worst = misses.max { $0.value < $1.value }?.key
        // (as a lesson's done screen: Bùbù pleased, the title, the tiles, together in the middle; the buttons pinned.
        // No splash: the owner, 25 Oct 2026)
        return VStack(spacing: 0) {
            VStack(spacing: 0) {
                Spacer(minLength: 12)
                Image("done-panda").resizable().scaledToFit().frame(minHeight: 120, maxHeight: 260).layoutPriority(-1)
                Text(right == qs.count ? "Perfect ear!" : accuracy >= 70 ? "Nicely heard!" : "Keep listening!")
                    .font(.nunito(28, .black)).tracking(-0.4).foregroundStyle(Color.gold).padding(.top, 2)
                Text(level == .single ? "Single tones" : "Tone pairs")
                    .font(.nunito(14.5, .semibold)).foregroundStyle(Color.muted).padding(.top, 4)
                HStack(spacing: 10) {
                    DoneTile(value: xp, format: { "+\($0)" }, label: "XP", icon: "bolt.fill", tint: .gold, delay: 0.2)
                    DoneTile(value: accuracy, format: { "\($0)%" }, label: "Heard right", icon: "ear", tint: .good, delay: 0.42)
                }
                .padding(.top, 22)
                if let w = worst {
                    let ab = w.split(separator: "+").compactMap { Int($0) }
                    HStack(spacing: 12) {
                        if ab.count == 2 { TonePairShape(pair: (ab[0], ab[1])).frame(width: 64) }
                        else if let t = ab.first { ToneShape(tone: t).frame(width: 46, height: 26) }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ab.count == 2 ? "Trickiest: \(Self.names[ab[0]]!) + \(Self.names[ab[1]]!)" : "Trickiest: \(Self.names[ab.first ?? 1]!)")
                                .font(.nunito(15, .black)).foregroundStyle(Color.ink)
                            Text("The next rounds lean on it.").font(.nunito(13, .semibold)).foregroundStyle(Color.muted)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(Color.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.line, lineWidth: 1.5))
                    .padding(.top, 14)
                }
                Spacer(minLength: 12)
            }
            .padding(.horizontal, 18)
            .frame(maxHeight: .infinity)
            .overlay { if right == qs.count { Confetti(count: 40).allowsHitTesting(false) } }
            VStack(spacing: 10) {
                Button { finished = false; start() } label: { Text("Go again") }
                    .buttonStyle(RaisedButton(fill: Color.accent, ink: Color.onAccent))
                Button { withAnimation { finished = false; playing = false } } label: { Text("Done") }
                    .buttonStyle(RaisedButton(fill: Color.panel, ink: Color.accent, edge: Color.line, sweep: false, lip: 4))
            }
            .padding(.horizontal, 18).padding(.bottom, 14)
        }
    }
}

/// One tone's pitch, small: level, rising, the dip, falling (a dot for the light tone).
struct ToneShape: View {
    let tone: Int
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height, c = Color.tones[max(0, min(4, tone - 1))]
            var p = Path()
            switch tone {
            case 1: p.move(to: .init(x: 3, y: h * 0.22)); p.addLine(to: .init(x: w - 3, y: h * 0.22))
            case 2: p.move(to: .init(x: 3, y: h * 0.72)); p.addLine(to: .init(x: w - 3, y: h * 0.2))
            case 3:
                p.move(to: .init(x: 3, y: h * 0.5))
                p.addQuadCurve(to: .init(x: w * 0.5, y: h * 0.86), control: .init(x: w * 0.3, y: h * 0.95))
                p.addQuadCurve(to: .init(x: w - 3, y: h * 0.25), control: .init(x: w * 0.72, y: h * 0.78))
            case 4: p.move(to: .init(x: 3, y: h * 0.2)); p.addLine(to: .init(x: w - 3, y: h * 0.82))
            default:
                ctx.fill(Path(ellipseIn: CGRect(x: w / 2 - 3.5, y: h * 0.6 - 3.5, width: 7, height: 7)), with: .color(c)); return
            }
            ctx.stroke(p, with: .color(c), style: StrokeStyle(lineWidth: 3.6, lineCap: .round, lineJoin: .round))
        }
    }
}

/// A word's pitch line, each syllable's tone in its colour, drawn left to right as `drawn` goes 0 → 1.
struct PitchLine: View {
    let tones: [Int]
    var drawn: Double
    var body: some View {
        GeometryReader { g in
            let n = max(1, tones.count), gap: CGFloat = 18
            let segW = (g.size.width - gap * CGFloat(n - 1)) / CGFloat(n)
            ZStack(alignment: .topLeading) {
                ForEach(Array(tones.enumerated()), id: \.offset) { k, t in
                    let part = min(1, max(0, drawn * Double(n) - Double(k)))
                    ToneContour(tone: t)
                        .trim(from: 0, to: part)
                        .stroke(Color.tones[max(0, min(4, t - 1))], style: StrokeStyle(lineWidth: 5.5, lineCap: .round, lineJoin: .round))
                        .frame(width: segW, height: g.size.height)
                        .offset(x: CGFloat(k) * (segW + gap))
                }
            }
        }
    }
}

/// a tone's contour as a shape (for drawing it in, trimmed)
struct ToneContour: Shape {
    let tone: Int
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        var p = Path()
        switch tone {
        case 1: p.move(to: .init(x: 4, y: h * 0.18)); p.addLine(to: .init(x: w - 4, y: h * 0.18))
        case 2: p.move(to: .init(x: 4, y: h * 0.62)); p.addLine(to: .init(x: w - 4, y: h * 0.16))
        case 3:
            p.move(to: .init(x: 4, y: h * 0.48))
            p.addQuadCurve(to: .init(x: w * 0.5, y: h * 0.88), control: .init(x: w * 0.28, y: h * 0.98))
            p.addQuadCurve(to: .init(x: w - 4, y: h * 0.3), control: .init(x: w * 0.74, y: h * 0.8))
        case 4: p.move(to: .init(x: 4, y: h * 0.14)); p.addLine(to: .init(x: w - 4, y: h * 0.86))
        default: p.addEllipse(in: CGRect(x: w / 2 - 4, y: h * 0.6 - 4, width: 8, height: 8))
        }
        return p
    }
}

/// The four tones, with 妈 麻 马 骂 to hear (web: the tones primer).
struct TonesPrimer: View {
    static let demo = [("1st tone", "high and flat", "mā", "妈", "mother"),
                       ("2nd tone", "rising, like asking a question", "má", "麻", "hemp"),
                       ("3rd tone", "dips down low, then rises", "mǎ", "马", "horse"),
                       ("4th tone", "sharp and falling, like a command", "mà", "骂", "to scold")]
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            (Text("Mandarin is ") + Text("tonal").bold()
             + Text(": the same syllable said with a different pitch is a different word. The mark over the vowel tells you the tone — it matters as much as the letters. Tap the speaker to hear each."))
                .font(.nunito(15)).foregroundStyle(Color.ink).lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 10)
            ForEach(Array(Self.demo.enumerated()), id: \.offset) { _, t in
                HStack(spacing: 12) {
                    Text(t.2).font(.nunitoXB(24)).foregroundStyle(Color.accent)
                        .frame(width: 44, alignment: .center)
                    VStack(alignment: .leading, spacing: 2) {
                        (Text(t.0).bold() + Text(" — \(t.3) \(t.4)")).font(.nunito(15)).foregroundStyle(Color.ink)
                        Text(t.1).font(.nunito(13)).foregroundStyle(Color.muted)
                    }
                    Spacer(minLength: 0)
                    SpeakerButton(text: t.3)
                }
                .frame(minHeight: 60)
                .overlay(alignment: .bottom) { Rectangle().fill(Color.line).frame(height: 1) }
            }
            (Text("Neutral tone").bold() + Text(" — no mark, said light and quick: ")
             + Text("ma").bold() + Text(" 吗 (turns a sentence into a question)."))
                .font(.nunito(15)).foregroundStyle(Color.ink).lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
            (Text("Same letters, different tone = different meaning: ") + Text("mǎi").bold() + Text(" 买 (buy) vs ")
             + Text("mài").bold() + Text(" 卖 (sell)."))
                .font(.nunito(13)).foregroundStyle(Color.muted).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
        }
    }
}
