import Foundation

/// Motor de voz seleccionado por el usuario
enum VoiceEngineType: String, Codable, CaseIterable, Identifiable {
    case elevenLabs = "elevenLabs"
    case systemTTS = "systemTTS"
    
    var id: String { rawValue }
    
    var displayTitle: String {
        switch self {
        case .elevenLabs:
            return "ElevenLabs AI"
        case .systemTTS:
            return "Voz del iPhone"
        }
    }
}

/// Modelos soportados de ElevenLabs para español
enum ElevenLabsModel: String, Codable, CaseIterable, Identifiable {
    case multilingualV2 = "eleven_multilingual_v2"
    case flashV2_5 = "eleven_flash_v2_5"
    
    var id: String { rawValue }
    
    var displayTitle: String {
        switch self {
        case .multilingualV2:
            return "Multilingual v2 (Máxima Calidad)"
        case .flashV2_5:
            return "Flash v2.5 (Rápido)"
        }
    }
    
    var shortTitle: String {
        switch self {
        case .multilingualV2:
            return "Multilingual v2"
        case .flashV2_5:
            return "Flash v2.5"
        }
    }
}

/// Nivel de interferencia por señuelos (Lures a N-1 y N+1)
enum LureLevel: Double, Codable, CaseIterable, Identifiable {
    case low = 0.10
    case standard = 0.20
    case high = 0.30
    
    var id: Double { rawValue }
    
    var title: String {
        switch self {
        case .low:
            return "Bajo (10%)"
        case .standard:
            return "Estándar (20%)"
        case .high:
            return "Alto (30%)"
        }
    }
    
    var shortLabel: String {
        switch self {
        case .low:
            return "10%"
        case .standard:
            return "20%"
        case .high:
            return "30%"
        }
    }
    
    static func closest(to rate: Double) -> LureLevel {
        if abs(rate - LureLevel.low.rawValue) < 0.05 {
            return .low
        } else if abs(rate - LureLevel.high.rawValue) < 0.05 {
            return .high
        } else {
            return .standard
        }
    }
}

/// Preferencias globales y de entrenamiento persistidas en `settings.json`
struct GameSettings: Codable, Equatable {
    var currentN: Int
    var isAdaptive: Bool
    var dailyGoal: Int
    var defaultInterval: Double
    var defaultDuration: Int
    var lureRate: Double
    var hapticsEnabled: Bool
    var visualFeedbackEnabled: Bool
    var fixationCrossEnabled: Bool
    var voiceEnabled: Bool
    var selectedVoiceIdentifier: String?
    var voiceVolume: Float
    
    // Preferencias de ElevenLabs AI
    var voiceEngine: VoiceEngineType
    var elevenLabsVoiceId: String
    var elevenLabsVoiceName: String
    var elevenLabsCustomVoiceId: String
    var elevenLabsModelId: String
    
    /// Devuelve el Voice ID efectivo (priorizando el Voice ID manual si el usuario escribió uno)
    var effectiveElevenLabsVoiceId: String {
        let manual = elevenLabsCustomVoiceId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !manual.isEmpty {
            return manual
        }
        return elevenLabsVoiceId.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    init(
        currentN: Int = 2,
        isAdaptive: Bool = true,
        dailyGoal: Int = 5,
        defaultInterval: Double = 1.5,
        defaultDuration: Int = 120,
        lureRate: Double = 0.20,
        hapticsEnabled: Bool = true,
        visualFeedbackEnabled: Bool = true,
        fixationCrossEnabled: Bool = true,
        voiceEnabled: Bool = true,
        selectedVoiceIdentifier: String? = nil,
        voiceVolume: Float = 1.0,
        voiceEngine: VoiceEngineType = .elevenLabs,
        elevenLabsVoiceId: String = "",
        elevenLabsVoiceName: String = "",
        elevenLabsCustomVoiceId: String = "",
        elevenLabsModelId: String = ElevenLabsModel.multilingualV2.rawValue
    ) {
        self.currentN = min(9, max(1, currentN))
        self.isAdaptive = isAdaptive
        self.dailyGoal = min(20, max(1, dailyGoal))
        self.defaultInterval = min(4.0, max(1.0, (defaultInterval * 10).rounded() / 10))
        self.defaultDuration = min(180, max(30, (defaultDuration / 10) * 10))
        self.lureRate = min(0.50, max(0.0, lureRate))
        self.hapticsEnabled = hapticsEnabled
        self.visualFeedbackEnabled = visualFeedbackEnabled
        self.fixationCrossEnabled = fixationCrossEnabled
        self.voiceEnabled = voiceEnabled
        self.selectedVoiceIdentifier = selectedVoiceIdentifier
        self.voiceVolume = min(1.0, max(0.1, voiceVolume))
        self.voiceEngine = voiceEngine
        self.elevenLabsVoiceId = elevenLabsVoiceId
        self.elevenLabsVoiceName = elevenLabsVoiceName
        self.elevenLabsCustomVoiceId = elevenLabsCustomVoiceId
        self.elevenLabsModelId = elevenLabsModelId.isEmpty ? ElevenLabsModel.multilingualV2.rawValue : elevenLabsModelId
    }
    
    enum CodingKeys: String, CodingKey {
        case currentN
        case isAdaptive
        case dailyGoal
        case defaultInterval
        case defaultDuration
        case lureRate
        case hapticsEnabled
        case visualFeedbackEnabled
        case fixationCrossEnabled
        case voiceEnabled
        case selectedVoiceIdentifier
        case voiceVolume
        case voiceEngine
        case elevenLabsVoiceId
        case elevenLabsVoiceName
        case elevenLabsCustomVoiceId
        case elevenLabsModelId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let n = try container.decodeIfPresent(Int.self, forKey: .currentN) ?? 2
        let adaptive = try container.decodeIfPresent(Bool.self, forKey: .isAdaptive) ?? true
        let goal = try container.decodeIfPresent(Int.self, forKey: .dailyGoal) ?? 5
        let interval = try container.decodeIfPresent(Double.self, forKey: .defaultInterval) ?? 1.5
        let duration = try container.decodeIfPresent(Int.self, forKey: .defaultDuration) ?? 120
        let lure = try container.decodeIfPresent(Double.self, forKey: .lureRate) ?? 0.20
        let haptics = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        let visual = try container.decodeIfPresent(Bool.self, forKey: .visualFeedbackEnabled) ?? true
        let cross = try container.decodeIfPresent(Bool.self, forKey: .fixationCrossEnabled) ?? true
        let voice = try container.decodeIfPresent(Bool.self, forKey: .voiceEnabled) ?? true
        let voiceId = try container.decodeIfPresent(String.self, forKey: .selectedVoiceIdentifier)
        let volume = try container.decodeIfPresent(Float.self, forKey: .voiceVolume) ?? 1.0
        
        let engine = try container.decodeIfPresent(VoiceEngineType.self, forKey: .voiceEngine) ?? .elevenLabs
        let elVoiceId = try container.decodeIfPresent(String.self, forKey: .elevenLabsVoiceId) ?? ""
        let elVoiceName = try container.decodeIfPresent(String.self, forKey: .elevenLabsVoiceName) ?? ""
        let elCustomVoiceId = try container.decodeIfPresent(String.self, forKey: .elevenLabsCustomVoiceId) ?? ""
        let elModelId = try container.decodeIfPresent(String.self, forKey: .elevenLabsModelId) ?? ElevenLabsModel.multilingualV2.rawValue
        
        self.init(
            currentN: n,
            isAdaptive: adaptive,
            dailyGoal: goal,
            defaultInterval: interval,
            defaultDuration: duration,
            lureRate: lure,
            hapticsEnabled: haptics,
            visualFeedbackEnabled: visual,
            fixationCrossEnabled: cross,
            voiceEnabled: voice,
            selectedVoiceIdentifier: voiceId,
            voiceVolume: volume,
            voiceEngine: engine,
            elevenLabsVoiceId: elVoiceId,
            elevenLabsVoiceName: elVoiceName,
            elevenLabsCustomVoiceId: elCustomVoiceId,
            elevenLabsModelId: elModelId
        )
    }
}
