import SwiftUI

/// What opens when you tap a stone, as on the web: the lesson's coin and name,
/// how far through it you are, Start studying, its grammar notes, and Bùbù
/// peeking over the top edge.
struct LessonSheet: View {
    let lesson: Lesson
    var close: () -> Void
    @Environment(ProgressStore.self) private var progress
    @Environment(Router.self) private var router
    @State private var shown = false
    @State private var drag: CGFloat = 0
    private let course = Course.shared

    var body: some View {
        let cards = course.cards(in: lesson.id)
        let learned = cards.filter { (progress.srs[$0.id]?.reps ?? 0) >= 1 }.count
        let done = progress.isDone(lesson.id)
        ZStack(alignment: .bottom) {
            Color.black.opacity(shown ? 0.55 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(alignment: .leading, spacing: 0) {
                Capsule().fill(Color.line).frame(width: 38, height: 5)
                    .frame(maxWidth: .infinity).padding(.bottom, 14)

                HStack(spacing: 12) {
                    Text(course.hero[lesson.id] ?? "")
                        .font(.hanzi(22, .semibold)).foregroundStyle(Color.onAccent)
                        .frame(width: 52, height: 44)
                        .background(Ellipse().fill(Color.accentDark).offset(y: 5))
                        .background(Ellipse().fill(Color.accent))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(lesson.code).font(.nunito(11)).tracking(0.5).foregroundStyle(Color.muted)
                        Text(lesson.name).font(.nunito(16, .bold)).foregroundStyle(Color.ink).lineLimit(2)
                        Bar(value: cards.isEmpty ? 0 : Double(learned) / Double(cards.count), height: 7, fill: .good)
                            .padding(.top, 3).padding(.bottom, 4)
                        Text("\(done ? "completed" : learned > 0 ? "in progress" : "new lesson") · \(cards.count) words")
                            .font(.nunito(11)).foregroundStyle(Color.muted)
                    }
                }
                .padding(.bottom, 12)

                // lessons unlock in order: finished ones and the current one can be studied
                let open = done || lesson.id == progress.currentLessonId
                Button {
                    guard open else { return }
                    let s = StudySession(lessonId: lesson.id, progress: progress)
                    router.lesson = nil
                    router.study = s
                } label: {
                    VStack(spacing: 1) {
                        Text(done ? "Study again" : open ? "Start studying" : "Finish the lessons before this one").font(.nunitoXB(16))
                        Text("mixed skills · spaced repetition").font(.nunito(11, .medium)).opacity(0.9)
                    }
                    .foregroundStyle(Color.onAccent)
                    .frame(maxWidth: .infinity).padding(14)
                    .background(Color.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(PressDown())
                .background(Color.accentDark, in: RoundedRectangle(cornerRadius: 14, style: .continuous).offset(y: 5))
                .padding(.top, 6).padding(.bottom, 9)

                ForEach(course.notes(for: lesson.id), id: \.self) { n in
                    VStack(alignment: .leading, spacing: 6) {
                        Label { Text(n.title) } icon: { Image(systemName: "lightbulb") }
                            .font(.nunito(15, .bold)).foregroundStyle(Color.ink)
                        Text(n.body).font(.nunito(15)).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.bottom, 8)
                }

                Label("Finish a Study round to unlock focused practice", systemImage: "lock.fill")
                    .font(.nunito(11)).tracking(0.3).foregroundStyle(Color.muted)
                    .padding(.top, 8).padding(.horizontal, 2)
            }
            .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 20)
            .background(alignment: .top) {
                UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22, style: .continuous)
                    .fill(Color.panel)
                    .shadow(color: .black.opacity(0.2), radius: 12, y: -8)
                    .ignoresSafeArea(edges: .bottom)
            }
            .overlay(alignment: .topTrailing) {
                Image("sheet-waving").resizable().scaledToFit().frame(width: 108)
                    .shadow(color: .black.opacity(0.28), radius: 8, y: 6)
                    .offset(x: -14, y: -84)
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
