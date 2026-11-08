import Foundation
import Combine

/// Punto de datos para la gráfica de evolución de Nivel N en Swift Charts
struct NProgressionPoint: Identifiable, Equatable {
    let id: UUID
    let index: Int
    let date: Date
    let nLevel: Int
    let resultingN: Int
    let combinedAccuracy: Double
}

/// Punto de datos para la gráfica de sesiones por día (últimos 14 días) en Swift Charts
struct DailySessionCount: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let shortDayLabel: String
    let count: Int
}

/// Gestor de persistencia local en archivos JSON (`settings.json` y `sessions.json`)
@MainActor
final class StorageManager: ObservableObject {
    static let shared = StorageManager()
    
    @Published var settings: GameSettings {
        didSet {
            if settings != oldValue {
                saveSettings()
            }
        }
    }
    
    @Published private(set) var sessions: [SessionResult] = []
    
    private let fileManager = FileManager.default
    private let settingsURL: URL
    private let sessionsURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    init(customDirectory: URL? = nil) {
        let baseDir = customDirectory ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.settingsURL = baseDir.appendingPathComponent("settings.json")
        self.sessionsURL = baseDir.appendingPathComponent("sessions.json")
        
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc
        
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec
        
        // Cargar settings.json
        if let data = try? Data(contentsOf: settingsURL),
           let loaded = try? dec.decode(GameSettings.self, from: data) {
            self.settings = loaded
        } else {
            self.settings = GameSettings()
        }
        
        // Cargar sessions.json
        if let data = try? Data(contentsOf: sessionsURL),
           let loaded = try? dec.decode([SessionResult].self, from: data) {
            self.sessions = loaded.sorted { $0.timestamp > $1.timestamp }
        } else {
            self.sessions = []
        }
    }
    
    // MARK: - Guardado en Disco
    
    func saveSettings() {
        do {
            let data = try encoder.encode(settings)
            try data.write(to: settingsURL, options: [.atomic])
        } catch {
            // Fallo silencioso en caso de permisos de sistema
        }
    }
    
    private func saveSessions() {
        do {
            let data = try encoder.encode(sessions)
            try data.write(to: sessionsURL, options: [.atomic])
        } catch {
            // Fallo silencioso en caso de permisos de sistema
        }
    }
    
    /// Registra una sesión completada, actualiza el nivel N actual y guarda ambos archivos JSON
    func recordSession(_ result: SessionResult) {
        sessions.insert(result, at: 0)
        sessions.sort { $0.timestamp > $1.timestamp }
        saveSessions()
        
        if settings.currentN != result.resultingN {
            settings.currentN = result.resultingN
        }
    }
    
    /// Borra todo el historial de sesiones y reinicia estadísticas conservando las preferencias de voz y ajustes
    func clearHistory() {
        sessions.removeAll()
        saveSessions()
    }
    
    // MARK: - Métricas Dinámicas por Calendario Local
    
    /// Número de sesiones completadas en el día natural actual (`startOfDay`)
    var sessionsCompletedToday: Int {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        return sessions.filter { calendar.startOfDay(for: $0.timestamp) == todayStart }.count
    }
    
    /// Indica si la meta diaria de sesiones se ha cumplido hoy
    var isDailyGoalMetToday: Bool {
        sessionsCompletedToday >= settings.dailyGoal
    }
    
    /// Nivel N máximo histórico alcanzado
    var maxNReached: Int {
        guard !sessions.isEmpty else { return settings.currentN }
        let maxPlayed = sessions.map(\.nLevel).max() ?? settings.currentN
        let maxResulting = sessions.map(\.resultingN).max() ?? settings.currentN
        return max(settings.currentN, max(maxPlayed, maxResulting))
    }
    
    /// Total de sesiones completadas históricamente
    var totalSessionsCount: Int {
        sessions.count
    }
    
    /// Tiempo total entrenado en segundos
    var totalTrainedSeconds: Int {
        sessions.reduce(0) { $0 + $1.duration }
    }
    
    /// Tiempo total entrenado formateado en español (`"12 min"` o `"1 h 25 min"`)
    var formattedTotalTrainedTime: String {
        let totalMinutes = totalTrainedSeconds / 60
        if totalMinutes < 60 {
            return "\(totalMinutes) min"
        } else {
            let hours = totalMinutes / 60
            let mins = totalMinutes % 60
            if mins == 0 {
                return "\(hours) h"
            } else {
                return "\(hours) h \(mins) min"
            }
        }
    }
    
    /// Racha actual de días consecutivos cumpliendo la meta diaria configurada (`Calendar.current`)
    var currentStreakDays: Int {
        guard !sessions.isEmpty else { return 0 }
        let calendar = Calendar.current
        let goal = max(1, settings.dailyGoal)
        
        var countsByDay: [Date: Int] = [:]
        for session in sessions {
            let day = calendar.startOfDay(for: session.timestamp)
            countsByDay[day, default: 0] += 1
        }
        
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var checkDate = today
        
        // Si hoy ya cumplió la meta, empezamos contando hoy; si aún no la cumple hoy,
        // verificamos desde ayer para mostrar la racha vigente que sigue activa hoy.
        if (countsByDay[today] ?? 0) >= goal {
            streak += 1
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
                return streak
            }
            checkDate = yesterday
        } else {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
                return 0
            }
            checkDate = yesterday
        }
        
        while (countsByDay[checkDate] ?? 0) >= goal {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                break
            }
            checkDate = previousDay
        }
        
        return streak
    }
    
    /// Serie cronológica de sesiones (de más antigua a más reciente, hasta las últimas 30) para la Gráfica 1
    var progressionChartPoints: [NProgressionPoint] {
        let chronological = Array(sessions.reversed().suffix(30))
        return chronological.enumerated().map { idx, session in
            NProgressionPoint(
                id: session.id,
                index: idx + 1,
                date: session.timestamp,
                nLevel: session.nLevel,
                resultingN: session.resultingN,
                combinedAccuracy: session.combinedAccuracy
            )
        }
    }
    
    /// Serie de los últimos 14 días naturales para la Gráfica 2 (Sesiones por día)
    var last14DaysCounts: [DailySessionCount] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var countsByDay: [Date: Int] = [:]
        for session in sessions {
            let day = calendar.startOfDay(for: session.timestamp)
            countsByDay[day, default: 0] += 1
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "d MMM"
        
        var results: [DailySessionCount] = []
        for offset in stride(from: -13, through: 0, by: 1) {
            if let dayDate = calendar.date(byAdding: .day, value: offset, to: today) {
                let count = countsByDay[dayDate] ?? 0
                let label = formatter.string(from: dayDate)
                results.append(
                    DailySessionCount(
                        date: dayDate,
                        shortDayLabel: label,
                        count: count
                    )
                )
            }
        }
        return results
    }
}
