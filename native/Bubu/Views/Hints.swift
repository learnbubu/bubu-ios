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
struct HintChip<Label: View>: View {
    let hanzi: String?
    var pinyin: String? = nil
    var reverse = false            // show the Chinese, for an English word
    var highlight: Color? = nil
    /// also told of a tap (a word's pinyin, hidden once it's strong, shows on a tap)
    var tapped: (() -> Void)? = nil
    @ViewBuilder var label: Label
    @State private var open = false
    @State private var openedAt = Date.distantPast

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.12)) { open.toggle() }
            guard open else { return }
            // said, unless it was only just heard (the speaker beside it says it again)
            if let h = hanzi { Speech.shared.autoSpeak(h) }
            HintTip.used = true
            tapped?()
            // it closes by itself after a few seconds, or at another tap
            let stamp = Date()
            openedAt = stamp
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if openedAt == stamp { withAnimation(.easeIn(duration: 0.15)) { open = false } }
            }
        } label: {
            label
                .padding(.horizontal, 2)
                .background(open ? Color.accentSoft : highlight ?? .clear, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        // the bubble always above the word, drawn over its neighbours (not a popover: one, once
        // dismissed, sometimes wouldn't open again, the owner's report of 2 Oct 2026)
        .overlay(alignment: .top) {
            if open {
                bubble
                    .fixedSize()
                    .alignmentGuide(.top) { d in d[.bottom] + 6 }
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
                    .onTapGesture { withAnimation(.easeIn(duration: 0.12)) { open = false } }
            }
        }
        .zIndex(open ? 10 : 0)
    }

    private var bubble: some View {
            VStack(spacing: 3) {
                if let h = hanzi {
                    let py = pinyin ?? Course.wordPy[h] ?? ""
                    if reverse {
                        ToneText(hanzi: h, pinyin: py, size: 24, weight: .bold)
                    } else {
                        Text(Hints.meaning(h).isEmpty ? "No meaning listed yet" : Hints.meaning(h))
                            .font(.nunito(15, .bold)).foregroundStyle(Color.ink).multilineTextAlignment(.center)
                    }
                    PinyinText(pinyin: py, size: 14)
                } else {
                    Text("No separate word in Chinese").font(.nunito(14, .semibold)).foregroundStyle(Color.muted)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(maxWidth: 240)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.panel)
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.line, lineWidth: 1))
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
