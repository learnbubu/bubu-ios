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

/// A page's top in the app's own look, in place of the system's navigation bar and its grey glass buttons (the owner,
/// 23 Oct 2026: "doesn't fit our theme ... do a sweep and match our style"): a round back button as BackPill is drawn,
/// the page's name in the middle, and on the right a count or a button as a small pill of the same kind. Day and night.
struct PageBar<Trailing: View>: View {
    let title: String
    /// a back button (pages pushed on a stack); off for a sheet, closed by its own button
    var back = true
    /// what back does, when not going back a page (a screen shown over the others closes itself)
    var onBack: (() -> Void)? = nil
    @ViewBuilder var trailing: Trailing
    @Environment(\.dismiss) private var dismiss

    static var pill: Color { Color(light: 0xFFFDF8, dark: 0x16263A) }

    var body: some View {
        ZStack {
            Text(title).font(.nunito(17, .black)).foregroundStyle(Color.ink)
                .lineLimit(1).minimumScaleFactor(0.75)
                .padding(.horizontal, 104)
            HStack(spacing: 0) {
                if back {
                    Button { if let onBack { onBack() } else { dismiss() } } label: {
                        Image(systemName: "chevron.left").font(.system(size: 16, weight: .heavy)).foregroundStyle(Color.accent)
                            .frame(width: 40, height: 40)
                            .background(Self.pill, in: Circle())
                            .overlay(Circle().stroke(Color.line, lineWidth: 1.5))
                            .contentShape(Circle())
                    }
                    .buttonStyle(CardPress())
                    .accessibilityLabel("Back")
                }
                Spacer(minLength: 0)
                trailing
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(Color.bg)
    }
}

/// A count on the right of a page's bar ("36 / 36 words"): a small cream pill, as the bar's back button.
struct BarCount: View {
    let text: String
    var body: some View {
        Text(text).font(.nunito(13, .heavy)).monospacedDigit().foregroundStyle(Color.muted).lineLimit(1)
            .padding(.horizontal, 12).frame(height: 32)
            .background(PageBar<EmptyView>.pill, in: Capsule())
            .overlay(Capsule().stroke(Color.line, lineWidth: 1.5))
    }
}

/// A button on the right of a page's bar ("Reset", "Done"): the same pill, its word in teal.
struct BarButton: View {
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label).font(.nunito(14, .black)).foregroundStyle(Color.accent)
                .padding(.horizontal, 14).frame(height: 32)
                .background(PageBar<EmptyView>.pill, in: Capsule())
                .overlay(Capsule().stroke(Color.line, lineWidth: 1.5))
                .contentShape(Capsule())
        }
        .buttonStyle(CardPress())
    }
}

/// A search box in the app's look (the system's lived in the navigation bar, gone now): a magnifier, the words typed,
/// and a clear button, on a cream field with a line round it, teal while it's being typed in.
struct SearchField: View {
    @Binding var text: String
    let prompt: String
    @FocusState private var focused: Bool
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 15, weight: .bold)).foregroundStyle(Color.muted)
            TextField(prompt, text: $text)
                .font(.nunito(15.5, .bold)).foregroundStyle(Color.ink)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .focused($focused).submitLabel(.search)
            if !text.isEmpty {
                Button { text = ""; focused = false } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 17)).foregroundStyle(Color.muted)
                        .frame(width: 44, height: 46).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, -12)
                .accessibilityLabel("Clear the search")
            }
        }
        .padding(.horizontal, 14).frame(height: 46)
        .background(PageBar<EmptyView>.pill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(focused ? Color.accent : Color.line, lineWidth: 1.5))
    }
}

extension View {
    /// A search box under the page's bar, staying there as the page scrolls.
    func searchBar(_ text: Binding<String>, prompt: String) -> some View {
        safeAreaInset(edge: .top, spacing: 0) {
            SearchField(text: text, prompt: prompt).padding(.horizontal, 18).padding(.top, 2).padding(.bottom, 8).background(Color.bg)
        }
    }

    /// The page's own bar across its top (the system's hidden), with a count or button on the right.
    func pageBar<T: View>(_ title: String, back: Bool = true, @ViewBuilder trailing: () -> T) -> some View {
        toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) { PageBar(title: title, back: back, trailing: trailing) }
    }
    /// The page's own bar across its top: back and its name.
    func pageBar(_ title: String, back: Bool = true) -> some View {
        pageBar(title, back: back) { EmptyView() }
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
