import Foundation
import Combine

/// App-wide facade over the bundled dictionary database.
///
/// Injected into the SwiftUI environment at the app root and shared by every
/// screen. It is a thin, main-actor wrapper: the actual work happens in
/// `DictionaryDatabase`, and prefix queries are fast enough (indexed lookups on
/// ~100k rows) to run synchronously as the user types.
@MainActor
final class DictionaryStore: ObservableObject {
    private let database: DictionaryDatabase?

    /// Number of headwords available, shown in the search placeholder.
    let entryCount: Int

    /// `false` if the bundled database could not be opened.
    var isReady: Bool { database != nil }

    init() {
        let database = DictionaryDatabase()
        self.database = database
        self.entryCount = database?.entryCount ?? 0
    }

    func search(_ query: String) -> [DictionaryEntry] {
        database?.search(prefix: query) ?? []
    }

    func entry(for word: String) -> DictionaryEntry? {
        database?.entry(for: word)
    }

    func entry(id: Int) -> DictionaryEntry? {
        database?.entry(id: id)
    }

    func randomEntry() -> DictionaryEntry? {
        database?.randomEntry()
    }

    // MARK: - Browse

    private var cachedBrowseSections: [BrowseSection]?

    /// All headwords grouped into alphabetical sections for the Browse screen.
    /// The heavy load + grouping runs off the main thread; the result is cached
    /// so subsequent visits are instant.
    func loadBrowseSections() async -> [BrowseSection] {
        if let cachedBrowseSections { return cachedBrowseSections }
        let sections = await Task.detached(priority: .userInitiated) {
            DictionaryStore.buildSections(from: DictionaryDatabase.loadHeadwords())
        }.value
        cachedBrowseSections = sections
        return sections
    }

    // A tiny LRU of fully-loaded letters so hopping between recently-viewed
    // letters is instant. Each letter's worth of definition text is a few MB;
    // keeping a handful is comfortable on iOS and avoids re-querying on revisit.
    private var browseEntries: [String: [DictionaryEntry]] = [:]
    private var browseEntryOrder: [String] = []
    private let browseEntryCacheLimit = 4

    /// The full entries (with definitions) for one Browse letter, in the same
    /// alphabetical order as the section's headwords. The bulk DB fetch runs off
    /// the main thread; results are cached so revisiting a letter is instant.
    func loadBrowseEntries(for section: BrowseSection) async -> [DictionaryEntry] {
        if let cached = browseEntries[section.letter] {
            touchBrowseCache(section.letter)
            return cached
        }
        let ids = section.headwords.map(\.id)
        let byID = await Task.detached(priority: .userInitiated) {
            DictionaryDatabase.loadEntries(ids: ids)
        }.value
        let ordered = section.headwords.compactMap { byID[$0.id] }

        browseEntries[section.letter] = ordered
        touchBrowseCache(section.letter)
        while browseEntryOrder.count > browseEntryCacheLimit {
            browseEntries.removeValue(forKey: browseEntryOrder.removeFirst())
        }
        return ordered
    }

    private func touchBrowseCache(_ letter: String) {
        browseEntryOrder.removeAll { $0 == letter }
        browseEntryOrder.append(letter)
    }

    nonisolated static func buildSections(from headwords: [Headword]) -> [BrowseSection] {
        var groups: [String: [Headword]] = [:]
        for headword in headwords {
            groups[sectionKey(for: headword.word), default: []].append(headword)
        }
        // A–Z first (in order), with the non-letter "#" bucket last.
        let letters = groups.keys.sorted { lhs, rhs in
            if lhs == "#" { return false }
            if rhs == "#" { return true }
            return lhs < rhs
        }
        return letters.map { BrowseSection(letter: $0, headwords: groups[$0]!) }
    }

    /// The section a word belongs to: its uppercased initial (accents folded to
    /// a base A–Z letter), or "#" for anything not starting with a letter.
    nonisolated static func sectionKey(for word: String) -> String {
        guard let first = word.first else { return "#" }
        guard first.isLetter else { return "#" }
        let folded = String(first).folding(options: .diacriticInsensitive, locale: nil).uppercased()
        if let base = folded.first, base.isLetter, base.isASCII {
            return String(base)
        }
        return String(first).uppercased()
    }
}
