import SwiftUI
import LinkKit

struct BankConnectionSettingsView: View {
    // Explicit module qualification: LinkKit also exports a type named
    // `Environment`, which makes the bare `@Environment` property wrapper
    // ambiguous once both modules are imported.
    @SwiftUI.Environment(\.tabAccentColor) private var accentColor
    @AppStorage(PlaidClient.backendURLDefaultsKey) private var backendURL: String = ""
    @State private var isConnected = PlaidClient.isConnected
    @State private var linkSession: PlaidLinkSession?
    @State private var isPresentingLink = false
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var showDisconnectConfirm = false

    private let plaidClient = PlaidClient()

    var body: some View {
        List {
            Section {
                TextField("http://100.x.x.x:4001", text: $backendURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            } header: {
                Text("Backend URL")
            } footer: {
                Text("The Tailscale address of your Mooney Plaid backend.")
            }

            Section {
                if isConnected {
                    Button("Disconnect Bank Account", role: .destructive) {
                        showDisconnectConfirm = true
                    }
                    .disabled(isWorking)
                } else {
                    Button {
                        connect()
                    } label: {
                        HStack {
                            Text("Connect Bank Account")
                            Spacer()
                            if isWorking {
                                ProgressView()
                            }
                        }
                    }
                    .foregroundStyle(accentColor)
                    .disabled(backendURL.isEmpty || isWorking)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Bank Connection")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isPresentingLink) {
            if let linkSession {
                linkSession.sheet()
            }
        }
        .confirmationDialog(
            "Disconnect Bank Account?",
            isPresented: $showDisconnectConfirm,
            titleVisibility: .visible
        ) {
            Button("Disconnect", role: .destructive) { disconnect() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Mooney will stop showing your live balance until you reconnect.")
        }
    }

    private func connect() {
        errorMessage = nil
        isWorking = true
        Task {
            do {
                let token = try await plaidClient.createLinkToken()
                startLinkSession(token: token)
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func startLinkSession(token: String) {
        let configuration = LinkTokenConfiguration(
            token: token,
            onSuccess: { success in
                isPresentingLink = false
                guard let account = success.metadata.accounts.first else {
                    errorMessage = "Link didn't return an account to connect."
                    return
                }
                Task { await finishConnecting(publicToken: success.publicToken, accountId: account.id) }
            },
            onExit: { exit in
                isPresentingLink = false
                if let error = exit.error {
                    errorMessage = error.displayMessage ?? error.errorMessage
                }
            },
            onEvent: nil,
            onLoad: nil
        )
        do {
            linkSession = try Plaid.createPlaidLinkSession(configuration: configuration)
            isPresentingLink = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func finishConnecting(publicToken: String, accountId: String) async {
        do {
            try await plaidClient.exchangePublicToken(publicToken, accountId: accountId)
            PlaidClient.isConnected = true
            isConnected = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func disconnect() {
        isWorking = true
        Task {
            do {
                try await plaidClient.disconnect()
            } catch {
                errorMessage = error.localizedDescription
            }
            PlaidClient.isConnected = false
            isConnected = false
            isWorking = false
        }
    }
}
