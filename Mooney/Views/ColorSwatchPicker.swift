import SwiftUI

struct ColorSwatchPicker: View {
    @Environment(AppStore.self) var store
    @Binding var selectedHex: String
    var palette: [String] = bucketPalette

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    // The dashed "+" slot's working value while the system color picker is
    // open — held locally and NOT written to the store until "Save" is
    // tapped. ColorPicker's binding fires continuously while dragging the
    // wheel/sliders, so writing straight to store.customColorHexes on every
    // change used to save a new near-duplicate color for each drag frame.
    @State private var draftColor: Color = .white
    @State private var hasDraft = false

    @State private var isEditingCustom = false
    @State private var pendingDeletion: Set<String> = []

    private var isUnrepresentedSelection: Bool {
        let known = palette + store.state.customColorHexes
        return !known.contains { $0.uppercased() == selectedHex.uppercased() }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(palette, id: \.self) { hex in
                    swatch(hex)
                }

                // Custom colors ever saved from the draft slot below, kept in
                // AppState.customColorHexes so they persist and show up in
                // every ColorSwatchPicker from then on.
                ForEach(store.state.customColorHexes, id: \.self) { hex in
                    customSwatch(hex)
                }

                // selectedHex can be a color that's neither a preset nor (yet)
                // in the saved custom palette — e.g. one picked before this
                // palette existed, or set via a different picker instance.
                // Without this, none of the swatches above would show a
                // checkmark and the picker would look like nothing's chosen.
                // Tapping it loads the color into the draft slot so it can be
                // saved into the permanent palette.
                if isUnrepresentedSelection {
                    Circle()
                        .fill(Color(hex: selectedHex))
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .onTapGesture {
                            draftColor = Color(hex: selectedHex)
                            hasDraft = true
                        }
                }

                ColorPicker("", selection: Binding(
                    get: { draftColor },
                    set: { draftColor = $0; hasDraft = true }
                ), supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    .overlay {
                        Circle().strokeBorder(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        if !hasDraft {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.secondary)
                                .allowsHitTesting(false)
                        }
                    }
                    .disabled(isEditingCustom)
            }

            if hasDraft {
                HStack(spacing: 10) {
                    Text("New Color").font(.caption).foregroundStyle(Color.helperText)
                    Spacer()
                    Button("Cancel") { hasDraft = false; draftColor = .white }
                        .font(.caption)
                    Button("Save") {
                        let hex = draftColor.toHex()
                        store.addCustomColor(hex: hex)
                        selectedHex = hex
                        hasDraft = false
                        draftColor = .white
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(draftColor)
                }
            }

            if !store.state.customColorHexes.isEmpty {
                HStack(spacing: 12) {
                    if isEditingCustom && !pendingDeletion.isEmpty {
                        Button("Delete \(pendingDeletion.count)", role: .destructive) {
                            for hex in pendingDeletion { store.removeCustomColor(hex: hex) }
                            pendingDeletion.removeAll()
                            isEditingCustom = false
                        }
                        .font(.caption.weight(.semibold))
                    }
                    Spacer()
                    Button(isEditingCustom ? "Done" : "Edit Custom Colors") {
                        isEditingCustom.toggle()
                        if !isEditingCustom { pendingDeletion.removeAll() }
                    }
                    .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func swatch(_ hex: String) -> some View {
        Circle()
            .fill(Color(hex: hex))
            .frame(width: 32, height: 32)
            .overlay {
                if hex.uppercased() == selectedHex.uppercased() {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .onTapGesture { selectedHex = hex }
    }

    @ViewBuilder
    private func customSwatch(_ hex: String) -> some View {
        let isMarked = pendingDeletion.contains(hex)
        Circle()
            .fill(Color(hex: hex))
            .frame(width: 32, height: 32)
            .overlay {
                if isEditingCustom {
                    Circle().strokeBorder(isMarked ? Color.red : Color.secondary.opacity(0.4), lineWidth: isMarked ? 2 : 1)
                    Image(systemName: isMarked ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14))
                        .foregroundStyle(isMarked ? Color.red : Color.white.opacity(0.85))
                } else if hex.uppercased() == selectedHex.uppercased() {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .onTapGesture {
                if isEditingCustom {
                    if isMarked { pendingDeletion.remove(hex) } else { pendingDeletion.insert(hex) }
                } else {
                    selectedHex = hex
                }
            }
    }
}
