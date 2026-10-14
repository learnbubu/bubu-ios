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
    /// a milestone day (3, 7, 14…): its line is told, not the week's
    var milestone = false
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

    init(streak: Int, milestone: Bool = false, finished: @escaping () -> Void) {
        self.streak = streak
        self.milestone = milestone
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
            Image("lantern-unlit").resizable().scaledToFit()
                .opacity(lit ? 0 : 1)
            Image("lantern-lit").resizable().scaledToFit()
                .opacity(lit ? 1 : 0)
        }
        .frame(height: 170)
        // its glow, behind (it doesn't make the lantern's box any bigger)
        .background {
            Circle()
                .fill(RadialGradient(colors: [Color(UIColor(hex: 0xFFB347)).opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: 130))
                .frame(width: 260, height: 260)
                .opacity(lit ? (flare ? 1 : 0.7) : 0)
                .scaleEffect(flare ? 1.15 : 1)
        }
        // the string it hangs from, fading out above, joining the little cord at the top of the picture
        .overlay(alignment: .top) {
            Rectangle().fill(LinearGradient(colors: [Color(UIColor(hex: 0xC9A05A)).opacity(0), Color(UIColor(hex: 0xC9A05A))], startPoint: .top, endPoint: .bottom))
                .frame(width: 2.5, height: 120).offset(y: -120 + 2)
        }
        .scaleEffect(flare ? 1.08 : 1, anchor: .top)
        .padding(.top, 20)
    }

    private func weekRow(_ week: [String], today: String) -> some View {
        let names = ["M", "T", "W", "T", "F", "S", "S"]
        return HStack(spacing: 10) {
            ForEach(0..<7, id: \.self) { i in
                let d = week[i], isToday = d == today, future = d > today
                let on = isToday ? todayTicked : progress.litOn(d)
                VStack(spacing: 8) {
                    Text(names[i]).font(.nunitoXB(12)).foregroundStyle(isToday ? Self.red : Color.muted)
                    let nextOn = i < 6 && (week[i + 1] == today ? todayTicked : week[i + 1] < today && progress.litOn(week[i + 1]))
                    ZStack {
                        Circle().fill(on ? Self.red : future ? Color.line.opacity(0.6) : Color.line.opacity(0.35))
                        if isToday && !on { Circle().strokeBorder(Self.red, style: StrokeStyle(lineWidth: 2, dash: [4, 3])) }
                        if on { Image(systemName: "checkmark").font(.system(size: 13, weight: .heavy)).foregroundStyle(.white) }
                    }
                    .frame(width: 32, height: 32)
                    // days in a row join up into one pill, as Duolingo's
                    .background(alignment: .leading) {
                        if on && nextOn { Rectangle().fill(Self.red).frame(width: 42, height: 32).offset(x: 16) }
                    }
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
        if milestone, let m = DoneView.milestoneWords[streak] {
            Text(m).font(.nunito(17, .heavy)).foregroundStyle(Color.ink).multilineTextAlignment(.center)
        } else if allSoFar && left == 0 {
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

/// Today's quests after a session (the owner, 14 Oct 2026: "more professional"): the pouch, how many
/// are done, and the three on one card, each bar filling from where it was when the session began;
/// a done one gets its tick, and all three, the lucky pocket.
struct QuestStage: View {
    let before: [String: Int]
    @Environment(ProgressStore.self) private var progress
    @State private var filled = -1
    @State private var bob = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let gold = Color(UIColor(hex: 0xF2B33D)), goldInk = Color(UIColor(hex: 0xB7822E))

    var body: some View {
        let quests = progress.todayQuests
        let shown = quests.enumerated().map { i, q -> Int in
            let now = min(q.target, progress.progress(of: q)), was = min(q.target, before[q.id] ?? now)
            return i <= filled ? now : was
        }
        let done = zip(quests, shown).filter { $1 >= $0.target }.count
        VStack(spacing: 0) {
            Image("quest-pouch").resizable().scaledToFit().frame(height: 104)
                .offset(y: bob ? -4 : 2)
                .shadow(color: goldInk.opacity(0.25), radius: 12, y: 8)
                .padding(.top, 6)
            Text("Daily quests").font(.nunito(28, .black)).tracking(-0.4).foregroundStyle(Home.ink).padding(.top, 14)
            Text(done == 3 ? "All three done today!" : "\(done) of 3 done today")
                .font(.nunito(15.5, .bold)).foregroundStyle(done == 3 ? goldInk : Home.muted)
                .contentTransition(.numericText(value: Double(done)))
                .padding(.top, 2)
            VStack(spacing: 0) {
                ForEach(Array(quests.enumerated()), id: \.offset) { i, q in
                    let n = shown[i], ok = n >= q.target
                    let was = min(q.target, before[q.id] ?? min(q.target, progress.progress(of: q)))
                    if i > 0 { Rectangle().fill(Home.line).frame(height: 1).padding(.leading, 66) }
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(ok ? Color.goodSoft : gold.opacity(0.18))
                            Image(systemName: ok ? "checkmark" : q.icon).font(.system(size: 17, weight: .heavy))
                                .foregroundStyle(ok ? Color.good : goldInk)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                // one size whatever the state (it shrank to fit beside "Done"): a long title wraps instead
                                Text(q.title).font(.nunito(15.5, .heavy)).foregroundStyle(Home.ink).lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 6)
                                Text(ok ? "Done" : "\(n) / \(q.target)").font(.nunito(13.5, .black)).monospacedDigit().fixedSize()
                                    .foregroundStyle(ok ? Color.good : Home.muted)
                                    .contentTransition(.numericText(value: Double(n)))
                            }
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color(UIColor(hex: 0xEFE9DD)))
                                    Capsule().fill(ok ? Color.good : gold).frame(width: g.size.width * Double(n) / Double(q.target))
                                }
                            }
                            .frame(height: 9)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 15)
                    .modifier(SuccessShine(on: ok && i <= filled && was < q.target, delay: 0.3))
                }
            }
            .homeCard(radius: 22)
            .padding(.top, 22)
            if done == 3 {
                HStack(spacing: 12) {
                    Image("pocket-jade").resizable().scaledToFit().frame(width: 34, height: 40)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Lucky pocket earned!").font(.nunito(16, .black)).foregroundStyle(Home.ink)
                        Text("Full of XP, for all three").font(.nunito(13, .bold)).foregroundStyle(Home.muted)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(gold.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(gold.opacity(0.6), lineWidth: 1.5))
                .padding(.top, 14)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .task {
            if !reduceMotion { withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { bob = true } }
            if reduceMotion { filled = 2; return }
            try? await Task.sleep(for: .milliseconds(450))
            for i in 0..<3 {
                withAnimation(.easeOut(duration: 0.56)) { filled = i }
                try? await Task.sleep(for: .milliseconds(560 + 260))
            }
        }
    }
}
