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
                    Section("App Lock") {
                        Toggle("Require PIN", isOn: Binding(
                            get: { pinEnabled },
                            set: { newValue in
                                if newValue {
                                    pinSheetKind = .real
                                } else {
                                    showRemovePINConfirm = true
                                }
                            }
                        ))
                        if pinEnabled {
                            Button {
                                pinSheetKind = .decoy
                            } label: {
                                HStack {
                                    Text("Decoy PIN")
                                    Spacer()
                                    Text(decoyEnabled ? "Change" : "Set Up")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .foregroundStyle(.primary)
                            if decoyEnabled {
                                Button("Remove Decoy PIN", role: .destructive) {
                                    AppLockManager.removeDecoyPIN()
                                    decoyEnabled = false
                                }
                            }
                            if BiometricAuth.isAvailable {
                                Toggle("Unlock with Face ID", isOn: Binding(
                                    get: { faceIDEnabled },
                                    set: { newValue in
                                        faceIDEnabled = newValue
                                        BiometricAuth.isEnabled = newValue
                                    }
                                ))
                            }
                        }
                    }
                }

                if !store.isDecoyMode {
                    Section("Notifications") {
                        Toggle("Payday Reminders", isOn: Binding(
                            get: { paydayRemindersEnabled },
                            set: { newValue in
                                PaydayNotifications.setEnabled(newValue, schedule: store.state.paySchedule) { granted in
                                    paydayRemindersEnabled = granted
                                }
                            }
                        ))
                        if paydayRemindersEnabled && store.state.paySchedule == nil {
                            Text("Set a pay schedule to start getting reminders.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Appearance") {
                    ColorSwatchPicker(
                        selectedHex: Binding(
                            get: { store.state.accentColorHex },
                            set: { store.setAccentColor(hex: $0) }
                        ),
                        palette: accentPalette
                    )
                }

                Section {
                    ForEach(AppTab.allCases) { tab in
                        Button { editingColorTab = tab } label: {
                            HStack {
                                Text(tab.label).foregroundStyle(.primary)
                                Spacer()
                                Circle().fill(store.accentColor(for: tab)).frame(width: 20, height: 20)
                            }
                        }
                    }
                } header: {
                    Text("Tab Colors")
                } footer: {
                    Text("Each tab can have its own color, used for its buttons, links, and highlights. Defaults to the color above.")
                }

                Section {
                    NavigationLink("Buckets") { BucketsSettingsView() }
                    NavigationLink("Bills") { BillsSettingsView() }
                    NavigationLink("Credit Cards") { CreditCardsSettingsView() }
                    NavigationLink("Income Sources") { IncomeSourcesSettingsView() }
                    NavigationLink("Recurring Transfers") { RecurringTransfersSettingsView() }
                }

                Section {
                    NavigationLink("History") { HistoryView() }
                    NavigationLink("Notes") { NotesView() }
                    NavigationLink("Paycheck Schedule") { PayScheduleSettingsView() }
                }

                if !store.isDecoyMode {
                    Section("Bank Connection") {
                        NavigationLink("Connect Bank Account") { BankConnectionSettingsView() }
                    }
                }

                Section("Data") {
                    Button("Export Backup") { startExport() }
                    Button("Import Backup") { showImporter = true }
                    Button("Reset All Data", role: .destructive) { showResetConfirm = true }
                }
            }
            .listStyle(.insetGrouped)
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
