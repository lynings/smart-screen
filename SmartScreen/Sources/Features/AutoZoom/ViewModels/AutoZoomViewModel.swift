import Foundation
import Observation

/// ViewModel for Auto Zoom settings and state management
@Observable
@MainActor
final class AutoZoomViewModel {
    
    // MARK: - Settings
    
    var isEnabled: Bool = true
    var zoomLevel: CGFloat = 2.0
    var duration: TimeInterval = 1.2
    var easing: EasingCurve = .easeInOut
    var followCursor: Bool = true  // AC-FU-01, AC-FU-02
    
    // MARK: - Computed
    
    var settings: AutoZoomSettings {
        AutoZoomSettings(
            isEnabled: isEnabled,
            zoomLevel: zoomLevel,
            duration: duration,
            easing: easing,
            followCursor: followCursor
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
        duration = settings.duration
        easing = settings.easing
    }
    
    // MARK: - Preset Type
    
    enum Preset: String, CaseIterable, Identifiable {
        case subtle = "Subtle"
        case normal = "Normal"
        case dramatic = "Dramatic"
        
        var id: String { rawValue }
    }
}
