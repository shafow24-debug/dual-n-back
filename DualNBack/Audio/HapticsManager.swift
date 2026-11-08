import UIKit

/// Gestor de respuesta háptica de baja latencia para aciertos, errores y controles
@MainActor
final class HapticsManager {
    static let shared = HapticsManager()
    
    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let softGenerator = UIImpactFeedbackGenerator(style: .soft)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    
    private init() {}
    
    /// Prepara los motores Taptic Engine antes de comenzar una sesión
    func prepare() {
        lightGenerator.prepare()
        softGenerator.prepare()
        notificationGenerator.prepare()
    }
    
    /// Vibración ligera al interactuar con selectores de la interfaz
    func playSelectionTap(enabled: Bool = true) {
        guard enabled else { return }
        softGenerator.impactOccurred(intensity: 0.75)
    }
    
    /// Vibración de confirmación cuando el jugador acierta un objetivo (Hit)
    func playHit(enabled: Bool) {
        guard enabled else { return }
        lightGenerator.impactOccurred(intensity: 0.9)
    }
    
    /// Vibración suave de advertencia cuando ocurre una Falsa Alarma u Omisión
    func playError(enabled: Bool) {
        guard enabled else { return }
        notificationGenerator.notificationOccurred(.error)
    }
}
