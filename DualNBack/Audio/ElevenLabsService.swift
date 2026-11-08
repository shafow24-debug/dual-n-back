import Foundation

/// Modelo de una voz de ElevenLabs devuelta por `GET /v1/voices`
struct ElevenLabsVoice: Identifiable, Codable, Equatable, Hashable {
    let voice_id: String
    let name: String
    let category: String?
    let labels: [String: String]?
    let preview_url: String?
    
    var id: String { voice_id }
    
    /// Indica si es una voz clonada, profesional o creada por el usuario (`category != "premade"`)
    var isCustomVoice: Bool {
        guard let category = category?.lowercased() else { return false }
        return category != "premade"
    }
    
    /// Etiqueta en español para la categoría de la voz
    var categoryDisplayName: String {
        switch (category ?? "premade").lowercased() {
        case "cloned":
            return "Clonada"
        case "professional":
            return "Profesional"
        case "generated":
            return "Creada"
        case "high_quality":
            return "Library"
        case "premade":
            return "Premade"
        default:
            return (category ?? "Premade").capitalized
        }
    }
    
    /// Resumen compacto de etiquetas útiles (`accent`, `language`, `gender`) si están disponibles
    var labelsSummary: String {
        guard let labels, !labels.isEmpty else { return "" }
        let preferredKeys = ["accent", "language", "descriptive", "gender"]
        var parts: [String] = []
        for key in preferredKeys {
            if let val = labels[key], !val.isEmpty {
                parts.append(val)
            }
        }
        if parts.isEmpty {
            parts = Array(labels.values.prefix(2))
        }
        return parts.joined(separator: ", ")
    }
    
    /// Texto formateado para el selector en Ajustes
    var displayTitle: String {
        let summary = labelsSummary
        if summary.isEmpty {
            return "\(name) • [\(categoryDisplayName)]"
        } else {
            return "\(name) • [\(categoryDisplayName)] (\(summary))"
        }
    }
}

private struct ElevenLabsVoicesResponse: Codable {
    let voices: [ElevenLabsVoice]
}

private struct ElevenLabsErrorEnvelope: Codable {
    struct DetailObject: Codable {
        let status: String?
        let message: String?
    }
    let detail: DetailObject?
}

/// Errores descriptivos en español para el servicio de ElevenLabs
enum ElevenLabsError: LocalizedError {
    case missingAPIKey
    case missingVoiceId
    case invalidURL
    case unauthorized
    case httpError(statusCode: Int, message: String)
    case emptyAudioData
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Ingresa tu API Key de ElevenLabs antes de continuar."
        case .missingVoiceId:
            return "Selecciona una voz de la lista o escribe un Voice ID válido."
        case .invalidURL:
            return "El Voice ID contiene caracteres no válidos para la URL."
        case .unauthorized:
            return "API Key inválida o sin autorización (HTTP 401). Verifica tu xi-api-key."
        case .httpError(let code, let message):
            return "Error de ElevenLabs (HTTP \(code)): \(message)"
        case .emptyAudioData:
            return "El servidor devolvió un archivo de audio vacío."
        case .networkError(let reason):
            return "Error de conexión: \(reason)"
        }
    }
}

/// Servicio de comunicación con la API de ElevenLabs (`GET /v1/voices` y `POST /v1/text-to-speech/{voice_id}`)
final class ElevenLabsService {
    static let shared = ElevenLabsService()
    
    private let session: URLSession
    private let voicesCacheURL: URL
    
    init(session: URLSession = .shared) {
        self.session = session
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.voicesCacheURL = docs.appendingPathComponent("elevenlabs_voices_cache.json")
    }
    
    // MARK: - 1. Obtener y Ordenar Voces (`GET /v1/voices`)
    
    /// Consulta `https://api.elevenlabs.io/v1/voices` y ordena primero las voces Clonadas/Profesionales/Creadas
    func fetchVoices(apiKey: String) async throws -> [ElevenLabsVoice] {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw ElevenLabsError.missingAPIKey
        }
        
        guard let url = URL(string: "https://api.elevenlabs.io/v1/voices") else {
            throw ElevenLabsError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue(trimmedKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ElevenLabsError.networkError(error.localizedDescription)
        }
        
        guard let http = response as? HTTPURLResponse else {
            throw ElevenLabsError.networkError("Respuesta HTTP inválida")
        }
        
        if http.statusCode == 401 {
            throw ElevenLabsError.unauthorized
        }
        guard (200...299).contains(http.statusCode) else {
            let msg = Self.extractErrorMessage(from: data)
            throw ElevenLabsError.httpError(statusCode: http.statusCode, message: msg)
        }
        
        let decoded = try JSONDecoder().decode(ElevenLabsVoicesResponse.self, from: data)
        let sorted = Self.sortVoices(decoded.voices)
        saveCachedVoicesList(sorted)
        return sorted
    }
    
    /// Ordena las voces poniendo primero Clonadas / Profesionales / Creadas (`category != "premade"`)
    static func sortVoices(_ voices: [ElevenLabsVoice]) -> [ElevenLabsVoice] {
        voices.sorted { lhs, rhs in
            let lhsRank = categoryPriority(lhs.category)
            let rhsRank = categoryPriority(rhs.category)
            if lhsRank != rhsRank {
                return lhsRank > rhsRank
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
    
    private static func categoryPriority(_ category: String?) -> Int {
        switch (category ?? "premade").lowercased() {
        case "cloned":
            return 5
        case "professional":
            return 4
        case "generated":
            return 3
        case "high_quality":
            return 2
        case "premade":
            return 1
        default:
            return 2
        }
    }
    
    // MARK: - Caché Local de Lista de Voces
    
    func loadCachedVoicesList() -> [ElevenLabsVoice] {
        guard let data = try? Data(contentsOf: voicesCacheURL),
              let voices = try? JSONDecoder().decode([ElevenLabsVoice].self, from: data) else {
            return []
        }
        return voices
    }
    
    private func saveCachedVoicesList(_ voices: [ElevenLabsVoice]) {
        if let data = try? JSONEncoder().encode(voices) {
            try? data.write(to: voicesCacheURL, options: [.atomic])
        }
    }
    
    // MARK: - 2. Descarga Pre-Generada de las 8 Letras (`POST /v1/text-to-speech/{voice_id}`)
    
    /// Descarga las 8 letras en español con un `ThrowingTaskGroup` (máximo 3 peticiones simultáneas)
    /// y las almacena permanentemente en `ElevenLabsAudioCache`.
    func downloadAllEightLetters(
        apiKey: String,
        voiceId: String,
        modelId: String,
        cache: ElevenLabsAudioCache = .shared,
        onProgress: @escaping @Sendable (Int, Int) -> Void
    ) async throws {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw ElevenLabsError.missingAPIKey
        }
        
        let trimmedVoice = voiceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedVoice.isEmpty else {
            throw ElevenLabsError.missingVoiceId
        }
        
        let items = ElevenLabsAudioCache.lettersToPhoneticFilename
        let totalCount = items.count
        let maxConcurrency = 3
        
        onProgress(0, totalCount)
        
        try await withThrowingTaskGroup(of: (String, Data).self) { group in
            var nextIndex = 0
            var completedCount = 0
            
            // Lanzar las primeras `maxConcurrency` tareas
            while nextIndex < min(maxConcurrency, totalCount) {
                let item = items[nextIndex]
                nextIndex += 1
                group.addTask {
                    let audioData = try await self.synthesizeSingleLetter(
                        promptText: item.spokenPrompt,
                        apiKey: trimmedKey,
                        voiceId: trimmedVoice,
                        modelId: modelId
                    )
                    return (item.letter, audioData)
                }
            }
            
            // A medida que cada tarea termina, guardamos el .mp3 y encolamos la siguiente letra
            for try await (letter, audioData) in group {
                try cache.saveAudioData(
                    audioData,
                    forLetter: letter,
                    voiceId: trimmedVoice,
                    modelId: modelId
                )
                completedCount += 1
                onProgress(completedCount, totalCount)
                
                if nextIndex < totalCount {
                    let nextItem = items[nextIndex]
                    nextIndex += 1
                    group.addTask {
                        let data = try await self.synthesizeSingleLetter(
                            promptText: nextItem.spokenPrompt,
                            apiKey: trimmedKey,
                            voiceId: trimmedVoice,
                            modelId: modelId
                        )
                        return (nextItem.letter, data)
                    }
                }
            }
        }
    }
    
    /// Genera el clip `.mp3` de una letra con fallback automático si el modelo rechaza `language_code` (HTTP 400/422)
    func synthesizeSingleLetter(
        promptText: String,
        apiKey: String,
        voiceId: String,
        modelId: String
    ) async throws -> Data {
        do {
            return try await performTTSRequest(
                promptText: promptText,
                apiKey: apiKey,
                voiceId: voiceId,
                modelId: modelId,
                includeLanguageCode: true,
                includeSpeed: true
            )
        } catch ElevenLabsError.httpError(let code, _) where code == 400 || code == 422 {
            // Fallback automático reintentando sin `language_code`
            do {
                return try await performTTSRequest(
                    promptText: promptText,
                    apiKey: apiKey,
                    voiceId: voiceId,
                    modelId: modelId,
                    includeLanguageCode: false,
                    includeSpeed: true
                )
            } catch ElevenLabsError.httpError(let retryCode, _) where retryCode == 400 || retryCode == 422 {
                // Segundo fallback sin `language_code` ni `speed`
                return try await performTTSRequest(
                    promptText: promptText,
                    apiKey: apiKey,
                    voiceId: voiceId,
                    modelId: modelId,
                    includeLanguageCode: false,
                    includeSpeed: false
                )
            }
        }
    }
    
    private func performTTSRequest(
        promptText: String,
        apiKey: String,
        voiceId: String,
        modelId: String,
        includeLanguageCode: Bool,
        includeSpeed: Bool
    ) async throws -> Data {
        let encodedVoiceId = voiceId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? voiceId
        let urlString = "https://api.elevenlabs.io/v1/text-to-speech/\(encodedVoiceId)?output_format=mp3_44100_128"
        guard let url = URL(string: urlString) else {
            throw ElevenLabsError.invalidURL
        }
        
        var voiceSettings: [String: Any] = [
            "stability": 0.75,
            "similarity_boost": 0.80,
            "style": 0.0,
            "use_speaker_boost": true
        ]
        if includeSpeed {
            voiceSettings["speed"] = 1.08
        }
        
        var payload: [String: Any] = [
            "text": promptText,
            "model_id": modelId,
            "voice_settings": voiceSettings
        ]
        if includeLanguageCode {
            payload["language_code"] = "es"
        }
        
        let bodyData = try JSONSerialization.data(withJSONObject: payload, options: [])
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        request.httpBody = bodyData
        
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ElevenLabsError.networkError(error.localizedDescription)
        }
        
        guard let http = response as? HTTPURLResponse else {
            throw ElevenLabsError.networkError("Respuesta HTTP inválida")
        }
        
        if http.statusCode == 401 {
            throw ElevenLabsError.unauthorized
        }
        guard (200...299).contains(http.statusCode) else {
            let msg = Self.extractErrorMessage(from: data)
            throw ElevenLabsError.httpError(statusCode: http.statusCode, message: msg)
        }
        
        guard data.count > 256 else {
            throw ElevenLabsError.emptyAudioData
        }
        
        return data
    }
    
    private static func extractErrorMessage(from data: Data) -> String {
        if let decoded = try? JSONDecoder().decode(ElevenLabsErrorEnvelope.self, from: data),
           let msg = decoded.detail?.message,
           !msg.isEmpty {
            return msg
        }
        if let rawText = String(data: data, encoding: .utf8), !rawText.isEmpty {
            return String(rawText.prefix(180))
        }
        return "Error desconocido en la solicitud."
    }
}
