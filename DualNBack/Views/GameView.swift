import SwiftUI

/// Pantalla principal de entrenamiento Dual N-Back con cuadrícula 3x3 y botones SOUND / POSITION
struct GameView: View {
    @ObservedObject var storage: StorageManager
    var onExitToHome: () -> Void
    
    @StateObject private var engine = GameEngine()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            if case .finished(let sessionResult) = engine.phase {
                ResultsView(
                    result: sessionResult,
                    onPlayAgain: {
                        engine.startNewSession(
                            nLevel: storage.settings.currentN,
                            interval: storage.settings.defaultInterval,
                            duration: storage.settings.defaultDuration
                        )
                    },
                    onGoHome: {
                        engine.stopAndExitSession()
                        onExitToHome()
                    }
                )
                .transition(.opacity)
            } else {
                GeometryReader { geo in
                    let totalHeight = geo.size.height
                    let totalWidth = geo.size.width
                    let bottomBarHeight = max(145, totalHeight * 0.22)
                    
                    VStack(spacing: 0) {
                        // MARK: - Zona Superior: Barra de Progreso + Nivel N + Botón de Pausa
                        VStack(spacing: 12) {
                            // Barra de progreso horizontal delgada y redondeada (height: 8 pt)
                            GeometryReader { barGeo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.40))
                                        .frame(height: 8)
                                    
                                    Capsule()
                                        .fill(Theme.accentYellow)
                                        .frame(
                                            width: max(0, barGeo.size.width * CGFloat(engine.progress)),
                                            height: 8
                                        )
                                }
                            }
                            .frame(height: 8)
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                            
                            // Fila con "N = X" centrado y botón circular de pausa 44x44 a la derecha
                            ZStack {
                                VStack(spacing: 2) {
                                    Text("N = \(engine.sessionNLevel)")
                                        .font(Theme.font(.title2, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    if engine.isMemoryLoadingPhase && engine.phase == .playing {
                                        Text("Memorizando (\(min(engine.currentTurnIndex + 1, engine.sessionNLevel))/\(engine.sessionNLevel))")
                                            .font(Theme.font(.caption2, weight: .bold))
                                            .foregroundColor(Theme.accentYellow)
                                    }
                                }
                                
                                HStack {
                                    Spacer()
                                    
                                    Button {
                                        engine.pauseGame()
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .fill(Theme.primaryBlue)
                                                .frame(width: 44, height: 44)
                                                .softShadow()
                                            
                                            Image(systemName: "pause.fill")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Pausar sesión")
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        Spacer(minLength: 8)
                        
                        // MARK: - Cuadrícula Central 3x3
                        ZStack {
                            let maxGridSide = min(totalWidth - 44, (totalHeight - bottomBarHeight) * 0.68)
                            let cellSpacing: CGFloat = 12
                            let cellSide = max(64, (maxGridSide - (cellSpacing * 2)) / 3.0)
                            
                            VStack(spacing: cellSpacing) {
                                ForEach(0..<3, id: \.self) { row in
                                    HStack(spacing: cellSpacing) {
                                        ForEach(0..<3, id: \.self) { col in
                                            let index = row * 3 + col
                                            let isActive = engine.activeGridPosition == index
                                            
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .fill(isActive ? Theme.accentYellow : Theme.inactiveCell)
                                                    .frame(width: cellSide, height: cellSide)
                                                
                                                // Cruz central de fijación (+) discreta en la casilla central (índice 4)
                                                if index == 4 && storage.settings.fixationCrossEnabled {
                                                    Image(systemName: "plus")
                                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                                        .foregroundColor(
                                                            isActive
                                                                ? Theme.darkBlue.opacity(0.55)
                                                                : Color.white.opacity(0.70)
                                                        )
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Indicador de cuenta regresiva inicial ("Prepárate... 3, 2, 1")
                            if case .countdown(let count) = engine.phase {
                                VStack(spacing: 8) {
                                    Text("Prepárate...")
                                        .font(Theme.font(.headline, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text("\(count)")
                                        .font(Theme.font(size: 56, weight: .heavy))
                                        .foregroundColor(Theme.accentYellow)
                                }
                                .padding(.horizontal, 36)
                                .padding(.vertical, 22)
                                .background(
                                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                                        .fill(Theme.darkBlue.opacity(0.92))
                                        .softShadow()
                                )
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        
                        Spacer(minLength: 12)
                        
                        // MARK: - Zona Inferior de Respuesta: Botones SOUND y POSITION (~22% de la altura)
                        HStack(spacing: 0) {
                            // Botón Izquierdo: SOUND
                            responseActionButton(
                                icon: "music.note",
                                label: "SOUND",
                                isPressedThisTurn: engine.soundPressedThisTurn,
                                isLockedLoading: engine.isMemoryLoadingPhase || engine.phase != .playing,
                                feedbackState: engine.soundFeedback,
                                action: {
                                    engine.registerSoundPress()
                                }
                            )
                            
                            // Línea vertical blanca fina (1 pt al 30% de opacidad)
                            Rectangle()
                                .fill(Color.white.opacity(0.30))
                                .frame(width: 1)
                                .padding(.vertical, 18)
                            
                            // Botón Derecho: POSITION
                            responseActionButton(
                                icon: "square.fill",
                                label: "POSITION",
                                isPressedThisTurn: engine.positionPressedThisTurn,
                                isLockedLoading: engine.isMemoryLoadingPhase || engine.phase != .playing,
                                feedbackState: engine.positionFeedback,
                                action: {
                                    engine.registerPositionPress()
                                }
                            )
                        }
                        .frame(height: bottomBarHeight)
                        .background(
                            Theme.darkBlue
                                .ignoresSafeArea(edges: .bottom)
                        )
                    }
                }
                
                // MARK: - Superposición Modal de Pausa
                if engine.phase == .paused {
                    PauseModalView(
                        engine: engine,
                        hapticsEnabled: storage.settings.hapticsEnabled,
                        onResumeOrRestart: {
                            engine.resumeOrRestartFromPause()
                        },
                        onConfirmExit: {
                            engine.stopAndExitSession()
                            onExitToHome()
                        }
                    )
                    .transition(.opacity)
                }
            }
        }
        .onAppear {
            engine.startNewSession(
                nLevel: storage.settings.currentN,
                interval: storage.settings.defaultInterval,
                duration: storage.settings.defaultDuration
            )
        }
        .onDisappear {
            engine.stopAndExitSession()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase != .active {
                engine.pauseGame()
            }
        }
    }
    
    // MARK: - Botón de Acción Dual (SOUND / POSITION)
    
    private func responseActionButton(
        icon: String,
        label: String,
        isPressedThisTurn: Bool,
        isLockedLoading: Bool,
        feedbackState: ButtonFeedbackState,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                // Fondo según estado de destello de acierto/error
                buttonBackgroundColor(feedbackState: feedbackState)
                
                VStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 30, weight: .bold))
                    
                    Text(label)
                        .font(Theme.font(size: 22, weight: .heavy))
                        .tracking(1.0)
                }
                .foregroundColor(
                    contentForegroundColor(
                        isPressedThisTurn: isPressedThisTurn,
                        isLockedLoading: isLockedLoading,
                        feedbackState: feedbackState
                    )
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLockedLoading)
    }
    
    private func buttonBackgroundColor(feedbackState: ButtonFeedbackState) -> Color {
        switch feedbackState {
        case .none:
            return Theme.darkBlue
        case .hit:
            return Theme.feedbackHit.opacity(0.85)
        case .miss:
            return Theme.feedbackMiss.opacity(0.85)
        }
    }
    
    private func contentForegroundColor(
        isPressedThisTurn: Bool,
        isLockedLoading: Bool,
        feedbackState: ButtonFeedbackState
    ) -> Color {
        if feedbackState != .none || isPressedThisTurn {
            return Color.white
        }
        if isLockedLoading {
            return Color.white.opacity(0.18)
        }
        return Color.white.opacity(0.28)
    }
}
