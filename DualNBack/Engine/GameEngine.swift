import SwiftUI
import Combine
import UIKit

/// Fases del ciclo de vida de una partida
enum GamePhase: Equatable {
    case countdown(Int)
    case playing
    case paused
    case finished(SessionResult)
}

/// Estado de destello visual de acierto/error en los botones SOUND y POSITION
enum ButtonFeedbackState: Equatable {
    case none
    case hit
    case miss
}

/// Modalidades del entrenamiento Dual N-Back
enum StimulusModality {
    case sound
    case position
}

/// Motor principal de juego con temporización monotónica libre de deriva (Drift-Free Timer)
@MainActor
final class GameEngine: ObservableObject {
    // MARK: - Estado Publicado para la Interfaz
    @Published private(set) var phase: GamePhase = .countdown(3)
    @Published private(set) var steps: [StimulusStep] = []
    @Published private(set) var currentTurnIndex: Int = 0
    @Published private(set) var activeGridPosition: Int? = nil
    @Published private(set) var progress: Double = 0.0
    
    @Published private(set) var soundPressedThisTurn: Bool = false
    @Published private(set) var positionPressedThisTurn: Bool = false
    
    @Published private(set) var soundFeedback: ButtonFeedbackState = .none
    @Published private(set) var positionFeedback: ButtonFeedbackState = .none
    
    // Parámetros activos de la sesión actual
    @Published private(set) var sessionNLevel: Int
    @Published private(set) var sessionInterval: Double
    @Published private(set) var sessionDuration: Int
    
    // Parámetros editables dentro del modal de Pausa
    @Published var pauseNLevel: Int
    @Published var pauseInterval: Double
    @Published var pauseDuration: Int
    
    // Contadores acumulados de la sesión en curso
    @Published private(set) var soundHits: Int = 0
    @Published private(set) var soundMisses: Int = 0
    @Published private(set) var soundFalseAlarms: Int = 0
    @Published private(set) var positionHits: Int = 0
    @Published private(set) var positionMisses: Int = 0
    @Published private(set) var positionFalseAlarms: Int = 0
    
    // MARK: - Dependencias
    private let storage: StorageManager
    private let speech: SpeechManager
    private let haptics: HapticsManager
    
    // Tareas asíncronas cancelables
    private var gameLoopTask: Task<Void, Never>?
    private var soundFeedbackTask: Task<Void, Never>?
    private var positionFeedbackTask: Task<Void, Never>?
    private var resignActiveCancellable: AnyCancellable?
    
    init(
        storage: StorageManager = .shared,
        speech: SpeechManager = .shared,
        haptics: HapticsManager = .shared
    ) {
        self.storage = storage
        self.speech = speech
        self.haptics = haptics
        
        let n = storage.settings.currentN
        let interval = storage.settings.defaultInterval
        let duration = storage.settings.defaultDuration
        
        self.sessionNLevel = n
        self.sessionInterval = interval
        self.sessionDuration = duration
        
        self.pauseNLevel = n
        self.pauseInterval = interval
        self.pauseDuration = duration
        
        observeSystemInterruptions()
    }
    
    deinit {
        gameLoopTask?.cancel()
        soundFeedbackTask?.cancel()
        positionFeedbackTask?.cancel()
    }
    
    // MARK: - Propiedades Computadas de Estado
    
    /// Indica si estamos en los primeros `N` turnos de carga de memoria
    var isMemoryLoadingPhase: Bool {
        currentTurnIndex < sessionNLevel
    }
    
    /// Indica si el usuario modificó `N`, `Intervalo` o `Duración` mientras estaba en Pausa
    var hasPauseParameterChanges: Bool {
        pauseNLevel != sessionNLevel ||
        abs(pauseInterval - sessionInterval) > 0.04 ||
        pauseDuration != sessionDuration
    }
    
    /// Total de turnos evaluables en la sesión actual
    var evaluatedTurnsCount: Int {
        max(1, steps.count - sessionNLevel)
    }
    
    // MARK: - Control de Sesión
    
    /// Inicia una nueva sesión desde el Turno 1 con cuenta regresiva previa ("Prepárate... 3, 2, 1")
    func startNewSession(
        nLevel: Int? = nil,
        interval: Double? = nil,
        duration: Int? = nil
    ) {
        cancelAllTasks()
        
        let chosenN = min(9, max(1, nLevel ?? storage.settings.currentN))
        let chosenInterval = min(4.0, max(1.0, ((interval ?? storage.settings.defaultInterval) * 10).rounded() / 10))
        let chosenDuration = min(180, max(30, ((duration ?? storage.settings.defaultDuration) / 10) * 10))
        
        sessionNLevel = chosenN
        sessionInterval = chosenInterval
        sessionDuration = chosenDuration
        
        pauseNLevel = chosenN
        pauseInterval = chosenInterval
        pauseDuration = chosenDuration
        
        // Sincronizar con ajustes actuales
        if storage.settings.currentN != chosenN {
            storage.settings.currentN = chosenN
        }
        if abs(storage.settings.defaultInterval - chosenInterval) > 0.04 {
            storage.settings.defaultInterval = chosenInterval
        }
        if storage.settings.defaultDuration != chosenDuration {
            storage.settings.defaultDuration = chosenDuration
        }
        
        steps = SequenceGenerator.generate(
            nLevel: chosenN,
            duration: chosenDuration,
            interval: chosenInterval,
            lureRate: storage.settings.lureRate
        )
        
        currentTurnIndex = 0
        activeGridPosition = nil
        progress = 0.0
        
        soundPressedThisTurn = false
        positionPressedThisTurn = false
        soundFeedback = .none
        positionFeedback = .none
        
        soundHits = 0
        soundMisses = 0
        soundFalseAlarms = 0
        positionHits = 0
        positionMisses = 0
        positionFalseAlarms = 0
        
        setIdleTimerDisabled(true)
        haptics.prepare()
        speech.activateGameAudioSession()
        
        runGameLoop(startingAtTurn: 0, includeCountdown: true)
    }
    
    /// Pausa inmediatamente el temporizador y el sintetizador de voz
    func pauseGame() {
        guard phase == .playing || isInCountdown else { return }
        gameLoopTask?.cancel()
        gameLoopTask = nil
        
        speech.stopSpeaking()
        withAnimation(.easeInOut(duration: 0.12)) {
            activeGridPosition = nil
        }
        
        pauseNLevel = sessionNLevel
        pauseInterval = sessionInterval
        pauseDuration = sessionDuration
        
        setIdleTimerDisabled(false)
        phase = .paused
    }
    
    /// Reanuda la sesión en el mismo turno o la reinicia desde el turno 1 si se modificaron parámetros en Pausa
    func resumeOrRestartFromPause() {
        guard phase == .paused else { return }
        
        if hasPauseParameterChanges {
            startNewSession(
                nLevel: pauseNLevel,
                interval: pauseInterval,
                duration: pauseDuration
            )
        } else {
            setIdleTimerDisabled(true)
            haptics.prepare()
            speech.activateGameAudioSession()
            runGameLoop(startingAtTurn: currentTurnIndex, includeCountdown: false)
        }
    }
    
    /// Detiene por completo la sesión y limpia recursos al salir al inicio
    func stopAndExitSession() {
        cancelAllTasks()
        withAnimation(.easeInOut(duration: 0.12)) {
            activeGridPosition = nil
        }
        setIdleTimerDisabled(false)
        speech.deactivateGameAudioSession()
    }
    
    // MARK: - Registro de Respuestas del Jugador (`SOUND` y `POSITION`)
    
    func registerSoundPress() {
        guard phase == .playing,
              currentTurnIndex < steps.count,
              !isMemoryLoadingPhase,
              !soundPressedThisTurn else {
            return
        }
        
        soundPressedThisTurn = true
        let step = steps[currentTurnIndex]
        
        if step.isSoundTarget {
            triggerVisualFeedback(for: .sound, state: .hit)
            haptics.playHit(enabled: storage.settings.hapticsEnabled)
        } else {
            triggerVisualFeedback(for: .sound, state: .miss)
            haptics.playError(enabled: storage.settings.hapticsEnabled)
        }
    }
    
    func registerPositionPress() {
        guard phase == .playing,
              currentTurnIndex < steps.count,
              !isMemoryLoadingPhase,
              !positionPressedThisTurn else {
            return
        }
        
        positionPressedThisTurn = true
        let step = steps[currentTurnIndex]
        
        if step.isPositionTarget {
            triggerVisualFeedback(for: .position, state: .hit)
            haptics.playHit(enabled: storage.settings.hapticsEnabled)
        } else {
            triggerVisualFeedback(for: .position, state: .miss)
            haptics.playError(enabled: storage.settings.hapticsEnabled)
        }
    }
    
    // MARK: - Bucle Principal sin Deriva (Drift-Free Monotonic Loop)
    
    private var isInCountdown: Bool {
        if case .countdown = phase { return true }
        return false
    }
    
    private func runGameLoop(startingAtTurn startTurn: Int, includeCountdown: Bool) {
        gameLoopTask?.cancel()
        
        gameLoopTask = Task { [weak self] in
            guard let self else { return }
            
            if includeCountdown {
                for count in stride(from: 3, through: 1, by: -1) {
                    if Task.isCancelled { return }
                    self.phase = .countdown(count)
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 s por paso (1.5 s total)
                }
            }
            
            if Task.isCancelled { return }
            self.phase = .playing
            
            let totalTurns = self.steps.count
            guard totalTurns > 0 else { return }
            
            for turnIdx in startTurn ..< totalTurns {
                if Task.isCancelled { return }
                
                self.currentTurnIndex = turnIdx
                self.soundPressedThisTurn = false
                self.positionPressedThisTurn = false
                
                let step = self.steps[turnIdx]
                let interval = self.sessionInterval
                let flashDuration = min(0.5, interval * 0.5)
                
                // 1. Encender cuadro en la cuadrícula 3x3 y pronunciar letra inmediatamente
                withAnimation(.easeInOut(duration: 0.12)) {
                    self.activeGridPosition = step.position
                }
                self.speech.speakLetter(
                    step.letter,
                    interval: interval,
                    settings: self.storage.settings
                )
                
                let turnStartUptime = ProcessInfo.processInfo.systemUptime
                let flashOffUptime = turnStartUptime + flashDuration
                let turnEndUptime = turnStartUptime + interval
                var didTurnOffGrid = false
                
                // 2. Ciclo de alta precisión (~60 Hz) basado en tiempo monotónico del sistema
                while !Task.isCancelled {
                    let now = ProcessInfo.processInfo.systemUptime
                    
                    if !didTurnOffGrid && now >= flashOffUptime {
                        didTurnOffGrid = true
                        withAnimation(.easeInOut(duration: 0.12)) {
                            self.activeGridPosition = nil
                        }
                    }
                    
                    let elapsedInTurn = min(interval, max(0.0, now - turnStartUptime))
                    let turnFraction = elapsedInTurn / interval
                    self.progress = min(1.0, (Double(turnIdx) + turnFraction) / Double(totalTurns))
                    
                    if now >= turnEndUptime {
                        break
                    }
                    
                    let remainingSeconds = turnEndUptime - now
                    let sleepNanos = UInt64(min(0.016, max(0.002, remainingSeconds)) * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: sleepNanos)
                }
                
                if Task.isCancelled { return }
                
                // Asegurar que el cuadro quede apagado al cerrar el turno
                if self.activeGridPosition != nil {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        self.activeGridPosition = nil
                    }
                }
                
                // 3. Evaluar respuestas del turno si es un turno evaluable (`turnIdx >= sessionNLevel`)
                let hadMissOnLastTurn = self.evaluateTurnResponses(step: step)
                
                // Si fue el último turno y hubo una omisión, damos 0.25 s para que el usuario perciba el destello
                if turnIdx == totalTurns - 1 && hadMissOnLastTurn {
                    try? await Task.sleep(nanoseconds: 250_000_000)
                }
            }
            
            if Task.isCancelled { return }
            self.finishSession()
        }
    }
    
    /// Evalúa aciertos, omisiones y falsas alarmas al cierre del turno `step.index`
    @discardableResult
    private func evaluateTurnResponses(step: StimulusStep) -> Bool {
        guard step.index >= sessionNLevel else { return false }
        var triggeredMissFeedback = false
        
        // Evaluación de SOUND
        if step.isSoundTarget && soundPressedThisTurn {
            soundHits += 1
        } else if step.isSoundTarget && !soundPressedThisTurn {
            soundMisses += 1
            triggerVisualFeedback(for: .sound, state: .miss)
            triggeredMissFeedback = true
        } else if !step.isSoundTarget && soundPressedThisTurn {
            soundFalseAlarms += 1
        }
        
        // Evaluación de POSITION
        if step.isPositionTarget && positionPressedThisTurn {
            positionHits += 1
        } else if step.isPositionTarget && !positionPressedThisTurn {
            positionMisses += 1
            triggerVisualFeedback(for: .position, state: .miss)
            triggeredMissFeedback = true
        } else if !step.isPositionTarget && positionPressedThisTurn {
            positionFalseAlarms += 1
        }
        
        if triggeredMissFeedback {
            haptics.playError(enabled: storage.settings.hapticsEnabled)
        }
        
        return triggeredMissFeedback
    }
    
    /// Dispara el destello de 0.25 s en verde (`#4CD964`) o rojo (`#FF5A5F`) en el botón correspondiente
    private func triggerVisualFeedback(for modality: StimulusModality, state: ButtonFeedbackState) {
        guard storage.settings.visualFeedbackEnabled else { return }
        
        switch modality {
        case .sound:
            soundFeedbackTask?.cancel()
            withAnimation(.easeOut(duration: 0.08)) {
                soundFeedback = state
            }
            soundFeedbackTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard let self, !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.15)) {
                    self.soundFeedback = .none
                }
            }
            
        case .position:
            positionFeedbackTask?.cancel()
            withAnimation(.easeOut(duration: 0.08)) {
                positionFeedback = state
            }
            positionFeedbackTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard let self, !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.15)) {
                    self.positionFeedback = .none
                }
            }
        }
    }
    
    /// Construye el `SessionResult`, actualiza el nivel N adaptativo y persiste la sesión
    private func finishSession() {
        progress = 1.0
        setIdleTimerDisabled(false)
        speech.deactivateGameAudioSession()
        
        let evaluatedCount = max(10, steps.count - sessionNLevel)
        let result = SessionResult(
            nLevel: sessionNLevel,
            interval: sessionInterval,
            duration: sessionDuration,
            evaluatedTurns: evaluatedCount,
            soundHits: soundHits,
            soundMisses: soundMisses,
            soundFalseAlarms: soundFalseAlarms,
            positionHits: positionHits,
            positionMisses: positionMisses,
            positionFalseAlarms: positionFalseAlarms,
            isAdaptive: storage.settings.isAdaptive
        )
        
        storage.recordSession(result)
        phase = .finished(result)
    }
    
    // MARK: - Utilidades de Sistema
    
    private func observeSystemInterruptions() {
        resignActiveCancellable = NotificationCenter.default
            .publisher(for: UIApplication.willResignActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if self.phase == .playing || self.isInCountdown {
                    self.pauseGame()
                }
            }
    }
    
    private func setIdleTimerDisabled(_ disabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = disabled
    }
    
    private func cancelAllTasks() {
        gameLoopTask?.cancel()
        gameLoopTask = nil
        soundFeedbackTask?.cancel()
        soundFeedbackTask = nil
        positionFeedbackTask?.cancel()
        positionFeedbackTask = nil
    }
}
