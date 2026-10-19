import SwiftUI

/// Your avatar, to dress: him on his disc, alive and as big as on Profile, and below him two tabs (as Duolingo's):
/// Outfits, a tile each (head and shoulders, in your colours), and Avatar, a row of icons for what's yours whatever
/// you wear (skin, hair, the clothes' colours where the outfit has them, the disc). Changes show on him at once; Save
/// look hands the look straight back (so Profile wears it as the editor goes), back leaves it.
struct AvatarEditor: View {
    /// the look saved (nil: left as it was)
    var close: (AvatarLook?) -> Void
    @State private var look = AvatarLook.load()
    @State private var tab = Tab.outfits
    @State private var part = Part.skin

    enum Tab: String, CaseIterable { case outfits = "Outfits", avatar = "Avatar" }
    enum Part: CaseIterable {
        case skin, hair, clothes, backdrop
        var icon: String {
            switch self {
            case .skin: return "face.smiling"
            case .hair: return "scissors"
            case .clothes: return "tshirt"
            case .backdrop: return "paintpalette"
            }
        }
        var label: String {
            switch self {
            case .skin: return "Skin"
            case .hair: return "Hair"
            case .clothes: return "Clothes colours"
            case .backdrop: return "Background"
            }
        }
        /// its colours: the rig's, by name (Studio's), with what to call them here
        var groups: [(title: String, channel: String)] {
            switch self {
            case .skin: return [("Skin", "Skin")]
            case .hair: return [("Hair colour", "Hair colour")]
            case .clothes: return [("Sweater", "Sweater colour"), ("Trousers", "Trousers colour")]
            case .backdrop: return []
            }
        }
    }

    private var rig: AvatarRig? { AvatarRig.load(look.outfit) }
    /// whether the outfit has any of this part's colours (a costume has no sweater to colour)
    private func has(_ p: Part) -> Bool {
        p == .backdrop || p.groups.contains { g in rig?.channels?.contains { $0.name == g.channel } ?? false }
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            ZStack {
                AvatarBackdrop(hex: look.backdrop).frame(width: 290, height: 290)
                AvatarFigure(outfit: look.outfit, look: look.colours, size: 316)
            }
            .frame(width: 316, height: 316)
            tabs
            if tab == .avatar { parts }
            ScrollView {
                Group {
                    if tab == .outfits { outfits } else { colours }
                }
                .padding(.horizontal, 18).padding(.top, 4).padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
            Button("Save look") { look.save(); close(look) }
                .buttonStyle(WideButton())
                .padding(.horizontal, 18).padding(.bottom, 8)
        }
        .background(Home.bg.ignoresSafeArea())
        .environment(\.colorScheme, .light)
        .sensoryFeedback(.selection, trigger: look)
    }

    private var header: some View {
        HStack {
            round("chevron.left", label: "Back") { close(nil) }
            Spacer()
            Text(Outfit.named(look.outfit).name).font(.nunito(18, .black)).foregroundStyle(Home.ink)
                .contentTransition(.opacity).animation(.easeOut(duration: 0.15), value: look.outfit)
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

    /// Outfits | Avatar, underlined
    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { t in
                Button { withAnimation(.easeOut(duration: 0.18)) { tab = t } } label: {
                    Text(t.rawValue.uppercased()).font(.nunito(15, .black)).tracking(1.4)
                        .foregroundStyle(tab == t ? Home.teal : Home.muted)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .overlay(alignment: .bottom) {
                            Capsule().fill(tab == t ? Home.teal : .clear).frame(height: 3).padding(.horizontal, 34).offset(y: 1.5)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(tab == t ? .isSelected : [])
            }
        }
        .background(alignment: .bottom) { Rectangle().fill(Home.line).frame(height: 1.5) }
        .padding(.horizontal, 18)
    }

    /// the Avatar tab's icons, underlined as the tabs are (one the outfit has no colours for greys out)
    private var parts: some View {
        HStack(spacing: 0) {
            ForEach(Part.allCases, id: \.self) { p in
                let on = part == p, can = has(p)
                Button { withAnimation(.easeOut(duration: 0.15)) { part = p } } label: {
                    Image(systemName: p.icon).font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(on ? Home.teal : Home.muted)
                        .frame(maxWidth: .infinity).frame(height: 46)
                        .overlay(alignment: .bottom) {
                            Capsule().fill(on ? Home.teal : .clear).frame(height: 3).padding(.horizontal, 22).offset(y: 1.5)
                        }
                }
                .buttonStyle(.plain)
                .disabled(!can).opacity(can ? 1 : 0.35)
                .accessibilityLabel(p.label)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .background(alignment: .bottom) { Rectangle().fill(Home.line).frame(height: 1.5) }
        .padding(.horizontal, 18)
        .onChange(of: look.outfit) { _, _ in if !has(part) { part = .skin } }
    }

    // MARK: outfits: three a row, head and shoulders, the name under; the one worn ringed

    private var outfits: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 14) {
            ForEach(Outfit.all) { o in
                let on = look.outfit == o.id
                Button { withAnimation(.easeOut(duration: 0.15)) { look.outfit = o.id } } label: {
                    VStack(spacing: 6) {
                        AvatarStage(name: o.id, look: look.colours, box: AvatarRig.tileBox, still: true)
                            .aspectRatio(1, contentMode: .fit)
                            .background(Color(UIColor(hex: 0xFFFDF8)))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(on ? Home.teal : Home.line, lineWidth: on ? 3 : 1.5))
                        Text(o.name).font(.nunito(14, on ? .black : .heavy)).foregroundStyle(on ? Home.teal : Home.muted).lineLimit(1).minimumScaleFactor(0.8)
                    }
                }
                .buttonStyle(CardPress())
                .accessibilityLabel(o.name)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    // MARK: the Avatar tab: the chosen icon's colours

    private var colours: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(part.groups.indices, id: \.self) { n in
                if let c = rig?.channels?.first(where: { $0.name == part.groups[n].channel }) {
                    section(part.groups[n].title, swatches: c.swatches, picked: look.colours[c.name] ?? 0) { look.colours[c.name] = $0 }
                }
            }
            if part == .backdrop {
                section("Background", swatches: AvatarBackdrop.colours.map { $0.hex }, names: AvatarBackdrop.colours.map { $0.name },
                        picked: AvatarBackdrop.colours.firstIndex { $0.hex == look.backdrop } ?? 0) { look.backdrop = AvatarBackdrop.colours[$0].hex }
            }
        }
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
