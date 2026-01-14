import Foundation

/// EWMA-based cursor trajectory smoother
final class CursorSmoother {
    
    // MARK: - Properties
    
    private(set) var level: SmoothingLevel
    
    // MARK: - Initialization
    
    init(level: SmoothingLevel = .medium) {
        self.level = level
    }
    
    // MARK: - Smoothing
    
    /// Apply EWMA smoothing to a series of cursor points
    /// EWMA: smoothed[i] = alpha * raw[i] + (1 - alpha) * smoothed[i-1]
    func smooth(_ points: [CursorPoint]) -> [CursorPoint] {
        guard points.count > 1 else { return points }
        
        let alpha = level.smoothingFactor
        var smoothed: [CursorPoint] = []
        
        // First point is unchanged
        smoothed.append(points[0])
        
        // Apply EWMA to subsequent points
        for i in 1..<points.count {
            let current = points[i]
            let previous = smoothed[i - 1]
            
            // EWMA formula: new = alpha * previous + (1 - alpha) * current
            // Higher alpha = more weight on previous = smoother but more lag
            let smoothedX = alpha * previous.position.x + (1 - alpha) * current.position.x
            let smoothedY = alpha * previous.position.y + (1 - alpha) * current.position.y
            
            let smoothedPoint = CursorPoint(
                position: CGPoint(x: smoothedX, y: smoothedY),
                timestamp: current.timestamp
            )
            smoothed.append(smoothedPoint)
        }
        
        return smoothed
    }
    
    /// Update smoothing level
    func setLevel(_ newLevel: SmoothingLevel) {
        level = newLevel
    }
}
