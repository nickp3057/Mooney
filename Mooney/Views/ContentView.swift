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
            NotesView()
                .tabItem { Label("Notes", systemImage: "doc.text") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .tint(store.accentColor)
    }
}

#Preview {
    ContentView()
        .environment(AppStore())
}
