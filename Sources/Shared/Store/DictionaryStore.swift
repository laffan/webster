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

    func randomEntry() -> DictionaryEntry? {
        database?.randomEntry()
    }
}
