import Foundation

/// Configuration for focus following behavior
struct FocusFollowConfig {
    /// Edge margin (portion of visible area to keep cursor away from edges)
    let edgeMargin: CGFloat
    
    /// Whether to use spring physics for smoothing
    let useSpringSmoothing: Bool
    
    /// Spring animation parameters for following
    let spring: SpringAnimation
    
    /// Lookahead factor for predictive panning (0 = none, higher = more prediction)
    let lookaheadFactor: CGFloat
    
    /// Whether continuous follow mode is enabled
    let continuousFollowEnabled: Bool
    
    /// Minimum cursor movement (normalized) to trigger follow update
    let followMovementThreshold: CGFloat
    
    /// Fallback smoothing factor for EWMA (0 = no smoothing, 1 = instant)
    let ewmaSmoothingFactor: CGFloat
    
    static let `default` = FocusFollowConfig(
        edgeMargin: 0.15,
        useSpringSmoothing: true,
        spring: AnimationStyle.mellow.spring,
        lookaheadFactor: 0.1,
        continuousFollowEnabled: true,
        followMovementThreshold: 0.01,
        ewmaSmoothingFactor: 0.25
    )
    
    init(
        edgeMargin: CGFloat = 0.15,
        useSpringSmoothing: Bool = true,
        spring: SpringAnimation = AnimationStyle.mellow.spring,
        lookaheadFactor: CGFloat = 0.1,
        continuousFollowEnabled: Bool = true,
        followMovementThreshold: CGFloat = 0.01,
        ewmaSmoothingFactor: CGFloat = 0.25
    ) {
        self.edgeMargin = edgeMargin
        self.useSpringSmoothing = useSpringSmoothing
        self.spring = spring
        self.lookaheadFactor = lookaheadFactor
        self.continuousFollowEnabled = continuousFollowEnabled
        self.followMovementThreshold = followMovementThreshold
        self.ewmaSmoothingFactor = ewmaSmoothingFactor
    }
    
    /// Create config from animation style
    static func fromStyle(_ style: AnimationStyle) -> FocusFollowConfig {
        FocusFollowConfig(
            edgeMargin: 0.15,
            useSpringSmoothing: true,
            spring: style.spring,
            lookaheadFactor: style.followLookaheadFactor,
            continuousFollowEnabled: true,
            followMovementThreshold: 0.01,
            ewmaSmoothingFactor: style.followSmoothingFactor
        )
    }
}

/// Calculates smooth focus following for auto zoom using spring physics
final class FocusFollower {
    
    // MARK: - Configuration
    
    private let config: FocusFollowConfig
    
    // Legacy accessors for backward compatibility
    var edgeMargin: CGFloat { config.edgeMargin }
    var followSmoothing: CGFloat { config.ewmaSmoothingFactor }
    var lookaheadFactor: CGFloat { config.lookaheadFactor }
    
    // MARK: - State
    
    private var previousCenter: CGPoint?
    private var previousTime: TimeInterval?
    private var targetCenter: CGPoint?
    private var springStartTime: TimeInterval?
    private var springStartCenter: CGPoint?
    private var currentVelocity: CGPoint = .zero
    
    // MARK: - Initialization
    
    init(config: FocusFollowConfig = .default) {
        self.config = config
    }
    
    /// Legacy initializer for backward compatibility
    convenience init(
        edgeMargin: CGFloat = 0.15,
        followSmoothing: CGFloat = 0.2,
        lookaheadFactor: CGFloat = 0.1
    ) {
        let config = FocusFollowConfig(
            edgeMargin: edgeMargin,
            useSpringSmoothing: false,  // Use EWMA for legacy
            lookaheadFactor: lookaheadFactor,
            ewmaSmoothingFactor: followSmoothing
        )
        self.init(config: config)
    }
    
    // MARK: - Focus Calculation
    
    /// Calculate focus state at a given time
    func focusState(
        at time: TimeInterval,
        segments: [SmartZoomSegment],
        cursorPosition: CGPoint,
        cursorVelocity: CGPoint = .zero
    ) -> FocusState {
        // 1. Find active segment
        guard let segment = findActiveSegment(at: time, in: segments) else {
            // No active segment - return default state centered on cursor
            return FocusState(center: cursorPosition, scale: 1.0)
        }
        
        // 2. Get base focus state from segment
        let segmentState = segment.focusAt(time: time)
        
        // 3. Apply cursor following (edge-aware adjustment)
        let adjustedCenter = calculateAdjustedCenter(
            baseCenter: segmentState.center,
            cursorPosition: cursorPosition,
            cursorVelocity: cursorVelocity,
            scale: segmentState.scale
        )
        
        // 4. Apply smoothing (spring or EWMA)
        let smoothedCenter: CGPoint
        if config.useSpringSmoothing {
            smoothedCenter = applySpringSmoothing(
                targetCenter: adjustedCenter,
                time: time
            )
        } else {
            smoothedCenter = applyEWMASmoothing(center: adjustedCenter, time: time)
        }
        
        // 5. Apply boundary constraints
        let constrainedCenter = applyBoundaryConstraints(
            center: smoothedCenter,
            scale: segmentState.scale
        )
        
        return FocusState(center: constrainedCenter, scale: segmentState.scale)
    }
    
    /// Calculate follow center using spring animation
    /// This method can be used directly for continuous following without segments
    func calculateSpringFollowCenter(
        currentCenter: CGPoint,
        targetPosition: CGPoint,
        time: TimeInterval,
        scale: CGFloat
    ) -> CGPoint {
        // Constrain target to keep cursor visible
        let constrainedTarget = constrainCenterForCursor(
            center: targetPosition,
            cursorPosition: targetPosition,
            scale: scale
        )
        
        // Check if target has changed significantly
        let needsNewSpring = shouldStartNewSpring(to: constrainedTarget)
        
        if needsNewSpring {
            startNewSpring(from: currentCenter, to: constrainedTarget, at: time)
        }
        
        // Calculate spring position
        guard let startTime = springStartTime,
              let startCenter = springStartCenter,
              let target = targetCenter else {
            return constrainedTarget
        }
        
        let elapsed = time - startTime
        let springPos = config.spring.value(
            at: elapsed,
            from: startCenter,
            to: target,
            initialVelocity: currentVelocity
        )
        
        // Update velocity for potential interruption
        currentVelocity = config.spring.velocity(
            at: elapsed,
            from: startCenter,
            to: target
        )
        
        // Apply boundary constraints
        return applyBoundaryConstraints(center: springPos, scale: scale)
    }
    
    /// Reset follower state (call when starting new export)
    func reset() {
        previousCenter = nil
        previousTime = nil
        targetCenter = nil
        springStartTime = nil
        springStartCenter = nil
        currentVelocity = .zero
    }
    
    // MARK: - Private Helpers
    
    private func findActiveSegment(at time: TimeInterval, in segments: [SmartZoomSegment]) -> SmartZoomSegment? {
        segments.first { $0.contains(time: time) }
    }
    
    private func calculateAdjustedCenter(
        baseCenter: CGPoint,
        cursorPosition: CGPoint,
        cursorVelocity: CGPoint,
        scale: CGFloat
    ) -> CGPoint {
        guard scale > 1.0 else { return baseCenter }
        
        // Calculate visible area dimensions
        let visibleWidth = 1.0 / scale
        let visibleHeight = 1.0 / scale
        let effectiveMargin = config.edgeMargin * visibleWidth
        
        var center = baseCenter
        
        // 1. Apply lookahead based on velocity (predictive following)
        if config.lookaheadFactor > 0 {
            center.x += cursorVelocity.x * config.lookaheadFactor
            center.y += cursorVelocity.y * config.lookaheadFactor
        }
        
        // 2. Ensure cursor is within safe zone
        let halfWidth = visibleWidth / 2
        let halfHeight = visibleHeight / 2
        
        // Calculate cursor position relative to center
        let cursorRelativeX = cursorPosition.x - center.x
        let cursorRelativeY = cursorPosition.y - center.y
        
        // Check if cursor is outside safe zone and adjust
        let safeHalfWidth = halfWidth - effectiveMargin
        let safeHalfHeight = halfHeight - effectiveMargin
        
        if cursorRelativeX > safeHalfWidth {
            center.x = cursorPosition.x - safeHalfWidth
        } else if cursorRelativeX < -safeHalfWidth {
            center.x = cursorPosition.x + safeHalfWidth
        }
        
        if cursorRelativeY > safeHalfHeight {
            center.y = cursorPosition.y - safeHalfHeight
        } else if cursorRelativeY < -safeHalfHeight {
            center.y = cursorPosition.y + safeHalfHeight
        }
        
        return center
    }
    
    private func constrainCenterForCursor(
        center: CGPoint,
        cursorPosition: CGPoint,
        scale: CGFloat
    ) -> CGPoint {
        guard scale > 1.0 else { return center }
        
        let visibleWidth = 1.0 / scale
        let visibleHeight = 1.0 / scale
        let halfWidth = visibleWidth / 2
        let halfHeight = visibleHeight / 2
        let margin = config.edgeMargin * visibleWidth
        
        var result = center
        
        // Ensure cursor stays in safe zone
        let safeHalfWidth = halfWidth - margin
        let safeHalfHeight = halfHeight - margin
        
        let dx = cursorPosition.x - result.x
        let dy = cursorPosition.y - result.y
        
        if dx > safeHalfWidth {
            result.x = cursorPosition.x - safeHalfWidth
        } else if dx < -safeHalfWidth {
            result.x = cursorPosition.x + safeHalfWidth
        }
        
        if dy > safeHalfHeight {
            result.y = cursorPosition.y - safeHalfHeight
        } else if dy < -safeHalfHeight {
            result.y = cursorPosition.y + safeHalfHeight
        }
        
        return result
    }
    
    private func applySpringSmoothing(targetCenter: CGPoint, time: TimeInterval) -> CGPoint {
        // Check if target has changed
        let needsNewSpring = shouldStartNewSpring(to: targetCenter)
        
        if needsNewSpring {
            let startFrom = previousCenter ?? targetCenter
            startNewSpring(from: startFrom, to: targetCenter, at: time)
        }
        
        // Calculate spring position
        guard let startTime = springStartTime,
              let startCenter = springStartCenter,
              let target = self.targetCenter else {
            previousCenter = targetCenter
            previousTime = time
            return targetCenter
        }
        
        let elapsed = time - startTime
        let springPos = config.spring.value(
            at: elapsed,
            from: startCenter,
            to: target,
            initialVelocity: currentVelocity
        )
        
        // Update velocity
        currentVelocity = config.spring.velocity(
            at: elapsed,
            from: startCenter,
            to: target
        )
        
        previousCenter = springPos
        previousTime = time
        
        return springPos
    }
    
    private func applyEWMASmoothing(center: CGPoint, time: TimeInterval) -> CGPoint {
        guard let prevCenter = previousCenter else {
            previousCenter = center
            previousTime = time
            return center
        }
        
        // EWMA smoothing
        let alpha = config.ewmaSmoothingFactor
        let smoothed = CGPoint(
            x: alpha * center.x + (1 - alpha) * prevCenter.x,
            y: alpha * center.y + (1 - alpha) * prevCenter.y
        )
        
        previousCenter = smoothed
        previousTime = time
        
        return smoothed
    }
    
    private func shouldStartNewSpring(to newTarget: CGPoint) -> Bool {
        guard let currentTarget = targetCenter else { return true }
        
        let distance = hypot(newTarget.x - currentTarget.x, newTarget.y - currentTarget.y)
        return distance > config.followMovementThreshold
    }
    
    private func startNewSpring(from: CGPoint, to: CGPoint, at time: TimeInterval) {
        springStartCenter = from
        targetCenter = to
        springStartTime = time
        // Keep current velocity for smooth interruption
    }
    
    private func applyBoundaryConstraints(center: CGPoint, scale: CGFloat) -> CGPoint {
        guard scale > 1.0 else { return center }
        
        let halfWidth = (1.0 / scale) / 2
        let halfHeight = (1.0 / scale) / 2
        
        return CGPoint(
            x: max(halfWidth, min(1.0 - halfWidth, center.x)),
            y: max(halfHeight, min(1.0 - halfHeight, center.y))
        )
    }
}
