import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Search screen contents. Expects to be hosted inside a `NavigationStack`
/// (each platform provides its own); result rows push a definition via a
/// direct `NavigationLink`.
///
/// iOS uses a custom search bar with a paste button; watchOS shows an explicit
/// text field at the top of the list (tapping it opens the watch's
/// scribble/dictation/keyboard input).
struct SearchContent: View {
    @EnvironmentObject private var store: DictionaryStore
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var favorites: FavoritesStore
    @State private var query = ""
    @State private var results: [DictionaryEntry] = []

    var body: some View {
        #if os(iOS)
        VStack(spacing: 0) {
            SearchBar(query: $query, placeholder: searchPrompt)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)
            resultsList
        }
        #else
        resultsList
        #endif
    }

    private var resultsList: some View {
        List {
            #if os(watchOS)
            // watchOS: an explicit, tappable field. `.searchable` does not
            // reliably surface a search box on a pushed watch view, which left
            // the screen with no way to type a query at all. Tapping this opens
            // the system text-entry screen (scribble, dictation, or keyboard).
            TextField(searchPrompt, text: $query)
                .searchFieldStyling()
                .submitLabel(.search)
            #endif

            if query.isEmpty {
                recentSection
            } else {
                ForEach(results) { entry in
                    resultRow(entry)
                }
            }
        }
        .overlay {
            // On watchOS the field lives inside the list, so a full-screen
            // overlay would cover it; keep the empty-state art to iOS only.
            #if os(iOS)
            if query.isEmpty && history.lookups.isEmpty {
                ContentUnavailableView(
                    "Webster's Dictionary",
                    systemImage: "character.book.closed",
                    description: Text("Search \(store.entryCount.formatted()) definitions from the 1913 Revised Unabridged edition.")
                )
            } else if !query.isEmpty && results.isEmpty {
                ContentUnavailableView.search(text: query)
            }
            #endif
        }
        // Debounce: re-run only after typing pauses briefly; `.task(id:)`
        // cancels the previous query on each keystroke.
        .task(id: query) {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            results = store.search(query)
        }
    }

    /// Recently looked-up words, shown when the field is empty. Swipe left to
    /// remove, swipe right to favorite.
    @ViewBuilder
    private var recentSection: some View {
        let recents = history.lookups.compactMap { store.entry(for: $0.word) }
        if !recents.isEmpty {
            Section {
                ForEach(recents) { entry in
                    resultRow(entry)
                        .swipeActions(edge: .leading) {
                            Button {
                                favorites.toggle(entry.word)
                            } label: {
                                let isFavorite = favorites.isFavorite(entry.word)
                                Label(isFavorite ? "Unfavorite" : "Favorite",
                                      systemImage: isFavorite ? "star.slash" : "star")
                            }
                            .tint(.yellow)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                history.remove(word: entry.word)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            } header: {
                HStack {
                    Text("Recent Searches")
                    Spacer()
                    Button("Clear") { history.clear() }
                        .font(.caption)
                        .textCase(nil)
                }
            }
        }
    }

    private func resultRow(_ entry: DictionaryEntry) -> some View {
        NavigationLink {
            DefinitionView(entry: entry, recordAs: .lookup)
        } label: {
            EntryRow(entry: entry)
        }
    }

    private var searchPrompt: String {
        store.entryCount > 0 ? "Search \(store.entryCount.formatted()) words" : "Search"
    }
}

#if os(iOS)
/// A rounded search field with a magnifying glass, an inline clear button, and a
/// paste button that fills the field from the clipboard.
private struct SearchBar: View {
    @Binding var query: String
    let placeholder: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $query)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .focused($isFocused)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear")
            }

            Button {
                if let string = UIPasteboard.general.string {
                    query = string.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } label: {
                Image(systemName: "doc.on.clipboard")
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Paste")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        // The system keyboard has no dismiss key, so give it one: an accessory
        // bar with a button that resigns focus. Without this the keyboard covers
        // the tab bar with no way to get it back.
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    isFocused = false
                } label: {
                    Label("Hide Keyboard", systemImage: "keyboard.chevron.compact.down")
                }
                .accessibilityLabel("Hide Keyboard")
            }
        }
    }
}
#endif
