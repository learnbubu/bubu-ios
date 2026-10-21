import SwiftUI
import AVFoundation

/// A hongbao (红包) to open, full screen, as Bùbù Studio's Hongbao (the owner, 20-21 Oct 2026): it waits, bobbing,
/// under 红包; a tap opens it (a squash and a pop, the flap open, light and coins out of it), the dark comes down
/// from the top as it drops away, and the prize lands, a coin rain behind it, the words drawn here over it.
///
/// The pictures are three videos from Studio, played one after another: the waiting loop, the opening (once), and
/// the prize's hold loop, whose first frame is the opening's last. A little money (a lesson, a chapter) lands as a
/// small stack; a milestone's lands as the big heap.
struct HongbaoScreen: View {
    let pocket: Moments.Pocket
    /// the coins come out (once, as it opens)
    var opened: () -> Void = {}
    var close: () -> Void

    @State private var phase = Phase.waiting
    @State private var words = 0          // how many of the prize's words are in: greeting, amount, reason, button
    @State private var players = HongbaoPlayers()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Phase { case waiting, opening, prize }

    private var big: Bool { pocket.milestone }
    /// from the tap to the prize landing (the opening's own timing: Studio's Prize starts 2.75 s into Hongbao, 1 s
    /// of it the wait; the small stack lands 380 ms in, the big heap 320)
    private var landsAt: Double { big ? 2.07 : 2.13 }

    var body: some View {
        GeometryReader { g in
            let h = g.size.height
            ZStack {
                Color(UIColor(hex: 0xC02C22))
                HongbaoVideo(players: players).allowsHitTesting(false)

                // waiting: 红包 over it, "Tap to open!" under
                VStack(spacing: -12) {
                    Text("红包").font(.hanzi(64, .heavy)).tracking(14).padding(.leading, 14)
                    Text("Red envelope").font(.nunito(16, .heavy)).opacity(0.85)
                }
                .foregroundStyle(Color(UIColor(hex: 0xFFD98A)))
                .modifier(LetterSheen(on: phase == .waiting))
                .shadow(color: .black.opacity(0.2), radius: 0, y: 2)
                .position(x: g.size.width / 2, y: h * 0.131 + 60)
                .opacity(phase == .waiting ? 1 : 0)
                Text("Tap to open!").font(.nunito(17, .black)).foregroundStyle(.white)
                    .phaseAnimator([1.0, 0.55]) { v, a in v.opacity(phase == .waiting ? a : 0) } animation: { _ in .easeInOut(duration: 0.8) }
                    .position(x: g.size.width / 2, y: h * (1 - 0.128) - 10)

                // the prize: the greeting at the top, what you got and why under the pile
                Group {
                    VStack(spacing: 6) {
                        Text("恭喜发财").font(.hanzi(46, .heavy)).tracking(9).padding(.leading, 9)
                            .foregroundStyle(Color(UIColor(hex: 0xFFD98A)))
                        Text("Wishing you good fortune!").font(.nunito(17, .heavy)).foregroundStyle(Color(UIColor(hex: 0xF2D1A8)))
                    }
                    .position(x: g.size.width / 2, y: h * 0.192 + 38)
                    .modifier(WordIn(on: words >= 1))
                    Text("You got \(pocket.reward) coins!").font(.nunito(24, .black)).foregroundStyle(.white)
                        .position(x: g.size.width / 2, y: h * (big ? 0.599 : 0.579) + 14)
                        .modifier(WordIn(on: words >= 2, pop: true))
                    Text(pocket.sub).font(.nunito(15.5, .bold)).foregroundStyle(Color(UIColor(hex: 0xE9C9AE)))
                        .multilineTextAlignment(.center).padding(.horizontal, 30)
                        .position(x: g.size.width / 2, y: h * (big ? 0.642 : 0.623) + 12)
                        .modifier(WordIn(on: words >= 3))
                }
                VStack {
                    Spacer()
                    Button("Continue", action: close).buttonStyle(RaisedButton(fill: .white, ink: Color(UIColor(hex: 0xC0392B)), edge: nil))
                        .padding(.horizontal, 18).padding(.bottom, 30)
                        .opacity(words >= 4 ? 1 : 0).offset(y: words >= 4 ? 0 : 30)
                        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: words)
                        .disabled(words < 4)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { if phase == .waiting { open() } }
        }
        .ignoresSafeArea()
        .onAppear {
            players.start(big: big)
            #if DEBUG
            // the screenshots open it by themselves
            if ["pocket", "hongbaobig"].contains(Launch.screen ?? "") { DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { if phase == .waiting { open() } } }
            #endif
        }
        .onDisappear { players.stop() }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Open the hongbao") { if phase == .waiting { open() } }
    }

    private func open() {
        phase = .opening
        players.open { phase = .prize }
        Sounds.shared.play("chest")
        opened()
        // the words as it lands: the greeting, the amount, the reason, then the button
        let land = reduceMotion ? 0.3 : landsAt
        for (i, d) in [0.06, 0.24, 0.42, 0.7].enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + land + d) { withAnimation(.easeOut(duration: 0.4)) { words = i + 1 } }
        }
    }
}

/// The lessons' sheen (IdleSweep's two crisp streaks at 27°) across the words themselves, every few seconds: the
/// light only where the letters are (the owner, 21 Oct 2026: on the 红包 heading, not the pocket).
private struct LetterSheen: ViewModifier {
    var on: Bool
    @State private var sweep: CGFloat = -1
    @State private var shining = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var streak: some View {
        LinearGradient(stops: [.init(color: .white.opacity(0), location: 0), .init(color: .white, location: 0.35),
                               .init(color: .white, location: 0.65), .init(color: .white.opacity(0), location: 1)],
                       startPoint: .leading, endPoint: .trailing)
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { g in
                    let band = max(30, g.size.width * 0.32)
                    HStack(spacing: band * 0.03) {
                        streak.frame(width: band * 0.34)
                        streak.frame(width: band * 0.30)
                    }
                    .frame(width: band, height: g.size.height * 3)
                    .opacity(0.85)
                    .rotationEffect(.degrees(27))
                    .frame(height: g.size.height)
                    .offset(x: -band * 1.4 + (sweep + 1) / 2 * (g.size.width + band * 1.8))
                    .frame(width: g.size.width, height: g.size.height, alignment: .leading)
                }
                .opacity(shining ? 1 : 0)
                .mask(content)
                .allowsHitTesting(false)
            }
            .task(id: on) {
                guard on, !reduceMotion else { return }
                try? await Task.sleep(for: .seconds(0.8))
                while !Task.isCancelled {
                    sweep = -1; shining = true
                    withAnimation(.linear(duration: 0.8)) { sweep = 1 }
                    try? await Task.sleep(for: .seconds(0.85))
                    shining = false
                    try? await Task.sleep(for: .seconds(2.8))
                }
            }
    }
}

/// A word coming in: up a little and in (the amount pops).
private struct WordIn: ViewModifier {
    let on: Bool
    var pop = false
    func body(content: Content) -> some View {
        content.opacity(on ? 1 : 0)
            .scaleEffect(pop ? (on ? 1 : 0.85) : 1)
            .offset(y: pop || on ? 0 : 10)
            .animation(pop ? .spring(response: 0.35, dampingFraction: 0.6) : .easeOut(duration: 0.4), value: on)
    }
}

/// The three videos, each its own player and layer stacked in one view, so the hand-over from one to the next is a
/// frame-exact swap: the next is shown only once it's on screen, the last frame of the one before still under it.
@MainActor
final class HongbaoPlayers {
    let wait = AVQueuePlayer(), opening = AVPlayer(), hold = AVQueuePlayer()
    private var waitLoop: AVPlayerLooper?, holdLoop: AVPlayerLooper?
    private var ended: NSObjectProtocol?
    var show: (_ which: Int) -> Void = { _ in }       // 0 waiting, 1 opening, 2 hold

    private static func item(_ name: String) -> AVPlayerItem? {
        Bundle.main.url(forResource: name, withExtension: "mp4").map { AVPlayerItem(url: $0) }
    }

    func start(big: Bool) {
        for p in [wait, opening, hold] as [AVPlayer] { p.isMuted = true; p.preventsDisplaySleepDuringVideoPlayback = false }
        if let w = Self.item("hongbao-wait") { waitLoop = AVPlayerLooper(player: wait, templateItem: w) }
        if let o = Self.item(big ? "hongbao-open-big" : "hongbao-open") { opening.replaceCurrentItem(with: o) }
        if let h = Self.item(big ? "hongbao-hold-big" : "hongbao-hold") { holdLoop = AVPlayerLooper(player: hold, templateItem: h) }
        hold.pause()
        opening.pause()
        wait.play()
        show(0)
    }

    func open(prize: @escaping () -> Void) {
        opening.seek(to: .zero)
        opening.play()
        show(1)
        ended = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: opening.currentItem, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.hold.play()
                self.show(2)
                self.wait.pause()
                prize()
            }
        }
    }

    func stop() {
        for p in [wait, opening, hold] as [AVPlayer] { p.pause() }
        if let e = ended { NotificationCenter.default.removeObserver(e) }
        waitLoop = nil; holdLoop = nil
    }
}

/// The players' layers, filling the screen (the videos are made the phone's shape).
private struct HongbaoVideo: UIViewRepresentable {
    let players: HongbaoPlayers

    final class Stack: UIView {
        let layers: [AVPlayerLayer]
        init(_ p: HongbaoPlayers) {
            layers = [p.wait, p.opening, p.hold].map { AVPlayerLayer(player: $0) }
            super.init(frame: .zero)
            backgroundColor = UIColor(hex: 0xC02C22)
            for l in layers { l.videoGravity = .resizeAspectFill; l.isHidden = true; layer.addSublayer(l) }
            layers[0].isHidden = false
        }
        required init?(coder: NSCoder) { fatalError() }
        override func layoutSubviews() {
            super.layoutSubviews()
            CATransaction.begin(); CATransaction.setDisableActions(true)
            for l in layers { l.frame = bounds }
            CATransaction.commit()
        }
        /// show `i` once its first frame is up, then hide the rest (no flash of nothing between)
        func show(_ i: Int) {
            let l = layers[i]
            l.isHidden = false
            layer.insertSublayer(l, at: UInt32(layers.count))      // on top
            func hideRest() { for (j, o) in layers.enumerated() where j != i { o.isHidden = true } }
            if l.isReadyForDisplay { DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { hideRest() } }
            else {
                var tries = 0
                func wait() { tries += 1; if l.isReadyForDisplay || tries > 40 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { hideRest() } } else { DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) { wait() } } }
                wait()
            }
        }
    }

    func makeUIView(context: Context) -> Stack {
        let v = Stack(players)
        players.show = { [weak v] i in v?.show(i) }
        return v
    }
    func updateUIView(_ v: Stack, context: Context) {}
}
