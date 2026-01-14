import Foundation

/// Represents the current state of the zoom state machine
enum ZoomState: Equatable {
    /// No zoom active, scale = 1.0
    case idle
    
    /// Zooming in from startScale to targetScale
    case zoomingIn(startScale: CGFloat, targetScale: CGFloat, startTime: TimeInterval, duration: TimeInterval)
    
    /// Holding zoom at current scale, center follows cursor
    case zoomed(scale: CGFloat, holdStartTime: TimeInterval, holdEndTime: TimeInterval)
    
    /// Zooming out from currentScale to 1.0
    case zoomingOut(startScale: CGFloat, startTime: TimeInterval, duration: TimeInterval)
    
    /// Panning to a new position (at reduced scale or scale 1.0)
    /// After reaching target, will zoom in to targetScale
    case panning(targetPosition: CGPoint, targetScale: CGFloat, startTime: TimeInterval)
    
    // MARK: - Computed Properties
    
    var isActive: Bool {
        switch self {
        case .idle:
            return false
        case .zoomingIn, .zoomed, .zoomingOut, .panning:
            return true
        }
    }
    
    var currentTargetScale: CGFloat {
        switch self {
        case .idle:
            return 1.0
        case .zoomingIn(_, let targetScale, _, _):
            return targetScale
        case .zoomed(let scale, _, _):
            return scale
        case .zoomingOut:
            return 1.0
        case .panning(_, let targetScale, _):
            return targetScale
        }
    }
    
    var isPanning: Bool {
        if case .panning = self { return true }
        return false
    }
}

/// Events that can trigger state transitions
enum ZoomEvent: Equatable {
    /// Significant activity detected (click, dwell, etc.)
    case activityDetected(position: CGPoint, suggestedScale: CGFloat)
    
    /// Activity continues (extend hold)
    case activityContinues(position: CGPoint)
    
    /// Large movement detected - requires zoom out → pan → zoom in
    case largeMovement(from: CGPoint, to: CGPoint, distance: CGFloat, suggestedScale: CGFloat)
    
    /// No activity detected
    case noActivity
    
    /// Zoom in animation completed
    case zoomInComplete
    
    /// Hold time expired
    case holdExpired
    
    /// Zoom out animation completed
    case zoomOutComplete
    
    /// Pan animation completed (reached target position)
    case panComplete
}

/// Output of the state machine for a given time
struct ZoomOutput: Equatable {
    let scale: CGFloat
    let center: CGPoint
    let isTransitioning: Bool
    
    static let idle = ZoomOutput(scale: 1.0, center: CGPoint(x: 0.5, y: 0.5), isTransitioning: false)
}
