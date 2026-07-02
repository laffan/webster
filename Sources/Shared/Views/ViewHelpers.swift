import SwiftUI

extension View {
    /// Enables text selection on platforms that support it (iOS/iPadOS).
    /// watchOS has no text-selection affordance, so this is a no-op there.
    @ViewBuilder
    func selectableText() -> some View {
        #if os(iOS)
        self.textSelection(.enabled)
        #else
        self
        #endif
    }

    /// Disables autocapitalization on iOS; no-op elsewhere. Handy for a search
    /// field where the user is looking up lowercase headwords.
    @ViewBuilder
    func searchFieldStyling() -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(.never).autocorrectionDisabled()
        #else
        self.autocorrectionDisabled()
        #endif
    }
}
