import SwiftUI

struct HomeView: View {
    @Environment(ProgressStore.self) private var progress
    var openLearn: () -> Void
    private let course = Course.shared

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        let part = h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
        return progress.name.isEmpty ? part : "\(part), \(progress.name)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Text("步步").font(.hanzi(24, .heavy)).foregroundStyle(Color.ink)
                    Text("Bùbù").font(.nunitoXB(20)).foregroundStyle(Color.accent)
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting).font(.nunitoXB(30)).foregroundStyle(Color.ink)
                    Text("A little progress goes a long way").font(.nunito(16)).foregroundStyle(Color.muted)
                }

                Card3D {
                    HStack(alignment: .center, spacing: 16) {
                        Image(systemName: "flame.fill").font(.system(size: 40)).foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(progress.streak)").font(.nunito(40, .black)).foregroundStyle(Color.ink)
                            Text("day streak").font(.nunito(15, .semibold)).foregroundStyle(Color.muted)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(progress.wordsLearned)").font(.nunitoXB(24)).foregroundStyle(Color.accent)
                            Text("words learned").font(.nunito(13, .semibold)).foregroundStyle(Color.muted)
                        }
                    }
                }

                if let id = progress.currentLessonId, let lesson = course.lessonById[id], let ci = course.chapterOf[id] {
                    Text("Continue learning").font(.nunitoXB(19)).foregroundStyle(Color.ink).padding(.top, 4)
                    Card3D {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(course.chapterLabel(ci).uppercased()).font(.nunitoXB(11)).tracking(1.2).foregroundStyle(Color.accent)
                            Text(lesson.name).font(.nunitoXB(20)).foregroundStyle(Color.ink)
                            HStack(spacing: 8) {
                                ForEach(lesson.words.prefix(5), id: \.self) { w in
                                    Text(w.hanzi).font(.hanzi(17, .medium)).foregroundStyle(Color.ink)
                                        .padding(.horizontal, 9).padding(.vertical, 5)
                                        .background(Color.accentSoft, in: Capsule())
                                }
                            }
                            let (d, t) = progress.chapterProgress(ci)
                            ProgressView(value: Double(d), total: Double(max(t, 1))).tint(.accent)
                            Button("Continue", action: openLearn).buttonStyle(PrimaryButtonStyle()).padding(.top, 4)
                        }
                    }
                }

                Text("The course").font(.nunitoXB(19)).foregroundStyle(Color.ink).padding(.top, 4)
                Card3D {
                    VStack(alignment: .leading, spacing: 8) {
                        stat("Chapters", "\(course.chapters.count)")
                        stat("Lessons", "\(course.lessons.count)")
                        stat("Words", "\(course.cards.count)")
                        stat("Stories", "\(course.data.readings.count)")
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background(Color.bg.ignoresSafeArea())
    }

    private func stat(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(.nunito(16, .semibold)).foregroundStyle(Color.muted)
            Spacer()
            Text(v).font(.nunitoXB(16)).foregroundStyle(Color.ink)
        }
    }
}
