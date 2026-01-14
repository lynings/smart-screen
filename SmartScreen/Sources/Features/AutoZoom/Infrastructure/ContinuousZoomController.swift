import Foundation
import CoreGraphics

/// Configuration for continuous zoom behavior
struct ContinuousZoomConfig {
    /// Base zoom scale
    let baseZoomScale: CGFloat
    
    /// Duration for zoom in animation
    let zoomInDuration: TimeInterval
    
    /// Duration for zoom out animation
    let zoomOutDuration: TimeInterval
    
    /// Duration for pan/transition animation
    let panDuration: TimeInterval
    
    /// Idle timeout before auto zoom-out (seconds)
    let idleTimeout: TimeInterval
    
    /// Distance threshold for "large distance" (normalized)
    /// Beyond this, zoom out first then pan
    let largeDistanceThreshold: CGFloat
    
    /// Area threshold for debounce (ratio of screen area)
    let debounceAreaThreshold: CGFloat
    
    /// Time window for debounce detection
    let debounceTimeWindow: TimeInterval
    
    /// Easing curve for animations
    let easing: EasingCurve
    
    static let `default` = ContinuousZoomConfig(
        baseZoomScale: 2.0,
        zoomInDuration: 0.3,
        zoomOutDuration: 0.4,
        panDuration: 0.3,
        idleTimeout: 3.0,
        largeDistanceThreshold: 0.3,
        debounceAreaThreshold: 0.15,
        debounceTimeWindow: 0.5,
        easing: .easeInOut
    )
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
        keyboardEvents: [KeyboardEvent]
    ) -> [ZoomKeyframe] {
        var keyframes: [ZoomKeyframe] = []
        
        let clicks = cursorSession.clickEvents.sorted { $0.timestamp < $1.timestamp }
        guard !clicks.isEmpty else { return keyframes }
        
        // Add initial idle keyframe
        keyframes.append(.idle(at: 0))
        
        var currentState: ZoomControlState = .idle
        var lastZoomCenter: CGPoint?
        var lastActivityTime: TimeInterval = 0
        
        // Process each click event
        for (index, click) in clicks.enumerated() {
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
            if clickTime - lastActivityTime > config.idleTimeout {
                if case .zoomed = currentState, let center = lastZoomCenter {
                    keyframes.append(contentsOf: generateZoomOut(
                        from: center,
                        startTime: lastActivityTime + config.idleTimeout,
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
                keyframes.append(contentsOf: generateZoomIn(
                    to: clickPosition,
                    scale: zoomScale,
                    startTime: clickTime,
                    duration: config.zoomInDuration
                ))
                currentState = .zoomed(at: clickPosition)
                lastZoomCenter = clickPosition
                
            case .zoomed(let currentCenter), .following(let currentCenter):
                let distance = hypot(currentCenter.x - clickPosition.x, currentCenter.y - clickPosition.y)
                
                // Check if should debounce
                if shouldDebounce(currentClick: click, previousClicks: Array(clicks[0..<index]), currentCenter: currentCenter) {
                    // Stay at current position, just update activity time
                    lastActivityTime = clickTime
                    continue
                }
                
                if distance > config.largeDistanceThreshold {
                    // Large distance: zoom out -> pan -> zoom in
                    keyframes.append(contentsOf: generateLargeDistanceTransition(
                        from: currentCenter,
                        to: clickPosition,
                        startTime: clickTime,
                        currentScale: dynamicZoom.zoomScaleWithCornerBoost(at: currentCenter)
                    ))
                } else {
                    // Small distance: smooth pan transition
                    let newScale = dynamicZoom.zoomScaleWithCornerBoost(at: clickPosition)
                    keyframes.append(contentsOf: generateSmoothTransition(
                        from: currentCenter,
                        to: clickPosition,
                        fromScale: dynamicZoom.zoomScaleWithCornerBoost(at: currentCenter),
                        toScale: newScale,
                        startTime: clickTime,
                        duration: config.panDuration
                    ))
                }
                
                currentState = .zoomed(at: clickPosition)
                lastZoomCenter = clickPosition
                
            default:
                break
            }
            
            lastActivityTime = clickTime
        }
        
        // Add cursor following keyframes between clicks
        keyframes = addFollowingKeyframes(
            to: keyframes,
            cursorSession: cursorSession,
            clicks: clicks
        )
        
        // Add final zoom out if needed
        if case .zoomed = currentState, let center = lastZoomCenter {
            let endTime = cursorSession.duration
            if endTime - lastActivityTime > config.idleTimeout {
                keyframes.append(contentsOf: generateZoomOut(
                    from: center,
                    startTime: lastActivityTime + config.idleTimeout,
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
    
    // MARK: - Keyframe Generation
    
    private func generateZoomIn(
        to center: CGPoint,
        scale: CGFloat,
        startTime: TimeInterval,
        duration: TimeInterval
    ) -> [ZoomKeyframe] {
        let constrainedCenter = constrainCenter(center, at: scale)
        return [
            ZoomKeyframe(time: startTime, scale: 1.0, center: constrainedCenter, easing: config.easing),
            ZoomKeyframe(time: startTime + duration, scale: scale, center: constrainedCenter, easing: config.easing)
        ]
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
        
        // Phase 1: Zoom out
        let zoomOutEnd = startTime + config.zoomOutDuration
        keyframes.append(ZoomKeyframe(time: startTime, scale: currentScale, center: fromCenter, easing: config.easing))
        keyframes.append(ZoomKeyframe(time: zoomOutEnd, scale: 1.0, center: fromCenter, easing: config.easing))
        
        // Phase 2: Pan to new position (while zoomed out)
        let panEnd = zoomOutEnd + config.panDuration * 0.5
        keyframes.append(ZoomKeyframe(time: panEnd, scale: 1.0, center: toCenter, easing: config.easing))
        
        // Phase 3: Zoom in at new position
        let newScale = dynamicZoom.zoomScaleWithCornerBoost(at: toCenter)
        let constrainedTo = constrainCenter(toCenter, at: newScale)
        let zoomInEnd = panEnd + config.zoomInDuration
        keyframes.append(ZoomKeyframe(time: zoomInEnd, scale: newScale, center: constrainedTo, easing: config.easing))
        
        return keyframes
    }
    
    private func addFollowingKeyframes(
        to keyframes: [ZoomKeyframe],
        cursorSession: CursorTrackSession,
        clicks: [ClickEvent]
    ) -> [ZoomKeyframe] {
        var result = keyframes
        
        // For each pair of consecutive clicks, add following keyframes
        for i in 0..<(clicks.count - 1) {
            let currentClick = clicks[i]
            let nextClick = clicks[i + 1]
            
            let gapStart = currentClick.timestamp + config.zoomInDuration
            let gapEnd = nextClick.timestamp
            
            // Only add following if gap is significant
            guard gapEnd - gapStart > 0.3 else { continue }
            
            // Sample cursor positions in this gap
            let positions = cursorSession.cursorPoints.filter {
                $0.timestamp > gapStart && $0.timestamp < gapEnd
            }
            
            // Add following keyframes at regular intervals
            let interval: TimeInterval = 0.2
            var time = gapStart + interval
            
            while time < gapEnd - 0.1 {
                if let position = cursorSession.positionAt(time: time) {
                    let scale = dynamicZoom.zoomScaleWithCornerBoost(at: position)
                    let constrainedCenter = constrainCenter(position, at: scale)
                    result.append(ZoomKeyframe(
                        time: time,
                        scale: scale,
                        center: constrainedCenter,
                        easing: .linear
                    ))
                }
                time += interval
            }
        }
        
        return result
    }
    
    // MARK: - Helper Methods
    
    private func hasKeyboardActivity(at time: TimeInterval, events: [KeyboardEvent]) -> Bool {
        events.contains { event in
            let timeDiff = abs(time - event.timestamp)
            return timeDiff < 0.5 && event.type == .keyDown
        }
    }
    
    private func shouldDebounce(
        currentClick: ClickEvent,
        previousClicks: [ClickEvent],
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
}
