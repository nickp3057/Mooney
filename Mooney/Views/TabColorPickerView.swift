import SwiftUI

struct TabColorPickerView: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) var dismiss
    let tab: AppTab

    private var isCustomized: Bool {
        store.state.tabAccentColors[tab.rawValue] != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ColorSwatchPicker(
                        selectedHex: Binding(
                            get: { store.state.tabAccentColors[tab.rawValue] ?? store.state.accentColorHex },
                            set: { store.setAccentColor(hex: $0, for: tab) }
                        ),
                        palette: accentPalette
                    )
                } footer: {
                    Text("Colors buttons, links, and highlights throughout \(tab.label).")
                }
                if isCustomized {
                    Section {
                        Button("Use Default Color") {
                            store.resetAccentColor(for: tab)
                        }
                    }
                }
            }
            .navigationTitle(tab.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
