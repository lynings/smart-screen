import Foundation
import CoreGraphics

/// Timeline containing all zoom segments for a recording
/// Provides efficient lookup of zoom state at any time
struct ZoomTimeline {
    
    // MARK: - Properties
    
    let segments: [AutoZoomSegment]
    let duration: TimeInterval
    
    /// Transition duration between non-overlapping segments (方案 A: 平滑过渡)
    let transitionDuration: TimeInterval
    
    // MARK: - Initialization
    
    init(
        segments: [AutoZoomSegment],
        duration: TimeInterval,
        transitionDuration: TimeInterval = 0.3
    ) {
        // Sort segments by start time
        self.segments = segments.sorted { $0.startTime < $1.startTime }
        self.duration = duration
        self.transitionDuration = transitionDuration
    }
    
    // MARK: - State Query
    
    /// Get zoom state at a specific time (static center mode)
    func state(at time: TimeInterval) -> ZoomState {
        state(at: time, cursorPosition: nil, followCursor: false, smoothing: 0.2, hasKeyboardActivity: false)
    }
    
    /// Get zoom state at a specific time with cursor following support (AC-FU-01, AC-FU-02)
    func state(
        at time: TimeInterval,
        cursorPosition: CGPoint?,
        followCursor: Bool,
        smoothing: Double,
        hasKeyboardActivity: Bool = false
    ) -> ZoomState {
        // If keyboard is active, force zoom out to normal size
        if hasKeyboardActivity {
            // Return idle state when typing (scale = 1.0)
            return ZoomState.idle
        }
        
        // 1. Check if we're in a transition between segments (within segment)
        if let transitionState = transitionState(
            at: time,
            cursorPosition: cursorPosition,
            followCursor: followCursor,
            smoothing: smoothing
        ) {
            return transitionState
        }
        
        // 2. Find active segment
        if let segment = activeSegment(at: time),
           let segmentState = segment.state(
               at: time,
               cursorPosition: cursorPosition,
               followCursor: followCursor,
               smoothing: smoothing
           ) {
            return ZoomState(
                scale: segmentState.scale,
                center: segmentState.center,
                isActive: true,
                phase: segmentState.phase
            )
        }
        
        // 3. Check if we're in a gap between segments (方案 A: 间隙过渡)
        if let gapState = gapTransitionState(
            at: time,
            cursorPosition: cursorPosition,
            followCursor: followCursor
        ) {
            return gapState
        }
        
        // 4. No active segment - return default state
        return ZoomState.idle
    }
    
    /// Handle transitions during gap between segments
    /// Creates smooth pan from previous segment to next segment
    private func gapTransitionState(
        at time: TimeInterval,
        cursorPosition: CGPoint?,
        followCursor: Bool
    ) -> ZoomState? {
        guard let prev = previousSegment(before: time),
              let next = nextSegment(after: time) else {
            return nil
        }
        
        let gap = next.startTime - prev.endTime
        
        // Only create transition if gap is short enough
        guard gap < transitionDuration * 2 else { return nil }
        
        let timeInGap = time - prev.endTime
        let progress = timeInGap / gap
        let easedProgress = EasingCurve.easeInOut.value(at: progress)
        
        // Get centers
        let prevCenter = prev.focusCenter
        let nextCenter: CGPoint
        if followCursor, let cursor = cursorPosition {
            nextCenter = cursor
        } else {
            nextCenter = next.focusCenter
        }
        
        // Interpolate center smoothly across gap
        let blendedCenter = CGPoint(
            x: prevCenter.x + CGFloat(easedProgress) * (nextCenter.x - prevCenter.x),
            y: prevCenter.y + CGFloat(easedProgress) * (nextCenter.y - prevCenter.y)
        )
        
        // Scale: stay at zoom level during gap (don't zoom out and in again)
        // Use maximum scale of both segments for consistency
        let maintainedScale = max(prev.zoomScale, next.zoomScale)
        
        return ZoomState(
            scale: maintainedScale,
            center: blendedCenter,
            isActive: true,
            phase: .hold  // Treat gap as extended hold
        )
    }
    
    // MARK: - Transition Handling (方案 A: segment 间平滑过渡)
    
    /// Check if we're in a transition between two segments
    /// If current segment is in zoom-out phase and next segment is about to start,
    /// create a smooth transition instead of abrupt jump
    private func transitionState(
        at time: TimeInterval,
        cursorPosition: CGPoint?,
        followCursor: Bool,
        smoothing: Double
    ) -> ZoomState? {
        // Find current and next segment
        guard let currentIndex = segments.firstIndex(where: { $0.contains(time: time) }),
              currentIndex + 1 < segments.count else {
            return nil
        }
        
        let current = segments[currentIndex]
        let next = segments[currentIndex + 1]
        
        // Check if current is in zoom-out phase and next is close
        guard let currentState = current.state(at: time, cursorPosition: cursorPosition, followCursor: followCursor, smoothing: smoothing),
              currentState.phase == .zoomOut else {
            return nil
        }
        
        // Calculate gap between segments
        let gap = next.startTime - current.endTime
        
        // If next segment starts soon (within transition threshold), create transition
        let timeToEnd = current.endTime - time
        let needsTransition = gap < transitionDuration && timeToEnd < transitionDuration
        
        guard needsTransition else { return nil }
        
        // Create smooth transition: blend center towards next segment
        let transitionProgress = 1.0 - (timeToEnd / transitionDuration)
        let easedProgress = EasingCurve.easeInOut.value(at: transitionProgress)
        
        // Get target center for next segment
        let nextCenter: CGPoint
        if followCursor, let cursor = cursorPosition {
            nextCenter = cursor
        } else {
            nextCenter = next.focusCenter
        }
        
        // Interpolate center
        let blendedCenter = CGPoint(
            x: currentState.center.x + CGFloat(easedProgress) * (nextCenter.x - currentState.center.x),
            y: currentState.center.y + CGFloat(easedProgress) * (nextCenter.y - currentState.center.y)
        )
        
        // Keep scale from current state (still in zoom-out phase)
        return ZoomState(
            scale: currentState.scale,
            center: blendedCenter,
            isActive: true,
            phase: .zoomOut
        )
    }
    
    /// Find the active segment at a given time
    func activeSegment(at time: TimeInterval) -> AutoZoomSegment? {
        // Binary search could be used for large segment counts
        // For typical use cases, linear search is fine
        segments.first { $0.contains(time: time) }
    }
    
    /// Find segment that just ended (for gap transition)
    func previousSegment(before time: TimeInterval) -> AutoZoomSegment? {
        segments.last { $0.endTime <= time }
    }
    
    /// Find segment that is about to start (for gap transition)
    func nextSegment(after time: TimeInterval) -> AutoZoomSegment? {
        segments.first { $0.startTime > time }
    }
    
    /// Check if zoom is active at a given time
    func isZoomActive(at time: TimeInterval) -> Bool {
        activeSegment(at: time) != nil
    }
    
    // MARK: - Statistics
    
    var segmentCount: Int { segments.count }
    
    var totalZoomTime: TimeInterval {
        segments.reduce(0) { $0 + $1.duration }
    }
    
    var zoomPercentage: Double {
        guard duration > 0 else { return 0 }
        return totalZoomTime / duration * 100
    }
}

// MARK: - Zoom State

extension ZoomTimeline {
    
    /// Current zoom state
    struct ZoomState: Equatable {
        let scale: CGFloat
        let center: CGPoint
        let isActive: Bool
        let phase: AutoZoomSegment.ZoomState.Phase?
        
        static let idle = ZoomState(
            scale: 1.0,
            center: CGPoint(x: 0.5, y: 0.5),
            isActive: false,
            phase: nil
        )
    }
}

// MARK: - Factory

extension ZoomTimeline {
    
    /// Create an empty timeline (no zoom)
    static func empty(duration: TimeInterval) -> ZoomTimeline {
        ZoomTimeline(segments: [], duration: duration, transitionDuration: 0.3)
    }
    
    /// Create timeline from a cursor session
    static func from(
        session: CursorTrackSession,
        screenSize: CGSize,
        config: ZoomSegmentGenerator.Config = .default,
        transitionDuration: TimeInterval = 0.3
    ) -> ZoomTimeline {
        let generator = ZoomSegmentGenerator(config: config)
        let segments = generator.generate(from: session, screenSize: screenSize)
        return ZoomTimeline(
            segments: segments,
            duration: session.duration,
            transitionDuration: transitionDuration
        )
    }
}
