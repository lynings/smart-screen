import Foundation

/// Types of events that can trigger a zoom
enum ZoomTrigger: Equatable, Codable {
    /// Triggered by a mouse click
    case click(position: CGPoint)
    
    /// Triggered by cursor dwelling (staying still)
    case dwell(position: CGPoint, duration: TimeInterval)
    
    /// Triggered by activity clustering in a region
    case activityCluster(region: CGRect)
    
    /// Triggered by transitioning between regions
    case regionTransition(from: CGPoint, to: CGPoint)
    
    // MARK: - Properties
    
    /// Primary position for this trigger
    var position: CGPoint {
        switch self {
        case .click(let position):
            return position
        case .dwell(let position, _):
            return position
        case .activityCluster(let region):
            return CGPoint(x: region.midX, y: region.midY)
        case .regionTransition(_, let to):
            return to
        }
    }
    
    /// Priority of this trigger type (higher = more important)
    var priority: Int {
        switch self {
        case .click:
            return 100
        case .dwell:
            return 80
        case .activityCluster:
            return 60
        case .regionTransition:
            return 40
        }
    }
    
    /// Suggested zoom duration for this trigger type
    var suggestedDuration: TimeInterval {
        switch self {
        case .click:
            return 0.4
        case .dwell(_, let duration):
            return min(duration * 0.8, 0.6)
        case .activityCluster:
            return 0.5
        case .regionTransition:
            return 0.6
        }
    }
}
