import Foundation

/// State machine that manages zoom state transitions
/// Ensures smooth, continuous zoom behavior without conflicts
final class ZoomStateMachine {
    
    // MARK: - Configuration
    
    struct Config {
        /// Duration of zoom in animation
        let zoomInDuration: TimeInterval
        
        /// Duration of zoom out animation
        let zoomOutDuration: TimeInterval
        
        /// Base hold time before zoom out starts
        let baseHoldTime: TimeInterval
        
        /// Minimum time between activity to consider as "continuous"
        let activityContinuityThreshold: TimeInterval
        
        /// Cooldown period after zoom out before new zoom can start
        let cooldownPeriod: TimeInterval
        
        /// Edge safety margin (portion of visible area to keep cursor away from edges)
        let edgeSafetyMargin: CGFloat
        
        /// Distance threshold (normalized) to trigger large movement handling
        let largeMovementThreshold: CGFloat
        
        /// Pan duration for moving between positions
        let panDuration: TimeInterval
        
        /// Center follow smoothing factor (0-1, higher = faster follow)
        let centerFollowFactor: CGFloat
        
        /// Easing curve for animations
        let easing: EasingCurve
        
        static let `default` = Config(
            zoomInDuration: 0.4,
            zoomOutDuration: 0.5,
            baseHoldTime: 1.5,
            activityContinuityThreshold: 0.8,
            cooldownPeriod: 0.5,
            edgeSafetyMargin: 0.15,
            largeMovementThreshold: 0.25,
            panDuration: 0.3,
            centerFollowFactor: 0.4,
            easing: .easeInOut
        )
        
        init(from settings: AutoZoomSettings) {
            self.zoomInDuration = settings.duration
            self.zoomOutDuration = settings.duration * 1.2
            self.baseHoldTime = settings.holdTime
            self.activityContinuityThreshold = 0.8
            self.cooldownPeriod = 0.5
            self.edgeSafetyMargin = 0.15
            self.largeMovementThreshold = 0.25
            self.panDuration = 0.3
            self.centerFollowFactor = 0.4
            self.easing = settings.easing
        }
        
        init(
            zoomInDuration: TimeInterval = 0.4,
            zoomOutDuration: TimeInterval = 0.5,
            baseHoldTime: TimeInterval = 1.5,
            activityContinuityThreshold: TimeInterval = 0.8,
            cooldownPeriod: TimeInterval = 0.5,
            edgeSafetyMargin: CGFloat = 0.15,
            largeMovementThreshold: CGFloat = 0.25,
            panDuration: TimeInterval = 0.3,
            centerFollowFactor: CGFloat = 0.4,
            easing: EasingCurve = .easeInOut
        ) {
            self.zoomInDuration = zoomInDuration
            self.zoomOutDuration = zoomOutDuration
            self.baseHoldTime = baseHoldTime
            self.activityContinuityThreshold = activityContinuityThreshold
            self.cooldownPeriod = cooldownPeriod
            self.edgeSafetyMargin = edgeSafetyMargin
            self.largeMovementThreshold = largeMovementThreshold
            self.panDuration = panDuration
            self.centerFollowFactor = centerFollowFactor
            self.easing = easing
        }
    }
    
    // MARK: - Properties
    
    let config: Config
    private var state: ZoomState = .idle
    private var currentCenter: CGPoint = CGPoint(x: 0.5, y: 0.5)
    private var targetCenter: CGPoint = CGPoint(x: 0.5, y: 0.5)
    private var panStartCenter: CGPoint = CGPoint(x: 0.5, y: 0.5)
    private var lastActivityTime: TimeInterval = 0
    private var lastZoomOutCompleteTime: TimeInterval = -1000
    private var currentScale: CGFloat = 1.0
    private var pendingZoomInScale: CGFloat? = nil
    
    // MARK: - Initialization
    
    init(config: Config = .default) {
        self.config = config
    }
    
    // MARK: - State Machine
    
    /// Process an event and return the new state
    @discardableResult
    func process(event: ZoomEvent, at time: TimeInterval) -> ZoomState {
        switch (state, event) {
            
        // MARK: From IDLE
        case (.idle, .activityDetected(let position, let suggestedScale)):
            // Check cooldown period
            guard time - lastZoomOutCompleteTime >= config.cooldownPeriod else {
                break
            }
            
            targetCenter = calculateSafeCenter(cursorPosition: position, scale: suggestedScale)
            currentCenter = targetCenter
            currentScale = 1.0
            lastActivityTime = time
            state = .zoomingIn(
                startScale: 1.0,
                targetScale: suggestedScale,
                startTime: time,
                duration: config.zoomInDuration
            )
            
        case (.idle, .largeMovement(_, let to, _, let suggestedScale)):
            // Check cooldown period
            guard time - lastZoomOutCompleteTime >= config.cooldownPeriod else {
                break
            }
            
            targetCenter = calculateSafeCenter(cursorPosition: to, scale: suggestedScale)
            currentCenter = targetCenter
            currentScale = 1.0
            lastActivityTime = time
            state = .zoomingIn(
                startScale: 1.0,
                targetScale: suggestedScale,
                startTime: time,
                duration: config.zoomInDuration
            )
            
        case (.idle, _):
            break // Stay idle
            
        // MARK: From ZOOMING_IN
        case (.zoomingIn(_, let targetScale, _, _), .zoomInComplete):
            currentScale = targetScale
            let holdEndTime = time + config.baseHoldTime
            state = .zoomed(scale: targetScale, holdStartTime: time, holdEndTime: holdEndTime)
            
        case (.zoomingIn(let startScale, let targetScale, let startTime, let duration), .activityDetected(let position, let newScale)):
            // Update center directly to cursor position
            let currentProgress = min((time - startTime) / duration, 1.0)
            let progressScale = startScale + (targetScale - startScale) * CGFloat(currentProgress)
            let newTargetScale = max(targetScale, newScale)
            
            currentScale = progressScale
            targetCenter = calculateSafeCenter(cursorPosition: position, scale: newTargetScale)
            currentCenter = targetCenter  // Direct update - cursor at center
            lastActivityTime = time
            
            state = .zoomingIn(
                startScale: progressScale,
                targetScale: newTargetScale,
                startTime: time,
                duration: config.zoomInDuration * (1.0 - currentProgress) + 0.1
            )
            
        case (.zoomingIn(let startScale, let targetScale, let startTime, let duration), .largeMovement(_, let to, let distance, let suggestedScale)):
            // Large movement during zoom in: zoom out first, then pan to new position
            let currentProgress = min((time - startTime) / duration, 1.0)
            let progressScale = startScale + (targetScale - startScale) * CGFloat(currentProgress)
            
            // Only switch to zoom out if movement is significant enough
            if distance > config.largeMovementThreshold * 0.5 {
                currentScale = progressScale
                pendingZoomInScale = suggestedScale
                targetCenter = calculateSafeCenter(cursorPosition: to, scale: suggestedScale)
                lastActivityTime = time
                
                state = .zoomingOut(
                    startScale: progressScale,
                    startTime: time,
                    duration: config.zoomOutDuration * 0.7
                )
            }
            
        case (.zoomingIn(_, _, let startTime, let duration), _):
            // Auto-transition to zoomed when time exceeds duration
            if time >= startTime + duration {
                process(event: .zoomInComplete, at: time)
            }
            
        // MARK: From ZOOMED
        case (.zoomed(let scale, let holdStartTime, _), .activityDetected(let position, let newScale)):
            // Extend hold time and update center directly to cursor position
            let newTargetScale = max(scale, newScale)
            targetCenter = calculateSafeCenter(cursorPosition: position, scale: newTargetScale)
            currentCenter = targetCenter  // Direct update - cursor at center
            currentScale = newTargetScale
            lastActivityTime = time
            let newHoldEndTime = time + config.baseHoldTime
            state = .zoomed(scale: newTargetScale, holdStartTime: holdStartTime, holdEndTime: newHoldEndTime)
            
        case (.zoomed(let scale, _, _), .activityContinues(let position)):
            // Update center directly to follow cursor
            targetCenter = calculateSafeCenter(cursorPosition: position, scale: scale)
            currentCenter = targetCenter  // Direct update - cursor at center
            lastActivityTime = time
            let newHoldEndTime = time + config.baseHoldTime * 0.5
            state = .zoomed(scale: scale, holdStartTime: lastActivityTime, holdEndTime: newHoldEndTime)
            
        case (.zoomed(let scale, _, _), .largeMovement(_, let to, _, let suggestedScale)):
            // Large movement: zoom out → pan → zoom in
            pendingZoomInScale = suggestedScale
            targetCenter = calculateSafeCenter(cursorPosition: to, scale: suggestedScale)
            lastActivityTime = time
            
            state = .zoomingOut(
                startScale: scale,
                startTime: time,
                duration: config.zoomOutDuration
            )
            
        case (.zoomed(let scale, _, _), .holdExpired):
            pendingZoomInScale = nil
            state = .zoomingOut(
                startScale: scale,
                startTime: time,
                duration: config.zoomOutDuration
            )
            
        case (.zoomed(_, _, let holdEndTime), .noActivity):
            if time >= holdEndTime {
                process(event: .holdExpired, at: time)
            }
            
        case (.zoomed, _):
            break
            
        // MARK: From ZOOMING_OUT
        case (.zoomingOut(let startScale, let startTime, let duration), .activityDetected(let position, let suggestedScale)):
            let currentProgress = min((time - startTime) / duration, 1.0)
            
            // Don't interrupt if we're more than halfway through zoom out
            guard currentProgress < 0.5 else {
                // Update target for after zoom out completes
                pendingZoomInScale = suggestedScale
                targetCenter = calculateSafeCenter(cursorPosition: position, scale: suggestedScale)
                break
            }
            
            let progressScale = startScale - (startScale - 1.0) * CGFloat(currentProgress)
            currentScale = progressScale
            targetCenter = calculateSafeCenter(cursorPosition: position, scale: suggestedScale)
            currentCenter = targetCenter
            lastActivityTime = time
            
            state = .zoomingIn(
                startScale: progressScale,
                targetScale: suggestedScale,
                startTime: time,
                duration: config.zoomInDuration
            )
            
        case (.zoomingOut(let startScale, let startTime, let duration), .largeMovement(_, let to, _, let suggestedScale)):
            // Update target position for after zoom out completes
            pendingZoomInScale = suggestedScale
            targetCenter = calculateSafeCenter(cursorPosition: to, scale: suggestedScale)
            
            // Update current center smoothly during zoom out
            let currentProgress = min((time - startTime) / duration, 1.0)
            currentScale = startScale - (startScale - 1.0) * CGFloat(currentProgress)
            currentCenter = smoothCenter(from: currentCenter, to: targetCenter)
            
        case (.zoomingOut, .zoomOutComplete):
            currentScale = 1.0
            lastZoomOutCompleteTime = time
            
            // Check if we have a pending zoom in target
            if let pendingScale = pendingZoomInScale {
                pendingZoomInScale = nil
                // Start panning to target position
                panStartCenter = currentCenter
                state = .panning(
                    targetPosition: targetCenter,
                    targetScale: pendingScale,
                    startTime: time
                )
            } else {
                state = .idle
            }
            
        case (.zoomingOut(_, let startTime, let duration), _):
            // Auto-transition when time exceeds duration
            if time >= startTime + duration {
                // Update center during zoom out
                let progress = config.easing.value(at: 1.0)
                currentCenter = CGPoint(
                    x: currentCenter.x + (targetCenter.x - currentCenter.x) * CGFloat(progress) * 0.5,
                    y: currentCenter.y + (targetCenter.y - currentCenter.y) * CGFloat(progress) * 0.5
                )
                currentScale = 1.0
                process(event: .zoomOutComplete, at: time)
            }
            
        // MARK: From PANNING
        case (.panning(let targetPos, let targetScale, _), .panComplete):
            currentCenter = targetPos
            lastActivityTime = time
            
            // Start zooming in at target position
            state = .zoomingIn(
                startScale: 1.0,
                targetScale: targetScale,
                startTime: time,
                duration: config.zoomInDuration
            )
            
        case (.panning(let targetPos, let targetScale, let startTime), .activityDetected(let position, let newScale)):
            // Update target
            let newTargetScale = max(targetScale, newScale)
            targetCenter = calculateSafeCenter(cursorPosition: position, scale: newTargetScale)
            
            // Check if we're close enough to start zoom in early
            let distanceToTarget = hypot(currentCenter.x - targetPos.x, currentCenter.y - targetPos.y)
            if distanceToTarget < 0.05 || time - startTime > config.panDuration {
                currentCenter = targetCenter
                state = .zoomingIn(
                    startScale: 1.0,
                    targetScale: newTargetScale,
                    startTime: time,
                    duration: config.zoomInDuration
                )
            } else {
                state = .panning(targetPosition: targetCenter, targetScale: newTargetScale, startTime: startTime)
            }
            
        case (.panning(_, let targetScale, let startTime), .largeMovement(_, let to, _, let suggestedScale)):
            // Update target position
            let newTargetScale = max(targetScale, suggestedScale)
            targetCenter = calculateSafeCenter(cursorPosition: to, scale: newTargetScale)
            state = .panning(targetPosition: targetCenter, targetScale: newTargetScale, startTime: startTime)
            
        case (.panning(let targetPos, _, let startTime), _):
            // Auto-transition to zoom in when pan duration exceeded or close enough
            let elapsed = time - startTime
            let progress = min(elapsed / config.panDuration, 1.0)
            let easedProgress = config.easing.value(at: progress)
            
            currentCenter = CGPoint(
                x: panStartCenter.x + (targetPos.x - panStartCenter.x) * CGFloat(easedProgress),
                y: panStartCenter.y + (targetPos.y - panStartCenter.y) * CGFloat(easedProgress)
            )
            
            if elapsed >= config.panDuration {
                process(event: .panComplete, at: time)
            }
        }
        
        return state
    }
    
    /// Get the zoom output at a specific time
    func output(at time: TimeInterval) -> ZoomOutput {
        switch state {
        case .idle:
            return ZoomOutput(scale: 1.0, center: currentCenter, isTransitioning: false)
            
        case .zoomingIn(let startScale, let targetScale, let startTime, let duration):
            let rawProgress = min(max((time - startTime) / duration, 0), 1.0)
            let progress = config.easing.value(at: rawProgress)
            let scale = startScale + (targetScale - startScale) * CGFloat(progress)
            return ZoomOutput(scale: scale, center: currentCenter, isTransitioning: true)
            
        case .zoomed(let scale, _, _):
            return ZoomOutput(scale: scale, center: currentCenter, isTransitioning: false)
            
        case .zoomingOut(let startScale, let startTime, let duration):
            let rawProgress = min(max((time - startTime) / duration, 0), 1.0)
            let progress = config.easing.value(at: rawProgress)
            let scale = startScale - (startScale - 1.0) * CGFloat(progress)
            
            // Smooth center movement during zoom out
            let centerProgress = CGFloat(progress)
            let centerX = currentCenter.x + (targetCenter.x - currentCenter.x) * centerProgress * 0.5
            let centerY = currentCenter.y + (targetCenter.y - currentCenter.y) * centerProgress * 0.5
            
            return ZoomOutput(scale: scale, center: CGPoint(x: centerX, y: centerY), isTransitioning: true)
            
        case .panning(let targetPos, _, let startTime):
            let rawProgress = min(max((time - startTime) / config.panDuration, 0), 1.0)
            let progress = config.easing.value(at: rawProgress)
            
            let centerX = panStartCenter.x + (targetPos.x - panStartCenter.x) * CGFloat(progress)
            let centerY = panStartCenter.y + (targetPos.y - panStartCenter.y) * CGFloat(progress)
            
            return ZoomOutput(scale: 1.0, center: CGPoint(x: centerX, y: centerY), isTransitioning: true)
        }
    }
    
    /// Reset state machine to idle
    func reset() {
        state = .idle
        currentCenter = CGPoint(x: 0.5, y: 0.5)
        targetCenter = CGPoint(x: 0.5, y: 0.5)
        panStartCenter = CGPoint(x: 0.5, y: 0.5)
        currentScale = 1.0
        lastActivityTime = 0
        lastZoomOutCompleteTime = -1000
        pendingZoomInScale = nil
    }
    
    /// Check if activity is considered continuous
    func isActivityContinuous(at time: TimeInterval) -> Bool {
        time - lastActivityTime < config.activityContinuityThreshold
    }
    
    /// Get current state (for testing)
    var currentState: ZoomState { state }
    
    // MARK: - Public Helpers (for testing)
    
    /// Calculate center position that places cursor at the center of view
    /// Only applies boundary constraints to prevent view from going out of bounds
    func calculateSafeCenter(cursorPosition: CGPoint, scale: CGFloat) -> CGPoint {
        guard scale > 1.0 else { return cursorPosition }
        
        // Calculate visible area dimensions (normalized)
        let visibleWidth = 1.0 / scale
        let visibleHeight = 1.0 / scale
        
        // Calculate half dimensions
        let halfWidth = visibleWidth / 2
        let halfHeight = visibleHeight / 2
        
        // Use cursor position directly as center
        var centerX = cursorPosition.x
        var centerY = cursorPosition.y
        
        // Only apply boundary constraints to keep visible rect in bounds
        // This ensures the cursor is at the center of the zoomed view
        centerX = max(halfWidth, min(1.0 - halfWidth, centerX))
        centerY = max(halfHeight, min(1.0 - halfHeight, centerY))
        
        return CGPoint(x: centerX, y: centerY)
    }
    
    // MARK: - Private Helpers
    
    /// Direct center update (no smoothing for immediate response)
    private func smoothCenter(from: CGPoint, to: CGPoint) -> CGPoint {
        // Use high factor for fast response - cursor should be at center
        let factor: CGFloat = 0.8
        return CGPoint(
            x: from.x + (to.x - from.x) * factor,
            y: from.y + (to.y - from.y) * factor
        )
    }
}
