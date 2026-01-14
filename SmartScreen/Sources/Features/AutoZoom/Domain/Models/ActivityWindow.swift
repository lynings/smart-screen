import Foundation

/// Represents a time window of cursor activity analysis
struct ActivityWindow: Equatable {
    
    // MARK: - Constants
    
    /// Threshold for high activity (events per second)
    static let highActivityThreshold: Double = 10.0
    
    /// Threshold for dwell detection (normalized velocity)
    static let dwellVelocityThreshold: CGFloat = 0.02
    
    /// Minimum dwell duration to be considered significant
    static let minDwellDuration: TimeInterval = 0.5
    
    /// Maximum velocity for zoom calculation (normalized per second)
    static let maxVelocity: CGFloat = 1.0
    
    // MARK: - Properties
    
    /// Time range of this activity window
    let timeRange: ClosedRange<TimeInterval>
    
    /// Bounding box of all cursor positions (normalized 0-1)
    let boundingBox: CGRect
    
    /// Center of activity (centroid of all positions)
    let centroid: CGPoint
    
    /// Activity intensity (events per second)
    let intensity: Double
    
    /// Average cursor velocity (normalized distance per second)
    let averageVelocity: CGFloat
    
    /// Whether this window contains a click event
    let hasClick: Bool
    
    /// Duration of dwell (cursor nearly stationary), nil if no dwell
    let dwellDuration: TimeInterval?
    
    // MARK: - Computed Properties
    
    /// Activity area as ratio of screen (0-1)
    var areaRatio: CGFloat {
        boundingBox.width * boundingBox.height
    }
    
    /// Whether this is high activity (many events)
    var isHighActivity: Bool {
        intensity >= Self.highActivityThreshold
    }
    
    /// Whether cursor is dwelling (nearly stationary)
    var isDwell: Bool {
        guard let dwell = dwellDuration else { return false }
        return averageVelocity < Self.dwellVelocityThreshold && dwell >= Self.minDwellDuration
    }
    
    /// Duration of this window
    var duration: TimeInterval {
        timeRange.upperBound - timeRange.lowerBound
    }
    
    // MARK: - Zoom Calculation
    
    /// Suggested zoom level based on activity characteristics
    var suggestedZoomLevel: CGFloat {
        // 1. Base zoom from area ratio
        let baseZoom: CGFloat
        switch areaRatio {
        case ..<0.05:
            baseZoom = 2.5  // Small area: high zoom
        case 0.05..<0.15:
            baseZoom = 2.0  // Medium area: medium zoom
        case 0.15..<0.30:
            baseZoom = 1.5  // Large area: low zoom
        default:
            baseZoom = 1.0  // Very large: no zoom
        }
        
        // 2. Apply velocity factor (reduce zoom for fast movement)
        let velocityFactor = max(0.5, 1.0 - (averageVelocity / Self.maxVelocity) * 0.5)
        
        // 3. Boost for clicks
        let clickBoost: CGFloat = hasClick ? 1.1 : 1.0
        
        // 4. Boost for dwell
        let dwellBoost: CGFloat = isDwell ? 1.15 : 1.0
        
        // 5. Calculate final zoom
        let finalZoom = baseZoom * velocityFactor * clickBoost * dwellBoost
        
        // 6. Clamp to valid range
        return min(max(finalZoom, 1.0), 3.0)
    }
}
