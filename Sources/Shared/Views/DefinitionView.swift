import SwiftUI

/// The definition layout, free of side effects so it can be reused by the
/// Random screen without polluting the recents list.
struct DefinitionBody: View {
    let entry: DictionaryEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(entry.displayWord)
                    .font(.system(.title, design: .serif).weight(.bold))
                    .selectableText()

                Divider()

                Text(entry.definition)
                    .font(.system(.body, design: .serif))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .selectableText()
            }
            .padding()
        }
    }
}

/// A full definition screen used as a navigation destination. Viewing a word
/// records it in the recents list.
struct DefinitionView: View {
    let entry: DictionaryEntry
    @EnvironmentObject private var recents: RecentsStore

    var body: some View {
        DefinitionBody(entry: entry)
            .navigationTitle(entry.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear { recents.record(entry.word) }
    }
}
