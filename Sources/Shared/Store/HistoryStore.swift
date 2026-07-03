import Foundation
import Combine

/// How a word entered the history.
enum HistorySource: String, Codable, CaseIterable {
    case lookup   // viewed from Search
    case browse   // legacy: expanded in the old Browse accordion
    case random   // surfaced in the Random screen
}

/// A seen headword tagged with how it was encountered.
struct HistoryItem: Identifiable, Codable, Hashable {
    let word: String
    let source: HistorySource
    var id: String { word }
}

/// Tracks seen headwords, most-recent first, persisted per device.
///
/// Each word is remembered once (the newest encounter wins) and tagged with its
/// `source` so the History screen can split it into "Lookup" and "Random"
/// sections. The display entries are re-resolved from the database on demand so
/// we never persist stale definition text.
@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var items: [HistoryItem] = []

    // Persistence keys keep their original "recent" names so existing installs
    // carry their history forward through the rename.
    private let key = "recent_items_v1"
    private let legacyKey = "recent_words"
    private let maxCount = 100
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    var lookups: [HistoryItem] { items.filter { $0.source == .lookup } }
    var browses: [HistoryItem] { items.filter { $0.source == .browse } }
    var randoms: [HistoryItem] { items.filter { $0.source == .random } }

    /// Records a visit, moving the word to the top and de-duplicating. If the
    /// word was already present it adopts the new source.
    func record(_ rawWord: String, source: HistorySource) {
        let word = rawWord.lowercased()
        guard !word.isEmpty else { return }

        var updated = items.filter { $0.word != word }
        updated.insert(HistoryItem(word: word, source: source), at: 0)
        if updated.count > maxCount {
            updated = Array(updated.prefix(maxCount))
        }
        items = updated
        persist()
    }

    /// Removes items at `offsets` within the given section.
    func remove(source: HistorySource, atOffsets offsets: IndexSet) {
        let section = items.filter { $0.source == source }
        let wordsToRemove = Set(offsets.map { section[$0].word })
        items.removeAll { $0.source == source && wordsToRemove.contains($0.word) }
        persist()
    }

    func clear() {
        items = []
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: key)
        }
    }

    private func load() {
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            items = decoded
            return
        }
        // Migrate the previous flat list of words into the Lookup section.
        if let legacy = defaults.stringArray(forKey: legacyKey), !legacy.isEmpty {
            items = legacy.map { HistoryItem(word: $0, source: .lookup) }
            persist()
        }
    }
}
