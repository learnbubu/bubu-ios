import SwiftUI

// Tap-a-word hints, as the web's hintable / showHint / englishHints.

extension Course {
    /// The first meaning each word has in the course (web: WORD_EN).
    static let wordEn: [String: String] = {
        var d: [String: String] = [:]
        for c in Course.shared.cards where d[c.word.hanzi] == nil { d[c.word.hanzi] = c.word.en }
        return d
    }()
    /// The first pinyin each word has (web: PINYIN_BY_HANZI).
    static let wordPy: [String: String] = {
        var d: [String: String] = [:]
        for c in Course.shared.cards where d[c.word.hanzi] == nil { d[c.word.hanzi] = c.word.pinyin }
        return d
    }()
}

enum Hints {
    /// What a word means: its own card, a compound built from its parts, else its characters (web: wordMeaning).
    static func meaning(_ h: String) -> String {
        if let e = Course.wordEn[h] { return e }
        let han = h.filter(Course.isHan).map(String.init)
        let charEn = { (c: String) in Course.wordEn[c] ?? CharData.shared.meaning(c) }
        if han.count > 1 {
            for k in stride(from: han.count - 1, to: 0, by: -1) {
                let a = han[..<k].joined(), b = han[k...].joined()
                if let ea = Course.wordEn[a], let eb = Course.wordEn[b] ?? (charEn(b).isEmpty ? nil : charEn(b)) { return "\(ea) + \(eb)" }
            }
        }
        return han.map(charEn).filter { !$0.isEmpty }.joined(separator: " + ")
    }

    /// Up to three meanings of a word, the short one first: its card's meaning split at ; and ,,
    /// asides and Chinese examples left out (说: speak, talk, say). As Duolingo's hint rows.
    static func senses(_ h: String, max n: Int = 3) -> [String] {
        let han = h.filter(Course.isHan)
        var out = [short(h)]
        for c in Course.shared.cardsByHanzi[han] ?? [] {
            let plain = c.word.en.replacingOccurrences(of: "\\([^)]*\\)", with: " ", options: .regularExpression)
                .replacingOccurrences(of: "\\p{Han}+[^,;]*", with: " ", options: .regularExpression)
            for part in plain.components(separatedBy: CharacterSet(charactersIn: ";,")) {
                let t = part.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "  ", with: " ")
                guard !t.isEmpty, t.count <= 24, !out.contains(where: { $0.lowercased() == t.lowercased() }) else { continue }
                out.append(t)
            }
        }
        return Array(out.filter { !$0.isEmpty }.prefix(n))
    }

    /// Words that work together across a sentence (你 … 吗 "do you…?", 会 说 "can speak"), as
    /// Duolingo links them in its hints (the owner, 4 Oct 2026: "when we click on words to see
    /// what they mean and connect to one another").
    struct Link: Hashable {
        let header: String          // 你 … 吗
        let pinyin: String          // nǐ … ma
        let meanings: [String]      // do you, are you
    }

    static let pronounEn: [String: (String, String)] = [
        "你": ("you", "you"), "您": ("you", "you"), "他": ("he", "him"), "她": ("she", "her"), "我": ("I", "me"),
        "我们": ("we", "us"), "你们": ("you", "you"), "他们": ("they", "them"), "她们": ("they", "them"),
    ]
    static let possessive: [String: String] = ["我": "my", "你": "your", "您": "your", "他": "his", "她": "her",
                                               "我们": "our", "你们": "your", "他们": "their", "她们": "their"]

    /// Other Chinese for an English word, beside the sentence's own (speak: 说, 讲): course words
    /// whose short meaning is that word (or "to" it), up to `n`, the most common first.
    static func alternatives(_ english: String, besides primary: String, max n: Int = 2) -> [SentenceWord] {
        let st = stem(english)
        guard !st.isEmpty, !filler.contains(st) || alias[st] != nil else { return [] }
        var out: [SentenceWord] = [], seen: Set<String> = [primary]
        for c in Course.shared.cards where !c.isSentence {
            let g = c.word.gloss.lowercased()
            let parts = g.components(separatedBy: CharacterSet(charactersIn: ",;")).map {
                stem($0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "to ", with: "", options: .anchored))
            }
            guard parts.contains(st), seen.insert(c.word.hanzi).inserted else { continue }
            out.append(SentenceWord(hanzi: c.word.hanzi, pinyin: Course.wordPy[c.word.hanzi] ?? c.word.pinyin))
            if out.count == n { break }
        }
        return out
    }

    /// The English words beside token `i` that share its Chinese ("How are you" all 你好吗), as one span.
    static func span(_ tokens: [Token], at i: Int) -> String? {
        guard let w = tokens[i].word else { return nil }
        var a = i, b = i
        while a > 0, tokens[a - 1].word == w { a -= 1 }
        while b + 1 < tokens.count, tokens[b + 1].word == w { b += 1 }
        return a == b ? nil : tokens[a...b].map(\.text).joined(separator: " ")
    }

    /// The link the word at `i` takes part in, if any.
    static func link(_ words: [SentenceWord], at i: Int) -> Link? {
        let hz = words.map(\.hanzi), py = words.map(\.pinyin)
        guard hz.indices.contains(i) else { return nil }
        func at(_ k: Int) -> String? { hz.indices.contains(k) ? hz[k] : nil }
        func meaningOf(_ k: Int) -> String { short(hz[k]).replacingOccurrences(of: "to ", with: "", options: .anchored) }
        func make(_ a: Int, _ b: Int, _ m: [String]) -> Link {
            let gap = b - a > 1
            return Link(header: hz[a] + (gap ? " … " : " ") + hz[b], pinyin: py[a] + (gap ? " … " : " ") + py[b], meanings: m)
        }
        // a question with 吗: its subject and the 吗 (你 … 吗: do you / are you)
        if let q = hz.lastIndex(of: "吗"), let s = hz.firstIndex(where: { pronounEn[$0] != nil }), s < q, i == s || i == q {
            let (sub, _) = pronounEn[hz[s]]!
            let aux = sub == "he" || sub == "she" ? ["does \(sub)", "is \(sub)"] : sub == "I" ? ["do I", "am I"] : ["do \(sub)", "are \(sub)"]
            return make(s, q, aux.map { $0 + " …?" })
        }
        // 会 + verb: can …
        if let k = hz.firstIndex(of: "会"), let v = at(k + 1), v.first.map(Course.isHan) == true, i == k || i == k + 1 {
            return make(k, k + 1, ["can " + meaningOf(k + 1), "know how to " + meaningOf(k + 1)])
        }
        // 不 / 没 + word: not …
        for neg in ["不", "没"] {
            if let k = hz.firstIndex(of: neg), at(k + 1) != nil, i == k || i == k + 1 {
                let m = meaningOf(k + 1)
                return make(k, k + 1, neg == "没" ? ["didn't " + m, "not " + m] : ["not " + m, "don't " + m])
            }
        }
        // 很 + adjective: very … (or just "is …")
        if let k = hz.firstIndex(of: "很"), at(k + 1) != nil, i == k || i == k + 1 {
            return make(k, k + 1, ["very " + meaningOf(k + 1), "is " + meaningOf(k + 1)])
        }
        // X 的: X's (我的: my), when X is a person or a thing; after a verb (你拍的照片) 的 ties a whole
        // clause to the noun, and isn't linked
        if let k = hz.firstIndex(of: "的"), k > 0, i == k || i == k - 1,
           possessive[hz[k - 1]] != nil || Course.shared.nameList.contains(hz[k - 1])
            || (Course.shared.cardsByHanzi[hz[k - 1]]?.first?.word.pos ?? "").hasPrefix("n") {
            let owner = hz[k - 1]
            return make(k - 1, k, [possessive[owner] ?? (meaningOf(k - 1) + "'s")])
        }
        // 太 … 了: too … / so …!
        if let a = hz.firstIndex(of: "太"), let b = hz.lastIndex(of: "了"), a < b, i == a || i == b {
            let m = b - a > 1 ? meaningOf(a + 1) : "…"
            return make(a, b, ["too " + m, "so " + m + "!"])
        }
        // 想 / 要 + verb: want to … / going to …
        for (w, m) in [("想", ["want to ", "would like to "]), ("要", ["going to ", "want to "])] {
            if let k = hz.firstIndex(of: w), at(k + 1) != nil, i == k || i == k + 1 {
                return make(k, k + 1, m.map { $0 + meaningOf(k + 1) })
            }
        }
        // 在 + place: at / in …
        if let k = hz.firstIndex(of: "在"), at(k + 1) != nil, i == k || i == k + 1 {
            return make(k, k + 1, ["in " + meaningOf(k + 1), "at " + meaningOf(k + 1)])
        }
        // a sentence ending in 吧 or 呢: let's … / and …?
        if hz.last == "吧" && i == hz.count - 1 { return Link(header: "… 吧", pinyin: "… ba", meanings: ["let's …", "… OK?"]) }
        if hz.last == "呢" && i == hz.count - 1 { return Link(header: "… 呢", pinyin: "… ne", meanings: ["and …?", "what about …?"]) }
        return nil
    }

    /// A word's short meaning (its card's `short`, "(yes/no question)"), else its meaning.
    static func short(_ h: String) -> String {
        if let c = Course.shared.cardsByHanzi[h.filter(Course.isHan)]?.first { return c.word.gloss }
        return meaning(h)
    }

    /// The whole English of a sentence whose words can't be matched one by one (How are you? for
    /// 你好吗): shown first on each of its Chinese words, as Duolingo's phrase hints.
    static func phrase(_ en: String, _ words: [SentenceWord]) -> String? {
        guard words.count > 1 else { return nil }
        let whole = words.map(\.hanzi).joined()
        let hits = english(en, words).compactMap(\.word)
        return !hits.isEmpty && hits.allSatisfy({ $0.hanzi == whole }) ? en : nil
    }

    static let filler: Set<String> = ["the", "a", "an", "to", "of", "is", "are", "am", "be", "it", "its", "that", "this", "and", "or",
                                      "for", "in", "on", "at", "with", "some", "do", "does", "did"]
    static let alias: [String: [String]] = ["me": ["i"], "my": ["i"], "mine": ["i"], "your": ["you"], "yours": ["you"],
                                            "yes": ["yes", "right", "correct"], "ok": ["good", "okay"], "okay": ["good", "okay"],
                                            "hi": ["hello"], "bye": ["goodbye", "bye"], "thank": ["thank"], "thanks": ["thank"],
                                            // (the owner, 2 Oct 2026: "am" in "I am Mark." is 是)
                                            "am": ["be"], "is": ["be"], "are": ["be"], "was": ["be"], "were": ["be"], "be": ["be"]]

    /// An English word folded to its stem: plurals, -ing, -ed and n't (web: enStem).
    static func stem(_ word: String) -> String {
        var w = word.lowercased().replacingOccurrences(of: "’", with: "'").filter { ("a"..."z").contains($0) || $0 == "'" }
        if w.hasSuffix("n't") { return "not" }
        w = w.replacingOccurrences(of: "'(s|m|re|ll|d|ve)$", with: "", options: .regularExpression)
        if w.count > 4 && w.hasSuffix("ies") { return String(w.dropLast(3)) + "y" }
        if w.count > 5 && w.hasSuffix("ing") { return String(w.dropLast(3)) }
        if w.count > 4 && w.hasSuffix("ed") { return String(w.dropLast(2)) }
        if w.count > 3 && w.hasSuffix("s") && !w.hasSuffix("ss") { return String(w.dropLast()) }
        return w
    }

    struct Token: Hashable { let text: String; let word: SentenceWord?; let none: Bool }

    /// Particles whose meanings say what they do, not what they mean ("(yes/no question)",
    /// "softens a reply"): no English word is ever theirs. (吧 is "let's …", so it stays.)
    static let unhinted: Set<String> = ["了", "吗", "呢", "啊", "哇", "呀", "嘛", "啦", "哦"]

    /// Each English word matched to the Chinese word whose meaning contains it; filler
    /// words match nothing, so a hint is never a guess (web: englishHints). A meaning's
    /// Chinese examples don't count ("softens a reply: 好啊 sure!" gave Sure → 啊, the owner's
    /// report), and a one-word English (Sure!) that matches nothing is the whole sentence.
    static func english(_ en: String, _ words: [SentenceWord]) -> [Token] {
        let pools: [(w: SentenceWord, stems: Set<String>)] = words.filter { !unhinted.contains($0.hanzi) }.map { w in
            let m = (Course.wordEn[w.hanzi] ?? meaning(w.hanzi)).replacingOccurrences(of: "\\([^)]*\\)", with: " ", options: .regularExpression)
                .replacingOccurrences(of: "\\p{Han}+[^,;]*", with: " ", options: .regularExpression)
            let stems = m.components(separatedBy: CharacterSet.letters.union(CharacterSet(charactersIn: "'")).inverted)
                .map(stem).filter { !$0.isEmpty && (!filler.contains($0) || $0 == "be") }
            return (w, Set(stems))
        }
        func keys(_ st: String) -> [String] {
            var ks = alias[st] ?? [st]
            if st.count > 4 && st.hasSuffix("er") {                          // cheaper, colder, bigger
                let base = String(st.dropLast(2)); ks += [base, base + "e"]
                if let l = base.last, base.dropLast().last == l { ks.append(String(base.dropLast())) }
                if base.hasSuffix("i") { ks.append(String(base.dropLast()) + "y") }
            }
            return ks
        }
        func find(_ ks: [String]) -> SentenceWord? {
            for k in ks { if let hit = pools.first(where: { $0.stems.contains(k) }) { return hit.w } }
            for k in ks where k.count >= 4 {                                   // "plane" in "aeroplane"
                if let hit = pools.first(where: { $0.stems.contains { $0.count > k.count && $0.hasSuffix(k) } }) { return hit.w }
            }
            return nil
        }
        var out = en.split(separator: " ", omittingEmptySubsequences: true).map { raw in
            let tok = String(raw), st = stem(tok)
            guard !st.isEmpty else { return Token(text: tok, word: nil, none: false) }
            let hit = filler.contains(st) && alias[st] == nil ? nil : find(keys(st))
            return hit.map { Token(text: tok, word: $0, none: false) } ?? Token(text: tok, word: nil, none: true)
        }
        // a name: an English name left over takes the name left over in the Chinese, in order
        // ("Mark." is 马克)
        let names = Set(Course.shared.nameList)
        var spare = words.filter { w in names.contains(w.hanzi.filter(Course.isHan)) && !out.contains { $0.word == w } }
        for i in out.indices where out[i].word == nil && out[i].text.first?.isUppercase == true && out[i].text != "I" {
            guard !spare.isEmpty else { break }
            out[i] = Token(text: out[i].text, word: spare.removeFirst(), none: false)
        }
        // an idiom (How are you? 你好吗; Sure! 好啊): when no English word has a Chinese word of its
        // own, every one of them shows the whole
        let content = out.indices.filter { !stem(out[$0].text).isEmpty && !filler.contains(stem(out[$0].text)) || alias[stem(out[$0].text)] != nil }
        if !content.isEmpty, content.allSatisfy({ out[$0].word == nil }), words.count > 1 {
            let whole = SentenceWord(hanzi: words.map(\.hanzi).joined(), pinyin: words.map(\.pinyin).joined(separator: " "))
            for i in content { out[i] = Token(text: out[i].text, word: whole, none: false) }
        }
        return out
    }
}

/// A tappable piece of a prompt that shows a small bubble: the meaning and pinyin of a
/// Chinese word, or the Chinese for an English word (web: hintable).
/// Which hint bubble is open: one at a time, so opening one closes any other (the owner,
/// 4 Oct 2026: "they both stay up at the same time").
@Observable final class HintFocus {
    static let shared = HintFocus()
    var open: AnyHashable?
}

struct HintChip<Label: View>: View {
    let hanzi: String?
    var pinyin: String? = nil
    var reverse = false            // show the Chinese, for an English word
    var highlight: Color? = nil
    /// what the whole phrase means, shown first (你好吗: "How are you?"), as Duolingo's phrase hints
    var phrase: String? = nil
    /// words it works with across the sentence (你 … 吗 "do you…?"), shown above its own meanings
    var link: Hints.Link? = nil
    /// for an English word: its span (How are you) and other Chinese for it
    var span: String? = nil
    /// the English word tapped: its other Chinese are looked up when the bubble opens
    var english: String? = nil
    /// also told of a tap (a word's pinyin, hidden once it's strong, shows on a tap)
    var tapped: (() -> Void)? = nil
    @ViewBuilder var label: Label
    @State private var me = UUID()
    @State private var openedAt = Date.distantPast
    private var focus = HintFocus.shared
    private var open: Bool { focus.open == AnyHashable(me) }

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.12)) { focus.open = open ? nil : AnyHashable(me) }
            guard open else { return }
            // said, unless it was only just heard (the speaker beside it says it again)
            if let h = hanzi { Speech.shared.autoSpeak(h) }
            HintTip.used = true
            tapped?()
            // it closes by itself after a few seconds, or at another tap
            let stamp = Date()
            openedAt = stamp
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                if openedAt == stamp && open { withAnimation(.easeIn(duration: 0.15)) { focus.open = nil } }
            }
        } label: {
            label
                .padding(.horizontal, 2)
                .background(open ? Color.accentSoft : highlight ?? .clear, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .hintBubble(open: Binding(get: { open }, set: { if !$0 && open { focus.open = nil } })) {
            HintBubble(hanzi: hanzi, pinyin: pinyin, reverse: reverse, phrase: phrase, link: link, span: span,
                       alternatives: english.map { Hints.alternatives($0, besides: hanzi ?? "") } ?? [])
        }
    }
}

/// What a hint says: a phrase's meaning first when there is one, then the word's short meaning
/// (or, for an English word, its Chinese) and pinyin. Its width is worked out from its text, so
/// it wraps instead of running off the card (the owner's 你好吗 screenshot, 2 Oct 2026).
struct HintBubble: View {
    let hanzi: String?
    var pinyin: String? = nil
    var reverse = false
    var phrase: String? = nil
    var link: Hints.Link? = nil
    var span: String? = nil
    var alternatives: [SentenceWord] = []
    var empty = "No separate word in Chinese"

    private var rows: [String] {
        guard !reverse, let h = hanzi else { return [] }
        // not a meaning the link above already says (呢: "and …?" twice)
        let said = (link?.meanings ?? []).map { $0.lowercased().replacingOccurrences(of: " …?", with: "").replacingOccurrences(of: " …", with: "") }
        let all = Hints.senses(h)
        let kept = all.filter { r in !said.contains { r.lowercased().hasPrefix($0) } }
        return kept.isEmpty ? Array(all.prefix(1)) : kept
    }
    private var width: CGFloat {
        let texts = [phrase ?? "", span ?? ""] + rows + (link?.meanings ?? []) + [link?.header ?? ""]
        let longest = CGFloat(texts.map(\.count).max() ?? 0) * 8.4
        let chars = CGFloat(([hanzi ?? ""] + alternatives.map(\.hanzi)).map(\.count).max() ?? 0) * 26
        return min(240, max(110, max(longest, chars) + 28))
    }

    var body: some View {
        VStack(spacing: 0) {
            if let phrase {
                row(phrase, strong: true)
                divider
            }
            if let link {
                // the words working together, then what they mean together
                VStack(spacing: 1) {
                    Text(link.pinyin).font(.nunito(12, .semibold)).foregroundStyle(Color.muted)
                    Text(link.header).font(.hanzi(20, .bold)).foregroundStyle(Color.ink)
                }
                .padding(.vertical, 7)
                divider
                ForEach(link.meanings, id: \.self) { m in
                    row(m, strong: true)
                    divider
                }
            }
            if let h = hanzi {
                let py = pinyin ?? Course.wordPy[h] ?? ""
                if reverse {
                    // as Duolingo's: the English (with the words beside it that go with it), then a row
                    // for each Chinese: this sentence's first, then others that mean it
                    if let span { row(span, strong: true); divider }
                    // pinyin and characters, always both (the owner, 4 Oct 2026)
                    VStack(spacing: 1) {
                        PinyinText(pinyin: py, size: 13)
                        ToneText(hanzi: h, pinyin: py, size: 24, weight: .bold)
                    }
                    .padding(.vertical, 7)
                    ForEach(alternatives, id: \.hanzi) { a in
                        divider
                        VStack(spacing: 1) {
                            PinyinText(pinyin: a.pinyin, size: 12)
                            Text(a.hanzi).font(.hanzi(19, .semibold)).foregroundStyle(Color.ink.opacity(0.8))
                        }
                        .padding(.vertical, 6)
                    }
                } else {
                    VStack(spacing: 1) {
                        PinyinText(pinyin: py, size: 12.5)
                        if link != nil || phrase != nil { Text(h).font(.hanzi(17, .semibold)).foregroundStyle(Color.ink) }
                    }
                    .padding(.top, 6).padding(.bottom, rows.isEmpty ? 6 : 2)
                    ForEach(Array(rows.enumerated()), id: \.offset) { k, m in
                        if k > 0 { divider }
                        row(m, strong: k == 0 && link == nil && phrase == nil)
                    }
                    if rows.isEmpty { row("No meaning listed yet", strong: false) }
                }
            } else if phrase == nil && link == nil {
                row(empty, strong: false)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: width)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.panel)
            .shadow(color: .black.opacity(0.18), radius: 8, y: 3))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var divider: some View { Rectangle().fill(Color.line).frame(height: 1) }

    private func row(_ text: String, strong: Bool) -> some View {
        Text(text).font(.nunito(strong ? 15.5 : 14.5, strong ? .heavy : .semibold))
            .foregroundStyle(strong ? Color.ink : Color.ink.opacity(0.8))
            .multilineTextAlignment(.center).frame(maxWidth: .infinity)
            .padding(.horizontal, 12).padding(.vertical, 7)
    }
}

extension View {
    /// A hint bubble standing above this view, drawn over its neighbours and kept on the screen;
    /// a tap on it closes it. (Not a popover: one, once dismissed, wouldn't always open again,
    /// and one on a sentence tile, once dismissed, closed the whole lesson: the owner's reports.)
    func hintBubble<B: View>(open: Binding<Bool>, @ViewBuilder _ bubble: @escaping () -> B) -> some View {
        modifier(HintBubbleModifier(open: open, bubble: bubble))
    }
}

private struct HintBubbleModifier<B: View>: ViewModifier {
    @Binding var open: Bool
    let bubble: () -> B
    @State private var anchor: CGRect = .zero
    @State private var size: CGSize = .zero

    /// Below the word, as Duolingo's (above, the exercise card cut a tall one off: the Mac's
    /// check of 0.1.37); above only when it wouldn't fit below (a word low on the screen).
    private var below: Bool {
        let screen = UIScreen.main.bounds.height
        return anchor.maxY + 6 + size.height < screen - 170      // (the Check button's band)
    }

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { anchor = $0 }
            .overlay(alignment: below ? .bottom : .top) {
                if open {
                    // a line with no height along the word's edge, and the bubble hanging from it
                    Color.clear.frame(height: 0)
                        .overlay(alignment: below ? .top : .bottom) {
                            bubble()
                                .fixedSize()
                                .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
                                .offset(x: shift)
                                .contentShape(Rectangle())
                                .onTapGesture { withAnimation(.easeIn(duration: 0.12)) { open = false } }
                                .padding(below ? .top : .bottom, 6)
                        }
                        .transition(.opacity)
                }
            }
            .zIndex(open ? 10 : 0)
    }

    /// Sideways, so the bubble stays clear of the exercise card's edges (about 19 points in from
    /// the screen's, and a little more).
    private var shift: CGFloat {
        let screen = UIScreen.main.bounds.width, margin: CGFloat = 26
        let left = anchor.midX - size.width / 2, right = anchor.midX + size.width / 2
        if left < margin { return margin - left }
        if right > screen - margin { return screen - margin - right }
        return 0
    }
}

/// "Tap a word for its meaning", until a hint has been used once.
enum HintTip {
    static var used: Bool {
        get { UserDefaults.standard.bool(forKey: "hintUsed") }
        set { UserDefaults.standard.set(newValue, forKey: "hintUsed") }
    }
}

/// What a beginner is shown only at first, and what's shown once: kept on this phone.
enum Coach {
    private static let d = UserDefaults.standard
    /// Sessions finished here (any kind), for help that fades after the first few.
    static var sessions: Int { d.integer(forKey: "coachSessions") }
    static func sessionFinished() { d.set(sessions + 1, forKey: "coachSessions") }
    /// "What are tones?" beside a pinyin drill: for the first three sessions, or until tapped once.
    static var showTonesLink: Bool { sessions < 3 && !d.bool(forKey: "tonesLinkTapped") }
    static func tonesLinkTapped() { d.set(true, forKey: "tonesLinkTapped") }
    /// The tones' intro card has been seen (or, before it existed, the primer opened itself once).
    static var tonesSeen: Bool { d.bool(forKey: "tonesSeen") }
    static func markTonesSeen() { d.set(true, forKey: "tonesSeen") }
    /// A stone's notes are shown as a tip once, when it's first started.
    static func tipSeen(_ lessonId: String) -> Bool { (d.stringArray(forKey: "tipsSeen") ?? []).contains(lessonId) }
    static func markTipSeen(_ lessonId: String) {
        var seen = d.stringArray(forKey: "tipsSeen") ?? []
        if !seen.contains(lessonId) { seen.append(lessonId); d.set(seen, forKey: "tipsSeen") }
    }
}
