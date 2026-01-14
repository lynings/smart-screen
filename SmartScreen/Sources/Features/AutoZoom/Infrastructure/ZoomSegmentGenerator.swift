import Foundation
import CoreGraphics

/// Generates ZoomSegments from click events
/// Handles click merging and segment merging according to AC rules
final class ZoomSegmentGenerator {
    
    // MARK: - Configuration
    
    struct Config {
        /// Default segment duration (AC-TR-01: 1.2s)
        let defaultDuration: TimeInterval
        
        /// Default zoom scale
        let defaultZoomScale: CGFloat
        
        /// Time threshold for merging clicks (AC-TR-03: 0.3s)
        let clickMergeTime: TimeInterval
        
        /// Distance threshold for merging clicks in pixels (AC-TR-03: 100px)
        /// Will be converted to normalized distance based on screen size
        let clickMergeDistancePixels: CGFloat
        
        /// Time gap threshold for merging segments (AC-AN-03: 0.3s)
        let segmentMergeGap: TimeInterval
        
        /// Distance threshold for merging segments (AC-AN-03: 50px normalized ~0.05)
        let segmentMergeDistance: CGFloat
        
        /// Minimum zoom scale (AC-FR-03)
        let minZoomScale: CGFloat
        
        /// Maximum zoom scale (AC-FR-03)
        let maxZoomScale: CGFloat
        
        /// Easing curve for animations
        let easing: EasingCurve
        
        static let `default` = Config(
            defaultDuration: 1.2,
            defaultZoomScale: 2.0,
            clickMergeTime: 0.5,           // Increased from 0.3s for better merging
            clickMergeDistancePixels: 200,  // Increased from 100px for better merging
            segmentMergeGap: 0.5,           // Increased from 0.3s
            segmentMergeDistance: 0.10,     // Increased from 0.05
            minZoomScale: 1.0,
            maxZoomScale: 6.0,
            easing: .easeInOut
        )
        
        init(
            defaultDuration: TimeInterval = 1.2,
            defaultZoomScale: CGFloat = 2.0,
            clickMergeTime: TimeInterval = 0.3,
            clickMergeDistancePixels: CGFloat = 100,
            segmentMergeGap: TimeInterval = 0.3,
            segmentMergeDistance: CGFloat = 0.05,
            minZoomScale: CGFloat = 1.0,
            maxZoomScale: CGFloat = 6.0,
            easing: EasingCurve = .easeInOut
        ) {
            self.defaultDuration = defaultDuration
            self.defaultZoomScale = defaultZoomScale
            self.clickMergeTime = clickMergeTime
            self.clickMergeDistancePixels = clickMergeDistancePixels
            self.segmentMergeGap = segmentMergeGap
            self.segmentMergeDistance = segmentMergeDistance
            self.minZoomScale = minZoomScale
            self.maxZoomScale = maxZoomScale
            self.easing = easing
        }
    }
    
    // MARK: - Properties
    
    private let config: Config
    
    // MARK: - Initialization
    
    init(config: Config = .default) {
        self.config = config
    }
    
    // MARK: - Generation
    
    /// Generate ZoomSegments from a cursor track session
    /// AC-TR-01: Only clicks trigger segments
    /// AC-TR-02: No clicks = no segments
    func generate(from session: CursorTrackSession, screenSize: CGSize) -> [AutoZoomSegment] {
        let clicks = session.clickEvents
        
        // AC-TR-02: No clicks = no segments
        guard !clicks.isEmpty else { return [] }
        
        // 1. Merge nearby clicks (AC-TR-03)
        let mergedClickGroups = mergeClicks(clicks, screenSize: screenSize)
        
        // 2. Generate segments from click groups
        var segments = mergedClickGroups.map { clickGroup in
            createSegment(from: clickGroup, screenSize: screenSize)
        }
        
        // 3. Merge adjacent segments (AC-AN-03)
        segments = mergeSegments(segments)
        
        // 4. Apply boundary constraints (AC-FR-02)
        segments = segments.map { applyBoundaryConstraints($0) }
        
        // 5. Truncate segments at keyboard events (typing triggers zoom out)
        segments = truncateAtKeyboardEvents(segments, keyboardEvents: session.typingEvents)
        
        return segments
    }
    
    // MARK: - Keyboard Event Handling
    
    /// Truncate segments when keyboard typing is detected
    /// This causes zoom to return to normal when user starts typing
    private func truncateAtKeyboardEvents(
        _ segments: [AutoZoomSegment],
        keyboardEvents: [KeyboardEvent]
    ) -> [AutoZoomSegment] {
        guard !keyboardEvents.isEmpty else { return segments }
        
        return segments.compactMap { segment in
            // Find first keyboard event during this segment's hold/zoomOut phase
            // (We allow zoom-in to complete before checking for keyboard events)
            let keyEventDuringSegment = keyboardEvents.first { event in
                event.timestamp > segment.zoomInEndTime && event.timestamp < segment.endTime
            }
            
            guard let keyEvent = keyEventDuringSegment else {
                return segment
            }
            
            // Calculate new end time: start zoom-out immediately at key event
            let zoomOutDuration = segment.zoomOutDuration
            let newEndTime = keyEvent.timestamp + zoomOutDuration
            
            // Only truncate if it actually shortens the segment
            guard newEndTime < segment.endTime else { return segment }
            
            // Create truncated segment
            return AutoZoomSegment(
                id: segment.id,
                timeRange: segment.startTime...newEndTime,
                focusCenter: segment.focusCenter,
                zoomScale: segment.zoomScale,
                easing: segment.easing
            )
        }
    }
    
    // MARK: - Click Merging (AC-TR-03)
    
    /// Merge clicks that are close in time and space
    private func mergeClicks(_ clicks: [ClickEvent], screenSize: CGSize) -> [[ClickEvent]] {
        guard !clicks.isEmpty else { return [] }
        
        // Sort by timestamp
        let sorted = clicks.sorted { $0.timestamp < $1.timestamp }
        
        // Convert pixel distance to normalized distance
        let normalizedMergeDistance = config.clickMergeDistancePixels / max(screenSize.width, screenSize.height)
        
        var groups: [[ClickEvent]] = []
        var currentGroup: [ClickEvent] = [sorted[0]]
        
        for i in 1..<sorted.count {
            let current = sorted[i]
            let previous = currentGroup.last!
            
            let timeDiff = current.timestamp - previous.timestamp
            let distance = hypot(
                current.position.x - previous.position.x,
                current.position.y - previous.position.y
            )
            
            // Check if should merge
            if timeDiff < config.clickMergeTime && distance < normalizedMergeDistance {
                currentGroup.append(current)
            } else {
                groups.append(currentGroup)
                currentGroup = [current]
            }
        }
        
        // Add last group
        groups.append(currentGroup)
        
        return groups
    }
    
    // MARK: - Segment Creation
    
    /// Create a segment from a group of clicks
    private func createSegment(from clicks: [ClickEvent], screenSize: CGSize) -> AutoZoomSegment {
        let clampedScale = min(max(config.defaultZoomScale, config.minZoomScale), config.maxZoomScale)
        
        if clicks.count == 1 {
            return AutoZoomSegment.fromClick(
                clicks[0],
                duration: config.defaultDuration,
                zoomScale: clampedScale,
                easing: config.easing
            )
        } else {
            return AutoZoomSegment.fromClicks(
                clicks,
                duration: config.defaultDuration,
                zoomScale: clampedScale,
                easing: config.easing
            )
        }
    }
    
    // MARK: - Segment Merging (AC-AN-03)
    
    /// Merge adjacent segments that are close in time and space
    private func mergeSegments(_ segments: [AutoZoomSegment]) -> [AutoZoomSegment] {
        guard segments.count > 1 else { return segments }
        
        var result: [AutoZoomSegment] = []
        var current = segments[0]
        
        for i in 1..<segments.count {
            let next = segments[i]
            
            if current.canMerge(with: next, maxGap: config.segmentMergeGap, maxDistance: config.segmentMergeDistance) {
                current = current.merged(with: next)
            } else {
                result.append(current)
                current = next
            }
        }
        
        result.append(current)
        return result
    }
    
    // MARK: - Boundary Constraints (AC-FR-02)
    
    /// Apply boundary constraints to ensure focus doesn't exceed screen bounds
    private func applyBoundaryConstraints(_ segment: AutoZoomSegment) -> AutoZoomSegment {
        let scale = segment.zoomScale
        guard scale > 1.0 else { return segment }
        
        // Calculate visible area at this scale
        let visibleWidth = 1.0 / scale
        let visibleHeight = 1.0 / scale
        let halfWidth = visibleWidth / 2
        let halfHeight = visibleHeight / 2
        
        // Clamp center to keep visible area in bounds
        let constrainedX = max(halfWidth, min(1.0 - halfWidth, segment.focusCenter.x))
        let constrainedY = max(halfHeight, min(1.0 - halfHeight, segment.focusCenter.y))
        
        let constrainedCenter = CGPoint(x: constrainedX, y: constrainedY)
        
        // Return new segment if center changed
        if constrainedCenter != segment.focusCenter {
            return AutoZoomSegment(
                id: segment.id,
                timeRange: segment.timeRange,
                focusCenter: constrainedCenter,
                zoomScale: segment.zoomScale,
                easing: segment.easing
            )
        }
        
        return segment
    }
}
