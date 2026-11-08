import SwiftUI
import Charts

/// Pantalla de Estadísticas con 4 KPIs y 2 gráficas nativas de Swift Charts
struct StatsView: View {
    @ObservedObject var storage: StorageManager
    @Environment(\.dismiss) private var dismiss
    
    private let kpiColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]
    
    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Encabezado superior
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
                    
                    Text("Estadísticas")
                        .font(Theme.font(.title2, weight: .heavy))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Color.clear
                        .frame(width: 78, height: 36)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 12)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        // MARK: - Cuadrícula 2x2 de 4 Tarjetas KPI
                        LazyVGrid(columns: kpiColumns, spacing: 14) {
                            kpiCard(
                                icon: "brain.head.profile",
                                title: "N Máximo",
                                value: "N = \(storage.maxNReached)",
                                subtitle: "Histórico alcanzado"
                            )
                            
                            kpiCard(
                                icon: "checkmark.seal.fill",
                                title: "Sesiones",
                                value: "\(storage.totalSessionsCount)",
                                subtitle: "Completadas en total"
                            )
                            
                            kpiCard(
                                icon: "clock.fill",
                                title: "Tiempo Total",
                                value: storage.formattedTotalTrainedTime,
                                subtitle: "Entrenamiento activo"
                            )
                            
                            kpiCard(
                                icon: "flame.fill",
                                title: "Racha Actual",
                                value: "\(storage.currentStreakDays) d",
                                subtitle: "Meta: \(storage.settings.dailyGoal)/día"
                            )
                        }
                        
                        // MARK: - Gráfica 1: Evolución de Nivel N (Swift Charts)
                        nProgressionChartCard
                        
                        // MARK: - Gráfica 2: Sesiones por Día - Últimos 14 Días (Swift Charts)
                        dailySessionsChartCard
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 6)
                    .padding(.bottom, 28)
                }
            }
        }
    }
    
    // MARK: - Tarjeta KPI Individual
    
    private func kpiCard(icon: String, title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.accentYellow)
                
                Text(title)
                    .font(Theme.font(.subheadline, weight: .bold))
                    .foregroundColor(.white.opacity(0.92))
            }
            
            Text(value)
                .font(Theme.font(size: 28, weight: .heavy))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            
            Text(subtitle)
                .font(Theme.font(.caption2, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.mediumBlue)
                .softShadow()
        )
    }
    
    // MARK: - Gráfica 1: Evolución de Nivel N
    
    private var nProgressionChartCard: some View {
        let points = storage.progressionChartPoints
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Evolución de Nivel N")
                        .font(Theme.font(.headline, weight: .heavy))
                        .foregroundColor(.white)
                    
                    Text("Últimas sesiones completadas")
                        .font(Theme.font(.caption, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
                
                Spacer()
                
                Text("Actual: N = \(storage.settings.currentN)")
                    .font(Theme.font(.caption, weight: .heavy))
                    .foregroundColor(Theme.darkBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Theme.accentYellow)
                    )
            }
            
            if points.isEmpty {
                emptyChartPlaceholder(text: "Completa sesiones para graficar la evolución de tu nivel N.")
            } else {
                Chart {
                    ForEach(points) { point in
                        AreaMark(
                            x: .value("Sesión", point.index),
                            yStart: .value("Base", 1),
                            yEnd: .value("Nivel N", point.resultingN)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Theme.accentYellow.opacity(0.48),
                                    Theme.accentYellow.opacity(0.05)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        
                        LineMark(
                            x: .value("Sesión", point.index),
                            y: .value("Nivel N", point.resultingN)
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(Theme.accentYellow)
                        
                        PointMark(
                            x: .value("Sesión", point.index),
                            y: .value("Nivel N", point.resultingN)
                        )
                        .symbolSize(45)
                        .foregroundStyle(Color.white)
                    }
                }
                .chartYScale(domain: 1...9)
                .chartYAxis {
                    AxisMarks(values: [1, 3, 5, 7, 9]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.6, dash: [4, 4]))
                            .foregroundStyle(Color.white.opacity(0.25))
                        AxisValueLabel {
                            if let intVal = value.as(Int.self) {
                                Text("N\(intVal)")
                                    .font(Theme.font(.caption2, weight: .bold))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let intVal = value.as(Int.self) {
                                Text("#\(intVal)")
                                    .font(Theme.font(.caption2, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                        }
                    }
                }
                .frame(height: 185)
                .padding(.top, 4)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.mediumBlue)
                .softShadow()
        )
    }
    
    // MARK: - Gráfica 2: Sesiones por Día (Últimos 14 Días)
    
    private var dailySessionsChartCard: some View {
        let dailyData = storage.last14DaysCounts
        let dailyGoal = storage.settings.dailyGoal
        let maxCount = max(dailyGoal + 1, (dailyData.map(\.count).max() ?? 0) + 1)
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sesiones por día")
                        .font(Theme.font(.headline, weight: .heavy))
                        .foregroundColor(.white)
                    
                    Text("Últimos 14 días vs. meta diaria (\(dailyGoal))")
                        .font(Theme.font(.caption, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
                
                Spacer()
                
                Text("Hoy: \(storage.sessionsCompletedToday)/\(dailyGoal)")
                    .font(Theme.font(.caption, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Theme.darkBlue)
                    )
            }
            
            Chart {
                ForEach(dailyData) { item in
                    BarMark(
                        x: .value("Día", item.date, unit: .day),
                        y: .value("Sesiones", item.count)
                    )
                    .cornerRadius(5)
                    .foregroundStyle(
                        item.count >= dailyGoal
                            ? Theme.accentYellow
                            : Color.white.opacity(0.65)
                    )
                }
                
                RuleMark(y: .value("Meta Diaria", dailyGoal))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 5]))
                    .foregroundStyle(Theme.accentOrange)
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Meta \(dailyGoal)")
                            .font(Theme.font(.caption2, weight: .heavy))
                            .foregroundColor(Theme.accentYellow)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Theme.darkBlue.opacity(0.85))
                            )
                    }
            }
            .chartYScale(domain: 0...maxCount)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.6, dash: [4, 4]))
                        .foregroundStyle(Color.white.opacity(0.25))
                    AxisValueLabel {
                        if let intVal = value.as(Int.self) {
                            Text("\(intVal)")
                                .font(Theme.font(.caption2, weight: .bold))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 3)) { value in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: true)
                        .font(Theme.font(.caption2, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
            }
            .frame(height: 185)
            .padding(.top, 4)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.mediumBlue)
                .softShadow()
        )
    }
    
    private func emptyChartPlaceholder(text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white.opacity(0.75))
            
            Text(text)
                .font(Theme.font(.caption, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.darkBlue.opacity(0.35))
        )
    }
}
