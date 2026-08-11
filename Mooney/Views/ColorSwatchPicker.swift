import SwiftUI

struct ColorSwatchPicker: View {
    @Binding var selectedHex: String
    var palette: [String] = bucketPalette

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(palette, id: \.self) { hex in
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
        }
        .padding(.vertical, 4)
    }
}
