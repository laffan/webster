import SwiftUI

/// Browse screen.
///
/// On iPhone/iPad it reads like a page of a printed dictionary: one letter is
/// shown at a time, with every entry's full definition laid out inline. Two
/// trailing rails sit on the edge: an A–Z column of buttons that flip between
/// letters, and — just inside it — a proportional "section" rail listing the
/// two-letter sub-sections of the current letter (Pa, Pe, Pn…) that doubles as a
/// scroll-position indicator. Only the selected letter's entries are ever loaded
/// (in one bulk, off-main query, cached), and rows render lazily and parse once,
/// so even the biggest letters scroll smoothly.
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

/// A run of entries sharing a two-letter prefix (Pa, Pe, Pn…), used to annotate
/// the section rail and to jump within a letter.
private struct BrowseSubsection: Identifiable {
    let firstIndex: Int      // index of the first entry in the letter's array
    let firstEntryID: Int    // that entry's id, for scrollTo
    let label: String        // e.g. "Pa"
    var id: Int { firstIndex }
}

/// Reports each visible row's vertical offset (keyed by index) so the parent can
/// work out which entry is at the top of the viewport.
private struct RowOffsetsKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

/// A single letter rendered as a dictionary page: a large drop-letter heading
/// followed by every entry's headword and full definition. Entries are
/// bulk-loaded once per letter and rendered lazily.
private struct BrowseLetterView: View {
    let section: BrowseSection

    @EnvironmentObject private var store: DictionaryStore
    @State private var entries: [DictionaryEntry] = []
    @State private var subsections: [BrowseSubsection] = []
    @State private var loadedLetter: String?
    @State private var topIndex: Int = 0

    private let coordinateSpace = "letterScroll"

    private var isLoaded: Bool { loadedLetter == section.letter }

    var body: some View {
        ScrollViewReader { proxy in
            HStack(spacing: 0) {
                scrollView

                if isLoaded && subsections.count > 1 {
                    SectionRail(
                        subsections: subsections,
                        total: entries.count,
                        topIndex: topIndex
                    ) { entryID in
                        proxy.scrollTo(entryID, anchor: .top)
                    }
                }
            }
        }
    }

    private var scrollView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                pageHeader

                if isLoaded {
                    // Iterating `indices` (not `Array(enumerated())`) keeps this
                    // body allocation-free, which matters because the scroll
                    // tracker re-evaluates it as the user scrolls.
                    ForEach(entries.indices, id: \.self) { index in
                        let entry = entries[index]
                        VStack(alignment: .leading, spacing: 0) {
                            if index > 0 {
                                Divider().padding(.vertical, 14)
                            }
                            BrowseEntryView(entry: entry)
                        }
                        .id(entry.id)
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: RowOffsetsKey.self,
                                    value: [index: geo.frame(in: .named(coordinateSpace)).minY]
                                )
                            }
                        )
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
        .coordinateSpace(name: coordinateSpace)
        .onPreferenceChange(RowOffsetsKey.self) { offsets in
            topIndex = Self.topIndex(from: offsets)
        }
        .task(id: section.letter) {
            let letter = section.letter
            let loaded = await store.loadBrowseEntries(for: section)
            // Ignore a result that arrived after the user moved to another letter.
            guard section.letter == letter else { return }
            entries = loaded
            subsections = Self.makeSubsections(loaded)
            topIndex = 0
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

    /// The entry sitting at (or just above) the top of the viewport.
    private static func topIndex(from offsets: [Int: CGFloat]) -> Int {
        let atTop = offsets.filter { $0.value <= 8 }
        if let top = atTop.max(by: { $0.value < $1.value }) { return top.key }
        return offsets.min(by: { $0.value < $1.value })?.key ?? 0
    }

    /// Splits a letter's entries into two-letter sub-sections in order.
    private static func makeSubsections(_ entries: [DictionaryEntry]) -> [BrowseSubsection] {
        var result: [BrowseSubsection] = []
        var lastPrefix: String?
        for (index, entry) in entries.enumerated() {
            let prefix = String(entry.word.lowercased().prefix(2))
            if prefix != lastPrefix {
                result.append(
                    BrowseSubsection(firstIndex: index,
                                     firstEntryID: entry.id,
                                     label: prefix.capitalized)
                )
                lastPrefix = prefix
            }
        }
        return result
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

// MARK: - Section rail (sub-sections + scroll position)

/// A proportional minimap of the current letter's two-letter sub-sections. Each
/// label sits at the vertical fraction where its section begins (so their
/// spacing is deliberately uneven), the section containing the viewport top is
/// highlighted, and a thin bar marks the live scroll position. Tapping or
/// dragging jumps to the nearest sub-section.
private struct SectionRail: View {
    let subsections: [BrowseSubsection]
    let total: Int
    let topIndex: Int
    let onJump: (Int) -> Void

    @State private var lastJumped: Int?

    private var currentIndex: Int {
        subsections.lastIndex(where: { $0.firstIndex <= topIndex }) ?? 0
    }

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let visible = labelVisibility(height: height)

            ZStack(alignment: .top) {
                ForEach(Array(subsections.enumerated()), id: \.element.id) { index, sub in
                    if visible[index] || index == currentIndex {
                        Text(sub.label)
                            .font(.system(size: 10,
                                          weight: index == currentIndex ? .bold : .regular,
                                          design: .serif))
                            .foregroundStyle(index == currentIndex ? Color.accentColor : Color.secondary)
                            .position(x: geo.size.width / 2, y: y(for: subsections[index].firstIndex, height: height))
                    }
                }

                // Live scroll-position marker.
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: 16, height: 2)
                    .position(x: geo.size.width / 2, y: y(for: topIndex, height: height))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let fraction = min(max(value.location.y / height, 0), 1)
                        let target = nearestSubsection(toFraction: fraction)
                        if target.firstEntryID != lastJumped {
                            lastJumped = target.firstEntryID
                            onJump(target.firstEntryID)
                        }
                    }
                    .onEnded { _ in lastJumped = nil }
            )
        }
        .frame(width: 32)
        .padding(.vertical, 10)
    }

    private func y(for index: Int, height: CGFloat) -> CGFloat {
        guard total > 1 else { return 0 }
        return CGFloat(index) / CGFloat(total - 1) * height
    }

    /// Which labels have room to be drawn without overlapping the previous one.
    private func labelVisibility(height: CGFloat) -> [Bool] {
        var flags = Array(repeating: false, count: subsections.count)
        var lastY: CGFloat = -.greatestFiniteMagnitude
        let minGap: CGFloat = 13
        for (index, sub) in subsections.enumerated() {
            let position = y(for: sub.firstIndex, height: height)
            if position - lastY >= minGap {
                flags[index] = true
                lastY = position
            }
        }
        return flags
    }

    private func nearestSubsection(toFraction fraction: CGFloat) -> BrowseSubsection {
        let denominator = CGFloat(max(total - 1, 1))
        return subsections.min(by: { lhs, rhs in
            abs(CGFloat(lhs.firstIndex) / denominator - fraction)
                < abs(CGFloat(rhs.firstIndex) / denominator - fraction)
        }) ?? subsections[0]
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
