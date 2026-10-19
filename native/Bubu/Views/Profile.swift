import SwiftUI

/// Profile (the owner's pick, 19 Oct 2026: Duolingo's order, a small overview): your avatar big on his disc, your
/// name, when you joined and your level, Invite friends, an overview of four numbers, achievements, and your learning
/// activity a tap away. The hanger, top right, dresses him (settings is in the tab bar); today's quests are on a page
/// of their own, behind Home's Daily quests.
struct ProfileView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(Router.self) private var router
    @State private var dressing = Launch.screen == "dress"   // (`-screen dress`: the editor, for the Mac's checks)
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
                invite(lv)
                overview(out: out)
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
            AvatarEditor { saved in
                if let saved { look = saved; if saved.outfit != Outfit.all[0].id { progress.dressUp() } }
                dressing = false
            }
        }
    }

    /// Every achievement tier reached, stamped with the day (for "NEW" and the newest first).
    private func stamp() { progress.stampAchievements() }

    /// a section's name, small and quiet
    private func heading(_ t: String) -> some View {
        Text(t.uppercased()).font(.nunito(13, .black)).tracking(1.4).foregroundStyle(Home.muted)
    }

    /// The month you started: the first day anything was done.
    private var joined: String? {
        let a = progress.activity
        guard let first = (Array(a.days.keys) + Array(a.xpDays.keys) + Array(a.lit.keys)).min() else { return nil }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        return f.date(from: first)?.formatted(.dateTime.month(.wide).year())
    }

    // MARK: you: your avatar (alive: it idles, and now and then plays one of its outfit's moves; tap it), your name,
    // your level

    private func you(_ lv: (level: Int, into: Int, span: Int, next: Int)) -> some View {
        let name = progress.name.trimmingCharacters(in: .whitespaces)
        return VStack(alignment: .leading, spacing: 6) {
            ZStack {
                AvatarBackdrop(hex: look.backdrop).frame(width: 290, height: 290)
                AvatarFigure(outfit: look.outfit, look: look.colours, size: 316)
            }
            .frame(width: 316, height: 316)
            .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 4) {
                Text(name.isEmpty ? "Learner" : name).font(.nunito(28, .black)).foregroundStyle(Home.ink).lineLimit(1).minimumScaleFactor(0.7)
                HStack(spacing: 8) {
                    if let j = joined { Text("Joined \(j)").font(.nunito(13.5, .bold)).foregroundStyle(Home.muted).lineLimit(1) }
                    Text("Level \(lv.level)").font(.nunito(12.5, .black)).foregroundStyle(Home.teal)
                        .padding(.horizontal, 9).padding(.vertical, 3)
                        .background(Home.teal.opacity(0.12), in: Capsule())
                }
            }
            .padding(.top, 4)
        }
    }

    // MARK: invite friends (the share sheet: there are no accounts to follow yet), and share how you're doing

    private func invite(_ lv: (level: Int, into: Int, span: Int, next: Int)) -> some View {
        let mine = "I'm on level \(lv.level) in Bùbù 步步 and I can read \(progress.charsKnown) Chinese characters!"
        return HStack(spacing: 10) {
            ShareLink(item: "I'm learning Chinese with Bùbù 步步. Come and learn with me!") {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus").font(.system(size: 16, weight: .bold))
                    Text("INVITE FRIENDS").font(.nunito(14, .black)).tracking(0.6).lineLimit(1)
                }
                .foregroundStyle(Home.teal)
                .frame(maxWidth: .infinity).frame(height: 46)
                .homeCard(radius: 15)
            }
            .buttonStyle(CardPress())
            ShareLink(item: mine) {
                Image(systemName: "square.and.arrow.up").font(.system(size: 16, weight: .bold)).foregroundStyle(Home.teal)
                    .frame(width: 46, height: 46).homeCard(radius: 15)
            }
            .buttonStyle(CardPress())
            .accessibilityLabel("Share your progress")
        }
    }

    // MARK: overview: four numbers, small, two by two

    private func overview(out: (date: String, lost: Int)?) -> some View {
        let learned = course.cards.filter { (progress.srs[$0.id]?.reps ?? 0) >= 1 }.count
        let lit = out == nil && progress.streak > 0
        let days = out?.lost ?? progress.streak
        return VStack(alignment: .leading, spacing: 12) {
            heading("Overview")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10, alignment: .leading), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 14) {
                stat("\(days) day\(days == 1 ? "" : "s")\(out != nil ? " (out)" : "")", icon: lit ? "chip-lantern-lit" : "chip-lantern-unlit")
                stat("\(progress.xpTotal.formatted()) XP", symbol: "bolt.fill", tint: 0xF2B33D)
                Button { router.push(.chars) } label: { stat("\(progress.charsKnown) characters", han: true) }.buttonStyle(CardPress())
                stat("\(learned) words", symbol: "leaf.fill", tint: 0x1F8A6D)
            }
        }
        .padding(.top, 4)
    }

    private func stat(_ value: String, icon: String? = nil, symbol: String? = nil, tint: UInt32 = 0x1F7A6C, han: Bool = false) -> some View {
        HStack(spacing: 8) {
            Group {
                if let icon { Image(icon).resizable().scaledToFit().frame(height: 22) }
                else if han { Text("字").font(.hanzi(17, .black)).foregroundStyle(Home.teal) }
                else if let symbol { Image(systemName: symbol).font(.system(size: 16, weight: .bold)).foregroundStyle(Color(UIColor(hex: tint))) }
            }
            .frame(width: 22)
            Text(value).font(.nunito(16, .black)).foregroundStyle(Home.ink).lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    // MARK: achievements: three badges, the newest earned first; the rest on their own page

    private var achievements: some View {
        let w = (UIScreen.main.bounds.width - 36 - 24) / 3
        return VStack(alignment: .leading, spacing: 12) {
            Button { router.push(.achievements) } label: {
                HStack {
                    heading("Achievements")
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .heavy)).foregroundStyle(Home.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("See all achievements")
            HStack(alignment: .top, spacing: 12) {
                ForEach(progress.achievementsInOrder.prefix(3)) { f in AchievementCell(family: f, width: w) }
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
