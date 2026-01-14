import Foundation

/// A smart zoom segment with dynamic focus following
struct SmartZoomSegment: Equatable {
    
    // MARK: - Properties
    
    /// Time range of this segment
    let timeRange: ClosedRange<TimeInterval>
    
    /// What triggered this zoom
    let trigger: ZoomTrigger
    
    /// Keyframes defining the focus path
    let keyframes: [FocusKeyframe]
    
    /// Easing curve for interpolation
    let easing: EasingCurve
    
    // MARK: - Computed Properties
    
    /// Duration of this segment
    var duration: TimeInterval {
        timeRange.upperBound - timeRange.lowerBound
    }
    
    /// Target zoom scale (maximum scale in keyframes)
    var targetScale: CGFloat {
        keyframes.map(\.scale).max() ?? 1.0
    }
    
    // MARK: - Time Queries
    
    /// Check if a given time falls within this segment
    func contains(time: TimeInterval) -> Bool {
        time >= timeRange.lowerBound && time <= timeRange.upperBound
    }
    
    // MARK: - Focus Calculation
    
    /// Get the focus state at a specific time
    func focusAt(time: TimeInterval) -> FocusState {
        guard !keyframes.isEmpty else {
            return .default
        }
        
        // Before first keyframe
        if time <= keyframes.first!.time {
            return FocusState.from(keyframes.first!)
        }
        
        // After last keyframe
        if time >= keyframes.last!.time {
            return FocusState.from(keyframes.last!)
        }
        
        // Find surrounding keyframes
        var beforeIndex = 0
        for (index, keyframe) in keyframes.enumerated() {
            if keyframe.time <= time {
                beforeIndex = index
            } else {
                break
            }
        }
        
        let afterIndex = min(beforeIndex + 1, keyframes.count - 1)
        let before = keyframes[beforeIndex]
        let after = keyframes[afterIndex]
        
        // Interpolate
        let interpolated = FocusKeyframe.interpolate(
            from: before,
            to: after,
            at: time,
            easing: easing
        )
        
        return FocusState.from(interpolated)
    }
    
    /// Get the scale at a specific time
    func scaleAt(time: TimeInterval) -> CGFloat {
        focusAt(time: time).scale
    }
    
    /// Get the center at a specific time
    func centerAt(time: TimeInterval) -> CGPoint {
        focusAt(time: time).center
    }
    
    // MARK: - Factory Methods
    
    /// Create a simple zoom segment (zoom in, hold, zoom out)
    static func simple(
        startTime: TimeInterval,
        center: CGPoint,
        scale: CGFloat,
        zoomInDuration: TimeInterval = 0.4,
        holdDuration: TimeInterval = 2.0,
        zoomOutDuration: TimeInterval = 0.5,
        trigger: ZoomTrigger,
        easing: EasingCurve = .easeInOut
    ) -> SmartZoomSegment {
        let endTime = startTime + zoomInDuration + holdDuration + zoomOutDuration
        
        let keyframes = [
            FocusKeyframe(time: startTime, center: center, scale: 1.0, velocity: .zero),
            FocusKeyframe(time: startTime + zoomInDuration, center: center, scale: scale, velocity: .zero),
            FocusKeyframe(time: startTime + zoomInDuration + holdDuration, center: center, scale: scale, velocity: .zero),
            FocusKeyframe(time: endTime, center: center, scale: 1.0, velocity: .zero)
        ]
        
        return SmartZoomSegment(
            timeRange: startTime...endTime,
            trigger: trigger,
            keyframes: keyframes,
            easing: easing
        )
    }
    
    /// Create a following zoom segment (center moves along path)
    static func following(
        timeRange: ClosedRange<TimeInterval>,
        centerPath: [(time: TimeInterval, center: CGPoint)],
        scale: CGFloat,
        trigger: ZoomTrigger,
        easing: EasingCurve = .easeInOut
    ) -> SmartZoomSegment {
        let keyframes = centerPath.map { point in
            FocusKeyframe(time: point.time, center: point.center, scale: scale, velocity: .zero)
        }
        
        return SmartZoomSegment(
            timeRange: timeRange,
            trigger: trigger,
            keyframes: keyframes,
            easing: easing
        )
    }
}
