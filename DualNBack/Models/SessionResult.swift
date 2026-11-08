import Foundation

/// Resultado de progresión de nivel N al finalizar una sesión
enum LevelProgression: String, Codable, Equatable {
    case increased
    case maintained
    case decreased
    case manual
}

/// Modelo de sesión finalizada persistido en `sessions.json`
struct SessionResult: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let nLevel: Int
    let interval: Double
    let duration: Int
    let evaluatedTurns: Int
    let soundHits: Int
    let soundMisses: Int
    let soundFalseAlarms: Int
    let positionHits: Int
    let positionMisses: Int
    let positionFalseAlarms: Int
    let soundAccuracy: Double
    let positionAccuracy: Double
    let resultingN: Int
    let progression: LevelProgression
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        nLevel: Int,
        interval: Double,
        duration: Int,
        evaluatedTurns: Int,
        soundHits: Int,
        soundMisses: Int,
        soundFalseAlarms: Int,
        positionHits: Int,
        positionMisses: Int,
        positionFalseAlarms: Int,
        isAdaptive: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.nLevel = nLevel
        self.interval = interval
        self.duration = duration
        self.evaluatedTurns = evaluatedTurns
        self.soundHits = soundHits
        self.soundMisses = soundMisses
        self.soundFalseAlarms = soundFalseAlarms
        self.positionHits = positionHits
        self.positionMisses = positionMisses
        self.positionFalseAlarms = positionFalseAlarms
        
        let soundPct = Self.calculatePercentage(
            hits: soundHits,
            misses: soundMisses,
            falseAlarms: soundFalseAlarms
        )
        let positionPct = Self.calculatePercentage(
            hits: positionHits,
            misses: positionMisses,
            falseAlarms: positionFalseAlarms
        )
        
        self.soundAccuracy = soundPct
        self.positionAccuracy = positionPct
        
        let evaluation = Self.evaluateProgression(
            currentN: nLevel,
            soundPercentage: soundPct,
            positionPercentage: positionPct,
            isAdaptive: isAdaptive
        )
        self.resultingN = evaluation.nextN
        self.progression = evaluation.progression
    }
    
    /// Porcentaje global combinado (promedio de SOUND y POSITION)
    var combinedAccuracy: Double {
        (soundAccuracy + positionAccuracy) / 2.0
    }
    
    /// Entero redondeado para mostrar en UI (`0...100`)
    var soundAccuracyInt: Int {
        Int(soundAccuracy.rounded())
    }
    
    /// Entero redondeado para mostrar en UI (`0...100`)
    var positionAccuracyInt: Int {
        Int(positionAccuracy.rounded())
    }
    
    /// Entero redondeado del promedio global (`0...100`)
    var combinedAccuracyInt: Int {
        Int(combinedAccuracy.rounded())
    }
    
    /// Texto del banner de progresión de nivel N según las reglas del protocolo
    var progressionBannerText: String {
        switch progression {
        case .increased:
            return "¡Excelente! Subes a N = \(resultingN)"
        case .maintained:
            return "Te mantienes en N = \(resultingN)"
        case .decreased:
            return "Bajas a N = \(resultingN) para consolidar"
        case .manual:
            return "Modo manual: N = \(resultingN)"
        }
    }
    
    // MARK: - Fórmulas Científicas de Puntaje y Nivel Adaptativo
    
    /// Calcula el porcentaje exacto para una modalidad:
    /// `Aciertos / (Aciertos + Omisiones + Falsas Alarmas) * 100`
    static func calculatePercentage(hits: Int, misses: Int, falseAlarms: Int) -> Double {
        let denominator = hits + misses + falseAlarms
        guard denominator > 0 else { return 0.0 }
        return (Double(hits) / Double(denominator)) * 100.0
    }
    
    /// Evalúa el cambio de nivel N al finalizar la sesión:
    /// - Si `sound >= 80%` Y `position >= 80%` -> sube a `min(9, currentN + 1)`
    /// - Si `sound < 50%` O `position < 50%` -> baja a `max(1, currentN - 1)`
    /// - En cualquier otro caso -> se mantiene en `currentN`
    static func evaluateProgression(
        currentN: Int,
        soundPercentage: Double,
        positionPercentage: Double,
        isAdaptive: Bool
    ) -> (nextN: Int, progression: LevelProgression) {
        let clampedCurrent = min(9, max(1, currentN))
        guard isAdaptive else {
            return (clampedCurrent, .manual)
        }
        
        if soundPercentage >= 80.0 && positionPercentage >= 80.0 {
            let nextN = min(9, clampedCurrent + 1)
            return (nextN, .increased)
        } else if soundPercentage < 50.0 || positionPercentage < 50.0 {
            let nextN = max(1, clampedCurrent - 1)
            return (nextN, .decreased)
        } else {
            return (clampedCurrent, .maintained)
        }
    }
}
