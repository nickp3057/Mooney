import SwiftUI
import UIKit
import BackgroundTasks

@main
struct MoonayApp: App {
    // Registered in Info.plist under BGTaskSchedulerPermittedIdentifiers.
    static let refreshTaskID = "com.nickpearson.Mooney.refresh"

    @State private var store = AppStore.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Applies to every List in the app in one place, rather than each
        // screen individually — a Spotify-style near-black instead of pure
        // system black.
        UITableView.appearance().backgroundColor = UIColor(Color(hex: appBackgroundHex))
        MoonayApp.registerRefreshTask()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                store.runScheduledTransfers()
                store.ensureCardPayments()
            } else if newPhase == .background {
                store.lock()
                MoonayApp.scheduleRefresh()
            }
        }
    }

    // A BGAppRefreshTask backstop so the weekly recurring transfers post
    // (and card payments catch up, and the reminder window refills) even
    // when the app isn't opened for days. iOS decides when to actually run
    // it — typically within a day for a regularly used app, but never
    // guaranteed and never precisely on time — so the launch/foreground
    // catch-up in ContentView/AppStore stays the primary mechanism.
    private static var didRegister = false

    static func registerRefreshTask() {
        guard !didRegister else { return }
        didRegister = true
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshTaskID, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handleRefresh(task)
        }
        scheduleRefresh()
    }

    static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        // Earliest, not exact — iOS runs it when it sees fit after this.
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handleRefresh(_ task: BGAppRefreshTask) {
        // Chain the next one first, so a throw/early-return below can't
        // break the cycle.
        scheduleRefresh()
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        DispatchQueue.main.async {
            let store = AppStore.shared
            store.runScheduledTransfers()
            store.ensureCardPayments()
            RecurringTransferNotifications.reschedule(from: store.state.recurringTransfers)
            task.setTaskCompleted(success: true)
        }
    }
}
