import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppStore.self) var store
    @State private var showResetConfirm = false
    @State private var resetText        = ""
    @State private var showExporter     = false
    @State private var showImporter     = false
    @State private var showImportConfirm = false
    @State private var backupDocument: MoonayBackupDocument?
    @State private var pendingImport: AppState?
    @State private var dataMessage: String?
    @State private var pinEnabled = AppLockManager.isPINEnabled
    @State private var decoyEnabled = AppLockManager.isDecoyEnabled
    @State private var faceIDEnabled = BiometricAuth.isEnabled
    @State private var paydayRemindersEnabled = PaydayNotifications.isEnabled
    @State private var transferRemindersEnabled = RecurringTransferNotifications.isEnabled
    @State private var pinSheetKind: PINSheetKind?
    @State private var showRemovePINConfirm = false
    @State private var editingColorTab: AppTab?

    private enum PINSheetKind: Identifiable {
        case real, decoy
        var id: Self { self }
    }

    var body: some View {
        let accentColor = store.accentColor(for: .settings)
        NavigationStack {
            List {
                if !store.isDecoyMode {
                    Section("Security") { securityRows }
                    Section("Notifications") { notificationRows }
                }

                Section {
                    ColorSwatchPicker(
                        selectedHex: Binding(
                            get: { store.state.accentColorHex },
                            set: { store.setAccentColor(hex: $0) }
                        ),
                        palette: accentPalette
                    )
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Sets the app's default color. Tap the dashed circle to add a custom color, saved for reuse everywhere.")
                }

                Section {
                    ForEach(AppTab.allCases) { tab in
                        tabColorRow(tab)
                    }
                } header: {
                    Text("Tab Colors")
                } footer: {
                    Text("Each tab can have its own color, used for its buttons, links, and highlights. Defaults to the color above.")
                }

                Section("Manage") {
                    NavigationLink { BucketsSettingsView() } label: {
                        SettingsLabel("Buckets", systemImage: "tray.2.fill", color: Color(hex: "#5856D6"))
                    }
                    NavigationLink { BillsSettingsView() } label: {
                        SettingsLabel("Bills", systemImage: "doc.text.fill", color: Color(hex: "#FF9500"))
                    }
                    NavigationLink { CreditCardsSettingsView() } label: {
                        SettingsLabel("Credit Cards", systemImage: "creditcard.fill", color: Color(hex: "#007AFF"))
                    }
                    NavigationLink { IncomeSourcesSettingsView() } label: {
                        SettingsLabel("Income Sources", systemImage: "dollarsign", color: Color(hex: "#34C759"))
                    }
                    NavigationLink { RecurringTransfersSettingsView() } label: {
                        SettingsLabel("Recurring Transfers", systemImage: "arrow.triangle.2.circlepath", color: Color(hex: "#30B0C7"))
                    }
                    NavigationLink { PayScheduleSettingsView() } label: {
                        SettingsLabel("Paycheck Schedule", systemImage: "calendar.badge.clock", color: Color(hex: "#FF2D55"))
                    }
                }

                Section("Records") {
                    NavigationLink { HistoryView() } label: {
                        SettingsLabel("History", systemImage: "clock.arrow.circlepath", color: Color(hex: "#8E8E93"))
                    }
                    NavigationLink { NotesView() } label: {
                        SettingsLabel("Notes", systemImage: "note.text", color: Color(hex: "#FFCC00"))
                    }
                }

                if !store.isDecoyMode {
                    Section("Bank Connection") {
                        NavigationLink { BankConnectionSettingsView() } label: {
                            SettingsLabel("Connect Bank Account", systemImage: "building.columns.fill", color: Color(hex: "#00C7BE"))
                        }
                    }
                }

                Section("Data") {
                    Button { startExport() } label: {
                        SettingsLabel("Export Backup", systemImage: "square.and.arrow.up", color: Color(hex: "#007AFF"))
                    }
                    Button { showImporter = true } label: {
                        SettingsLabel("Import Backup", systemImage: "square.and.arrow.down", color: Color(hex: "#5856D6"))
                    }
                    Button(role: .destructive) { showResetConfirm = true } label: {
                        SettingsLabel("Reset All Data", systemImage: "trash.fill", color: Color(hex: "#FF3B30"), titleColor: .red)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .screenBackground()
            .navigationTitle("Settings")
            .sheet(item: $pinSheetKind) { kind in
                switch kind {
                case .real:
                    SetPINView(title: "Set PIN") { pin in
                        AppLockManager.setPIN(pin)
                        pinEnabled = true
                    }
                case .decoy:
                    SetPINView(title: "Set Decoy PIN") { pin in
                        AppLockManager.setDecoyPIN(pin)
                        decoyEnabled = true
                    }
                }
            }
            .confirmationDialog("Remove PIN Lock?", isPresented: $showRemovePINConfirm, titleVisibility: .visible) {
                Button("Remove PIN", role: .destructive) {
                    AppLockManager.removePIN()
                    pinEnabled = false
                    decoyEnabled = false
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(decoyEnabled ? "This also removes your decoy PIN." : "The app will open without a PIN.")
            }
            .sheet(isPresented: $showResetConfirm) {
                ResetDataView(resetText: $resetText) {
                    store.clearFinancialData()
                    resetText = ""
                    showResetConfirm = false
                    dataMessage = "Financial history cleared."
                }
            }
            .confirmationDialog("Restore Backup?", isPresented: $showImportConfirm, titleVisibility: .visible) {
                Button("Restore Backup", role: .destructive) {
                    if let pendingImport {
                        store.restoreBackup(pendingImport)
                        dataMessage = "Backup restored."
                    }
                    pendingImport = nil
                }
                Button("Cancel", role: .cancel) { pendingImport = nil }
            } message: {
                Text("This replaces the data currently on this device. Export a backup first if you want to keep it.")
            }
            .fileExporter(
                isPresented: $showExporter,
                document: backupDocument,
                contentType: .json,
                defaultFilename: "Moonay Backup \(todayISO())"
            ) { result in
                switch result {
                case .success:
                    dataMessage = "Backup exported."
                case .failure(let error):
                    dataMessage = error.localizedDescription
                }
                backupDocument = nil
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                handleImport(result)
            }
            .alert("Moonay Data", isPresented: Binding(
                get: { dataMessage != nil },
                set: { if !$0 { dataMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(dataMessage ?? "")
            }
            .sheet(item: $editingColorTab) { tab in
                TabColorPickerView(tab: tab)
            }
        }
        .environment(\.tabAccentColor, accentColor)
    }

    // Each `*Rows` group is a separate property only to keep the `body`
    // expression small enough for the type-checker — inlining any one of
    // them pushes the whole List over its time limit.

    @ViewBuilder
    private var securityRows: some View {
        Toggle(isOn: Binding(
            get: { pinEnabled },
            set: { newValue in
                if newValue { pinSheetKind = .real } else { showRemovePINConfirm = true }
            }
        )) {
            SettingsLabel("Require PIN", systemImage: "lock.fill", color: Color(hex: "#FF3B30"))
        }
        if pinEnabled {
            Button {
                pinSheetKind = .decoy
            } label: {
                HStack {
                    SettingsLabel("Decoy PIN", systemImage: "theatermasks.fill", color: Color(hex: "#AF52DE"))
                    Spacer()
                    Text(decoyEnabled ? "Change" : "Set Up").foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
            }
            .foregroundStyle(.primary)
            if decoyEnabled {
                Button(role: .destructive) {
                    AppLockManager.removeDecoyPIN()
                    decoyEnabled = false
                } label: {
                    SettingsLabel("Remove Decoy PIN", systemImage: "theatermasks", color: Color(hex: "#8E8E93"), titleColor: .red)
                }
            }
            if BiometricAuth.isAvailable {
                Toggle(isOn: Binding(
                    get: { faceIDEnabled },
                    set: { newValue in
                        faceIDEnabled = newValue
                        BiometricAuth.isEnabled = newValue
                    }
                )) {
                    SettingsLabel("Unlock with Face ID", systemImage: "faceid", color: Color(hex: "#34C759"))
                }
            }
        }
    }

    @ViewBuilder
    private var notificationRows: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: Binding(
                get: { paydayRemindersEnabled },
                set: { newValue in
                    PaydayNotifications.setEnabled(newValue, schedule: store.state.paySchedule) { granted in
                        paydayRemindersEnabled = granted
                    }
                }
            )) {
                SettingsLabel("Payday Reminders", systemImage: "bell.badge.fill", color: Color(hex: "#FF9500"))
            }
            if paydayRemindersEnabled && store.state.paySchedule == nil {
                Text("Set a pay schedule to start getting reminders.")
                    .font(.caption).foregroundStyle(Color.helperText)
                    .padding(.leading, 41)
            }
        }
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: Binding(
                get: { transferRemindersEnabled },
                set: { newValue in
                    RecurringTransferNotifications.setEnabled(newValue, transfers: store.state.recurringTransfers) { granted in
                        transferRemindersEnabled = granted
                    }
                }
            )) {
                SettingsLabel("Transfer Reminders", systemImage: "bell.fill", color: Color(hex: "#30B0C7"))
            }
            if transferRemindersEnabled && !store.state.recurringTransfers.contains(where: { $0.isActive }) {
                Text("Turn on a recurring transfer to start getting reminders.")
                    .font(.caption).foregroundStyle(Color.helperText)
                    .padding(.leading, 41)
            }
        }
    }

    @ViewBuilder
    private func tabColorRow(_ tab: AppTab) -> some View {
        Button { editingColorTab = tab } label: {
            HStack {
                SettingsLabel(tab.label, systemImage: tab.systemImage, color: store.accentColor(for: tab))
                Spacer()
                Circle()
                    .fill(store.accentColor(for: tab))
                    .frame(width: 18, height: 18)
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(.primary)
    }

    private func startExport() {
        do {
            backupDocument = MoonayBackupDocument(data: try store.backupData())
            showExporter = true
        } catch {
            dataMessage = error.localizedDescription
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let data = try Data(contentsOf: url)
            pendingImport = try store.decodedBackup(from: data)
            showImportConfirm = true
        } catch {
            dataMessage = error.localizedDescription
        }
    }
}

// iOS-Settings-style row label: a colored icon tile followed by the title.
struct SettingsLabel: View {
    let title: String
    let systemImage: String
    let color: Color
    var titleColor: Color = .primary

    init(_ title: String, systemImage: String, color: Color, titleColor: Color = .primary) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
        self.titleColor = titleColor
    }

    var body: some View {
        HStack(spacing: 12) {
            IconTile(systemName: systemImage, color: color, size: 29)
            Text(title)
                .foregroundStyle(titleColor)
        }
    }
}

extension AppTab {
    var systemImage: String {
        switch self {
        case .ledger:        return "house.fill"
        case .add:           return "plus"
        case .subscriptions: return "calendar"
        case .settings:      return "gearshape.fill"
        }
    }
}
