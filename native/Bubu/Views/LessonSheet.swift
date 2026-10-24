import SwiftUI

/// What opens when you tap a stone: its name, how it's going, and one button (the owner, 24 Oct
/// 2026: "sooooo much info on them … more simple", mockup A). The rest (its tips, one skill at a time, a practice
/// stone's words) is a tap away, on the sheet's second page.
struct LessonSheet: View {
    let lesson: Lesson
    var close: () -> Void
    @Environment(ProgressStore.self) private var progress
    @Environment(Router.self) private var router
    @State private var shown = false
    @State private var drag: CGFloat = 0
    /// the second page: tips, one skill at a time, the words
    @State private var more = false
    /// the notes opened (they start folded: the tip was shown when the stone began)
    @State private var openNotes: Set<String> = []
    private let course = Course.shared

    var body: some View {
        let cards = course.cards(in: lesson.id)
        let mastered = cards.filter { progress.isMastered($0.id) }.count
        let due = cards.filter { (progress.srs[$0.id]?.due).map { $0 <= progress.now() } ?? false }.count
        let done = progress.isDone(lesson.id)
        let studied = done || cards.contains { progress.srs[$0.id] != nil }
        let pct = cards.isEmpty ? 0 : Double(mastered) / Double(cards.count)
        let locked = !done && lesson.id != progress.currentLessonId
        ZStack(alignment: .bottom) {
            Color.black.opacity(shown ? 0.55 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(alignment: .leading, spacing: 0) {
                Capsule().fill(Color.line).frame(width: 38, height: 5)
                    .frame(maxWidth: .infinity).padding(.bottom, 14)
                ScrollView {
                    Group {
                        if more {
                            morePage(studied: studied, locked: locked)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        } else {
                            front(studied: studied, locked: locked, done: done, pct: pct, mastered: mastered, total: cards.count, due: due)
                                .transition(.move(edge: .leading).combined(with: .opacity))
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: UIScreen.main.bounds.height * 0.66)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 4)
            .background(alignment: .top) {
                UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22, style: .continuous)
                    .fill(Color.panel)
                    .shadow(color: .black.opacity(0.2), radius: 12, y: -8)
                    .ignoresSafeArea(edges: .bottom)
            }
            .offset(y: shown ? max(0, drag) : 700)
            .gesture(DragGesture()
                .onChanged { drag = $0.translation.height }
                .onEnded { v in
                    if v.translation.height > 120 || v.predictedEndTranslation.height > 260 { dismiss() }
                    else { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { drag = 0 } }
                })
        }
        .onAppear { withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { shown = true } }
        .sensoryFeedback(.impact(weight: .light), trigger: shown)
    }

    /// The front, in the pinned chapter bar's style (the owner, 24 Oct 2026: "a little more bold … like the bar we have
    /// at the top with the book"): its place in the course small and spaced, its name big; how it's going on the lessons'
    /// own bar; the button with the lessons' lip and shine; under it, the one way to the rest, as a quieter button.
    private func front(studied: Bool, locked: Bool, done: Bool, pct: Double, mastered: Int, total: Int, due: Int) -> some View {
        let parts = lesson.nameParts
        let steps = StudySession.lessonSteps(lesson.id, progress)
        let notes = course.notes(for: lesson.id)
        let words = Self.uniqueWords(course.practiceCards(lesson.id)).count
        // (its place in the course, a review's too: its name already says what it is)
        let eyebrow = lesson.code.uppercased()
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(eyebrow).font(.nunito(12, .heavy)).tracking(1.4).foregroundStyle(Color.muted)
                Text(parts.hanzi).font(.hanzi(24, .heavy)).foregroundStyle(Color.ink).lineLimit(1).minimumScaleFactor(0.7)
                if !parts.en.isEmpty {
                    // (its step kept with its name: "· 2" wrapped onto a line alone, the Mac, 0.2.26)
                    Text(parts.en.replacingOccurrences(of: " · ", with: "\u{00A0}·\u{00A0}")).font(.nunito(17, .black)).foregroundStyle(Color.ink.opacity(0.78)).lineLimit(2)
                }
            }
            .padding(.bottom, 16)

            // how it's going
            Group {
                if lesson.isPractice {
                    Text(done ? "Done · practise again any time" : "\(words) words, weakest first")
                        .font(.nunito(14, .bold)).foregroundStyle(Color.muted)
                } else if !done && !locked && steps.total > 1 {
                    HStack(spacing: 10) {
                        StepSegments(done: steps.step - 1, total: steps.total, current: true, width: 46, height: 10)
                        Text("Step \(steps.step) of \(steps.total)").font(.nunito(14, .heavy)).foregroundStyle(Color.accent)
                    }
                } else if studied {
                    HStack(spacing: 10) {
                        ProgressBarShine(value: max(pct, 0.04), height: 14)
                        Text("\(mastered)/\(total)").font(.nunito(14, .heavy)).foregroundStyle(Color.ink).fixedSize()
                    }
                    if due > 0 {
                        Text("\(due) due for review").font(.nunito(13, .bold)).foregroundStyle(Color.again).padding(.top, 4)
                    }
                } else {
                    Text("\(total) new words").font(.nunito(14, .bold)).foregroundStyle(Color.muted)
                }
            }
            .padding(.bottom, 18)

            studyButton(locked: locked, studied: studied)

            // the one way to the rest, saying what it opens
            // (quieter than the button over it: its words smaller, no icon; the owner, 24 Oct 2026)
            let second: String? = lesson.isPractice ? "See the \(words) words"
                : studied ? "Practise a skill"
                : notes.isEmpty ? nil : notes.count == 1 ? "Read the tip" : "Read the \(notes.count) tips"
            if let second, !locked {
                Button { withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) { more = true } } label: {
                    Text(second).font(.nunito(15, .heavy)).foregroundStyle(Color.accent)
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                        .background(Color.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.line, lineWidth: 1.5))
                }
                .buttonStyle(PressDown(depth: 3))
                .background(Color.line, in: RoundedRectangle(cornerRadius: 14, style: .continuous).offset(y: 3))
                .padding(.top, 12)
            }
        }
    }

    /// The second page: back, then the stone's tips, a practice stone's words, and one skill at a time.
    private func morePage(studied: Bool, locked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Button { withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) { more = false } } label: {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.ink)
                        .frame(width: 32, height: 32).background(Color.bg, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                Text(lesson.nameParts.hanzi).font(.hanzi(17, .bold)).foregroundStyle(Color.ink).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 14)

            if lesson.isPractice { practiceWords }

            // the stone's notes, folded to their titles: tap one to read it again
            ForEach(course.notes(for: lesson.id), id: \.self) { n in
                let open = openNotes.contains(n.title)
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                        if open { openNotes.remove(n.title) } else { openNotes.insert(n.title) }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label { Text(n.title) } icon: { Image(systemName: "lightbulb") }
                                .font(.nunito(15, .bold)).foregroundStyle(Color.ink)
                            Spacer(minLength: 4)
                            Image(systemName: open ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .bold)).foregroundStyle(Color.muted)
                        }
                        if open {
                            Text(n.body).font(.nunito(15)).foregroundStyle(Color.ink).multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accentSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)
            }

            if studied && !lesson.isPractice && !locked {
                Text("ONE SKILL AT A TIME").font(.nunito(11, .semibold)).tracking(0.6).foregroundStyle(Color.muted)
                    .padding(.top, 8).padding(.bottom, 8).padding(.horizontal, 2)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)], spacing: 9) {
                    chip("pencil", "Write", "write")
                    chip("character.textbox", "Pinyin", "pinyin")
                    chip("headphones", "Listen", "listen")
                    chip("square.stack.3d.up", "Sentences", "sentence")
                    chip("checklist", "Quiz", "quiz")
                    chip("book", "Browse", "browse")
                }
            }
        }
    }

    /// Study, or for a locked lesson the skip test that unlocks it: the lessons' raised button, its lip and its shine.
    @ViewBuilder
    private func studyButton(locked: Bool, studied: Bool) -> some View {
        Button {
            if locked { router.start(StudySession.placement(progress, to: lesson.id)) }
            else { router.start(StudySession.lesson(lesson.id, progress)) }
        } label: {
            if locked { Label("Take the skip test", systemImage: "scope") }
            else if lesson.isPractice { Text(progress.isDone(lesson.id) ? "Practise again" : "Start practice") }
            else { Text(stepLabel(studied: studied)) }
        }
        .buttonStyle(RaisedButton(fill: Color.accent, ink: Color.onAccent))
        if locked {
            Text("Pass it to unlock this and everything before it").font(.nunito(12, .semibold)).foregroundStyle(Color.muted)
                .frame(maxWidth: .infinity).padding(.top, 8)
        }
    }

    /// The words a practice stone covers, as small tiles.
    private var practiceWords: some View {
        FlowLayout(spacing: 6, lineSpacing: 6) {
            // (one tile a word: 零 is in two stones, as "0" and as "zero": the Mac, 0.2.25)
            ForEach(Self.uniqueWords(course.practiceCards(lesson.id)), id: \.id) { c in
                Text(c.word.hanzi).font(.hanzi(17, .medium)).foregroundStyle(Color.ink)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.bg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.line, lineWidth: 1))
            }
        }
        .padding(.bottom, 10)
    }

    /// each word once, by its characters, in the order they come
    static func uniqueWords(_ cards: [Card]) -> [Card] {
        var seen = Set<String>()
        return cards.filter { seen.insert($0.word.hanzi).inserted }
    }

    /// "Start studying", or for a lesson in steps "Start step 2 of 2".
    private func stepLabel(studied: Bool) -> String {
        let s = StudySession.lessonSteps(lesson.id, progress)
        if !progress.isDone(lesson.id) && s.total > 1 { return "Start step \(s.step) of \(s.total)" }
        return studied ? "Study" : "Start"
    }

    /// One skill on its own, for a lesson that's been studied (web: launchLesson with a focus).
    private func chip(_ icon: String, _ label: String, _ focus: String) -> some View {
        Button {
            switch focus {
            case "quiz": router.start(StudySession.quiz(progress, cards: course.cards(in: lesson.id)))
            case "browse": router.lesson = nil; router.push(.browse(lesson.id))
            default: router.start(StudySession.lesson(lesson.id, progress, focuses: [focus]))
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.accent).frame(width: 22)
                Text(label).font(.nunito(14, .semibold)).foregroundStyle(Color.ink)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12).padding(.vertical, 11)
            .background(Color.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.line, lineWidth: 1.5))
        }
        .buttonStyle(PressDown(depth: 1))
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.95)) { shown = false } completion: { close() }
    }
}

/// Sinks by the depth of its 3D base while pressed.
struct PressDown: ButtonStyle {
    var depth: CGFloat = 5
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? depth - 1 : 0)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed)
    }
}


/// A lesson's steps as a row of short bars: the finished ones filled, the one you're
/// on (when `current`) half-filled.
struct StepSegments: View {
    let done: Int
    let total: Int
    var current = false
    var width: CGFloat = 16
    var height: CGFloat = 5
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<max(total, 1), id: \.self) { i in
                Capsule()
                    .fill(i < done ? Color.accent : current && i == done ? Color.accent.opacity(0.4) : Color.line)
                    .frame(width: width, height: height)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(min(done + (current ? 1 : 0), total)) of \(total)")
    }
}
