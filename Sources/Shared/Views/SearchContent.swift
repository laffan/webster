import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Search screen contents. Expects to be hosted inside a `NavigationStack`
/// (each platform provides its own), so it declares a `navigationDestination`
/// but no stack of its own.
///
/// iOS uses a custom search bar with a paste button; watchOS keeps the system
/// `.searchable` field (which offers dictation/scribble and has no clipboard).
struct SearchContent: View {
    @EnvironmentObject private var store: DictionaryStore
    @State private var query = ""
    @State private var results: [DictionaryEntry] = []

    var body: some View {
        #if os(iOS)
        VStack(spacing: 0) {
            SearchBar(query: $query, placeholder: searchPrompt)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)
            resultsList
        }
        #else
        resultsList
            .searchable(text: $query, prompt: searchPrompt)
            .searchFieldStyling()
        #endif
    }

    private var resultsList: some View {
        List(results) { entry in
            NavigationLink(value: entry) {
                EntryRow(entry: entry)
            }
        }
        .navigationDestination(for: DictionaryEntry.self) { entry in
            DefinitionView(entry: entry, recordAs: .lookup)
        }
        .overlay {
            if query.isEmpty {
                ContentUnavailableView(
                    "Webster's Dictionary",
                    systemImage: "character.book.closed",
                    description: Text("Search \(store.entryCount.formatted()) definitions from the 1913 Revised Unabridged edition.")
                )
            } else if results.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        // Debounce: re-run only after typing pauses briefly; `.task(id:)`
        // cancels the previous query on each keystroke.
        .task(id: query) {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            results = store.search(query)
        }
    }

    private var searchPrompt: String {
        store.entryCount > 0 ? "Search \(store.entryCount.formatted()) words" : "Search"
    }
}

#if os(iOS)
/// A rounded search field with a magnifying glass, an inline clear button, and a
/// paste button that fills the field from the clipboard.
private struct SearchBar: View {
    @Binding var query: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $query)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear")
            }

            Button {
                if let string = UIPasteboard.general.string {
                    query = string.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } label: {
                Image(systemName: "doc.on.clipboard")
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Paste")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
#endif
