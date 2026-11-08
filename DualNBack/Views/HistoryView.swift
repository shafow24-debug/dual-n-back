import SwiftUI

/// Pantalla de Historial de sesiones completadas ordenadas de la más reciente a la más antigua
struct HistoryView: View {
    @ObservedObject var storage: StorageManager
    @Environment(\.dismiss) private var dismiss
    
    private static let spanishDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "d MMM yyyy, HH:mm"
        return formatter
    }()
    
    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Encabezado
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .heavy))
                            Text("Inicio")
                                .font(Theme.font(.headline, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            Capsule()
                                .fill(Theme.primaryBlue)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Text("Historial")
                        .font(Theme.font(.title2, weight: .heavy))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Espaciador simétrico
                    Color.clear
                        .frame(width: 78, height: 36)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 12)
                
                if storage.sessions.isEmpty {
                    emptyStateView
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 14) {
                            ForEach(storage.sessions) { session in
                                sessionCard(session)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 6)
                        .padding(.bottom, 28)
                    }
                }
            }
        }
    }
    
    // MARK: - Estado Vacío
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.20))
                    .frame(width: 96, height: 96)
                
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text("Aún no hay sesiones registradas")
                .font(Theme.font(.title3, weight: .heavy))
                .foregroundColor(.white)
            
            Text("Completa tu primera partida de Dual N-Back para ver aquí el registro detallado de tu progreso.")
                .font(Theme.font(.subheadline, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    // MARK: - Tarjeta de Sesión
    
    private func sessionCard(_ session: SessionResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Fila superior: Fecha en español + Insignia destacada "N = X"
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                    
                    Text(Self.spanishDateFormatter.string(from: session.timestamp))
                        .font(Theme.font(.subheadline, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text("N = \(session.nLevel)")
                    .font(Theme.font(.subheadline, weight: .heavy))
                    .foregroundColor(Theme.darkBlue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Theme.accentYellow)
                    )
            }
            
            // Fila central: % SOUND, % POSITION y % Promedio
            HStack(spacing: 10) {
                scorePill(
                    icon: "music.note",
                    title: "SOUND",
                    percentage: session.soundAccuracyInt
                )
                
                scorePill(
                    icon: "square.fill",
                    title: "POSITION",
                    percentage: session.positionAccuracyInt
                )
                
                scorePill(
                    icon: "sparkles",
                    title: "PROMEDIO",
                    percentage: session.combinedAccuracyInt,
                    highlighted: true
                )
            }
            
            // Fila inferior: Metadatos de intervalo, duración y turnos evaluados
            HStack(spacing: 14) {
                Label(String(format: "%.1fs", session.interval), systemImage: "timer")
                Label("\(session.duration)s", systemImage: "hourglass")
                Label("\(session.evaluatedTurns) turnos", systemImage: "number.square")
                
                Spacer()
                
                if session.progression == .increased {
                    Text("↑ N = \(session.resultingN)")
                        .font(Theme.font(.caption, weight: .heavy))
                        .foregroundColor(Theme.accentYellow)
                } else if session.progression == .decreased {
                    Text("↓ N = \(session.resultingN)")
                        .font(Theme.font(.caption, weight: .heavy))
                        .foregroundColor(Color.white.opacity(0.85))
                }
            }
            .font(Theme.font(.caption, weight: .semibold))
            .foregroundColor(.white.opacity(0.9))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.mediumBlue)
                .softShadow()
        )
    }
    
    private func scorePill(
        icon: String,
        title: String,
        percentage: Int,
        highlighted: Bool = false
    ) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(Theme.font(size: 11, weight: .heavy))
            }
            .foregroundColor(.white.opacity(0.9))
            
            Text("\(percentage)%")
                .font(Theme.font(.title3, weight: .heavy))
                .foregroundColor(highlighted ? Theme.accentYellow : .white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.darkBlue.opacity(0.55))
        )
    }
}
