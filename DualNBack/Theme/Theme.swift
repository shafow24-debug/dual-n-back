import SwiftUI

enum Theme {
    // MARK: - Paleta de Colores Exacta
    /// Azul claro `#85B8EE` — Fondo principal de todas las pantallas
    static let background = Color(hex: "#85B8EE")
    
    /// Azul principal `#4A8DE0` — Botones principales, cápsulas de acción y botón de pausa
    static let primaryBlue = Color(hex: "#4A8DE0")
    
    /// Azul profundo `#4589DC` — Barra inferior de botones SOUND/POSITION y encabezado de pausa
    static let darkBlue = Color(hex: "#4589DC")
    
    /// Azul intermedio `#5A9FE8` — Tarjetas secundarias, contenedores y estado presionado
    static let mediumBlue = Color(hex: "#5A9FE8")
    
    /// Azul pálido `#A8CCF4` — Cuadritos inactivos de la mini cuadrícula 3x3 en la ilustración del cerebro
    static let lightBrainCell = Color(hex: "#A8CCF4")
    
    /// Amarillo cálido `#FAD272` — Cuadro activo 3x3, barra de progreso, tramo activo de sliders y línea decorativa
    static let accentYellow = Color(hex: "#FAD272")
    
    /// Naranja `#F5A65B` — Círculos de los botones ◀ y ▶ en el selector de nivel N
    static let accentOrange = Color(hex: "#F5A65B")
    
    /// Blanco al 45% de opacidad — Casilla inactiva de la cuadrícula 3x3
    static let inactiveCell = Color.white.opacity(0.45)
    
    /// Verde suave pero claro `#4CD964` — Destello de acierto (Hit)
    static let feedbackHit = Color(hex: "#4CD964")
    
    /// Rojo coral `#FF5A5F` — Destello de error (Falsa alarma u Omisión)
    static let feedbackMiss = Color(hex: "#FF5A5F")
    
    // MARK: - Sombras
    static let subtleShadow = Color.black.opacity(0.12)
    static let titleShadow = Color(hex: "#2E6BB8").opacity(0.45)
    
    // MARK: - Tipografía Redondeada (SF Pro Rounded)
    static func font(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        Font.system(size: size, weight: weight, design: .rounded)
    }
    
    static func font(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        Font.system(style, design: .rounded).weight(weight)
    }
}

extension Color {
    /// Inicializador de `Color` a partir de cadena hexadecimal (`#RRGGBB` o `#AARRGGBB`)
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        
        let a, r, g, b: UInt64
        switch cleaned.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (
                255,
                (int >> 8) * 17,
                (int >> 4 & 0xF) * 17,
                (int & 0xF) * 17
            )
        case 6: // RRGGBB (24-bit)
            (a, r, g, b) = (
                255,
                int >> 16,
                int >> 8 & 0xFF,
                int & 0xFF
            )
        case 8: // AARRGGBB (32-bit)
            (a, r, g, b) = (
                int >> 24,
                int >> 16 & 0xFF,
                int >> 8 & 0xFF,
                int & 0xFF
            )
        default:
            (a, r, g, b) = (255, 133, 184, 238)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }
}

// MARK: - Modificador de Sombra Estándar Suave
struct SoftCardShadow: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(color: Theme.subtleShadow, radius: 6, x: 0, y: 3)
    }
}

extension View {
    func softShadow() -> some View {
        modifier(SoftCardShadow())
    }
}
