import Foundation

/// Generador determinista y controlado de secuencias Dual N-Back con soporte de señuelos (Lures)
struct SequenceGenerator {
    static let allPositions: [Int] = Array(0...8)
    static let allLetters: [String] = StimulusStep.allowedLetters
    
    /// Calcula el número de turnos evaluables: `max(10, Int((duracion / intervalo).rounded()))`
    static func calculateEvaluatedTurns(duration: Int, interval: Double) -> Int {
        guard interval > 0 else { return 10 }
        return max(10, Int((Double(duration) / interval).rounded()))
    }
    
    /// Calcula el total de turnos de la sesión: `turnosEvaluables + N`
    static func calculateTotalTurns(duration: Int, interval: Double, nLevel: Int) -> Int {
        let clampedN = min(9, max(1, nLevel))
        return calculateEvaluatedTurns(duration: duration, interval: interval) + clampedN
    }
    
    /// Calcula el total de objetivos (targets) por modalidad (~28% de los turnos evaluables, mínimo 3)
    static func calculateTargetsPerModality(evaluatedTurns: Int) -> Int {
        max(3, Int((Double(evaluatedTurns) * 0.28).rounded()))
    }
    
    /// Genera una secuencia completa de estímulos siguiendo el protocolo de Jaeggi et al. (2008)
    static func generate(
        nLevel: Int,
        duration: Int,
        interval: Double,
        lureRate: Double = 0.20,
        using rng: inout some RandomNumberGenerator
    ) -> [StimulusStep] {
        let n = min(9, max(1, nLevel))
        let evaluatedTurns = calculateEvaluatedTurns(duration: duration, interval: interval)
        let totalTurns = evaluatedTurns + n
        
        let targetsPerModality = min(evaluatedTurns, calculateTargetsPerModality(evaluatedTurns: evaluatedTurns))
        let dualCount = min(targetsPerModality, max(1, Int((Double(targetsPerModality) * 0.25).rounded())))
        let singleCount = max(0, targetsPerModality - dualCount)
        
        // Selección de índices dentro de `n ..< totalTurns` para objetivos dobles, solo posición y solo sonido
        var evaluableIndices = Array(n ..< totalTurns)
        evaluableIndices.shuffle(using: &rng)
        
        var positionTargetIndices = Set<Int>()
        var soundTargetIndices = Set<Int>()
        
        var cursor = 0
        // 1. Objetivos dobles simultáneos (posición + sonido en el mismo turno)
        for _ in 0 ..< dualCount where cursor < evaluableIndices.count {
            let idx = evaluableIndices[cursor]
            positionTargetIndices.insert(idx)
            soundTargetIndices.insert(idx)
            cursor += 1
        }
        
        // 2. Objetivos exclusivos de posición
        for _ in 0 ..< singleCount where cursor < evaluableIndices.count {
            let idx = evaluableIndices[cursor]
            positionTargetIndices.insert(idx)
            cursor += 1
        }
        
        // 3. Objetivos exclusivos de sonido
        var soundAdded = 0
        while soundAdded < singleCount && cursor < evaluableIndices.count {
            let idx = evaluableIndices[cursor]
            soundTargetIndices.insert(idx)
            soundAdded += 1
            cursor += 1
        }
        // Si por algún motivo evaluableIndices fuera muy pequeño, completamos desde los disponibles no-sonido
        if soundAdded < singleCount {
            let remainingForSound = evaluableIndices.filter { !soundTargetIndices.contains($0) }
            for idx in remainingForSound.prefix(singleCount - soundAdded) {
                soundTargetIndices.insert(idx)
            }
        }
        
        var positions: [Int] = []
        positions.reserveCapacity(totalTurns)
        
        var letters: [String] = []
        letters.reserveCapacity(totalTurns)
        
        var steps: [StimulusStep] = []
        steps.reserveCapacity(totalTurns)
        
        let clampedLureRate = min(1.0, max(0.0, lureRate))
        
        for i in 0 ..< totalTurns {
            if i < n {
                // Fase de carga de memoria (primeros N turnos): sin objetivos ni evaluación
                let pos = allPositions.randomElement(using: &rng) ?? 0
                let letter = allLetters.randomElement(using: &rng) ?? "H"
                
                positions.append(pos)
                letters.append(letter)
                
                steps.append(
                    StimulusStep(
                        index: i,
                        position: pos,
                        letter: letter,
                        isEvaluatedTurn: false,
                        isPositionTarget: false,
                        isSoundTarget: false,
                        isPositionLure: false,
                        isSoundLure: false
                    )
                )
            } else {
                // Turno evaluable (i >= n)
                let nBackPos = positions[i - n]
                let nBackLetter = letters[i - n]
                
                let isPosTarget = positionTargetIndices.contains(i)
                let isSndTarget = soundTargetIndices.contains(i)
                
                // --- POSICIÓN ---
                let chosenPos: Int
                var isPosLure = false
                
                if isPosTarget {
                    chosenPos = nBackPos
                } else {
                    var lureCandidates: [Int] = []
                    if n > 1 {
                        let lureMinusOne = positions[i - (n - 1)]
                        if lureMinusOne != nBackPos {
                            lureCandidates.append(lureMinusOne)
                        }
                    }
                    if i >= n + 1 {
                        let lurePlusOne = positions[i - (n + 1)]
                        if lurePlusOne != nBackPos && !lureCandidates.contains(lurePlusOne) {
                            lureCandidates.append(lurePlusOne)
                        }
                    }
                    
                    let roll = Double.random(in: 0.0 ..< 1.0, using: &rng)
                    if roll < clampedLureRate, let lurePos = lureCandidates.randomElement(using: &rng) {
                        chosenPos = lurePos
                        isPosLure = true
                    } else {
                        let allowedNonTargetPositions = allPositions.filter { $0 != nBackPos }
                        chosenPos = allowedNonTargetPositions.randomElement(using: &rng) ?? ((nBackPos + 1) % 9)
                    }
                }
                
                // --- SONIDO (LETRA) ---
                let chosenLetter: String
                var isSndLure = false
                
                if isSndTarget {
                    chosenLetter = nBackLetter
                } else {
                    var lureCandidates: [String] = []
                    if n > 1 {
                        let lureMinusOne = letters[i - (n - 1)]
                        if lureMinusOne != nBackLetter {
                            lureCandidates.append(lureMinusOne)
                        }
                    }
                    if i >= n + 1 {
                        let lurePlusOne = letters[i - (n + 1)]
                        if lurePlusOne != nBackLetter && !lureCandidates.contains(lurePlusOne) {
                            lureCandidates.append(lurePlusOne)
                        }
                    }
                    
                    let roll = Double.random(in: 0.0 ..< 1.0, using: &rng)
                    if roll < clampedLureRate, let lureLet = lureCandidates.randomElement(using: &rng) {
                        chosenLetter = lureLet
                        isSndLure = true
                    } else {
                        let allowedNonTargetLetters = allLetters.filter { $0 != nBackLetter }
                        chosenLetter = allowedNonTargetLetters.randomElement(using: &rng) ?? (nBackLetter == "H" ? "J" : "H")
                    }
                }
                
                positions.append(chosenPos)
                letters.append(chosenLetter)
                
                steps.append(
                    StimulusStep(
                        index: i,
                        position: chosenPos,
                        letter: chosenLetter,
                        isEvaluatedTurn: true,
                        isPositionTarget: isPosTarget,
                        isSoundTarget: isSndTarget,
                        isPositionLure: isPosLure,
                        isSoundLure: isSndLure
                    )
                )
            }
        }
        
        return steps
    }
    
    /// Sobrecarga conveniente utilizando `SystemRandomNumberGenerator`
    static func generate(
        nLevel: Int,
        duration: Int,
        interval: Double,
        lureRate: Double = 0.20
    ) -> [StimulusStep] {
        var rng = SystemRandomNumberGenerator()
        return generate(
            nLevel: nLevel,
            duration: duration,
            interval: interval,
            lureRate: lureRate,
            using: &rng
        )
    }
}
