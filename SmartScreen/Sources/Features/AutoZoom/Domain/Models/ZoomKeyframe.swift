import Foundation
import CoreGraphics

/// A single keyframe in the continuous zoom timeline
struct ZoomKeyframe: Equatable {
    let time: TimeInterval
    let scale: CGFloat
    let center: CGPoint  // Normalized (0-1)
    let easing: EasingCurve
    
    /// Idle state keyframe (no zoom)
    static func idle(at time: TimeInterval) -> ZoomKeyframe {
        ZoomKeyframe(
            time: time,
            scale: 1.0,
            center: CGPoint(x: 0.5, y: 0.5),
            easing: .easeInOut
        )
    }
    
    /// Create a zoomed keyframe
    static func zoomed(
        at time: TimeInterval,
        scale: CGFloat,
        center: CGPoint,
        easing: EasingCurve = .easeInOut
    ) -> ZoomKeyframe {
        ZoomKeyframe(
            time: time,
            scale: scale,
            center: center,
            easing: easing
        )
    }
}

// MARK: - Interpolation

extension ZoomKeyframe {
    
    /// Interpolate between two keyframes
    static func interpolate(
        from: ZoomKeyframe,
        to: ZoomKeyframe,
        at time: TimeInterval
    ) -> ZoomKeyframe {
        guard from.time != to.time else { return from }
        
        // Calculate progress
        let totalDuration = to.time - from.time
        let elapsed = time - from.time
        let rawProgress = elapsed / totalDuration
        let clampedProgress = max(0, min(1, rawProgress))
        
        // Apply easing
        let easedProgress = to.easing.value(at: clampedProgress)
        
        // Interpolate values
        let scale = from.scale + (to.scale - from.scale) * CGFloat(easedProgress)
        let centerX = from.center.x + (to.center.x - from.center.x) * CGFloat(easedProgress)
        let centerY = from.center.y + (to.center.y - from.center.y) * CGFloat(easedProgress)
        
        return ZoomKeyframe(
            time: time,
            scale: scale,
            center: CGPoint(x: centerX, y: centerY),
            easing: to.easing
        )
    }
}
