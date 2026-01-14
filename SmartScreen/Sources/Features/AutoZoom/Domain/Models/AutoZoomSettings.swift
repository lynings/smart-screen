import Foundation

/// Configuration for auto zoom behavior (AC-CF-01)
struct AutoZoomSettings: Codable, Equatable {
    
    // MARK: - Constants (AC-CF-01)
    
    static let zoomLevelRange: ClosedRange<CGFloat> = 1.0...6.0
    static let durationRange: ClosedRange<TimeInterval> = 0.6...3.0
    static let cursorSmoothingRange: ClosedRange<Double> = 0.1...0.5
    static let cursorScaleRange: ClosedRange<CGFloat> = 1.0...3.0
    
    // MARK: - Core Properties
    
    /// Whether auto zoom is enabled
    var isEnabled: Bool
    
    /// Zoom scale (1.0x - 6.0x, default 2.0x)
    var zoomLevel: CGFloat
    
    /// Total segment duration (0.6s - 3.0s, default 1.2s)
    /// Note: This is the total duration, split into 25% zoom in, 50% hold, 25% zoom out
    var duration: TimeInterval
    
    /// Hold time portion (calculated from duration, not directly set)
    var holdTime: TimeInterval {
        duration * 0.5
    }
    
    /// Easing curve for animations
    var easing: EasingCurve
    
    // MARK: - Follow Mode (AC-FU-01, AC-FU-02)
    
    /// Whether to follow cursor during zoom (default: false = static center)
    var followCursor: Bool
    
    /// Smoothing factor for cursor following (0.1-0.5, higher = faster follow)
    var cursorSmoothing: Double
    
    // MARK: - Cursor Enhancement (AC-CU-01, AC-CU-02, AC-CU-03)
    
    /// Scale factor for cursor during zoom (1.0x - 3.0x, default 1.6x)
    var cursorScale: CGFloat
    
    /// Whether to auto-hide cursor when stationary
    var cursorAutoHide: Bool
    
    // MARK: - Initialization
    
    init(
        isEnabled: Bool = true,
        zoomLevel: CGFloat = 2.0,
        duration: TimeInterval = 1.2,
        easing: EasingCurve = .easeInOut,
        followCursor: Bool = false,
        cursorSmoothing: Double = 0.2,
        cursorScale: CGFloat = 1.6,
        cursorAutoHide: Bool = false
    ) {
        self.isEnabled = isEnabled
        self.zoomLevel = Self.clamp(zoomLevel, to: Self.zoomLevelRange)
        self.duration = Self.clamp(duration, to: Self.durationRange)
        self.easing = easing
        self.followCursor = followCursor
        self.cursorSmoothing = Self.clamp(cursorSmoothing, to: Self.cursorSmoothingRange)
        self.cursorScale = Self.clamp(cursorScale, to: Self.cursorScaleRange)
        self.cursorAutoHide = cursorAutoHide
    }
    
    // MARK: - Presets
    
    static let `default` = AutoZoomSettings()
    
    static let subtle = AutoZoomSettings(
        zoomLevel: 1.5,
        duration: 1.0,
        easing: .easeInOut
    )
    
    static let normal = AutoZoomSettings(
        zoomLevel: 2.0,
        duration: 1.2,
        easing: .easeInOut
    )
    
    static let dramatic = AutoZoomSettings(
        zoomLevel: 2.5,
        duration: 1.5,
        easing: .easeInOut
    )
    
    // MARK: - Private Helpers
    
    private static func clamp<T: Comparable>(_ value: T, to range: ClosedRange<T>) -> T {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
