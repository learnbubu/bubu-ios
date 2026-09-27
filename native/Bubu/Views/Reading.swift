import SwiftUI

// The chapter stories and the chapter guidebooks (web: openReadings, openReading, openGuide).

extension Course {
    /// "起步 1 · Chapter 2"
    func storyFor(chapter ci: Int) -> Reading? { data.readings.first { $0.chapter == ci } }

    /// What a word means: its own card, else its characters' meanings (web: wordMeaning).
    func meaning(of hanzi: String) -> String {
        if let c = cards.first(where: { $0.word.hanzi == hanzi }) { return c.word.en }
        return hanzi.filter(Course.isHan).map { CharData.shared.meaning(String($0)) }.filter { !$0.isEmpty }.joined(separator: " + ")
    }

    /// Every character taught up to and including a chapter (web: chapterChars).
    func charsThrough(chapter ci: Int) -> Set<Character> {
        let ids = Set(chapters[0...ci].flatMap(\.lessons))
        return Set(cards.filter { ids.contains($0.lessonId) }.flatMap { $0.word.hanzi.filter(Course.isHan) })
    }

    /// Up to six dialogue lines that use only what's been taught by this chapter and
    /// at least one of its words, most useful first, then shortest first (web: keyPhrases).
    func keyPhrases(chapter ci: Int) -> [Turn] {
        let ch = chapters[ci], known = charsThrough(chapter: ci)
        let words = cards.filter { ch.lessons.contains($0.lessonId) }.map { $0.word.hanzi.filter(Course.isHan) }.filter { !$0.isEmpty }
        var seen = Set<String>(), out: [(Turn, Int, Int)] = []
        for d in data.dialogues {
            for t in d.turns {
                let han = t.hanzi.filter(Course.isHan)
                guard han.count >= 2, !seen.contains(t.hanzi), !(t.free ?? false), han.allSatisfy(known.contains) else { continue }
                let hits = words.filter { t.hanzi.contains($0) }.count
                guard hits > 0 else { continue }
                seen.insert(t.hanzi); out.append((t, hits, han.count))
            }
        }
        return out.sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.2 < $1.2 }.prefix(6).map(\.0)
            .sorted { $0.hanzi.count < $1.hanzi.count }
    }
}

/// A word you can tap for its pinyin and meaning, in a little bubble.
struct HintWord: View {
    let hanzi: String
    let pinyin: String
    var size: CGFloat = 20
    var meaning: String? = nil
    var showPinyin = false
    var onTap: (() -> Void)? = nil
    @State private var open = false

    var body: some View {
        Button {
            open = true
            Speech.shared.speak(hanzi)
            onTap?()
        } label: {
            VStack(spacing: 0) {
                if showPinyin { Text(pinyin).font(.nunito(size * 0.5)).foregroundStyle(Color.muted) }
                ToneText(hanzi: hanzi, pinyin: pinyin, size: size, weight: .medium)
                    .padding(.horizontal, 1)
                    .background(open ? Color.accentSoft : .clear, in: RoundedRectangle(cornerRadius: 5))
                    .overlay(alignment: .bottom) {
                        Line().stroke(Color.muted.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [1.5, 2.5])).frame(height: 1.5).offset(y: 2)
                    }
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $open) {
            VStack(spacing: 4) {
                TappableHanzi(text: hanzi, pinyin: pinyin, size: 26, weight: .bold)
                PinyinText(pinyin: pinyin, size: 15)
                Text(meaning ?? Course.shared.meaning(of: hanzi)).font(.nunito(14)).foregroundStyle(Color.ink).multilineTextAlignment(.center)
            }
            .padding(14)
            .frame(maxWidth: 260)
            .presentationCompactAdaptation(.popover)
        }
    }
}

// MARK: - the story list

struct ReadingsPage: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(Router.self) private var router
    private let course = Course.shared

    var body: some View {
        let reads = course.data.readings
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Finish a chapter and its story opens here. Every word in it is one you've learnt.")
                    .font(.nunito(14.5)).foregroundStyle(Color.muted).padding(.bottom, 4)
                ForEach(reads, id: \.id) { r in
                    let open = progress.chapterDone(r.chapter), done = progress.readDone(r.id)
                    Button {
                        if open { router.push(.story(r.id)) }
                        else { Moments.shared.toast("Finish every lesson in “\(course.chapters[r.chapter].title)” first.") }
                    } label: {
                        HStack(spacing: 14) {
                            ToneText(hanzi: r.title, pinyin: r.py, size: 22, weight: .bold)
                                .lineLimit(1).minimumScaleFactor(0.6).frame(width: 96, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(course.chapterLabel(r.chapter).uppercased()).font(.nunito(10.5, .black)).tracking(0.8).foregroundStyle(Color.accent)
                                Text(r.en).font(.nunitoXB(15.5)).foregroundStyle(Color.ink).multilineTextAlignment(.leading)
                                Text(open ? (done ? "Read ✓" : "New · +15 XP") : "Finish “\(course.chapters[r.chapter].title)” to open")
                                    .font(.nunito(12.5, .bold)).foregroundStyle(done ? Color.good : open ? Color.gold : Color.muted)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: open ? "chevron.right" : "lock.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.muted)
                        }
                        .padding(14)
                        .panel(radius: 16)
                        .opacity(open ? 1 : 0.6)
                    }
                    .buttonStyle(PressDown(depth: 1))
                }
            }
            .padding(.horizontal, 18).padding(.bottom, 30)
        }
        .navigationTitle("Reading")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Text("\(reads.filter { progress.readDone($0.id) }.count) / \(reads.count) read").font(.nunito(13, .semibold)).foregroundStyle(Color.muted)
            }
        }
    }
}

// MARK: - a story

struct StoryPage: View {
    let storyId: String
    @Environment(ProgressStore.self) private var progress
    @Environment(\.dismiss) private var dismiss
    @State private var pinyinOn = false
    @State private var englishOn = false
    @State private var wrong: Set<Int> = []
    @State private var solved = false
    @State private var confetti = false
    @State private var options: [Option] = []
    private struct Option: Hashable { let text: String; let index: Int }
    private let course = Course.shared

    private struct Token { let h: String; let p: String?; let e: String? }
    private func token(_ t: String) -> Token {
        let parts = t.components(separatedBy: "|")
        return parts.count == 3 ? Token(h: parts[0], p: parts[1], e: parts[2]) : Token(h: t, p: nil, e: nil)
    }

    var body: some View {
        if let r = course.data.readings.first(where: { $0.id == storyId }) {
            let all = r.sentences.map { $0.map { token($0).h }.joined() }.joined()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(course.chapterLabel(r.chapter)) · Story".uppercased()).font(.nunito(11, .black)).tracking(0.9).foregroundStyle(Color.accent)
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            ToneText(hanzi: r.title, pinyin: r.py, size: 26, weight: .bold)
                            Text(r.en).font(.nunito(16, .bold)).foregroundStyle(Color.muted)
                        }
                    }
                    HStack(spacing: 8) {
                        tool("Listen", icon: "speaker.wave.2.fill") { Speech.shared.speak(all) }
                        tool("½×", icon: nil) { Speech.shared.speak(all, slow: true) }
                        tool("Pinyin", icon: nil, on: pinyinOn) { withAnimation { pinyinOn.toggle() } }
                        tool("English", icon: nil, on: englishOn) { withAnimation { englishOn.toggle() } }
                    }
                    FlowLayout(spacing: 2, lineSpacing: pinyinOn ? 10 : 8) {
                        ForEach(Array(r.sentences.enumerated()), id: \.offset) { _, s in
                            ForEach(Array(s.enumerated()), id: \.offset) { _, raw in
                                let t = token(raw)
                                if let p = t.p {
                                    HintWord(hanzi: t.h, pinyin: p, size: 23, meaning: t.e, showPinyin: pinyinOn)
                                } else {
                                    Text(t.h).font(.hanzi(23)).foregroundStyle(Color.ink)
                                        .padding(.top, pinyinOn ? 11.5 : 0)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .panel(radius: 18)
                    if englishOn {
                        Text(r.translation).font(.nunito(15.5)).foregroundStyle(Color.ink).lineSpacing(3)
                            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.accentSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .transition(.opacity)
                    }
                    Text("Tap any word for its pinyin and meaning.").font(.nunito(13)).foregroundStyle(Color.muted)

                    question(r)
                    if solved {
                        Button("Finish") { finish(r) }.buttonStyle(WideButton()).transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 18).padding(.bottom, 40)
            }
            .overlay { if confetti { Confetti(count: 70).allowsHitTesting(false) } }
            .navigationTitle(r.title)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if options.isEmpty { options = r.q.options.enumerated().map { Option(text: $0.element, index: $0.offset) }.shuffled() }
            }
        }
    }

    private func tool(_ label: String, icon: String?, on: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon { Image(systemName: icon).font(.system(size: 13)) }
                Text(label).font(.nunitoXB(13.5))
            }
            .foregroundStyle(on ? Color.onAccent : Color.accent)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(on ? Color.accent : Color.accentSoft, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func question(_ r: Reading) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DID YOU FOLLOW IT?").font(.nunito(11, .black)).tracking(0.9).foregroundStyle(Color.muted)
            Text(r.q.text).font(.nunitoXB(16.5)).foregroundStyle(Color.ink)
            ForEach(options, id: \.index) { o in
                let right = solved && o.index == r.q.answer, bad = wrong.contains(o.index)
                Button {
                    guard !solved, !bad else { return }
                    if o.index == r.q.answer {
                        withAnimation { solved = true }
                        Sounds.shared.play("correct")
                    } else {
                        wrong.insert(o.index)
                        Sounds.shared.play("wrong")
                    }
                } label: {
                    Text(o.text).font(.nunito(15.5, .semibold)).foregroundStyle(Color.ink).multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(13)
                        .background(right ? Color.goodSoft : bad ? Color.againSoft : Color.panel, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(right ? Color.good : bad ? Color.again : Color.line, lineWidth: 1.5))
                        .opacity(bad ? 0.6 : 1)
                }
                .buttonStyle(PressDown(depth: 1))
                .sensoryFeedback(.success, trigger: solved) { _, n in n && right }
            }
        }
        .padding(16).panel(radius: 18)
    }

    private func finish(_ r: Reading) {
        if progress.markRead(r.id) {
            progress.earnXP(15)
            Sounds.shared.play("complete")
            confetti = true
            Moments.shared.toast("Story read! +15 XP")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { dismiss() }
        } else {
            dismiss()
        }
    }
}

// MARK: - a chapter's guidebook

struct GuidePage: View {
    let chapter: Int
    @Environment(ProgressStore.self) private var progress
    @Environment(Router.self) private var router
    private let course = Course.shared

    var body: some View {
        let ch = course.chapters[chapter]
        let cards = course.cards.filter { ch.lessons.contains($0.lessonId) }
        let learnt = cards.filter { (progress.srs[$0.id]?.reps ?? 0) >= 1 }.count
        let notes = ch.lessons.flatMap { course.notes(for: $0) }
        let phrases = course.keyPhrases(chapter: chapter)
        let finished = progress.chapterDone(chapter)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(course.chapterLabel(chapter).uppercased()).font(.nunito(11, .black)).tracking(0.9).foregroundStyle(Color.accent)
                Text(ch.title).font(.nunitoXB(26)).foregroundStyle(Color.ink).padding(.top, 2)
                Text("\(ch.lessons.count) lesson\(ch.lessons.count == 1 ? "" : "s") · \(cards.count) words" + (finished ? " · finished" : ""))
                    .font(.nunito(14.5)).foregroundStyle(Color.muted).padding(.top, 2)

                if !notes.isEmpty {
                    heading("Grammar tips")
                    ForEach(Array(notes.enumerated()), id: \.offset) { _, n in
                        VStack(alignment: .leading, spacing: 5) {
                            Label { Text(n.title) } icon: { Image(systemName: "lightbulb") }.font(.nunito(15, .bold)).foregroundStyle(Color.ink)
                            Text(n.body).font(.nunito(14.5)).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.accentSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.bottom, 8)
                    }
                }

                if !phrases.isEmpty {
                    heading("Key phrases")
                    VStack(spacing: 0) {
                        ForEach(Array(phrases.enumerated()), id: \.offset) { i, t in
                            HStack(alignment: .center, spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    phraseLine(t)
                                    PinyinText(pinyin: t.pinyin, size: 13.5, weight: .regular)
                                    Text(t.en).font(.nunito(13.5)).foregroundStyle(Color.muted)
                                }
                                Spacer(minLength: 0)
                                SpeakerButton(text: t.hanzi)
                            }
                            .padding(.vertical, 10)
                            .overlay(alignment: .top) { if i > 0 { Rectangle().fill(Color.line).frame(height: 1) } }
                        }
                    }
                    .padding(.horizontal, 14).panel(radius: 16)
                    Text("Tap a word for its meaning").font(.nunito(12.5)).foregroundStyle(Color.muted).padding(.top, 6)
                }

                heading("Words")
                ForEach(ch.lessons, id: \.self) { id in
                    if let l = course.lessonById[id] {
                        Text(l.name).font(.nunitoXB(14)).foregroundStyle(Color.accent).padding(.top, 10).padding(.bottom, 6)
                        VStack(spacing: 0) {
                            ForEach(Array(cards.filter { $0.lessonId == id }.enumerated()), id: \.element.id) { i, c in
                                let s = progress.srs[c.id]
                                let lv = s == nil ? 0 : (s?.reps ?? 0) >= 2 || (s?.interval ?? 0) >= 7 ? 2 : (s?.reps ?? 0) >= 1 ? 1 : 0
                                HStack(spacing: 10) {
                                    TappableHanzi(text: c.word.hanzi, pinyin: c.word.pinyin, size: 19, weight: .bold)
                                        .frame(minWidth: 52, alignment: .leading)
                                    VStack(alignment: .leading, spacing: 1) {
                                        PinyinText(pinyin: c.word.pinyin, size: 13, weight: .regular)
                                        Text(c.word.en).font(.nunito(13.5)).foregroundStyle(Color.ink).lineLimit(2)
                                    }
                                    Spacer(minLength: 0)
                                    Circle().fill([Color.line, Color.gold, Color.good][lv]).frame(width: 9, height: 9)
                                    SpeakerButton(text: c.word.hanzi, size: 17)
                                }
                                .padding(.vertical, 7)
                                .overlay(alignment: .top) { if i > 0 { Rectangle().fill(Color.line).frame(height: 1) } }
                            }
                        }
                        .padding(.horizontal, 12).panel(radius: 14)
                    }
                }

                if let story = course.storyFor(chapter: chapter) {
                    Button { router.push(.story(story.id)) } label: {
                        Label(finished ? "Read the story: \(story.title)" : "Finish the chapter to unlock its story",
                              systemImage: finished ? "book.fill" : "lock.fill")
                    }
                    .buttonStyle(WideButton(ghost: !finished))
                    .disabled(!finished)
                    .padding(.top, 18)
                }
            }
            .padding(.horizontal, 18).padding(.bottom, 40)
        }
        .navigationTitle("Guidebook")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Text("\(learnt) / \(cards.count) words").font(.nunito(13, .semibold)).foregroundStyle(Color.muted)
            }
        }
    }

    private func heading(_ t: String) -> some View {
        Text(t).font(.nunitoXB(18)).foregroundStyle(Color.ink).padding(.top, 22).padding(.bottom, 10)
    }

    /// The phrase split into its words, each tappable, punctuation in place.
    @ViewBuilder
    private func phraseLine(_ t: Turn) -> some View {
        if let words = Sentence.segment(hanzi: t.hanzi, pinyin: t.pinyin) {
            FlowLayout(spacing: 0, lineSpacing: 4) {
                ForEach(Array(pieces(t.hanzi, words).enumerated()), id: \.offset) { _, p in
                    if let w = p.word { HintWord(hanzi: w.hanzi, pinyin: w.pinyin, size: 19) }
                    else { Text(p.text).font(.hanzi(19)).foregroundStyle(Color.ink) }
                }
            }
        } else {
            ToneText(hanzi: t.hanzi, pinyin: t.pinyin, size: 19, weight: .medium)
        }
    }

    private func pieces(_ hanzi: String, _ words: [SentenceWord]) -> [(text: String, word: SentenceWord?)] {
        var out: [(String, SentenceWord?)] = [], chars = Array(hanzi), pos = 0
        for w in words {
            while pos < chars.count && !Course.isHan(chars[pos]) { out.append((String(chars[pos]), nil)); pos += 1 }
            out.append((w.hanzi, w)); pos += w.hanzi.count
        }
        while pos < chars.count { out.append((String(chars[pos]), nil)); pos += 1 }
        return out
    }
}
