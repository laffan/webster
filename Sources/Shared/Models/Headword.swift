import Foundation

/// A lightweight headword (no definition text) for the Browse list, where we
/// load all ~100k entries and only need the word and its id.
struct Headword: Identifiable, Hashable, Sendable {
    let id: Int
    let word: String

    var titleCased: String { word.capitalized }
}

/// A run of headwords sharing an initial letter, used as a Browse section.
struct BrowseSection: Identifiable, Sendable {
    let letter: String
    let headwords: [Headword]

    var id: String { letter }
}
