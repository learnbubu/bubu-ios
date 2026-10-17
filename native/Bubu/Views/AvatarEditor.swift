import SwiftUI

/// Your avatar, to dress: him big on his disc, alive, and below him what to change, a tab at a time (Look: his skin;
/// Hair; Outfit: sweater and trousers; Extras: the disc's colour). Changes show on him at once; Save look keeps them,
/// back leaves them.
struct AvatarEditor: View {
    var name = "relaxed"
    var close: () -> Void
    @State private var look = AvatarLook.load()
    @State private var tab = Tab.look
    private let rig = AvatarRig.load("relaxed")

    enum Tab: String, CaseIterable { case look = "Look", hair = "Hair", outfit = "Outfit", extras = "Extras" }

    /// what each tab offers: the rig's colours, by name (Studio's), with what to call them here
    private func groups(_ t: Tab) -> [(title: String, channel: String)] {
        switch t {
        case .look: return [("Skin", "Skin")]
        case .hair: return [("Hair colour", "Hair colour")]
        case .outfit: return [("Sweater", "Sweater colour"), ("Trousers", "Trousers colour")]
        case .extras: return []
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            header
            ZStack {
                AvatarBackdrop(hex: look.backdrop).frame(width: 250, height: 250)
                AvatarStage(name: name, look: look.colours).frame(width: 266, height: 266)
            }
            .frame(height: 266)
            tabs
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    let gs = groups(tab)
                    ForEach(gs.indices, id: \.self) { n in
                        if let c = rig?.channels?.first(where: { $0.name == gs[n].channel }) { section(gs[n].title, swatches: c.swatches, picked: look.colours[c.name] ?? 0) { look.colours[c.name] = $0 } }
                    }
                    if tab == .extras {
                        section("Background", swatches: AvatarBackdrop.colours.map { $0.hex }, names: AvatarBackdrop.colours.map { $0.name },
                                picked: AvatarBackdrop.colours.firstIndex { $0.hex == look.backdrop } ?? 0) { look.backdrop = AvatarBackdrop.colours[$0].hex }
                    }
                }
                .padding(.horizontal, 18).padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
            Button("Save look") { look.save(); close() }
                .buttonStyle(WideButton())
                .padding(.horizontal, 18).padding(.bottom, 8)
        }
        .background(Home.bg.ignoresSafeArea())
        .environment(\.colorScheme, .light)
    }

    private var header: some View {
        HStack {
            round("chevron.left", label: "Back") { close() }
            Spacer()
            Text("Your avatar").font(.nunito(18, .black)).foregroundStyle(Home.ink)
            Spacer()
            round("arrow.uturn.backward", label: "Start again") { withAnimation(.easeOut(duration: 0.2)) { look = AvatarLook() } }
        }
        .padding(.horizontal, 18).padding(.top, 8)
    }

    private func round(_ icon: String, label: String, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(Home.ink)
                .frame(width: 42, height: 42).homeCard(radius: 21)
        }
        .buttonStyle(CardPress())
        .accessibilityLabel(label)
    }

    private var tabs: some View {
        HStack(spacing: 6) {
            ForEach(Tab.allCases, id: \.self) { t in
                Button { withAnimation(.easeOut(duration: 0.18)) { tab = t } } label: {
                    Text(t.rawValue).font(.nunito(15, .heavy))
                        .foregroundStyle(tab == t ? .white : Home.ink)
                        .frame(maxWidth: .infinity).frame(height: 40)
                        .background(tab == t ? Home.teal : Color(UIColor(hex: 0xFFFDF8)), in: Capsule())
                        .overlay(Capsule().stroke(tab == t ? .clear : Home.line, lineWidth: 1))
                }
                .buttonStyle(CardPress())
                .accessibilityAddTraits(tab == t ? .isSelected : [])
            }
        }
        .padding(.horizontal, 18)
    }

    /// A row of colours to choose from, the chosen one ringed and ticked.
    private func section(_ title: String, swatches: [String], names: [String]? = nil, picked: Int, choose: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased()).font(.nunito(12, .black)).tracking(1.3).foregroundStyle(Home.teal).padding(.leading, 4)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(swatches.indices, id: \.self) { k in
                    let on = k == picked
                    Button { withAnimation(.easeOut(duration: 0.15)) { choose(k) } } label: {
                        VStack(spacing: 6) {
                            Circle().fill(Color(UIColor(hex: UInt32(swatches[k].replacingOccurrences(of: "#", with: ""), radix: 16) ?? 0)))
                                .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 1))
                                .frame(width: 44, height: 44)
                            if let n = names?[k] { Text(n).font(.nunito(12, .bold)).foregroundStyle(Home.muted) }
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .homeCard(radius: 16)
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(on ? Home.teal : .clear, lineWidth: 2.5))
                        .overlay(alignment: .topTrailing) {
                            if on {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 20)).foregroundStyle(.white, Home.teal).offset(x: 6, y: -6)
                            }
                        }
                    }
                    .buttonStyle(CardPress())
                    .accessibilityLabel(names?[k] ?? "\(title) \(k + 1)")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }
}
