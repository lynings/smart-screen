import Foundation

/// Easing curves for smooth zoom animations
enum EasingCurve: String, Codable, CaseIterable, Equatable {
    case linear
    case easeIn
    case easeOut
    case easeInOut
    
    /// Calculate the eased value for a given progress (0-1)
    func value(at progress: Double) -> Double {
        let t = max(0, min(1, progress))
        
        switch self {
        case .linear:
            return t
            
        case .easeIn:
            // Quadratic ease in: t^2
            return t * t
            
        case .easeOut:
            // Quadratic ease out: 1 - (1-t)^2
            return 1 - (1 - t) * (1 - t)
            
        case .easeInOut:
            // Quadratic ease in-out
            if t < 0.5 {
                return 2 * t * t
            } else {
                return 1 - pow(-2 * t + 2, 2) / 2
            }
        }
    }
    
    var displayName: String {
        switch self {
        case .linear: return "Linear"
        case .easeIn: return "Ease In"
        case .easeOut: return "Ease Out"
        case .easeInOut: return "Ease In-Out"
        }
    }
}
