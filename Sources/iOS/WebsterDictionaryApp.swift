import SwiftUI

/// iPhone & iPad app entry point.
@main
struct WebsterDictionaryApp: App {
    @StateObject private var store = DictionaryStore()
    @StateObject private var recents = RecentsStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .environmentObject(recents)
        }
    }
}
