import SwiftUI

/// Hoja modal explicativa con ejemplo gráfico paso a paso para `N = 2`
struct InstructionsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Encabezado superior fijo
                HStack {
                    Text("¿Cómo se juega?")
                        .font(Theme.font(.title2, weight: .heavy))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)
                .padding(.top, 20)
                .padding(.bottom, 12)
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        // Tarjeta 1: Concepto general
                        instructionCard(
                            icon: "brain.head.profile",
                            title: "Entrenamiento de Memoria de Trabajo",
                            description: "En cada turno ocurren dos estímulos al mismo tiempo:\n• Un cuadro amarillo se ilumina en la cuadrícula 3x3.\n• Escuchas una letra hablada en español.\n\nTu objetivo es recordar qué ocurrió exactamente hace N turnos atrás."
                        )
                        
                        // Tarjeta 2: Ejemplo visual paso a paso (N = 2)
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .foregroundColor(Theme.accentYellow)
                                Text("Ejemplo paso a paso con N = 2")
                                    .font(Theme.font(.headline, weight: .heavy))
                                    .foregroundColor(.white)
                            }
                            
                            Text("Con N = 2, debes comparar cada turno con lo que ocurrió 2 turnos antes:")
                                .font(Theme.font(.subheadline, weight: .medium))
                                .foregroundColor(.white.opacity(0.92))
                            
                            VStack(spacing: 10) {
                                exampleTurnRow(
                                    turnNumber: 1,
                                    activeCell: 0,
                                    spokenText: "«hache»",
                                    badgeText: "Solo memorizar",
                                    badgeColor: Color.white.opacity(0.25)
                                )
                                
                                exampleTurnRow(
                                    turnNumber: 2,
                                    activeCell: 4,
                                    spokenText: "«ka»",
                                    badgeText: "Solo memorizar",
                                    badgeColor: Color.white.opacity(0.25)
                                )
                                
                                exampleTurnRow(
                                    turnNumber: 3,
                                    activeCell: 0,
                                    spokenText: "«erre»",
                                    badgeText: "¡Igual posición que Turno 1! → Pulsa POSITION",
                                    badgeColor: Theme.feedbackHit
                                )
                                
                                exampleTurnRow(
                                    turnNumber: 4,
                                    activeCell: 8,
                                    spokenText: "«ka»",
                                    badgeText: "¡Igual sonido que Turno 2! → Pulsa SOUND",
                                    badgeColor: Theme.feedbackHit
                                )
                            }
                        }
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Theme.mediumBlue)
                                .softShadow()
                        )
                        
                        // Tarjeta 3: Puntaje y Nivel Adaptativo
                        instructionCard(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Puntaje y Progresión de Nivel N",
                            description: "• Solo pulsa cuando haya coincidencia. Pulsar sin coincidencia cuenta como Falsa Alarma.\n• Si en un mismo turno coinciden tanto el sonido como la posición, pulsa ambos botones (SOUND y POSITION).\n• ≥ 80% en ambos canales: Subes a N + 1.\n• < 50% en algún canal: Bajas a N - 1 para consolidar.\n• Entre 50% y 79%: Te mantienes en el nivel actual."
                        )
                        
                        // Tarjeta 4: Consejo de fijación visual
                        instructionCard(
                            icon: "plus.viewfinder",
                            title: "Consejo de Laboratorio",
                            description: "Mantén la mirada relajada en la cruz central (+) y usa tu visión periférica para detectar las posiciones mientras escuchas las letras."
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                
                // Botón inferior "¡Entendido!"
                Button {
                    dismiss()
                } label: {
                    Text("¡Entendido!")
                        .font(Theme.font(.title3, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            Capsule()
                                .fill(Theme.primaryBlue)
                                .softShadow()
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
            }
        }
    }
    
    // MARK: - Subvistas de Apoyo
    
    private func instructionCard(icon: String, title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Theme.accentYellow)
                
                Text(title)
                    .font(Theme.font(.headline, weight: .heavy))
                    .foregroundColor(.white)
            }
            
            Text(description)
                .font(Theme.font(.subheadline, weight: .medium))
                .foregroundColor(.white.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.mediumBlue)
                .softShadow()
        )
    }
    
    private func exampleTurnRow(
        turnNumber: Int,
        activeCell: Int,
        spokenText: String,
        badgeText: String,
        badgeColor: Color
    ) -> some View {
        HStack(spacing: 14) {
            // Mini cuadrícula 3x3 demostrativa
            VStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { col in
                            let idx = row * 3 + col
                            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                .fill(idx == activeCell ? Theme.accentYellow : Color.white.opacity(0.38))
                                .frame(width: 13, height: 13)
                        }
                    }
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.darkBlue.opacity(0.6))
            )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Turno \(turnNumber)")
                        .font(Theme.font(.subheadline, weight: .heavy))
                        .foregroundColor(Theme.accentYellow)
                    
                    Text("🔊 \(spokenText)")
                        .font(Theme.font(.subheadline, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text(badgeText)
                    .font(Theme.font(.caption, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(badgeColor)
                    )
            }
            
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
    }
}
