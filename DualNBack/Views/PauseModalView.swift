import SwiftUI

/// Modal superpuesto de Pausa con controles de N-Level, Intervalo, Duración, Ayuda y Salida con confirmación
struct PauseModalView: View {
    @ObservedObject var engine: GameEngine
    var hapticsEnabled: Bool
    var onResumeOrRestart: () -> Void
    var onConfirmExit: () -> Void
    
    @State private var showExitConfirmation: Bool = false
    @State private var showInstructionsSheet: Bool = false
    
    var body: some View {
        ZStack {
            // Fondo oscurecido semitransparente sobre GameView
            Color.black.opacity(0.45)
                .ignoresSafeArea()
            
            // Tarjeta central con esquinas ampliamente redondeadas (cornerRadius: 28)
            VStack(spacing: 0) {
                // Encabezado en Theme.darkBlue (#4589DC)
                Text("Pausa")
                    .font(Theme.font(.title2, weight: .heavy))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.darkBlue)
                
                // Cuerpo en Theme.background (#85B8EE)
                VStack(spacing: 20) {
                    // 1. N-Level + NLevelSelector
                    VStack(spacing: 8) {
                        Text("N-Level")
                            .font(Theme.font(.headline, weight: .bold))
                            .foregroundColor(.white)
                        
                        NLevelSelector(
                            level: $engine.pauseNLevel,
                            leadingLabel: nil,
                            hapticsEnabled: hapticsEnabled
                        )
                    }
                    
                    // 2. Slider de Intervalo (1.0 s a 4.0 s en pasos de 0.1)
                    VStack(spacing: 8) {
                        HStack {
                            Text("Intervalo")
                                .font(Theme.font(.headline, weight: .bold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text(String(format: "%.1f s", engine.pauseInterval))
                                .font(Theme.font(.headline, weight: .heavy))
                                .foregroundColor(.white)
                        }
                        
                        CustomSlider(
                            value: $engine.pauseInterval,
                            range: 1.0...4.0,
                            step: 0.1,
                            hapticsEnabled: hapticsEnabled
                        )
                    }
                    
                    // 3. Slider de Duración (30 s a 180 s en pasos de 10)
                    VStack(spacing: 8) {
                        HStack {
                            Text("Duración")
                                .font(Theme.font(.headline, weight: .bold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text("\(engine.pauseDuration) s")
                                .font(Theme.font(.headline, weight: .heavy))
                                .foregroundColor(.white)
                        }
                        
                        CustomSlider(
                            value: Binding(
                                get: { Double(engine.pauseDuration) },
                                set: { engine.pauseDuration = Int($0.rounded()) }
                            ),
                            range: 30.0...180.0,
                            step: 10.0,
                            hapticsEnabled: hapticsEnabled
                        )
                    }
                    
                    // 4. Botón cápsula principal: Reanudar o Reiniciar y Empezar
                    Button {
                        onResumeOrRestart()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 18, weight: .bold))
                            
                            Text(engine.hasPauseParameterChanges ? "Reiniciar y Empezar" : "Reanudar")
                                .font(Theme.font(.title3, weight: .bold))
                        }
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
                    .padding(.top, 4)
                    
                    // 5. Fila inferior con botones circulares "?" y "✕"
                    HStack {
                        Button {
                            showInstructionsSheet = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 44, height: 44)
                                    .softShadow()
                                
                                Text("?")
                                    .font(Theme.font(size: 23, weight: .heavy))
                                    .foregroundColor(Theme.primaryBlue)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Instrucciones")
                        
                        Spacer()
                        
                        Button {
                            showExitConfirmation = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Theme.mediumBlue)
                                    .frame(width: 44, height: 44)
                                    .softShadow()
                                
                                Image(systemName: "xmark")
                                    .font(.system(size: 20, weight: .heavy))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Terminar sesión y volver al inicio")
                    }
                    .padding(.top, 2)
                }
                .padding(24)
                .background(Theme.background)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: Color.black.opacity(0.28), radius: 18, x: 0, y: 10)
            .padding(.horizontal, 28)
        }
        .sheet(isPresented: $showInstructionsSheet) {
            InstructionsSheetView()
        }
        .alert("¿Salir de la partida?", isPresented: $showExitConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Salir al inicio", role: .destructive) {
                onConfirmExit()
            }
        } message: {
            Text("¿Terminar la sesión actual y volver al inicio?")
        }
    }
}
