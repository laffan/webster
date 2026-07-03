import SwiftUI

/// Apple Watch root: a single navigation stack whose menu pushes each of the
/// shared screens; those screens push definition panes via `NavigationLink`.
struct WatchRootView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    SearchContent()
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }

                NavigationLink {
                    BrowseContent()
                } label: {
                    Label("Browse", systemImage: "list.bullet")
                }

                NavigationLink {
                    RandomContent()
                } label: {
                    Label("Random", systemImage: "shuffle")
                }

                NavigationLink {
                    FavoritesContent()
                } label: {
                    Label("Favorites", systemImage: "star")
                }
            }
            .navigationTitle("Webster")
        }
    }
}
