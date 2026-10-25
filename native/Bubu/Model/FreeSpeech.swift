import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Speaking freely in the Classroom's chats (the owner, 23 Oct 2026: "inside the classroom ... more freely say whatever
/// you think is right, and then [it] will come back: well done, that works well, or give you ways to improve or correct
/// you"): you're told what to say in English, say it your own way, and a tutor judges it. The tutor is Apple's on-phone
/// model (Apple Intelligence: free, private, offline; the owner's pick), where the phone has it. Elsewhere the chats keep
/// their set lines, judged as before.
struct SpeakingVerdict: Equatable {
    /// a sensible reply that fits, worded however
    var works: Bool
    /// a sentence or two for you, in English
    var comment: String
    /// how a native speaker might say it (a correction, or another natural way), with its pinyin
    var better: String?
    var betterPinyin: String?
    /// it was the example, or near enough, without asking the tutor
    var spotOn = false
    /// the Chinese words the comment is about, each with its pinyin and meaning (never a word left unexplained: the
    /// owner, 23 Oct 2026, "only the hanzi, no clue what it meant")
    var words: [SpeakingWord] = []
}

struct SpeakingWord: Equatable {
    let hanzi: String
    let pinyin: String?
    let en: String
}

enum FreeSpeech {
    /// The phone has the on-phone model, ready (iOS 26 and Apple Intelligence on).
    static var available: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), !Launch.underTests {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    /// What you said, judged: against the example first (said near enough, no need to ask), then by the tutor.
    /// `before` is the line you're answering; nil if the tutor couldn't be reached (the chat then judges as before).
    static func judge(said alts: [String], goal: Turn, before: Turn?, confidence: Float = 0) async -> SpeakingVerdict? {
        guard let raw = alts.first?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        let heard = clean(raw)
        if SpeechScore.score(goal.hanzi, alts.map(clean), keyword: nil).level == .exact {
            return SpeakingVerdict(works: true, comment: "Spot on!", spotOn: true)
        }
        // (not asked when there's no Chinese to judge: the model passed "呃 yes am call", the owner's phone, 23 Oct 2026)
        if let gate = noChinese(heard, goal: goal) { return gate }
        // (the recogniser unsure of what it wrote: sounds, not words)
        if confidence > 0 && confidence < 0.45 {
            return SpeakingVerdict(works: false, comment: "I couldn't make that out. Try again, a little slower?",
                                   better: goal.hanzi, betterPinyin: goal.pinyin)
        }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), available {
            guard var v = await ask(heard: heard, goal: goal, before: before) else { return nil }
            // (the model passes nonsense now and then: a reply sharing almost nothing with the example or the line
            // it answers is told to try again)
            if v.works && overlap(heard, goal: goal, before: before) < 0.2 {
                v = SpeakingVerdict(works: false, comment: "That doesn't quite answer this. Try again, or tap Need help?",
                                    better: goal.hanzi, betterPinyin: goal.pinyin)
            }
            return v
        }
        #endif
        return nil
    }

    /// Hesitation sounds, not words: left out of what's judged.
    static let fillers: Set<Character> = ["呃", "嗯", "啊", "额", "哦", "唔", "诶", "欸", "哎"]

    /// What was heard without the hesitations.
    static func clean(_ s: String) -> String {
        String(s.filter { !fillers.contains($0) }).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Mostly English (or nothing but hesitations): not Chinese to judge, so try again, the example offered.
    static func noChinese(_ heard: String, goal: Turn) -> SpeakingVerdict? {
        let han = heard.filter(Course.isHan)
        let latin = heard.filter { $0.isASCII && $0.isLetter }.count
        // (an English word in it at all: "耶我会跟你 great" was passed; the owner, 25 Oct 2026)
        let englishWord = heard.split(whereSeparator: { !($0.isASCII && $0.isLetter) }).contains { $0.count >= 2 }
        let again = { (c: String) in SpeakingVerdict(works: false, comment: c, better: goal.hanzi, betterPinyin: goal.pinyin) }
        if han.isEmpty || latin > han.count * 2 {
            return again(latin > 0 ? "That sounded like English. Have a go in Chinese!" : "I didn't catch any Chinese there. Try again?")
        }
        if englishWord { return again("Some of that was English. Say it all in Chinese!") }
        // (mostly characters from no word of the course: not words at all, babble heard as Chinese; "奥利嘎都嘎啵啵扒皮噗"
        // was passed, the owner, 25 Oct 2026)
        let known = han.filter { courseChars.contains($0) }.count
        if Double(known) / Double(han.count) < 0.6 {
            return again("I couldn't make that out as Chinese words. Try again, or tap Need help?")
        }
        return nil
    }

    /// every character in the course's words and lines
    static let courseChars: Set<Character> = {
        var s = Set<Character>()
        for c in Course.shared.cards { for ch in c.word.hanzi where Course.isHan(ch) { s.insert(ch) } }
        for t in Course.shared.data.dialogues.flatMap(\.turns) { for ch in t.hanzi where Course.isHan(ch) { s.insert(ch) } }
        return s
    }()

    /// How much of the reply is the example's or the line being answered's: a reply that shares almost nothing with
    /// either isn't an answer to it, whatever the model says.
    static func overlap(_ heard: String, goal: Turn, before: Turn?) -> Double {
        let h = Set(heard.filter(Course.isHan)), g = Set(goal.hanzi.filter(Course.isHan)).union(before.map { Set($0.hanzi.filter(Course.isHan)) } ?? [])
        guard !h.isEmpty else { return 0 }
        return Double(h.intersection(g).count) / Double(h.count)
    }

    /// The pinyin of a sentence from the course's own words (its chats' lines, its cards, longest first), never the
    /// model's (it wrote "mǎk" for 马克); nil if any character isn't in the course.
    static func pinyin(_ hanzi: String) -> String? {
        enum Kind { case word, punct, latin }
        let chars = Array(hanzi)
        // longest words first, backing off when a longer one leaves a character with no word (the Mac, 23 Oct 2026:
        // taking the longest each time stranded characters in 11 of the course's lines)
        var memo: [Int: [(String, Kind)]?] = [:]
        func from(_ i: Int) -> [(String, Kind)]? {
            if i >= chars.count { return [] }
            if let m = memo[i] { return m }
            var r: [(String, Kind)]? = nil
            let c = chars[i]
            if !Course.isHan(c) {
                if let rest = from(i + 1) {
                    if let p = punct[c] { r = [(p, .punct)] + rest }
                    else if c.isASCII && (c.isLetter || c.isNumber) { r = [(String(c), .latin)] + rest }
                    else { r = rest }                       // (quotes, spaces: left out)
                }
            } else {
                for n in stride(from: min(lexiconLongest, chars.count - i), through: 1, by: -1) {
                    guard let p = lexicon[String(chars[i..<(i + n)])], let rest = from(i + n) else { continue }
                    r = [(p, .word)] + rest
                    break
                }
            }
            memo[i] = r
            return r
        }
        guard let parts = from(0), parts.contains(where: { $0.1 == .word }) else { return nil }
        // punctuation on the word before it, letters run together ("AI"), words spaced
        var out = ""
        var last: Kind?
        for (t, k) in parts {
            if k == .punct || (k == .latin && last == .latin) || out.isEmpty { out += t } else { out += " " + t }
            last = k
        }
        return out
    }

    private static let punct: [Character: String] = ["，": ",", "。": ".", "！": "!", "？": "?", "、": ",", "；": ";", "：": ":", "…": "…"]

    /// Each word's pinyin, as the course has it: its chats' lines split into words, and its cards.
    private static let lexicon: [String: String] = {
        var d: [String: String] = [:]
        let course = Course.shared
        for t in course.data.dialogues.flatMap(\.turns) {
            for w in Sentence.segment(hanzi: t.hanzi, pinyin: t.pinyin) ?? [] where d[w.hanzi] == nil { d[w.hanzi] = w.pinyin }
        }
        for c in course.cards where !c.isSentence {
            let h = c.word.hanzi.filter(Course.isHan)
            if !h.isEmpty && d[h] == nil { d[h] = c.word.pinyin }
        }
        return d
    }()
    private static let lexiconLongest = lexicon.keys.map(\.count).max() ?? 1

    /// Each of the course's words, by its characters: its pinyin and its meaning.
    private static let glossary: [String: (pinyin: String, en: String)] = {
        var d: [String: (pinyin: String, en: String)] = [:]
        for c in Course.shared.cards where !c.isSentence {
            let h = c.word.hanzi.filter(Course.isHan)
            if !h.isEmpty && d[h] == nil { d[h] = (c.word.pinyin, c.word.gloss) }
        }
        return d
    }()

    /// The tutor's comment kept to English, and the Chinese it's about listed with pinyin and meaning: the words it
    /// named (their meaning from the course where it has them), then any Chinese left in the comment (taken out of it,
    /// listed when the course knows it; a misheard word with no meaning given isn't shown at all).
    static func explained(comment: String, named: [(hanzi: String, en: String)]) -> (String, [SpeakingWord]) {
        var words: [SpeakingWord] = []
        func add(_ h: String, _ en: String?) {
            let h = h.filter(Course.isHan)
            guard !h.isEmpty, !words.contains(where: { $0.hanzi == h }) else { return }
            let g = glossary[h]
            guard let meaning = g?.en ?? en.flatMap({ $0.isEmpty ? nil : $0 }) else { return }
            words.append(SpeakingWord(hanzi: h, pinyin: g?.pinyin ?? pinyin(h), en: meaning))
        }
        for w in named { add(w.hanzi, w.en) }
        // Chinese in the comment: out of the sentence ("that word"), listed below it
        var text = ""
        var run = ""
        for ch in comment {
            if Course.isHan(ch) { run.append(ch); continue }
            if !run.isEmpty { add(run, nil); text += "that word"; run = "" }
            text.append(ch)
        }
        if !run.isEmpty { add(run, nil); text += "that word" }
        // (quotes and brackets left empty around a word taken out)
        text = text.replacingOccurrences(of: #"[“"「『(（]\s*that word\s*[”"」』)）]"#, with: "that word", options: .regularExpression)
        return (text, words)
    }

    static let instructions = """
    You are a warm, encouraging Mandarin tutor for a beginner learning Chinese in an app. The learner is in a chat \
    conversation and speaks a reply aloud; you see what speech recognition heard (simplified characters; it may write a \
    word that sounds the same, so ignore those slips). You only see text: you cannot hear tones or pronunciation, so \
    never mention them. If what was heard is not Chinese, it does not work. Decide whether their reply is sensible, \
    understandable Chinese that fits the conversation and says roughly what they meant. It does NOT have to match the \
    example: any natural way of saying it works. Be generous to a beginner: small slips still work if the meaning is \
    clear. Write your comment in plain English only, one or two short sentences, kind and specific (what was good, or \
    what to change). Never put Chinese characters in the comment: describe a word in English instead ("the word for \
    teacher"), and list each Chinese word you talk about under words, with its English meaning. Speech recognition \
    can mishear, so never repeat or dwell on a strange or rude word; just say that word doesn't fit here. Give a better \
    version only if a native speaker would say it differently or there is a mistake.
    """

    static func prompt(heard: String, goal: Turn, before: Turn?) -> String {
        var p = ""
        if let b = before { p += "\(b.name ?? "They") said: \(b.hanzi) (\(b.en))\n" }
        p += "The learner wanted to say: \(goal.en)\n"
        p += "An example answer: \(goal.hanzi)\n"
        p += "The learner said: \(heard)"
        return p
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func ask(heard: String, goal: Turn, before: Turn?) async -> SpeakingVerdict? {
        do {
            let session = LanguageModelSession(instructions: instructions)
            let r = try await session.respond(to: prompt(heard: heard, goal: goal, before: before), generating: TutorFeedback.self)
            let f = r.content
            let better = f.better.trimmingCharacters(in: .whitespacesAndNewlines)
            // (no "better" that's only what they said again)
            let same = SpeechScore.clean(better) == SpeechScore.clean(heard)
            let (comment, words) = explained(comment: f.comment, named: f.words.map { ($0.hanzi, $0.english) })
            return SpeakingVerdict(works: f.works, comment: comment,
                                   better: better.isEmpty || same ? nil : better,
                                   betterPinyin: better.isEmpty || same ? nil : pinyin(better), words: words)
        } catch {
            return nil
        }
    }
    #endif
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
struct TutorFeedback {
    @Guide(description: "true if the learner's reply is sensible, understandable Chinese that fits the conversation and means roughly what they wanted, even if worded differently from the example")
    var works: Bool
    @Guide(description: "One or two short, warm sentences in plain English for the learner, with no Chinese characters: what was good, or gently what to change")
    var comment: String
    @Guide(description: "Each Chinese word the comment talks about, with its English meaning; empty if none")
    var words: [TutorWord]
    @Guide(description: "If there's a mistake or a native speaker would say it differently, the corrected or more natural sentence in simplified Chinese characters; otherwise an empty string")
    var better: String
}

@available(iOS 26.0, *)
@Generable
struct TutorWord {
    @Guide(description: "The word in simplified Chinese characters")
    var hanzi: String
    @Guide(description: "Its meaning in English, a few words")
    var english: String
}
#endif
