import SwiftUI

/// Recent screen contents: recently seen headwords split into "Lookup" (from
/// Search) and "Random" (from the Random screen), newest first, with
/// swipe-to-delete and a clear-all action.
struct RecentsContent: View {
    @EnvironmentObject private var store: DictionaryStore
    @EnvironmentObject private var recents: RecentsStore

    var body: some View {
        List {
            if !recents.lookups.isEmpty {
                Section("Lookup") {
                    ForEach(entries(for: recents.lookups)) { entry in
                        NavigationLink(value: entry) {
                            EntryRow(entry: entry)
                        }
                    }
                    .onDelete { recents.remove(source: .lookup, atOffsets: $0) }
                }
            }

            if !recents.randoms.isEmpty {
                Section("Random") {
                    ForEach(entries(for: recents.randoms)) { entry in
                        NavigationLink(value: entry) {
                            EntryRow(entry: entry)
                        }
                    }
                    .onDelete { recents.remove(source: .random, atOffsets: $0) }
                }
            }
        }
        .navigationDestination(for: DictionaryEntry.self) { entry in
            DefinitionView(entry: entry)
        }
        .overlay {
            if recents.items.isEmpty {
                ContentUnavailableView(
                    "No Recent Words",
                    systemImage: "clock",
                    description: Text("Words you look up or discover will appear here.")
                )
            }
        }
        .toolbar {
            if !recents.items.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("Clear", role: .destructive) {
                        recents.clear()
                    }
                }
            }
        }
    }

    /// Section order mirrors the stored order, so delete offsets line up. Words
    /// always originate from the database, so `entry(for:)` resolves them.
    private func entries(for items: [RecentItem]) -> [DictionaryEntry] {
        items.compactMap { store.entry(for: $0.word) }
    }
}
