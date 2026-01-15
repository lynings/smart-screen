import Foundation
import CoreGraphics

/// Diagnostics tool for analyzing zoom behavior and detecting potential jitter sources
struct ZoomDiagnostics {
    
    /// Analyze cursor track session for potential jitter sources
    static func analyzeSession(_ session: CursorTrackSession) -> SessionAnalysis {
        let clicks = session.clickEvents
        let moves = session.cursorPoints
        
        // Analyze click patterns
        var rapidClicks: [(ClickEvent, ClickEvent, TimeInterval)] = []
        for i in 0..<clicks.count-1 {
            let timeDiff = clicks[i+1].timestamp - clicks[i].timestamp
            if timeDiff < 0.5 {
                rapidClicks.append((clicks[i], clicks[i+1], timeDiff))
            }
        }
        
        // Analyze move patterns around clicks
        var movesNearClicks: [(ClickEvent, [CursorPoint])] = []
        for click in clicks {
            let nearbyMoves = moves.filter { point in
                abs(point.timestamp - click.timestamp) < 0.1 // Within 100ms
            }
            if !nearbyMoves.isEmpty {
                movesNearClicks.append((click, nearbyMoves))
            }
        }
        
        // Calculate average move sampling rate
        var moveSampleIntervals: [TimeInterval] = []
        for i in 0..<moves.count-1 {
            moveSampleIntervals.append(moves[i+1].timestamp - moves[i].timestamp)
        }
        let avgMoveInterval = moveSampleIntervals.isEmpty ? 0 : moveSampleIntervals.reduce(0, +) / Double(moveSampleIntervals.count)
        
        return SessionAnalysis(
            totalClicks: clicks.count,
            totalMoves: moves.count,
            rapidClickPairs: rapidClicks,
            movesNearClicks: movesNearClicks,
            avgMoveSampleInterval: avgMoveInterval,
            duration: session.duration
        )
    }
    
    /// Analyze generated keyframes for potential jitter
    static func analyzeKeyframes(_ keyframes: [ZoomKeyframe]) -> KeyframeAnalysis {
        var rapidTransitions: [(ZoomKeyframe, ZoomKeyframe, TimeInterval)] = []
        var frequentScaleChanges: [(ZoomKeyframe, ZoomKeyframe, CGFloat)] = []
        
        for i in 0..<keyframes.count-1 {
            let current = keyframes[i]
            let next = keyframes[i+1]
            let timeDiff = next.time - current.time
            let scaleDiff = abs(next.scale - current.scale)
            let positionDiff = hypot(next.center.x - current.center.x, next.center.y - current.center.y)
            
            // Detect rapid transitions (< 0.1s between keyframes with significant changes)
            if timeDiff < 0.1 && (scaleDiff > 0.1 || positionDiff > 0.05) {
                rapidTransitions.append((current, next, timeDiff))
            }
            
            // Detect frequent scale changes
            if scaleDiff > 0.5 {
                frequentScaleChanges.append((current, next, scaleDiff))
            }
        }
        
        return KeyframeAnalysis(
            totalKeyframes: keyframes.count,
            rapidTransitions: rapidTransitions,
            frequentScaleChanges: frequentScaleChanges
        )
    }
    
    /// Print diagnostic report
    static func printDiagnosticReport(session: CursorTrackSession, keyframes: [ZoomKeyframe]) {
        let sessionAnalysis = analyzeSession(session)
        let keyframeAnalysis = analyzeKeyframes(keyframes)
        
        print("═══════════════════════════════════════════════════════")
        print("🔍 Auto Zoom Diagnostics Report")
        print("═══════════════════════════════════════════════════════")
        
        print("\n📊 Session Analysis:")
        print("  Duration: \(String(format: "%.2f", sessionAnalysis.duration))s")
        print("  Total Clicks: \(sessionAnalysis.totalClicks)")
        print("  Total Moves: \(sessionAnalysis.totalMoves)")
        print("  Avg Move Sample Rate: \(String(format: "%.1f", 1.0/sessionAnalysis.avgMoveSampleInterval))fps")
        
        if !sessionAnalysis.rapidClickPairs.isEmpty {
            print("\n⚠️  Rapid Clicks Detected (\(sessionAnalysis.rapidClickPairs.count) pairs):")
            for (click1, click2, timeDiff) in sessionAnalysis.rapidClickPairs.prefix(5) {
                let distance = hypot(click2.position.x - click1.position.x, click2.position.y - click1.position.y)
                print("    • t=\(String(format: "%.3f", click1.timestamp)) → t=\(String(format: "%.3f", click2.timestamp)) (Δt=\(String(format: "%.3f", timeDiff))s, Δd=\(String(format: "%.3f", distance)))")
            }
        }
        
        if !sessionAnalysis.movesNearClicks.isEmpty {
            print("\n🎯 Moves Near Clicks (\(sessionAnalysis.movesNearClicks.count) clicks with nearby moves):")
            for (click, moves) in sessionAnalysis.movesNearClicks.prefix(3) {
                print("    • Click at t=\(String(format: "%.3f", click.timestamp)) has \(moves.count) moves within 100ms")
            }
        }
        
        print("\n🎬 Keyframe Analysis:")
        print("  Total Keyframes: \(keyframeAnalysis.totalKeyframes)")
        
        if !keyframeAnalysis.rapidTransitions.isEmpty {
            print("\n⚠️  Rapid Transitions Detected (\(keyframeAnalysis.rapidTransitions.count)):")
            for (kf1, kf2, timeDiff) in keyframeAnalysis.rapidTransitions.prefix(5) {
                print("    • t=\(String(format: "%.3f", kf1.time)) → t=\(String(format: "%.3f", kf2.time)) (Δt=\(String(format: "%.3f", timeDiff))s)")
            }
        }
        
        if !keyframeAnalysis.frequentScaleChanges.isEmpty {
            print("\n📏 Significant Scale Changes (\(keyframeAnalysis.frequentScaleChanges.count)):")
            for (kf1, kf2, scaleDiff) in keyframeAnalysis.frequentScaleChanges.prefix(5) {
                print("    • t=\(String(format: "%.3f", kf1.time)): scale \(String(format: "%.2f", kf1.scale)) → \(String(format: "%.2f", kf2.scale)) (Δ=\(String(format: "%.2f", scaleDiff)))")
            }
        }
        
        print("\n═══════════════════════════════════════════════════════")
    }
}

// MARK: - Analysis Results

struct SessionAnalysis {
    let totalClicks: Int
    let totalMoves: Int
    let rapidClickPairs: [(ClickEvent, ClickEvent, TimeInterval)]
    let movesNearClicks: [(ClickEvent, [CursorPoint])]
    let avgMoveSampleInterval: TimeInterval
    let duration: TimeInterval
}

struct KeyframeAnalysis {
    let totalKeyframes: Int
    let rapidTransitions: [(ZoomKeyframe, ZoomKeyframe, TimeInterval)]
    let frequentScaleChanges: [(ZoomKeyframe, ZoomKeyframe, CGFloat)]
}
