import SwiftUI

/// Browse screen: every headword in one long list, divided into large
/// alphabetical section headers. On iOS an A–Z index down the trailing edge
/// jumps (and scrubs) to a section.
struct BrowseContent: View {
    @EnvironmentObject private var store: DictionaryStore
    @State private var sections: [BrowseSection] = []

    var body: some View {
        ScrollViewReader { proxy in
            Group {
                if sections.isEmpty {
                    ProgressView()
                } else {
                    List {
                        ForEach(sections) { section in
                            Section {
                                ForEach(section.headwords) { headword in
                                    NavigationLink(value: headword) {
                                        Text(headword.titleCased)
                                            .font(.system(.body, design: .serif))
                                    }
                                }
                            } header: {
                                Text(section.letter)
                                    .font(.system(.title2, design: .serif).weight(.bold))
                                    .foregroundStyle(.primary)
                                    .textCase(nil)
                            }
                            .id(section.letter)
                        }
                    }
                    #if os(iOS)
                    .overlay(alignment: .trailing) {
                        SectionIndexBar(letters: sections.map(\.letter)) { letter in
                            proxy.scrollTo(letter, anchor: .top)
                        }
                    }
                    #endif
                }
            }
            .navigationDestination(for: Headword.self) { headword in
                if let entry = store.entry(id: headword.id) {
                    DefinitionView(entry: entry, recordAs: .lookup)
                }
            }
            .task {
                if sections.isEmpty {
                    sections = await store.loadBrowseSections()
                }
            }
        }
    }
}

#if os(iOS)
/// A Contacts-style A–Z index. Tapping or dragging reports the letter under the
/// finger so the list can scroll to that section.
private struct SectionIndexBar: View {
    let letters: [String]
    let onSelect: (String) -> Void

    @State private var lastLetter: String?

    var body: some View {
        GeometryReader { geo in
            let rowHeight = geo.size.height / CGFloat(max(letters.count, 1))
            VStack(spacing: 0) {
                ForEach(letters, id: \.self) { letter in
                    Text(letter)
                        .font(.system(size: 10, weight: .semibold))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let index = Int(value.location.y / rowHeight)
                        guard letters.indices.contains(index) else { return }
                        let letter = letters[index]
                        if letter != lastLetter {
                            lastLetter = letter
                            onSelect(letter)
                        }
                    }
                    .onEnded { _ in lastLetter = nil }
            )
        }
        .frame(width: 18)
        .foregroundStyle(.tint)
        .padding(.trailing, 2)
    }
}
#endif
