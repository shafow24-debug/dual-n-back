import Foundation

/// Representa un turno individual dentro de una secuencia de Dual N-Back
struct StimulusStep: Identifiable, Equatable, Codable {
    /// Las 8 letras fonéticamente inconfundibles en español seleccionadas para el protocolo
    static let allowedLetters: [String] = ["H", "J", "K", "L", "Q", "R", "X", "T"]
    
    /// Diccionario fonético explícito en español (en minúsculas) para síntesis de voz limpia
    static let phoneticDictionary: [String: String] = [
        "H": "hache",
        "J": "jota",
        "K": "ka",
        "L": "ele",
        "Q": "cu",
        "R": "erre",
        "X": "equis",
        "T": "te"
    ]
    
    /// Índice basado en 0 dentro de la sesión (`0 ..< totalTurns`)
    let index: Int
    
    /// Posición en la cuadrícula 3x3 (`0...8`)
    let position: Int
    
    /// Letra pronunciada en este turno (`"H"`, `"J"`, `"K"`, `"L"`, `"Q"`, `"R"`, `"X"`, `"T"`)
    let letter: String
    
    /// Indica si este turno pertenece a los turnos evaluables (`index >= nLevel`)
    let isEvaluatedTurn: Bool
    
    /// Indica si la posición coincide exactamente con `index - nLevel`
    let isPositionTarget: Bool
    
    /// Indica si el sonido (letra) coincide exactamente con `index - nLevel`
    let isSoundTarget: Bool
    
    /// Indica si la posición fue generada como señuelo de interferencia (`N-1` o `N+1`)
    let isPositionLure: Bool
    
    /// Indica si el sonido fue generado como señuelo de interferencia (`N-1` o `N+1`)
    let isSoundLure: Bool
    
    var id: Int { index }
    
    /// Texto fonético exacto que debe pronunciar `AVSpeechSynthesizer`
    var phoneticText: String {
        Self.phoneticDictionary[letter.uppercased()] ?? letter.lowercased()
    }
}
