import Foundation
import Combine

/// Tracks recently viewed headwords, most-recent first, persisted per device.
///
/// Stored as a plain list of lowercase words in `UserDefaults`; the display
/// entries are re-resolved from the database on demand so we never persist stale
/// definition text.
@MainActor
final class RecentsStore: ObservableObject {
    @Published private(set) var words: [String] = []

    private let key = "recent_words"
    private let maxCount = 100
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.words = defaults.stringArray(forKey: key) ?? []
    }

    /// Records a visit, moving the word to the top and de-duplicating.
    func record(_ rawWord: String) {
        let word = rawWord.lowercased()
        guard !word.isEmpty else { return }

        var updated = words.filter { $0 != word }
        updated.insert(word, at: 0)
        if updated.count > maxCount {
            updated = Array(updated.prefix(maxCount))
        }
        words = updated
        persist()
    }

    func remove(atOffsets offsets: IndexSet) {
        words.remove(atOffsets: offsets)
        persist()
    }

    func clear() {
        words = []
        persist()
    }

    private func persist() {
        defaults.set(words, forKey: key)
    }
}
