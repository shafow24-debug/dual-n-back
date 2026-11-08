import SwiftUI

/// Forma de burbuja de diálogo con piquito lateral hacia la izquierda para la fila de meta diaria
struct SpeechBubbleLeftPointerShape: Shape {
    var cornerRadius: CGFloat = 14
    var pointerWidth: CGFloat = 8
    var pointerHeight: CGFloat = 12
    
    func path(in rect: CGRect) -> Path {
        let bodyRect = CGRect(
            x: rect.minX + pointerWidth,
            y: rect.minY,
            width: max(0, rect.width - pointerWidth),
            height: rect.height
        )
        
        var path = Path()
        path.addRoundedRect(
            in: bodyRect,
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius),
            style: .continuous
        )
        
        let midY = rect.midY
        path.move(to: CGPoint(x: bodyRect.minX, y: midY - (pointerHeight / 2.0)))
        path.addLine(to: CGPoint(x: rect.minX, y: midY))
        path.addLine(to: CGPoint(x: bodyRect.minX, y: midY + (pointerHeight / 2.0)))
        path.closeSubpath()
        
        return path
    }
}

/// Destinos modales desde la pantalla de Inicio
enum HomeDestination: Identifiable {
    case instructions
    case history
    case stats
    case settings
    
    var id: Self { self }
}

/// Pantalla 1: Inicio de Dual N-Back
struct HomeView: View {
    @ObservedObject var storage: StorageManager
    
    @State private var isPlayingSession: Bool = false
    @State private var activeDestination: HomeDestination? = nil
    
    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            if isPlayingSession {
                GameView(
                    storage: storage,
                    onExitToHome: {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            isPlayingSession = false
                        }
                    }
                )
                .transition(.opacity)
            } else {
                GeometryReader { geo in
                    let isCompactHeight = geo.size.height < 700
                    
                    VStack(spacing: isCompactHeight ? 14 : 20) {
                        Spacer(minLength: isCompactHeight ? 6 : 14)
                        
                        // MARK: - 1. Encabezado Principal
                        VStack(spacing: 4) {
                            Text("Juego para entrenar la memoria")
                                .font(Theme.font(.subheadline, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Rectangle()
                                .fill(Theme.accentYellow)
                                .frame(width: 185, height: 2)
                                .cornerRadius(1)
                                .padding(.bottom, 2)
                            
                            VStack(alignment: .trailing, spacing: 0) {
                                Text("dual NBack")
                                    .font(Theme.font(size: isCompactHeight ? 42 : 46, weight: .heavy))
                                    .foregroundColor(.white)
                                    .shadow(color: Theme.titleShadow, radius: 3, x: 0, y: 2)
                                
                                Text("v1.0")
                                    .font(Theme.font(.caption2, weight: .bold))
                                    .foregroundColor(.white.opacity(0.8))
                                    .offset(y: -4)
                            }
                        }
                        
                        // MARK: - 2. Ilustración Central (Cabeza de perfil + cuadrícula 3x3 + botón "?")
                        BrainHeaderIllustration {
                            activeDestination = .instructions
                        }
                        .scaleEffect(isCompactHeight ? 0.88 : 1.0)
                        .frame(height: isCompactHeight ? 175 : 200)
                        
                        // MARK: - 3. Selector de Nivel N
                        NLevelSelector(
                            level: $storage.settings.currentN,
                            leadingLabel: "N =",
                            hapticsEnabled: storage.settings.hapticsEnabled
                        )
                        
                        // MARK: - 4. Botón Principal "Empezar"
                        Button {
                            HapticsManager.shared.playSelectionTap(enabled: storage.settings.hapticsEnabled)
                            withAnimation(.easeInOut(duration: 0.22)) {
                                isPlayingSession = true
                            }
                        } label: {
                            Text("Empezar")
                                .font(Theme.font(.title2, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: min(320, geo.size.width * 0.75), height: 58)
                                .background(
                                    Capsule()
                                        .fill(Theme.primaryBlue)
                                        .softShadow()
                                )
                        }
                        .buttonStyle(.plain)
                        
                        // MARK: - 5. Fila de Meta Diaria con Globo de Diálogo
                        dailyGoalRow
                            .padding(.top, 2)
                        
                        Spacer(minLength: isCompactHeight ? 8 : 16)
                        
                        // MARK: - 6. Barra de Navegación Inferior (Historial, Estadísticas, Ajustes)
                        bottomNavigationBar
                            .padding(.bottom, isCompactHeight ? 12 : 20)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear {
            SpeechManager.shared.warmUp(settings: storage.settings)
        }
        .sheet(item: $activeDestination) { destination in
            switch destination {
            case .instructions:
                InstructionsSheetView()
            case .history:
                HistoryView(storage: storage)
            case .stats:
                StatsView(storage: storage)
            case .settings:
                SettingsView(storage: storage)
            }
        }
    }
    
    // MARK: - Fila de Meta Diaria
    
    private var dailyGoalRow: some View {
        let completedToday = storage.sessionsCompletedToday
        let dailyGoal = storage.settings.dailyGoal
        let isGoalMet = completedToday >= dailyGoal
        
        return HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: isGoalMet ? "calendar.badge.checkmark" : "calendar")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.accentYellow)
                
                Text("Sesiones diarias")
                    .font(Theme.font(.subheadline, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text("\(completedToday)")
                .font(Theme.font(size: 26, weight: .heavy))
                .foregroundColor(.white)
            
            // Globo de diálogo blanco con piquito hacia la izquierda
            Text(isGoalMet ? "¡Meta cumplida! 🎉" : "¡Vamos! \(completedToday) / \(dailyGoal)")
                .font(Theme.font(.footnote, weight: .heavy))
                .foregroundColor(Theme.primaryBlue)
                .padding(.leading, 18)
                .padding(.trailing, 12)
                .padding(.vertical, 8)
                .background(
                    SpeechBubbleLeftPointerShape(cornerRadius: 14, pointerWidth: 8, pointerHeight: 11)
                        .fill(Color.white)
                        .softShadow()
                )
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Barra de Navegación Inferior
    
    private var bottomNavigationBar: some View {
        HStack(spacing: 42) {
            navBarButton(
                icon: "doc.text.fill",
                label: "Historial"
            ) {
                activeDestination = .history
            }
            
            navBarButton(
                icon: "person.crop.circle.fill",
                label: "Estadísticas"
            ) {
                activeDestination = .stats
            }
            
            navBarButton(
                icon: "gearshape.fill",
                label: "Ajustes"
            ) {
                activeDestination = .settings
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 10)
    }
    
    private func navBarButton(
        icon: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticsManager.shared.playSelectionTap(enabled: storage.settings.hapticsEnabled)
            action()
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(Theme.mediumBlue)
                        .frame(width: 50, height: 50)
                        .softShadow()
                    
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text(label)
                    .font(Theme.font(.caption2, weight: .bold))
                    .foregroundColor(.white.opacity(0.92))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
