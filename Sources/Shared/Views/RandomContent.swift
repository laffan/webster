import SwiftUI

/// Random screen contents: shows two random definitions with a shuffle control.
struct RandomContent: View {
    @EnvironmentObject private var store: DictionaryStore
    @State private var entries: [DictionaryEntry] = []

    private let wordCount = 2

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView("No words yet", systemImage: "shuffle")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            if index > 0 {
                                Divider().padding(.vertical, 16)
                            }
                            DefinitionContent(entry: entry)
                        }
                    }
                    .padding()
                }
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
            if entries.isEmpty { shuffle() }
        }
    }

    private func shuffle() {
        var picked: [DictionaryEntry] = []
        var attempts = 0
        while picked.count < wordCount && attempts < wordCount * 10 {
            attempts += 1
            guard let candidate = store.randomEntry() else { break }
            if !picked.contains(where: { $0.id == candidate.id }) {
                picked.append(candidate)
            }
        }
        entries = picked
    }
}
