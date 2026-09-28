import SwiftUI

// Coins, buns and pockets on screen: the coin, the buns, the shop, the buns sheet,
// Bùbù Plus and the pockets that open (web: "Coins, buns and red pockets").

extension Color {
    static let ember = Color(UIColor(hex: 0xE8672A))
    static let bunBrown = Color(UIColor(hex: 0xB98540))
}

/// The coin: a gold cash coin with a square hole (web: images/rewards/coin.webp).
struct CoinIcon: View {
    var size: CGFloat = 20
    var body: some View {
        Image("coin").resizable().scaledToFit().frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// A bun (包子); a lost one is faded and grey.
struct BunIcon: View {
    var width: CGFloat = 24
    var gone = false
    var body: some View {
        Image("bun").resizable().scaledToFit().frame(width: width)
            .grayscale(gone ? 1 : 0).brightness(gone ? -0.05 : 0).contrast(gone ? 0.8 : 1)
            .opacity(gone ? 0.38 : 1)
            .accessibilityHidden(true)
    }
}

/// The five buns beside a lesson's progress bar (web: .bun-row); Plus shows one and ∞.
/// `bump` counts buns earned back: the newest one pops in.
struct BunRow: View {
    let n: Int
    let plus: Bool
    var bump = 0
    var body: some View {
        HStack(spacing: 1) {
            if plus {
                BunIcon(width: 21)
                Text("∞").font(.nunito(16, .black)).foregroundStyle(Color.bunBrown).padding(.leading, 3)
            } else {
                ForEach(0..<ProgressStore.bunsMax, id: \.self) { i in
                    BunIcon(width: 21, gone: i >= n)
                        .keyframeAnimator(initialValue: 1.0, trigger: i == n - 1 ? bump : 0) { v, s in
                            v.scaleEffect(s)
                        } keyframes: { _ in
                            KeyframeTrack {
                                LinearKeyframe(0.4, duration: 0.01)
                                CubicKeyframe(1.35, duration: 0.3)
                                CubicKeyframe(1, duration: 0.2)
                            }
                        }
                }
            }
        }
        .padding(.vertical, -6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(plus ? "Unlimited buns" : "\(n) buns")
    }
}

/// A mistake in a lesson: the bitten bun pops up in the middle, wobbles, then
/// flies into the bun row (web: munchBun).
struct Munch: View {
    let from: CGPoint
    let to: CGPoint
    private struct Phase { var scale = 0.0; var angle = -10.0; var t = 0.0; var opacity = 1.0 }

    var body: some View {
        VStack(spacing: -6) {
            Image("bun-bitten").resizable().scaledToFit().frame(width: 130)
            Text("−1 包子").font(.nunito(14, .black)).foregroundStyle(Color.again)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(Color.panel, in: Capsule())
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
        }
        .keyframeAnimator(initialValue: Phase(), repeating: false) { v, s in
            v.scaleEffect(s.scale)
                .rotationEffect(.degrees(s.angle))
                .opacity(s.opacity)
                .position(x: from.x + (to.x - from.x) * s.t, y: from.y + (to.y - from.y) * s.t)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                CubicKeyframe(1.1, duration: 0.29)
                CubicKeyframe(0.94, duration: 0.13)
                CubicKeyframe(1.02, duration: 0.13)
                CubicKeyframe(1, duration: 0.57)
                CubicKeyframe(0.15, duration: 0.48)
            }
            KeyframeTrack(\.angle) {
                CubicKeyframe(4, duration: 0.29)
                CubicKeyframe(-3, duration: 0.13)
                CubicKeyframe(0, duration: 0.13)
            }
            KeyframeTrack(\.t) {
                LinearKeyframe(0, duration: 1.12)
                CubicKeyframe(1, duration: 0.48)
            }
            KeyframeTrack(\.opacity) {
                LinearKeyframe(1, duration: 1.12)
                LinearKeyframe(0, duration: 0.48)
            }
        }
        .allowsHitTesting(false)
    }
}

// the Bùbù Plus row's green (a generic view can't hold these as its own statics)
private let plusFill = LinearGradient(colors: [Color(UIColor(hex: 0x1D6B5C)), Color(UIColor(hex: 0x2B776D))],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)
private let plusLine = Color(UIColor(hex: 0x16564A))

/// One row of the shop and the buns sheet (web: .shop-item). `plus` is the green Bùbù Plus row.
struct ShopRow<Icon: View>: View {
    let title: String
    let sub: String
    var tag: String? = nil
    var price: Int? = nil
    var plus = false
    var disabled = false
    let action: () -> Void
    let icon: Icon

    init(_ title: String, sub: String, tag: String? = nil, price: Int? = nil, plus: Bool = false, disabled: Bool = false,
         action: @escaping () -> Void, @ViewBuilder icon: () -> Icon) {
        self.title = title; self.sub = sub; self.tag = tag; self.price = price
        self.plus = plus; self.disabled = disabled; self.action = action; self.icon = icon()
    }

    var body: some View {
        let border = plus ? plusLine : Color.line
        Button(action: action) {
            HStack(spacing: 12) {
                icon.font(.nunito(22, .black)).foregroundStyle(plus ? Color.white : Color.accent)
                    .frame(width: 38)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(title).font(.nunito(15.2, .black))
                        if let tag {
                            Text(tag).font(.nunito(10, .black)).foregroundStyle(Color.accent)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Color.accentSoft, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }
                    Text(sub).font(.nunito(12.8, .bold))
                        .foregroundStyle(plus ? Color(UIColor(hex: 0xCFE9E1)) : Color.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if let price {
                    HStack(spacing: 4) {
                        CoinIcon(size: 18)
                        Text("\(price)").monospacedDigit()
                    }
                    .font(.nunito(15, .black)).foregroundStyle(Color.gold)
                }
            }
            .foregroundStyle(plus ? Color.white : Color.ink)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(border).offset(y: 2)
                    if plus { RoundedRectangle(cornerRadius: 16, style: .continuous).fill(plusFill) }
                    else { RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.panel) }
                    RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(border, lineWidth: 2)
                }
            }
            .padding(.bottom, 2)
        }
        .buttonStyle(PressDown(depth: 2))
        .disabled(disabled)
        .opacity(disabled ? 0.55 : 1)
    }
}

private func cardTitle(_ t: String) -> some View { Text(t).font(.nunitoXB(22)).foregroundStyle(Color.ink) }
private func cardSub(_ t: String) -> some View {
    Text(t).font(.nunito(15.5, .semibold)).foregroundStyle(Color.muted).fixedSize(horizontal: false, vertical: true)
}

/// Out of buns, or a look at them from the top bar (web: showBuns).
struct BunsCard: View {
    let sheet: Moments.BunsSheet
    let progress: ProgressStore
    var close: () -> Void

    var body: some View {
        let s = progress.bunState, plus = progress.isPlus, n = progress.buns, empty = n < 1
        let mid = sheet.ctx == .mid, full = ProgressStore.bunsMax
        let title = plus ? "Unlimited buns" : mid ? "Bùbù ate all your buns!" : empty ? "No buns left" : "\(n) bun\(n == 1 ? "" : "s")"
        let sub = plus ? "With Plus, mistakes never cost a bun."
            : mid ? "Your progress in this lesson is saved. Here's how to get more:"
            : empty ? "You need a bun to start a new lesson. Here's how to get more:"
            : "Each mistake in a new lesson eats one. Reviews and practice never do."
        VStack(spacing: 6) {
            Image(empty && !plus ? "panda-sad" : "sprite-baozi").resizable().scaledToFit().frame(height: 118)
            cardTitle(title)
            cardSub(sub)
            if !plus {
                HStack(spacing: 4) {
                    ForEach(0..<full, id: \.self) { i in BunIcon(width: 34, gone: i >= s.n) }
                }
                .padding(.top, 8)
                VStack(spacing: 8) {
                    ShopRow("Review to earn buns", sub: "+1 for each right answer, up to \(full)", action: review) {
                        Image(systemName: "rectangle.stack.fill").font(.system(size: 21, weight: .semibold))
                    }
                    ShopRow("Steam a fresh batch", sub: "Refill all \(full) buns", price: ProgressStore.ShopItem.buns.price,
                            disabled: s.n >= full, action: buy) {
                        Image("bun").resizable().scaledToFit().frame(width: 36, height: 31)
                    }
                    ShopRow("Unlimited buns", sub: "With Bùbù Plus, never run out", plus: true,
                            action: { Moments.shared.replace(with: .plus) }) {
                        Text("∞")
                    }
                }
                .padding(.top, 12)
                if s.next > 0 && s.n < full {
                    Text("Next bun in \(ProgressStore.waitText(s.next))").font(.nunito(13.6, .bold)).foregroundStyle(Color.muted)
                        .padding(.top, 8)
                }
            }
            Button(mid ? "End the lesson" : "Close") {
                close()
                if mid { sheet.end?() }
            }
            .buttonStyle(WideButton(ghost: true))
            .padding(.top, 8)
        }
    }

    private func review() {
        close()
        if progress.dueCount == 0 && progress.srs.isEmpty {
            Moments.shared.toast("Nothing to review yet.")
            if sheet.ctx == .mid { sheet.end?() }
            return
        }
        if let r = sheet.review { r() } else { Moments.shared.launch?(StudySession.review(progress)) }
    }

    private func buy() {
        let price = ProgressStore.ShopItem.buns.price
        guard progress.buy(.buns) else {
            Moments.shared.toast("You need \(price - progress.coins) more coins. Red pockets from lessons hold them.")
            return
        }
        Sounds.shared.play("chest")
        close()
        Moments.shared.toast("A fresh batch of buns!")
        sheet.refilled?()
    }
}

/// Bùbù Plus isn't on sale yet: this says what it will be (web: showPlus).
struct PlusCard: View {
    var close: () -> Void
    var body: some View {
        VStack(spacing: 6) {
            Image("done-panda").resizable().scaledToFit().frame(height: 118)
            cardTitle("Bùbù Plus")
            VStack(alignment: .leading, spacing: 10) {
                perk("Unlimited buns: mistakes never stop a lesson") {
                    Text("∞").font(.nunito(20, .black)).foregroundStyle(Color.accent)
                }
                perk("A red pocket for every lesson, not just the first each day") { CoinIcon(size: 20) }
                perk("Hold up to 3 embers, and buy more in the shop") {
                    Image(systemName: "flame.fill").font(.system(size: 17)).foregroundStyle(Color.ember)
                }
            }
            .multilineTextAlignment(.leading)
            .padding(.top, 10)
            Text("Coming soon").font(.nunito(14, .bold)).foregroundStyle(Color.gold)
                .padding(.horizontal, 12).padding(.vertical, 5).background(Color.accentSoft, in: Capsule())
                .padding(.top, 10)
            Button("OK", action: close).buttonStyle(WideButton()).padding(.top, 10)
        }
    }

    private func perk<I: View>(_ t: String, @ViewBuilder icon: () -> I) -> some View {
        HStack(spacing: 10) {
            icon().frame(width: 24)
            Text(t).font(.nunito(14.7, .bold)).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

/// The shop: what coins buy (web: openShop).
struct ShopCard: View {
    let progress: ProgressStore
    var close: () -> Void

    var body: some View {
        let s = progress.bunState, plus = progress.isPlus, full = ProgressStore.bunsMax
        let ne = progress.embers, cap = progress.emberCap, boost = progress.boostActive
        VStack(spacing: 6) {
            HStack {
                cardTitle("Shop")
                Spacer()
                HStack(spacing: 6) {
                    CoinIcon(size: 20)
                    Text("\(progress.coins)").monospacedDigit()
                }
                .font(.nunito(16, .black)).foregroundStyle(Color.gold)
                .padding(.leading, 6).padding(.trailing, 12).padding(.vertical, 4)
                .background(Color.accentSoft, in: Capsule())
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    section("Buns")
                    ShopRow("Fresh batch", sub: plus ? "Unlimited with Plus" : s.n >= full ? "Your buns are full" : "Refill to \(full) buns · you have \(s.n)",
                            price: ProgressStore.ShopItem.buns.price, disabled: plus || s.n >= full,
                            action: { buy(.buns, "A fresh batch of buns!") }) {
                        BunIcon(width: 36)
                    }
                    section("Streak")
                    ShopRow("Ember", sub: plus ? "Relights a missed day · you have \(ne) of \(cap)" : "Relights a missed day. Plus members only",
                            tag: "PLUS", price: ProgressStore.ShopItem.ember.price, disabled: plus && ne >= cap,
                            action: { buy(.ember, "An ember, ready to relight a missed day.") }) {
                        Image(systemName: "flame.fill").font(.system(size: 22)).foregroundStyle(Color.ember)
                    }
                    section("Boosts")
                    ShopRow("Double XP", sub: boost ? "Double XP is on now" : "For the next 15 minutes",
                            price: ProgressStore.ShopItem.boost.price, disabled: boost,
                            action: { buy(.boost, "Double XP for 15 minutes!") }) {
                        Text("2×")
                    }
                    section("Wardrobe")
                    ShopRow("Avatar items", sub: "Hats, bags and more, coming soon", disabled: true, action: {}) {
                        Image(systemName: "person.fill").font(.system(size: 21))
                    }
                    if !plus {
                        ShopRow("Bùbù Plus", sub: "Unlimited buns, more pockets, embers", plus: true,
                                action: { Moments.shared.replace(with: .plus) }) {
                            Text("∞")
                        }
                    }
                }
                .padding(.bottom, 2)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: UIScreen.main.bounds.height * 0.6)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 6)
            Button("Close", action: close).buttonStyle(WideButton(ghost: true)).padding(.top, 6)
        }
    }

    private func section(_ t: String) -> some View {
        Text(t.uppercased()).font(.nunito(11.5, .black)).tracking(0.9).foregroundStyle(Color.muted)
            .padding(.horizontal, 2).padding(.top, 6).padding(.bottom, -2)
    }

    private func buy(_ item: ProgressStore.ShopItem, _ done: String) {
        // an ember is for Plus members: everyone else hears about Plus
        if item == .ember && !progress.isPlus { Moments.shared.replace(with: .plus); return }
        guard progress.buy(item) else {
            Moments.shared.toast("You need \(item.price - progress.coins) more coins.")
            return
        }
        Moments.shared.toast(done)
        Sounds.shared.play("chest")
        close()
    }
}

/// A pocket to tap open (web: showPocket): it wiggles until tapped, then pops, the
/// reward rises out of it and, from a red one, coins burst out.
struct PocketCard: View {
    let pocket: Moments.Pocket
    var opened: () -> Void
    var close: () -> Void
    @State private var open = false
    @State private var amountIn = false
    private struct Fly { var t = 0.0; var o = 0.0 }

    var body: some View {
        let red = pocket.kind == .red
        VStack(spacing: 6) {
            cardTitle(pocket.title)
            cardSub(pocket.sub)
            Button { openIt() } label: {
                ZStack {
                    Image("pocket-\(pocket.kind.rawValue)").resizable().scaledToFit().frame(width: 170)
                        .shadow(color: (red ? Color(UIColor(hex: 0x781E14)) : Color(UIColor(hex: 0x14503C))).opacity(0.28), radius: 10, y: 12)
                        .keyframeAnimator(initialValue: 0.0, repeating: true) { v, a in
                            v.rotationEffect(.degrees(a), anchor: UnitPoint(x: 0.5, y: 0.9))
                        } keyframes: { _ in
                            KeyframeTrack {
                                LinearKeyframe(0, duration: 1.68)
                                CubicKeyframe(-4, duration: 0.144)
                                CubicKeyframe(4, duration: 0.144)
                                CubicKeyframe(-2, duration: 0.144)
                                CubicKeyframe(1, duration: 0.144)
                                CubicKeyframe(0, duration: 0.144)
                            }
                        }
                        .scaleEffect(open ? 0.01 : 1)
                        .opacity(open ? 0 : 1)
                    if amountIn {
                        HStack(spacing: 8) {
                            if red { CoinIcon(size: 36) }
                            Text(red ? "+\(pocket.reward)" : "+\(pocket.reward) XP").monospacedDigit()
                        }
                        .font(.nunito(38, .black)).foregroundStyle(red ? Color.gold : Color.accent)
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                    }
                    if red {
                        ForEach(0..<10, id: \.self) { i in
                            let a = Double(i) / 10 * 2 * .pi
                            CoinIcon(size: 20)
                                .keyframeAnimator(initialValue: Fly(), trigger: open) { v, f in
                                    v.scaleEffect(0.5 + 0.5 * f.t)
                                        .offset(x: cos(a) * 120 * f.t, y: sin(a) * 120 * f.t)
                                        .opacity(f.o)
                                } keyframes: { _ in
                                    KeyframeTrack(\.t) {
                                        LinearKeyframe(0, duration: 0.01)
                                        CubicKeyframe(1, duration: 1)
                                    }
                                    KeyframeTrack(\.o) {
                                        LinearKeyframe(1, duration: 0.01)
                                        LinearKeyframe(0, duration: 1)
                                    }
                                }
                                .allowsHitTesting(false)
                        }
                    }
                }
                .padding(.top, 10).padding(.bottom, 4)
            }
            // not disabled once open: a disabled button fades its label, and the reward is in it
            .buttonStyle(.plain)
            .accessibilityLabel("Open the pocket")
            Text(open ? (red ? "coins" : "good luck!") : "Tap to open").font(.nunito(13.6, .heavy)).foregroundStyle(Color.muted)
            Button("Nice", action: close).buttonStyle(WideButton()).padding(.top, 10)
                .opacity(open ? 1 : 0).disabled(!open)
        }
        .sensoryFeedback(.success, trigger: open)
        .onAppear {
            #if DEBUG
            if Launch.screen == "pocket" { DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { openIt() } }
            #endif
        }
    }

    private func openIt() {
        guard !open else { return }
        withAnimation(.easeOut(duration: 0.5)) { open = true }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.55).delay(0.35)) { amountIn = true }
        Sounds.shared.play("chest")
        opened()
    }
}
