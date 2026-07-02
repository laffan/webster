import Foundation

/// A single headword and its definition from Webster's Revised Unabridged
/// Dictionary (1913).
///
/// The dataset stores headwords in lowercase. `displayWord` renders them in the
/// small-caps style Webster used for headwords, while `title` is the friendlier
/// capitalized form used for navigation titles and list rows.
struct DictionaryEntry: Identifiable, Hashable, Codable {
    let id: Int
    let word: String
    let definition: String

    /// Webster printed headwords in capitals (e.g. "SERENDIPITY").
    var displayWord: String { word.uppercased() }

    /// Capitalized form for list rows and navigation titles (e.g. "Serendipity").
    var title: String {
        guard let first = word.first else { return word }
        return first.uppercased() + word.dropFirst()
    }
}
