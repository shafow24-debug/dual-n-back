import Foundation
import AVFoundation

/// Información descriptiva de una voz instalada en español para el selector de Ajustes
struct SpanishVoiceOption: Identifiable, Equatable, Hashable {
    let identifier: String
    let name: String
    let language: String
    let qualityLabel: String
    let qualityRank: Int
    let regionRank: Int
    
    var id: String { identifier }
    
    var displayName: String {
        "\(name) (\(language)) • \(qualityLabel)"
    }
}

/// Motor de síntesis de voz de baja latencia en español para los estímulos auditivos
@MainActor
final class SpeechManager: ObservableObject {
    static let shared = SpeechManager()
    
    private let synthesizer = AVSpeechSynthesizer()
    private var isWarmedUp = false
    
    /// Diccionario fonético exacto en español (prohibido deletrear letras sueltas)
    static let phoneticDictionary: [String: String] = StimulusStep.phoneticDictionary
    
    @Published private(set) var availableSpanishVoices: [SpanishVoiceOption] = []
    
    init() {
        refreshAvailableVoices()
    }
    
    /// Descubre y ordena todas las voces en español instaladas en el iPhone
    func refreshAvailableVoices() {
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.lowercased().hasPrefix("es") }
        
        let mapped: [SpanishVoiceOption] = voices.map { voice in
            let qInfo = Self.qualityInfo(for: voice.quality)
            let rRank = Self.regionPriority(for: voice.language)
            return SpanishVoiceOption(
                identifier: voice.identifier,
                name: voice.name,
                language: voice.language,
                qualityLabel: qInfo.label,
                qualityRank: qInfo.rank,
                regionRank: rRank
            )
        }
        
        // Ordenamos primero por calidad (Premium > Mejorada > Estándar), luego por región (es-MX > es-US > es-ES > es-*)
        availableSpanishVoices = mapped.sorted { lhs, rhs in
            if lhs.qualityRank != rhs.qualityRank {
                return lhs.qualityRank > rhs.qualityRank
            }
            if lhs.regionRank != rhs.regionRank {
                return lhs.regionRank > rhs.regionRank
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
    
    /// Precalienta el motor TTS de iOS al abrir HomeView para eliminar cualquier latencia en el Turno 1
    func warmUp() {
        guard !isWarmedUp else { return }
        isWarmedUp = true
        refreshAvailableVoices()
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // Ignorar errores de sesión en simulador o segundo plano
        }
        
        let silentUtterance = AVSpeechUtterance(string: " ")
        silentUtterance.volume = 0.0
        silentUtterance.rate = AVSpeechUtteranceDefaultSpeechRate
        if let voice = resolveVoice(preferredIdentifier: nil) {
            silentUtterance.voice = voice
        }
        synthesizer.speak(silentUtterance)
    }
    
    /// Configura `AVAudioSession` en `.playback` + `.spokenAudio` sin `.mixWithOthers`
    /// para sonar incluso con el interruptor físico en Silencio y pausar música externa
    func activateGameAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true)
        } catch {
            // Continuar de forma segura si el hardware de audio reporta advertencia
        }
    }
    
    /// Desactiva la sesión de audio activa y devuelve el control a la música/podcasts de otras apps
    func deactivateGameAudioSession() {
        stopSpeaking()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            // Puede fallar si aún hay colas de audio cerrándose; no es crítico
        }
    }
    
    /// Detiene inmediatamente cualquier locución en curso
    func stopSpeaking() {
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
    
    /// Pronuncia la letra de un turno usando su fonética explícita en español y corte inmediato
    func speakLetter(_ letter: String, interval: Double, settings: GameSettings) {
        guard settings.voiceEnabled else { return }
        
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let key = letter.uppercased()
        let phoneticWord = Self.phoneticDictionary[key] ?? letter.lowercased()
        
        let utterance = AVSpeechUtterance(string: phoneticWord)
        utterance.voice = resolveVoice(preferredIdentifier: settings.selectedVoiceIdentifier)
        utterance.volume = min(1.0, max(0.1, settings.voiceVolume))
        utterance.rate = interval <= 1.2 ? 0.57 : 0.53
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.0
        utterance.postUtteranceDelay = 0.0
        
        synthesizer.speak(utterance)
    }
    
    /// Pronuncia la frase de prueba `"hache, jota, ka"` en la pantalla de Ajustes
    func previewVoice(settings: GameSettings) {
        activateGameAudioSession()
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: "hache, jota, ka")
        utterance.voice = resolveVoice(preferredIdentifier: settings.selectedVoiceIdentifier)
        utterance.volume = min(1.0, max(0.1, settings.voiceVolume))
        utterance.rate = 0.53
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.0
        utterance.postUtteranceDelay = 0.0
        
        synthesizer.speak(utterance)
    }
    
    /// Selecciona la voz óptima en español según la preferencia del usuario o la jerarquía de calidad/región
    func resolveVoice(preferredIdentifier: String?) -> AVSpeechSynthesisVoice? {
        if let preferredIdentifier,
           !preferredIdentifier.isEmpty,
           let chosen = AVSpeechSynthesisVoice(identifier: preferredIdentifier) {
            return chosen
        }
        
        if availableSpanishVoices.isEmpty {
            refreshAvailableVoices()
        }
        
        if let bestOption = availableSpanishVoices.first,
           let bestVoice = AVSpeechSynthesisVoice(identifier: bestOption.identifier) {
            return bestVoice
        }
        
        return AVSpeechSynthesisVoice(language: "es-MX")
            ?? AVSpeechSynthesisVoice(language: "es-US")
            ?? AVSpeechSynthesisVoice(language: "es-ES")
    }
    
    // MARK: - Helpers de Prioridad de Voz
    
    private static func qualityInfo(for quality: AVSpeechSynthesisVoiceQuality) -> (label: String, rank: Int) {
        switch quality {
        case .premium:
            return ("Premium", 3)
        case .enhanced:
            return ("Mejorada", 2)
        case .default:
            return ("Estándar", 1)
        @unknown default:
            return ("Estándar", 1)
        }
    }
    
    private static func regionPriority(for languageCode: String) -> Int {
        let normalized = languageCode.lowercased()
        if normalized == "es-mx" {
            return 4
        } else if normalized == "es-us" {
            return 3
        } else if normalized == "es-es" {
            return 2
        } else if normalized.hasPrefix("es") {
            return 1
        } else {
            return 0
        }
    }
}
