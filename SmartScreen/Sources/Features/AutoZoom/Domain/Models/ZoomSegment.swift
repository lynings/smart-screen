import Foundation

/// Represents a zoom animation segment in the video timeline
struct ZoomSegment: Codable, Equatable {
    
    // MARK: - Properties
    
    /// Start time of the zoom segment (in seconds)
    let startTime: TimeInterval
    
    /// End time of the zoom segment (in seconds)
    let endTime: TimeInterval
    
    /// Center point of the zoom (normalized 0-1)
    let center: CGPoint
    
    /// Target zoom scale (1.0 = no zoom, 2.0 = 2x zoom)
    let scale: CGFloat
    
    /// Easing curve for zoom animation
    let easing: EasingCurve
    
    // MARK: - Animation Phases
    
    /// Portion of segment duration for zoom-in animation (0-1)
    private let zoomInRatio: Double = 0.2
    
    /// Portion of segment duration for zoom-out animation (0-1)
    private let zoomOutRatio: Double = 0.2
    
    // MARK: - Computed Properties
    
    /// Total duration of the segment
    var duration: TimeInterval {
        endTime - startTime
    }
    
    // MARK: - Time Queries
    
    /// Check if a given time falls within this segment
    func contains(time: TimeInterval) -> Bool {
        time >= startTime && time <= endTime
    }
    
    /// Calculate linear progress (0-1) for a given time
    func progress(at time: TimeInterval) -> Double {
        guard duration > 0 else { return 0 }
        let rawProgress = (time - startTime) / duration
        return max(0, min(1, rawProgress))
    }
    
    // MARK: - Scale Calculation
    
    /// Calculate the current zoom scale at a given time
    /// Returns 1.0 outside the segment, interpolated value during transitions
    func scale(at time: TimeInterval) -> CGFloat {
        guard contains(time: time) else {
            return 1.0
        }
        
        let progress = self.progress(at: time)
        
        // Determine which phase we're in
        if progress < zoomInRatio {
            // Zoom-in phase: scale from 1.0 to target
            let phaseProgress = progress / zoomInRatio
            let easedProgress = easing.value(at: phaseProgress)
            return 1.0 + (scale - 1.0) * CGFloat(easedProgress)
            
        } else if progress > (1.0 - zoomOutRatio) {
            // Zoom-out phase: scale from target back to 1.0
            let phaseProgress = (progress - (1.0 - zoomOutRatio)) / zoomOutRatio
            let easedProgress = easing.value(at: phaseProgress)
            return scale - (scale - 1.0) * CGFloat(easedProgress)
            
        } else {
            // Hold phase: maintain target scale
            return scale
        }
    }
    
    /// Calculate the current center point at a given time
    /// Returns center for the segment, or nil outside
    func center(at time: TimeInterval) -> CGPoint? {
        guard contains(time: time) else {
            return nil
        }
        return center
    }
}
