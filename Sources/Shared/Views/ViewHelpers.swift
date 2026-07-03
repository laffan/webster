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

    /// Attaches a touch-and-hold menu that flags or unflags `word` as a
    /// favorite — the subtle, system-standard way to reveal the action without
    /// cluttering the row.
    func favoriteContextMenu(for word: String) -> some View {
        modifier(FavoriteContextMenu(word: word))
    }
}

private struct FavoriteContextMenu: ViewModifier {
    let word: String
    @EnvironmentObject private var favorites: FavoritesStore

    func body(content: Content) -> some View {
        content.contextMenu {
            Button {
                favorites.toggle(word)
            } label: {
                if favorites.isFavorite(word) {
                    Label("Remove from Favorites", systemImage: "star.slash")
                } else {
                    Label("Add to Favorites", systemImage: "star")
                }
            }
        }
    }
}
