import SwiftUI

/// The definition layout without an enclosing scroll view, so callers can place
/// one (Random shows two of these in a single scroll view).
struct DefinitionContent: View {
    let entry: DictionaryEntry

    #if os(watchOS)
    // On the Watch the headword only needs to be a touch larger than body text.
    private let headwordFont: Font = .system(.headline, design: .serif)
    #else
    private let headwordFont: Font = .system(.title, design: .serif)
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(entry.titleCased)
                .font(headwordFont)
                .fontWeight(.bold)
                .selectableText()

            Divider()

            FormattedDefinitionView(definition: entry.definition)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A scrollable single definition, used by `DefinitionView`.
struct DefinitionBody: View {
    let entry: DictionaryEntry

    var body: some View {
        ScrollView {
            DefinitionContent(entry: entry)
                .padding()
        }
    }
}

/// A full definition screen used as a navigation destination. When opened from a
/// search or browse result it records the word in the matching recents section;
/// re-opening from the Recent list passes `recordAs: nil` so it stays put.
struct DefinitionView: View {
    let entry: DictionaryEntry
    var recordAs: RecentSource? = nil

    @EnvironmentObject private var recents: RecentsStore

    var body: some View {
        DefinitionBody(entry: entry)
            .navigationTitle(entry.titleCased)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear {
                if let recordAs {
                    recents.record(entry.word, source: recordAs)
                }
            }
    }
}
