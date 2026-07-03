import SwiftUI

/// Browse screen: every headword in one long list, divided into large
/// alphabetical section headers. On iPhone/iPad a word twirls its definition
/// down inline (one at a time); on watchOS it pushes a definition pane. iOS also
/// gets an A–Z index down the trailing edge that jumps/scrubs to a section and
/// highlights the current scroll position.
struct BrowseContent: View {
    @EnvironmentObject private var store: DictionaryStore
    @State private var sections: [BrowseSection] = []
    @State private var expandedID: Int?

    private let coordinateSpace = "browseScroll"

    var body: some View {
        ScrollViewReader { proxy in
            Group {
                if sections.isEmpty {
                    ProgressView()
                } else {
                    list
                    #if os(iOS)
                        .coordinateSpace(name: coordinateSpace)
                        .contentMargins(.trailing, 34, for: .scrollContent)
                        .overlayPreferenceValue(SectionOffsetsKey.self) { offsets in
                            SectionIndexBar(
                                letters: sections.map(\.letter),
                                current: Self.currentLetter(from: offsets)
                            ) { letter in
                                proxy.scrollTo(letter, anchor: .top)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                        }
                    #endif
                }
            }
            .task {
                if sections.isEmpty {
                    sections = await store.loadBrowseSections()
                }
            }
        }
    }

    private var list: some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.headwords) { headword in
                        row(for: headword)
                    }
                } header: {
                    sectionHeader(section.letter)
                }
                .id(section.letter)
            }
        }
    }

    @ViewBuilder
    private func row(for headword: Headword) -> some View {
        #if os(iOS)
        InlineBrowseRow(
            headword: headword,
            isExpanded: expandedID == headword.id
        ) {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedID = (expandedID == headword.id) ? nil : headword.id
            }
        }
        #else
        WatchBrowseRow(headword: headword)
        #endif
    }

    private func sectionHeader(_ letter: String) -> some View {
        Text(letter)
            .font(.system(.title2, design: .serif).weight(.bold))
            .foregroundStyle(.primary)
            .textCase(nil)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: SectionOffsetsKey.self,
                        value: [letter: geo.frame(in: .named(coordinateSpace)).minY]
                    )
                }
            )
    }

    /// The section header sitting at (or just above) the top of the list.
    private static func currentLetter(from offsets: [String: CGFloat]) -> String? {
        let atTop = offsets.filter { $0.value <= 44 }
        return atTop.max(by: { $0.value < $1.value })?.key
            ?? offsets.min(by: { $0.value < $1.value })?.key
    }
}

// MARK: - Rows

#if os(iOS)
/// The iPhone/iPad browse row: a custom disclosure that reveals the definition
/// inline. Expansion is driven by the parent so only one row opens at a time.
private struct InlineBrowseRow: View {
    let headword: Headword
    let isExpanded: Bool
    let onToggle: () -> Void

    @EnvironmentObject private var store: DictionaryStore
    @EnvironmentObject private var recents: RecentsStore
    @State private var entry: DictionaryEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    Text(headword.titleCased)
                        .font(.system(.body, design: .serif))
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Group {
                    if let entry {
                        FormattedDefinitionView(definition: entry.definition)
                    } else {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 12)
            }
        }
        .onChange(of: isExpanded) { _, expanded in
            guard expanded else { return }
            if entry == nil {
                entry = store.entry(id: headword.id)
            }
            if let entry {
                recents.record(entry.word, source: .browse)
            }
        }
    }
}
#else
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

// MARK: - Index bar

/// Collects each visible section header's vertical offset so the index bar can
/// highlight the current scroll position.
private struct SectionOffsetsKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

#if os(iOS)
/// A Contacts-style A–Z index with its own background. Tapping or dragging
/// reports the letter under the finger; the current scroll position is
/// highlighted, and a bubble shows the active letter while scrubbing.
private struct SectionIndexBar: View {
    let letters: [String]
    let current: String?
    let onSelect: (String) -> Void

    @State private var isDragging = false
    @State private var activeLetter: String?

    var body: some View {
        GeometryReader { geo in
            let rowHeight = geo.size.height / CGFloat(max(letters.count, 1))
            VStack(spacing: 0) {
                ForEach(letters, id: \.self) { letter in
                    Text(letter)
                        .font(.system(size: 11, weight: current == letter ? .bold : .semibold))
                        .foregroundStyle(current == letter ? Color.accentColor : Color.secondary)
                        .scaleEffect(current == letter ? 1.3 : 1.0)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let index = min(max(Int(value.location.y / rowHeight), 0), letters.count - 1)
                        let letter = letters[index]
                        if letter != activeLetter {
                            activeLetter = letter
                            onSelect(letter)
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                        activeLetter = nil
                    }
            )
            .overlay(alignment: .center) {
                if isDragging, let activeLetter {
                    Text(activeLetter)
                        .font(.system(size: 34, weight: .bold, design: .serif))
                        .frame(width: 72, height: 72)
                        .background(.ultraThinMaterial, in: Circle())
                        .offset(x: -70)
                }
            }
        }
        .frame(width: 22)
        .padding(.trailing, 6)
        .padding(.vertical, 10)
    }
}
#endif
