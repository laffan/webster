import SwiftUI

/// History screen contents: seen headwords split into "Lookup" (from Search) and
/// "Random" sections, newest first, with swipe-to-delete and a clear-all action.
/// (A legacy "Browse" section still appears for anyone who used the old
/// accordion browse, but nothing records into it anymore.)
struct HistoryContent: View {
    @EnvironmentObject private var store: DictionaryStore
    @EnvironmentObject private var history: HistoryStore

    var body: some View {
        List {
            historySection("Lookup", items: history.lookups, source: .lookup)
            historySection("Browse", items: history.browses, source: .browse)
            historySection("Random", items: history.randoms, source: .random)
        }
        .navigationTitle("History")
        .overlay {
            if history.items.isEmpty {
                ContentUnavailableView(
                    "No History",
                    systemImage: "clock",
                    description: Text("Words you look up or discover will appear here.")
                )
            }
        }
        .toolbar {
            if !history.items.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("Clear", role: .destructive) {
                        history.clear()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func historySection(_ title: String, items: [HistoryItem], source: HistorySource) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(entries(for: items)) { entry in
                    NavigationLink {
                        DefinitionView(entry: entry)
                    } label: {
                        EntryRow(entry: entry)
                    }
                }
                .onDelete { history.remove(source: source, atOffsets: $0) }
            }
        }
    }

    /// Section order mirrors the stored order, so delete offsets line up. Words
    /// always originate from the database, so `entry(for:)` resolves them.
    private func entries(for items: [HistoryItem]) -> [DictionaryEntry] {
        items.compactMap { store.entry(for: $0.word) }
    }
}
