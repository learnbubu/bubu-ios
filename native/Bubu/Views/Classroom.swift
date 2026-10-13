import SwiftUI

/// The Classroom, behind the board's "Let's practise" (the studio's Classroom tab, 13 Oct 2026): Bùbù peeking
/// over the title, the catch-up row (mistakes, review, weak words), What to study, and the eight practice
/// tiles with their pictures. Light only for now.
struct ClassroomPage: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    // the studio's save (tuning/classroom): Bùbù leaning over the catch-up row (his left edge along it, how far
    // his bottom comes down onto it, his width; pt), the tiles' pictures (%) and height (pt)
    private let peekX: CGFloat = 243, peekY: CGFloat = 5, peekW: CGFloat = 109, pic: CGFloat = 0.64, tileH: CGFloat = 106

    private struct Tile { let id: String; let title: String; let bg: UInt32 }
    private let tiles = [
        Tile(id: "listen", title: "Listening", bg: 0xFBD9D2), Tile(id: "vocab", title: "Vocabulary", bg: 0xD6E9FB),
        Tile(id: "speak", title: "Speaking", bg: 0xD3EEDB), Tile(id: "write", title: "Writing", bg: 0xFCEBB8),
        Tile(id: "quiz", title: "Quiz", bg: 0xE5DCFA), Tile(id: "chars", title: "Characters", bg: 0xCDEDE8),
        Tile(id: "read", title: "Reading", bg: 0xFFDDC8), Tile(id: "tones", title: "Tones", bg: 0xFADBE8),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                header
                catchUp
                whatToStudy
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 11), GridItem(.flexible(), spacing: 11)], spacing: 11) {
                    ForEach(tiles, id: \.id) { t in
                        Button { router.practice(t.id == "vocab" ? "pick" : t.id, progress) } label: { tile(t) }
                            .buttonStyle(PressDown(depth: 2))
                    }
                }
            }
            .padding(.horizontal, 18).padding(.top, 4).padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .background(Home.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .environment(\.colorScheme, .light)
    }

    private var header: some View {
        ZStack(alignment: .topLeading) {
            Button { dismiss() } label: {
                Text("‹ Home").font(.nunito(14, .black)).foregroundStyle(Home.teal).padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            Text("Classroom").font(.nunito(34, .black)).tracking(-0.5).foregroundStyle(Home.ink)
                .frame(maxHeight: .infinity, alignment: .bottom).padding(.leading, 2).padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 92)
    }

    private var catchUp: some View {
        let mistakes = progress.mistakeCount, due = progress.dueCount, weak = progress.weakCount
        return HStack(spacing: 8) {
            cell("\(mistakes)", "Fix your mistakes", ink: 0xE0574A, hot: mistakes > 0) { router.start(StudySession.mistakes(progress)) }
            cell("\(due)", "Words to review", ink: 0x1F7A6C) { router.start(StudySession.review(progress)) }
            cell("\(weak)", "Weak words", ink: 0xB7822E) { router.start(StudySession.trouble(progress)) }
        }
        // Bùbù leans on the row, his paws over its top edge
        .overlay(alignment: .topLeading) {
            // his full size given outright: the row (shorter than he is) offered its own height, which shrank him
            Image("class-peek").resizable().scaledToFit().frame(width: peekW, height: peekW * 320 / 420)
                .fixedSize()
                .offset(x: peekX, y: peekY - peekW * 320 / 420)
                .allowsHitTesting(false)
        }
        .zIndex(1)
    }

    private func cell(_ n: String, _ label: String, ink: UInt32, hot: Bool = false, go: @escaping () -> Void) -> some View {
        Button(action: go) {
            VStack(spacing: 0) {
                Text(n).font(.nunito(21, .black)).monospacedDigit().foregroundStyle(Color(UIColor(hex: ink)))
                Text(label).font(.nunito(11, .heavy)).foregroundStyle(Home.muted).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 8).padding(.horizontal, 6)
            .background(Color(UIColor(hex: 0xFFFDF8)), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(hot ? Color(UIColor(hex: 0xE0574A)) : Home.line, lineWidth: 1.5))
        }
        .buttonStyle(PressDown(depth: 2))
    }

    private var whatToStudy: some View {
        let nL = progress.selectedLessons.count
        return Button { router.push(.studyChoice) } label: {
            HStack {
                Text("What to study").font(.nunito(15, .heavy)).foregroundStyle(Home.ink)
                Spacer()
                Text(nL == Course.shared.lessons.count ? "All lessons" : "\(nL) lesson\(nL == 1 ? "" : "s")").font(.nunito(13, .bold)).foregroundStyle(Home.muted)
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold)).foregroundStyle(Home.muted)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color(UIColor(hex: 0xFFFDF8)), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Home.line, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    /// A tile: its picture above, its name on a pale band along the bottom (the owner's pick, 14 Oct 2026).
    private func tile(_ t: Tile) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return VStack(spacing: 0) {
            Image("class-\(t.id)").resizable().scaledToFit()
                .frame(height: tileH * pic * 0.86)
                .padding(.top, tileH * 0.07).padding(.horizontal, 10)
            Spacer(minLength: 0)
            Text(t.title).font(.nunito(14.5, .black)).foregroundStyle(Home.ink).lineLimit(1)
                .frame(maxWidth: .infinity).padding(.top, 6).padding(.bottom, 7)
                .background(Color(UIColor(hex: 0xFFFDF8)).opacity(0.62))
        }
        .frame(maxWidth: .infinity).frame(height: tileH)
        .background(Color(UIColor(hex: t.bg)))
        .clipShape(shape)
        .background(shape.fill(.black.opacity(0.08)).offset(y: 4))
        .contentShape(shape)
    }
}
