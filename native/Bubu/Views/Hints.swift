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
                                            "hi": ["hello"], "bye": ["goodbye", "bye"], "thank": ["thank"], "thanks": ["thank"]]

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

    /// Each English word matched to the Chinese word whose meaning contains it; filler
    /// words match nothing, so a hint is never a guess (web: englishHints).
    static func english(_ en: String, _ words: [SentenceWord]) -> [Token] {
        let pools: [(w: SentenceWord, stems: Set<String>)] = words.map { w in
            let m = (Course.wordEn[w.hanzi] ?? meaning(w.hanzi)).replacingOccurrences(of: "\\([^)]*\\)", with: " ", options: .regularExpression)
            let stems = m.components(separatedBy: CharacterSet.letters.union(CharacterSet(charactersIn: "'")).inverted)
                .map(stem).filter { !$0.isEmpty && !filler.contains($0) }
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
        return en.split(separator: " ", omittingEmptySubsequences: true).map { raw in
            let tok = String(raw), st = stem(tok)
            guard !st.isEmpty else { return Token(text: tok, word: nil, none: false) }
            let hit = filler.contains(st) && alias[st] == nil ? nil : find(keys(st))
            return hit.map { Token(text: tok, word: $0, none: false) } ?? Token(text: tok, word: nil, none: true)
        }
    }
}

/// A tappable piece of a prompt that shows a small bubble: the meaning and pinyin of a
/// Chinese word, or the Chinese for an English word (web: hintable).
struct HintChip<Label: View>: View {
    let hanzi: String?
    var pinyin: String? = nil
    var reverse = false            // show the Chinese, for an English word
    var highlight: Color? = nil
    @ViewBuilder var label: Label
    @State private var open = false

    var body: some View {
        Button {
            open = true
            if let h = hanzi { Speech.shared.speak(h) }
            HintTip.used = true
        } label: {
            label
                .padding(.horizontal, 2)
                .background(open ? Color.accentSoft : highlight ?? .clear, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $open) {
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
            .presentationCompactAdaptation(.popover)
        }
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
    /// A stone's notes are shown as a tip once, when it's first started.
    static func tipSeen(_ lessonId: String) -> Bool { (d.stringArray(forKey: "tipsSeen") ?? []).contains(lessonId) }
    static func markTipSeen(_ lessonId: String) {
        var seen = d.stringArray(forKey: "tipsSeen") ?? []
        if !seen.contains(lessonId) { seen.append(lessonId); d.set(seen, forKey: "tipsSeen") }
    }
}
