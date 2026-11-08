import SwiftUI

/// Pantalla de resultados al concluir una sesión con desglose de SOUND, POSITION y progresión de nivel N
struct ResultsView: View {
    let result: SessionResult
    var onPlayAgain: () -> Void
    var onGoHome: () -> Void
    
    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            VStack(spacing: 18) {
                Spacer(minLength: 8)
                
                // Encabezado
                VStack(spacing: 6) {
                    Text("Resultados de la sesión")
                        .font(Theme.font(size: 30, weight: .heavy))
                        .foregroundColor(.white)
                        .shadow(color: Theme.titleShadow, radius: 3, x: 0, y: 2)
                    
                    Text(String(format: "N = %d  •  %d s  •  %.1f s/turno", result.nLevel, result.duration, result.interval))
                        .font(Theme.font(.subheadline, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                // Porcentaje global combinado en el centro
                VStack(spacing: 2) {
                    Text("\(result.combinedAccuracyInt)%")
                        .font(Theme.font(size: 46, weight: .heavy))
                        .foregroundColor(Theme.accentYellow)
                        .shadow(color: Theme.subtleShadow, radius: 4, x: 0, y: 2)
                    
                    Text("Precisión Global")
                        .font(Theme.font(.caption, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.vertical, 4)
                
                // Dos tarjetas gemelas para SOUND y POSITION
                HStack(spacing: 14) {
                    modalityCard(
                        icon: "music.note",
                        title: "SOUND",
                        percentage: result.soundAccuracyInt,
                        hits: result.soundHits,
                        misses: result.soundMisses,
                        falseAlarms: result.soundFalseAlarms
                    )
                    
                    modalityCard(
                        icon: "square.fill",
                        title: "POSITION",
                        percentage: result.positionAccuracyInt,
                        hits: result.positionHits,
                        misses: result.positionMisses,
                        falseAlarms: result.positionFalseAlarms
                    )
                }
                .padding(.horizontal, 18)
                
                // Banner de progresión de Nivel N
                progressionBanner
                    .padding(.horizontal, 18)
                
                Spacer(minLength: 10)
                
                // Botones de acción inferiores: "Otra vez" e "Inicio"
                VStack(spacing: 12) {
                    Button(action: onPlayAgain) {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 20, weight: .bold))
                            Text("Otra vez")
                                .font(Theme.font(.title3, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            Capsule()
                                .fill(Theme.primaryBlue)
                                .softShadow()
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onGoHome) {
                        HStack(spacing: 8) {
                            Image(systemName: "house.fill")
                                .font(.system(size: 18, weight: .bold))
                            Text("Inicio")
                                .font(Theme.font(.title3, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            Capsule()
                                .fill(Theme.mediumBlue)
                                .softShadow()
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 22)
            }
        }
    }
    
    // MARK: - Subvistas
    
    private func modalityCard(
        icon: String,
        title: String,
        percentage: Int,
        hits: Int,
        misses: Int,
        falseAlarms: Int
    ) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                Text(title)
                    .font(Theme.font(.headline, weight: .heavy))
            }
            .foregroundColor(.white)
            
            Text("\(percentage)%")
                .font(Theme.font(size: 36, weight: .heavy))
                .foregroundColor(percentage >= 80 ? Theme.accentYellow : .white)
            
            Divider()
                .background(Color.white.opacity(0.35))
            
            VStack(spacing: 8) {
                statRow(label: "Aciertos", value: hits, valueColor: Theme.feedbackHit)
                statRow(label: "Omisiones", value: misses, valueColor: misses > 0 ? Theme.feedbackMiss : .white)
                statRow(label: "Falsas alarmas", value: falseAlarms, valueColor: falseAlarms > 0 ? Theme.feedbackMiss : .white)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.mediumBlue)
                .softShadow()
        )
    }
    
    private func statRow(label: String, value: Int, valueColor: Color) -> some View {
        HStack {
            Text(label)
                .font(Theme.font(.caption, weight: .semibold))
                .foregroundColor(.white.opacity(0.92))
            Spacer()
            Text("\(value)")
                .font(Theme.font(.subheadline, weight: .heavy))
                .foregroundColor(valueColor)
        }
    }
    
    private var progressionBanner: some View {
        let isLevelUp = result.progression == .increased
        return HStack(spacing: 12) {
            Image(systemName: bannerIconName)
                .font(.system(size: 24, weight: .heavy))
                .foregroundColor(isLevelUp ? Theme.darkBlue : Theme.accentYellow)
            
            Text(result.progressionBannerText)
                .font(Theme.font(.headline, weight: .heavy))
                .foregroundColor(isLevelUp ? Theme.darkBlue : .white)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isLevelUp ? Theme.accentYellow : Theme.darkBlue)
                .softShadow()
        )
    }
    
    private var bannerIconName: String {
        switch result.progression {
        case .increased:
            return "arrow.up.circle.fill"
        case .maintained:
            return "equal.circle.fill"
        case .decreased:
            return "arrow.down.circle.fill"
        case .manual:
            return "slider.horizontal.3"
        }
    }
}
