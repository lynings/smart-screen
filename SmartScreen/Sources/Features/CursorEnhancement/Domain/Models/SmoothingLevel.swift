import Foundation

/// Smoothing intensity level for cursor trajectory
enum SmoothingLevel: String, CaseIterable, Codable {
    case low
    case medium
    case high
    
    /// EWMA smoothing factor (alpha)
    /// Higher value = more smoothing, more lag
    var smoothingFactor: Double {
        switch self {
        case .low: return 0.3
        case .medium: return 0.5
        case .high: return 0.7
        }
    }
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}
