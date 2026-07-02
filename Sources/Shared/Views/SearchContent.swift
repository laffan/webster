import SwiftUI

/// Search screen contents. Expects to be hosted inside a `NavigationStack`
/// (each platform provides its own), so it declares a `navigationDestination`
/// but no stack of its own.
struct SearchContent: View {
    @EnvironmentObject private var store: DictionaryStore
    @State private var query = ""
    @State private var results: [DictionaryEntry] = []

    var body: some View {
        List(results) { entry in
            NavigationLink(value: entry) {
                EntryRow(entry: entry)
            }
        }
        .navigationDestination(for: DictionaryEntry.self) { entry in
            DefinitionView(entry: entry, recordAs: .lookup)
        }
        .searchable(text: $query, prompt: searchPrompt)
        .searchFieldStyling()
        .overlay {
            if query.isEmpty {
                ContentUnavailableView(
                    "Webster's Dictionary",
                    systemImage: "character.book.closed",
                    description: Text("Search \(store.entryCount.formatted()) definitions from the 1913 Revised Unabridged edition.")
                )
            } else if results.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        // Debounce: re-run only after typing pauses briefly; `.task(id:)`
        // cancels the previous query on each keystroke.
        .task(id: query) {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            results = store.search(query)
        }
    }

    private var searchPrompt: String {
        store.entryCount > 0 ? "Search \(store.entryCount.formatted()) words" : "Search"
    }
}
