import SwiftUI

/// Recent screen contents: recently seen headwords split into "Lookup" (from
/// Search), "Browse", and "Random" sections, newest first, with swipe-to-delete
/// and a clear-all action.
struct RecentsContent: View {
    @EnvironmentObject private var store: DictionaryStore
    @EnvironmentObject private var recents: RecentsStore

    var body: some View {
        List {
            recentSection("Lookup", items: recents.lookups, source: .lookup)
            recentSection("Browse", items: recents.browses, source: .browse)
            recentSection("Random", items: recents.randoms, source: .random)
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

    @ViewBuilder
    private func recentSection(_ title: String, items: [RecentItem], source: RecentSource) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(entries(for: items)) { entry in
                    NavigationLink {
                        DefinitionView(entry: entry)
                    } label: {
                        EntryRow(entry: entry)
                    }
                }
                .onDelete { recents.remove(source: source, atOffsets: $0) }
            }
        }
    }

    /// Section order mirrors the stored order, so delete offsets line up. Words
    /// always originate from the database, so `entry(for:)` resolves them.
    private func entries(for items: [RecentItem]) -> [DictionaryEntry] {
        items.compactMap { store.entry(for: $0.word) }
    }
}
