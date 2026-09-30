import Foundation

// Help for total beginners in the exercises: pinyin training wheels, what to play aloud
// and when, and gentler, specific corrections. Pure rules, so they can be tested.

// MARK: pinyin training wheels

/// Settings → Pinyin: when pinyin shows over the Chinese in an exercise.
enum PinyinMode: String, CaseIterable {
    /// over a word until it's strong (see TrainingWheels.isStrong), then a tap away
    case auto
    /// over every word, always
    case always
    /// over a word only until it's been learned at all (answered right once), then a tap away
    case known
}

extension Prefs {
    /// The pinyin setting. Never chosen: Auto, unless the old "Show pinyin" switch was turned
    /// off, which becomes the strictest, "Hide when known". Choosing one also sets
    /// `showPinyin`, which the website reads.
    var pinyin: PinyinMode {
        get { pinyinMode.flatMap { PinyinMode(rawValue: $0) } ?? (showPinyin ? .auto : .known) }
        set { pinyinMode = newValue.rawValue; showPinyin = newValue != .known }
    }
    /// Play an exercise's Chinese as it appears, and the right answer after it (default on).
    var playsAutomatically: Bool { autoplay ?? true }
}

enum TrainingWheels {
    /// A word is strong once it has been answered right this many times in its reviews…
    static let strongReps = 3
    /// …or its reviews are spaced at least this many days apart.
    static let strongDays = 3.0

    /// On Auto, pinyin stays over every word through the first books; only from this book
    /// on does it fade from the words you know (the owner: "more when we get to the 4th book").
    static let fadeFromBook = 4

    /// Whether a word is strong enough to go without its pinyin (Auto).
    static func isStrong(_ s: SRSRecord?) -> Bool {
        guard let s else { return false }
        return (s.reps ?? 0) >= strongReps || (s.interval ?? 0) >= strongDays
    }

    /// Whether an exercise is testing the pinyin itself: "Which pinyin?", and listening until
    /// it's answered. No pinyin is shown on its Chinese then, whatever the setting.
    static func testsPinyin(dir: String, answered: Bool) -> Bool {
        !answered && (dir == "pinyin" || dir == "listen")
    }

    /// Whether pinyin shows over a word (where it doesn't, a tap on the word shows it).
    static func shows(_ s: SRSRecord?, mode: PinyinMode, testing: Bool = false, early: Bool = false) -> Bool {
        if testing { return false }
        switch mode {
        case .always: return true
        case .auto: return early || !isStrong(s)
        case .known: return StudySession.isNewCard(s)
        }
    }
}

/// The training wheels for one exercise: the learner's records as the exercise appeared (so
/// answering doesn't make the pinyin vanish mid-feedback) and the setting.
struct Wheels {
    var srs: [String: SRSRecord] = [:]
    var mode: PinyinMode = .auto
    /// The learner is still in the first books, where Auto keeps pinyin on everything.
    var early = false

    /// A word's record: its own card's, the strongest if the course has it more than once.
    func record(hanzi: String) -> SRSRecord? {
        let cards = Course.shared.cardsByHanzi[hanzi.filter(Course.isHan)] ?? []
        let recs = cards.compactMap { srs[$0.id] }
        return recs.first(where: { TrainingWheels.isStrong($0) }) ?? recs.first
    }

    func shows(card: Card, testing: Bool = false) -> Bool {
        TrainingWheels.shows(srs[card.id], mode: mode, testing: testing, early: early)
    }

    func shows(hanzi: String, testing: Bool = false) -> Bool {
        TrainingWheels.shows(record(hanzi: hanzi), mode: mode, testing: testing, early: early)
    }
}

extension Wheels {
    /// The training wheels for a learner as things stand: their records (or the ones given),
    /// their setting, and whether they're still in the first books (pinyin over everything).
    static func now(_ p: ProgressStore, srs: [String: SRSRecord]? = nil) -> Wheels {
        var w = Wheels(srs: srs ?? p.srs, mode: p.prefs.pinyin)
        let here = p.currentLessonId ?? Course.shared.lessons.last?.id ?? ""
        w.early = Course.shared.bookNumber(of: here) < TrainingWheels.fadeFromBook
        return w
    }
}

// MARK: hearing it

/// What an exercise says aloud by itself, without giving the answer away.
enum Autoplay {
    /// As the exercise appears: its Chinese prompt. Nothing where hearing it would be the
    /// answer: recall (English → Chinese) and building the Chinese (the sound is the answer),
    /// "Which pinyin?" (the tones are). Listening always plays, since the sound is the question;
    /// the rest only with "Play audio automatically" on, writing too (hearing a word doesn't
    /// say how to write it). Speaking has its own.
    static func onShow(_ ex: Exercise, autoplay: Bool) -> String? {
        if ex.kind == .choice {
            if ex.dir == "listen" { return ex.card.word.hanzi }
            if ex.dir == "recognize" && autoplay { return ex.card.word.hanzi }
            return nil
        }
        if ex.kind == .sentence, autoplay, !ex.toChinese, let s = ex.sentence { return s.hanzi }
        if ex.kind == .write, autoplay { return ex.card.word.hanzi }
        return nil
    }

    /// Once the answer is out: the right Chinese, but only if it wasn't already said as the
    /// exercise appeared (then the right or wrong chime is enough: once is plenty).
    static func onAnswer(_ ex: Exercise, autoplay: Bool) -> String? {
        guard autoplay, onShow(ex, autoplay: autoplay) == nil else { return nil }
        if ex.kind == .choice { return ex.card.word.hanzi }
        if ex.kind == .sentence { return ex.sentence?.hanzi }
        return nil
    }
}

// MARK: pick, then check

/// Multiple choice, Duolingo's way: a tap selects an option, another tap moves the selection,
/// and only Check answers, so a slip of the thumb costs nothing. The selection lives on the
/// screen; the session only hears of the option checked (`StudySession.answer`).
struct ChoicePick: Equatable {
    /// the option selected (nil: none yet)
    private(set) var selected: String?

    /// Whether Check can be pressed: once something is selected.
    var canCheck: Bool { selected != nil }

    /// An option tapped. False (and nothing changes) once the exercise is answered, or if
    /// it isn't one of the exercise's options.
    @discardableResult
    mutating func select(_ option: String, in ex: Exercise, answered: Bool) -> Bool {
        guard !answered, ex.kind == .choice, ex.options.contains(option) else { return false }
        selected = option
        return true
    }

    /// Check pressed: whether the option selected is the right one (nil: nothing to check).
    func verdict(_ ex: Exercise) -> Bool? {
        guard ex.kind == .choice, let selected else { return nil }
        return selected == ex.answer
    }
}

// MARK: tap to hear

/// A Chinese option or sentence tile is said as it's tapped, except where hearing it would
/// give the answer away: in a listening exercise the sound is the question, so nothing is
/// said until it's answered. (This rests on one source in the Duolingo teardown: `enabled`
/// switches it off everywhere.)
enum TapToHear {
    /// The one switch: false, and no option or tile speaks.
    static let enabled = true

    /// Whether the settings allow it: sound on, and audio playing by itself not switched off.
    static func allowed(_ prefs: Prefs) -> Bool {
        enabled && prefs.sound && prefs.playsAutomatically
    }

    /// What to say for a text tapped in an exercise (nil: nothing).
    static func say(_ text: String, in ex: Exercise, answered: Bool, allowed: Bool) -> String? {
        guard enabled, allowed else { return nil }
        if ex.dir == "listen" && !answered { return nil }
        guard text.contains(where: Course.isHan) else { return nil }
        return text
    }

    /// A multiple-choice option selected.
    static func option(_ option: String, in ex: Exercise, answered: Bool, allowed: Bool = true) -> String? {
        guard ex.kind == .choice else { return nil }
        return say(option, in: ex, answered: answered, allowed: allowed)
    }

    /// A sentence tile tapped into the answer.
    static func tile(_ tile: Exercise.Tile, in ex: Exercise, answered: Bool, allowed: Bool = true) -> String? {
        guard ex.kind == .sentence else { return nil }
        return say(tile.text, in: ex, answered: answered, allowed: allowed)
    }
}

// MARK: gentler corrections

/// One short line saying what was different about a wrong answer (the right answer is
/// shown under it). Look-alike characters are explained by the feedback's own diff.
enum Correction {
    /// "1st", "2nd", "3rd", "4th", or "neutral" (5), from toneOf.
    static func ordinal(_ tone: Int) -> String {
        switch tone {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        case 4: return "4th"
        default: return "neutral"
        }
    }

    /// Same sounds, different tones: "Close! 好 is hǎo — 3rd tone (you chose hào — 4th)".
    /// For a word where more than one syllable is off (or the characters don't line up with
    /// the syllables), the whole word: "Close! 你好 is nǐ hǎo — 3rd + 3rd tones (you chose
    /// ní hào — 2nd + 4th)". Nil when the letters differ too.
    static func toneLine(hanzi: String, right: String, chosen: String) -> String? {
        let r = Pinyin.syllables(right), c = Pinyin.syllables(chosen)
        guard !r.isEmpty, r.count == c.count, right != chosen,
              Pinyin.toneless(right).lowercased() == Pinyin.toneless(chosen).lowercased() else { return nil }
        let differ = r.indices.filter { r[$0] != c[$0] }
        guard !differ.isEmpty else { return nil }
        let han = hanzi.filter(Course.isHan).map(String.init)
        if differ.count == 1 && han.count == r.count {
            let i = differ[0]
            return "Close! \(han[i]) is \(r[i]) — \(ordinal(toneOf(r[i]))) tone (you chose \(c[i]) — \(ordinal(toneOf(c[i]))))"
        }
        let tones = { (s: [String]) in s.map { Correction.ordinal(toneOf($0)) }.joined(separator: " + ") }
        return "Close! \(hanzi) is \(right) — \(tones(r)) \(r.count == 1 ? "tone" : "tones") (you chose \(chosen) — \(tones(c)))"
    }

    /// The wrong meaning: "你 means 'you'. (他 is 'he')".
    static func meaningLine(_ right: Word, _ other: Word) -> String {
        "\(right.hanzi) means '\(right.gloss)'. (\(other.hanzi) is '\(other.gloss)')"
    }

    /// The line for a wrong multiple-choice answer, if there's something specific to say.
    static func line(_ ex: Exercise, chosen: String?, cards: [Card] = Course.shared.cards) -> String? {
        guard ex.kind == .choice, let chosen, chosen != ex.answer else { return nil }
        let w = ex.card.word
        switch ex.dir {
        case "pinyin":
            return toneLine(hanzi: w.hanzi, right: w.pinyin, chosen: chosen)
        case "recall":
            guard let o = cards.first(where: { $0.word.hanzi == chosen })?.word, o.hanzi != w.hanzi else { return nil }
            return meaningLine(w, o)
        case "recognize", "listen":
            guard let o = cards.first(where: { $0.word.gloss == chosen })?.word, o.hanzi != w.hanzi else { return nil }
            return meaningLine(w, o)
        default:
            return nil
        }
    }
}
