import SwiftUI

// Lightweight, dependency-free celebration overlay for "card paid off" — a
// fixed batch of colored pieces that fall and spin once. Purely decorative
// (allowsHitTesting false); the host is responsible for removing it after
// roughly 1.5-2s.
struct ConfettiView: View {
    private struct Piece: Identifiable {
        let id = UUID()
        let xFraction: CGFloat
        let delay: Double
        let duration: Double
        let color: Color
        let rotation: Double
        let size: CGFloat
    }

    @State private var animate = false
    private let pieces: [Piece]

    init(pieceCount: Int = 60) {
        let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
        pieces = (0..<pieceCount).map { _ in
            Piece(
                xFraction: .random(in: 0...1),
                delay: .random(in: 0...0.3),
                duration: .random(in: 1.4...2.2),
                color: colors.randomElement() ?? .yellow,
                rotation: .random(in: 180...720),
                size: .random(in: 6...10)
            )
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size * 0.4)
                        .position(x: piece.xFraction * geo.size.width, y: animate ? geo.size.height + 40 : -40)
                        .rotationEffect(.degrees(animate ? piece.rotation : 0))
                        .animation(.easeIn(duration: piece.duration).delay(piece.delay), value: animate)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { animate = true }
    }
}
