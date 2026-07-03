import Foundation
import SQLite3

/// Passing `SQLITE_TRANSIENT` to `sqlite3_bind_text` tells SQLite to make its
/// own copy of the bound string, which is required because the Swift `String`
/// backing store may be released before the statement is stepped.
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Read-only access to the bundled Webster dictionary database.
///
/// The database ships as a prebuilt SQLite file (`dictionary.sqlite`) so the app
/// works fully offline and never has to hold the ~100k entries in memory at
/// once. Queries hit an index on the lowercased headword, so prefix search stays
/// instant even on Apple Watch.
final class DictionaryDatabase {
    private var db: OpaquePointer?

    /// Total number of entries, cached at open time.
    let entryCount: Int

    init?(resource: String = "dictionary", withExtension ext: String = "sqlite") {
        guard let url = Bundle.main.url(forResource: resource, withExtension: ext) else {
            assertionFailure("Missing \(resource).\(ext) in the app bundle.")
            return nil
        }

        var handle: OpaquePointer?
        guard sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let handle else {
            if let handle { sqlite3_close(handle) }
            return nil
        }
        self.db = handle

        // Count once up front so `randomEntry()` can pick an id cheaply.
        var count = 0
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(handle, "SELECT COUNT(*) FROM entries;", -1, &stmt, nil) == SQLITE_OK,
           sqlite3_step(stmt) == SQLITE_ROW {
            count = Int(sqlite3_column_int64(stmt, 0))
        }
        sqlite3_finalize(stmt)
        self.entryCount = count
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    // MARK: - Queries

    /// Headwords beginning with `prefix`, shortest first (so an exact match such
    /// as "serene" sorts above "serenely").
    func search(prefix rawPrefix: String, limit: Int = 60) -> [DictionaryEntry] {
        let query = normalize(rawPrefix)
        guard !query.isEmpty else { return [] }

        let pattern = escapeForLike(query) + "%"
        let sql = """
        SELECT id, word, definition FROM entries
        WHERE word_lower LIKE ? ESCAPE '\\'
        ORDER BY length(word_lower), word_lower
        LIMIT ?;
        """
        return run(sql) { stmt in
            sqlite3_bind_text(stmt, 1, pattern, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 2, Int32(limit))
        }
    }

    /// The exact entry for a headword, if one exists.
    func entry(for rawWord: String) -> DictionaryEntry? {
        let word = normalize(rawWord)
        guard !word.isEmpty else { return nil }
        let sql = "SELECT id, word, definition FROM entries WHERE word_lower = ? LIMIT 1;"
        return run(sql) { stmt in
            sqlite3_bind_text(stmt, 1, word, -1, SQLITE_TRANSIENT)
        }.first
    }

    /// A pseudo-random entry, used by the Random screen.
    func randomEntry() -> DictionaryEntry? {
        guard entryCount > 0 else { return nil }
        let target = Int.random(in: 1...entryCount)
        // `>=` tolerates any gaps in the rowid sequence and wraps to the first
        // row if we land past the last id.
        let sql = "SELECT id, word, definition FROM entries WHERE id >= ? ORDER BY id LIMIT 1;"
        let results = run(sql) { stmt in sqlite3_bind_int64(stmt, 1, Int64(target)) }
        return results.first ?? entry(id: 1)
    }

    func entry(id: Int) -> DictionaryEntry? {
        let sql = "SELECT id, word, definition FROM entries WHERE id = ? LIMIT 1;"
        return run(sql) { stmt in sqlite3_bind_int64(stmt, 1, Int64(id)) }.first
    }

    /// Loads every headword (id + word, no definitions) sorted alphabetically,
    /// for the Browse screen.
    ///
    /// Opens its own read-only connection so it is safe to call off the main
    /// thread — SQLite connections must not be shared across threads, but
    /// separate connections to the same file are fine for reading.
    static func loadHeadwords(resource: String = "dictionary",
                              withExtension ext: String = "sqlite") -> [Headword] {
        guard let url = Bundle.main.url(forResource: resource, withExtension: ext) else {
            return []
        }
        var handle: OpaquePointer?
        guard sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let handle else {
            if let handle { sqlite3_close(handle) }
            return []
        }
        defer { sqlite3_close(handle) }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, "SELECT id, word FROM entries ORDER BY word_lower;",
                                 -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        var result: [Headword] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = Int(sqlite3_column_int64(stmt, 0))
            guard let wordC = sqlite3_column_text(stmt, 1) else { continue }
            result.append(Headword(id: id, word: String(cString: wordC)))
        }
        return result
    }

    // MARK: - Helpers

    private func run(_ sql: String, bind: (OpaquePointer?) -> Void) -> [DictionaryEntry] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        bind(stmt)

        var entries: [DictionaryEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = Int(sqlite3_column_int64(stmt, 0))
            guard let wordC = sqlite3_column_text(stmt, 1),
                  let defC = sqlite3_column_text(stmt, 2) else { continue }
            entries.append(
                DictionaryEntry(id: id,
                                word: String(cString: wordC),
                                definition: String(cString: defC))
            )
        }
        return entries
    }

    private func normalize(_ string: String) -> String {
        string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Escapes SQL `LIKE` wildcards so a user typing "%" searches for a literal
    /// percent sign rather than "match anything".
    private func escapeForLike(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }
}
