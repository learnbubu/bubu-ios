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

/// Hear a two-syllable word and pick its two tones (web: startTones).
struct TonesPage: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.dismiss) private var dismiss
    @State private var questions: [Card] = []
    @State private var index = 0
    @State private var right = 0
    @State private var misses: [String: Int] = [:]
    @State private var choices: [[Int]] = []
    @State private var picked: [Int]?
    @State private var finished = false
    @State private var xp = 0
    @State private var confetti = false
    private let course = Course.shared
    static let rounds = 10
    static let names = [1: "high", 2: "rising", 3: "dipping", 4: "falling", 5: "light"]

    /// A word's two tones, when what you hear matches what's written (no 3+3, 不 or 一).
    static func pair(_ c: Card) -> [Int]? {
        let han = c.word.hanzi.filter(Course.isHan), ss = Pinyin.syllables(c.word.pinyin)
        guard han.count == 2, ss.count == 2, !c.word.hanzi.contains("不"), !c.word.hanzi.contains("一") else { return nil }
        let a = toneOf(ss[0]), b = toneOf(ss[1])
        if a == 5 || (a == 3 && b == 3) { return nil }
        return [a, b]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ProgressBarShine(value: finished ? 1 : Double(index) / Double(max(1, questions.count)))
                if finished { results } else if index < questions.count { round(questions[index]) }
            }
            .padding(.horizontal, 18).padding(.bottom, 40)
        }
        .overlay { if confetti { Confetti(count: 70).allowsHitTesting(false) } }
        .navigationTitle("Tone pairs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !finished && !questions.isEmpty {
                    Text("\(index + 1) / \(questions.count)").font(.nunito(13, .semibold)).foregroundStyle(Color.muted)
                }
            }
        }
        .onAppear { if questions.isEmpty { start() } }
    }

    private func start() {
        let all = course.cards.filter { Self.pair($0) != nil }
        let met = all.filter { progress.srs[$0.id] != nil || progress.isDone($0.lessonId) }
        let pool = met.count >= 6 ? met : all.filter { course.chapters[0].lessons.contains($0.lessonId) } + met
        var seen = Set<String>()
        let unique = pool.filter { seen.insert($0.word.hanzi).inserted }.shuffled()
        questions = unique.isEmpty ? [] : (0..<Self.rounds).map { unique[$0 % unique.count] }
        index = 0; right = 0; misses = [:]; finished = false; confetti = false
        prepare()
    }

    private func prepare() {
        picked = nil
        guard index < questions.count, let ans = Self.pair(questions[index]) else { return }
        var pairs: [[Int]] = []
        for a in 1...4 { for b in 1...5 where !(a == 3 && b == 3) { pairs.append([a, b]) } }
        let others = pairs.filter { $0 != ans }
        let near = Array(others.filter { $0[0] == ans[0] || $0[1] == ans[1] }.shuffled().prefix(2))
        let far = Array(others.filter { !near.contains($0) }.shuffled().prefix(3 - near.count))
        choices = ([ans] + near + far).shuffled()
        let word = questions[index].word.hanzi
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { Speech.shared.speak(word) }
    }

    private func round(_ c: Card) -> some View {
        let ans = Self.pair(c) ?? [1, 1]
        return VStack(spacing: 16) {
            Text("Which two tones do you hear?").font(.nunitoXB(19.2)).foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
            HStack(spacing: 14) {
                Button { Speech.shared.speak(c.word.hanzi) } label: {
                    Image(systemName: "speaker.wave.2").font(.system(size: 30, weight: .semibold)).foregroundStyle(Color.onAccent)
                        .frame(width: 84, height: 84).background(Color.accent, in: Circle())
                }
                .buttonStyle(PressDown(depth: 4))
                .background(Circle().fill(Color.accentDark).offset(y: 4))
                .padding(.bottom, 4)
                Button { Speech.shared.speak(c.word.hanzi, slow: true) } label: {
                    Text("½×").font(.nunitoXB(15)).foregroundStyle(Color.ink)
                        .frame(width: 50, height: 50)
                        .background(Color.panel, in: Circle())
                        .overlay(Circle().strokeBorder(Color.line, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(choices, id: \.self) { p in
                    let isAns = p == ans, chosen = picked == p
                    let state: Bool? = picked == nil ? nil : isAns ? true : chosen ? false : nil
                    Button { choose(p, ans) } label: {
                        VStack(spacing: 6) {
                            TonePairShape(pair: (p[0], p[1])).frame(height: 34)
                            (Text(p[0] == 5 ? "light" : "\(p[0])").foregroundColor(Color.tones[p[0] - 1])
                             + Text(" + ").foregroundColor(Color.muted)
                             + Text(p[1] == 5 ? "light" : "\(p[1])").foregroundColor(Color.tones[p[1] - 1]))
                                .font(.nunitoXB(15))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(state == true ? Color.goodSoft : state == false ? Color.againSoft : Color.panel,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(state == true ? Color.good : state == false ? Color.again : Color.line, lineWidth: 1.5))
                    }
                    .buttonStyle(PressDown(depth: 1))
                    .disabled(picked != nil)
                }
            }
            if let p = picked {
                VStack(spacing: 4) {
                    TappableHanzi(text: c.word.hanzi, pinyin: c.word.pinyin, size: 30, weight: .bold)
                    PinyinText(pinyin: c.word.pinyin, size: 16)
                    Text(c.word.en).font(.nunito(14)).foregroundStyle(Color.ink)
                    Text("\(Self.names[ans[0]]!) then \(Self.names[ans[1]]!)").font(.nunito(13, .bold)).foregroundStyle(Color.muted)
                }
                .frame(maxWidth: .infinity).padding(14)
                .background(p == ans ? Color.goodSoft : Color.againSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                Button(index + 1 < questions.count ? "Continue" : "See results") {
                    withAnimation {
                        index += 1
                        if index < questions.count { prepare() } else { results_() }
                    }
                }
                .buttonStyle(WideButton())
            }
        }
    }

    private func choose(_ p: [Int], _ ans: [Int]) {
        guard picked == nil else { return }
        withAnimation { picked = p }
        let ok = p == ans
        if ok { right += 1 } else { misses["\(ans[0])+\(ans[1])", default: 0] += 1 }
        Sounds.shared.play(ok ? "correct" : "wrong")
        Speech.shared.speak(questions[index].word.hanzi)
    }

    private func results_() {
        xp = right * 2 + 10
        progress.earnXP(xp)
        Sounds.shared.play("complete")
        confetti = Double(right) >= Double(questions.count) * 0.8
        finished = true
    }

    private var results: some View {
        let worst = misses.max { $0.value < $1.value }?.key.split(separator: "+").compactMap { Int($0) }
        return VStack(spacing: 14) {
            Text("\(right) / \(questions.count)").font(.nunito(52, .black)).foregroundStyle(Color.ink).padding(.top, 20)
            Text(right == questions.count ? "Perfect ear!" : Double(right) >= Double(questions.count) * 0.7 ? "Nicely heard" : "Tones take time. Keep listening.")
                .font(.nunitoXB(18)).foregroundStyle(Color.ink)
            Text("+\(xp) XP").font(.nunitoXB(16)).foregroundStyle(Color.gold)
            if let w = worst, w.count == 2 {
                HStack(spacing: 12) {
                    TonePairShape(pair: (w[0], w[1])).frame(width: 70)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Trickiest: \(Self.names[w[0]]!) + \(Self.names[w[1]]!)").font(.nunitoXB(15)).foregroundStyle(Color.ink)
                        Text("Say a few words with this pattern out loud, drawing the shape with your hand.")
                            .font(.nunito(13.5)).foregroundStyle(Color.muted)
                    }
                }
                .padding(14).panel(radius: 16)
            }
            Button("Go again") { start() }.buttonStyle(WideButton()).padding(.top, 8)
            Button("Done") { dismiss() }.buttonStyle(WideButton(ghost: true))
        }
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
