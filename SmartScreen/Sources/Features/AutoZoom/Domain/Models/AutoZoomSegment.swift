import Foundation
import CoreGraphics

/// A zoom segment representing a period of zoomed view
/// Generated from click events, with defined time range and focus
struct AutoZoomSegment: Equatable, Identifiable {
    let id: UUID
    let timeRange: ClosedRange<TimeInterval>
    let focusCenter: CGPoint  // Normalized (0-1)
    let zoomScale: CGFloat
    let easing: EasingCurve
    
    // MARK: - Computed Properties
    
    var duration: TimeInterval {
        timeRange.upperBound - timeRange.lowerBound
    }
    
    var startTime: TimeInterval {
        timeRange.lowerBound
    }
    
    var endTime: TimeInterval {
        timeRange.upperBound
    }
    
    // MARK: - Animation Phases
    
    /// Phase durations (15% zoom in, 70% hold, 15% zoom out)
    /// Optimized to reduce frequent zoom transitions during rapid clicking
    var zoomInDuration: TimeInterval { duration * 0.15 }
    var holdDuration: TimeInterval { duration * 0.70 }
    var zoomOutDuration: TimeInterval { duration * 0.15 }
    
    var zoomInEndTime: TimeInterval { startTime + zoomInDuration }
    var holdEndTime: TimeInterval { zoomInEndTime + holdDuration }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        timeRange: ClosedRange<TimeInterval>,
        focusCenter: CGPoint,
        zoomScale: CGFloat = 2.0,
        easing: EasingCurve = .easeInOut
    ) {
        self.id = id
        self.timeRange = timeRange
        self.focusCenter = focusCenter
        self.zoomScale = zoomScale
        self.easing = easing
    }
    
    // MARK: - State at Time
    
    /// Get zoom state at a specific time (static center mode)
    func state(at time: TimeInterval) -> ZoomState? {
        state(at: time, cursorPosition: nil, followCursor: false, smoothing: 0.2)
    }
    
    /// Get zoom state at a specific time with optional cursor following (AC-FU-01, AC-FU-02)
    func state(
        at time: TimeInterval,
        cursorPosition: CGPoint?,
        followCursor: Bool,
        smoothing: Double
    ) -> ZoomState? {
        guard timeRange.contains(time) else { return nil }
        
        let relativeTime = time - startTime
        
        // Determine center based on follow mode
        let center: CGPoint
        if followCursor, let cursor = cursorPosition {
            // AC-FU-02: Follow cursor with boundary constraints (AC-FU-03)
            center = constrainedCenter(for: cursor, at: zoomScale)
        } else {
            // AC-FU-01: Static center at initial click position
            center = focusCenter
        }
        
        if relativeTime < zoomInDuration {
            // Zoom In phase
            let progress = relativeTime / zoomInDuration
            let easedProgress = easing.value(at: progress)
            let scale = 1.0 + (zoomScale - 1.0) * CGFloat(easedProgress)
            return ZoomState(scale: scale, center: center, phase: .zoomIn)
            
        } else if relativeTime < zoomInDuration + holdDuration {
            // Hold phase
            return ZoomState(scale: zoomScale, center: center, phase: .hold)
            
        } else {
            // Zoom Out phase
            let zoomOutStart = zoomInDuration + holdDuration
            let progress = (relativeTime - zoomOutStart) / zoomOutDuration
            let easedProgress = easing.value(at: progress)
            let scale = zoomScale - (zoomScale - 1.0) * CGFloat(easedProgress)
            return ZoomState(scale: scale, center: center, phase: .zoomOut)
        }
    }
    
    /// Constrain center to keep visible area in bounds (AC-FU-03)
    private func constrainedCenter(for cursor: CGPoint, at scale: CGFloat) -> CGPoint {
        guard scale > 1.0 else { return cursor }
        
        let visibleWidth = 1.0 / scale
        let visibleHeight = 1.0 / scale
        let halfWidth = visibleWidth / 2
        let halfHeight = visibleHeight / 2
        
        let constrainedX = max(halfWidth, min(1.0 - halfWidth, cursor.x))
        let constrainedY = max(halfHeight, min(1.0 - halfHeight, cursor.y))
        
        return CGPoint(x: constrainedX, y: constrainedY)
    }
    
    /// Check if this segment contains a time
    func contains(time: TimeInterval) -> Bool {
        timeRange.contains(time)
    }
}

// MARK: - Zoom State

extension AutoZoomSegment {
    
    /// Current zoom state at a point in time
    struct ZoomState: Equatable {
        let scale: CGFloat
        let center: CGPoint
        let phase: Phase
        
        enum Phase {
            case zoomIn
            case hold
            case zoomOut
        }
    }
}

// MARK: - Factory Methods

extension AutoZoomSegment {
    
    /// Create a segment centered on a click event
    static func fromClick(
        _ click: ClickEvent,
        duration: TimeInterval = 1.2,
        zoomScale: CGFloat = 2.0,
        easing: EasingCurve = .easeInOut
    ) -> AutoZoomSegment {
        let halfDuration = duration / 2
        let startTime = max(0, click.timestamp - halfDuration)
        let endTime = click.timestamp + halfDuration
        
        return AutoZoomSegment(
            timeRange: startTime...endTime,
            focusCenter: click.position,
            zoomScale: zoomScale,
            easing: easing
        )
    }
    
    /// Create a segment from multiple clicks (merged)
    static func fromClicks(
        _ clicks: [ClickEvent],
        duration: TimeInterval = 1.2,
        zoomScale: CGFloat = 2.0,
        easing: EasingCurve = .easeInOut
    ) -> AutoZoomSegment {
        guard !clicks.isEmpty else {
            fatalError("Cannot create segment from empty clicks")
        }
        
        // Calculate centroid
        let centroid = CGPoint(
            x: clicks.map(\.position.x).reduce(0, +) / CGFloat(clicks.count),
            y: clicks.map(\.position.y).reduce(0, +) / CGFloat(clicks.count)
        )
        
        // Calculate time range covering all clicks
        let minTime = clicks.map(\.timestamp).min()!
        let maxTime = clicks.map(\.timestamp).max()!
        let halfDuration = duration / 2
        
        let startTime = max(0, minTime - halfDuration)
        let endTime = maxTime + halfDuration
        
        // Ensure minimum duration
        let actualEndTime = max(endTime, startTime + 0.6)
        
        return AutoZoomSegment(
            timeRange: startTime...actualEndTime,
            focusCenter: centroid,
            zoomScale: zoomScale,
            easing: easing
        )
    }
}

// MARK: - Merge Support

extension AutoZoomSegment {
    
    /// Check if this segment can merge with another
    func canMerge(with other: AutoZoomSegment, maxGap: TimeInterval = 0.3, maxDistance: CGFloat = 0.05) -> Bool {
        // Check time gap
        let gap = other.startTime - self.endTime
        guard gap >= 0 && gap < maxGap else { return false }
        
        // Check distance
        let distance = hypot(focusCenter.x - other.focusCenter.x, focusCenter.y - other.focusCenter.y)
        return distance < maxDistance
    }
    
    /// Merge with another segment
    func merged(with other: AutoZoomSegment) -> AutoZoomSegment {
        let newStartTime = min(startTime, other.startTime)
        let newEndTime = max(endTime, other.endTime)
        let newCenter = CGPoint(
            x: (focusCenter.x + other.focusCenter.x) / 2,
            y: (focusCenter.y + other.focusCenter.y) / 2
        )
        let newScale = max(zoomScale, other.zoomScale)
        
        return AutoZoomSegment(
            timeRange: newStartTime...newEndTime,
            focusCenter: newCenter,
            zoomScale: newScale,
            easing: easing
        )
    }
}
