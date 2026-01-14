import Foundation

/// Analyzes cursor activity and generates smart zoom segments
final class SmartZoomAnalyzer {
    
    // MARK: - Configuration
    
    /// Minimum time between separate zoom segments
    private let mergeThreshold: TimeInterval = 1.5
    
    /// Time before trigger to start zoom (anticipation)
    private let anticipationTime: TimeInterval = 0.2
    
    /// Keyframe interval for focus following
    private let keyframeInterval: TimeInterval = 0.1
    
    // MARK: - Dependencies
    
    private let activityAnalyzer = ActivityAnalyzer()
    
    // MARK: - Analysis
    
    /// Analyze a cursor track session and generate smart zoom segments
    func analyze(
        session: CursorTrackSession,
        settings: AutoZoomSettings
    ) -> [SmartZoomSegment] {
        guard settings.isEnabled else { return [] }
        guard !session.events.isEmpty else { return [] }
        
        // 1. Analyze activity windows
        let activityWindows = activityAnalyzer.analyze(session: session)
        guard !activityWindows.isEmpty else { return [] }
        
        // 2. Find trigger points (clicks, dwells, activity clusters)
        let triggers = findTriggers(
            session: session,
            activityWindows: activityWindows,
            settings: settings
        )
        
        guard !triggers.isEmpty else { return [] }
        
        // 3. Merge nearby triggers
        let mergedTriggers = mergeTriggers(triggers)
        
        // 4. Generate segments with focus following
        let segments = mergedTriggers.compactMap { triggerInfo in
            createSegment(
                trigger: triggerInfo,
                session: session,
                activityWindows: activityWindows,
                settings: settings
            )
        }
        
        return segments
    }
    
    // MARK: - Trigger Detection
    
    private struct TriggerInfo {
        let trigger: ZoomTrigger
        let time: TimeInterval
        let suggestedScale: CGFloat
    }
    
    private func findTriggers(
        session: CursorTrackSession,
        activityWindows: [ActivityWindow],
        settings: AutoZoomSettings
    ) -> [TriggerInfo] {
        var triggers: [TriggerInfo] = []
        
        // 1. Click triggers
        for click in session.clickEvents {
            let window = findWindow(at: click.timestamp, in: activityWindows)
            let scale = min(window?.suggestedZoomLevel ?? settings.zoomLevel, settings.zoomLevel)
            
            triggers.append(TriggerInfo(
                trigger: .click(position: click.position),
                time: click.timestamp,
                suggestedScale: scale
            ))
        }
        
        // 2. Dwell triggers
        for window in activityWindows where window.isDwell {
            // Skip if there's already a click trigger nearby
            let hasNearbyClick = triggers.contains { abs($0.time - window.timeRange.lowerBound) < 0.5 }
            if !hasNearbyClick {
                triggers.append(TriggerInfo(
                    trigger: .dwell(position: window.centroid, duration: window.dwellDuration ?? 0.5),
                    time: window.timeRange.lowerBound,
                    suggestedScale: window.suggestedZoomLevel
                ))
            }
        }
        
        // 3. Activity cluster triggers (high activity in small area)
        for window in activityWindows where window.isHighActivity && window.areaRatio < 0.1 {
            let hasNearbyTrigger = triggers.contains { abs($0.time - window.timeRange.lowerBound) < 0.5 }
            if !hasNearbyTrigger {
                triggers.append(TriggerInfo(
                    trigger: .activityCluster(region: window.boundingBox),
                    time: window.timeRange.lowerBound,
                    suggestedScale: window.suggestedZoomLevel
                ))
            }
        }
        
        // Sort by time
        return triggers.sorted { $0.time < $1.time }
    }
    
    private func findWindow(at time: TimeInterval, in windows: [ActivityWindow]) -> ActivityWindow? {
        windows.first { $0.timeRange.contains(time) }
    }
    
    // MARK: - Trigger Merging
    
    private func mergeTriggers(_ triggers: [TriggerInfo]) -> [TriggerInfo] {
        guard !triggers.isEmpty else { return [] }
        
        var merged: [TriggerInfo] = []
        var currentGroup: [TriggerInfo] = [triggers[0]]
        
        for i in 1..<triggers.count {
            let prev = triggers[i - 1]
            let curr = triggers[i]
            
            if curr.time - prev.time < mergeThreshold {
                currentGroup.append(curr)
            } else {
                // Merge current group and start new one
                if let mergedTrigger = mergeGroup(currentGroup) {
                    merged.append(mergedTrigger)
                }
                currentGroup = [curr]
            }
        }
        
        // Don't forget last group
        if let mergedTrigger = mergeGroup(currentGroup) {
            merged.append(mergedTrigger)
        }
        
        return merged
    }
    
    private func mergeGroup(_ group: [TriggerInfo]) -> TriggerInfo? {
        guard !group.isEmpty else { return nil }
        
        // Use highest priority trigger
        let sorted = group.sorted { $0.trigger.priority > $1.trigger.priority }
        let primary = sorted[0]
        
        // Use maximum scale from group
        let maxScale = group.map(\.suggestedScale).max() ?? primary.suggestedScale
        
        return TriggerInfo(
            trigger: primary.trigger,
            time: primary.time,
            suggestedScale: maxScale
        )
    }
    
    // MARK: - Segment Creation
    
    private func createSegment(
        trigger: TriggerInfo,
        session: CursorTrackSession,
        activityWindows: [ActivityWindow],
        settings: AutoZoomSettings
    ) -> SmartZoomSegment? {
        let startTime = max(0, trigger.time - anticipationTime)
        let totalDuration = settings.duration + settings.holdTime + settings.duration
        let endTime = min(startTime + totalDuration, session.duration)
        
        // Generate keyframes with focus following
        let keyframes = generateKeyframes(
            startTime: startTime,
            endTime: endTime,
            trigger: trigger,
            session: session,
            settings: settings
        )
        
        guard !keyframes.isEmpty else { return nil }
        
        return SmartZoomSegment(
            timeRange: startTime...endTime,
            trigger: trigger.trigger,
            keyframes: keyframes,
            easing: settings.easing
        )
    }
    
    private func generateKeyframes(
        startTime: TimeInterval,
        endTime: TimeInterval,
        trigger: TriggerInfo,
        session: CursorTrackSession,
        settings: AutoZoomSettings
    ) -> [FocusKeyframe] {
        var keyframes: [FocusKeyframe] = []
        
        let zoomInEnd = startTime + settings.duration
        let zoomOutStart = endTime - settings.duration
        
        // Generate keyframes at regular intervals
        var time = startTime
        while time <= endTime {
            // Calculate scale at this time
            let scale: CGFloat
            if time < zoomInEnd {
                // Zoom in phase
                let progress = (time - startTime) / settings.duration
                scale = 1.0 + (trigger.suggestedScale - 1.0) * CGFloat(progress)
            } else if time > zoomOutStart {
                // Zoom out phase
                let progress = (time - zoomOutStart) / settings.duration
                scale = trigger.suggestedScale - (trigger.suggestedScale - 1.0) * CGFloat(progress)
            } else {
                // Hold phase
                scale = trigger.suggestedScale
            }
            
            // Get cursor position at this time (for focus following)
            let cursorPosition = session.positionAt(time: time) ?? trigger.trigger.position
            
            // Calculate focus center (smoothed cursor position with boundary constraints)
            let center = calculateFocusCenter(
                cursorPosition: cursorPosition,
                scale: scale,
                margin: 0.1  // 10% margin (normalized)
            )
            
            // Calculate velocity for prediction
            let velocity = calculateVelocity(at: time, session: session)
            
            keyframes.append(FocusKeyframe(
                time: time,
                center: center,
                scale: scale,
                velocity: velocity
            ))
            
            time += keyframeInterval
        }
        
        // Ensure we have the exact end time
        if keyframes.last?.time != endTime {
            let lastKeyframe = keyframes.last!
            keyframes.append(FocusKeyframe(
                time: endTime,
                center: lastKeyframe.center,
                scale: 1.0,
                velocity: .zero
            ))
        }
        
        return keyframes
    }
    
    private func calculateFocusCenter(
        cursorPosition: CGPoint,
        scale: CGFloat,
        margin: CGFloat
    ) -> CGPoint {
        // Start with cursor position as center
        var center = cursorPosition
        
        // Calculate visible area at this scale
        let halfWidth = (1.0 / scale) / 2
        let halfHeight = (1.0 / scale) / 2
        
        // Clamp center to keep visible rect in bounds
        center.x = max(halfWidth, min(1.0 - halfWidth, center.x))
        center.y = max(halfHeight, min(1.0 - halfHeight, center.y))
        
        return center
    }
    
    private func calculateVelocity(at time: TimeInterval, session: CursorTrackSession) -> CGPoint {
        let delta: TimeInterval = 0.1
        
        guard let pos1 = session.positionAt(time: time - delta),
              let pos2 = session.positionAt(time: time + delta) else {
            return .zero
        }
        
        return CGPoint(
            x: (pos2.x - pos1.x) / CGFloat(delta * 2),
            y: (pos2.y - pos1.y) / CGFloat(delta * 2)
        )
    }
}
