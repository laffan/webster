import SwiftUI

/// Tab layout for iPhone and iPad: Search, Browse, Random, Favorites. Each tab
/// owns its own `NavigationStack` so navigation state is independent per tab.
/// (Recent searches live in the Search tab, not a tab of their own.)
struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                SearchContent()
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }

            NavigationStack {
                BrowseContent()
            }
            .tabItem {
                Label("Browse", systemImage: "list.bullet")
            }

            NavigationStack {
                RandomContent()
            }
            .tabItem {
                Label("Random", systemImage: "shuffle")
            }

            NavigationStack {
                FavoritesContent()
            }
            .tabItem {
                Label("Favorites", systemImage: "star")
            }
        }
    }
}
