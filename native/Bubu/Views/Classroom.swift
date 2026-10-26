import SwiftUI

/// The Classroom, behind the board's "Let's practise" (the studio's Classroom tab, 13 Oct 2026): Bùbù peeking
/// over the title, the catch-up row (mistakes, review, weak words), and the eight practice
/// tiles with their pictures. Light only for now.
struct ClassroomPage: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    // the studio's save (tuning/classroom): Bùbù leaning over the catch-up row (his left edge along it, how far
    // his bottom comes down onto it, his width; pt), the tiles' pictures (%) and height (pt)
    /// the tiles' room with the tab bar up: kept, so coming back from a page that hid the bar (Tones), the tiles
    /// don't come in tall and then shrink as the bar returns (the owner's video, 0.2.43)
    @State private var room: CGFloat = 0

    private let peekX: CGFloat = 243, peekY: CGFloat = 5, peekW: CGFloat = 109, pic: CGFloat = 0.64, tileH: CGFloat = 106

    private struct Tile { let id: String; let title: String; let bg: UInt32 }
    private let tiles = [
        Tile(id: "listen", title: "Listening", bg: 0xFBD9D2), Tile(id: "vocab", title: "Vocabulary", bg: 0xD6E9FB),
        Tile(id: "speak", title: "Speaking", bg: 0xD3EEDB), Tile(id: "write", title: "Writing", bg: 0xFCEBB8),
        Tile(id: "quiz", title: "Quiz", bg: 0xE5DCFA), Tile(id: "chars", title: "Characters", bg: 0xCDEDE8),
        Tile(id: "read", title: "Reading", bg: 0xFFDDC8), Tile(id: "tones", title: "Tones", bg: 0xFADBE8),
    ]

    // (one screen, no scrolling, the tiles tall enough to fill it: the owner, 25 Oct 2026, "make each of the types
    // bigger now since there's a gap at the bottom, elongate them … make this page non scrollable")
    var body: some View {
        VStack(spacing: 12) {
            header
            catchUp
            GeometryReader { g in
                // four rows of two, sharing the room left: taller on a tall phone, shorter on a small one (on the SE, held
                // at the studio's 106, the last row ran under the tab bar: the Mac)
                let fit = room > 0 ? min(room, g.size.height) : g.size.height
                let h = max(72, (fit - 3 * 11 - 4) / 4)
                VStack(spacing: 11) {
                    ForEach(0..<4, id: \.self) { r in
                        HStack(spacing: 11) {
                            ForEach(tiles[(r * 2)..<(r * 2 + 2)], id: \.id) { t in
                                Button { router.practice(t.id, progress) } label: { tile(t, height: h) }
                                    .buttonStyle(PressDown(depth: 2))
                            }
                        }
                    }
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { if room == 0 || $0 < room { room = $0 } }
        }
        .padding(.horizontal, 18).padding(.top, 4).padding(.bottom, 14)
        .background(Home.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .environment(\.colorScheme, .light)
    }

    private var header: some View {
        ZStack(alignment: .topLeading) {
            BackPill(label: "Home") { dismiss() }
            Text("Classroom").font(.nunito(34, .black)).tracking(-0.5).foregroundStyle(Home.ink)
                .frame(maxHeight: .infinity, alignment: .bottom).padding(.leading, 2).padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 100)
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


    /// A tile: its picture above, its name on a pale band along the bottom (the owner's pick, 14 Oct 2026).
    private func tile(_ t: Tile, height: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        // (the picture grows with the tile, a little less than in proportion, so the name keeps its room)
        let picH = max(30, min(height - 34, tileH * pic * 0.86 + (height - tileH) * 0.7))
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            Image("class-\(t.id)").resizable().scaledToFit()
                .frame(height: picH)
                .padding(.horizontal, 10)
            Spacer(minLength: 0)
            Text(t.title).font(.nunito(14.5, .black)).foregroundStyle(Home.ink).lineLimit(1)
                .frame(maxWidth: .infinity).padding(.top, 6).padding(.bottom, 7)
                .background(Color(UIColor(hex: 0xFFFDF8)).opacity(0.62))
        }
        .frame(maxWidth: .infinity).frame(height: height)
        .background(Color(UIColor(hex: t.bg)))
        .clipShape(shape)
        .background(shape.fill(.black.opacity(0.08)).offset(y: 4))
        .contentShape(shape)
    }
}
