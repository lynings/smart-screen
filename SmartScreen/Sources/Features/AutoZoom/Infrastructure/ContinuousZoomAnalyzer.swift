import Foundation

/// Analyzes cursor activity and generates a continuous zoom timeline
/// Uses state machine to ensure smooth transitions without conflicts
final class ContinuousZoomAnalyzer {
    
    // MARK: - Configuration
    
    /// Interval for timeline sampling
    private let sampleInterval: TimeInterval = 0.033 // ~30fps
    
    /// Minimum activity intensity to trigger zoom
    private let activityThreshold: Double = 5.0
    
    /// Minimum time with no activity before considering "no activity"
    private let noActivityThreshold: TimeInterval = 0.5
    
    /// Maximum velocity (normalized per second) to trigger zoom for non-click events
    private let maxVelocityForZoomTrigger: CGFloat = 0.3
    
    /// Minimum area ratio for activity cluster trigger (smaller = more focused activity)
    private let maxAreaRatioForTrigger: CGFloat = 0.08
    
    /// Time window to look back for movement detection
    private let movementDetectionWindow: TimeInterval = 0.15
    
    // MARK: - Dependencies
    
    private let activityAnalyzer = ActivityAnalyzer()
    
    // MARK: - State for movement tracking
    
    private var previousPosition: CGPoint?
    private var previousTime: TimeInterval = 0
    
    // MARK: - Analysis
    
    /// Analyze a cursor track session and generate continuous zoom timeline
    func analyze(
        session: CursorTrackSession,
        settings: AutoZoomSettings
    ) -> ContinuousZoomTimeline {
        guard settings.isEnabled else {
            return ContinuousZoomTimeline(keyframes: [.idle(at: 0)])
        }
        guard !session.events.isEmpty else {
            return ContinuousZoomTimeline(keyframes: [.idle(at: 0)])
        }
        
        // Reset state
        previousPosition = nil
        previousTime = 0
        
        // 1. Analyze activity windows
        let activityWindows = activityAnalyzer.analyze(session: session)
        
        // 2. Build click lookup for quick access
        let clicks = session.clickEvents.sorted { $0.timestamp < $1.timestamp }
        
        // 3. Initialize state machine
        let config = ZoomStateMachine.Config(from: settings)
        let stateMachine = ZoomStateMachine(config: config)
        
        // 4. Generate timeline by sampling
        var keyframes: [ZoomKeyframe] = []
        var time: TimeInterval = 0
        var lastKeyframe: ZoomKeyframe?
        
        while time <= session.duration {
            // Check for activity at this time
            let event = determineEvent(
                at: time,
                activityWindows: activityWindows,
                clicks: clicks,
                session: session,
                settings: settings,
                stateMachine: stateMachine
            )
            
            // Process event through state machine
            stateMachine.process(event: event, at: time)
            
            // Get output
            let output = stateMachine.output(at: time)
            
            // Create keyframe if significant change or at regular interval
            let keyframe = ZoomKeyframe(
                time: time,
                scale: output.scale,
                center: output.center,
                easing: settings.easing
            )
            
            if shouldAddKeyframe(keyframe, lastKeyframe: lastKeyframe, isTransitioning: output.isTransitioning) {
                keyframes.append(keyframe)
                lastKeyframe = keyframe
            }
            
            time += sampleInterval
        }
        
        // Ensure we have endpoint
        if let last = keyframes.last, last.time < session.duration {
            keyframes.append(ZoomKeyframe(
                time: session.duration,
                scale: 1.0,
                center: last.center,
                easing: settings.easing
            ))
        }
        
        return ContinuousZoomTimeline(keyframes: keyframes)
    }
    
    // MARK: - Event Detection
    
    private func determineEvent(
        at time: TimeInterval,
        activityWindows: [ActivityWindow],
        clicks: [ClickEvent],
        session: CursorTrackSession,
        settings: AutoZoomSettings,
        stateMachine: ZoomStateMachine
    ) -> ZoomEvent {
        // Get current cursor position
        let currentPosition = session.positionAt(time: time)
        
        // Track movement for large movement detection
        defer {
            if let pos = currentPosition {
                previousPosition = pos
                previousTime = time
            }
        }
        
        // 1. Check for click at this time (highest priority - always triggers)
        if let click = findClick(at: time, in: clicks) {
            let window = findWindow(at: time, in: activityWindows)
            let suggestedScale = min(window?.suggestedZoomLevel ?? settings.zoomLevel, settings.zoomLevel)
            
            // Check if this is a large movement click (clicking far from current center)
            if let prevPos = previousPosition,
               stateMachine.currentState.isActive {
                let distance = hypot(click.position.x - prevPos.x, click.position.y - prevPos.y)
                if distance > stateMachine.config.largeMovementThreshold {
                    return .largeMovement(
                        from: prevPos,
                        to: click.position,
                        distance: distance,
                        suggestedScale: suggestedScale
                    )
                }
            }
            
            return .activityDetected(position: click.position, suggestedScale: suggestedScale)
        }
        
        // 2. Check for large movement (while zoomed)
        if let currentPos = currentPosition,
           let prevPos = previousPosition,
           stateMachine.currentState.isActive {
            let timeDelta = time - previousTime
            if timeDelta > 0 && timeDelta < movementDetectionWindow * 2 {
                let distance = hypot(currentPos.x - prevPos.x, currentPos.y - prevPos.y)
                let velocity = distance / CGFloat(timeDelta)
                
                // Large and fast movement triggers zoom out → pan → zoom in
                if distance > stateMachine.config.largeMovementThreshold && velocity > 0.5 {
                    let window = findWindow(at: time, in: activityWindows)
                    let suggestedScale = min(window?.suggestedZoomLevel ?? settings.zoomLevel, settings.zoomLevel)
                    return .largeMovement(
                        from: prevPos,
                        to: currentPos,
                        distance: distance,
                        suggestedScale: suggestedScale
                    )
                }
            }
        }
        
        // 3. Check for significant activity window
        if let window = findWindow(at: time, in: activityWindows) {
            // Dwell detection (low velocity = user focusing on area)
            if window.isDwell {
                return .activityDetected(
                    position: window.centroid,
                    suggestedScale: window.suggestedZoomLevel
                )
            }
            
            // High activity in very small area with low velocity
            if window.isHighActivity &&
               window.areaRatio < maxAreaRatioForTrigger &&
               window.averageVelocity < maxVelocityForZoomTrigger {
                return .activityDetected(
                    position: window.centroid,
                    suggestedScale: window.suggestedZoomLevel
                )
            }
        }
        
        // 4. Continue following cursor if already zoomed
        if stateMachine.currentState.isActive, let position = currentPosition {
            return .activityContinues(position: position)
        }
        
        // 5. No significant activity
        return .noActivity
    }
    
    private func findClick(at time: TimeInterval, in clicks: [ClickEvent]) -> ClickEvent? {
        // Look for click within small time window
        let tolerance: TimeInterval = 0.05
        return clicks.first { abs($0.timestamp - time) < tolerance }
    }
    
    private func findWindow(at time: TimeInterval, in windows: [ActivityWindow]) -> ActivityWindow? {
        windows.first { $0.timeRange.contains(time) }
    }
    
    // MARK: - Keyframe Optimization
    
    private func shouldAddKeyframe(
        _ keyframe: ZoomKeyframe,
        lastKeyframe: ZoomKeyframe?,
        isTransitioning: Bool
    ) -> Bool {
        guard let last = lastKeyframe else { return true }
        
        // Always add during transitions
        if isTransitioning { return true }
        
        // Add if scale changed significantly
        let scaleChange = abs(keyframe.scale - last.scale)
        if scaleChange > 0.01 { return true }
        
        // Add if center moved significantly while zoomed
        if keyframe.scale > 1.05 {
            let centerDistance = hypot(
                keyframe.center.x - last.center.x,
                keyframe.center.y - last.center.y
            )
            if centerDistance > 0.02 { return true }
        }
        
        // Add at regular intervals when zoomed
        if keyframe.scale > 1.0 && keyframe.time - last.time > 0.1 {
            return true
        }
        
        return false
    }
}

// MARK: - Supporting Types

// Note: ZoomKeyframe and ContinuousZoomTimeline are defined in
// Domain/Models/ZoomKeyframe.swift and Domain/Models/ContinuousZoomTimeline.swift
