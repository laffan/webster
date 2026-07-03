import SwiftUI

/// Compact list row: a capitalized headword above a two-line definition preview,
/// with a small star when the word is favorited. Touch-and-hold toggles the
/// favorite.
struct EntryRow: View {
    let entry: DictionaryEntry

    @EnvironmentObject private var favorites: FavoritesStore

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.titleCased)
                    .font(.system(.headline, design: .serif))
                Text(entry.definition)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if favorites.isFavorite(entry.word) {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Favorite")
            }
        }
        .padding(.vertical, 2)
        .favoriteContextMenu(for: entry.word)
    }
}
