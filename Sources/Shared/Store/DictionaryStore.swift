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
