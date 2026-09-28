import SwiftUI

/// Achievements, worked out from what's already tracked (web: achievementDefs).
struct Achievement: Identifiable {
    let id: String, icon: String, tint: Color, title: String, sub: String
    let test: (ProgressStore) -> Bool

    static let all: [Achievement] = {
        let learned = { (p: ProgressStore) in Course.shared.cards.filter { (p.srs[$0.id]?.reps ?? 0) >= 1 }.count }
        var a: [Achievement] = [
            .init(id: "streak-7", icon: "flame.fill", tint: .again, title: "7-day streak", sub: "Keep it going!") { $0.streak >= 7 },
            .init(id: "streak-30", icon: "flame.fill", tint: .again, title: "30-day streak", sub: "A whole month") { $0.streak >= 30 },
            .init(id: "words-50", icon: "leaf.fill", tint: .good, title: "First words", sub: "Learned 50 words") { learned($0) >= 50 },
            .init(id: "words-200", icon: "leaf.fill", tint: .good, title: "Growing", sub: "Learned 200 words") { learned($0) >= 200 },
            .init(id: "lessons-10", icon: "flag.fill", tint: Color.tiles["teal"]!.ink, title: "On a roll", sub: "10 lessons") { $0.done.count >= 10 },
            .init(id: "level-5", icon: "crown.fill", tint: .gold, title: "Level 5", sub: "1,000 XP") { $0.level.level >= 5 },
            .init(id: "level-10", icon: "crown.fill", tint: .gold, title: "Level 10", sub: "5,500 XP") { $0.level.level >= 10 },
            .init(id: "quests-20", icon: "scope", tint: Color.tiles["teal"]!.ink, title: "Quest month", sub: "20 quests in a month") { $0.activity.questMonths.values.contains { $0 >= 20 } },
            .init(id: "chests-10", icon: "gift.fill", tint: .gold, title: "Lucky panda", sub: "10 lucky pockets opened") { $0.activity.chests >= 10 },
        ]
        for (i, ch) in Course.shared.chapters.enumerated() {
            a.append(.init(id: "chapter-\(i)", icon: "book.fill", tint: Color.tiles["blue"]!.ink, title: "Chapter \(i + 1) complete", sub: ch.title) { $0.chapterDone(i) })
        }
        return a
    }()
}

/// Profile, as the web's: you and your avatar, your numbers, where you are on the
/// path, achievements, this month's fire, this week's XP, your characters, and
/// how much of each chapter you've mastered.
struct ProfileView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(Router.self) private var router
    @State private var tab = "month"
    @State private var allAch = false
    private let course = Course.shared

    var body: some View {
        let lv = progress.level
        let out = progress.outSince
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Profile").font(.nunitoXB(28)).foregroundStyle(Color.ink)
                    Spacer()
                    Button { router.tab = .settings } label: {
                        Image(systemName: "gearshape.fill").font(.system(size: 17)).foregroundStyle(Color.accent)
                            .frame(width: 38, height: 38).background(Color.panel, in: Circle()).overlay(Circle().strokeBorder(Color.line, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)

                hero(lv)
                stats(lv, out: out)
                if out != nil {
                    Button(progress.embers < 1 ? "No embers to relight" : "Relight the fire") {
                        if let o = out { Moments.shared.show(.askRelight(lost: o.lost, embers: progress.embers)) }
                    }
                    .buttonStyle(WideButton()).disabled(progress.embers < 1)
                }
                pathCard
                achievements
                quote
                activity
                mastery
                Color.clear.frame(height: 90)
            }
            .padding(.horizontal, 18)
        }
        .scrollIndicators(.hidden)
        .background(Color.bg.ignoresSafeArea())
        .onAppear { stamp() }
    }

    /// The day each achievement was first earned, for ordering.
    private func stamp() {
        for a in Achievement.all where progress.activity.achv[a.id] == nil && a.test(progress) { progress.stampAchievement(a.id) }
    }

    private func hero(_ lv: (level: Int, into: Int, span: Int, next: Int)) -> some View {
        ZStack(alignment: .bottom) {
            // the picture fills the card without setting its width
            Color.clear.frame(maxWidth: .infinity).frame(height: 285)
                .overlay { Image("profile-hero").resizable().scaledToFill() }
                .clipped()
            AvatarView(config: progress.avatar).frame(width: 310, height: 310).offset(y: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(progress.name.isEmpty ? "Learner" : progress.name).font(.nunitoXB(24)).foregroundStyle(Color.ink)
                Text("Level \(lv.level) · \(lv.next) XP to go").font(.nunito(13.6, .semibold)).foregroundStyle(Color.muted)
                    .frame(maxWidth: 110, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(16).padding(.top, -4)
            Button { router.push(.avatar) } label: {
                Label("Edit", systemImage: "pencil").font(.nunitoXB(14)).foregroundStyle(Color.ink)
                    .padding(.horizontal, 17).padding(.vertical, 9).background(Color.panel.opacity(0.92), in: Capsule())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(14)
        }
        .frame(height: 285)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.line))
    }

    private func stats(_ lv: (level: Int, into: Int, span: Int, next: Int), out: (date: String, lost: Int)?) -> some View {
        HStack(spacing: 8) {
            stat(out.map { "\($0.lost)" } ?? "\(progress.streak)", out != nil ? "Went out" : "Day streak", muted: out != nil)
            stat(lv.level > 0 ? progress.xpTotal.formatted() : "0", "Total XP")
            Button { router.push(.chars) } label: { stat("\(progress.charsKnown)", "Characters", han: true) }.buttonStyle(.plain)
            stat("\(lv.level)", "Level")
        }
    }

    private func stat(_ value: String, _ label: String, muted: Bool = false, han: Bool = false) -> some View {
        VStack(spacing: 2) {
            if han { Text("字").font(.hanzi(13, .bold)).foregroundStyle(Color.accent) }
            Text(value).font(.nunitoXB(20)).foregroundStyle(muted ? Color.muted : Color.ink).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.nunito(11.5, .bold)).foregroundStyle(Color.muted).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12).panel(radius: 16)
    }

    /// The chapter you're in, and how far through it.
    private var pathCard: some View {
        let cur = progress.currentLessonId
        let ci = cur.flatMap { course.chapterOf[$0] } ?? course.chapters.count - 1
        let ch = course.chapters[ci]
        let done = ch.lessons.filter(progress.isDone).count
        return Button { router.tab = .learn } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text("LEARNING PATH").font(.nunito(12.5, .bold)).foregroundStyle(Color.muted)
                Text(course.chapterLabel(ci)).font(.nunitoXB(20)).foregroundStyle(Color.ink).padding(.top, 3)
                Text(ch.title).font(.nunito(13.5, .semibold)).foregroundStyle(Color.muted)
                Bar(value: Double(done) / Double(max(1, ch.lessons.count)), height: 8).frame(maxWidth: 200).padding(.top, 12).padding(.bottom, 7)
                Text("\(done) / \(ch.lessons.count) lessons").font(.nunito(13, .bold)).foregroundStyle(Color.muted)
                    .padding(.horizontal, 6).padding(.vertical, 3).background(Color.panel, in: RoundedRectangle(cornerRadius: 8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background {
                Color.clear.overlay { Image("profile-path").resizable().scaledToFill() }.clipped()
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0.3), .init(color: .black, location: 0.9)], startPoint: .leading, endPoint: .trailing))
            }
            .background(Color.panel)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "chevron.right").font(.system(size: 19, weight: .bold)).foregroundStyle(Color.onAccent)
                    .frame(width: 46, height: 46).background(Color.accent, in: Circle()).padding(14)
            }
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.line))
        }
        .buttonStyle(PressDown(depth: 2))
    }

    private var achievements: some View {
        let achv = progress.activity.achv
        let earned = Achievement.all.filter { achv[$0.id] != nil }.sorted { achv[$0.id]! > achv[$1.id]! }
        let locked = Achievement.all.filter { achv[$0.id] == nil }
        let list = allAch ? earned + locked : Array((earned + locked).prefix(4))
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent achievements").font(.nunitoXB(17)).foregroundStyle(Color.ink)
                Spacer()
                Button(allAch ? "Show fewer" : "See all ›") { withAnimation { allAch.toggle() } }
                    .font(.nunitoXB(14)).foregroundStyle(Color.accent)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(list) { a in
                    let got = achv[a.id] != nil
                    VStack(spacing: 4) {
                        Image(systemName: a.icon).font(.system(size: 20)).foregroundStyle(got ? a.tint : Color.muted)
                            .frame(width: 48, height: 48).background((got ? a.tint : Color.muted).opacity(0.14), in: Circle())
                        Text(a.title).font(.nunitoXB(10.9)).foregroundStyle(Color.ink).multilineTextAlignment(.center).lineLimit(2)
                        Text(a.sub).font(.nunito(9.6, .semibold)).foregroundStyle(Color.muted).multilineTextAlignment(.center).lineLimit(2)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 12).padding(.horizontal, 4)
                    .panel(radius: 16)
                    .opacity(got ? 1 : 0.55)
                    .saturation(got ? 1 : 0)
                }
            }
        }
        .padding(.top, 6)
    }

    private var quote: some View {
        HStack(spacing: 14) {
            Text("“").font(.nunitoXB(38)).opacity(0.5).frame(maxHeight: .infinity, alignment: .top)
            Text("A little progress\ngoes a long way.").font(.nunito(15.2, .semibold))
            Spacer()
            VStack(spacing: 0) {
                Text("步步").font(.hanzi(23, .bold)).foregroundStyle(Color.ink)
                Text("Bùbù").font(.nunito(11, .semibold)).foregroundStyle(Color.ink)
            }
        }
        .foregroundStyle(Color.accent)
        .padding(18).frame(minHeight: 106)
        .background(alignment: .bottomTrailing) {
            Image("profile-foliage").resizable().scaledToFit().frame(width: 120, height: 120).offset(x: -37, y: 10)
        }
        .background(Color.panel)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.line))
    }

    // MARK: activity

    private var activity: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Activity").font(.nunitoXB(17)).foregroundStyle(Color.ink)
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
            .padding(16).panel(radius: 18)
        }
        .padding(.top, 6)
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
                        if relit { Image(systemName: "flame.fill").font(.system(size: 12)).foregroundStyle(.white) }
                        else { Text("\(d)").font(.nunito(12.5, .bold)).foregroundStyle(lit || goal ? Color.white : isToday ? Color.accent : Color.ink) }
                    }
                    .frame(height: 30)
                    .opacity(k > today ? 0.4 : 1)
                }
            }
            HStack {
                Label("\(progress.embers) ember\(progress.embers == 1 ? "" : "s")", systemImage: "flame").font(.nunitoXB(12.5)).foregroundStyle(Color.gold)
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

    // MARK: mastery by chapter

    private var mastery: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mastered by chapter").font(.nunitoXB(17)).foregroundStyle(Color.ink).padding(.top, 6)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(course.chapters.enumerated()), id: \.offset) { ci, ch in
                    if ci == 0 || course.chapters[ci - 1].unit != ch.unit {
                        Text(ch.unit).font(.nunito(12, .black)).tracking(0.8).foregroundStyle(Color.accent).padding(.top, ci == 0 ? 0 : 12).padding(.bottom, 4)
                    }
                    let cards = course.chapterCards[ci]
                    let m = cards.filter { progress.isMastered($0.id) }.count
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(ch.title).font(.nunito(13.5, .semibold)).foregroundStyle(Color.ink).lineLimit(1)
                            Spacer()
                            Text("\(m) / \(cards.count)").font(.nunito(12.5, .bold)).monospacedDigit().foregroundStyle(m == cards.count && m > 0 ? Color.good : Color.muted)
                        }
                        Bar(value: cards.isEmpty ? 0 : Double(m) / Double(cards.count), height: 5, fill: .good)
                    }
                    .padding(.vertical, 5)
                }
            }
            .padding(16).panel(radius: 18)
        }
    }
}

extension ProgressStore {
    /// Your avatar, brought up to date with the wardrobe.
    var avatar: AvatarConfig { Wardrobe.shared.migrate(prefs.avatar) }
}

// MARK: - the avatar builder (web: renderModularBuilder)

struct AvatarBuilderPage: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.dismiss) private var dismiss
    @State private var draft: AvatarConfig?
    @State private var section = "Outfit"
    @State private var category = "top"
    private let w = Wardrobe.shared

    static let sections: [(name: String, icon: String, keys: [String])] = [
        ("Face", "face.smiling", ["tone", "eyes", "brows", "mouth"]), ("Hair", "comb", ["hair", "hairColour"]),
        ("Outfit", "tshirt", ["top", "bottom", "shoes"]), ("Extras", "star", ["accessory"]),
    ]
    static let names = ["top": "Tops", "bottom": "Bottoms", "shoes": "Shoes", "accessory": "Accessories", "hair": "Hair",
                        "hairColour": "Hair colour", "tone": "Skin", "eyes": "Eyes", "brows": "Brows", "mouth": "Mouth"]

    var body: some View {
        let cfg = draft ?? progress.avatar
        VStack(spacing: 0) {
            ZStack {
                Color.clear.frame(maxWidth: .infinity)
                    .overlay { Image("profile-hero").resizable().scaledToFill() }
                    .clipped()
                AvatarView(config: cfg).frame(width: 290, height: 290).offset(y: 20)
                    .animation(.spring(response: 0.3), value: cfg)
            }
            .frame(height: 280).clipped()

            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    ForEach(Self.sections, id: \.name) { s in
                        Button { section = s.name; category = s.keys[0] } label: {
                            VStack(spacing: 3) {
                                Image(systemName: s.icon).font(.system(size: 18, weight: .semibold))
                                Text(s.name).font(.nunitoXB(12.5))
                            }
                            .foregroundStyle(section == s.name ? Color.onAccent : Color.ink)
                            .frame(maxWidth: .infinity).padding(.vertical, 9)
                            .background(section == s.name ? Color.accent : Color.bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Self.sections.first { $0.name == section }?.keys ?? [], id: \.self) { k in
                            Button { category = k } label: {
                                Text(Self.names[k] ?? k).font(.nunito(14, .bold)).foregroundStyle(category == k ? Color.onAccent : Color.ink)
                                    .padding(.horizontal, 14).padding(.vertical, 7)
                                    .background(category == k ? Color.ink : Color.bg, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                ScrollView {
                    if category == "tone" {
                        HStack(spacing: 12) {
                            ForEach(w.choices(cfg, "tone"), id: \.self) { id in
                                Button { set(cfg, "tone", id) } label: {
                                    Circle().fill(w.toneColour(id)).frame(width: 46, height: 46)
                                        .overlay(Circle().strokeBorder(cfg.tone == id ? Color.accent : Color.line, lineWidth: cfg.tone == id ? 3 : 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 6)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 10)], spacing: 10) {
                            ForEach(w.choices(cfg, category), id: \.self) { id in
                                let next = w.change(cfg, category, id)
                                let on = cfg[category] == id
                                Button { if let n = next { draft = n } } label: {
                                    VStack(spacing: 3) {
                                        if let n = next, let l = w.layer(for: category, in: n), let t = w.thumbnail(l) {
                                            Image(t).resizable().scaledToFit().frame(width: 72, height: 72)
                                        } else {
                                            Image(systemName: "nosign").font(.system(size: 26)).foregroundStyle(Color.muted).frame(width: 72, height: 72)
                                        }
                                        if !["top", "bottom", "shoes"].contains(category) {
                                            Text(Wardrobe.label(id)).font(.nunito(11.5, .bold)).foregroundStyle(Color.ink).lineLimit(1)
                                        }
                                    }
                                    .frame(maxWidth: .infinity).padding(6)
                                    .background(Color.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(on ? Color.accent : Color.line, lineWidth: on ? 2.5 : 1))
                                }
                                .buttonStyle(PressDown(depth: 1))
                                .disabled(next == nil)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    if section == "Extras" {
                        Text("More accessories are coming soon.").font(.nunito(13)).foregroundStyle(Color.muted).padding(.top, 8)
                    }
                }
                Button("Save Avatar") {
                    progress.prefs.avatar = cfg
                    Moments.shared.toast("Avatar saved")
                    dismiss()
                }
                .buttonStyle(WideButton())
            }
            .padding(16)
            .background(Color.panel)
        }
        .sensoryFeedback(.selection, trigger: draft)
        .navigationTitle("Edit Avatar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("Reset") { draft = nil } }
        }
    }

    private func set(_ cfg: AvatarConfig, _ key: String, _ id: String) {
        if let n = w.change(cfg, key, id) { draft = n }
    }
}
