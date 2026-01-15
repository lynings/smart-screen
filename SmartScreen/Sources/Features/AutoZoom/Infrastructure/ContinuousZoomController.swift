import Foundation
import CoreGraphics

/// Configuration for continuous zoom behavior
struct ContinuousZoomConfig {
    /// Base zoom scale
    let baseZoomScale: CGFloat
    
    /// Duration for zoom in animation (Ease In phase)
    let zoomInDuration: TimeInterval
    
    /// Minimum hold duration (seconds) - shortest time before allowing interruption
    let holdMin: TimeInterval
    
    /// Base hold duration (seconds) - initial duration for Hold phase
    let holdBase: TimeInterval
    
    /// Maximum hold duration (seconds) - cap for extended holds
    let holdMax: TimeInterval
    
    /// Duration to extend Hold per repeated event in same region
    let holdExtensionPerEvent: TimeInterval
    
    /// Duration for holding at zoom position (Hold phase) - DEPRECATED, use holdBase
    @available(*, deprecated, message: "Use holdBase instead")
    var holdDuration: TimeInterval { holdBase }
    
    /// Duration for zoom out animation (Ease Out phase)
    let zoomOutDuration: TimeInterval
    
    /// Duration for pan/transition animation
    let panDuration: TimeInterval
    
    /// Idle timeout before auto zoom-out (seconds)
    let idleTimeout: TimeInterval
    
    /// Distance threshold for "large distance" (normalized)
    /// Beyond this, zoom out first then pan
    let largeDistanceThreshold: CGFloat
    
    /// Active session timeout: if clicks are within this interval, treat as same session
    /// During active session, use direct pan instead of zoom out → zoom in
    /// Default: 1.0s (rapid clicks within 1 second)
    let activeSessionTimeout: TimeInterval
    
    /// Area threshold for debounce (ratio of screen area)
    let debounceAreaThreshold: CGFloat
    
    /// Time window for debounce detection
    let debounceTimeWindow: TimeInterval
    
    /// Easing curve for animations
    let easing: EasingCurve

    /// Time threshold for merging rapid consecutive clicks (seconds)
    let clickMergeTime: TimeInterval

    /// Distance threshold for merging rapid consecutive clicks (pixels in reference space)
    let clickMergeDistancePixels: CGFloat

    /// Interval for generating follow keyframes while zoomed (seconds)
    let followKeyframeInterval: TimeInterval

    /// One-Euro filter configuration for cursor smoothing (follow mode)
    let oneEuroMinCutoff: Double
    let oneEuroBeta: Double
    let oneEuroDCutoff: Double

    /// RDP epsilon in normalized coordinates for follow path simplification
    let rdpEpsilon: CGFloat

    /// Maximum time gap allowed between follow keyframes after simplification
    let followMaxKeyframeGap: TimeInterval
    
    static let `default` = ContinuousZoomConfig(
        baseZoomScale: 2.0,
        zoomInDuration: 0.3,
        holdMin: 0.35,
        holdBase: 0.6,
        holdMax: 1.5,
        holdExtensionPerEvent: 0.4,
        zoomOutDuration: 0.4,
        panDuration: 0.3,
        idleTimeout: 3.0,
        largeDistanceThreshold: 0.3,
        activeSessionTimeout: 1.0,
        debounceAreaThreshold: 0.15,
        debounceTimeWindow: 0.5,
        easing: .easeInOut,
        clickMergeTime: 0.35,
        clickMergeDistancePixels: 120,
        followKeyframeInterval: 1.0 / 15.0,
        oneEuroMinCutoff: 1.0,
        oneEuroBeta: 0.007,
        oneEuroDCutoff: 1.0,
        rdpEpsilon: 0.004,
        followMaxKeyframeGap: 0.4
    )

    init(
        baseZoomScale: CGFloat = 2.0,
        zoomInDuration: TimeInterval = 0.3,
        holdMin: TimeInterval = 0.35,
        holdBase: TimeInterval = 0.6,
        holdMax: TimeInterval = 1.5,
        holdExtensionPerEvent: TimeInterval = 0.4,
        zoomOutDuration: TimeInterval = 0.4,
        panDuration: TimeInterval = 0.3,
        idleTimeout: TimeInterval = 3.0,
        largeDistanceThreshold: CGFloat = 0.3,
        activeSessionTimeout: TimeInterval = 1.0,
        debounceAreaThreshold: CGFloat = 0.15,
        debounceTimeWindow: TimeInterval = 0.5,
        easing: EasingCurve = .easeInOut,
        clickMergeTime: TimeInterval = 0.35,
        clickMergeDistancePixels: CGFloat = 120,
        followKeyframeInterval: TimeInterval = 1.0 / 15.0,
        oneEuroMinCutoff: Double = 1.0,
        oneEuroBeta: Double = 0.007,
        oneEuroDCutoff: Double = 1.0,
        rdpEpsilon: CGFloat = 0.004,
        followMaxKeyframeGap: TimeInterval = 0.4
    ) {
        self.baseZoomScale = baseZoomScale
        self.zoomInDuration = zoomInDuration
        self.holdMin = holdMin
        self.holdBase = holdBase
        self.holdMax = holdMax
        self.holdExtensionPerEvent = holdExtensionPerEvent
        self.zoomOutDuration = zoomOutDuration
        self.panDuration = panDuration
        self.idleTimeout = idleTimeout
        self.largeDistanceThreshold = largeDistanceThreshold
        self.activeSessionTimeout = activeSessionTimeout
        self.debounceAreaThreshold = debounceAreaThreshold
        self.debounceTimeWindow = debounceTimeWindow
        self.easing = easing
        self.clickMergeTime = clickMergeTime
        self.clickMergeDistancePixels = clickMergeDistancePixels
        self.followKeyframeInterval = followKeyframeInterval
        self.oneEuroMinCutoff = oneEuroMinCutoff
        self.oneEuroBeta = oneEuroBeta
        self.oneEuroDCutoff = oneEuroDCutoff
        self.rdpEpsilon = rdpEpsilon
        self.followMaxKeyframeGap = followMaxKeyframeGap
    }
}

/// Zoom state for the controller
enum ZoomControlState: Equatable {
    case idle
    case zoomingIn(to: CGPoint)
    case zoomed(at: CGPoint)
    case following(at: CGPoint)
    case zoomingOut(from: CGPoint)
    case transitioning(from: CGPoint, to: CGPoint)
}

/// Merged click event with original event count for Hold duration calculation
struct MergedClick {
    let position: CGPoint
    let timestamp: TimeInterval
    let eventCount: Int  // Number of original clicks merged into this one
    let type: ClickType
    
    init(from click: ClickEvent, eventCount: Int = 1) {
        self.position = click.position
        self.timestamp = click.timestamp
        self.eventCount = eventCount
        self.type = click.type
    }
    
    init(from group: [ClickEvent]) {
        guard let first = group.first, !group.isEmpty else {
            self.position = .zero
            self.timestamp = 0
            self.eventCount = 0
            self.type = .leftClick
            return
        }
        
        if group.count == 1 {
            self.position = first.position
            self.timestamp = first.timestamp
            self.eventCount = 1
            self.type = first.type
        } else {
            let centroid = group
                .map(\.position)
                .reduce(CGPoint.zero) { partial, p in
                    CGPoint(x: partial.x + p.x, y: partial.y + p.y)
                }
            let count = CGFloat(group.count)
            self.position = CGPoint(x: centroid.x / count, y: centroid.y / count)
            self.timestamp = first.timestamp
            self.eventCount = group.count
            self.type = first.type
        }
    }
}

/// Generates a continuous zoom timeline from mouse and keyboard events
final class ContinuousZoomController {
    
    // MARK: - Properties
    
    private let config: ContinuousZoomConfig
    private let dynamicZoom: DynamicZoomCalculator
    
    // MARK: - Initialization
    
    init(config: ContinuousZoomConfig = .default) {
        self.config = config
        self.dynamicZoom = DynamicZoomCalculator(baseScale: config.baseZoomScale)
    }
    
    // MARK: - Timeline Generation
    
    /// Generate keyframes from cursor and keyboard events
    func generateKeyframes(
        from cursorSession: CursorTrackSession,
        keyboardEvents: [KeyboardEvent],
        referenceSize: CGSize = CGSize(width: 1920, height: 1080)
    ) -> [ZoomKeyframe] {
        var keyframes: [ZoomKeyframe] = [.idle(at: 0)]
        
        let clicks = cursorSession.clickEvents.sorted { $0.timestamp < $1.timestamp }
        guard !clicks.isEmpty else { return keyframes }

        let mergedClicks = mergeClicks(clicks, referenceSize: referenceSize)
        
        var currentState: ZoomControlState = .idle
        var lastZoomCenter: CGPoint?
        var lastActivityTime: TimeInterval = 0
        var currentHoldEndTime: TimeInterval = 0  // Track when current Hold phase ends
        var currentHoldStartTime: TimeInterval = 0  // Track when current Hold phase starts
        
        // Process each click event
        for (index, click) in mergedClicks.enumerated() {
            let clickTime = click.timestamp
            let clickPosition = click.position
            
            // 1. Check for keyboard activity - zoom out if typing
            if hasKeyboardActivity(at: clickTime, events: keyboardEvents) {
                if case .zoomed = currentState, let center = lastZoomCenter {
                    keyframes.append(contentsOf: generateZoomOut(
                        from: center,
                        startTime: clickTime - 0.1,
                        duration: config.zoomOutDuration
                    ))
                    currentState = .idle
                    lastZoomCenter = nil
                }
                continue
            }
            
            // 2. Check for idle timeout - zoom out if no activity for 3 seconds
            // Consider keyboard activity as activity to prevent premature zoom out
            // Look at ALL keyboard events, not just those before current click
            let lastKeyboardBeforeClick = keyboardEvents.filter { $0.timestamp <= clickTime }.last?.timestamp ?? 0
            let effectiveLastActivity = max(lastActivityTime, lastKeyboardBeforeClick)
            
            if clickTime - effectiveLastActivity > config.idleTimeout {
                if case .zoomed = currentState, let center = lastZoomCenter {
                    keyframes.append(contentsOf: generateZoomOut(
                        from: center,
                        startTime: effectiveLastActivity + config.idleTimeout,
                        duration: config.zoomOutDuration
                    ))
                    currentState = .idle
                    lastZoomCenter = nil
                }
            }
            
            // 3. Determine transition type based on current state
            switch currentState {
            case .idle:
                // Simply zoom in to click position
                let zoomScale = dynamicZoom.zoomScaleWithCornerBoost(at: clickPosition)
                let constrainedPosition = constrainCenter(clickPosition, at: zoomScale)
                
                // Calculate dynamic hold duration based on event count
                // baseHold + (eventCount - 1) * extensionPerEvent, capped at holdMax
                let baseHold = config.holdBase
                let holdExtension = TimeInterval(click.eventCount - 1) * config.holdExtensionPerEvent
                let uncappedHold = baseHold + holdExtension
                let calculatedHold: TimeInterval = min(uncappedHold, config.holdMax)
                let baseHoldEndTime = clickTime + config.zoomInDuration + calculatedHold
                
                // Apply keyboard protection: extend hold if keyboard activity detected
                let holdEndTime = calculateHoldWithKeyboardProtection(
                    baseHoldEnd: baseHoldEndTime,
                    holdStartTime: clickTime + config.zoomInDuration,
                    keyboardEvents: keyboardEvents
                )
                
                // Check for Click-Then-Move pattern
                let nextClickTime = (index + 1 < mergedClicks.count) ? mergedClicks[index + 1].timestamp : nil
                let (shouldFollow, followUntil, moveEvents) = detectClickThenMovePattern(
                    afterClick: clickTime,
                    clickPosition: constrainedPosition,
                    from: cursorSession,
                    nextClickTime: nextClickTime
                )
                
                if shouldFollow {
                    // Enter Follow Mode: zoom in, then follow cursor immediately
                    // Don't add Hold phase - go straight from Ease In to Follow
                    keyframes.append(contentsOf: generateZoomIn(
                        to: clickPosition,
                        scale: zoomScale,
                        startTime: clickTime,
                        duration: config.zoomInDuration,
                        holdUntil: nil  // No hold - transition directly to follow
                    ))
                    
                    // Generate follow keyframes starting from when movement begins
                    // This can overlap with Ease In for faster response
                    let firstMoveTime = moveEvents.first?.timestamp ?? (clickTime + config.zoomInDuration)
                    keyframes.append(contentsOf: generateFollowKeyframes(
                        fromPosition: constrainedPosition,
                        scale: zoomScale,
                        startTime: max(firstMoveTime, clickTime + config.zoomInDuration * 0.8),  // Start near end of Ease In
                        endTime: followUntil,
                        moveEvents: moveEvents,
                        referenceSize: referenceSize
                    ))
                    
                    // Update state to following
                    let finalPosition = moveEvents.last?.position ?? constrainedPosition
                    let finalConstrained = constrainCenter(finalPosition, at: zoomScale)
                    currentState = .following(at: finalConstrained)
                    lastZoomCenter = finalConstrained
                    currentHoldStartTime = followUntil
                    currentHoldEndTime = followUntil + calculatedHold
                } else {
                    // Normal zoom in with hold
                    keyframes.append(contentsOf: generateZoomIn(
                        to: clickPosition,
                        scale: zoomScale,
                        startTime: clickTime,
                        duration: config.zoomInDuration,
                        holdUntil: holdEndTime
                    ))
                    currentState = .zoomed(at: constrainedPosition)
                    lastZoomCenter = constrainedPosition  // Use constrained position, not original click position
                    currentHoldStartTime = clickTime + config.zoomInDuration  // Hold starts after Ease In
                    currentHoldEndTime = holdEndTime  // Remember when Hold ends
                }
                
            case .zoomed(let currentCenter), .following(let currentCenter):
                let distance = hypot(currentCenter.x - clickPosition.x, currentCenter.y - clickPosition.y)
                
                // Check if should debounce
                if shouldDebounce(currentClick: click, previousClicks: Array(mergedClicks[0..<index]), currentCenter: currentCenter) {
                    // Stay at current position, just update activity time
                    lastActivityTime = clickTime
                    continue
                }
                
                // Check if should apply hysteresis (prevent switching during Hold phase for small movements)
                if shouldApplyHysteresis(
                    currentClick: click,
                    lastActivityTime: lastActivityTime,
                    currentCenter: currentCenter,
                    currentState: currentState
                ) {
                    // Stay at current position during Hold phase for stability
                    lastActivityTime = clickTime
                    continue
                }
                
                // Check if we can interrupt Hold phase
                // Must satisfy holdMin requirement before allowing interruption
                let holdElapsed = clickTime - currentHoldStartTime
                
                if holdElapsed < config.holdMin {
                    // Cannot interrupt before holdMin, even for large distance
                    // Skip this click - it will not trigger a transition
                    continue
                }
                
                // Transition start time logic:
                // - If holdMin is satisfied and this is a large distance move: can interrupt immediately
                // - Otherwise: wait for current Hold to finish naturally
                let canInterruptEarly = distance > config.largeDistanceThreshold && holdElapsed >= config.holdMin
                let transitionStartTime: TimeInterval
                if canInterruptEarly {
                    // Allow early interruption: start transition immediately
                    transitionStartTime = clickTime
                } else {
                    // Wait for Hold to complete naturally
                    transitionStartTime = max(clickTime, currentHoldEndTime)
                }
                
                // Check if we're in an active session (rapid consecutive clicks)
                let timeSinceLastActivity = clickTime - lastActivityTime
                let inActiveSession = timeSinceLastActivity < config.activeSessionTimeout
                
                if distance > config.largeDistanceThreshold && !inActiveSession {
                    // Large distance in isolated click: zoom out -> pan -> zoom in
                    keyframes.append(contentsOf: generateLargeDistanceTransition(
                        from: currentCenter,
                        to: clickPosition,
                        startTime: transitionStartTime,  // Wait for Hold to finish
                        currentScale: dynamicZoom.zoomScaleWithCornerBoost(at: currentCenter)
                    ))
                    // largeDistanceTransition internally constrains the position, extract it from generated keyframes
                    let newScale = dynamicZoom.zoomScaleWithCornerBoost(at: clickPosition)
                    let constrainedPosition = constrainCenter(clickPosition, at: newScale)
                    currentState = .zoomed(at: constrainedPosition)
                    lastZoomCenter = constrainedPosition  // Use constrained position
                    
                    // Update Hold start and end time for this new zoom
                    let nextClickTime = (index + 1 < mergedClicks.count) ? mergedClicks[index + 1].timestamp : nil
                    let transitionDuration: TimeInterval = 0.8  // zoom out + pan + zoom in
                    let zoomInEndTime = transitionStartTime + transitionDuration
                    currentHoldStartTime = zoomInEndTime  // Hold starts after transition completes
                    let maxHoldTime = zoomInEndTime + config.holdBase
                    currentHoldEndTime = nextClickTime.map { min($0, maxHoldTime) } ?? maxHoldTime
                } else {
                    // Small distance: smooth pan transition
                    let newScale = dynamicZoom.zoomScaleWithCornerBoost(at: clickPosition)
                    let constrainedPosition = constrainCenter(clickPosition, at: newScale)
                    keyframes.append(contentsOf: generateSmoothTransition(
                        from: currentCenter,
                        to: clickPosition,
                        fromScale: dynamicZoom.zoomScaleWithCornerBoost(at: currentCenter),
                        toScale: newScale,
                        startTime: transitionStartTime,  // Wait for Hold to finish
                        duration: config.panDuration
                    ))
                    currentState = .zoomed(at: constrainedPosition)
                    lastZoomCenter = constrainedPosition  // Use constrained position
                    
                    // Update Hold start and end time for this new zoom
                    let nextClickTime = (index + 1 < mergedClicks.count) ? mergedClicks[index + 1].timestamp : nil
                    let panEndTime = transitionStartTime + config.panDuration
                    currentHoldStartTime = panEndTime  // Hold starts after pan completes
                    let maxHoldTime = panEndTime + config.holdBase
                    currentHoldEndTime = nextClickTime.map { min($0, maxHoldTime) } ?? maxHoldTime
                }
                
            default:
                break
            }
            
            lastActivityTime = clickTime
        }
        
        // Note: Follow keyframes disabled to maintain "Hold" phase stability.
        // Camera stays at attention point during Hold phase, only moves for explicit triggers (clicks).
        // TODO: Re-enable selective follow only for large cursor movements after hysteresis confirmation.
        
        // Add final zoom out if needed
        if case .zoomed = currentState, let center = lastZoomCenter {
            let endTime = cursorSession.duration
            // Consider keyboard activity with protection buffer (5s)
            let keyboardProtectionBuffer: TimeInterval = 5.0
            let lastKeyboardTime = keyboardEvents.last?.timestamp ?? 0
            let effectiveLastActivity = max(lastActivityTime, lastKeyboardTime)
            
            // Use keyboard protection buffer if keyboard activity is recent
            let timeoutToUse = (lastKeyboardTime > lastActivityTime) ? keyboardProtectionBuffer : config.idleTimeout
            
            if endTime - effectiveLastActivity > timeoutToUse {
                keyframes.append(contentsOf: generateZoomOut(
                    from: center,
                    startTime: effectiveLastActivity + timeoutToUse,
                    duration: config.zoomOutDuration
                ))
            } else {
                // Zoom out at end of recording
                keyframes.append(contentsOf: generateZoomOut(
                    from: center,
                    startTime: endTime - config.zoomOutDuration,
                    duration: config.zoomOutDuration
                ))
            }
        }
        
        // Sort by time and remove duplicates
        keyframes = keyframes.sorted { $0.time < $1.time }
        return deduplicateKeyframes(keyframes)
    }
    
    // MARK: - Click-Then-Move Pattern Detection
    
    /// Detects if there's significant cursor movement immediately after a click
    /// Returns (shouldFollow, targetTime, moveEvents) if pattern detected
    private func detectClickThenMovePattern(
        afterClick clickTime: TimeInterval,
        clickPosition: CGPoint,
        from session: CursorTrackSession,
        nextClickTime: TimeInterval?
    ) -> (shouldFollow: Bool, followUntil: TimeInterval, moveEvents: [MouseEvent]) {
        // Thresholds for pattern detection
        let detectionWindow: TimeInterval = 0.3  // Must start moving within 0.3s
        let minMovementThreshold: CGFloat = 0.05  // Min 5% screen movement
        let followTimeLimit: TimeInterval = 2.0   // Max follow duration
        
        // Find move events after this click
        let relevantMoves = session.events.filter { event in
            guard event.type == .move else { return false }
            guard event.timestamp > clickTime else { return false }
            
            // Stop if next click arrives
            if let nextClick = nextClickTime, event.timestamp >= nextClick {
                return false
            }
            
            // Within follow time limit
            return event.timestamp <= clickTime + followTimeLimit
        }
        
        
        guard !relevantMoves.isEmpty else {
            return (false, 0, [])
        }
        
        // Check if first significant movement happens within detection window
        var firstSignificantMove: MouseEvent?
        for event in relevantMoves {
            let distance = hypot(event.position.x - clickPosition.x, 
                               event.position.y - clickPosition.y)
            if distance >= minMovementThreshold {
                firstSignificantMove = event
                break
            }
        }
        
        guard let firstMove = firstSignificantMove,
              firstMove.timestamp - clickTime <= detectionWindow else {
            return (false, 0, [])
        }
        
        // Pattern detected! Determine follow duration
        // Follow until: cursor stops, new click, or time limit
        let lastMoveTime = relevantMoves.last?.timestamp ?? clickTime
        let followUntil = min(lastMoveTime + 0.5, clickTime + followTimeLimit)
        
        return (true, followUntil, relevantMoves)
    }
    
    // MARK: - Follow Mode Keyframes
    
    /// Generates smooth follow keyframes for Click-Then-Move pattern
    private func generateFollowKeyframes(
        fromPosition: CGPoint,
        scale: CGFloat,
        startTime: TimeInterval,
        endTime: TimeInterval,
        moveEvents: [MouseEvent],
        referenceSize: CGSize
    ) -> [ZoomKeyframe] {
        var keyframes: [ZoomKeyframe] = []
        
        guard !moveEvents.isEmpty else { return keyframes }
        
        // Use One-Euro filter for smooth following (separate for x and y)
        var smootherX = OneEuroFilter(
            minCutoff: config.oneEuroMinCutoff * 1.5,  // Stronger smoothing for follow
            beta: config.oneEuroBeta * 0.5,            // Less speed adaptation
            dCutoff: config.oneEuroDCutoff
        )
        var smootherY = OneEuroFilter(
            minCutoff: config.oneEuroMinCutoff * 1.5,
            beta: config.oneEuroBeta * 0.5,
            dCutoff: config.oneEuroDCutoff
        )
        
        // Sample and smooth the cursor path
        var smoothedPoints: [(time: TimeInterval, position: CGPoint)] = []
        smoothedPoints.append((startTime, fromPosition))
        
        var lastSampleTime: TimeInterval = startTime
        let sampleInterval: TimeInterval = config.followKeyframeInterval
        
        for event in moveEvents {
            guard event.timestamp >= startTime && event.timestamp <= endTime else { continue }
            
            // Sample at regular intervals
            if event.timestamp - lastSampleTime >= sampleInterval {
                let smoothedX = smootherX.filter(
                    value: event.position.x,
                    timestamp: event.timestamp
                )
                let smoothedY = smootherY.filter(
                    value: event.position.y,
                    timestamp: event.timestamp
                )
                let smoothed = CGPoint(x: smoothedX, y: smoothedY)
                smoothedPoints.append((event.timestamp, smoothed))
                lastSampleTime = event.timestamp
            }
        }
        
        // Ensure we have the final position
        if let lastEvent = moveEvents.last,
           lastEvent.timestamp > lastSampleTime,
           lastEvent.timestamp <= endTime {
            let smoothedX = smootherX.filter(
                value: lastEvent.position.x,
                timestamp: lastEvent.timestamp
            )
            let smoothedY = smootherY.filter(
                value: lastEvent.position.y,
                timestamp: lastEvent.timestamp
            )
            let smoothed = CGPoint(x: smoothedX, y: smoothedY)
            smoothedPoints.append((lastEvent.timestamp, smoothed))
        }
        
        // Generate keyframes from smoothed points
        for point in smoothedPoints {
            let constrainedPosition = constrainCenter(point.position, at: scale)
            keyframes.append(ZoomKeyframe(
                time: point.time,
                scale: scale,  // Maintain zoom level
                center: constrainedPosition,
                easing: .linear  // Linear for smooth following
            ))
        }
        
        return keyframes
    }
    
    // MARK: - Keyframe Generation
    
    private func generateZoomIn(
        to center: CGPoint,
        scale: CGFloat,
        startTime: TimeInterval,
        duration: TimeInterval,
        holdUntil: TimeInterval? = nil
    ) -> [ZoomKeyframe] {
        let constrainedCenter = constrainCenter(center, at: scale)
        var keyframes = [
            // Ease In: zoom in to target
            ZoomKeyframe(time: startTime, scale: 1.0, center: constrainedCenter, easing: config.easing),
            ZoomKeyframe(time: startTime + duration, scale: scale, center: constrainedCenter, easing: config.easing)
        ]
        
        // Add Hold keyframe if specified and there's enough time
        if let holdUntil {
            let holdTime = max(startTime + duration, holdUntil)
            if holdTime > startTime + duration + 0.1 {  // At least 0.1s of hold
                keyframes.append(ZoomKeyframe(
                    time: holdTime,
                    scale: scale,
                    center: constrainedCenter,
                    easing: .linear
                ))
            }
        }
        
        return keyframes
    }
    
    private func generateZoomOut(
        from center: CGPoint,
        startTime: TimeInterval,
        duration: TimeInterval
    ) -> [ZoomKeyframe] {
        let scale = dynamicZoom.zoomScaleWithCornerBoost(at: center)
        return [
            ZoomKeyframe(time: startTime, scale: scale, center: center, easing: config.easing),
            ZoomKeyframe(time: startTime + duration, scale: 1.0, center: CGPoint(x: 0.5, y: 0.5), easing: config.easing)
        ]
    }
    
    private func generateSmoothTransition(
        from fromCenter: CGPoint,
        to toCenter: CGPoint,
        fromScale: CGFloat,
        toScale: CGFloat,
        startTime: TimeInterval,
        duration: TimeInterval
    ) -> [ZoomKeyframe] {
        let constrainedTo = constrainCenter(toCenter, at: toScale)
        return [
            ZoomKeyframe(time: startTime, scale: fromScale, center: fromCenter, easing: config.easing),
            ZoomKeyframe(time: startTime + duration, scale: toScale, center: constrainedTo, easing: config.easing)
        ]
    }
    
    private func generateLargeDistanceTransition(
        from fromCenter: CGPoint,
        to toCenter: CGPoint,
        startTime: TimeInterval,
        currentScale: CGFloat
    ) -> [ZoomKeyframe] {
        var keyframes: [ZoomKeyframe] = []
        
        let distance = hypot(toCenter.x - fromCenter.x, toCenter.y - fromCenter.y)
        
        // Strategy: Parallel interpolation of scale and translation
        // Total duration: 0.5-0.6s (faster than serial 0.8s)
        // Interpolate both scale and center simultaneously
        
        // Determine intermediate scale based on distance
        let intermediateScale: CGFloat
        if distance < 0.5 {
            intermediateScale = 1.5  // Minimal zoom out
        } else if distance < 0.7 {
            intermediateScale = 1.3  // Moderate zoom out
        } else {
            intermediateScale = 1.0  // Full zoom out
        }
        
        let newScale = dynamicZoom.zoomScaleWithCornerBoost(at: toCenter)
        let _ = constrainCenter(toCenter, at: newScale)  // Constraint checking
        
        // Adaptive transition duration based on distance
        // Formula: duration = baseTime + (distance * scalingFactor)
        // - Short distance (<0.3): ~0.3s
        // - Medium distance (0.3-0.6): ~0.4-0.5s
        // - Long distance (>0.6): ~0.5-0.65s
        let baseDuration: TimeInterval = 0.25
        let distanceScale: TimeInterval = 0.5  // Max additional time
        let totalDuration = baseDuration + (Double(distance) * distanceScale)
        
        // Generate keyframes at regular intervals for smooth interpolation
        let steps = 5  // Number of intermediate steps
        for i in 0...steps {
            let t = TimeInterval(i) / TimeInterval(steps)  // 0.0 to 1.0
            let time = startTime + t * totalDuration
            
            // Parallel interpolation:
            // - Scale: currentScale -> intermediateScale -> newScale (ease-in-out curve)
            // - Center: fromCenter -> toCenter (ease-in-out curve)
            
            let scale: CGFloat
            let center: CGPoint
            
            if t < 0.5 {
                // First half: zoom out while starting to move
                let localT = t * 2.0  // 0.0 to 1.0
                let easedT = easeInOut(localT)
                scale = lerp(currentScale, intermediateScale, easedT)
                center = CGPoint(
                    x: lerp(fromCenter.x, toCenter.x, easedT * 0.6),  // Move partially
                    y: lerp(fromCenter.y, toCenter.y, easedT * 0.6)
                )
            } else {
                // Second half: zoom in while completing movement
                let localT = (t - 0.5) * 2.0  // 0.0 to 1.0
                let easedT = easeInOut(localT)
                scale = lerp(intermediateScale, newScale, easedT)
                center = CGPoint(
                    x: lerp(fromCenter.x, toCenter.x, 0.6 + easedT * 0.4),  // Complete movement
                    y: lerp(fromCenter.y, toCenter.y, 0.6 + easedT * 0.4)
                )
            }
            
            // Apply constraint to center based on current scale
            let constrainedCenter = constrainCenter(center, at: scale)
            keyframes.append(ZoomKeyframe(
                time: time,
                scale: scale,
                center: constrainedCenter,
                easing: config.easing
            ))
        }
        
        return keyframes
    }
    
    // MARK: - Interpolation Helpers
    
    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        return a + (b - a) * t
    }
    
    private func easeInOut(_ t: CGFloat) -> CGFloat {
        // Cubic ease-in-out: smoother than linear
        if t < 0.5 {
            return 4 * t * t * t
        } else {
            let f = 2 * t - 2
            return 1 + f * f * f / 2
        }
    }
    
    private func addFollowingKeyframes(
        to keyframes: [ZoomKeyframe],
        cursorSampler: inout OneEuroCursorSampler,
        clicks: [ClickEvent],
        endTime: TimeInterval
    ) -> [ZoomKeyframe] {
        var result = keyframes
        
        guard !clicks.isEmpty else { return result }
        
        // For each click, add following keyframes until the next click (or until we zoom out).
        for i in 0..<clicks.count {
            let currentClick = clicks[i]
            let nextClick = (i + 1 < clicks.count) ? clicks[i + 1] : nil
            
            let gapStart = currentClick.timestamp + config.zoomInDuration
            let rawGapEnd = nextClick?.timestamp ?? max(gapStart, (currentClick.timestamp + config.zoomInDuration + config.idleTimeout))
            let gapEnd = min(rawGapEnd, endTime)
            
            // Only add following if gap is significant
            guard gapEnd - gapStart > 0.3 else { continue }
            
            // 1. Sample follow points at regular interval (smoothed with One-Euro)
            let interval = config.followKeyframeInterval
            var sampled: [RDPPoint] = []
            var time = gapStart + interval
            while time < gapEnd - 0.1 {
                if let position = cursorSampler.smoothedPosition(at: time) {
                    sampled.append(RDPPoint(time: time, position: position))
                }
                time += interval
            }
            
            // 2. Simplify path with RDP to reduce keyframes
            var simplified = RamerDouglasPeucker.simplify(points: sampled, epsilon: config.rdpEpsilon)
            
            // Ensure we keep the last sampled point to reflect latest cursor position before the next event/zoom-out.
            if let lastSample = sampled.last, simplified.last?.time != lastSample.time {
                simplified.append(lastSample)
            }
            
            // Ensure sorted by time after appending.
            simplified.sort { $0.time < $1.time }
            
            // 2.5 Densify to keep responsiveness (cap time gaps between keyframes).
            simplified = densify(
                simplified: simplified,
                sampled: sampled,
                maxGap: config.followMaxKeyframeGap
            )
            
            // 3. Emit follow keyframes at simplified points
            for point in simplified {
                let scale = dynamicZoom.zoomScaleWithCornerBoost(at: point.position)
                let constrainedCenter = constrainCenter(point.position, at: scale)
                result.append(ZoomKeyframe(
                    time: point.time,
                    scale: scale,
                    center: constrainedCenter,
                    easing: .linear
                ))
            }
        }
        
        return result
    }

    private func densify(
        simplified: [RDPPoint],
        sampled: [RDPPoint],
        maxGap: TimeInterval
    ) -> [RDPPoint] {
        guard simplified.count >= 2, maxGap > 0 else { return simplified }
        guard !sampled.isEmpty else { return simplified }
        
        var result: [RDPPoint] = [simplified[0]]
        
        for i in 1..<simplified.count {
            let prev = result.last!
            let next = simplified[i]
            
            var t = prev.time + maxGap
            while t < next.time {
                if let filler = sampled.min(by: { abs($0.time - t) < abs($1.time - t) }) {
                    if filler.time > prev.time && filler.time < next.time {
                        result.append(filler)
                    }
                }
                t += maxGap
            }
            
            result.append(next)
        }
        
        // Deduplicate and sort
        var seen: Set<TimeInterval> = []
        let deduped = result
            .sorted { $0.time < $1.time }
            .filter { point in
                if seen.contains(point.time) { return false }
                seen.insert(point.time)
                return true
            }
        
        return deduped
    }
    
    // MARK: - Helper Methods
    
    private func hasKeyboardActivity(at time: TimeInterval, events: [KeyboardEvent]) -> Bool {
        events.contains { event in
            let timeDiff = abs(time - event.timestamp)
            return timeDiff < 0.5 && event.type == .keyDown
        }
    }
    
    private func shouldDebounce(
        currentClick: MergedClick,
        previousClicks: [MergedClick],
        currentCenter: CGPoint
    ) -> Bool {
        // Get recent clicks within debounce time window
        let recentClicks = previousClicks.filter {
            currentClick.timestamp - $0.timestamp < config.debounceTimeWindow
        }
        
        guard recentClicks.count >= 2 else { return false }
        
        // Calculate bounding box of recent activity
        let allPositions = recentClicks.map(\.position) + [currentClick.position]
        let minX = allPositions.map(\.x).min()!
        let maxX = allPositions.map(\.x).max()!
        let minY = allPositions.map(\.y).min()!
        let maxY = allPositions.map(\.y).max()!
        
        let areaRatio = (maxX - minX) * (maxY - minY)
        
        // Debounce if activity is concentrated in a small area
        return areaRatio < config.debounceAreaThreshold
    }
    
    private func shouldApplyHysteresis(
        currentClick: MergedClick,
        lastActivityTime: TimeInterval,
        currentCenter: CGPoint,
        currentState: ZoomControlState
    ) -> Bool {
        // During Hold phase, require higher threshold to switch (hysteresis effect).
        // Only switch if:
        // 1. Enough time has passed since last activity (grace period), OR
        // 2. Click is far enough from current center (significant movement)
        
        guard case .zoomed = currentState else { return false }
        
        let timeSinceLastActivity = currentClick.timestamp - lastActivityTime
        let distanceFromCenter = hypot(currentClick.position.x - currentCenter.x, currentClick.position.y - currentCenter.y)
        
        // If still in Hold phase (< holdBase), only switch for large movements
        let isInHoldPhase = timeSinceLastActivity < config.holdBase
        let isLargeMovement = distanceFromCenter > config.largeDistanceThreshold * 0.5
        
        // Apply hysteresis: reject switch if we're in Hold phase AND movement is small
        return isInHoldPhase && !isLargeMovement
    }
    
    private func constrainCenter(_ center: CGPoint, at scale: CGFloat) -> CGPoint {
        guard scale > 1.0 else { return center }
        
        let visibleWidth = 1.0 / scale
        let visibleHeight = 1.0 / scale
        let halfWidth = visibleWidth / 2
        let halfHeight = visibleHeight / 2
        
        let constrainedX = max(halfWidth, min(1.0 - halfWidth, center.x))
        let constrainedY = max(halfHeight, min(1.0 - halfHeight, center.y))
        
        return CGPoint(x: constrainedX, y: constrainedY)
    }
    
    private func deduplicateKeyframes(_ keyframes: [ZoomKeyframe]) -> [ZoomKeyframe] {
        var result: [ZoomKeyframe] = []
        var lastTime: TimeInterval = -1
        
        for keyframe in keyframes {
            if keyframe.time - lastTime > 0.01 {
                result.append(keyframe)
                lastTime = keyframe.time
            }
        }
        
        return result
    }

    // MARK: - Click Merge (T_merge / D_merge)

    private func mergeClicks(_ clicks: [ClickEvent], referenceSize: CGSize) -> [MergedClick] {
        guard !clicks.isEmpty else { return [] }
        guard clicks.count > 1 else { return [MergedClick(from: clicks[0], eventCount: 1)] }
        
        let maxDimension = max(referenceSize.width, referenceSize.height)
        let mergeDistanceNormalized = maxDimension > 0 ? (config.clickMergeDistancePixels / maxDimension) : 0
        
        var result: [MergedClick] = []
        var group: [ClickEvent] = [clicks[0]]
        
        for i in 1..<clicks.count {
            let current = clicks[i]
            let previous = group.last!
            
            let dt = current.timestamp - previous.timestamp
            let distance = hypot(current.position.x - previous.position.x, current.position.y - previous.position.y)
            
            if dt < config.clickMergeTime && distance < mergeDistanceNormalized {
                group.append(current)
            } else {
                result.append(MergedClick(from: group))
                group = [current]
            }
        }
        
        result.append(MergedClick(from: group))
        return result
    }

    // MARK: - Cursor Filtering (One-Euro)

    // MARK: - Cursor Sampler

    private struct OneEuroCursorSampler {
        let points: [CursorPoint]

        private var filterX: OneEuroFilter
        private var filterY: OneEuroFilter

        init(points: [CursorPoint], minCutoff: Double, beta: Double, dCutoff: Double) {
            self.points = points
            self.filterX = OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff)
            self.filterY = OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff)
        }

        mutating func smoothedPosition(at time: TimeInterval) -> CGPoint? {
            guard let raw = Self.positionAt(time: time, points: points) else { return nil }
            let x = filterX.filter(value: Double(raw.x), timestamp: time)
            let y = filterY.filter(value: Double(raw.y), timestamp: time)
            return CGPoint(x: CGFloat(x), y: CGFloat(y))
        }

        private static func positionAt(time: TimeInterval, points: [CursorPoint]) -> CGPoint? {
            guard !points.isEmpty else { return nil }
            
            guard let afterIndex = points.firstIndex(where: { $0.timestamp >= time }) else {
                return points.last?.position
            }
            
            if afterIndex == 0 {
                return points.first?.position
            }
            
            let before = points[afterIndex - 1]
            let after = points[afterIndex]
            
            let timeDelta = after.timestamp - before.timestamp
            guard timeDelta > 0 else { return before.position }
            
            let t = (time - before.timestamp) / timeDelta
            let x = before.position.x + CGFloat(t) * (after.position.x - before.position.x)
            let y = before.position.y + CGFloat(t) * (after.position.y - before.position.y)
            
            return CGPoint(x: x, y: y)
        }
    }
    
    // MARK: - Keyboard Protection (Phase 3.2)
    
    /// Calculate hold duration considering keyboard activity
    /// Extends hold if keyboard events occur during the hold phase
    /// - Parameters:
    ///   - baseHoldEnd: The base hold end time without keyboard protection
    ///   - holdStartTime: When the hold phase begins
    ///   - keyboardEvents: All keyboard events in the session
    /// - Returns: Extended hold end time if keyboard activity is detected
    private func calculateHoldWithKeyboardProtection(
        baseHoldEnd: TimeInterval,
        holdStartTime: TimeInterval,
        keyboardEvents: [KeyboardEvent]
    ) -> TimeInterval {
        // Keyboard protection buffer: maintain zoom for at least 5s after last keystroke
        let keyboardProtectionBuffer: TimeInterval = 5.0
        
        // Find keyboard events that occur during or shortly after the hold period
        // We look ahead by a reasonable window to catch ongoing typing
        let relevantEvents = keyboardEvents.filter { event in
            event.timestamp >= holdStartTime &&
            event.timestamp <= (baseHoldEnd + keyboardProtectionBuffer + 10.0)  // Look ahead to detect ongoing activity
        }
        
        guard !relevantEvents.isEmpty else {
            return baseHoldEnd  // No keyboard activity, use base hold
        }
        
        // Find the last keyboard event
        guard let lastKeyboardEvent = relevantEvents.max(by: { $0.timestamp < $1.timestamp }) else {
            return baseHoldEnd
        }
        
        // Extend hold to at least keyboardProtectionBuffer seconds after the last keyboard event
        let extendedHold = lastKeyboardEvent.timestamp + keyboardProtectionBuffer
        
        // Return the longer of baseHoldEnd or extended hold
        return max(baseHoldEnd, extendedHold)
    }
}
