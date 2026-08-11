import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppStore.self) var store
    @State private var editingBucket: Bucket?
    @State private var editingBill: Bill?
    @State private var showAddBucket    = false
    @State private var showAddBill      = false
    @State private var showAddSource    = false
    @State private var editingTransfer: RecurringTransfer?
    @State private var showAddTransfer  = false
    @State private var showArchived     = false
    @State private var showResetConfirm = false
    @State private var resetText        = ""
    @State private var showExporter     = false
    @State private var showImporter     = false
    @State private var showImportConfirm = false
    @State private var backupDocument: MoonayBackupDocument?
    @State private var pendingImport: AppState?
    @State private var dataMessage: String?

    var active:   [Bucket] { store.sortedNonArchived.filter  { $0.isActive  } }
    var inactive: [Bucket] { store.sortedNonArchived.filter  { !$0.isActive } }
    var archived: [Bucket] { store.state.buckets.filter { $0.archived }.sorted { $0.order < $1.order } }

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    ColorSwatchPicker(
                        selectedHex: Binding(
                            get: { store.state.accentColorHex },
                            set: { store.setAccentColor(hex: $0) }
                        ),
                        palette: accentPalette
                    )
                }

                if !active.isEmpty {
                    Section("Active Buckets") {
                        ForEach(active) { b in
                            BucketSettingRow(bucket: b) { editingBucket = b }
                        }
                        .onMove { store.moveBuckets(from: $0, to: $1, among: active) }
                    }
                }

                if !inactive.isEmpty {
                    Section("Planned Buckets") {
                        ForEach(inactive) { b in
                            BucketSettingRow(bucket: b) { editingBucket = b }
                        }
                        .onMove { store.moveBuckets(from: $0, to: $1, among: inactive) }
                    }
                }

                Section {
                    Button("+ New Bucket") { showAddBucket = true }
                        .foregroundStyle(store.accentColor)
                }

                Section("Bills") {
                    ForEach(store.sortedBills) { bill in
                        BillSettingRow(bill: bill) { editingBill = bill }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", role: .destructive) {
                                    store.deleteBill(id: bill.id)
                                }
                            }
                    }
                    Button("+ New Bill") { showAddBill = true }
                        .foregroundStyle(store.accentColor)
                }

                Section {
                    NavigationLink("Notes") { NotesView() }
                }

                Section("Income Sources") {
                    ForEach(store.state.incomeSources) { source in
                        Text(source.name)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", role: .destructive) {
                                    store.deleteIncomeSource(id: source.id)
                                }
                            }
                    }
                    Button("+ New Source") { showAddSource = true }
                        .foregroundStyle(store.accentColor)
                }

                Section("Recurring Transfers") {
                    ForEach(store.sortedRecurringTransfers) { transfer in
                        RecurringTransferRow(transfer: transfer) { editingTransfer = transfer }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", role: .destructive) {
                                    store.deleteRecurringTransfer(id: transfer.id)
                                }
                            }
                    }
                    Button("+ New Recurring Transfer") { showAddTransfer = true }
                        .foregroundStyle(store.accentColor)
                }

                if !archived.isEmpty {
                    Section {
                        DisclosureGroup("Archived (\(archived.count))", isExpanded: $showArchived) {
                            ForEach(archived) { b in
                                BucketSettingRow(bucket: b) { editingBucket = b }
                            }
                        }
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
            .toolbar { EditButton() }
            .sheet(item: $editingBucket) { BucketEditView(bucket: $0) }
            .sheet(item: $editingBill) { BillEditView(bill: $0) }
            .sheet(item: $editingTransfer) { RecurringTransferEditView(transfer: $0) }
            .sheet(isPresented: $showAddBucket) { BucketAddView() }
            .sheet(isPresented: $showAddBill) { BillAddView() }
            .sheet(isPresented: $showAddSource) { IncomeSourceAddView() }
            .sheet(isPresented: $showAddTransfer) { RecurringTransferAddView() }
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
        }
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
