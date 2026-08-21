import SwiftUI

struct ColorSwatchPicker: View {
    @Binding var selectedHex: String
    var palette: [String] = bucketPalette

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    // Selection outside the preset palette (from the custom picker below)
    // gets its own highlight on the custom swatch instead of matching none
    // of the presets and looking like nothing is selected.
    private var isCustom: Bool {
        !palette.contains { $0.uppercased() == selectedHex.uppercased() }
    }

    private var customColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: selectedHex) },
            set: { selectedHex = $0.toHex() }
        )
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(palette, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 32, height: 32)
                    .overlay {
                        if !isCustom, hex.uppercased() == selectedHex.uppercased() {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .onTapGesture { selectedHex = hex }
            }

            // The system color picker (wheel + sliders + spectrum + eyedropper)
            // doubles as both an "add a custom color" button and, once one's
            // picked, the display for that custom color — so there's no need
            // to separately track or list previously-added custom colors.
            ColorPicker("", selection: customColorBinding, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .overlay {
                    Circle().strokeBorder(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    if isCustom {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .allowsHitTesting(false)
                    }
                }
        }
        .padding(.vertical, 4)
    }
}
