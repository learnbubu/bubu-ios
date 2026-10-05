import SwiftUI

/// Tap the pairs (Duolingo's match): 4–5 words already met, Chinese on the left (with its
/// pinyin while the word is still new) and short meanings on the right; or, once the words
/// are past their first rung, sounds on the left and characters on the right. Tap one on each
/// side: a right pair turns green and fades, a wrong one shakes and flashes red and costs
/// nothing. The whole match is one step of the progress bar (see StudySession.matchPair).
struct MatchView: View {
    let session: StudySession
    @Environment(ProgressStore.self) private var progress
    let cards: [Card]
    let audio: Bool
    var done: () -> Void

    private enum Side { case left, right }

    @State private var left: [Card] = []
    @State private var right: [Card] = []
    @State private var pickedLeft: String?
    @State private var pickedRight: String?
    /// tiles flashing red after a wrong pair ("L" or "R" + the card id)
    @State private var wrong: Set<String> = []
    /// each tile's shakes so far, animated one more on a wrong pair
    @State private var shakes: [String: Int] = [:]
    /// matched words whose tiles have faded
    @State private var faded: Set<String> = []
    @State private var misses = 0

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 10) {
                    ForEach(left, id: \.id) { c in tile(.left, c) }
                }
                VStack(spacing: 10) {
                    ForEach(right, id: \.id) { c in tile(.right, c) }
                }
            }
            Text(audio ? "Tap a sound to hear it, then its characters." : "Tap a word, then its meaning.")
                .font(.nunito(12.5)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
                .padding(.top, 2)
            Spacer(minLength: 6)
            Button(action: done) {
                Text("Continue").font(.nunitoXB(16.8))
                    .foregroundStyle(session.matchFinished ? Color.onAccent : Color.onAccent.opacity(0.7))
                    .frame(maxWidth: .infinity).padding(15)
                    .background(session.matchFinished ? Color.accent : Color.accent.opacity(0.38), in: Capsule())
            }
            .buttonStyle(PressDown(depth: 1))
            .disabled(!session.matchFinished)
            .padding(.bottom, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard left.isEmpty else { return }
            let l = cards.shuffled()
            var r = cards.shuffled()
            // no more than one pair straight across from its partner
            var tries = 0
            while tries < 20, r.count > 1, zip(l, r).filter({ pair in pair.0.id == pair.1.id }).count > 1 { r.shuffle(); tries += 1 }
            left = l
            right = r
        }
        .sensoryFeedback(.success, trigger: session.matched.count)
        .sensoryFeedback(.error, trigger: misses)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: session.matchFinished)
    }

    private func key(_ side: Side, _ id: String) -> String { (side == .left ? "L" : "R") + id }

    private func tile(_ side: Side, _ c: Card) -> some View {
        let k = key(side, c.id)
        let isDone = session.matched.contains(c.id)
        let isPicked = (side == .left ? pickedLeft : pickedRight) == c.id
        let isWrong = wrong.contains(k)
        let edge: Color = isWrong ? .again : isDone ? .good : isPicked ? .accent : .line
        let fill: Color = isWrong ? .againSoft : isDone ? .goodSoft : isPicked ? .accentSoft : .panel
        return Button { tap(side, c) } label: {
            face(side, c)
                .frame(maxWidth: .infinity, minHeight: 60)
                .padding(.horizontal, 8).padding(.vertical, 6)
        }
        .buttonStyle(Tile3D(fill: fill, edge: edge))
        .disabled(isDone)
        .opacity(faded.contains(c.id) ? 0.35 : 1)
        .modifier(MatchShake(shakes: CGFloat(shakes[k] ?? 0)))
        .animation(.easeOut(duration: 0.15), value: isPicked)
        .animation(.easeOut(duration: 0.15), value: isWrong)
        .accessibilityLabel(accessibility(side, c))
    }

    @ViewBuilder
    private func face(_ side: Side, _ c: Card) -> some View {
        let w = c.word
        if side == .left && audio {
            Image(systemName: "speaker.wave.2.fill").font(.system(size: 24)).foregroundStyle(Color.accent)
        } else if side == .left || audio {
            VStack(spacing: 2) {
                Text(w.hanzi).font(.hanzi(w.hanzi.count > 3 ? 19 : 24, .medium)).foregroundStyle(Color.ink)
                    .lineLimit(1).minimumScaleFactor(0.6)
                // the pinyin while the word is new, and over every word through the first
                // books (never under the answer to a sound)
                if !audio && (session.isStillNew(c.id) || Wheels.now(progress).shows(card: c)) {
                    PinyinText(pinyin: w.pinyin, size: 12.5).lineLimit(1).minimumScaleFactor(0.7)
                }
            }
        } else {
            if let pic = Pictures.asset(w.hanzi) {
                Image(pic).resizable().scaledToFit().frame(height: 46)
            } else {
                Text(w.gloss).font(.nunito(15.5, .bold)).foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.75)
            }
        }
    }

    private func accessibility(_ side: Side, _ c: Card) -> String {
        if side == .left && audio { return "Sound" }
        if side == .left || audio { return c.word.hanzi }
        return c.word.gloss
    }

    private func tap(_ side: Side, _ c: Card) {
        guard !session.matched.contains(c.id) else { return }
        // the left side speaks: the Chinese, or the sound to match
        if side == .left { Speech.shared.speak(c.word.hanzi) }
        switch side {
        case .left: pickedLeft = pickedLeft == c.id ? nil : c.id
        case .right: pickedRight = pickedRight == c.id ? nil : c.id
        }
        guard let l = pickedLeft, let r = pickedRight else { return }
        pickedLeft = nil
        pickedRight = nil
        if session.matchPair(l, r) {
            Sounds.shared.play("correct")
            withAnimation(.easeOut(duration: 0.4).delay(0.35)) { _ = faded.insert(l) }
        } else {
            Sounds.shared.play("wrong")
            misses += 1
            let keys: Set<String> = [key(.left, l), key(.right, r)]
            wrong.formUnion(keys)
            withAnimation(.linear(duration: 0.4)) {
                for k in keys { shakes[k, default: 0] += 1 }
            }
            let n = misses
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                // a newer wrong pair keeps its own flash
                if misses == n { wrong.removeAll() } else { wrong.subtract(keys) }
            }
        }
    }
}

/// A side-to-side shake: two quick wobbles for each step up in `shakes`.
private struct MatchShake: GeometryEffect {
    var shakes: CGFloat
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 7 * sin(shakes * .pi * 4), y: 0))
    }
}
