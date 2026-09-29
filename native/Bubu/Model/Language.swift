import Foundation

// Chinese-specific helpers for building exercises, each a port of the web app's.

// MARK: pinyin

enum Pinyin {
    static let toneVowels: [Character: [Character]] = [
        "a": ["ā", "á", "ǎ", "à"], "e": ["ē", "é", "ě", "è"], "i": ["ī", "í", "ǐ", "ì"],
        "o": ["ō", "ó", "ǒ", "ò"], "u": ["ū", "ú", "ǔ", "ù"], "ü": ["ǖ", "ǘ", "ǚ", "ǜ"],
    ]
    /// toned vowel → (base vowel, tone index 0…3)
    static let decode: [Character: (Character, Int)] = {
        var d: [Character: (Character, Int)] = [:]
        for (base, arr) in toneVowels { for (i, ch) in arr.enumerated() { d[ch] = (base, i) } }
        return d
    }()

    static func toneless(_ py: String) -> String { String(py.map { decode[$0]?.0 ?? $0 }) }

    /// Up to n versions of the pinyin with one or two tone marks changed (web: toneVariants).
    static func variants(_ py: String, _ n: Int) -> [String] {
        let chars = Array(py)
        let marks = chars.indices.filter { decode[chars[$0]] != nil }
        guard !marks.isEmpty else { return [] }
        var out: [String] = [], guardN = 0
        while out.count < n && guardN < 60 {
            guardN += 1
            var arr = chars
            let k = 1 + Int.random(in: 0..<min(2, marks.count))
            for idx in marks.shuffled().prefix(k) {
                let (base, tone) = decode[chars[idx]]!
                var t2 = tone
                while t2 == tone { t2 = Int.random(in: 0..<4) }
                arr[idx] = toneVowels[base]![t2]
            }
            let v = String(arr)
            if v != py && !out.contains(v) { out.append(v) }
        }
        return Array(out.prefix(n))
    }

    static let vowels = Set("aeiouüāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ")

    /// Vowel groups in a pinyin token: how many syllables it spells.
    static func syllableCount(_ token: String) -> Int {
        var n = 0, inVowel = false
        for ch in token.lowercased() {
            let v = vowels.contains(ch)
            if v && !inVowel { n += 1 }
            inVowel = v
        }
        return max(1, n)
    }
}

// MARK: sentences, for the word-tile builder

struct SentenceWord: Hashable { let hanzi: String; let pinyin: String }

struct Sentence: Hashable {
    let hanzi: String
    let pinyin: String
    let en: String
    let words: [SentenceWord]

    /// Split a dialogue line into words using its pinyin, grouped by word
    /// ("nǐ jiào shénme míngzi"). Only trusted if it uses every character
    /// and gives at least two words (web: segmentSentence).
    static func segment(hanzi: String, pinyin: String) -> [SentenceWord]? {
        let chars = hanzi.filter(Course.isHan).map(String.init)
        let punct = CharacterSet(charactersIn: ",.!?;:，。！？")
        let tokens = pinyin.split(whereSeparator: \.isWhitespace)
            .map { String($0.unicodeScalars.filter { !punct.contains($0) }) }
            .filter { !$0.isEmpty }
        var words: [SentenceWord] = [], i = 0
        for tok in tokens {
            var n = Pinyin.syllableCount(tok)
            // an erhua syllable (nǎr, yīdiǎnr) also takes the 儿 that follows it
            let lower = tok.lowercased()
            if lower.hasSuffix("r") && !lower.hasSuffix("er"), i + n < chars.count, chars[i + n] == "儿" { n += 1 }
            guard i < chars.count else { break }
            let w = chars[i..<min(chars.count, i + n)].joined()
            if w.isEmpty { break }
            words.append(SentenceWord(hanzi: w, pinyin: tok))
            i += n
        }
        return (i == chars.count && words.count >= 2) ? words : nil
    }

    static let subjects: Set<String> = ["我", "你", "他", "她", "它", "我们", "你们", "他们", "她们", "咱们", "您"]

    static func isTimeWord(_ w: String) -> Bool {
        if w.range(of: "^(今|明|昨|后|前)(天|年)$", options: .regularExpression) != nil { return true }
        if w.range(of: "^(早|晚|上|中|下)(上|午)$", options: .regularExpression) != nil { return true }
        if w.hasPrefix("星期") || w.hasPrefix("周") { return true }
        return ["现在", "周末", "每天", "每年", "平时", "以后", "以前", "刚才"].contains(w)
    }

    /// Every word order that counts as right: as written, and with a leading
    /// subject and time word swapped (web: acceptedOrders).
    var acceptedOrders: [[String]] {
        let base = words.map(\.hanzi)
        var orders = [base]
        if base.count > 2 {
            let a = base[0], b = base[1]
            if (Self.subjects.contains(a) && Self.isTimeWord(b)) || (Self.isTimeWord(a) && Self.subjects.contains(b)) {
                let swapped = [b, a] + base.dropFirst(2)
                if swapped.joined() != base.joined() { orders.append(swapped) }
            }
        }
        return orders
    }

    /// The pinyin re-ordered to follow a different word order.
    func pinyin(for order: [String]) -> String {
        var py: [String: String] = [:]
        for w in words { py[w.hanzi] = w.pinyin }
        return order.map { py[$0] ?? "" }.joined(separator: " ")
    }

    /// English split into words, punctuation dropped (web: enWords).
    static func enWords(_ s: String) -> [String] {
        s.replacingOccurrences(of: "[.!?,;:]+", with: "", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace).map(String.init)
    }
}

// MARK: characters: parts and look-alikes

struct CharInfo: Codable {
    let d: String?      // meaning
    let p: String?      // pinyin
    let c: [[String]]?  // parts: [part, role] where role m = meaning, s = sound
    let h: String?      // how it's built
    let t: String?      // type: g = a picture character
}

final class CharData {
    static let shared = CharData()
    let chars: [String: CharInfo]
    let partNames: [String: [String]]     // part → [meaning, pinyin]

    private init() {
        struct File: Codable { let chars: [String: CharInfo]; let parts: [String: [String?]]? }
        if let url = Bundle.main.url(forResource: "chars", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let f = try? JSONDecoder().decode(File.self, from: data) {
            chars = f.chars; partNames = (f.parts ?? [:]).mapValues { $0.map { $0 ?? "" } }
        } else {
            chars = [:]; partNames = [:]
        }
    }

    func meaning(_ ch: String) -> String { (chars[ch]?.d ?? "").components(separatedBy: CharacterSet(charactersIn: ",;")).first ?? "" }

    static let notes: [String: String] = [
        "买卖": "卖 sell has an extra 十 on top of 买 buy: you add something on top when you sell it on.",
        "人入": "人 person steps forward on its left leg; 入 enter leads with the right, stepping in.",
        "大太": "太 too is 大 big with an extra dot underneath: bigger than big.",
        "大天": "天 sky has a line over 大 big: the sky above a person.",
        "大夫": "夫 has a second line through the top of 大.",
        "己已": "已 already closes a little higher than 己 self; 巳 closes all the way.",
        "日目": "目 eye has two lines inside; 日 sun has one.",
        "日白": "白 white has a small tick on top of 日 sun.",
        "土士": "士 has the longer line on top; 土 earth has the longer line at the bottom.",
        "未末": "末 end has the longer line on top; 未 not yet has the shorter line on top.",
        "千干": "千 thousand starts with a slanted stroke; 干 starts with a flat one.",
        "午牛": "牛 cow's middle stroke pokes through the top; 午 noon's doesn't.",
        "儿几": "几 has a lid across the top; 儿 is open.",
        "问间": "问 ask has a mouth 口 in the door 门; 间 between has the sun 日.",
        "今令": "令 has a hook at the bottom where 今 has a flat stroke.",
        "见贝": "见 see ends in a long hooked leg; 贝 shell has two short legs.",
        "为办": "办 do has a dot on each side of 力; 为 has two dots together.",
        "力刀": "力 strength pokes up through the top; 刀 knife doesn't.",
        "东车": "车 car has a flat line at the bottom; 东 east has two dots.",
        "找我": "我 I has an extra dot on the right that 找 look for doesn't.",
        "住往": "住 live has person 亻 on the left; 往 towards has the double person 彳.",
        "休体": "体 body has an extra line at the bottom of 木.",
        "午年": "年 year has extra strokes on the left of 午 noon.",
        "左右": "左 left has 工 underneath; 右 right has 口.",
    ]
    static func pairKey(_ a: String, _ b: String) -> String? {
        notes[a + b] != nil ? a + b : notes[b + a] != nil ? b + a : nil
    }

    // tiny strokes and the everywhere-parts don't make two characters look alike
    static let trivial = Set("口一丨丿丶乛亅乚八十冖亠".map(String.init))

    func parts(_ ch: String) -> Set<String> {
        Set((chars[ch]?.c ?? []).compactMap(\.first).filter { !Self.trivial.contains($0) })
    }

    func charSim(_ a: String, _ b: String) -> Double {
        if a == b { return 2 }
        if Self.pairKey(a, b) != nil { return 4 }
        let pa = parts(a)
        return Double(parts(b).filter { pa.contains($0) }.count) * 1.5
    }

    /// How easily two words could be mistaken for each other at a glance (web: wordSim).
    func wordSim(_ a: String, _ b: String) -> Double {
        let x = a.filter(Course.isHan).map(String.init), y = b.filter(Course.isHan).map(String.init)
        guard !x.isEmpty, x.count == y.count, a != b else { return 0 }
        var s = 0.0, differ = 0
        for i in x.indices {
            if x[i] != y[i] { differ += 1 }
            s += charSim(x[i], y[i])
        }
        return differ > 0 ? s / Double(x.count) + (differ == 1 && x.count > 1 ? 1 : 0) : 0
    }

    /// The first character that differs between two same-length words, and a note on telling them apart.
    func difference(_ right: String, _ wrong: String) -> (right: String, wrong: String, note: String)? {
        let x = right.filter(Course.isHan).map(String.init), y = wrong.filter(Course.isHan).map(String.init)
        guard let i = x.indices.first(where: { $0 < y.count && x[$0] != y[$0] }) else { return nil }
        let a = x[i], b = y[i]
        if let k = Self.pairKey(a, b), let n = Self.notes[k] { return (a, b, n) }
        let pa = parts(a), pb = parts(b)
        let onlyA = pa.subtracting(pb).sorted(), onlyB = pb.subtracting(pa).sorted()
        let name = { (p: String) -> String in
            if let d = self.partNames[p]?.first, !d.isEmpty { return "\(p) \(d)" }
            return p
        }
        let list = { (ps: [String]) -> String in ps.isEmpty ? "no extra part" : ps.map(name).joined(separator: " and ") }
        let note = onlyA.isEmpty && onlyB.isEmpty
            ? "Look closely at \(a) and \(b): same parts, different arrangement."
            : "\(a) \(meaning(a)) has \(list(onlyA)); \(b) \(meaning(b)) has \(list(onlyB))."
        return (a, b, note)
    }
}

extension Course {
    /// Every dialogue line that splits cleanly into words.
    var sentences: [Sentence] { Course.sentencePool }

    static let sentencePool: [Sentence] = Course.shared.data.dialogues.flatMap { d in
        d.turns.compactMap { t in
            Sentence.segment(hanzi: t.hanzi, pinyin: t.pinyin).map { Sentence(hanzi: t.hanzi, pinyin: t.pinyin, en: t.en, words: $0) }
        }
    }

    func sentences(for card: Card) -> [Sentence] { sentences.filter { $0.hanzi.contains(card.word.hanzi) } }

    /// Little particles that barely count as words: a sentence may have these unmet.
    static let trivialWords: Set<String> = ["了", "吗", "呢", "吧", "啊", "哇", "呀", "嘛", "啦", "哦"]
    /// Sentences of up to this many words are preferred when there's a choice.
    static let shortSentence = 8

    /// Whether a sentence word has been met: a card for exactly that word has, or, for a
    /// word that isn't one of the course's own (a name, a compound), every character of
    /// it is in a word that has. `met` says whether a card id has been met.
    func isMetWord(_ w: String, met: (String) -> Bool) -> Bool {
        let han = w.filter(Course.isHan)
        if han.isEmpty { return true }
        if let cs = cardsByHanzi[han] { return cs.contains { met($0.id) } }
        return han.allSatisfy { ch in (cardsByChar[ch] ?? []).contains { met($0.id) } }
    }

    /// The words of a sentence the learner hasn't met yet, leaving out the card's own
    /// word (the one new word allowed, unless `ownAllowed` is false) and the little particles.
    func unmetWords(in s: Sentence, for card: Card, met: (String) -> Bool, ownAllowed: Bool = true) -> [String] {
        let own = card.word.hanzi.filter(Course.isHan)
        let all = s.words.map(\.hanzi).joined()
        var ownSpan: Range<Int>?
        if ownAllowed, !own.isEmpty, let r = all.range(of: own) {
            let lo = all.distance(from: all.startIndex, to: r.lowerBound)
            ownSpan = lo..<(lo + own.count)
        }
        var out: [String] = [], at = 0
        for w in s.words {
            let span = at..<(at + w.hanzi.count)
            at += w.hanzi.count
            // a piece of the card's own word (不客气 can split as 不 + 客气)
            if let o = ownSpan, span.lowerBound >= o.lowerBound, span.upperBound <= o.upperBound { continue }
            if Course.trivialWords.contains(w.hanzi) || isMetWord(w.hanzi, met: met) { continue }
            out.append(w.hanzi)
        }
        return out
    }

    /// The sentences a card's sentence exercise may use: every word met apart from the
    /// card's own and the little particles, the short ones when there are any, else the
    /// shortest. Empty when none will do, and another kind of exercise is asked instead.
    func sentences(for card: Card, met: (String) -> Bool) -> [Sentence] {
        let ok = sentences(for: card).filter { unmetWords(in: $0, for: card, met: met).isEmpty }
        let short = ok.filter { $0.words.count <= Course.shortSentence }
        if !short.isEmpty { return short }
        guard let least = ok.map(\.words.count).min() else { return [] }
        return ok.filter { $0.words.count == least }
    }

    /// The words of your lines in a dialogue you haven't met yet (little particles aside).
    func unmetWords(in d: Dialogue, met: (String) -> Bool) -> [String] {
        var out: [String] = []
        for t in d.turns where t.who == "you" {
            let words = Sentence.segment(hanzi: t.hanzi, pinyin: t.pinyin)?.map(\.hanzi)
                ?? t.hanzi.filter(Course.isHan).map { String($0) }
            for w in words where !Course.trivialWords.contains(w) && !isMetWord(w, met: met) && !out.contains(w) {
                out.append(w)
            }
        }
        return out
    }

    /// A dialogue is yours to say once you've met the words of your lines.
    func dialogueUnlocked(_ d: Dialogue, met: (String) -> Bool) -> Bool {
        unmetWords(in: d, met: met).isEmpty
    }

    /// A speaking exercise's sentence has at most this many words.
    static let speakSentenceMax = 6

    /// The sentences a card's speaking exercise may ask for instead of the word alone: short
    /// (at most `speakSentenceMax` words), and every word in them met, the card's own word
    /// included (no new word to say). Empty when none will do: then it's just the word.
    func speakSentences(for card: Card, met: (String) -> Bool) -> [Sentence] {
        sentences(for: card).filter {
            $0.words.count <= Course.speakSentenceMax
                && unmetWords(in: $0, for: card, met: met, ownAllowed: false).isEmpty
        }
    }

    /// Up to n look-alike cards for a card, strongest first with a little shuffle (web: lookalikes).
    func lookalikes(_ c: Card, _ n: Int) -> [Card] {
        let cd = CharData.shared
        return cards.filter { $0.word.en != c.word.en && $0.word.hanzi != c.word.hanzi }
            .map { ($0, cd.wordSim(c.word.hanzi, $0.word.hanzi)) }
            .filter { $0.1 >= 1.5 }
            .shuffled()
            .sorted { $0.1 > $1.1 }
            .prefix(n).map(\.0)
    }
}
