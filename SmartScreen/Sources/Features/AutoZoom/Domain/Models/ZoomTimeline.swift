import Foundation
import CoreGraphics

/// Timeline containing all zoom segments for a recording
/// Provides efficient lookup of zoom state at any time
struct ZoomTimeline {
    
    // MARK: - Properties
    
    let segments: [AutoZoomSegment]
    let duration: TimeInterval
    
    // MARK: - Initialization
    
    init(segments: [AutoZoomSegment], duration: TimeInterval) {
        // Sort segments by start time
        self.segments = segments.sorted { $0.startTime < $1.startTime }
        self.duration = duration
    }
    
    // MARK: - State Query
    
    /// Get zoom state at a specific time (static center mode)
    func state(at time: TimeInterval) -> ZoomState {
        state(at: time, cursorPosition: nil, followCursor: false, smoothing: 0.2)
    }
    
    /// Get zoom state at a specific time with cursor following support (AC-FU-01, AC-FU-02)
    func state(
        at time: TimeInterval,
        cursorPosition: CGPoint?,
        followCursor: Bool,
        smoothing: Double
    ) -> ZoomState {
        // Find active segment
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
        
        // No active segment - return default state
        return ZoomState.idle
    }
    
    /// Find the active segment at a given time
    func activeSegment(at time: TimeInterval) -> AutoZoomSegment? {
        // Binary search could be used for large segment counts
        // For typical use cases, linear search is fine
        segments.first { $0.contains(time: time) }
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
        ZoomTimeline(segments: [], duration: duration)
    }
    
    /// Create timeline from a cursor session
    static func from(
        session: CursorTrackSession,
        screenSize: CGSize,
        config: ZoomSegmentGenerator.Config = .default
    ) -> ZoomTimeline {
        let generator = ZoomSegmentGenerator(config: config)
        let segments = generator.generate(from: session, screenSize: screenSize)
        return ZoomTimeline(segments: segments, duration: session.duration)
    }
}
