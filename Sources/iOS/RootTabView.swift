import SwiftUI

/// Three-tab layout for iPhone and iPad: Search, Random, Recent. Each tab owns
/// its own `NavigationStack` so navigation state is independent per tab.
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
                RandomContent()
            }
            .tabItem {
                Label("Random", systemImage: "shuffle")
            }

            NavigationStack {
                RecentsContent()
            }
            .tabItem {
                Label("Recent", systemImage: "clock")
            }
        }
    }
}
