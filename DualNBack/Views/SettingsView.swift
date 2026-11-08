import SwiftUI

/// Pantalla de Ajustes con soporte híbrido de voces ElevenLabs AI (precaché local de latencia cero) y Voz del iPhone
struct SettingsView: View {
    @ObservedObject var storage: StorageManager
    @ObservedObject var speechManager: SpeechManager = .shared
    @Environment(\.dismiss) private var dismiss
    
    // Estado para ElevenLabs AI
    @State private var apiKeyInput: String = ""
    @State private var isAPIKeyVisible: Bool = false
    @State private var isAPIKeySavedInKeychain: Bool = false
    
    @State private var elevenLabsVoices: [ElevenLabsVoice] = []
    @State private var isLoadingVoices: Bool = false
    
    @State private var isDownloadingLetters: Bool = false
    @State private var downloadCompletedCount: Int = 0
    @State private var downloadTotalCount: Int = 8
    
    @State private var cachedLettersCount: Int = 0
    @State private var formattedCacheSize: String = "0 KB"
    @State private var elevenLabsStatusMessage: String? = nil
    @State private var elevenLabsErrorMessage: String? = nil
    
    // Alertas de borrado de historial
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
                        
                        // MARK: - 3. Sección Voz (ElevenLabs AI + Voz del iPhone)
                        voiceSectionCard
                        
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
                                
                                Text("Elimina las sesiones guardadas y reinicia las estadísticas conservando tu API Key y preferencias de voz.")
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
            loadInitialElevenLabsState()
        }
        .onChange(of: storage.settings.elevenLabsVoiceId) { _ in
            refreshCacheMetrics()
            autoDownloadSelectedVoiceIfNeeded()
        }
        .onChange(of: storage.settings.elevenLabsCustomVoiceId) { _ in
            refreshCacheMetrics()
        }
        .onChange(of: storage.settings.elevenLabsModelId) { _ in
            refreshCacheMetrics()
            autoDownloadSelectedVoiceIfNeeded()
        }
        .alert("¿Borrar historial de sesiones?", isPresented: $showFirstDeleteAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Continuar", role: .destructive) {
                showSecondDeleteAlert = true
            }
        } message: {
            Text("Se eliminarán todas las partidas registradas y se reiniciarán tus estadísticas. Tus ajustes de voz y API Key se conservarán.")
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
    
    // MARK: - Subvista de la Sección de Voz
    
    private var voiceSectionCard: some View {
        sectionCard(title: "Voz (Audio en Español)", icon: "speaker.wave.3.fill") {
            VStack(spacing: 16) {
                Toggle(isOn: $storage.settings.voiceEnabled) {
                    Text("Voz activada")
                        .font(Theme.font(.subheadline, weight: .bold))
                        .foregroundColor(.white)
                }
                .tint(Theme.accentYellow)
                
                Divider().background(Color.white.opacity(0.28))
                
                // 1. Selector Cápsula de Motor de Voz: ElevenLabs AI vs Voz del iPhone
                VStack(alignment: .leading, spacing: 8) {
                    Text("Motor de Voz")
                        .font(Theme.font(.subheadline, weight: .bold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        ForEach(VoiceEngineType.allCases) { engine in
                            let isSelected = storage.settings.voiceEngine == engine
                            Button {
                                storage.settings.voiceEngine = engine
                                HapticsManager.shared.playSelectionTap(enabled: storage.settings.hapticsEnabled)
                                refreshCacheMetrics()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: engine == .elevenLabs ? "waveform.badge.sparkles" : "iphone")
                                        .font(.system(size: 13, weight: .bold))
                                    Text(engine.displayTitle)
                                        .font(Theme.font(.caption, weight: .heavy))
                                }
                                .foregroundColor(isSelected ? Theme.darkBlue : .white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? Theme.accentYellow : Theme.darkBlue.opacity(0.55))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Divider().background(Color.white.opacity(0.28))
                
                if storage.settings.voiceEngine == .elevenLabs {
                    elevenLabsControlsView
                } else {
                    systemTTSControlsView
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
                
                // Botón "Probar voz" (reproduce "hache", "jota", "ka")
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
    }
    
    // MARK: - Controles de ElevenLabs AI
    
    private var elevenLabsControlsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 1. Campo API Key con botón mostrar/ocultar (👁) y estado Keychain
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("ElevenLabs API Key")
                        .font(Theme.font(.subheadline, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if isAPIKeySavedInKeychain {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("Guardada en Keychain")
                                .font(Theme.font(.caption2, weight: .bold))
                        }
                        .foregroundColor(Theme.feedbackHit)
                    } else {
                        Text("No configurada")
                            .font(Theme.font(.caption2, weight: .bold))
                            .foregroundColor(Theme.accentYellow)
                    }
                }
                
                HStack(spacing: 8) {
                    Group {
                        if isAPIKeyVisible {
                            TextField("xi-api-key...", text: $apiKeyInput)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                        } else {
                            SecureField("Pega aquí tu xi-api-key...", text: $apiKeyInput)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                        }
                    }
                    .font(Theme.font(.footnote, weight: .semibold))
                    .foregroundColor(.white)
                    .onChange(of: apiKeyInput) { newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        KeychainHelper.saveAPIKey(trimmed)
                        isAPIKeySavedInKeychain = !trimmed.isEmpty
                    }
                    
                    Button {
                        isAPIKeyVisible.toggle()
                    } label: {
                        Image(systemName: isAPIKeyVisible ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isAPIKeyVisible ? "Ocultar API Key" : "Mostrar API Key")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.darkBlue.opacity(0.65))
                )
            }
            
            // 2. Botón "Cargar mis voces" (GET /v1/voices)
            Button {
                Task {
                    await fetchElevenLabsVoices()
                }
            } label: {
                HStack(spacing: 8) {
                    if isLoadingVoices {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.85)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            .font(.system(size: 17, weight: .bold))
                    }
                    Text(isLoadingVoices ? "Cargando voces de tu cuenta..." : "Cargar mis voces")
                        .font(Theme.font(.subheadline, weight: .heavy))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    Capsule()
                        .fill(Theme.primaryBlue)
                        .softShadow()
                )
            }
            .buttonStyle(.plain)
            .disabled(isLoadingVoices)
            
            // 3. Selector de Voz (Clonadas, Profesionales, Premade) + Campo Voice ID manual
            VStack(alignment: .leading, spacing: 8) {
                Text("Selector de Voz")
                    .font(Theme.font(.subheadline, weight: .bold))
                    .foregroundColor(.white)
                
                if elevenLabsVoices.isEmpty {
                    Text("Pulsa «Cargar mis voces» arriba o ingresa un Voice ID manual abajo.")
                        .font(Theme.font(.caption, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Theme.darkBlue.opacity(0.5))
                        )
                } else {
                    Picker(
                        "Voz de ElevenLabs",
                        selection: Binding<String>(
                            get: { storage.settings.elevenLabsVoiceId },
                            set: { newVoiceId in
                                storage.settings.elevenLabsVoiceId = newVoiceId
                                if let found = elevenLabsVoices.first(where: { $0.voice_id == newVoiceId }) {
                                    storage.settings.elevenLabsVoiceName = found.name
                                }
                            }
                        )
                    ) {
                        if storage.settings.elevenLabsVoiceId.isEmpty {
                            Text("Selecciona una voz...")
                                .tag("")
                        }
                        ForEach(elevenLabsVoices) { voice in
                            Text(voice.displayTitle)
                                .tag(voice.voice_id)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.accentYellow)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.darkBlue.opacity(0.65))
                    )
                }
                
                // Campo opcional para Voice ID manual (ej. de Voice Library)
                VStack(alignment: .leading, spacing: 4) {
                    Text("O ingresar Voice ID manual (opcional):")
                        .font(Theme.font(.caption, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                    
                    HStack(spacing: 8) {
                        TextField("Ej. JBFqnCBsd6RMkjVDRZzb", text: $storage.settings.elevenLabsCustomVoiceId)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .font(Theme.font(.footnote, weight: .semibold))
                            .foregroundColor(.white)
                        
                        if !storage.settings.elevenLabsCustomVoiceId.isEmpty {
                            Button {
                                storage.settings.elevenLabsCustomVoiceId = ""
                                refreshCacheMetrics()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.75))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.darkBlue.opacity(0.55))
                    )
                }
            }
            
            // 4. Selector de Modelo: Multilingual v2 vs Flash v2.5
            VStack(alignment: .leading, spacing: 8) {
                Text("Modelo de Síntesis")
                    .font(Theme.font(.subheadline, weight: .bold))
                    .foregroundColor(.white)
                
                VStack(spacing: 8) {
                    ForEach(ElevenLabsModel.allCases) { model in
                        let isSelected = storage.settings.elevenLabsModelId == model.rawValue
                        Button {
                            storage.settings.elevenLabsModelId = model.rawValue
                            HapticsManager.shared.playSelectionTap(enabled: storage.settings.hapticsEnabled)
                        } label: {
                            HStack {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(isSelected ? Theme.darkBlue : .white.opacity(0.8))
                                
                                Text(model.displayTitle)
                                    .font(Theme.font(.caption, weight: .heavy))
                                    .foregroundColor(isSelected ? Theme.darkBlue : .white)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 14)
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
            
            // 5. Estado del Paquete de Audio (las 8 letras) + Botón Descargar / Regenerar
            VStack(alignment: .leading, spacing: 10) {
                let isReadyOffline = cachedLettersCount == 8
                
                HStack(alignment: .top, spacing: 8) {
                    Text(isReadyOffline ? "✅" : "⚠️")
                        .font(.system(size: 16))
                    
                    Text(
                        isReadyOffline
                            ? "8/8 letras descargadas en el iPhone (Listo para jugar sin internet)"
                            : "Falta descargar las 8 letras para esta voz (\(cachedLettersCount)/8)"
                    )
                    .font(Theme.font(.caption, weight: .bold))
                    .foregroundColor(isReadyOffline ? Theme.accentYellow : .white)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.darkBlue.opacity(0.65))
                )
                
                // Barra de progreso mientras descarga las 8 letras
                if isDownloadingLetters {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            ProgressView()
                                .tint(Theme.accentYellow)
                                .scaleEffect(0.8)
                            Text("Descargando sonidos: \(downloadCompletedCount) / \(downloadTotalCount)")
                                .font(Theme.font(.caption, weight: .heavy))
                                .foregroundColor(Theme.accentYellow)
                        }
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 7)
                                
                                Capsule()
                                    .fill(Theme.accentYellow)
                                    .frame(
                                        width: max(0, geo.size.width * CGFloat(downloadCompletedCount) / CGFloat(max(1, downloadTotalCount))),
                                        height: 7
                                    )
                            }
                        }
                        .frame(height: 7)
                    }
                    .padding(.vertical, 4)
                }
                
                if let errorMsg = elevenLabsErrorMessage {
                    Text(errorMsg)
                        .font(Theme.font(.caption2, weight: .bold))
                        .foregroundColor(Theme.feedbackMiss)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.92))
                        )
                } else if let statusMsg = elevenLabsStatusMessage {
                    Text(statusMsg)
                        .font(Theme.font(.caption2, weight: .bold))
                        .foregroundColor(Theme.accentYellow)
                }
                
                Button {
                    Task {
                        await downloadEightLettersPackage()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text(isReadyOffline ? "Regenerar las 8 letras" : "Descargar las 8 letras")
                            .font(Theme.font(.subheadline, weight: .heavy))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Theme.primaryBlue)
                            .softShadow()
                    )
                }
                .buttonStyle(.plain)
                .disabled(isDownloadingLetters)
                
                // Botón secundario "Limpiar caché de voces descargadas"
                Button {
                    speechManager.invalidatePreloadedCache()
                    ElevenLabsAudioCache.shared.clearAllCache()
                    refreshCacheMetrics()
                    elevenLabsStatusMessage = "Caché de voces limpiada correctamente."
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.circle")
                            .font(.system(size: 15, weight: .bold))
                        Text("Limpiar caché de voces descargadas (\(formattedCacheSize))")
                            .font(Theme.font(.caption, weight: .bold))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(Theme.darkBlue.opacity(0.55))
                    )
                }
                .buttonStyle(.plain)
                .disabled(isDownloadingLetters)
            }
        }
    }
    
    // MARK: - Controles de Voz del iPhone (Sistema)
    
    private var systemTTSControlsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selector de voz en español del iPhone")
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
    }
    
    // MARK: - Acciones Asíncronas de ElevenLabs
    
    private func loadInitialElevenLabsState() {
        let savedKey = KeychainHelper.loadAPIKey()
        apiKeyInput = savedKey
        isAPIKeySavedInKeychain = !savedKey.isEmpty
        
        let cachedList = ElevenLabsService.shared.loadCachedVoicesList()
        if !cachedList.isEmpty {
            elevenLabsVoices = cachedList
        }
        refreshCacheMetrics()
    }
    
    private func refreshCacheMetrics() {
        let voiceId = storage.settings.effectiveElevenLabsVoiceId
        let modelId = storage.settings.elevenLabsModelId
        cachedLettersCount = ElevenLabsAudioCache.shared.cachedLettersCount(voiceId: voiceId, modelId: modelId)
        formattedCacheSize = ElevenLabsAudioCache.shared.formattedCacheSize()
        
        if cachedLettersCount == 8 {
            speechManager.prepareElevenLabsPlayersIfAvailable(settings: storage.settings)
        }
    }
    
    private func autoDownloadSelectedVoiceIfNeeded() {
        guard storage.settings.voiceEngine == .elevenLabs,
              !isDownloadingLetters else { return }
        let voiceId = storage.settings.effectiveElevenLabsVoiceId
        let modelId = storage.settings.elevenLabsModelId
        let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !voiceId.isEmpty,
              !key.isEmpty,
              !ElevenLabsAudioCache.shared.isVoiceFullyCached(voiceId: voiceId, modelId: modelId) else {
            return
        }
        Task {
            await downloadEightLettersPackage()
        }
    }
    
    @MainActor
    private func fetchElevenLabsVoices() async {
        elevenLabsErrorMessage = nil
        elevenLabsStatusMessage = nil
        isLoadingVoices = true
        defer { isLoadingVoices = false }
        
        let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        KeychainHelper.saveAPIKey(key)
        isAPIKeySavedInKeychain = !key.isEmpty
        
        do {
            let voices = try await ElevenLabsService.shared.fetchVoices(apiKey: key)
            elevenLabsVoices = voices
            if storage.settings.elevenLabsVoiceId.isEmpty, let first = voices.first {
                storage.settings.elevenLabsVoiceId = first.voice_id
                storage.settings.elevenLabsVoiceName = first.name
            }
            refreshCacheMetrics()
            elevenLabsStatusMessage = "Se cargaron \(voices.count) voces de tu cuenta."
        } catch {
            elevenLabsErrorMessage = error.localizedDescription
        }
    }
    
    @MainActor
    private func downloadEightLettersPackage() async {
        guard !isDownloadingLetters else { return }
        elevenLabsErrorMessage = nil
        elevenLabsStatusMessage = nil
        
        let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        KeychainHelper.saveAPIKey(key)
        isAPIKeySavedInKeychain = !key.isEmpty
        
        let voiceId = storage.settings.effectiveElevenLabsVoiceId
        let modelId = storage.settings.elevenLabsModelId
        
        isDownloadingLetters = true
        downloadCompletedCount = 0
        downloadTotalCount = 8
        
        do {
            try await ElevenLabsService.shared.downloadAllEightLetters(
                apiKey: key,
                voiceId: voiceId,
                modelId: modelId
            ) { completed, total in
                Task { @MainActor in
                    self.downloadCompletedCount = completed
                    self.downloadTotalCount = total
                }
            }
            isDownloadingLetters = false
            refreshCacheMetrics()
            speechManager.prepareElevenLabsPlayersIfAvailable(settings: storage.settings, forceReload: true)
            HapticsManager.shared.playHit(enabled: storage.settings.hapticsEnabled)
            elevenLabsStatusMessage = "¡8/8 letras descargadas y precargadas en RAM!"
        } catch {
            isDownloadingLetters = false
            refreshCacheMetrics()
            HapticsManager.shared.playError(enabled: storage.settings.hapticsEnabled)
            elevenLabsErrorMessage = error.localizedDescription
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
