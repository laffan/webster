import SwiftUI

/// Browse screen.
///
/// On iPhone/iPad it reads like a page of a printed dictionary: one letter is
/// shown at a time, with every entry's full definition laid out inline, and the
/// A–Z rail down the trailing edge is a column of buttons that flip between
/// letters. Only the selected letter's entries are ever loaded (in one bulk,
/// off-main query, cached), and rows render lazily and parse once, so even the
/// biggest letters scroll smoothly.
///
/// On watchOS it keeps the original long sectioned list, each word pushing a
/// definition pane.
struct BrowseContent: View {
    @EnvironmentObject private var store: DictionaryStore
    @State private var sections: [BrowseSection] = []
    #if os(iOS)
    @State private var selectedLetter: String?
    #endif

    var body: some View {
        Group {
            if sections.isEmpty {
                ProgressView()
            } else {
                #if os(iOS)
                iOSLayout
                #else
                watchList
                #endif
            }
        }
        .task {
            if sections.isEmpty {
                sections = await store.loadBrowseSections()
                #if os(iOS)
                if selectedLetter == nil {
                    selectedLetter = sections.first?.letter
                }
                #endif
            }
        }
    }

    #if os(iOS)
    private var currentSection: BrowseSection? {
        sections.first { $0.letter == selectedLetter } ?? sections.first
    }

    private var iOSLayout: some View {
        HStack(spacing: 0) {
            if let section = currentSection {
                BrowseLetterView(section: section)
                    .frame(maxWidth: .infinity)
            }
            LetterRail(
                letters: sections.map(\.letter),
                selected: currentSection?.letter
            ) { selectedLetter = $0 }
        }
        .navigationTitle("Browse")
        .navigationBarTitleDisplayMode(.inline)
    }
    #else
    private var watchList: some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.headwords) { headword in
                        WatchBrowseRow(headword: headword)
                    }
                } header: {
                    Text(section.letter)
                        .font(.system(.title3, design: .serif).weight(.bold))
                        .foregroundStyle(.primary)
                        .textCase(nil)
                }
            }
        }
    }
    #endif
}

#if os(iOS)
// MARK: - One letter, dictionary-style

/// A single letter rendered as a dictionary page: a large drop-letter heading
/// followed by every entry's headword and full definition. Entries are
/// bulk-loaded once per letter and rendered lazily.
private struct BrowseLetterView: View {
    let section: BrowseSection

    @EnvironmentObject private var store: DictionaryStore
    @State private var entries: [DictionaryEntry] = []
    @State private var loadedLetter: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                pageHeader

                if loadedLetter == section.letter {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 {
                            Divider().padding(.vertical, 14)
                        }
                        BrowseEntryView(entry: entry)
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
            // A fresh identity per letter resets the scroll position to the top.
            .id(section.letter)
        }
        .task(id: section.letter) {
            let letter = section.letter
            let loaded = await store.loadBrowseEntries(for: section)
            // Ignore a result that arrived after the user moved to another letter.
            guard section.letter == letter else { return }
            entries = loaded
            loadedLetter = letter
        }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(section.letter)
                .font(.system(size: 52, weight: .bold, design: .serif))
                .foregroundStyle(.primary)
            Rectangle()
                .fill(.primary)
                .frame(height: 1)
        }
        .padding(.top, 12)
        .padding(.bottom, 18)
    }
}

/// A single dictionary entry: bold serif headword above its full, formatted
/// definition. The definition is parsed once, off the render path, and cached
/// so scrolling back and forth never re-parses it.
private struct BrowseEntryView: View {
    let entry: DictionaryEntry
    @State private var parsed: ParsedDefinition?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.titleCased)
                .font(.system(.title3, design: .serif).weight(.bold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .selectableText()

            if let parsed {
                FormattedDefinitionView(parsed: parsed)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .favoriteContextMenu(for: entry.word)
        .task {
            if parsed == nil {
                parsed = ParsedDefinition.parse(entry.definition)
            }
        }
    }
}

// MARK: - Letter rail

/// The trailing A–Z rail, rebuilt as buttons: each letter flips the page to that
/// letter, and the current letter is highlighted.
private struct LetterRail: View {
    let letters: [String]
    let selected: String?
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(letters, id: \.self) { letter in
                Button {
                    onSelect(letter)
                } label: {
                    Text(letter)
                        .font(.system(size: 12,
                                      weight: selected == letter ? .bold : .semibold,
                                      design: .serif))
                        .foregroundStyle(selected == letter ? Color.accentColor : Color.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 26)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.trailing, 4)
        .padding(.vertical, 8)
    }
}
#endif

// MARK: - watchOS row

#if os(watchOS)
/// The watchOS browse row: pushes a definition pane. A direct `NavigationLink`
/// destination is used rather than value-based navigation, which is unreliable
/// from a pushed view on watchOS.
private struct WatchBrowseRow: View {
    let headword: Headword
    @EnvironmentObject private var store: DictionaryStore

    var body: some View {
        NavigationLink {
            if let entry = store.entry(id: headword.id) {
                DefinitionView(entry: entry, recordAs: .browse)
            }
        } label: {
            Text(headword.titleCased)
                .font(.system(.body, design: .serif))
        }
    }
}
#endif
