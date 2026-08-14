import SwiftUI

struct ContentView: View {
    @Environment(AppStore.self) var store

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Ledger", systemImage: "house") }
            AddIncomeView()
                .tabItem { Label("Add", systemImage: "plus.circle.fill") }
            CalendarView()
                .tabItem { Label("Subs", systemImage: "calendar") }
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
