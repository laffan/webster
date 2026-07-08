import SwiftUI

/// Tab layout for iPhone and iPad: Search, Browse, Random, Favorites. Each tab
/// owns its own `NavigationStack` so navigation state is independent per tab.
/// (Recent searches live in the Search tab, not a tab of their own.)
///
/// The app opens on **Random** so there's a word to explore the moment it
/// launches, rather than an empty search field.
struct RootTabView: View {
    private enum Tab: Hashable { case search, browse, random, favorites }

    @State private var selection: Tab = .random

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                SearchContent()
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
            .tag(Tab.search)

            NavigationStack {
                BrowseContent()
            }
            .tabItem {
                Label("Browse", systemImage: "list.bullet")
            }
            .tag(Tab.browse)

            NavigationStack {
                RandomContent()
            }
            .tabItem {
                Label("Random", systemImage: "shuffle")
            }
            .tag(Tab.random)

            NavigationStack {
                FavoritesContent()
            }
            .tabItem {
                Label("Favorites", systemImage: "star")
            }
            .tag(Tab.favorites)
        }
    }
}
