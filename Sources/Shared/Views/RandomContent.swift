import SwiftUI

/// Random screen contents: shows one random definition with a shuffle control.
/// Each word shown is recorded in the Random section of recents.
struct RandomContent: View {
    @EnvironmentObject private var store: DictionaryStore
    @EnvironmentObject private var recents: RecentsStore
    @State private var entry: DictionaryEntry?

    var body: some View {
        Group {
            if let entry {
                DefinitionBody(entry: entry)
            } else {
                ContentUnavailableView("No word yet", systemImage: "shuffle")
            }
        }
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
        guard let next = store.randomEntry() else { return }
        entry = next
        recents.record(next.word, source: .random)
    }
}
