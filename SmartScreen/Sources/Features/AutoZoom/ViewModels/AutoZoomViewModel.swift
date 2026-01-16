import Foundation
import Observation

/// ViewModel for Auto Zoom settings and state management
/// Auto Zoom 2.0: Continuous zoom with dynamic scale and smooth transitions
/// v5.0: Spring physics, animation presets, pre-click buffer, continuous follow
@Observable
@MainActor
final class AutoZoomViewModel {
    
    // MARK: - Core Settings
    
    var isEnabled: Bool = true
    var zoomLevel: CGFloat = 2.0
    var easing: EasingCurve = .easeInOut
    var cursorScale: CGFloat = 1.6
    
    // MARK: - Auto Zoom 2.0 Settings
    
    /// Idle timeout before auto zoom-out (seconds)
    var idleTimeout: TimeInterval = 3.0
    
    /// Enable dynamic zoom scale (larger at edges/corners, smaller at center)
    var dynamicZoomEnabled: Bool = true
    
    /// Zoom out when keyboard activity detected
    var zoomOutOnKeyboard: Bool = true
    
    // MARK: - v5.0 Settings
    
    /// Animation style preset (Slow/Mellow/Quick/Rapid)
    var animationStyle: AnimationStyle = .mellow
    
    /// Enable pre-click buffer (start zoom before click)
    var enablePreClickBuffer: Bool = true
    
    /// Pre-click buffer duration in seconds
    var preClickBufferDuration: TimeInterval = 0.15
    
    /// Enable continuous cursor following during zoomed state
    var enableContinuousFollow: Bool = true
    
    // MARK: - Computed
    
    var settings: AutoZoomSettings {
        AutoZoomSettings(
            isEnabled: isEnabled,
            zoomLevel: zoomLevel,
            easing: easing,
            idleTimeout: idleTimeout,
            dynamicZoomEnabled: dynamicZoomEnabled,
            zoomOutOnKeyboard: zoomOutOnKeyboard,
            cursorScale: cursorScale,
            animationStyle: animationStyle,
            enablePreClickBuffer: enablePreClickBuffer,
            preClickBufferDuration: preClickBufferDuration,
            enableContinuousFollow: enableContinuousFollow
        )
    }
    
    // MARK: - Presets
    
    func applyPreset(_ preset: Preset) {
        switch preset {
        case .subtle:
            applySettings(AutoZoomSettings.subtle)
        case .normal:
            applySettings(AutoZoomSettings.normal)
        case .dramatic:
            applySettings(AutoZoomSettings.dramatic)
        }
    }
    
    private func applySettings(_ settings: AutoZoomSettings) {
        zoomLevel = settings.zoomLevel
        idleTimeout = settings.idleTimeout
        easing = settings.easing
        animationStyle = settings.animationStyle
        enablePreClickBuffer = settings.enablePreClickBuffer
        preClickBufferDuration = settings.preClickBufferDuration
        enableContinuousFollow = settings.enableContinuousFollow
    }
    
    // MARK: - Preset Type
    
    enum Preset: String, CaseIterable, Identifiable {
        case subtle = "Subtle"
        case normal = "Normal"
        case dramatic = "Dramatic"
        
        var id: String { rawValue }
        
        var description: String {
            switch self {
            case .subtle: return "轻柔 - 1.5x 缩放，慢速动画"
            case .normal: return "标准 - 2.0x 缩放，自然动画"
            case .dramatic: return "强烈 - 2.5x 缩放，快速动画"
            }
        }
    }
}
