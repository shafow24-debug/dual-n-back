import Foundation
import AVFoundation

/// Banco de voz pre-generado en caché local (`Documents/ElevenLabsCache/<voice_id>_<model_id>/<letra>.mp3`)
/// Garantiza 0 ms de latencia durante el juego y 0 consumo repetido de créditos de ElevenLabs.
final class ElevenLabsAudioCache {
    static let shared = ElevenLabsAudioCache()
    
    private let fileManager = FileManager.default
    private let baseCacheURL: URL
    
    /// Las 8 letras del protocolo y su nombre de archivo fonético sin extensión
    static let lettersToPhoneticFilename: [(letter: String, filename: String, spokenPrompt: String)] = [
        ("H", "hache", "hache."),
        ("J", "jota", "jota."),
        ("K", "ka", "ka."),
        ("L", "ele", "ele."),
        ("Q", "cu", "cu."),
        ("R", "erre", "erre."),
        ("X", "equis", "equis."),
        ("T", "te", "te.")
    ]
    
    init(customRootDirectory: URL? = nil) {
        let docs = customRootDirectory ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.baseCacheURL = docs.appendingPathComponent("ElevenLabsCache", isDirectory: true)
    }
    
    /// Devuelve la carpeta específica para una combinación `<voice_id>_<model_id>`
    func directoryURL(voiceId: String, modelId: String) -> URL {
        let safeVoice = Self.sanitizeIdentifier(voiceId)
        let safeModel = Self.sanitizeIdentifier(modelId)
        return baseCacheURL.appendingPathComponent("\(safeVoice)_\(safeModel)", isDirectory: true)
    }
    
    /// Devuelve la ruta `.mp3` para una letra (`"H"`, `"J"`, etc.)
    func fileURL(forLetter letter: String, voiceId: String, modelId: String) -> URL {
        let upper = letter.uppercased()
        let phonetic = StimulusStep.phoneticDictionary[upper] ?? letter.lowercased()
        return directoryURL(voiceId: voiceId, modelId: modelId)
            .appendingPathComponent("\(phonetic).mp3")
    }
    
    /// Guarda en disco el archivo `.mp3` descargado para una letra
    func saveAudioData(_ data: Data, forLetter letter: String, voiceId: String, modelId: String) throws {
        let dir = directoryURL(voiceId: voiceId, modelId: modelId)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        let destination = fileURL(forLetter: letter, voiceId: voiceId, modelId: modelId)
        try data.write(to: destination, options: [.atomic])
    }
    
    /// Cuenta cuántas de las 8 letras están descargadas y son válidas (> 256 bytes) para la voz y modelo dados
    func cachedLettersCount(voiceId: String, modelId: String) -> Int {
        let trimmedVoice = voiceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedVoice.isEmpty else { return 0 }
        
        var count = 0
        for item in Self.lettersToPhoneticFilename {
            let url = fileURL(forLetter: item.letter, voiceId: trimmedVoice, modelId: modelId)
            if let attrs = try? fileManager.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? NSNumber,
               size.intValue > 256 {
                count += 1
            }
        }
        return count
    }
    
    /// Indica si las 8 letras están completamente descargadas en el iPhone para uso offline
    func isVoiceFullyCached(voiceId: String, modelId: String) -> Bool {
        cachedLettersCount(voiceId: voiceId, modelId: modelId) == Self.lettersToPhoneticFilename.count
    }
    
    /// Carga los 8 archivos `.mp3` en memoria RAM (`[String: AVAudioPlayer]`) y ejecuta `prepareToPlay()`
    func loadPreparedPlayers(voiceId: String, modelId: String) -> [String: AVAudioPlayer] {
        let trimmedVoice = voiceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedVoice.isEmpty else { return [:] }
        
        var players: [String: AVAudioPlayer] = [:]
        for item in Self.lettersToPhoneticFilename {
            let url = fileURL(forLetter: item.letter, voiceId: trimmedVoice, modelId: modelId)
            guard fileManager.fileExists(atPath: url.path),
                  let player = try? AVAudioPlayer(contentsOf: url) else {
                continue
            }
            player.enableRate = true
            player.prepareToPlay()
            players[item.letter] = player
        }
        return players
    }
    
    /// Calcula el tamaño total en bytes de todos los archivos en `Documents/ElevenLabsCache`
    func totalCacheSizeBytes() -> Int64 {
        guard fileManager.fileExists(atPath: baseCacheURL.path),
              let enumerator = fileManager.enumerator(
                at: baseCacheURL,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
              ) else {
            return 0
        }
        
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
               values.isRegularFile == true,
               let fileSize = values.fileSize {
                total += Int64(fileSize)
            }
        }
        return total
    }
    
    /// Devuelve el espacio ocupado en formato legible (ej. `"142 KB"` o `"0 KB"`)
    func formattedCacheSize() -> String {
        let bytes = totalCacheSizeBytes()
        if bytes <= 0 {
            return "0 KB"
        }
        let kb = Double(bytes) / 1024.0
        if kb < 1024.0 {
            return String(format: "%.0f KB", max(1.0, kb))
        } else {
            let mb = kb / 1024.0
            return String(format: "%.2f MB", mb)
        }
    }
    
    /// Elimina todos los paquetes de voz descargados en `Documents/ElevenLabsCache`
    func clearAllCache() {
        if fileManager.fileExists(atPath: baseCacheURL.path) {
            try? fileManager.removeItem(at: baseCacheURL)
        }
    }
    
    private static func sanitizeIdentifier(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: allowed.inverted)
            .joined(separator: "_")
        return cleaned.isEmpty ? "default" : cleaned
    }
}
