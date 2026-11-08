import XCTest
@testable import DualNBack

final class SequenceAndScoringTests: XCTestCase {
    
    // MARK: - 1. Prueba de Cálculo de Turnos (N = 2, 120 s, 1.5 s -> 80 + 2 = 82 turnos)
    
    func testTurnCountForN2Duration120Interval1_5() {
        let nLevel = 2
        let duration = 120
        let interval = 1.5
        
        let evaluatedTurns = SequenceGenerator.calculateEvaluatedTurns(duration: duration, interval: interval)
        XCTAssertEqual(evaluatedTurns, 80, "120s / 1.5s debe producir exactamente 80 turnos evaluables.")
        
        let totalTurns = SequenceGenerator.calculateTotalTurns(duration: duration, interval: interval, nLevel: nLevel)
        XCTAssertEqual(totalTurns, 82, "El total de turnos debe ser 80 + 2 = 82.")
        
        let sequence = SequenceGenerator.generate(
            nLevel: nLevel,
            duration: duration,
            interval: interval,
            lureRate: 0.20
        )
        XCTAssertEqual(sequence.count, 82)
        
        // Verificar que los primeros N turnos son de preparación y los 80 restantes son evaluables
        let prepTurns = sequence.prefix(nLevel)
        XCTAssertTrue(prepTurns.allSatisfy { !$0.isEvaluatedTurn && !$0.isPositionTarget && !$0.isSoundTarget })
        
        let evalTurns = sequence.dropFirst(nLevel)
        XCTAssertEqual(evalTurns.count, 80)
        XCTAssertTrue(evalTurns.allSatisfy { $0.isEvaluatedTurn })
    }
    
    // MARK: - 2. Prueba de Cero Coincidencias Accidentales en Turnos No-Objetivo
    
    func testZeroAccidentalMatchesInNonTargetTurnsAcrossAllNLevels() {
        for nLevel in 1...9 {
            for lureRate in [0.0, 0.10, 0.20, 0.30] {
                let steps = SequenceGenerator.generate(
                    nLevel: nLevel,
                    duration: 120,
                    interval: 1.5,
                    lureRate: lureRate
                )
                
                for i in nLevel ..< steps.count {
                    let current = steps[i]
                    let nBack = steps[i - nLevel]
                    
                    if current.isPositionTarget {
                        XCTAssertEqual(
                            current.position,
                            nBack.position,
                            "El turno objetivo de posición \(i) (N=\(nLevel)) debe coincidir con \(i - nLevel)."
                        )
                    } else {
                        XCTAssertNotEqual(
                            current.position,
                            nBack.position,
                            "El turno NO-objetivo de posición \(i) (N=\(nLevel)) jamás debe coincidir accidentalmente con \(i - nLevel)."
                        )
                    }
                    
                    if current.isSoundTarget {
                        XCTAssertEqual(
                            current.letter,
                            nBack.letter,
                            "El turno objetivo de sonido \(i) (N=\(nLevel)) debe coincidir con \(i - nLevel)."
                        )
                    } else {
                        XCTAssertNotEqual(
                            current.letter,
                            nBack.letter,
                            "El turno NO-objetivo de sonido \(i) (N=\(nLevel)) jamás debe coincidir accidentalmente con \(i - nLevel)."
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - 3. Prueba de Distribución de Objetivos y Letras Fonéticas Válidas
    
    func testTargetDistributionAndAllowedSpanishLetters() {
        let steps = SequenceGenerator.generate(
            nLevel: 2,
            duration: 120,
            interval: 1.5,
            lureRate: 0.20
        )
        
        let expectedTargets = SequenceGenerator.calculateTargetsPerModality(evaluatedTurns: 80)
        let posTargets = steps.filter(\.isPositionTarget).count
        let sndTargets = steps.filter(\.isSoundTarget).count
        let dualTargets = steps.filter { $0.isPositionTarget && $0.isSoundTarget }.count
        
        XCTAssertEqual(posTargets, expectedTargets)
        XCTAssertEqual(sndTargets, expectedTargets)
        XCTAssertGreaterThanOrEqual(dualTargets, 1, "Debe existir al menos una coincidencia doble simultánea.")
        
        let validLetters = Set(StimulusStep.allowedLetters)
        for step in steps {
            XCTAssertTrue(validLetters.contains(step.letter), "Letra inválida encontrada: \(step.letter)")
            XCTAssertTrue((0...8).contains(step.position), "Posición fuera de rango 0...8: \(step.position)")
            XCTAssertNotNil(StimulusStep.phoneticDictionary[step.letter], "Falta fonética en español para \(step.letter)")
        }
    }
    
    // MARK: - 4. Prueba de Fórmula de Porcentaje y Reglas de Nivel Adaptativo
    
    func testPercentageCalculationFormula() {
        // Aciertos / (Aciertos + Omisiones + Falsas Alarmas) * 100
        let pctPerfect = SessionResult.calculatePercentage(hits: 15, misses: 0, falseAlarms: 0)
        XCTAssertEqual(pctPerfect, 100.0, accuracy: 0.001)
        
        let pct80 = SessionResult.calculatePercentage(hits: 16, misses: 2, falseAlarms: 2)
        XCTAssertEqual(pct80, 80.0, accuracy: 0.001)
        
        let pct50 = SessionResult.calculatePercentage(hits: 10, misses: 5, falseAlarms: 5)
        XCTAssertEqual(pct50, 50.0, accuracy: 0.001)
        
        let pctZeroDenominator = SessionResult.calculatePercentage(hits: 0, misses: 0, falseAlarms: 0)
        XCTAssertEqual(pctZeroDenominator, 0.0, accuracy: 0.001)
    }
    
    func testAdaptiveProgressionRules() {
        // Caso 1: >= 80% en AMBOS canales -> Sube a N + 1
        let up = SessionResult.evaluateProgression(
            currentN: 2,
            soundPercentage: 80.0,
            positionPercentage: 85.0,
            isAdaptive: true
        )
        XCTAssertEqual(up.nextN, 3)
        XCTAssertEqual(up.progression, .increased)
        
        // Caso 2: Límite superior N = 9 no supera 9
        let capAt9 = SessionResult.evaluateProgression(
            currentN: 9,
            soundPercentage: 90.0,
            positionPercentage: 95.0,
            isAdaptive: true
        )
        XCTAssertEqual(capAt9.nextN, 9)
        XCTAssertEqual(capAt9.progression, .increased)
        
        // Caso 3: < 50% en cualquiera de los dos canales -> Baja a N - 1
        let downBySound = SessionResult.evaluateProgression(
            currentN: 3,
            soundPercentage: 49.9,
            positionPercentage: 90.0,
            isAdaptive: true
        )
        XCTAssertEqual(downBySound.nextN, 2)
        XCTAssertEqual(downBySound.progression, .decreased)
        
        let downByPosition = SessionResult.evaluateProgression(
            currentN: 3,
            soundPercentage: 85.0,
            positionPercentage: 40.0,
            isAdaptive: true
        )
        XCTAssertEqual(downByPosition.nextN, 2)
        XCTAssertEqual(downByPosition.progression, .decreased)
        
        // Caso 4: Límite inferior N = 1 no baja de 1
        let floorAt1 = SessionResult.evaluateProgression(
            currentN: 1,
            soundPercentage: 30.0,
            positionPercentage: 25.0,
            isAdaptive: true
        )
        XCTAssertEqual(floorAt1.nextN, 1)
        XCTAssertEqual(floorAt1.progression, .decreased)
        
        // Caso 5: Entre 50% y 79% (o uno >= 80% y el otro 65%) -> Se mantiene en N
        let stay = SessionResult.evaluateProgression(
            currentN: 4,
            soundPercentage: 85.0,
            positionPercentage: 75.0,
            isAdaptive: true
        )
        XCTAssertEqual(stay.nextN, 4)
        XCTAssertEqual(stay.progression, .maintained)
        
        // Caso 6: Modo adaptativo desactivado -> Siempre mantiene N en modo manual
        let manual = SessionResult.evaluateProgression(
            currentN: 4,
            soundPercentage: 100.0,
            positionPercentage: 100.0,
            isAdaptive: false
        )
        XCTAssertEqual(manual.nextN, 4)
        XCTAssertEqual(manual.progression, .manual)
    }
}
