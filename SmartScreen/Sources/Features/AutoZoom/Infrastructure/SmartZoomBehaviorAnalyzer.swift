import Foundation
import CoreGraphics

/// Keyframe representing zoom state at a specific time
struct SmartZoomKeyframe: Equatable {
    let time: TimeInterval
    let scale: CGFloat
    let center: CGPoint  // Normalized (0-1)
    
    static let idle = SmartZoomKeyframe(time: 0, scale: 1.0, center: CGPoint(x: 0.5, y: 0.5))
}

/// Timeline of smart zoom keyframes for smooth playback
struct SmartZoomTimeline: Equatable {
    let keyframes: [SmartZoomKeyframe]
    let duration: TimeInterval
    
    /// Get interpolated zoom state at a specific time
    func state(at time: TimeInterval) -> (scale: CGFloat, center: CGPoint) {
        guard !keyframes.isEmpty else {
            return (1.0, CGPoint(x: 0.5, y: 0.5))
        }
        
        // Find surrounding keyframes
        guard let afterIndex = keyframes.firstIndex(where: { $0.time > time }) else {
            // After last keyframe
            let last = keyframes.last!
            return (last.scale, last.center)
        }
        
        if afterIndex == 0 {
            // Before first keyframe
            let first = keyframes.first!
            return (first.scale, first.center)
        }
        
        // Interpolate between keyframes
        let before = keyframes[afterIndex - 1]
        let after = keyframes[afterIndex]
        
        let timeDelta = after.time - before.time
        guard timeDelta > 0 else {
            return (before.scale, before.center)
        }
        
        let progress = (time - before.time) / timeDelta
        let easedProgress = CGFloat(EasingCurve.easeInOut.value(at: progress))
        
        let scale = before.scale + (after.scale - before.scale) * easedProgress
        let centerX = before.center.x + (after.center.x - before.center.x) * easedProgress
        let centerY = before.center.y + (after.center.y - before.center.y) * easedProgress
        
        return (scale, CGPoint(x: centerX, y: centerY))
    }
    
    static func empty(duration: TimeInterval) -> SmartZoomTimeline {
        SmartZoomTimeline(keyframes: [], duration: duration)
    }
}

/// Analyzes user behavior to generate smart zoom timeline
/// Implements intelligent zoom triggering based on cursor stability
final class SmartZoomBehaviorAnalyzer {
    
    // MARK: - Properties
    
    private let config: ZoomBehaviorConfig
    
    // MARK: - Initialization
    
    init(config: ZoomBehaviorConfig = .default) {
        self.config = config
    }
    
    // MARK: - Analysis
    
    /// Generate smart zoom timeline from cursor session
    func analyze(session: CursorTrackSession) -> SmartZoomTimeline {
        guard !session.events.isEmpty else {
            return .empty(duration: session.duration)
        }
        
        // 1. Build activity events
        let activities = buildActivityEvents(from: session)
        
        // 2. Process events through state machine
        let keyframes = processEvents(activities, duration: session.duration)
        
        return SmartZoomTimeline(keyframes: keyframes, duration: session.duration)
    }
    
    // MARK: - Private Methods
    
    private func buildActivityEvents(from session: CursorTrackSession) -> [ActivityEvent] {
        session.events.map { event in
            ActivityEvent(
                type: event.isClick ? .click : .move,
                position: event.position,
                timestamp: event.timestamp
            )
        }
    }
    
    private func processEvents(_ events: [ActivityEvent], duration: TimeInterval) -> [SmartZoomKeyframe] {
        guard !events.isEmpty else { return [] }
        
        var keyframes: [SmartZoomKeyframe] = []
        var state: ZoomBehaviorState = .idle
        var lastClickTime: TimeInterval = -10
        var lastClickPosition: CGPoint = .zero
        var recentClicks: [TimeInterval] = []
        
        // Initial keyframe
        keyframes.append(SmartZoomKeyframe(time: 0, scale: 1.0, center: CGPoint(x: 0.5, y: 0.5)))
        
        for event in events {
            let time = event.timestamp
            
            // Update click frequency tracking
            if event.type == .click {
                recentClicks.append(time)
                recentClicks = recentClicks.filter { time - $0 < 1.0 } // Keep last 1 second
            }
            
            let clickFrequency = Double(recentClicks.count)
            let isHighFrequency = clickFrequency > config.maxClickFrequency
            
            // Calculate movement metrics
            let movementDistance = event.type == .click ? 
                hypot(event.position.x - lastClickPosition.x, event.position.y - lastClickPosition.y) : 0
            let isLargeMovement = movementDistance > config.largeMovementThreshold
            
            // State machine transitions
            switch state {
            case .idle:
                if event.type == .click && !isHighFrequency {
                    // Start observing
                    state = .observing(since: time, position: event.position)
                }
                
            case .observing(let since, let observePosition):
                if event.type == .click {
                    let distance = hypot(event.position.x - observePosition.x, event.position.y - observePosition.y)
                    
                    if isHighFrequency || distance > config.stableAreaRadius * 3 {
                        // Too much activity, reset
                        state = .observing(since: time, position: event.position)
                    } else if time - since >= config.stabilizationTime {
                        // Cursor stabilized, start zoom
                        let constrainedCenter = constrainCenter(observePosition, scale: config.targetScale)
                        state = .zoomingIn(startTime: time, from: 1.0, to: config.targetScale, center: constrainedCenter)
                        
                        // Add zoom-in keyframes
                        keyframes.append(SmartZoomKeyframe(time: time, scale: 1.0, center: constrainedCenter))
                        keyframes.append(SmartZoomKeyframe(
                            time: time + config.zoomInDuration,
                            scale: config.targetScale,
                            center: constrainedCenter
                        ))
                    }
                } else {
                    // Check if cursor moved out of stable area
                    let distance = hypot(event.position.x - observePosition.x, event.position.y - observePosition.y)
                    if distance > config.stableAreaRadius {
                        // Reset observation with new position
                        state = .observing(since: time, position: event.position)
                    } else if time - since >= config.stabilizationTime {
                        // Cursor stabilized without click, still zoom
                        let constrainedCenter = constrainCenter(observePosition, scale: config.targetScale)
                        state = .zoomingIn(startTime: time, from: 1.0, to: config.targetScale, center: constrainedCenter)
                        
                        keyframes.append(SmartZoomKeyframe(time: time, scale: 1.0, center: constrainedCenter))
                        keyframes.append(SmartZoomKeyframe(
                            time: time + config.zoomInDuration,
                            scale: config.targetScale,
                            center: constrainedCenter
                        ))
                    }
                }
                
            case .zoomingIn(let startTime, _, let to, let center):
                if time >= startTime + config.zoomInDuration {
                    // Zoom in complete
                    state = .zoomed(center: center, scale: to)
                }
                
                // Check for interruption
                if event.type == .click && isLargeMovement {
                    // Large movement detected, zoom out first
                    state = .zoomingOut(startTime: time, from: config.targetScale, center: center)
                    keyframes.append(SmartZoomKeyframe(time: time, scale: config.targetScale, center: center))
                    keyframes.append(SmartZoomKeyframe(
                        time: time + config.zoomOutDuration,
                        scale: 1.0,
                        center: center
                    ))
                }
                
            case .zoomed(let center, let scale):
                if event.type == .click {
                    let distance = hypot(event.position.x - center.x, event.position.y - center.y)
                    
                    if isLargeMovement || isHighFrequency {
                        // Large movement or high frequency, zoom out
                        state = .zoomingOut(startTime: time, from: scale, center: center)
                        keyframes.append(SmartZoomKeyframe(time: time, scale: scale, center: center))
                        keyframes.append(SmartZoomKeyframe(
                            time: time + config.zoomOutDuration,
                            scale: 1.0,
                            center: center
                        ))
                    } else if distance > config.stableAreaRadius * 2 {
                        // Moderate movement, smoothly pan to new position
                        let newCenter = constrainCenter(event.position, scale: scale)
                        state = .zoomed(center: newCenter, scale: scale)
                        keyframes.append(SmartZoomKeyframe(
                            time: time + 0.2, // Smooth pan
                            scale: scale,
                            center: newCenter
                        ))
                    }
                }
                
            case .zoomingOut(let startTime, _, let center):
                if time >= startTime + config.zoomOutDuration {
                    // Zoom out complete, enter cooldown
                    state = .cooldown(since: time, lastPosition: event.position)
                }
                
            case .cooldown(let since, _):
                if event.type == .click {
                    if time - since >= config.cooldownDuration {
                        // Cooldown complete, start observing again
                        state = .observing(since: time, position: event.position)
                    }
                } else {
                    // Update last position during cooldown
                    state = .cooldown(since: since, lastPosition: event.position)
                }
            }
            
            // Update last click tracking
            if event.type == .click {
                lastClickTime = time
                lastClickPosition = event.position
            }
        }
        
        // Ensure we end at 1.0x if still zoomed
        if case .zoomed(let center, let scale) = state {
            let endTime = duration - config.zoomOutDuration
            if endTime > (keyframes.last?.time ?? 0) {
                keyframes.append(SmartZoomKeyframe(time: endTime, scale: scale, center: center))
                keyframes.append(SmartZoomKeyframe(time: duration, scale: 1.0, center: center))
            }
        }
        
        return keyframes.sorted { $0.time < $1.time }
    }
    
    // MARK: - Boundary Constraints
    
    private func constrainCenter(_ position: CGPoint, scale: CGFloat) -> CGPoint {
        guard scale > 1.0 else { return position }
        
        let visibleWidth = 1.0 / scale
        let visibleHeight = 1.0 / scale
        let halfWidth = visibleWidth / 2
        let halfHeight = visibleHeight / 2
        
        let constrainedX = max(halfWidth, min(1.0 - halfWidth, position.x))
        let constrainedY = max(halfHeight, min(1.0 - halfHeight, position.y))
        
        return CGPoint(x: constrainedX, y: constrainedY)
    }
}

// MARK: - MouseEvent Extension

private extension MouseEvent {
    var isClick: Bool {
        switch type {
        case .leftClick, .rightClick, .doubleClick:
            return true
        case .move:
            return false
        }
    }
}
