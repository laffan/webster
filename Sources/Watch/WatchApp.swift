import SwiftUI

/// Apple Watch app entry point.
@main
struct WebsterDictionaryWatchApp: App {
    @StateObject private var store = DictionaryStore()
    @StateObject private var history = HistoryStore()
    @StateObject private var favorites = FavoritesStore()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(store)
                .environmentObject(history)
                .environmentObject(favorites)
        }
    }
}
