import SwiftUI

/// Today's three quests, all of them, with how far each has got: Home's Daily quests card opens it.
struct QuestsPage: View {
    @Environment(ProgressStore.self) private var progress

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    Image("quest-pouch").resizable().scaledToFit().frame(height: 64)
                    Text("Finish all three today to open the pouch.").font(.nunito(15, .bold)).foregroundStyle(Home.muted)
                }
                .padding(.top, 6)
                quests
            }
            .padding(.horizontal, 18).padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(Home.bg.ignoresSafeArea())
        .environment(\.colorScheme, .light)
        .pageBar("Daily quests")
        .onAppear { progress.ensureQuests() }
    }

    private func heading(_ t: String) -> some View {
        Text(t.uppercased()).font(.nunito(12, .black)).tracking(1.3).foregroundStyle(Home.teal).padding(.leading, 4)
    }

    private var quests: some View {
        let list = progress.todayQuests
        let n = { (q: Quest) in min(q.target, progress.questDone(q) ? q.target : progress.progress(of: q)) }
        let done = list.filter { n($0) >= $0.target }.count
        let opened = done == 3 && progress.chestOpened
        let gold = Color(UIColor(hex: 0xF2B33D)), goldInk = Color(UIColor(hex: 0xB7822E))
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                heading("Today")
                Spacer()
                Text(done == 3 ? (opened ? "Pocket opened" : "3/3") : "\(done)/3").font(.nunito(13, .black))
                    .foregroundStyle(done == 3 ? goldInk : Home.muted)
            }
            VStack(spacing: 0) {
                ForEach(Array(list.enumerated()), id: \.offset) { i, q in
                    let k = n(q), ok = k >= q.target
                    if i > 0 { Rectangle().fill(Home.line).frame(height: 1).padding(.leading, 60) }
                    HStack(spacing: 12) {
                        Image(systemName: ok ? "checkmark" : q.icon).font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(ok ? Color.good : goldInk)
                            .frame(width: 34, height: 34)
                            .background(ok ? Color.goodSoft : gold.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(q.title).font(.nunito(14.5, .heavy)).foregroundStyle(Home.ink).lineLimit(1).minimumScaleFactor(0.85)
                                Spacer(minLength: 6)
                                Text(ok ? "Done" : "\(k)/\(q.target)").font(.nunito(13, .black)).monospacedDigit().foregroundStyle(ok ? Color.good : Home.muted)
                            }
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color(UIColor(hex: 0xEFE9DD)))
                                    Capsule().fill(ok ? Color.good : gold).frame(width: g.size.width * Double(k) / Double(q.target))
                                }
                            }
                            .frame(height: 7)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                }
            }
            .homeCard()
        }
    }
}

/// Your learning activity: this month's lit days, this week's XP, every character: Profile's Learning activity row
/// opens it.
struct ActivityPage: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(Router.self) private var router
    @State private var tab = "month"

    var body: some View {
        ScrollView {
            activity.padding(.horizontal, 18).padding(.top, 6).padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(Home.bg.ignoresSafeArea())
        .environment(\.colorScheme, .light)
        .pageBar("Learning activity")
    }

    private func heading(_ t: String) -> some View {
        Text(t.uppercased()).font(.nunito(12, .black)).tracking(1.3).foregroundStyle(Home.teal).padding(.leading, 4)
    }

    private var activity: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                heading("Activity")
                Spacer()
                Segments(options: [("month", "Month"), ("week", "Week"), ("chars", "字")], value: $tab).frame(width: 200)
            }
            Group {
                switch tab {
                case "week": xpWeek
                case "chars": charGrid
                default: month
                }
            }
            .padding(16).homeCard()
        }
    }

    /// This month: lit days filled, goal days gold, relit days marked (web: renderStreakCal).
    private var month: some View {
        let cal = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: progress.now() / 1000)
        let first = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        let days = cal.range(of: .day, in: .month, for: now)!.count
        let lead = (cal.component(.weekday, from: first) + 5) % 7
        let today = progress.today
        let key = { (d: Int) in ProgressStore.dayKey(cal.date(byAdding: .day, value: d - 1, to: first)!.timeIntervalSince1970 * 1000) }
        let best = progress.bestStreak
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(first.formatted(.dateTime.month(.wide).year())).font(.nunitoXB(15)).foregroundStyle(Color.ink)
                Spacer()
                Text("Longest \(best) day\(best == 1 ? "" : "s")").font(.nunito(12.5, .bold)).foregroundStyle(Color.muted)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, n in
                    Text(n).font(.nunito(11, .bold)).foregroundStyle(Color.muted)
                }
                ForEach(0..<lead, id: \.self) { _ in Color.clear.frame(height: 30) }
                ForEach(1...days, id: \.self) { d in
                    let k = key(d)
                    let lit = progress.litOn(k), goal = false
                    let relit = progress.relitOn(k), isToday = k == today
                    ZStack {
                        Circle().fill(goal ? Color.gold : lit ? Color.good : .clear)
                        if isToday { Circle().strokeBorder(Color.accent, style: StrokeStyle(lineWidth: 2, dash: lit ? [] : [3, 3])) }
                        if relit { LanternMark(lit: true, size: 15) }
                        else { Text("\(d)").font(.nunito(12.5, .bold)).foregroundStyle(lit || goal ? Color.white : isToday ? Color.accent : Color.ink) }
                    }
                    .frame(height: 30)
                    .opacity(k > today ? 0.4 : 1)
                }
            }
            HStack {
                Label { Text("\(progress.embers) spare lantern\(progress.embers == 1 ? "" : "s")") } icon: { LanternMark(size: 15) }.font(.nunitoXB(12.5)).foregroundStyle(Color.gold)
                Spacer()
                HStack(spacing: 8) {
                    legend("done", .good); legend("relit", .good)
                }
            }
        }
    }

    private func legend(_ t: String, _ c: Color) -> some View {
        HStack(spacing: 3) { Circle().fill(c).frame(width: 8, height: 8); Text(t).font(.nunito(11, .semibold)).foregroundStyle(Color.muted) }
    }

    /// XP each day this week (web: renderXpWeek).
    private var xpWeek: some View {
        let days = progress.thisWeek, today = progress.today
        let vals = days.map(progress.xp(on:))
        let top = max(20, vals.max() ?? 0)
        let names = ["M", "T", "W", "T", "F", "S", "S"]
        return VStack(alignment: .leading, spacing: 10) {
            Text("XP this week").font(.nunitoXB(15)).foregroundStyle(Color.ink)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7, id: \.self) { i in
                    VStack(spacing: 4) {
                        Text(vals[i] > 0 ? "\(vals[i])" : " ").font(.nunito(11, .bold)).foregroundStyle(Color.muted)
                        RoundedRectangle(cornerRadius: 6).fill(days[i] == today ? Color.accent : Color.good.opacity(0.6))
                            .frame(height: max(4, 120 * CGFloat(vals[i]) / CGFloat(top)))
                        Text(names[i]).font(.nunito(11.5, .bold)).foregroundStyle(days[i] == today ? Color.accent : Color.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(days[i] > today ? 0.4 : 1)
                }
            }
            .frame(height: 160, alignment: .bottom)
        }
    }

    /// Every character as a little square, darker when stronger (web: renderCharGrid).
    private var charGrid: some View {
        let rows = Course.allChars.map { c -> (Int, Bool) in let lv = progress.charLevel(c.ch); return (lv, lv > 0 && progress.charDue(c.ch)) }
        let strong = rows.filter { $0.0 >= 2 }.count, learning = rows.filter { $0.0 == 1 }.count, due = rows.filter(\.1).count
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Your characters").font(.nunitoXB(15)).foregroundStyle(Color.ink)
                Spacer()
                Button("Open ›") { router.push(.chars) }.font(.nunitoXB(13.5)).foregroundStyle(Color.accent)
            }
            Canvas { ctx, size in
                let cols = 40, cell = size.width / CGFloat(cols)
                for (i, r) in rows.enumerated() {
                    let x = CGFloat(i % cols) * cell, y = CGFloat(i / cols) * cell
                    let c: Color = r.0 == 3 ? .good : r.0 == 2 ? .good.opacity(0.55) : r.0 == 1 ? .goodSoft : .line
                    ctx.fill(Path(roundedRect: CGRect(x: x + 0.5, y: y + 0.5, width: cell - 1, height: cell - 1), cornerRadius: 1.5), with: .color(r.1 ? .gold : c))
                }
            }
            .frame(height: CGFloat((rows.count + 39) / 40) * ((UIScreen.main.bounds.width - 68) / 40))
            Text("\(strong) strong · \(learning) learning · \(due) due").font(.nunito(12.5, .bold)).foregroundStyle(Color.muted)
        }
    }
}
