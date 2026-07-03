import SwiftUI

/// Apple Watch root: a single navigation stack whose menu pushes each of the
/// shared screens. The shared content views declare their own
/// `navigationDestination`, which resolves within this stack.
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
                    RecentsContent()
                } label: {
                    Label("Recent", systemImage: "clock")
                }
            }
            .navigationTitle("Webster")
        }
    }
}
