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

/// Motor híbrido de voz de latencia cero:
/// 1. Modo `.elevenLabs`: Reproduce desde memoria RAM (`[String: AVAudioPlayer]`) los 8 clips `.mp3` pre-generados.
/// 2. Modo `.systemTTS` (y fallback automático): Usa `AVSpeechSynthesizer` con fonética explícita en español.
@MainActor
final class SpeechManager: ObservableObject {
    static let shared = SpeechManager()
    
    private let synthesizer = AVSpeechSynthesizer()
    private let audioCache = ElevenLabsAudioCache.shared
    private var isWarmedUp = false
    
    /// Diccionario en memoria RAM con los 8 reproductores listos (`prepareToPlay()`)
    private var preloadedPlayers: [String: AVAudioPlayer] = [:]
    private var preloadedSignature: String = ""
    private var previewSequenceTask: Task<Void, Never>?
    
    /// Diccionario fonético exacto en español (prohibido deletrear letras sueltas)
    static let phoneticDictionary: [String: String] = StimulusStep.phoneticDictionary
    
    @Published private(set) var availableSpanishVoices: [SpanishVoiceOption] = []
    
    init() {
        refreshAvailableVoices()
    }
    
    /// Descubre y ordena todas las voces del sistema en español instaladas en el iPhone
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
    
    /// Precalienta el motor de audio y carga en RAM los 8 clips de ElevenLabs si ya están descargados
    func warmUp(settings: GameSettings? = nil) {
        if let settings {
            prepareElevenLabsPlayersIfAvailable(settings: settings)
        }
        
        guard !isWarmedUp else { return }
        isWarmedUp = true
        refreshAvailableVoices()
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // Ignorar errores de sesión en segundo plano
        }
        
        let silentUtterance = AVSpeechUtterance(string: " ")
        silentUtterance.volume = 0.0
        silentUtterance.rate = AVSpeechUtteranceDefaultSpeechRate
        if let voice = resolveVoice(preferredIdentifier: nil) {
            silentUtterance.voice = voice
        }
        synthesizer.speak(silentUtterance)
    }
    
    /// Precarga en memoria RAM los 8 archivos `.mp3` de ElevenLabs y ejecuta `prepareToPlay()`
    func prepareElevenLabsPlayersIfAvailable(settings: GameSettings, forceReload: Bool = false) {
        let voiceId = settings.effectiveElevenLabsVoiceId
        let modelId = settings.elevenLabsModelId
        guard !voiceId.isEmpty else {
            preloadedPlayers.removeAll()
            preloadedSignature = ""
            return
        }
        
        let signature = "\(voiceId)_\(modelId)"
        if !forceReload && preloadedSignature == signature && preloadedPlayers.count == 8 {
            for player in preloadedPlayers.values {
                player.prepareToPlay()
            }
            return
        }
        
        guard audioCache.isVoiceFullyCached(voiceId: voiceId, modelId: modelId) else {
            preloadedPlayers.removeAll()
            preloadedSignature = ""
            return
        }
        
        preloadedPlayers = audioCache.loadPreparedPlayers(voiceId: voiceId, modelId: modelId)
        preloadedSignature = preloadedPlayers.count == 8 ? signature : ""
    }
    
    /// Limpia los reproductores en memoria RAM cuando se regeneran o borran los archivos en caché
    func invalidatePreloadedCache() {
        stopSpeaking()
        preloadedPlayers.removeAll()
        preloadedSignature = ""
    }
    
    /// Configura `AVAudioSession` en `.playback` + `.spokenAudio` sin `.mixWithOthers`
    /// para sonar incluso con el interruptor físico en Silencio y pausar música externa
    func activateGameAudioSession(settings: GameSettings? = nil) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true)
        } catch {
            // Continuar de forma segura
        }
        
        if let settings {
            prepareElevenLabsPlayersIfAvailable(settings: settings)
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
    
    /// Detiene inmediatamente cualquier reproducción de ElevenLabs o locución de `AVSpeechSynthesizer`
    func stopSpeaking() {
        previewSequenceTask?.cancel()
        previewSequenceTask = nil
        
        for player in preloadedPlayers.values where player.isPlaying {
            player.stop()
            player.currentTime = 0
        }
        
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
    
    /// Pronuncia la letra de un turno:
    /// - Si está en modo `.elevenLabs` y las 8 letras están en caché, reproduce instantáneamente desde RAM (`0 ms` latencia).
    /// - Si no, aplica fallback automático a `AVSpeechSynthesizer` sin interrumpir el juego.
    func speakLetter(_ letter: String, interval: Double, settings: GameSettings) {
        guard settings.voiceEnabled else { return }
        
        stopSpeaking()
        let key = letter.uppercased()
        
        // 1. Intentar reproducción instantánea con ElevenLabs desde RAM
        if settings.voiceEngine == .elevenLabs {
            prepareElevenLabsPlayersIfAvailable(settings: settings)
            if let player = preloadedPlayers[key] {
                player.stop()
                player.currentTime = 0
                player.volume = min(1.0, max(0.1, settings.voiceVolume))
                player.enableRate = true
                player.rate = interval <= 1.1 ? 1.15 : 1.0
                player.play()
                return
            }
        }
        
        // 2. Fallback automático a la voz del sistema en español (`AVSpeechSynthesizer`)
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
    
    /// Reproduce en secuencia `"hache"`, `"jota"`, `"ka"` en la pantalla de Ajustes
    func previewVoice(settings: GameSettings) {
        stopSpeaking()
        activateGameAudioSession(settings: settings)
        
        if settings.voiceEngine == .elevenLabs {
            prepareElevenLabsPlayersIfAvailable(settings: settings, forceReload: true)
            if preloadedPlayers.count == 8 {
                let sampleLetters = ["H", "J", "K"]
                previewSequenceTask = Task { [weak self] in
                    guard let self else { return }
                    for (index, letter) in sampleLetters.enumerated() {
                        if Task.isCancelled { return }
                        if let player = self.preloadedPlayers[letter] {
                            player.stop()
                            player.currentTime = 0
                            player.volume = min(1.0, max(0.1, settings.voiceVolume))
                            player.enableRate = true
                            player.rate = 1.0
                            player.play()
                        }
                        if index < sampleLetters.count - 1 {
                            try? await Task.sleep(nanoseconds: 650_000_000)
                        }
                    }
                }
                return
            }
        }
        
        // Fallback o modo Voz del iPhone
        let utterance = AVSpeechUtterance(string: "hache, jota, ka")
        utterance.voice = resolveVoice(preferredIdentifier: settings.selectedVoiceIdentifier)
        utterance.volume = min(1.0, max(0.1, settings.voiceVolume))
        utterance.rate = 0.53
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.0
        utterance.postUtteranceDelay = 0.0
        
        synthesizer.speak(utterance)
    }
    
    /// Selecciona la voz óptima del sistema en español según la preferencia del usuario o jerarquía de calidad/región
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
    
    // MARK: - Helpers de Prioridad de Voz del Sistema
    
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
