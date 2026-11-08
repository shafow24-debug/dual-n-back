import SwiftUI

/// Pantalla de Ajustes de entrenamiento, experiencia, voz en español y gestión de datos
struct SettingsView: View {
    @ObservedObject var storage: StorageManager
    @ObservedObject var speechManager: SpeechManager = .shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showFirstDeleteAlert: Bool = false
    @State private var showSecondDeleteAlert: Bool = false
    @State private var didClearBanner: Bool = false
    
    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Encabezado
                HStack {
                    Button {
                        speechManager.deactivateGameAudioSession()
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
                    
                    Text("Ajustes")
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
                        // MARK: - 1. Sección Entrenamiento
                        sectionCard(title: "Entrenamiento", icon: "brain.head.profile") {
                            VStack(spacing: 16) {
                                Toggle(isOn: $storage.settings.isAdaptive) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Modo adaptativo")
                                            .font(Theme.font(.subheadline, weight: .bold))
                                            .foregroundColor(.white)
                                        Text("Sube a N+1 con ≥80% en ambos; baja a N-1 con <50%")
                                            .font(Theme.font(.caption2, weight: .medium))
                                            .foregroundColor(.white.opacity(0.85))
                                    }
                                }
                                .tint(Theme.accentYellow)
                                
                                Divider().background(Color.white.opacity(0.28))
                                
                                // Meta de sesiones diarias (1 a 20)
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Meta de sesiones diarias")
                                            .font(Theme.font(.subheadline, weight: .bold))
                                            .foregroundColor(.white)
                                        Text("Objetivo diario para tu racha")
                                            .font(Theme.font(.caption2, weight: .medium))
                                            .foregroundColor(.white.opacity(0.85))
                                    }
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 12) {
                                        Button {
                                            if storage.settings.dailyGoal > 1 {
                                                storage.settings.dailyGoal -= 1
                                                HapticsManager.shared.playSelectionTap(enabled: storage.settings.hapticsEnabled)
                                            }
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(Theme.accentYellow)
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Text("\(storage.settings.dailyGoal)")
                                            .font(Theme.font(.title3, weight: .heavy))
                                            .foregroundColor(.white)
                                            .frame(minWidth: 28)
                                        
                                        Button {
                                            if storage.settings.dailyGoal < 20 {
                                                storage.settings.dailyGoal += 1
                                                HapticsManager.shared.playSelectionTap(enabled: storage.settings.hapticsEnabled)
                                            }
                                        } label: {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(Theme.accentYellow)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                
                                Divider().background(Color.white.opacity(0.28))
                                
                                // Intervalo por defecto (1.0 s a 4.0 s, paso 0.1)
                                VStack(spacing: 8) {
                                    HStack {
                                        Text("Intervalo por defecto")
                                            .font(Theme.font(.subheadline, weight: .bold))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text(String(format: "%.1f s", storage.settings.defaultInterval))
                                            .font(Theme.font(.subheadline, weight: .heavy))
                                            .foregroundColor(Theme.accentYellow)
                                    }
                                    
                                    CustomSlider(
                                        value: $storage.settings.defaultInterval,
                                        range: 1.0...4.0,
                                        step: 0.1,
                                        hapticsEnabled: storage.settings.hapticsEnabled
                                    )
                                }
                                
                                // Duración por defecto (30 s a 180 s, paso 10 s)
                                VStack(spacing: 8) {
                                    HStack {
                                        Text("Duración por defecto")
                                            .font(Theme.font(.subheadline, weight: .bold))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text("\(storage.settings.defaultDuration) s")
                                            .font(Theme.font(.subheadline, weight: .heavy))
                                            .foregroundColor(Theme.accentYellow)
                                    }
                                    
                                    CustomSlider(
                                        value: Binding(
                                            get: { Double(storage.settings.defaultDuration) },
                                            set: { storage.settings.defaultDuration = Int($0.rounded()) }
                                        ),
                                        range: 30.0...180.0,
                                        step: 10.0,
                                        hapticsEnabled: storage.settings.hapticsEnabled
                                    )
                                }
                                
                                Divider().background(Color.white.opacity(0.28))
                                
                                // Nivel de señuelos (Lures / Interferencia)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Nivel de señuelos (Interferencia N±1)")
                                        .font(Theme.font(.subheadline, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    HStack(spacing: 8) {
                                        ForEach(LureLevel.allCases) { level in
                                            let isSelected = LureLevel.closest(to: storage.settings.lureRate) == level
                                            Button {
                                                storage.settings.lureRate = level.rawValue
                                                HapticsManager.shared.playSelectionTap(enabled: storage.settings.hapticsEnabled)
                                            } label: {
                                                Text(level.title)
                                                    .font(Theme.font(.caption, weight: .heavy))
                                                    .foregroundColor(isSelected ? Theme.darkBlue : .white)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 10)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                            .fill(isSelected ? Theme.accentYellow : Theme.darkBlue.opacity(0.55))
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // MARK: - 2. Sección Experiencia y Feedback
                        sectionCard(title: "Experiencia y Feedback", icon: "hand.tap.fill") {
                            VStack(spacing: 14) {
                                Toggle(isOn: $storage.settings.hapticsEnabled) {
                                    Text("Vibración háptica en aciertos/errores")
                                        .font(Theme.font(.subheadline, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .tint(Theme.accentYellow)
                                
                                Divider().background(Color.white.opacity(0.28))
                                
                                Toggle(isOn: $storage.settings.visualFeedbackEnabled) {
                                    Text("Destello visual de acierto/error en botones")
                                        .font(Theme.font(.subheadline, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .tint(Theme.accentYellow)
                                
                                Divider().background(Color.white.opacity(0.28))
                                
                                Toggle(isOn: $storage.settings.fixationCrossEnabled) {
                                    Text("Cruz central de fijación (+) en cuadrícula")
                                        .font(Theme.font(.subheadline, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .tint(Theme.accentYellow)
                            }
                        }
                        
                        // MARK: - 3. Sección Voz (Audio en Español)
                        sectionCard(title: "Voz (Audio en Español)", icon: "speaker.wave.3.fill") {
                            VStack(spacing: 16) {
                                Toggle(isOn: $storage.settings.voiceEnabled) {
                                    Text("Voz activada")
                                        .font(Theme.font(.subheadline, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .tint(Theme.accentYellow)
                                
                                Divider().background(Color.white.opacity(0.28))
                                
                                // Selector de voz en español instalada en el iPhone
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Selector de voz en español")
                                        .font(Theme.font(.subheadline, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Picker(
                                        "Voz en español",
                                        selection: Binding<String>(
                                            get: { storage.settings.selectedVoiceIdentifier ?? "" },
                                            set: { newValue in
                                                storage.settings.selectedVoiceIdentifier = newValue.isEmpty ? nil : newValue
                                            }
                                        )
                                    ) {
                                        Text("Automática (Mejor voz español disponible)")
                                            .tag("")
                                        
                                        ForEach(speechManager.availableSpanishVoices) { voice in
                                            Text(voice.displayName)
                                                .tag(voice.identifier)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(Theme.accentYellow)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Theme.darkBlue.opacity(0.6))
                                    )
                                    
                                    Text("Tip: En iOS puedes descargar voces Premium/Mejoradas en Configuración > Accesibilidad > Contenido leído > Voces > Español.")
                                        .font(Theme.font(.caption2, weight: .medium))
                                        .foregroundColor(.white.opacity(0.82))
                                }
                                
                                Divider().background(Color.white.opacity(0.28))
                                
                                // Slider de Volumen de voz (0.1 a 1.0)
                                VStack(spacing: 8) {
                                    HStack {
                                        Text("Volumen de voz")
                                            .font(Theme.font(.subheadline, weight: .bold))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text("\(Int((storage.settings.voiceVolume * 100).rounded()))%")
                                            .font(Theme.font(.subheadline, weight: .heavy))
                                            .foregroundColor(Theme.accentYellow)
                                    }
                                    
                                    CustomSlider(
                                        value: Binding(
                                            get: { Double(storage.settings.voiceVolume) },
                                            set: { storage.settings.voiceVolume = Float($0) }
                                        ),
                                        range: 0.1...1.0,
                                        step: 0.05,
                                        hapticsEnabled: storage.settings.hapticsEnabled
                                    )
                                }
                                
                                // Botón "Probar voz" ("hache, jota, ka")
                                Button {
                                    speechManager.previewVoice(settings: storage.settings)
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "play.circle.fill")
                                            .font(.system(size: 18, weight: .bold))
                                        Text("Probar voz («hache, jota, ka»)")
                                            .font(Theme.font(.subheadline, weight: .heavy))
                                    }
                                    .foregroundColor(Theme.darkBlue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        Capsule()
                                            .fill(Theme.accentYellow)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        // MARK: - 4. Sección Datos
                        sectionCard(title: "Datos", icon: "externaldrive.fill") {
                            VStack(spacing: 12) {
                                if didClearBanner {
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Theme.feedbackHit)
                                        Text("Historial y estadísticas reiniciados correctamente.")
                                            .font(Theme.font(.caption, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                
                                Button {
                                    showFirstDeleteAlert = true
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "trash.fill")
                                            .font(.system(size: 16, weight: .bold))
                                        Text("Borrar historial")
                                            .font(Theme.font(.subheadline, weight: .heavy))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(
                                        Capsule()
                                            .fill(Theme.feedbackMiss)
                                    )
                                }
                                .buttonStyle(.plain)
                                
                                Text("Elimina las sesiones guardadas y reinicia las estadísticas conservando tus preferencias de voz.")
                                    .font(Theme.font(.caption2, weight: .medium))
                                    .foregroundColor(.white.opacity(0.85))
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 6)
                    .padding(.bottom, 28)
                }
            }
        }
        .onAppear {
            speechManager.refreshAvailableVoices()
        }
        .alert("¿Borrar historial de sesiones?", isPresented: $showFirstDeleteAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Continuar", role: .destructive) {
                showSecondDeleteAlert = true
            }
        } message: {
            Text("Se eliminarán todas las partidas registradas y se reiniciarán tus estadísticas. Tus ajustes de voz se conservarán.")
        }
        .alert("Confirmación definitiva", isPresented: $showSecondDeleteAlert) {
            Button("No borrar", role: .cancel) {}
            Button("Sí, borrar todo el historial", role: .destructive) {
                storage.clearHistory()
                withAnimation {
                    didClearBanner = true
                }
            }
        } message: {
            Text("¿Estás completamente seguro? Esta acción no se puede deshacer.")
        }
    }
    
    // MARK: - Contenedor de Sección Redondeado
    
    private func sectionCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Theme.accentYellow)
                
                Text(title)
                    .font(Theme.font(.headline, weight: .heavy))
                    .foregroundColor(.white)
            }
            
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.mediumBlue)
                .softShadow()
        )
    }
}
