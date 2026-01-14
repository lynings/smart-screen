import Foundation

/// Configuration for auto zoom behavior (AC-CF-01)
/// Auto Zoom 2.0: Continuous zoom with dynamic scale, follow mode, and smooth transitions
struct AutoZoomSettings: Codable, Equatable {
    
    // MARK: - Constants (AC-CF-01)
    
    static let zoomLevelRange: ClosedRange<CGFloat> = 1.0...6.0
    static let durationRange: ClosedRange<TimeInterval> = 0.1...1.0
    static let idleTimeoutRange: ClosedRange<TimeInterval> = 1.0...10.0
    static let largeDistanceRange: ClosedRange<CGFloat> = 0.1...0.5
    static let cursorScaleRange: ClosedRange<CGFloat> = 1.0...3.0
    
    // MARK: - Core Properties
    
    /// Whether auto zoom is enabled
    var isEnabled: Bool
    
    /// Base zoom scale (1.0x - 6.0x, default 2.0x)
    /// Note: Actual zoom varies by position (edge/corner = larger, center = smaller)
    var zoomLevel: CGFloat
    
    /// Duration for zoom in/out animations (0.1s - 1.0s, default 0.3s)
    var zoomInDuration: TimeInterval
    
    /// Duration for zoom out animation
    var zoomOutDuration: TimeInterval
    
    /// Duration for pan/transition animation
    var panDuration: TimeInterval
    
    /// Easing curve for animations
    var easing: EasingCurve
    
    // MARK: - Continuous Zoom Behavior
    
    /// Idle timeout before auto zoom-out (seconds, default 3.0)
    /// Cursor must be stationary for this duration before zooming out
    var idleTimeout: TimeInterval
    
    /// Distance threshold for "large distance" transitions (normalized, default 0.3)
    /// Beyond this, zoom out first then pan to new position
    var largeDistanceThreshold: CGFloat
    
    /// Enable dynamic zoom scale based on screen position
    /// Edge/corner = larger zoom, center = smaller zoom
    var dynamicZoomEnabled: Bool
    
    // MARK: - Debounce Settings
    
    /// Area threshold for debounce (ratio of screen area, default 0.15)
    /// If activity is within this area ratio, maintain current zoom
    var debounceAreaThreshold: CGFloat
    
    /// Time window for debounce detection (default 0.5s)
    var debounceTimeWindow: TimeInterval
    
    // MARK: - Keyboard Behavior
    
    /// Zoom out when keyboard activity detected
    var zoomOutOnKeyboard: Bool
    
    // MARK: - Cursor Enhancement
    
    /// Scale factor for cursor/highlight during zoom (1.0x - 3.0x, default 1.6x)
    var cursorScale: CGFloat
    
    // MARK: - Legacy Compatibility
    
    /// Legacy property for backward compatibility
    var duration: TimeInterval {
        zoomInDuration + panDuration + zoomOutDuration
    }
    
    /// Legacy property
    var holdTime: TimeInterval {
        panDuration
    }
    
    /// Legacy: follow cursor is now always true in continuous mode
    var followCursor: Bool { true }
    
    /// Legacy: cursor smoothing
    var cursorSmoothing: Double { 0.2 }
    
    /// Legacy: cursor auto hide
    var cursorAutoHide: Bool { false }
    
    // MARK: - Initialization
    
    init(
        isEnabled: Bool = true,
        zoomLevel: CGFloat = 2.0,
        zoomInDuration: TimeInterval = 0.3,
        zoomOutDuration: TimeInterval = 0.4,
        panDuration: TimeInterval = 0.3,
        easing: EasingCurve = .easeInOut,
        idleTimeout: TimeInterval = 3.0,
        largeDistanceThreshold: CGFloat = 0.3,
        dynamicZoomEnabled: Bool = true,
        debounceAreaThreshold: CGFloat = 0.15,
        debounceTimeWindow: TimeInterval = 0.5,
        zoomOutOnKeyboard: Bool = true,
        cursorScale: CGFloat = 1.6
    ) {
        self.isEnabled = isEnabled
        self.zoomLevel = Self.clamp(zoomLevel, to: Self.zoomLevelRange)
        self.zoomInDuration = Self.clamp(zoomInDuration, to: Self.durationRange)
        self.zoomOutDuration = Self.clamp(zoomOutDuration, to: Self.durationRange)
        self.panDuration = Self.clamp(panDuration, to: Self.durationRange)
        self.easing = easing
        self.idleTimeout = Self.clamp(idleTimeout, to: Self.idleTimeoutRange)
        self.largeDistanceThreshold = Self.clamp(largeDistanceThreshold, to: Self.largeDistanceRange)
        self.dynamicZoomEnabled = dynamicZoomEnabled
        self.debounceAreaThreshold = debounceAreaThreshold
        self.debounceTimeWindow = debounceTimeWindow
        self.zoomOutOnKeyboard = zoomOutOnKeyboard
        self.cursorScale = Self.clamp(cursorScale, to: Self.cursorScaleRange)
    }
    
    // MARK: - Presets
    
    static let `default` = AutoZoomSettings()
    
    static let subtle = AutoZoomSettings(
        zoomLevel: 1.5,
        zoomInDuration: 0.4,
        zoomOutDuration: 0.5,
        panDuration: 0.3,
        idleTimeout: 4.0
    )
    
    static let normal = AutoZoomSettings(
        zoomLevel: 2.0,
        zoomInDuration: 0.3,
        zoomOutDuration: 0.4,
        panDuration: 0.3,
        idleTimeout: 3.0
    )
    
    static let dramatic = AutoZoomSettings(
        zoomLevel: 2.5,
        zoomInDuration: 0.25,
        zoomOutDuration: 0.35,
        panDuration: 0.25,
        idleTimeout: 2.5
    )
    
    // MARK: - Config Conversion
    
    /// Convert to ContinuousZoomConfig for the controller
    func toContinuousZoomConfig() -> ContinuousZoomConfig {
        ContinuousZoomConfig(
            baseZoomScale: zoomLevel,
            zoomInDuration: zoomInDuration,
            zoomOutDuration: zoomOutDuration,
            panDuration: panDuration,
            idleTimeout: idleTimeout,
            largeDistanceThreshold: largeDistanceThreshold,
            debounceAreaThreshold: debounceAreaThreshold,
            debounceTimeWindow: debounceTimeWindow,
            easing: easing
        )
    }
    
    // MARK: - Private Helpers
    
    private static func clamp<T: Comparable>(_ value: T, to range: ClosedRange<T>) -> T {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
