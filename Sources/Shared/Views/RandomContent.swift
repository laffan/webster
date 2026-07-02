import SwiftUI

/// Random screen contents: shows one random definition with a shuffle control.
/// Browsing here is intentionally ephemeral and does not record recents.
struct RandomContent: View {
    @EnvironmentObject private var store: DictionaryStore
    @State private var entry: DictionaryEntry?

    var body: some View {
        Group {
            if let entry {
                DefinitionBody(entry: entry)
            } else {
                ContentUnavailableView("No word yet", systemImage: "shuffle")
            }
        }
        .navigationTitle("Random")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    shuffle()
                } label: {
                    Label("Shuffle", systemImage: "shuffle")
                }
            }
        }
        .onAppear {
            if entry == nil { shuffle() }
        }
    }

    private func shuffle() {
        entry = store.randomEntry()
    }
}
