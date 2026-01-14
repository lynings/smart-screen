import Foundation
import Observation

/// ViewModel for Auto Zoom settings and state management
/// Auto Zoom 2.0: Continuous zoom with dynamic scale and smooth transitions
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
    
    // MARK: - Computed
    
    var settings: AutoZoomSettings {
        AutoZoomSettings(
            isEnabled: isEnabled,
            zoomLevel: zoomLevel,
            easing: easing,
            idleTimeout: idleTimeout,
            dynamicZoomEnabled: dynamicZoomEnabled,
            zoomOutOnKeyboard: zoomOutOnKeyboard,
            cursorScale: cursorScale
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
    }
    
    // MARK: - Preset Type
    
    enum Preset: String, CaseIterable, Identifiable {
        case subtle = "Subtle"
        case normal = "Normal"
        case dramatic = "Dramatic"
        
        var id: String { rawValue }
        
        var description: String {
            switch self {
            case .subtle: return "轻柔 - 1.5x 缩放，4秒超时"
            case .normal: return "标准 - 2.0x 缩放，3秒超时"
            case .dramatic: return "强烈 - 2.5x 缩放，2.5秒超时"
            }
        }
    }
}
