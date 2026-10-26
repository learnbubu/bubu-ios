import SwiftUI
import UIKit

/// A box to type in that asks for its keyboard by language: Chinese (pinyin, giving characters) or English. iOS lets an
/// app ask for one of the keyboards you've added, not switch to one you haven't; `hasChinese` says whether you have.
/// Return checks instead of adding a line. (The owner, 26 Oct 2026: "a button to switch to english/chinese? and always
/// start in chinese")
struct KeyboardField: UIViewRepresentable {
    @Binding var text: String
    var chinese: Bool
    @Binding var focused: Bool
    var enabled: Bool
    var submit: () -> Void

    /// a Chinese (simplified) keyboard is among the ones added in Settings
    static var hasChinese: Bool {
        UITextInputMode.activeInputModes.contains { ($0.primaryLanguage ?? "").hasPrefix("zh-Hans") }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> LanguageTextView {
        let v = LanguageTextView()
        v.delegate = context.coordinator
        v.font = UIFont(name: "Nunito-Bold", size: 22) ?? .boldSystemFont(ofSize: 22)
        v.textColor = UIColor(Color.ink)
        v.tintColor = UIColor(Color.accent)
        v.backgroundColor = .clear
        v.textContainerInset = .zero
        v.textContainer.lineFragmentPadding = 0
        v.autocapitalizationType = .none
        v.autocorrectionType = .no
        v.spellCheckingType = .no
        v.smartQuotesType = .no
        v.returnKeyType = .done
        v.wantChinese = chinese
        v.setContentHuggingPriority(.defaultLow, for: .vertical)
        v.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return v
    }

    func updateUIView(_ v: LanguageTextView, context: Context) {
        context.coordinator.parent = self
        if v.text != text && v.markedTextRange == nil { v.text = text }
        v.isEditable = enabled
        if v.wantChinese != chinese {
            v.wantChinese = chinese
            // (the keyboard is asked for again only as the box gains focus: off and on, at once)
            if v.isFirstResponder {
                context.coordinator.switching = true
                v.resignFirstResponder()
                v.becomeFirstResponder()
                context.coordinator.switching = false
            }
        }
        if focused && enabled && !v.isFirstResponder {
            DispatchQueue.main.async { if v.window != nil { v.becomeFirstResponder() } }
        } else if (!focused || !enabled) && v.isFirstResponder {
            DispatchQueue.main.async { v.resignFirstResponder() }
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: KeyboardField
        var switching = false
        init(_ p: KeyboardField) { parent = p }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText t: String) -> Bool {
            // Return checks (with the pinyin keyboard's letters still being spelled, its Return puts them in as typed)
            if t == "\n" { parent.submit(); return false }
            return true
        }
        func textViewDidChange(_ textView: UITextView) { parent.text = textView.text }
        func textViewDidBeginEditing(_ textView: UITextView) { if !parent.focused { parent.focused = true } }
        func textViewDidEndEditing(_ textView: UITextView) { if !switching && parent.focused { parent.focused = false } }
    }
}

/// The text view that names the keyboard it wants: the first Chinese (simplified) or English one you've added.
final class LanguageTextView: UITextView {
    var wantChinese = true
    override var textInputMode: UITextInputMode? {
        let modes = UITextInputMode.activeInputModes
        let want = modes.first { ($0.primaryLanguage ?? "").hasPrefix(wantChinese ? "zh-Hans" : "en") }
        return want ?? super.textInputMode
    }
}
