import Foundation

/// Calculates smooth focus following for auto zoom
final class FocusFollower {
    
    // MARK: - Configuration
    
    /// Edge margin (portion of visible area to keep cursor away from edges)
    let edgeMargin: CGFloat
    
    /// Smoothing factor for EWMA (0 = no smoothing, 1 = instant)
    let followSmoothing: CGFloat
    
    /// Lookahead factor for predictive panning
    let lookaheadFactor: CGFloat
    
    // MARK: - State
    
    private var previousCenter: CGPoint?
    private var previousTime: TimeInterval?
    
    // MARK: - Initialization
    
    init(
        edgeMargin: CGFloat = 0.15,
        followSmoothing: CGFloat = 0.2,
        lookaheadFactor: CGFloat = 0.1
    ) {
        self.edgeMargin = edgeMargin
        self.followSmoothing = followSmoothing
        self.lookaheadFactor = lookaheadFactor
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
        
        // 3. Apply cursor following
        let adjustedCenter = calculateAdjustedCenter(
            baseCenter: segmentState.center,
            cursorPosition: cursorPosition,
            cursorVelocity: cursorVelocity,
            scale: segmentState.scale
        )
        
        // 4. Apply smoothing
        let smoothedCenter = applySmoothing(center: adjustedCenter, time: time)
        
        // 5. Apply boundary constraints
        let constrainedCenter = applyBoundaryConstraints(
            center: smoothedCenter,
            scale: segmentState.scale
        )
        
        return FocusState(center: constrainedCenter, scale: segmentState.scale)
    }
    
    /// Reset follower state (call when starting new export)
    func reset() {
        previousCenter = nil
        previousTime = nil
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
        let effectiveMargin = edgeMargin * visibleWidth
        
        var center = baseCenter
        
        // 1. Apply lookahead based on velocity
        if lookaheadFactor > 0 {
            center.x += cursorVelocity.x * lookaheadFactor
            center.y += cursorVelocity.y * lookaheadFactor
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
    
    private func applySmoothing(center: CGPoint, time: TimeInterval) -> CGPoint {
        guard let prevCenter = previousCenter else {
            previousCenter = center
            previousTime = time
            return center
        }
        
        // EWMA smoothing
        let alpha = followSmoothing
        let smoothed = CGPoint(
            x: alpha * center.x + (1 - alpha) * prevCenter.x,
            y: alpha * center.y + (1 - alpha) * prevCenter.y
        )
        
        previousCenter = smoothed
        previousTime = time
        
        return smoothed
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
