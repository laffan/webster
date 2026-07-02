import SwiftUI

/// Apple Watch app entry point.
@main
struct WebsterDictionaryWatchApp: App {
    @StateObject private var store = DictionaryStore()
    @StateObject private var recents = RecentsStore()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(store)
                .environmentObject(recents)
        }
    }
}
