import SwiftUI
import Observation

/// Which character page is open, and the trail of characters that led to it.
/// One shared trail, so a character tapped anywhere (a lesson, the feedback, the
/// sheet itself) opens the same page.
@Observable
final class CharNav {
    static let shared = CharNav()
    var trail: [String] = []

    func open(_ ch: String) {
        guard CharData.shared.chars[ch] != nil else { return }
        if trail.last != ch { trail.append(ch) }
        if trail.count > 12 { trail.removeFirst() }
    }
    func close() { trail = [] }
}

extension View {
    /// Lets character pages open over this screen.
    func charSheetHost() -> some View { modifier(CharSheetHost()) }
}

private struct CharSheetHost: ViewModifier {
    @State private var nav = CharNav.shared
    func body(content: Content) -> some View {
        content.overlay {
            if let ch = nav.trail.last {
                CharSheet(ch: ch).transition(.opacity).zIndex(2)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: nav.trail.isEmpty)
    }
}

/// Characters you can tap to open their page, underlined with dots.
struct TappableHanzi: View {
    let text: String
    var pinyin: String? = nil
    var size: CGFloat = 20
    var weight: Font.Weight = .medium
    var toneColoured = true
    var color: Color = .ink

    var body: some View {
        let chars = Array(text)
        let syl = pinyin?.split(separator: " ").map(String.init) ?? []
        let hanCount = chars.filter(Course.isHan).count
        var k = 0
        let items: [(String, Color, Bool)] = chars.map { c in
            let s = String(c)
            guard Course.isHan(c) else { return (s, color, false) }
            var col = color
            if toneColoured && syl.count == hanCount { col = Color.tones[toneOf(syl[k]) - 1] }
            k += 1
            return (s, col, CharData.shared.chars[s] != nil)
        }
        return HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, it in
                if it.2 {
                    Button { CharNav.shared.open(it.0) } label: {
                        Text(it.0).font(.hanzi(size, weight)).foregroundStyle(it.1)
                            .overlay(alignment: .bottom) {
                                Line().stroke(it.1.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [1.5, 2.5]))
                                    .frame(height: 1.5).offset(y: 3)
                            }
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(it.0).font(.hanzi(size, weight)).foregroundStyle(it.1)
                }
            }
        }
    }
}

/// The character page, as the web's: the character, its sound and meaning, the
/// parts it's built from, a memory hook, your words that use it, and its relatives.
struct CharSheet: View {
    let ch: String
    @Environment(ProgressStore.self) private var progress
    @State private var nav = CharNav.shared
    @State private var shown = false
    @State private var drag: CGFloat = 0
    @State private var editing = false
    @State private var hookText = ""
    @State private var animating = false
    private let course = Course.shared
    private let cd = CharData.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(shown ? 0.55 : 0).ignoresSafeArea().onTapGesture { dismiss() }
            VStack(spacing: 0) {
                Capsule().fill(Color.line).frame(width: 38, height: 5).padding(.top, 10).padding(.bottom, 10)
                navBar.padding(.horizontal, 18)
                ScrollView {
                    page.padding(.horizontal, 18).padding(.bottom, 24).id(ch)
                }
                .scrollIndicators(.hidden)
            }
            .frame(maxHeight: UIScreen.main.bounds.height * 0.82)
            .background(alignment: .top) {
                UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22, style: .continuous)
                    .fill(Color.panel).shadow(color: .black.opacity(0.2), radius: 12, y: -8)
                    .ignoresSafeArea(edges: .bottom)
            }
            .offset(y: shown ? max(0, drag) : 800)
            .gesture(DragGesture()
                .onChanged { drag = $0.translation.height }
                .onEnded { v in
                    if v.translation.height > 120 || v.predictedEndTranslation.height > 260 { dismiss() }
                    else { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { drag = 0 } }
                })
        }
        .onAppear { withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { shown = true } }
        .onChange(of: ch) { _, _ in editing = false; animating = false }
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.95)) { shown = false } completion: { nav.close() }
    }

    // MARK: the trail

    private var navBar: some View {
        HStack(spacing: 8) {
            if nav.trail.count > 1 {
                Button { withAnimation { _ = nav.trail.popLast() } } label: {
                    Text("‹ Back").font(.nunitoXB(14)).foregroundStyle(Color.accent)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.accentSoft, in: Capsule())
                }
                .buttonStyle(.plain)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(Array(nav.trail.enumerated()), id: \.offset) { i, c in
                            if i > 0 { Text("›").font(.nunito(14, .black)).foregroundStyle(Color.line) }
                            Button { withAnimation { nav.trail = Array(nav.trail.prefix(i + 1)) } } label: {
                                Text(c).font(.hanzi(17.6, .bold))
                                    .foregroundStyle(i == nav.trail.count - 1 ? Color.ink : Color.muted)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(i == nav.trail.count - 1 ? Color.bg : .clear, in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .disabled(i == nav.trail.count - 1)
                        }
                    }
                }
            } else {
                Text("Tap any character to explore it").font(.nunito(12.8, .bold)).foregroundStyle(Color.muted)
                Spacer()
            }
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.muted)
                    .frame(width: 34, height: 34).background(Color.bg, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 8)
    }

    // MARK: the page

    @ViewBuilder
    private var page: some View {
        let d = cd.chars[ch]
        let py = d?.p ?? ""
        let strokes = StrokeData.shared.chars[ch]?.count ?? 0
        let words = course.cards.filter { $0.word.hanzi.contains(ch) }
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                Group {
                    if animating { GlyphAnimation(char: ch, size: 76, loops: 1) { animating = false } }
                    else { Text(ch).font(.hanzi(70.4, .bold)).foregroundStyle(Color.tones[toneOf(py) - 1]) }
                }
                .frame(width: 80, height: 80)
                VStack(alignment: .leading, spacing: 2) {
                    PinyinText(pinyin: py, size: 19.2, weight: .heavy)
                    Text(cd.meaning(ch)).font(.nunito(16, .bold)).foregroundStyle(Color.ink)
                    Text([strokes > 0 ? "\(strokes) strokes" : "",
                          words.isEmpty ? "" : "in \(words.count) of your word\(words.count == 1 ? "" : "s")"]
                            .filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.nunito(12.8)).foregroundStyle(Color.muted)
                }
                Spacer(minLength: 0)
                VStack(spacing: 6) {
                    SpeakerButton(text: ch, size: 22)
                    if strokes > 0 {
                        Button { animating = true } label: {
                            Image(systemName: "pencil.and.scribble").font(.system(size: 19)).foregroundStyle(Color.accent).padding(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let parts = d?.c, parts.count > 1 {
                HStack(alignment: .center, spacing: 8) {
                    ForEach(Array(parts.enumerated()), id: \.offset) { i, part in
                        if i > 0 { Text("+").font(.nunito(16, .black)).foregroundStyle(Color.muted) }
                        partBox(part.first ?? "", role: part.count > 1 ? part[1] : "")
                    }
                }
                .padding(.top, 14)
            } else if d?.t == "g" {
                Text("A picture character: it started as a drawing of the thing itself.")
                    .font(.nunito(14)).foregroundStyle(Color.muted).padding(.top, 12)
            }

            hook(d?.h).padding(.top, 12)

            if !words.isEmpty {
                sub("Words with \(ch)")
                VStack(spacing: 6) {
                    ForEach(words.prefix(12), id: \.id) { c in
                        let known = (progress.srs[c.id]?.reps ?? 0) >= 1
                        HStack(spacing: 10) {
                            TappableHanzi(text: c.word.hanzi, pinyin: c.word.pinyin, size: 20, weight: .bold)
                            VStack(alignment: .leading, spacing: 1) {
                                PinyinText(pinyin: c.word.pinyin, size: 13, weight: .regular)
                                Text(c.word.en).font(.nunito(13)).foregroundStyle(Color.muted).lineLimit(2)
                            }
                            Spacer(minLength: 0)
                            Text(known ? "KNOWN" : "NEW").font(.nunito(10, .black)).tracking(0.8)
                                .foregroundStyle(known ? Color.good : Color.newInk)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(known ? Color.goodSoft : Color.newBg, in: Capsule())
                        }
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(Color.bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }

            relatives(d)
        }
    }

    private func sub(_ t: String) -> some View {
        Text(t.uppercased()).font(.nunito(11.5, .black)).tracking(0.9).foregroundStyle(Color.muted)
            .padding(.top, 16).padding(.bottom, 8)
    }

    private func partBox(_ comp: String, role: String) -> some View {
        let names = cd.partNames[comp] ?? cd.chars[comp].map { [$0.d ?? "", $0.p ?? ""] } ?? []
        let label = names.isEmpty ? "" : role == "s" && names.count > 1 ? "\(names[1]) · \(names[0])" : names[0]
        let tappable = cd.chars[comp] != nil
        return Button { if tappable { withAnimation { nav.open(comp) } } } label: {
            VStack(spacing: 2) {
                Text(comp).font(.hanzi(27, .bold)).foregroundStyle(Color.ink)
                if !label.isEmpty {
                    Text(label).font(.nunito(11.8, .heavy)).foregroundStyle(Color.muted)
                        .multilineTextAlignment(.center).lineLimit(2)
                }
                if !role.isEmpty {
                    Text(role == "s" ? "SOUND" : "MEANING").font(.nunito(9.9, .black)).tracking(0.6)
                        .foregroundStyle(role == "s" ? Color.gold : Color.accent)
                        .padding(.horizontal, 7).padding(.vertical, 1)
                        .background((role == "s" ? Color.gold.opacity(0.22) : Color.accentSoft), in: Capsule())
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 8).padding(.horizontal, 4)
            .background(Color.bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!tappable)
    }

    /// The memory hook: the suggested one, or your own.
    private func hook(_ suggested: String?) -> some View {
        let mine = progress.hooks[ch]
        return HStack(alignment: .top, spacing: 9) {
            Image(systemName: "lightbulb").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.accent).padding(.top, 2)
            VStack(alignment: .leading, spacing: 6) {
                if editing {
                    TextField("Your story for \(ch)", text: $hookText, axis: .vertical)
                        .font(.nunito(14.4)).lineLimit(3...6)
                        .padding(8).background(Color.panel, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.line))
                    HStack {
                        Spacer()
                        Button(mine != nil ? "Use the suggested one" : "Cancel") {
                            if mine != nil { progress.setHook(ch, nil) }
                            editing = false
                        }
                        .font(.nunito(14, .bold)).foregroundStyle(Color.muted)
                        Button("Save hook") {
                            let v = hookText.trimmingCharacters(in: .whitespacesAndNewlines)
                            progress.setHook(ch, v.isEmpty || v == suggested ? nil : v)
                            editing = false
                        }
                        .font(.nunitoXB(14)).foregroundStyle(Color.onAccent)
                        .padding(.horizontal, 14).padding(.vertical, 7).background(Color.accent, in: Capsule())
                    }
                } else {
                    Text(mine ?? suggested ?? "Write a story to remember this one.")
                        .font(.nunito(14.4)).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
                    Button(mine != nil ? "Edit your hook" : "Write your own") { hookText = mine ?? suggested ?? ""; editing = true }
                        .font(.nunitoXB(12.5)).foregroundStyle(Color.accent)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color.accentSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// Characters from your lessons sharing a meaning part or a sound part.
    @ViewBuilder
    private func relatives(_ d: CharInfo?) -> some View {
        let mine = Course.lessonChars
        ForEach(Array((d?.c ?? []).enumerated()), id: \.offset) { _, part in
            if part.count > 1, !part[1].isEmpty, let comp = part.first {
                let sound = part[1] == "s"
                let rel = mine.filter { o in
                    o != ch && (cd.chars[o]?.c ?? []).contains { $0.first == comp && (!sound || ($0.count > 1 && $0[1] == "s")) }
                }
                if !rel.isEmpty {
                    sub(sound ? "Same sound part \(comp)" : "Also has \(comp)")
                    FlowLayout(spacing: 6, lineSpacing: 6) {
                        ForEach(rel.prefix(8), id: \.self) { o in
                            Button { withAnimation { nav.open(o) } } label: {
                                VStack(spacing: 0) {
                                    Text(o).font(.hanzi(20, .bold)).foregroundStyle(Color.tones[toneOf(cd.chars[o]?.p ?? "") - 1])
                                    Text(sound ? (cd.chars[o]?.p ?? "") : cd.meaning(o)).font(.nunito(10.5, .bold))
                                        .foregroundStyle(Color.muted).lineLimit(1)
                                }
                                .frame(minWidth: 52).padding(.horizontal, 6).padding(.vertical, 6)
                                .background(Color.bg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

extension Course {
    /// Every character in the course's words, in course order.
    static let lessonChars: [String] = {
        var seen = Set<String>(), out: [String] = []
        for c in Course.shared.cards {
            for ch in c.word.hanzi.filter(Course.isHan).map(String.init) where seen.insert(ch).inserted { out.append(ch) }
        }
        return out
    }()
}
