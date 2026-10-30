import SwiftUI

/// Overlay only on the fitted image rectangle. Never include in image rendering.
struct CompositionGrid: View {
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        GeometryReader { geometry in
            let lines = Path { path in
                for division in 1...2 {
                    let x = geometry.size.width * CGFloat(division) / 3
                    let y = geometry.size.height * CGFloat(division) / 3
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
            }
            lines.stroke(.black.opacity(0.35), lineWidth: 1.5)
            lines.stroke(.white.opacity(contrast == .increased ? 0.85 : 0.5), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
