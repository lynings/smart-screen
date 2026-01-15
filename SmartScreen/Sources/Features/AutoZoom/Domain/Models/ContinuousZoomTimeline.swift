import Foundation
import CoreGraphics

/// Zoom state returned by the continuous zoom timeline
struct ContinuousZoomState: Equatable {
    let scale: CGFloat
    let center: CGPoint
    let isActive: Bool
    let phase: Phase
    
    enum Phase: Equatable {
        case idle
        case zoomIn
        case hold
        case zoomOut
    }
    
    static let idle = ContinuousZoomState(
        scale: 1.0,
        center: CGPoint(x: 0.5, y: 0.5),
        isActive: false,
        phase: .idle
    )
}

/// A continuous zoom timeline that provides smooth interpolation between keyframes
struct ContinuousZoomTimeline {
    
    // MARK: - Properties
    
    private let keyframes: [ZoomKeyframe]
    
    var isEmpty: Bool { keyframes.isEmpty }
    var count: Int { keyframes.count }
    
    var duration: TimeInterval {
        guard let last = keyframes.last else { return 0 }
        return last.time
    }
    
    // MARK: - Initialization
    
    init(keyframes: [ZoomKeyframe] = []) {
        // Ensure keyframes are sorted by time
        self.keyframes = keyframes.sorted { $0.time < $1.time }
    }
    
    // MARK: - Query
    
    /// Get the zoom state at a specific time with smooth interpolation
    func state(at time: TimeInterval) -> ContinuousZoomState {
        guard !keyframes.isEmpty else {
            return ContinuousZoomState.idle
        }
        
        // Before first keyframe
        if time <= keyframes.first!.time {
            let kf = keyframes.first!
            return ContinuousZoomState(
                scale: kf.scale,
                center: kf.center,
                isActive: kf.scale > 1.0,
                phase: .idle
            )
        }
        
        // After last keyframe
        if time >= keyframes.last!.time {
            let kf = keyframes.last!
            return ContinuousZoomState(
                scale: kf.scale,
                center: kf.center,
                isActive: kf.scale > 1.0,
                phase: .idle
            )
        }
        
        // Find surrounding keyframes and interpolate
        for i in 0..<(keyframes.count - 1) {
            let current = keyframes[i]
            let next = keyframes[i + 1]
            
            if time >= current.time && time <= next.time {
                let interpolated = ZoomKeyframe.interpolate(from: current, to: next, at: time)
                
                // Determine phase
                let phase: ContinuousZoomState.Phase
                if interpolated.scale > current.scale && current.scale < next.scale {
                    phase = .zoomIn
                } else if interpolated.scale < current.scale && current.scale > next.scale {
                    phase = .zoomOut
                } else if abs(interpolated.scale - 1.0) < 0.01 {
                    phase = .idle
                } else {
                    phase = .hold
                }
                
                return ContinuousZoomState(
                    scale: interpolated.scale,
                    center: interpolated.center,
                    isActive: interpolated.scale > 1.01,
                    phase: phase
                )
            }
        }
        
        return ContinuousZoomState.idle
    }
    
    /// Get keyframe at specific index
    func keyframe(at index: Int) -> ZoomKeyframe? {
        guard index >= 0 && index < keyframes.count else { return nil }
        return keyframes[index]
    }
    
    /// Get all keyframes in a time range
    func keyframes(in range: ClosedRange<TimeInterval>) -> [ZoomKeyframe] {
        keyframes.filter { range.contains($0.time) }
    }
}

// MARK: - Factory Methods

extension ContinuousZoomTimeline {
    
    /// Create timeline from cursor session and keyboard events
    static func from(
        cursorSession: CursorTrackSession,
        keyboardEvents: [KeyboardEvent] = [],
        config: ContinuousZoomConfig = .default,
        referenceSize: CGSize = CGSize(width: 1920, height: 1080),
        enableDiagnostics: Bool = false
    ) -> ContinuousZoomTimeline {
        let controller = ContinuousZoomController(config: config)
        let keyframes = controller.generateKeyframes(
            from: cursorSession,
            keyboardEvents: keyboardEvents,
            referenceSize: referenceSize
        )
        
        if enableDiagnostics {
            ZoomDiagnostics.printDiagnosticReport(session: cursorSession, keyframes: keyframes)
        }
        
        return ContinuousZoomTimeline(keyframes: keyframes)
    }
}
