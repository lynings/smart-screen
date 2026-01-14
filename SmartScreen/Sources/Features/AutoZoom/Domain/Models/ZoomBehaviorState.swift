import Foundation
import CoreGraphics

/// State machine for smart zoom behavior
/// Manages transitions between zoom states based on user activity
enum ZoomBehaviorState: Equatable {
    /// Normal view (1.0x), no activity detected
    case idle
    
    /// Activity detected, observing cursor behavior
    /// Waiting for cursor to stabilize before zooming
    case observing(since: TimeInterval, position: CGPoint)
    
    /// Zooming in to focus area
    case zoomingIn(startTime: TimeInterval, from: CGFloat, to: CGFloat, center: CGPoint)
    
    /// Zoomed in, following cursor within safe zone
    case zoomed(center: CGPoint, scale: CGFloat)
    
    /// Zooming out due to rapid/large movement
    case zoomingOut(startTime: TimeInterval, from: CGFloat, center: CGPoint)
    
    /// Cooldown after zoom out, waiting for cursor to stabilize
    case cooldown(since: TimeInterval, lastPosition: CGPoint)
    
    // MARK: - Computed Properties
    
    var isZoomed: Bool {
        switch self {
        case .zoomed, .zoomingIn:
            return true
        default:
            return false
        }
    }
    
    var currentScale: CGFloat {
        switch self {
        case .idle, .observing, .cooldown:
            return 1.0
        case .zoomingIn(_, let from, let to, _):
            return (from + to) / 2 // Approximate
        case .zoomed(_, let scale):
            return scale
        case .zoomingOut(_, let from, _):
            return from
        }
    }
}

// MARK: - Behavior Configuration

/// Configuration for smart zoom behavior
struct ZoomBehaviorConfig: Equatable {
    
    // MARK: - Stabilization
    
    /// Time cursor must stay still before triggering zoom (seconds)
    let stabilizationTime: TimeInterval
    
    /// Maximum cursor speed to be considered "stable" (normalized units/second)
    let maxStableSpeed: CGFloat
    
    /// Radius within which cursor movement is considered "staying in area" (normalized)
    let stableAreaRadius: CGFloat
    
    // MARK: - Suppression
    
    /// Minimum distance between clicks to trigger zoom-out-first behavior (normalized)
    let largeMovementThreshold: CGFloat
    
    /// Maximum click frequency before suppressing zoom (clicks/second)
    let maxClickFrequency: Double
    
    /// Cooldown time after zoom out before allowing new zoom (seconds)
    let cooldownDuration: TimeInterval
    
    // MARK: - Animation
    
    /// Duration of zoom in animation (seconds)
    let zoomInDuration: TimeInterval
    
    /// Duration of zoom out animation (seconds)
    let zoomOutDuration: TimeInterval
    
    /// Target zoom scale
    let targetScale: CGFloat
    
    /// Easing curve for animations
    let easing: EasingCurve
    
    // MARK: - Defaults
    
    static let `default` = ZoomBehaviorConfig(
        stabilizationTime: 0.5,
        maxStableSpeed: 0.3,
        stableAreaRadius: 0.05,
        largeMovementThreshold: 0.25,
        maxClickFrequency: 3.0,
        cooldownDuration: 0.3,
        zoomInDuration: 0.4,
        zoomOutDuration: 0.3,
        targetScale: 2.0,
        easing: .easeInOut
    )
    
    static func from(settings: AutoZoomSettings) -> ZoomBehaviorConfig {
        ZoomBehaviorConfig(
            stabilizationTime: 0.5,
            maxStableSpeed: 0.3,
            stableAreaRadius: 0.05,
            largeMovementThreshold: 0.25,
            maxClickFrequency: 3.0,
            cooldownDuration: 0.3,
            zoomInDuration: settings.duration * 0.25,
            zoomOutDuration: settings.duration * 0.25,
            targetScale: settings.zoomLevel,
            easing: settings.easing
        )
    }
}

// MARK: - Activity Event

/// Represents a user activity event for behavior analysis
struct ActivityEvent: Equatable {
    let type: EventType
    let position: CGPoint  // Normalized (0-1)
    let timestamp: TimeInterval
    
    enum EventType: Equatable {
        case move
        case click
    }
}
