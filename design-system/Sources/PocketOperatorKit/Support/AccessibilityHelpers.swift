import SwiftUI

@available(macOS 15, *)
extension View {
    /// Apply an accessibility label only when one was supplied.
    ///
    /// Needed because `.accessibilityLabel("")` is not a no-op — it replaces
    /// whatever the content would otherwise have announced, which for a key
    /// carrying a custom label view silently deletes its name.
    @ViewBuilder
    func poAccessibilityLabel(_ text: String?) -> some View {
        if let text, !text.isEmpty {
            accessibilityLabel(Text(text))
        } else {
            self
        }
    }

    @ViewBuilder
    func poAccessibilityHint(_ text: String?) -> some View {
        if let text, !text.isEmpty {
            accessibilityHint(Text(text))
        } else {
            self
        }
    }

    @ViewBuilder
    func poAccessibilityValue(_ text: String?) -> some View {
        if let text, !text.isEmpty {
            accessibilityValue(Text(text))
        } else {
            self
        }
    }
}
