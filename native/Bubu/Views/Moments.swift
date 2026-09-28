import SwiftUI
import Observation

/// The web's full-screen moments and toasts, queued so they come one at a time.
@Observable
final class Moments {
    static let shared = Moments()

    enum Moment: Equatable {
        case level(Int, next: Int)
        case chest(ember: Bool)
        case milestone(Int, ember: Bool)
        case relit(streak: Int, left: Int)
        case fireOut(lost: Int)
        case askRelight(lost: Int, embers: Int)
    }

    private(set) var current: Moment?
    private var queue: [Moment] = []
    private(set) var toastText: String?
    private var toastQueue: [String] = []
    /// A full-screen study session is up: moments show there, not under it.
    var studyUp = false

    private var switching = false
    func show(_ m: Moment) {
        if current == nil && !switching { present(m) } else { queue.append(m) }
    }

    private func present(_ m: Moment) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { current = m }
        switch m {
        case .level: Sounds.shared.play("levelup")
        case .chest: Sounds.shared.play("chest")
        case .milestone: Sounds.shared.play("milestone")
        case .relit: DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { Sounds.shared.play("relight") }
        default: break
        }
        // the goal and the chest go by themselves, as on the web
        let auto: Double? = { if case .chest = m { return 3.2 }; return nil }()
        if let auto {
            DispatchQueue.main.asyncAfter(deadline: .now() + auto) { [weak self] in
                if self?.current == m { self?.dismiss() }
            }
        }
    }

    func dismiss() {
        withAnimation(.easeOut(duration: 0.25)) { current = nil }
        if !queue.isEmpty {
            switching = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                guard let self else { return }
                self.switching = false
                if !self.queue.isEmpty { self.present(self.queue.removeFirst()) }
            }
        }
    }

    /// A gentle message along the bottom, a couple of seconds long.
    func toast(_ text: String) {
        if toastText == nil { presentToast(text) } else { toastQueue.append(text) }
    }
    private func presentToast(_ text: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { toastText = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { [weak self] in
            guard let self else { return }
            withAnimation(.easeOut(duration: 0.25)) { self.toastText = nil }
            if !self.toastQueue.isEmpty {
                let next = self.toastQueue.removeFirst()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.presentToast(next) }
            }
        }
    }
}

extension View {
    /// Shows moments and toasts over this screen. `study` marks the study cover's host.
    func momentsHost(study: Bool = false) -> some View { modifier(MomentsHost(study: study)) }
}

private struct MomentsHost: ViewModifier {
    let study: Bool
    @State private var moments = Moments.shared
    @Environment(ProgressStore.self) private var progress

    func body(content: Content) -> some View {
        let here = study == moments.studyUp
        content
            .overlay(alignment: .bottom) {
                if here, let t = moments.toastText {
                    Text(t).font(.nunito(15, .bold)).foregroundStyle(Color.bg).multilineTextAlignment(.center)
                        .padding(.horizontal, 18).padding(.vertical, 11)
                        .background(Color.ink.opacity(0.92), in: Capsule())
                        .padding(.horizontal, 24).padding(.bottom, study ? 110 : 96)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                if here, let m = moments.current {
                    MomentCard(moment: m, progress: progress) { moments.dismiss() }
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .zIndex(5)
                }
            }
            .onAppear { if study { moments.studyUp = true } }
            .onDisappear { if study { moments.studyUp = false } }
    }
}

/// One full-screen moment, as the web's .goal-burst cards.
struct MomentCard: View {
    let moment: Moments.Moment
    let progress: ProgressStore
    var close: () -> Void
    @State private var shown = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
                .onTapGesture { if tapToClose { close() } }
            VStack(spacing: 6) {
                content
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24).padding(.vertical, 26)
            .frame(maxWidth: 330)
            .background(Color.panel, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 30, y: 12)
            .scaleEffect(shown ? 1 : 0.85)
            .padding(24)
            if confettiCount > 0 { Confetti(count: confettiCount).allowsHitTesting(false) }
        }
        .onAppear { withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) { shown = true } }
        .sensoryFeedback(.success, trigger: shown) { _, n in n }
    }

    private var tapToClose: Bool {
        if case .chest = moment { return true }
        return false
    }

    private var confettiCount: Int {
        switch moment {
        case .level: return 100
        case .chest: return 80
        case .milestone: return 120
        case .relit: return 70
        default: return 0
        }
    }

    private func title(_ t: String) -> some View { Text(t).font(.nunitoXB(22)).foregroundStyle(Color.ink) }
    private func sub(_ t: String) -> some View { Text(t).font(.nunito(15.5, .semibold)).foregroundStyle(Color.muted) }
    private func big(_ n: Int, small: Bool = false) -> some View {
        Text("\(n)").font(.nunito(small ? 44 : 64, .black)).tracking(-1.5).foregroundStyle(Color.ink)
    }
    private func note(_ t: String) -> some View {
        Label(t, systemImage: "flame.fill").font(.nunito(14, .bold)).foregroundStyle(Color.gold)
            .padding(.horizontal, 12).padding(.vertical, 5).background(Color.accentSoft, in: Capsule())
            .padding(.top, 4)
    }
    private func button(_ t: String, ghost: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(t, action: action).buttonStyle(WideButton(ghost: ghost))
    }

    @ViewBuilder
    private var content: some View {
        switch moment {
        case .level(let lv, let next):
            Image(systemName: "crown.fill").font(.system(size: 46)).foregroundStyle(Color.gold)
            big(lv)
            title("Level \(lv)!")
            sub("\(next) XP to level \(lv + 1)")
            button("Nice", close).padding(.top, 10)
        case .chest(let ember):
            Image("done-panda").resizable().scaledToFit().frame(height: 150)
            title("All quests done!")
            sub("+20 XP from the chest")
            if ember { note("and an ember") }
        case .milestone(let s, let ember):
            FlameIcon(lit: true, size: 90)
            big(s)
            title("day streak!")
            sub(DoneView.milestoneWords[s] ?? "Keep the fire lit.")
            if ember { note("You earned an ember") }
            button("Keep going", close).padding(.top, 10)
        case .relit(let streak, let left):
            FlameIcon(lit: true, size: 90)
            title("Your ember kept the fire lit")
            big(streak, small: true)
            sub("day streak carries on")
            note("\(left) ember\(left == 1 ? "" : "s") left")
            button("Keep going", close).padding(.top, 10)
        case .fireOut(let lost):
            FlameIcon(lit: false, size: 90)
            title("Your fire went out")
            sub("\(lost)-day streak. No ember was left to relight it.")
            note("Reach 3 days to earn one")
            button("Start fresh", close).padding(.top, 10)
        case .askRelight(let lost, let n):
            FlameIcon(lit: false, size: 90)
            title("Your fire went out")
            sub("\(lost)-day streak. Use an ember to relight it?")
            note("You have \(n) ember\(n == 1 ? "" : "s")")
            button("Relight the fire") {
                close()
                if progress.relight() {
                    Sounds.shared.play("complete")
                    Moments.shared.toast("Relit! \(progress.streak)-day streak carries on.")
                }
            }
            .padding(.top, 10)
            button("Let it go", ghost: true, close)
        }
    }
}

/// A short burst of confetti, as the web's: thrown up from the middle, falling, fading.
struct Confetti: View {
    let count: Int
    @State private var start = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let colours: [Color] = [0xF0B429, 0xF0742F, 0x4CE1AD, 0x6C9DFC, 0xE39AAE, 0xFDE68A].map { Color(UIColor(hex: $0)) }

    private struct Bit { let x: CGFloat; let vx: CGFloat; let vy: CGFloat; let w: CGFloat; let h: CGFloat; let r: Double; let vr: Double; let c: Int }
    @State private var bits: [Bit] = []
    @State private var over = false

    var body: some View {
        if !reduceMotion && !over {
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSince(start)
                Canvas { ctx, size in
                    let k = t / 1.6
                    guard k < 1 else { return }
                    ctx.opacity = k > 0.75 ? max(0, 1 - (k - 0.75) / 0.25) : 1
                    let frames = CGFloat(t * 60)
                    for b in bits {
                        // the web's per-frame physics, summed: velocity with gravity 0.35 and drag 0.99
                        let drag = (1 - pow(0.99, frames)) / 0.01
                        let x = size.width / 2 + b.x * size.width + b.vx * drag
                        let y = size.height * 0.45 + b.vy * frames + 0.35 * frames * frames / 2
                        var c = ctx
                        c.translateBy(x: x, y: y)
                        c.rotate(by: .radians(b.r + b.vr * Double(frames)))
                        c.fill(Path(CGRect(x: -b.w / 2, y: -b.h / 2, width: b.w, height: b.h)), with: .color(Self.colours[b.c]))
                    }
                }
            }
            .ignoresSafeArea()
            .onAppear {
                bits = (0..<count).map { _ in
                    Bit(x: CGFloat.random(in: -0.25...0.25), vx: CGFloat.random(in: -7...7), vy: -8 - CGFloat.random(in: 0...9),
                        w: 5 + CGFloat.random(in: 0...6), h: 3 + CGFloat.random(in: 0...5),
                        r: Double.random(in: 0...6.28), vr: Double.random(in: -0.15...0.15), c: Int.random(in: 0..<6))
                }
                start = Date()
            }
            .task { try? await Task.sleep(for: .seconds(1.7)); over = true }
        }
    }
}
