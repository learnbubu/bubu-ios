import SwiftUI
import UIKit

/// Pieces shared by the screens in the Home look (the owner, 14 Oct 2026).

/// A back button big enough to hit: a chevron and where it goes, on a pill 40 pt tall.
struct BackPill: View {
    let label: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left").font(.system(size: 14, weight: .heavy))
                Text(label).font(.nunito(15, .black))
            }
            .foregroundStyle(Home.teal)
            .padding(.leading, 12).padding(.trailing, 16).frame(height: 40)
            .background(Color(UIColor(hex: 0xFFFDF8)), in: Capsule())
            .overlay(Capsule().stroke(Home.line, lineWidth: 1.5))
            .contentShape(Capsule())
        }
        .buttonStyle(CardPress())
        .accessibilityLabel("Back to \(label)")
    }
}

/// A raised button: the face on a darker lip, the face sinking onto the lip while pressed;
/// nothing around it moves.
struct LipButton: ButtonStyle {
    var face: Color
    var lip: Color
    var radius: CGFloat = 16
    var depth: CGFloat = 4
    func makeBody(configuration: Configuration) -> some View {
        let down = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return configuration.label
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(face, in: shape)
            .offset(y: down ? depth : 0)
            .padding(.bottom, depth)
            .background(shape.fill(lip).padding(.top, depth))
            .contentShape(shape)
            .animation(.spring(response: 0.16, dampingFraction: 0.7), value: down)
            .sensoryFeedback(.impact(weight: .light), trigger: down)
    }
}

/// A card that's tapped: it dips a little and dims, in place (it's not a button with a lip).
struct CardPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

/// A card in the Home look: off-white on the cream page, a soft line round it.
extension View {
    func homeCard(radius: CGFloat = 18) -> some View {
        background(Color(UIColor(hex: 0xFFFDF8)), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Home.line, lineWidth: 1.5))
    }
}

/// Swipe from the left edge to go back, on the pages that hide the navigation bar for their own
/// back button (hiding the bar switches the swipe off; the owner, 14 Oct 2026).
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
