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

    /// Title-cased headword for display (e.g. "Serendipity", "The Gapes").
    var titleCased: String { word.capitalized }
}
