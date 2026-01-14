import Foundation

/// A keyframe in the focus path for smooth zoom animation
struct FocusKeyframe: Equatable, Codable {
    
    // MARK: - Properties
    
    /// Time of this keyframe (seconds from video start)
    let time: TimeInterval
    
    /// Focus center position (normalized 0-1)
    let center: CGPoint
    
    /// Zoom scale at this keyframe
    let scale: CGFloat
    
    /// Cursor velocity at this point (for prediction)
    let velocity: CGPoint
    
    // MARK: - Interpolation
    
    /// Interpolate between this keyframe and another
    static func interpolate(
        from: FocusKeyframe,
        to: FocusKeyframe,
        at time: TimeInterval,
        easing: EasingCurve
    ) -> FocusKeyframe {
        let duration = to.time - from.time
        guard duration > 0 else { return from }
        
        let rawProgress = (time - from.time) / duration
        let progress = easing.value(at: rawProgress)
        
        return FocusKeyframe(
            time: time,
            center: CGPoint(
                x: from.center.x + CGFloat(progress) * (to.center.x - from.center.x),
                y: from.center.y + CGFloat(progress) * (to.center.y - from.center.y)
            ),
            scale: from.scale + CGFloat(progress) * (to.scale - from.scale),
            velocity: CGPoint(
                x: from.velocity.x + CGFloat(progress) * (to.velocity.x - from.velocity.x),
                y: from.velocity.y + CGFloat(progress) * (to.velocity.y - from.velocity.y)
            )
        )
    }
}
