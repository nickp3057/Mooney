import SwiftUI

struct ContentView: View {
    @Environment(AppStore.self) var store

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Ledger", systemImage: "house") }
            AddIncomeView()
                .tabItem { Label("Income", systemImage: "plus.circle") }
            HistoryView()
                .tabItem { Label("History", systemImage: "list.bullet") }
            CalendarView()
                .tabItem { Label("Subscriptions", systemImage: "calendar") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .tint(store.accentColor)
        .fullScreenCover(isPresented: Bindable(store).isLocked) {
            LockView()
        }
    }
}

#Preview {
    ContentView()
        .environment(AppStore())
}
