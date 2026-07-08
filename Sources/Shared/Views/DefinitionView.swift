import SwiftUI

/// The definition layout without an enclosing scroll view, so callers can place
/// one (Random shows two of these in a single scroll view).
struct DefinitionContent: View {
    let entry: DictionaryEntry

    #if os(watchOS)
    // On the Watch the headword only needs to be a touch larger than body text.
    private let headwordFont: Font = .system(.headline, design: .serif)
    #else
    private let headwordFont: Font = .system(.title, design: .serif)
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Only the headword carries the touch-and-hold favorite menu, so the
            // definition below stays plain, selectable text you can copy/paste.
            Text(entry.titleCased)
                .font(headwordFont)
                .fontWeight(.bold)
                .favoriteContextMenu(for: entry.word)

            Divider()

            FormattedDefinitionView(definition: entry.definition)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A scrollable single definition, used by `DefinitionView`.
struct DefinitionBody: View {
    let entry: DictionaryEntry

    var body: some View {
        ScrollView {
            DefinitionContent(entry: entry)
                .padding()
        }
    }
}

/// A full definition screen used as a navigation destination. When opened from a
/// search or browse result it records the word in the matching history section;
/// re-opening from the History list passes `recordAs: nil` so it stays put.
struct DefinitionView: View {
    let entry: DictionaryEntry
    var recordAs: HistorySource? = nil

    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var favorites: FavoritesStore

    var body: some View {
        DefinitionBody(entry: entry)
            .navigationTitle(entry.titleCased)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    let isFavorite = favorites.isFavorite(entry.word)
                    Button {
                        favorites.toggle(entry.word)
                    } label: {
                        Label(isFavorite ? "Remove from Favorites" : "Add to Favorites",
                              systemImage: isFavorite ? "star.fill" : "star")
                    }
                    .accessibilityLabel(isFavorite ? "Remove from Favorites" : "Add to Favorites")
                }
            }
            .onAppear {
                if let recordAs {
                    history.record(entry.word, source: recordAs)
                }
            }
    }
}
