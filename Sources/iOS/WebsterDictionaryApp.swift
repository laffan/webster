import SwiftUI

/// iPhone & iPad app entry point.
@main
struct WebsterDictionaryApp: App {
    @StateObject private var store = DictionaryStore()
    @StateObject private var history = HistoryStore()
    @StateObject private var favorites = FavoritesStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .environmentObject(history)
                .environmentObject(favorites)
        }
    }
}
