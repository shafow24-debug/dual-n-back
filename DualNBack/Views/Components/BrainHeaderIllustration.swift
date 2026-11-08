import SwiftUI

/// Silueta vectorial limpia de cabeza humana de perfil en blanco con mini cuadrícula 3x3 en la zona cerebral
struct HeadProfileShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        
        // Empezamos en la base posterior del cuello
        p.move(to: CGPoint(x: w * 0.34, y: h * 0.96))
        
        // Base del cuello hacia adelante
        p.addQuadCurve(
            to: CGPoint(x: w * 0.64, y: h * 0.96),
            control: CGPoint(x: w * 0.49, y: h * 1.00)
        )
        
        // Subida frontal del cuello hacia la garganta
        p.addQuadCurve(
            to: CGPoint(x: w * 0.66, y: h * 0.78),
            control: CGPoint(x: w * 0.63, y: h * 0.86)
        )
        
        // Mentón redondeado (mirando hacia la derecha)
        p.addQuadCurve(
            to: CGPoint(x: w * 0.82, y: h * 0.73),
            control: CGPoint(x: w * 0.80, y: h * 0.79)
        )
        
        // Labios suaves y subida hacia la base de la nariz
        p.addCurve(
            to: CGPoint(x: w * 0.84, y: h * 0.56),
            control1: CGPoint(x: w * 0.86, y: h * 0.68),
            control2: CGPoint(x: w * 0.82, y: h * 0.61)
        )
        
        // Punta de la nariz redondeada
        p.addQuadCurve(
            to: CGPoint(x: w * 0.93, y: h * 0.49),
            control: CGPoint(x: w * 0.95, y: h * 0.54)
        )
        
        // Puente de la nariz hacia el entrecejo
        p.addQuadCurve(
            to: CGPoint(x: w * 0.82, y: h * 0.37),
            control: CGPoint(x: w * 0.88, y: h * 0.43)
        )
        
        // Frente amplia y bóveda craneal superior
        p.addCurve(
            to: CGPoint(x: w * 0.42, y: h * 0.05),
            control1: CGPoint(x: w * 0.85, y: h * 0.16),
            control2: CGPoint(x: w * 0.66, y: h * 0.03)
        )
        
        // Parte posterior del cráneo (occipital amplio donde descansa la cuadrícula)
        p.addCurve(
            to: CGPoint(x: w * 0.16, y: h * 0.55),
            control1: CGPoint(x: w * 0.16, y: h * 0.07),
            control2: CGPoint(x: w * 0.06, y: h * 0.33)
        )
        
        // Nuca bajando hacia la base posterior del cuello
        p.addCurve(
            to: CGPoint(x: w * 0.34, y: h * 0.96),
            control1: CGPoint(x: w * 0.23, y: h * 0.69),
            control2: CGPoint(x: w * 0.31, y: h * 0.82)
        )
        
        p.closeSubpath()
        return p
    }
}

/// Ilustración central de Inicio: silueta de cabeza en blanco + mini cuadrícula 3x3 + botón circular `"?"` con halo
struct BrainHeaderIllustration: View {
    var onHelpTapped: () -> Void
    
    /// Índice del cuadrito iluminado en amarillo `#FAD272` (esquina superior derecha del cerebro: índice 2)
    private let highlightedIndex: Int = 2
    private let columns = Array(repeating: GridItem(.fixed(22), spacing: 5), count: 3)
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Contenedor central de la cabeza + mini cuadrícula 3x3
            ZStack {
                HeadProfileShape()
                    .fill(Color.white)
                    .frame(width: 195, height: 195)
                    .softShadow()
                
                // Mini cuadrícula 3x3 posicionada exactamente en la bóveda craneal (zona del cerebro)
                LazyVGrid(columns: columns, spacing: 5) {
                    ForEach(0..<9, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                            .fill(index == highlightedIndex ? Theme.accentYellow : Theme.lightBrainCell)
                            .frame(width: 22, height: 22)
                    }
                }
                .offset(x: -8, y: -22)
            }
            .frame(width: 235, height: 200)
            
            // Botón circular "?" en la esquina superior derecha con resplandor/halo blanco suave
            Button(action: onHelpTapped) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 36, height: 36)
                        .shadow(color: Color.white.opacity(0.85), radius: 10, x: 0, y: 0)
                        .shadow(color: Theme.subtleShadow, radius: 4, x: 0, y: 2)
                    
                    Text("?")
                        .font(Theme.font(size: 21, weight: .heavy))
                        .foregroundColor(Theme.primaryBlue)
                }
            }
            .buttonStyle(.plain)
            .offset(x: 6, y: 4)
            .accessibilityLabel("Abrir instrucciones de cómo jugar")
        }
    }
}
