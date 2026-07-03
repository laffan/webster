import SwiftUI

/// Favorites screen: every word the user has flagged, newest first, with
/// swipe-to-delete. Words are added from the touch-and-hold menu anywhere a word
/// appears, so this list is purely a place to revisit them.
struct FavoritesContent: View {
    @EnvironmentObject private var store: DictionaryStore
    @EnvironmentObject private var favorites: FavoritesStore

    var body: some View {
        List {
            ForEach(entries) { entry in
                NavigationLink {
                    DefinitionView(entry: entry)
                } label: {
                    EntryRow(entry: entry)
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("Favorites")
        .overlay {
            if favorites.words.isEmpty {
                ContentUnavailableView(
                    "No Favorites",
                    systemImage: "star",
                    description: Text("Touch and hold any word to add it here.")
                )
            }
        }
    }

    /// Resolves stored words to entries, preserving the favorites order. Words
    /// always originate from the database, so `entry(for:)` resolves them.
    private var entries: [DictionaryEntry] {
        favorites.words.compactMap { store.entry(for: $0) }
    }

    /// Deletes by word (not index) so it stays correct even if a stored word
    /// failed to resolve and was dropped from `entries`.
    private func delete(at offsets: IndexSet) {
        let resolved = entries
        for offset in offsets where offset < resolved.count {
            favorites.remove(resolved[offset].word)
        }
    }
}
