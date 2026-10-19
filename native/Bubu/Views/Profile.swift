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

/// Profile (the owner's mock, 19 Oct 2026): your avatar big on his disc, your name and level, four numbers in a row,
/// achievements, and your learning activity a tap away. The hanger, top right, dresses him (settings is in the tab
/// bar); today's quests are on a page of their own, behind Home's Daily quests.
struct ProfileView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(Router.self) private var router
    @State private var allAch = false
    @State private var dressing = false
    @State private var look = AvatarLook.load()
    private let course = Course.shared

    var body: some View {
        let lv = progress.level
        let out = progress.outSince
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Profile").font(.nunito(32, .black)).tracking(-0.5).foregroundStyle(Home.ink)
                    Spacer()
                    Button { dressing = true } label: {
                        Image(systemName: "hanger").font(.system(size: 19, weight: .bold)).foregroundStyle(Home.teal)
                            .frame(width: 44, height: 44).homeCard(radius: 22)
                    }
                    .buttonStyle(CardPress())
                    .accessibilityLabel("Your avatar")
                }
                .padding(.top, 8)

                you(lv)
                numbers(out: out)
                if out != nil {
                    Button(progress.embers < 1 ? "No spare lanterns left" : "Use a spare lantern") {
                        if let o = out { Moments.shared.show(.askRelight(lost: o.lost, embers: progress.embers)) }
                    }
                    .buttonStyle(WideButton()).disabled(progress.embers < 1)
                }
                achievements
                activityRow
                Color.clear.frame(height: 90)
            }
            .padding(.horizontal, 18)
        }
        .scrollIndicators(.hidden)
        .background(Home.bg.ignoresSafeArea())
        .environment(\.colorScheme, .light)
        .onAppear { stamp() }
        .fullScreenCover(isPresented: $dressing) {
            // (the saved look on him now, as the editor goes, not once it's gone)
            AvatarEditor { saved in if let saved { look = saved }; dressing = false }
        }
    }

    /// The day each achievement was first earned, for ordering.
    private func stamp() {
        for a in Achievement.all where progress.activity.achv[a.id] == nil && a.test(progress) { progress.stampAchievement(a.id) }
    }

    private func title(_ t: String) -> some View {
        Text(t).font(.nunito(20, .black)).foregroundStyle(Home.ink)
    }

    // MARK: you: your avatar (alive: it idles, and now and then plays one of its outfit's moves; tap it), your name,
    // your level

    private func you(_ lv: (level: Int, into: Int, span: Int, next: Int)) -> some View {
        let name = progress.name.trimmingCharacters(in: .whitespaces)
        let gold = Color(UIColor(hex: 0xF2B33D)), goldInk = Color(UIColor(hex: 0xA8741F))
        return VStack(alignment: .leading, spacing: 6) {
            ZStack {
                AvatarBackdrop(hex: look.backdrop).frame(width: 290, height: 290)
                AvatarFigure(outfit: look.outfit, look: look.colours, size: 316)
            }
            .frame(width: 316, height: 316)
            .frame(maxWidth: .infinity)
            HStack(alignment: .center, spacing: 10) {
                Text(name.isEmpty ? "Learner" : name).font(.nunito(28, .black)).foregroundStyle(Home.ink).lineLimit(1).minimumScaleFactor(0.7)
                Text("Level \(lv.level)").font(.nunito(14, .black)).foregroundStyle(goldInk)
                    .padding(.horizontal, 11).padding(.vertical, 4)
                    .background(gold.opacity(0.3), in: Capsule())
            }
            .padding(.top, 4)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(UIColor(hex: 0xEFE9DD)))
                    Capsule().fill(gold).frame(width: g.size.width * Double(lv.into) / Double(max(1, lv.span)))
                }
            }
            .frame(height: 8)
            .padding(.trailing, 70).padding(.top, 4)
            Text("\(lv.next) XP to level \(lv.level + 1)").font(.nunito(13, .bold)).foregroundStyle(Home.muted)
        }
    }

    // MARK: four numbers, in a row

    private func numbers(out: (date: String, lost: Int)?) -> some View {
        let learned = course.cards.filter { (progress.srs[$0.id]?.reps ?? 0) >= 1 }.count
        let lit = out == nil && progress.streak > 0
        return HStack(spacing: 0) {
            number(out.map { "\($0.lost)" } ?? "\(progress.streak)", out != nil ? "Went out" : "Streak",
                   icon: lit ? "chip-lantern-lit" : "chip-lantern-unlit")
            divider
            number(progress.xpTotal.formatted(), "XP", symbol: "bolt.fill", tint: 0xF2B33D)
            divider
            Button { router.push(.chars) } label: { number("\(progress.charsKnown)", "Characters", han: true) }.buttonStyle(CardPress())
            divider
            number("\(learned)", "Words", symbol: "leaf.fill", tint: 0x1F8A6D)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .top) { Rectangle().fill(Home.line).frame(height: 1.5) }
        .overlay(alignment: .bottom) { Rectangle().fill(Home.line).frame(height: 1.5) }
    }

    private var divider: some View { Rectangle().fill(Home.line).frame(width: 1.5, height: 34) }

    private func number(_ value: String, _ label: String, icon: String? = nil, symbol: String? = nil, tint: UInt32 = 0x1F7A6C, han: Bool = false) -> some View {
        HStack(spacing: 6) {
            Group {
                if let icon { Image(icon).resizable().scaledToFit().frame(height: 26) }
                else if han { Text("字").font(.hanzi(19, .black)).foregroundStyle(Home.teal) }
                else if let symbol { Image(systemName: symbol).font(.system(size: 18, weight: .bold)).foregroundStyle(Color(UIColor(hex: tint))) }
            }
            .frame(width: 24)
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.nunito(17, .black)).foregroundStyle(Home.ink).lineLimit(1).minimumScaleFactor(0.6)
                Text(label).font(.nunito(11.5, .bold)).foregroundStyle(Home.muted).lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: achievements: a row of medals, the newest first; See all for every one

    private var achievements: some View {
        let achv = progress.activity.achv
        let earned = Achievement.all.filter { achv[$0.id] != nil }.sorted { achv[$0.id]! > achv[$1.id]! }
        let locked = Achievement.all.filter { achv[$0.id] == nil }
        let list = allAch ? earned + locked : Array((earned + locked).prefix(5))
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                title("Achievements")
                Spacer()
                Button { withAnimation { allAch.toggle() } } label: {
                    HStack(spacing: 2) {
                        Text(allAch ? "Show fewer" : "See all")
                        if !allAch { Image(systemName: "chevron.right").font(.system(size: 12, weight: .heavy)) }
                    }
                    .font(.nunito(15, .black)).foregroundStyle(Home.teal)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 14) {
                ForEach(list) { a in
                    let got = achv[a.id] != nil
                    VStack(spacing: 6) {
                        Image(systemName: a.icon).font(.system(size: 22)).foregroundStyle(got ? a.tint : Color.muted)
                            .frame(width: 56, height: 56).background((got ? a.tint : Color.muted).opacity(0.15), in: Circle())
                            .overlay(alignment: .bottomTrailing) {
                                if !got {
                                    Image(systemName: "lock.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                                        .frame(width: 20, height: 20).background(Color.muted, in: Circle())
                                }
                            }
                        Text(a.title).font(.nunito(11.5, .bold)).foregroundStyle(Home.muted).multilineTextAlignment(.center).lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                    .saturation(got ? 1 : 0)
                    .accessibilityElement(children: .combine)
                    .accessibilityHint(a.sub)
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: your learning activity, on its own page

    private var activityRow: some View {
        Button { router.push(.activity) } label: {
            HStack(spacing: 14) {
                Image(systemName: "calendar").font(.system(size: 18, weight: .bold)).foregroundStyle(Home.teal)
                    .frame(width: 44, height: 44).homeCard(radius: 22)
                Text("Learning activity").font(.nunito(18, .black)).foregroundStyle(Home.ink)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 15, weight: .heavy)).foregroundStyle(Home.ink)
            }
            .padding(.top, 14).padding(.bottom, 4)
            .contentShape(Rectangle())
            .overlay(alignment: .top) { Rectangle().fill(Home.line).frame(height: 1.5) }
        }
        .buttonStyle(CardPress())
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
