import SwiftUI

// The done screen's later screens, one thing each, as the after-lesson prototype (12 Oct 2026):
// the words met, the streak's lantern lighting, the quests moving on. (The first screen, how it
// went, and the buttons are DoneView's.)

/// "You learned": the session's new words (or a practice stone's words), one to a row, rising in turn.
struct LearnedStage: View {
    let title: String
    let cards: [Card]
    @State private var shown = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.nunitoXB(11.5)).tracking(1.2).foregroundStyle(Color.muted)
            Text(cards.count == 1 ? "1 new word" : "\(cards.count) new words")
                .font(.nunito(26, .black)).foregroundStyle(Color.ink).padding(.top, 2)
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { i, c in
                        row(c)
                            .opacity(i < shown ? 1 : 0)
                            .offset(y: i < shown ? 0 : 18)
                    }
                }
                .padding(.vertical, 14)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            if reduceMotion { shown = cards.count; return }
            try? await Task.sleep(for: .milliseconds(260))
            for i in 1...max(1, cards.count) {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) { shown = i }
                try? await Task.sleep(for: .milliseconds(110))
            }
        }
    }

    private func row(_ c: Card) -> some View {
        let w = c.word
        return HStack(spacing: 14) {
            Text(w.hanzi).font(.hanzi(w.hanzi.count > 2 ? 24 : 30, .semibold)).foregroundStyle(Color.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
                .frame(minWidth: 54, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                PinyinText(pinyin: w.pinyin, size: 14).lineLimit(1).minimumScaleFactor(0.7)
                Text(w.gloss).font(.nunito(14, .semibold)).foregroundStyle(Color.muted).lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
            if let pic = Pictures.asset(w.hanzi) {
                Image(pic).resizable().scaledToFit().frame(width: 34, height: 34)
            }
            SpeakerButton(text: w.hanzi, size: 16).accessibilityLabel("Hear \(w.hanzi)")
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.line, lineWidth: 1.5))
    }
}

/// The streak, when this session lit today's lantern: it hangs unlit, catches and flares, the
/// number rolls on, it lifts, the week comes in and a spark flies down to today and ticks it.
/// `finished` is called when it's all played (the button shows then).
struct StreakStage: View {
    let streak: Int
    var finished: () -> Void
    @Environment(ProgressStore.self) private var progress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lit = false
    @State private var flare = false
    @State private var shown: Int
    @State private var lifted = false
    @State private var weekIn = false
    @State private var spark: CGFloat = -1
    @State private var todayTicked = false
    @State private var lineIn = false

    static let red = Color(UIColor(hex: 0xD9392F))

    init(streak: Int, finished: @escaping () -> Void) {
        self.streak = streak
        self.finished = finished
        _shown = State(initialValue: max(0, streak - 1))
    }

    var body: some View {
        let week = progress.thisWeek, today = progress.today
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            lantern
                .anchorPreference(key: SparkEnds.self, value: .center) { SparkEnds(from: $0) }
            Text("\(shown)").font(.nunito(84, .black)).tracking(-2).foregroundStyle(Self.red)
                .monospacedDigit().contentTransition(.numericText(value: Double(shown)))
                .padding(.top, 8)
            Text("day streak").font(.nunito(20, .black)).foregroundStyle(Self.red).padding(.top, -6)
            weekRow(week, today: today)
                .padding(.top, 26)
                .opacity(weekIn ? 1 : 0).offset(y: weekIn ? 0 : 14)
            message(week, today: today)
                .padding(.top, 18).padding(.horizontal, 10)
                .opacity(lineIn ? 1 : 0)
            Spacer(minLength: 0)
        }
        .offset(y: lifted ? 0 : 60)
        .frame(maxWidth: .infinity)
        .overlayPreferenceValue(SparkEnds.self) { ends in
            GeometryReader { g in
                if spark >= 0, let from = ends.from, let to = ends.to {
                    let a = g[from], b = g[to]
                    Circle()
                        .fill(RadialGradient(colors: [.white, Color(UIColor(hex: 0xFFE08A)), Color(UIColor(hex: 0xFFB347)).opacity(0)], center: .center, startRadius: 0, endRadius: 14))
                        .frame(width: 28, height: 28)
                        .position(x: a.x + (b.x - a.x) * spark, y: a.y + (b.y - a.y) * spark)
                        .allowsHitTesting(false)
                }
            }
        }
        .task { await play() }
    }

    private var lantern: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(UIColor(hex: 0xFFB347)).opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: 130))
                .frame(width: 260, height: 260)
                .opacity(lit ? (flare ? 1 : 0.7) : 0)
                .scaleEffect(flare ? 1.15 : 1)
            Image("lantern-unlit").resizable().scaledToFit().frame(height: 170)
                .opacity(lit ? 0 : 1)
            Image("lantern-lit").resizable().scaledToFit().frame(height: 170)
                .opacity(lit ? 1 : 0)
        }
        .scaleEffect(flare ? 1.08 : 1)
        // the cord it hangs from, fading out above
        .overlay(alignment: .top) {
            Rectangle().fill(LinearGradient(colors: [Color(UIColor(hex: 0xC9A05A)).opacity(0), Color(UIColor(hex: 0xC9A05A))], startPoint: .top, endPoint: .bottom))
                .frame(width: 2.5, height: 120).offset(y: -120 + 8)
        }
        .frame(height: 200)
    }

    private func weekRow(_ week: [String], today: String) -> some View {
        let names = ["M", "T", "W", "T", "F", "S", "S"]
        return HStack(spacing: 10) {
            ForEach(0..<7, id: \.self) { i in
                let d = week[i], isToday = d == today, future = d > today
                let on = isToday ? todayTicked : progress.litOn(d)
                VStack(spacing: 8) {
                    Text(names[i]).font(.nunitoXB(12)).foregroundStyle(isToday ? Self.red : Color.muted)
                    ZStack {
                        Circle().fill(on ? Self.red : future ? Color.line.opacity(0.6) : Color.line.opacity(0.35))
                        if isToday && !on { Circle().strokeBorder(Self.red, style: StrokeStyle(lineWidth: 2, dash: [4, 3])) }
                        if on { Image(systemName: "checkmark").font(.system(size: 13, weight: .heavy)).foregroundStyle(.white) }
                    }
                    .frame(width: 32, height: 32)
                    .scaleEffect(isToday && todayTicked ? 1 : isToday ? 0.92 : 1)
                    .anchorPreference(key: SparkEnds.self, value: .center) { isToday ? SparkEnds(to: $0) : SparkEnds() }
                }
            }
        }
    }

    @ViewBuilder
    private func message(_ week: [String], today: String) -> some View {
        let ti = week.firstIndex(of: today) ?? 0
        let allSoFar = (0..<ti).allSatisfy { progress.litOn(week[$0]) }
        let left = 6 - ti
        if allSoFar && left == 0 {
            Text("A perfect week!").font(.nunito(16, .bold)).foregroundStyle(Color.muted)
        } else if allSoFar {
            (Text("Practise ") + Text("\(left) more day\(left == 1 ? "" : "s")").foregroundColor(Self.red) + Text(" for a perfect week!"))
                .font(.nunito(16, .bold)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
        } else {
            Text(DoneView.milestoneWords[streak] ?? (streak == 1 ? "Lantern lit. Come back tomorrow to make it two." : "Lantern lit. Keep it going tomorrow."))
                .font(.nunito(16, .bold)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
        }
    }

    private func play() async {
        if reduceMotion {
            lit = true; shown = streak; lifted = true; weekIn = true; todayTicked = true; lineIn = true
            finished(); return
        }
        try? await Task.sleep(for: .milliseconds(650))
        withAnimation(.easeOut(duration: 0.38)) { lit = true }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { flare = true }
        Sounds.shared.play("goal")
        try? await Task.sleep(for: .milliseconds(380))
        withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) { shown = streak }
        try? await Task.sleep(for: .milliseconds(520))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { flare = false }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) { lifted = true }
        try? await Task.sleep(for: .milliseconds(420))
        withAnimation(.easeOut(duration: 0.3)) { weekIn = true }
        try? await Task.sleep(for: .milliseconds(300))
        spark = 0
        withAnimation(.easeInOut(duration: 0.52)) { spark = 1 }
        try? await Task.sleep(for: .milliseconds(520))
        spark = -1
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { todayTicked = true }
        try? await Task.sleep(for: .milliseconds(260))
        withAnimation(.easeOut(duration: 0.3)) { lineIn = true }
        try? await Task.sleep(for: .milliseconds(350))
        finished()
    }
}

/// The spark's ends: the lantern, and today's circle in the week row.
private struct SparkEnds: PreferenceKey {
    var from: Anchor<CGPoint>? = nil
    var to: Anchor<CGPoint>? = nil
    static var defaultValue = SparkEnds()
    static func reduce(value: inout SparkEnds, nextValue: () -> SparkEnds) {
        let n = nextValue(); value.from = value.from ?? n.from; value.to = value.to ?? n.to
    }
}

/// "Quest progress!": today's quests, each bar filling from where it was when the session began.
struct QuestStage: View {
    let before: [String: Int]
    @Environment(ProgressStore.self) private var progress
    @State private var filled = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let quests = progress.todayQuests
        VStack(spacing: 14) {
            Text("Quest progress!").font(.nunito(26, .black)).foregroundStyle(Color(UIColor(hex: 0xB7822E)))
                .padding(.bottom, 6)
            ForEach(Array(quests.enumerated()), id: \.offset) { i, q in
                let now = min(q.target, progress.progress(of: q)), was = min(q.target, before[q.id] ?? now)
                let n = i <= filled ? now : was, ok = n >= q.target
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(q.title).font(.nunito(15, .heavy)).foregroundStyle(Color.ink).lineLimit(1).minimumScaleFactor(0.8)
                        Spacer()
                        Text("\(n) / \(q.target)").font(.nunitoXB(13)).monospacedDigit().foregroundStyle(Color.muted)
                            .contentTransition(.numericText(value: Double(n)))
                    }
                    HStack(spacing: 12) {
                        Bar(value: Double(n) / Double(q.target), fill: Color(UIColor(hex: 0xF2B33D)))
                        Image("pocket-jade").resizable().scaledToFit().frame(width: 30, height: 34)
                            .opacity(ok ? 1 : 0.55)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Color.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(ok ? Color(UIColor(hex: 0xF2B33D)) : Color.line, lineWidth: ok ? 2.5 : 1.5))
                .modifier(SuccessShine(on: ok && i <= filled && was < q.target, delay: 0.3))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .task {
            if reduceMotion { filled = 2; return }
            try? await Task.sleep(for: .milliseconds(450))
            for i in 0..<3 {
                withAnimation(.easeOut(duration: 0.56)) { filled = i }
                try? await Task.sleep(for: .milliseconds(560 + 260))
            }
        }
    }
}
