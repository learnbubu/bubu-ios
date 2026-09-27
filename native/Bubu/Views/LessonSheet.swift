import SwiftUI

/// What opens when you tap a stone: the lesson's words and its grammar notes.
struct LessonSheet: View {
    let lesson: Lesson
    @Environment(ProgressStore.self) private var progress
    @Environment(\.dismiss) private var dismiss
    private let course = Course.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let ci = course.chapterOf[lesson.id] {
                    Text(course.chapterLabel(ci).uppercased()).font(.nunitoXB(11)).tracking(1.2).foregroundStyle(Color.accent)
                }
                Text(lesson.name).font(.nunitoXB(26)).foregroundStyle(Color.ink)
                Text("\(course.cards(in: lesson.id).count) new words").font(.nunito(15, .semibold)).foregroundStyle(Color.muted)

                VStack(spacing: 0) {
                    ForEach(Array(lesson.words.enumerated()), id: \.offset) { i, w in
                        HStack(alignment: .firstTextBaseline, spacing: 14) {
                            ToneText(hanzi: w.hanzi, pinyin: w.pinyin, size: 26, weight: .medium)
                                .frame(minWidth: 64, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(w.pinyin).font(.nunito(15, .bold)).foregroundStyle(Color.gold)
                                Text(w.en).font(.nunito(15)).foregroundStyle(Color.ink)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 11)
                        if i < lesson.words.count - 1 { Divider().overlay(Color.line) }
                    }
                }
                .padding(.horizontal, 14)
                .background(Color.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.line))

                ForEach(course.notes(for: lesson.id), id: \.self) { n in
                    VStack(alignment: .leading, spacing: 6) {
                        Label(n.title, systemImage: "lightbulb").font(.nunitoXB(15)).foregroundStyle(Color.accent)
                        Text(n.body).font(.nunito(15)).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accentSoft.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Button(progress.isDone(lesson.id) ? "Practise again" : "Start lesson") {}
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 6)
                Text("Lessons arrive in the next build").font(.nunito(13)).foregroundStyle(Color.muted)
                    .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
        .background(Color.bg.ignoresSafeArea())
    }
}
