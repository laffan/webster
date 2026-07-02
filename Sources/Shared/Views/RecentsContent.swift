import SwiftUI

/// Recent screen contents: recently viewed headwords, newest first, with
/// swipe-to-delete and a clear-all action.
struct RecentsContent: View {
    @EnvironmentObject private var store: DictionaryStore
    @EnvironmentObject private var recents: RecentsStore

    var body: some View {
        List {
            ForEach(recentEntries) { entry in
                NavigationLink(value: entry) {
                    EntryRow(entry: entry)
                }
            }
            .onDelete(perform: recents.remove(atOffsets:))
        }
        .navigationTitle("Recent")
        .navigationDestination(for: DictionaryEntry.self) { entry in
            DefinitionView(entry: entry)
        }
        .overlay {
            if recents.words.isEmpty {
                ContentUnavailableView(
                    "No Recent Words",
                    systemImage: "clock",
                    description: Text("Words you look up will appear here.")
                )
            }
        }
        .toolbar {
            if !recents.words.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("Clear", role: .destructive) {
                        recents.clear()
                    }
                }
            }
        }
    }

    /// Recents order mirrors `recents.words`, so delete offsets line up. Words
    /// always originate from the database, so `entry(for:)` resolves them.
    private var recentEntries: [DictionaryEntry] {
        recents.words.compactMap { store.entry(for: $0) }
    }
}
