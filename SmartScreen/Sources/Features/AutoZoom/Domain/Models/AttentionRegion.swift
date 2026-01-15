import Foundation
import CoreGraphics

/// Represents a region of user attention with accumulated score
struct AttentionRegion {
    /// Center point of the attention region (normalized coordinates)
    var center: CGPoint
    
    /// Accumulated attention score
    var score: Double
    
    /// Last time this region was updated
    var lastUpdateTime: TimeInterval
    
    /// Number of events that contributed to this region
    var eventCount: Int
    
    /// Calculate Euclidean distance to another region
    func distance(to other: AttentionRegion) -> CGFloat {
        return hypot(center.x - other.center.x, center.y - other.center.y)
    }
    
    /// Check if this region overlaps with another region within a given radius
    func overlaps(with other: AttentionRegion, radius: CGFloat) -> Bool {
        return distance(to: other) <= radius
    }
    
    /// Update region with a new event
    mutating func update(addingScore scoreToAdd: Double, at time: TimeInterval) {
        score += scoreToAdd
        lastUpdateTime = time
        eventCount += 1
    }
    
    /// Apply exponential decay to the score
    mutating func decay(to currentTime: TimeInterval, tau: TimeInterval) {
        let dt = currentTime - lastUpdateTime
        score *= exp(-dt / tau)
    }
}
