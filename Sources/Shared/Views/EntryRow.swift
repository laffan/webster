import SwiftUI

/// Compact list row: a capitalized headword above a two-line definition preview.
struct EntryRow: View {
    let entry: DictionaryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.titleCased)
                .font(.system(.headline, design: .serif))
            Text(entry.definition)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }
}
