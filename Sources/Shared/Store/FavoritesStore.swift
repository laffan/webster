import Foundation
import Combine

/// Words the user has flagged as favorites, most-recently-added first,
/// persisted per device.
///
/// Unlike `HistoryStore`, favorites are a deliberate, uncapped collection: the
/// user adds and removes them by hand (via the touch-and-hold menu on any word).
/// A `Set` backs membership checks so `isFavorite` stays O(1) even when it is
/// queried once per visible row.
@MainActor
final class FavoritesStore: ObservableObject {
    /// Favorited headwords, newest first. Drives the Favorites list.
    @Published private(set) var words: [String] = []

    private var membership: Set<String> = []

    private let key = "favorite_words_v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func isFavorite(_ rawWord: String) -> Bool {
        membership.contains(rawWord.lowercased())
    }

    /// Adds the word if absent, removes it if present. Newly added words go to
    /// the top of the list.
    func toggle(_ rawWord: String) {
        let word = rawWord.lowercased()
        guard !word.isEmpty else { return }
        if membership.contains(word) {
            remove(word)
        } else {
            membership.insert(word)
            words.insert(word, at: 0)
            persist()
        }
    }

    func remove(_ rawWord: String) {
        let word = rawWord.lowercased()
        guard membership.remove(word) != nil else { return }
        words.removeAll { $0 == word }
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        defaults.set(words, forKey: key)
    }

    private func load() {
        words = defaults.stringArray(forKey: key) ?? []
        membership = Set(words)
    }
}
