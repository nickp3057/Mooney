import SwiftUI

@main
struct MoonayApp: App {
    @State private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                store.runScheduledTransfers()
            }
        }
    }
}
