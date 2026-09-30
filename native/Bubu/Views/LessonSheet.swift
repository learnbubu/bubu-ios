import SwiftUI

/// What opens when you tap a stone, as the web's lesson sheet: the lesson's coin and
/// name, how much is mastered, Study (or the skip test when it's locked), its grammar
/// notes, the one-skill practice chips once it's been studied, and Bùbù peeking over.
struct LessonSheet: View {
    let lesson: Lesson
    var close: () -> Void
    @Environment(ProgressStore.self) private var progress
    @Environment(Router.self) private var router
    @State private var shown = false
    @State private var drag: CGFloat = 0
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
        // a lesson with many new words comes in steps (its batches)
        let steps = StudySession.lessonSteps(lesson.id, progress)
        let pose = pct >= 1 || (lesson.isPractice && done) ? "done-panda" : studied ? "panda-idle" : "sheet-waving"
        ZStack(alignment: .bottom) {
            Color.black.opacity(shown ? 0.55 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(alignment: .leading, spacing: 0) {
                Capsule().fill(Color.line).frame(width: 38, height: 5)
                    .frame(maxWidth: .infinity).padding(.bottom, 14)
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 12) {
                            Text(course.hero[lesson.id] ?? "")
                                .font(.hanzi(22, .semibold)).foregroundStyle(Color.onAccent)
                                .frame(width: 52, height: 44)
                                .background(Ellipse().fill(Color.accentDark).offset(y: 5))
                                .background(Ellipse().fill(Color.accent))
                            if lesson.isPractice {
                                practiceHead(done: done)
                            } else {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(lesson.code.uppercased()).font(.nunito(11, .semibold)).tracking(1.2).foregroundStyle(Color.muted)
                                Text(lesson.name).font(.nunito(16, .bold)).foregroundStyle(Color.ink).lineLimit(2)
                                Bar(value: pct, height: 7, fill: .good).padding(.top, 3).padding(.bottom, 4)
                                Text(studied ? "\(mastered) / \(cards.count) mastered\(due > 0 ? " · \(due) due" : "")" : "new lesson · \(cards.count) words")
                                    .font(.nunito(11)).foregroundStyle(Color.muted)
                                if !done && !locked && steps.total > 1 {
                                    HStack(spacing: 8) {
                                        Text("STEP \(steps.step) OF \(steps.total)").font(.nunitoXB(11)).tracking(0.6).foregroundStyle(Color.accent)
                                        StepSegments(done: steps.step - 1, total: steps.total, current: true)
                                    }
                                    .padding(.top, 5)
                                }
                            }
                            }
                        }
                        .padding(.bottom, 12)

                        if lesson.isPractice { practiceWords }

                        studyButton(locked: locked, studied: studied)
                            .padding(.top, 6).padding(.bottom, 9)

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

                        // the one-skill chips below appear once any of the lesson's words is studied
                        if !studied && !locked && !lesson.isPractice {
                            HStack(spacing: 6) {
                                Image(systemName: "lock.fill").font(.system(size: 10, weight: .semibold))
                                Text("Start studying to unlock focused practice").font(.nunito(12, .medium))
                            }
                            .foregroundStyle(Color.muted)
                            .padding(.top, 6).padding(.horizontal, 2)
                        }

                        if studied && !lesson.isPractice {
                            Text("OR PRACTISE ONE SKILL").font(.nunito(11)).tracking(0.3).foregroundStyle(Color.muted)
                                .padding(.top, 14).padding(.bottom, 8).padding(.horizontal, 2)
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
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: UIScreen.main.bounds.height * 0.66)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 20)
            .background(alignment: .top) {
                UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22, style: .continuous)
                    .fill(Color.panel)
                    .shadow(color: .black.opacity(0.2), radius: 12, y: -8)
                    .ignoresSafeArea(edges: .bottom)
            }
            .overlay(alignment: .topTrailing) {
                // about 72 pt of panda, its feet ~30 pt over the sheet's top edge (web: .sheet-bubu).
                // The waving and done art carry empty margins; the idle art is cropped tight.
                let padded = pose != "panda-idle"
                Image(pose).resizable().scaledToFit()
                    .frame(width: padded ? 100 : 72, height: padded ? 150 : 110, alignment: .bottom)
                    .shadow(color: .black.opacity(0.28), radius: 8, y: 6)
                    .offset(x: -14, y: padded ? -90 : -80)
                    .scaleEffect(shown ? 1 : 0.9, anchor: .bottom)
                    .allowsHitTesting(false)
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

    /// Study, or for a locked lesson the skip test that unlocks it.
    private func studyButton(locked: Bool, studied: Bool) -> some View {
        Button {
            if locked { router.start(StudySession.placement(progress, to: lesson.id)) }
            else { router.start(StudySession.lesson(lesson.id, progress)) }
        } label: {
            VStack(spacing: 1) {
                if locked {
                    Label("Take the skip test", systemImage: "scope").font(.nunitoXB(16))
                    Text("pass to unlock this — and everything before it").font(.nunito(11, .medium)).opacity(0.9)
                } else if lesson.isPractice {
                    Text(progress.isDone(lesson.id) ? "Practise again" : "Start practice").font(.nunitoXB(16))
                    Text("no new words · no buns needed").font(.nunito(11, .medium)).opacity(0.9)
                } else {
                    Text(stepLabel(studied: studied)).font(.nunitoXB(16))
                    Text("mixed skills · spaced repetition").font(.nunito(11, .medium)).opacity(0.9)
                }
            }
            .foregroundStyle(Color.onAccent)
            .frame(maxWidth: .infinity).padding(14)
            .background(Color.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressDown())
        .background(Color.accentDark, in: RoundedRectangle(cornerRadius: 14, style: .continuous).offset(y: 5))
    }

    /// A practice stone's heading: what it is and what it covers.
    private func practiceHead(done: Bool) -> some View {
        let n = course.practiceCards(lesson.id).count
        let review = lesson.review == true
        let what = review ? "About \(StudySession.practiceLen) exercises on the chapter's \(n) words, weaker ones first"
                          : "About \(StudySession.practiceLen) exercises on the \(n) words so far, weaker ones first"
        return VStack(alignment: .leading, spacing: 2) {
            Text(review ? "CHAPTER REVIEW" : "PRACTICE").font(.nunito(11, .semibold)).tracking(1.2).foregroundStyle(Color.muted)
            Text(lesson.name).font(.nunito(16, .bold)).foregroundStyle(Color.ink).lineLimit(2)
            Text(done ? "Done · practise again any time" : what)
                .font(.nunito(12)).foregroundStyle(Color.muted).fixedSize(horizontal: false, vertical: true)
                .padding(.top, 3)
        }
    }

    /// The words a practice stone covers, as small tiles.
    private var practiceWords: some View {
        FlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(course.practiceCards(lesson.id), id: \.id) { c in
                Text(c.word.hanzi).font(.hanzi(17, .medium)).foregroundStyle(Color.ink)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.bg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.line, lineWidth: 1))
            }
        }
        .padding(.bottom, 10)
    }

    /// "Start studying", or for a lesson in steps "Start step 2 of 2".
    private func stepLabel(studied: Bool) -> String {
        let s = StudySession.lessonSteps(lesson.id, progress)
        if !progress.isDone(lesson.id) && s.total > 1 { return "Start step \(s.step) of \(s.total)" }
        return studied ? "Study" : "Start studying"
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
