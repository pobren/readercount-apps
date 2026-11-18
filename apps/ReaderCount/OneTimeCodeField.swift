#if os(iOS)
import SwiftUI
import UIKit

/// The six-digit code box on iPhone and iPad. SwiftUI's own TextField often takes only the first digit when the code
/// is tapped above the keyboard (AutoFill types it in one character at a time while SwiftUI redraws the box), so this
/// uses a UIKit text field, which takes the whole code in one go and keeps only digits, at most six.
struct OneTimeCodeField: UIViewRepresentable {
    @Binding var text: String
    var focused: Bool
    var placeholder: String
    var font: UIFont = .monospacedDigitSystemFont(ofSize: 22, weight: .regular)
    var onFocusChange: (Bool) -> Void = { _ in }
    var onSubmit: () -> Void = {}

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.textContentType = .oneTimeCode
        field.keyboardType = .numberPad
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.textAlignment = .center
        field.font = font
        field.adjustsFontForContentSizeCategory = true
        field.placeholder = placeholder
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if field.text != text { field.text = text }
        // Only move focus when it really needs to change, so AutoFill isn't interrupted mid-way.
        if focused, !field.isFirstResponder {
            DispatchQueue.main.async { if field.window != nil { field.becomeFirstResponder() } }
        } else if !focused, field.isFirstResponder {
            DispatchQueue.main.async { field.resignFirstResponder() }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    static func digits(_ s: String) -> String { String(s.filter(\.isNumber).prefix(6)) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: OneTimeCodeField
        init(_ parent: OneTimeCodeField) { self.parent = parent }

        @objc func changed(_ field: UITextField) {
            let clean = OneTimeCodeField.digits(field.text ?? "")
            if field.text != clean { field.text = clean }
            if parent.text != clean { parent.text = clean }
        }

        func textField(_ field: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            // A whole code arriving at once (AutoFill or paste) replaces what's there, digits only.
            let incoming = OneTimeCodeField.digits(string)
            if incoming.count == 6 {
                field.text = incoming
                changed(field)
                return false
            }
            return true
        }

        func textFieldDidBeginEditing(_ field: UITextField) { parent.onFocusChange(true) }
        func textFieldDidEndEditing(_ field: UITextField) { parent.onFocusChange(false) }
        func textFieldShouldReturn(_ field: UITextField) -> Bool { parent.onSubmit(); return true }
    }
}
#endif
