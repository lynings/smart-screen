import Foundation

/// Represents a cursor position at a specific point in time
struct CursorPoint: Equatable {
    let position: CGPoint
    let timestamp: TimeInterval
    
    /// Calculate the distance to another cursor point
    func distance(to other: CursorPoint) -> Double {
        let dx = other.position.x - position.x
        let dy = other.position.y - position.y
        return sqrt(dx * dx + dy * dy)
    }
    
    /// Calculate the velocity (pixels per second) to reach another point
    func velocity(to other: CursorPoint) -> Double {
        let timeDelta = other.timestamp - timestamp
        guard timeDelta > 0 else { return 0 }
        return distance(to: other) / timeDelta
    }
}
