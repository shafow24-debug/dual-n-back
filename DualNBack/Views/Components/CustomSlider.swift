import SwiftUI

/// Slider personalizado con tramo activo amarillo (`#FAD272`), tramo derecho blanco y perilla blanca con borde azul (`#4A8DE0`)
struct CustomSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var hapticsEnabled: Bool = true
    
    private let trackHeight: CGFloat = 8
    private let thumbSize: CGFloat = 26
    
    var body: some View {
        GeometryReader { proxy in
            let totalWidth = max(1, proxy.size.width)
            let usableWidth = max(1, totalWidth - thumbSize)
            let normalized = min(1.0, max(0.0, (value - range.lowerBound) / (range.upperBound - range.lowerBound)))
            let thumbCenterX = (thumbSize / 2.0) + CGFloat(normalized) * usableWidth
            
            ZStack(alignment: .leading) {
                // Tramo derecho (fondo completo en blanco)
                Capsule()
                    .fill(Color.white.opacity(0.92))
                    .frame(height: trackHeight)
                
                // Tramo izquierdo recorrido en amarillo (#FAD272)
                Capsule()
                    .fill(Theme.accentYellow)
                    .frame(width: max(trackHeight, thumbCenterX), height: trackHeight)
                
                // Perilla (thumb) circular blanca con borde azul (#4A8DE0)
                Circle()
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .overlay(
                        Circle()
                            .stroke(Theme.primaryBlue, lineWidth: 3.5)
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 2)
                    .offset(x: thumbCenterX - (thumbSize / 2.0))
            }
            .frame(height: thumbSize)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let clampedX = min(usableWidth, max(0, gesture.location.x - (thumbSize / 2.0)))
                        let fraction = Double(clampedX / usableWidth)
                        let rawValue = range.lowerBound + fraction * (range.upperBound - range.lowerBound)
                        let steppedValue = snapToStep(rawValue)
                        if abs(steppedValue - value) >= (step * 0.45) {
                            value = steppedValue
                            HapticsManager.shared.playSelectionTap(enabled: hapticsEnabled)
                        }
                    }
            )
        }
        .frame(height: thumbSize)
    }
    
    private func snapToStep(_ raw: Double) -> Double {
        guard step > 0 else {
            return min(range.upperBound, max(range.lowerBound, raw))
        }
        let stepsCount = ((raw - range.lowerBound) / step).rounded()
        let snapped = range.lowerBound + (stepsCount * step)
        let clamped = min(range.upperBound, max(range.lowerBound, snapped))
        // Evitar residuos de coma flotante como 1.5000000000000002
        return (clamped * 100).rounded() / 100
    }
}
