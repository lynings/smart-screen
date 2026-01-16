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
    
    /// Pre-click buffer duration (seconds) - start zoom this much before the click
    /// This allows viewers to see the click action happening
    let preClickBuffer: TimeInterval
    
    /// Whether pre-click buffer is enabled
    let preClickBufferEnabled: Bool
    
    static let `default` = ContinuousZoomConfig(
        baseZoomScale: 2.0,
        zoomInDuration: 0.35,      // Slightly longer for smoother zoom in
        holdMin: 0.8,              // Increased to prevent rapid zoom out
        holdBase: 1.2,             // Longer base hold to reduce flicker
        holdMax: 3.0,              // Allow longer holds for stability
        holdExtensionPerEvent: 0.5,// More extension per click
        zoomOutDuration: 0.5,      // Slightly longer for smoother zoom out
        panDuration: 0.35,
        idleTimeout: 2.5,          // Slightly shorter idle timeout
        largeDistanceThreshold: 0.3,
        activeSessionTimeout: 1.5, // Longer session timeout
        debounceAreaThreshold: 0.15,
        debounceTimeWindow: 0.8,   // Longer debounce window
        easing: .easeInOut,
        clickMergeTime: 0.8,       // Longer merge window to group rapid clicks
        clickMergeDistancePixels: 300,  // Larger merge area
        followKeyframeInterval: 1.0 / 30.0,  // 30fps for smoother animation
        oneEuroMinCutoff: 1.0,
        oneEuroBeta: 0.007,
        oneEuroDCutoff: 1.0,
        rdpEpsilon: 0.004,
        followMaxKeyframeGap: 0.2, // Smaller gap for more keyframes
        preClickBuffer: 0.15,
        preClickBufferEnabled: true
    )

    init(
        baseZoomScale: CGFloat = 2.0,
        zoomInDuration: TimeInterval = 0.3,
        holdMin: TimeInterval = 0.5,           // Increased for better stability
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
        clickMergeTime: TimeInterval = 0.5,    // Increased for better click grouping
        clickMergeDistancePixels: CGFloat = 200,  // Increased for larger merge area
        followKeyframeInterval: TimeInterval = 1.0 / 15.0,
        oneEuroMinCutoff: Double = 1.0,
        oneEuroBeta: Double = 0.007,
        oneEuroDCutoff: Double = 1.0,
        rdpEpsilon: CGFloat = 0.004,
        followMaxKeyframeGap: TimeInterval = 0.4,
        preClickBuffer: TimeInterval = 0.15,
        preClickBufferEnabled: Bool = true
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
        self.preClickBuffer = preClickBuffer
        self.preClickBufferEnabled = preClickBufferEnabled
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

/// Merged click event with first/last positions for smooth transitions
struct MergedClick {
    let position: CGPoint           // Primary position (first click)
    let timestamp: TimeInterval     // Time of first click
    let eventCount: Int             // Number of original clicks merged
    let type: ClickType
    
    // For handling rapid clicks: track first and last positions
    let firstPosition: CGPoint
    let lastPosition: CGPoint
    let lastTimestamp: TimeInterval
    let internalDistance: CGFloat   // Distance between first and last click
    
    init(from click: ClickEvent, eventCount: Int = 1) {
        self.position = click.position
        self.timestamp = click.timestamp
        self.eventCount = eventCount
        self.type = click.type
        self.firstPosition = click.position
        self.lastPosition = click.position
        self.lastTimestamp = click.timestamp
        self.internalDistance = 0
    }
    
    init(from group: [ClickEvent]) {
        guard let first = group.first, !group.isEmpty else {
            self.position = .zero
            self.timestamp = 0
            self.eventCount = 0
            self.type = .leftClick
            self.firstPosition = .zero
            self.lastPosition = .zero
            self.lastTimestamp = 0
            self.internalDistance = 0
            return
        }
        
        let last = group.last!
        
        // Use FIRST position as primary (user's initial intent)
            self.position = first.position
            self.timestamp = first.timestamp
            self.eventCount = group.count
            self.type = first.type
        
        // Track first and last for transition decisions
        self.firstPosition = first.position
        self.lastPosition = last.position
        self.lastTimestamp = last.timestamp
        self.internalDistance = hypot(
            last.position.x - first.position.x,
            last.position.y - first.position.y
        )
    }
    
    /// Duration of the rapid click sequence
    var sequenceDuration: TimeInterval {
        lastTimestamp - timestamp
    }
    
    /// Whether this merged click spans a significant distance (needs smooth transition)
    var needsSmoothTransition: Bool {
        internalDistance > 0.05 && eventCount > 1  // >5% screen distance with multiple clicks
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
        var lastZoomScale: CGFloat = 1.0  // Track current zoom scale for interruption
        var lastActivityTime: TimeInterval = 0
        var currentHoldEndTime: TimeInterval = 0  // Track when current Hold phase ends
        var currentHoldStartTime: TimeInterval = 0  // Track when current Hold phase starts
        
        // Track pending zoom out for interruption handling
        var pendingZoomOut: (startTime: TimeInterval, endTime: TimeInterval, fromCenter: CGPoint)? = nil
        
        // Process each click event
        for (index, click) in mergedClicks.enumerated() {
            let clickTime = click.timestamp
            let clickPosition = click.position
            
            // 1. Check for keyboard activity - zoom out if typing
            if hasKeyboardActivity(at: clickTime, events: keyboardEvents) {
                if case .zoomed = currentState, let center = lastZoomCenter {
                    let zoomOutStart = clickTime - 0.1
                    keyframes.append(contentsOf: generateZoomOut(
                        from: center,
                        startTime: zoomOutStart,
                        duration: config.zoomOutDuration
                    ))
                    pendingZoomOut = (zoomOutStart, zoomOutStart + config.zoomOutDuration, center)
                    currentState = .idle
                    lastZoomCenter = nil
                }
                continue
            }
            
            // 2. Check if click occurs during a pending zoom out - interrupt and redirect
            if let zoomOut = pendingZoomOut,
               clickTime >= zoomOut.startTime && clickTime <= zoomOut.endTime {
                // Click during zoom out - interrupt and zoom in to new position
                // Remove the zoom out keyframes that haven't started yet
                keyframes = keyframes.filter { $0.time < clickTime }
                
                // Calculate current scale at interruption point using spring physics
                let zoomOutProgress = (clickTime - zoomOut.startTime) / config.zoomOutDuration
                let spring = SpringAnimation.default
                let currentScale = spring.value(
                    at: zoomOutProgress * spring.settlingTime,
                    from: lastZoomScale,
                    to: 1.0
                )
                
                // Calculate current center (interpolated between old center and screen center)
                let currentCenter = CGPoint(
                    x: zoomOut.fromCenter.x + (0.5 - zoomOut.fromCenter.x) * CGFloat(zoomOutProgress),
                    y: zoomOut.fromCenter.y + (0.5 - zoomOut.fromCenter.y) * CGFloat(zoomOutProgress)
                )
                
                // Add interruption keyframe at current position
                keyframes.append(ZoomKeyframe(
                    time: clickTime,
                    scale: currentScale,
                    center: currentCenter,
                    easing: .easeOut
                ))
                
                // Zoom in to new click position with spring animation
                let newScale = dynamicZoom.zoomScaleWithCornerBoost(at: clickPosition)
                let constrainedPosition = constrainCenterForCursor(clickPosition, cursorPosition: clickPosition, at: newScale)
                
                keyframes.append(contentsOf: generateSpringZoomIn(
                    from: currentCenter,
                    fromScale: currentScale,
                    to: constrainedPosition,
                    toScale: newScale,
                    startTime: clickTime,
                    duration: config.zoomInDuration
                ))
                
                currentState = .zoomed(at: constrainedPosition)
                lastZoomCenter = constrainedPosition
                lastZoomScale = newScale
                currentHoldStartTime = clickTime + config.zoomInDuration
                currentHoldEndTime = currentHoldStartTime + config.holdBase
                pendingZoomOut = nil
                lastActivityTime = clickTime
                continue
            }
            
            // Clear pending zoom out if click is after it
            if let zoomOut = pendingZoomOut, clickTime > zoomOut.endTime {
                pendingZoomOut = nil
            }
            
            // 3. Check for idle timeout - zoom out if no activity for 3 seconds
            // Consider keyboard activity as activity to prevent premature zoom out
            // Look at ALL keyboard events, not just those before current click
            let lastKeyboardBeforeClick = keyboardEvents.filter { $0.timestamp <= clickTime }.last?.timestamp ?? 0
            let effectiveLastActivity = max(lastActivityTime, lastKeyboardBeforeClick)
            
            if clickTime - effectiveLastActivity > config.idleTimeout {
                if case .zoomed = currentState, let center = lastZoomCenter {
                    let zoomOutStart = effectiveLastActivity + config.idleTimeout
                    keyframes.append(contentsOf: generateZoomOut(
                        from: center,
                        startTime: zoomOutStart,
                        duration: config.zoomOutDuration
                    ))
                    pendingZoomOut = (zoomOutStart, zoomOutStart + config.zoomOutDuration, center)
                    currentState = .idle
                    lastZoomCenter = nil
                }
            }
            
            // 4. Determine transition type based on current state
            switch currentState {
            case .idle:
                // For rapid clicks with distance, use first position and smoothly pan to last
                let primaryPosition = click.firstPosition
                let finalPosition = click.lastPosition
                
                let zoomScale = dynamicZoom.zoomScaleWithCornerBoost(at: primaryPosition)
                lastZoomScale = zoomScale
                // Use cursor-aware constraint to prevent occlusion at edges
                let constrainedPosition = constrainCenterForCursor(primaryPosition, cursorPosition: primaryPosition, at: zoomScale)
                
                // Calculate dynamic hold duration based on event count and distance
                // More clicks = longer hold, larger distance = adjusted transition speed
                let baseHold = config.holdBase
                let holdExtension = TimeInterval(click.eventCount - 1) * config.holdExtensionPerEvent
                
                // If rapid clicks span distance, extend hold to allow smooth pan
                let distanceExtension: TimeInterval = click.needsSmoothTransition ? click.sequenceDuration + 0.3 : 0
                let uncappedHold = baseHold + holdExtension + distanceExtension
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
                    
                    // Apply pre-click buffer: start zoom before the click
                    let zoomStartTime = config.preClickBufferEnabled 
                        ? max(0, clickTime - config.preClickBuffer) 
                        : clickTime
                    
                    keyframes.append(contentsOf: generateZoomIn(
                        to: clickPosition,
                        scale: zoomScale,
                        startTime: zoomStartTime,
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
                    let finalConstrained = constrainCenterForCursor(finalPosition, cursorPosition: finalPosition, at: zoomScale)
                    currentState = .following(at: finalConstrained)
                    lastZoomCenter = finalConstrained
                    currentHoldStartTime = followUntil
                    currentHoldEndTime = followUntil + calculatedHold
                } else {
                    // Normal zoom in with hold
                    
                    // Apply pre-click buffer: start zoom before the click
                    let zoomStartTime = config.preClickBufferEnabled 
                        ? max(0, clickTime - config.preClickBuffer) 
                        : clickTime
                    
                    // Check for any movement during the Hold period that might trigger late follow mode
                    let holdStartTime = zoomStartTime + config.zoomInDuration
                    let (lateFollow, lateFollowUntil, lateMoveEvents) = detectLateFollowPattern(
                        during: holdStartTime...holdEndTime,
                        startPosition: constrainedPosition,
                        from: cursorSession,
                        nextClickTime: nextClickTime
                    )
                    
                    if lateFollow && !lateMoveEvents.isEmpty {
                        // Late follow detected during Hold - generate zoom in without hold, then follow
                    keyframes.append(contentsOf: generateZoomIn(
                        to: clickPosition,
                        scale: zoomScale,
                            startTime: zoomStartTime,
                        duration: config.zoomInDuration,
                            holdUntil: nil  // No static hold - go to follow
                        ))
                        
                        // Generate follow keyframes
                        keyframes.append(contentsOf: generateFollowKeyframes(
                            fromPosition: constrainedPosition,
                            scale: zoomScale,
                            startTime: holdStartTime,
                            endTime: lateFollowUntil,
                            moveEvents: lateMoveEvents,
                            referenceSize: referenceSize
                        ))
                        
                        let finalPosition = lateMoveEvents.last?.position ?? constrainedPosition
                        let finalConstrained = constrainCenterForCursor(finalPosition, cursorPosition: finalPosition, at: zoomScale)
                        currentState = .following(at: finalConstrained)
                        lastZoomCenter = finalConstrained
                        currentHoldStartTime = lateFollowUntil
                        currentHoldEndTime = lateFollowUntil + calculatedHold
                    } else {
                        // Standard zoom in with static hold
                        keyframes.append(contentsOf: generateZoomIn(
                            to: primaryPosition,
                            scale: zoomScale,
                            startTime: zoomStartTime,
                            duration: config.zoomInDuration,
                            holdUntil: click.needsSmoothTransition ? nil : holdEndTime
                        ))
                        
                        // If rapid clicks span a distance, smoothly pan from first to last position
                        if click.needsSmoothTransition {
                            let panStartTime = zoomStartTime + config.zoomInDuration
                            let panDuration = max(0.2, click.sequenceDuration)  // At least 0.2s for smooth pan
                            
                            let constrainedFinal = constrainCenterForCursor(finalPosition, cursorPosition: finalPosition, at: zoomScale)
                            keyframes.append(contentsOf: generateSmoothTransition(
                                from: constrainedPosition,
                                to: constrainedFinal,
                                fromScale: zoomScale,
                                toScale: zoomScale,  // Keep same zoom level
                                startTime: panStartTime,
                                duration: panDuration
                            ))
                            
                            // Add hold after pan completes
                            let holdStart = panStartTime + panDuration
                            keyframes.append(ZoomKeyframe(
                                time: holdStart,
                                scale: zoomScale,
                                center: constrainedFinal,
                                easing: .linear
                            ))
                            keyframes.append(ZoomKeyframe(
                                time: holdEndTime,
                                scale: zoomScale,
                                center: constrainedFinal,
                                easing: .linear
                            ))
                            
                            currentState = .zoomed(at: constrainedFinal)
                            lastZoomCenter = constrainedFinal
                            currentHoldStartTime = holdStart
                            currentHoldEndTime = holdEndTime
                        } else {
                    currentState = .zoomed(at: constrainedPosition)
                            lastZoomCenter = constrainedPosition
                            currentHoldStartTime = holdStartTime
                            currentHoldEndTime = holdEndTime
                        }
                    }
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
                    // Use cursor-aware constraint to prevent occlusion at edges
                    let newScale = dynamicZoom.zoomScaleWithCornerBoost(at: clickPosition)
                    let constrainedPosition = constrainCenterForCursor(clickPosition, cursorPosition: clickPosition, at: newScale)
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
                    // Use cursor-aware constraint to prevent occlusion at edges
                    let constrainedPosition = constrainCenterForCursor(clickPosition, cursorPosition: clickPosition, at: newScale)
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
    
    // MARK: - Movement Pattern Detection
    
    /// Detects movement during Hold phase that should trigger follow mode
    /// This catches cases where user starts moving after the initial detection window
    private func detectLateFollowPattern(
        during holdPeriod: ClosedRange<TimeInterval>,
        startPosition: CGPoint,
        from session: CursorTrackSession,
        nextClickTime: TimeInterval?
    ) -> (shouldFollow: Bool, followUntil: TimeInterval, moveEvents: [MouseEvent]) {
        let minMovementThreshold: CGFloat = 0.03  // 3% screen movement to trigger
        let followExtension: TimeInterval = 1.5   // Extend follow after last movement
        
        // Find move events during Hold period
        let relevantMoves = session.events.filter { event in
            guard event.type == .move else { return false }
            guard holdPeriod.contains(event.timestamp) else { return false }
            
            // Stop if next click arrives
            if let nextClick = nextClickTime, event.timestamp >= nextClick {
                return false
            }
            
            return true
        }
        
        guard !relevantMoves.isEmpty else {
            return (false, 0, [])
        }
        
        // Check for significant movement from start position
        var hasSignificantMovement = false
        var maxDistanceEvent: MouseEvent?
        var maxDistance: CGFloat = 0
        
        for event in relevantMoves {
            let distance = hypot(event.position.x - startPosition.x,
                               event.position.y - startPosition.y)
            if distance > maxDistance {
                maxDistance = distance
                maxDistanceEvent = event
            }
            if distance >= minMovementThreshold {
                hasSignificantMovement = true
            }
        }
        
        guard hasSignificantMovement else {
            return (false, 0, [])
        }
        
        // Calculate follow until time based on movement pattern
        let lastMoveTime = relevantMoves.last?.timestamp ?? holdPeriod.lowerBound
        var followUntil = lastMoveTime + followExtension
        
        // Cap by next click if present
        if let nextClick = nextClickTime {
            followUntil = min(followUntil, nextClick - 0.1)
        }
        
        return (true, followUntil, relevantMoves)
    }
    
    /// Detects if there's significant cursor movement after a click (e.g., menu navigation)
    /// Returns (shouldFollow, targetTime, moveEvents) if pattern detected
    private func detectClickThenMovePattern(
        afterClick clickTime: TimeInterval,
        clickPosition: CGPoint,
        from session: CursorTrackSession,
        nextClickTime: TimeInterval?
    ) -> (shouldFollow: Bool, followUntil: TimeInterval, moveEvents: [MouseEvent]) {
        // Relaxed thresholds for better menu/submenu detection
        let detectionWindow: TimeInterval = 0.8      // Extended: 0.3 -> 0.8s for slow menu interactions
        let minMovementThreshold: CGFloat = 0.02     // Reduced: 0.05 -> 0.02 (2% screen movement)
        let followTimeLimit: TimeInterval = 5.0      // Extended: 2.0 -> 5.0s for complex menu hierarchies
        let idleThreshold: TimeInterval = 0.8        // If no movement for 0.8s, consider cursor stopped
        
        // Find all move events after this click
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
        
        // Check if any significant movement happens within detection window
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
        
        // Pattern detected! Determine follow duration dynamically
        // Follow until: cursor becomes idle, new click, or time limit
        var followUntil = clickTime + followTimeLimit
        
        // Find the last active moment (when cursor was still moving)
        var lastActiveTime = firstMove.timestamp
        var lastPosition = firstMove.position
        
        for event in relevantMoves {
            if event.timestamp <= firstMove.timestamp { continue }
            
            let timeSinceLast = event.timestamp - lastActiveTime
            let distance = hypot(event.position.x - lastPosition.x,
                               event.position.y - lastPosition.y)
            
            // If cursor moved significantly, update last active time
            if distance > 0.005 {  // Small movement threshold
                lastActiveTime = event.timestamp
                lastPosition = event.position
            } else if timeSinceLast > idleThreshold {
                // Cursor has been idle for too long
                followUntil = lastActiveTime + 0.3  // Grace period after last movement
                break
            }
        }
        
        // Ensure we have at least some follow time after the last movement
        if let lastMove = relevantMoves.last {
            let dynamicEnd = lastMove.timestamp + 0.5
            followUntil = min(followUntil, dynamicEnd)
        }
        
        // Clamp to reasonable bounds
        followUntil = max(followUntil, clickTime + config.zoomInDuration + config.holdMin)
        
        return (true, followUntil, relevantMoves)
    }
    
    // MARK: - Follow Mode Keyframes
    
    /// Generates smooth follow keyframes using spring physics
    /// Camera follows cursor with natural spring-based motion
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
        
        // Sample cursor positions at high frequency
        let sampleInterval: TimeInterval = 1.0 / 60.0  // 60fps sampling for smooth input
        var rawSamples: [(time: TimeInterval, position: CGPoint)] = []
        rawSamples.append((startTime, fromPosition))
        
        var lastSampleTime = startTime
        
        for event in moveEvents {
            guard event.timestamp >= startTime && event.timestamp <= endTime else { continue }
            
            if event.timestamp - lastSampleTime >= sampleInterval {
                rawSamples.append((event.timestamp, event.position))
                lastSampleTime = event.timestamp
            }
        }
        
        // Ensure final position is captured
        if let lastEvent = moveEvents.last,
           lastEvent.timestamp > lastSampleTime,
           lastEvent.timestamp <= endTime {
            rawSamples.append((lastEvent.timestamp, lastEvent.position))
        }
        
        guard rawSamples.count >= 2 else {
            return keyframes
        }
        
        // Generate spring-interpolated keyframes
        // Camera "chases" cursor position with spring dynamics
        let spring = SpringAnimation.gentle  // Smooth following
        let outputInterval: TimeInterval = config.followKeyframeInterval  // Output rate
        
        var currentCameraPos = fromPosition
        var currentVelocity = CGPoint.zero
        var currentTime = startTime
        
        // Add initial keyframe
        keyframes.append(ZoomKeyframe(
            time: startTime,
            scale: scale,
            center: constrainCenterForCursor(fromPosition, cursorPosition: fromPosition, at: scale),
            easing: .easeOut
        ))
        
        // Simulate spring physics at each output interval
        while currentTime < endTime {
            currentTime += outputInterval
            if currentTime > endTime { currentTime = endTime }
            
            // Find target cursor position at this time
            let targetPosition = interpolateCursorPosition(at: currentTime, from: rawSamples)
            
            // Apply spring physics to camera position
            // This creates smooth "chasing" behavior
            let dt = outputInterval
            let springResult = applySpringStep(
                current: currentCameraPos,
                target: targetPosition,
                velocity: currentVelocity,
                spring: spring,
                dt: dt
            )
            
            currentCameraPos = springResult.position
            currentVelocity = springResult.velocity
            
            let constrainedCenter = constrainCenterForCursor(
                currentCameraPos,
                cursorPosition: targetPosition,
                at: scale
            )
            
            keyframes.append(ZoomKeyframe(
                time: currentTime,
                scale: scale,
                center: constrainedCenter,
                easing: .easeOut
            ))
        }
        
        return keyframes
    }
    
    /// Interpolate cursor position at a specific time from samples
    private func interpolateCursorPosition(
        at time: TimeInterval,
        from samples: [(time: TimeInterval, position: CGPoint)]
    ) -> CGPoint {
        guard !samples.isEmpty else { return .zero }
        guard samples.count > 1 else { return samples[0].position }
        
        // Find surrounding samples
        var beforeIndex = 0
        for (index, sample) in samples.enumerated() {
            if sample.time <= time {
                beforeIndex = index
            } else {
                break
            }
        }
        
        let afterIndex = min(beforeIndex + 1, samples.count - 1)
        
        if beforeIndex == afterIndex {
            return samples[beforeIndex].position
        }
        
        let before = samples[beforeIndex]
        let after = samples[afterIndex]
        
        let t = (time - before.time) / (after.time - before.time)
        
        // Smooth step interpolation
        let smoothT = t * t * (3 - 2 * t)
        
        return CGPoint(
            x: before.position.x + (after.position.x - before.position.x) * smoothT,
            y: before.position.y + (after.position.y - before.position.y) * smoothT
        )
    }
    
    /// Apply one step of spring physics simulation
    private func applySpringStep(
        current: CGPoint,
        target: CGPoint,
        velocity: CGPoint,
        spring: SpringAnimation,
        dt: TimeInterval
    ) -> (position: CGPoint, velocity: CGPoint) {
        // Spring force: F = -k * displacement - damping * velocity
        // Using spring parameters: tension (k), friction (damping)
        let displacement = CGPoint(
            x: current.x - target.x,
            y: current.y - target.y
        )
        
        // Calculate spring force
        let springForce = CGPoint(
            x: -spring.tension * displacement.x - spring.friction * velocity.x,
            y: -spring.tension * displacement.y - spring.friction * velocity.y
        )
        
        // Apply force (F = ma, assume mass = 1 for simplicity)
        let acceleration = springForce
        
        // Update velocity and position using semi-implicit Euler
        let newVelocity = CGPoint(
            x: velocity.x + acceleration.x * CGFloat(dt),
            y: velocity.y + acceleration.y * CGFloat(dt)
        )
        
        let newPosition = CGPoint(
            x: current.x + newVelocity.x * CGFloat(dt),
            y: current.y + newVelocity.y * CGFloat(dt)
        )
        
        return (newPosition, newVelocity)
    }
    
    // MARK: - Keyframe Generation
    
    private func generateZoomIn(
        to center: CGPoint,
        scale: CGFloat,
        startTime: TimeInterval,
        duration: TimeInterval,
        holdUntil: TimeInterval? = nil
    ) -> [ZoomKeyframe] {
        var keyframes: [ZoomKeyframe] = []
        
        // Use spring physics for cinematic "fast start, smooth landing" feel
        let spring = SpringAnimation.stiff  // Fast and responsive
        let steps = 12  // More steps for smoother animation (30fps equivalent)
        
        for i in 0...steps {
            let t = TimeInterval(i) / TimeInterval(steps)
            let time = startTime + t * duration
            
            // Spring progress creates natural deceleration
            let springProgress = spring.progress(at: t * spring.settlingTime * 0.5)
            
            let currentScale = 1.0 + (scale - 1.0) * springProgress
            
            // For each frame, directly calculate the optimal center for current scale
            // This ensures cursor is always visible regardless of zoom level
            let currentConstrainedCenter = constrainCenterForCursor(
                center,  // Target position
                cursorPosition: center,
                at: currentScale
            )
            
            keyframes.append(ZoomKeyframe(
                time: time,
                scale: currentScale,
                center: currentConstrainedCenter,
                easing: .easeOut
            ))
        }
        
        // Add Hold keyframe if specified and there's enough time
        if let holdUntil {
            let finalCenter = constrainCenterForCursor(center, cursorPosition: center, at: scale)
            let holdTime = max(startTime + duration, holdUntil)
            if holdTime > startTime + duration + 0.1 {  // At least 0.1s of hold
                keyframes.append(ZoomKeyframe(
                    time: holdTime,
                    scale: scale,
                    center: finalCenter,
                    easing: .linear
                ))
            }
        }
        
        return keyframes
    }
    
    /// Generate zoom in keyframes using spring physics for natural motion
    /// Used when interrupting zoom out or for smooth transitions
    private func generateSpringZoomIn(
        from fromCenter: CGPoint,
        fromScale: CGFloat,
        to toCenter: CGPoint,
        toScale: CGFloat,
        startTime: TimeInterval,
        duration: TimeInterval
    ) -> [ZoomKeyframe] {
        var keyframes: [ZoomKeyframe] = []
        
        let spring = SpringAnimation.stiff  // Fast and snappy for responsive feel
        let steps = 15  // More steps for smoother animation
        
        for i in 0...steps {
            let t = TimeInterval(i) / TimeInterval(steps)
            let time = startTime + t * duration
            
            // Use spring physics for both scale and position
            let springProgress = spring.progress(at: t * spring.settlingTime * 0.6)
            
            let scale = fromScale + (toScale - fromScale) * springProgress
            let center = CGPoint(
                x: fromCenter.x + (toCenter.x - fromCenter.x) * springProgress,
                y: fromCenter.y + (toCenter.y - fromCenter.y) * springProgress
            )
            
            let constrainedCenter = constrainCenterForCursor(center, cursorPosition: toCenter, at: scale)
            keyframes.append(ZoomKeyframe(
                time: time,
                scale: scale,
                center: constrainedCenter,
                easing: .easeOut
            ))
        }
        
        return keyframes
    }
    
    private func generateZoomOut(
        from center: CGPoint,
        startTime: TimeInterval,
        duration: TimeInterval
    ) -> [ZoomKeyframe] {
        var keyframes: [ZoomKeyframe] = []
        
        let fromScale = dynamicZoom.zoomScaleWithCornerBoost(at: center)
        let toScale: CGFloat = 1.0
        let toCenter = CGPoint(x: 0.5, y: 0.5)
        
        // Use spring physics for natural zoom out motion
        let spring = SpringAnimation.gentle
        let steps = 15  // More steps for smoother animation
        
        for i in 0...steps {
            let t = TimeInterval(i) / TimeInterval(steps)
            let time = startTime + t * duration
            
            // Spring progress for natural deceleration
            let springProgress = spring.progress(at: t * spring.settlingTime * 0.4)
            
            let scale = fromScale + (toScale - fromScale) * springProgress
            let currentCenter = CGPoint(
                x: center.x + (toCenter.x - center.x) * springProgress,
                y: center.y + (toCenter.y - center.y) * springProgress
            )
            
            keyframes.append(ZoomKeyframe(
                time: time,
                scale: scale,
                center: currentCenter,
                easing: .easeIn
            ))
        }
        
        return keyframes
    }
    
    private func generateSmoothTransition(
        from fromCenter: CGPoint,
        to toCenter: CGPoint,
        fromScale: CGFloat,
        toScale: CGFloat,
        startTime: TimeInterval,
        duration: TimeInterval
    ) -> [ZoomKeyframe] {
        var keyframes: [ZoomKeyframe] = []
        
        // Use cursor-aware constraint for target position
        let constrainedTo = constrainCenterForCursor(toCenter, cursorPosition: toCenter, at: toScale)
        
        // Use spring physics for natural motion
        let spring = SpringAnimation.default
        let steps = 12  // More steps for smoother animation
        
        for i in 0...steps {
            let t = TimeInterval(i) / TimeInterval(steps)
            let time = startTime + t * duration
            
            // Spring progress for natural deceleration
            let springProgress = spring.progress(at: t * spring.settlingTime * 0.5)
            
            let scale = fromScale + (toScale - fromScale) * springProgress
            let center = CGPoint(
                x: fromCenter.x + (constrainedTo.x - fromCenter.x) * springProgress,
                y: fromCenter.y + (constrainedTo.y - fromCenter.y) * springProgress
            )
            
            let constrainedCenter = constrainCenterForCursor(center, cursorPosition: toCenter, at: scale)
            keyframes.append(ZoomKeyframe(
                time: time,
                scale: scale,
                center: constrainedCenter,
                easing: .easeOut  // EaseOut for smooth landing
            ))
        }
        
        return keyframes
    }
    
    private func generateLargeDistanceTransition(
        from fromCenter: CGPoint,
        to toCenter: CGPoint,
        startTime: TimeInterval,
        currentScale: CGFloat
    ) -> [ZoomKeyframe] {
        var keyframes: [ZoomKeyframe] = []
        
        let distance = hypot(toCenter.x - fromCenter.x, toCenter.y - fromCenter.y)
        
        // Strategy: Two-phase spring transition
        // Phase 1: Spring zoom out + partial move
        // Phase 2: Spring zoom in + complete move
        
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
        // Use cursor-aware constraint for the final target position
        let finalConstrainedCenter = constrainCenterForCursor(toCenter, cursorPosition: toCenter, at: newScale)
        
        // Adaptive transition duration based on distance
        let baseDuration: TimeInterval = 0.25
        let distanceScale: TimeInterval = 0.5
        let totalDuration = baseDuration + (Double(distance) * distanceScale)
        
        // Use spring physics for natural motion
        let springOut = SpringAnimation.default   // For zoom out phase
        let springIn = SpringAnimation.stiff      // Faster for zoom in phase
        
        // Generate keyframes with spring physics
        let steps = 16  // More steps for smoother animation
        for i in 0...steps {
            let t = TimeInterval(i) / TimeInterval(steps)  // 0.0 to 1.0
            let time = startTime + t * totalDuration
            
            let scale: CGFloat
            let center: CGPoint
            let easing: EasingCurve
            
            if t < 0.5 {
                // Phase 1: Spring zoom out while starting to move
                let localT = t * 2.0  // 0.0 to 1.0
                let springProgress = springOut.progress(at: localT * springOut.settlingTime * 0.4)
                
                scale = currentScale + (intermediateScale - currentScale) * springProgress
                center = CGPoint(
                    x: fromCenter.x + (finalConstrainedCenter.x - fromCenter.x) * springProgress * 0.6,
                    y: fromCenter.y + (finalConstrainedCenter.y - fromCenter.y) * springProgress * 0.6
                )
                easing = .easeIn
            } else {
                // Phase 2: Spring zoom in while completing movement
                let localT = (t - 0.5) * 2.0  // 0.0 to 1.0
                let springProgress = springIn.progress(at: localT * springIn.settlingTime * 0.5)
                
                scale = intermediateScale + (newScale - intermediateScale) * springProgress
                let moveProgress = 0.6 + springProgress * 0.4  // Start from 60%, complete to 100%
                center = CGPoint(
                    x: fromCenter.x + (finalConstrainedCenter.x - fromCenter.x) * moveProgress,
                    y: fromCenter.y + (finalConstrainedCenter.y - fromCenter.y) * moveProgress
                )
                easing = .easeOut
            }
            
            // Apply cursor-aware constraint to center based on current scale
            let constrainedCenter = constrainCenterForCursor(center, cursorPosition: toCenter, at: scale)
            keyframes.append(ZoomKeyframe(
                time: time,
                scale: scale,
                center: constrainedCenter,
                easing: easing
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
                let constrainedCenter = constrainCenterForCursor(point.position, cursorPosition: point.position, at: scale)
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
    
    /// Constrain center while ensuring cursor remains visible with surrounding context
    /// For corner/edge clicks, position center so cursor is visible but not at extreme edge of view
    private func constrainCenterForCursor(
        _ center: CGPoint,
        cursorPosition: CGPoint,
        at scale: CGFloat
    ) -> CGPoint {
        guard scale > 1.0 else { return center }
        
        let visibleWidth = 1.0 / scale
        let visibleHeight = 1.0 / scale
        let halfWidth = visibleWidth / 2
        let halfHeight = visibleHeight / 2
        
        // Valid center range (ensures visible area stays within screen bounds)
        let minCenterX = halfWidth
        let maxCenterX = 1.0 - halfWidth
        let minCenterY = halfHeight
        let maxCenterY = 1.0 - halfHeight
        
        // Safety margin from edge - cursor should not be at the absolute edge of view
        let safetyMargin: CGFloat = 0.05  // 5% from edge
        let safeHalfWidth = halfWidth * (1.0 - safetyMargin)
        let safeHalfHeight = halfHeight * (1.0 - safetyMargin)
        
        var resultCenter = CGPoint.zero
        
        // X axis: Calculate center that keeps cursor visible
        // First calculate the range of centers that keep cursor within safe zone
        let minCenterForCursorX = cursorPosition.x - safeHalfWidth
        let maxCenterForCursorX = cursorPosition.x + safeHalfWidth
        
        // Find intersection with valid center range
        let validMinX = max(minCenterX, minCenterForCursorX)
        let validMaxX = min(maxCenterX, maxCenterForCursorX)
        
        if validMinX <= validMaxX {
            // Valid range exists - prefer cursor near center of view
            resultCenter.x = max(validMinX, min(validMaxX, cursorPosition.x))
        } else {
            // No valid range with safety margin - cursor at extreme corner
            // Choose the boundary that keeps cursor most visible
            if cursorPosition.x > 0.5 {
                resultCenter.x = maxCenterX
            } else {
                resultCenter.x = minCenterX
            }
        }
        
        // Y axis: Same logic
        let minCenterForCursorY = cursorPosition.y - safeHalfHeight
        let maxCenterForCursorY = cursorPosition.y + safeHalfHeight
        
        let validMinY = max(minCenterY, minCenterForCursorY)
        let validMaxY = min(maxCenterY, maxCenterForCursorY)
        
        if validMinY <= validMaxY {
            resultCenter.y = max(validMinY, min(validMaxY, cursorPosition.y))
        } else {
            if cursorPosition.y > 0.5 {
                resultCenter.y = maxCenterY
            } else {
                resultCenter.y = minCenterY
            }
        }
        
        // Final check: If cursor still outside visible area, adjust
        // This handles extreme corners where safety margin cannot be maintained
        let cursorRelX = cursorPosition.x - resultCenter.x
        let cursorRelY = cursorPosition.y - resultCenter.y
        
        // Cursor must be within view (use full halfWidth, not safe)
        if cursorRelX > halfWidth * 0.98 {
            // Push center right to bring cursor into view
            let adjustment = cursorRelX - halfWidth * 0.95
            resultCenter.x = min(maxCenterX, resultCenter.x + adjustment)
        } else if cursorRelX < -halfWidth * 0.98 {
            let adjustment = -halfWidth * 0.95 - cursorRelX
            resultCenter.x = max(minCenterX, resultCenter.x - adjustment)
        }
        
        if cursorRelY > halfHeight * 0.98 {
            let adjustment = cursorRelY - halfHeight * 0.95
            resultCenter.y = min(maxCenterY, resultCenter.y + adjustment)
        } else if cursorRelY < -halfHeight * 0.98 {
            let adjustment = -halfHeight * 0.95 - cursorRelY
            resultCenter.y = max(minCenterY, resultCenter.y - adjustment)
        }
        
        return resultCenter
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
