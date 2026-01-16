import Foundation
import CoreGraphics

/// Animation style presets for Auto Zoom transitions
///
/// Each style maps to specific spring physics parameters that create
/// different "feels" for the zoom animations.
enum AnimationStyle: String, Codable, CaseIterable, Equatable {
    
    /// Slow - Gentle, relaxed transitions
    /// Best for: tutorials, detailed explanations, calm content
    case slow
    
    /// Mellow - Natural, balanced transitions (default)
    /// Best for: general use, balanced pacing
    case mellow
    
    /// Quick - Responsive, snappy transitions
    /// Best for: fast-paced content, action-oriented demos
    case quick
    
    /// Rapid - Ultra-fast, energetic transitions
    /// Best for: gaming content, high-energy presentations
    case rapid
    
    // MARK: - Display Properties
    
    var displayName: String {
        switch self {
        case .slow: return "Slow"
        case .mellow: return "Mellow"
        case .quick: return "Quick"
        case .rapid: return "Rapid"
        }
    }
    
    var description: String {
        switch self {
        case .slow: return "Gentle, relaxed transitions"
        case .mellow: return "Natural, balanced feel"
        case .quick: return "Responsive and snappy"
        case .rapid: return "Ultra-fast and energetic"
        }
    }
    
    // MARK: - Spring Configuration
    
    /// The spring animation parameters for this style
    var spring: SpringAnimation {
        switch self {
        case .slow:
            // Low tension, high friction, high mass = slow, smooth, no bounce
            return SpringAnimation(tension: 80, friction: 20, mass: 1.5)
            
        case .mellow:
            // Balanced parameters = natural feel with slight softness
            return SpringAnimation(tension: 150, friction: 22, mass: 1.0)
            
        case .quick:
            // High tension, medium friction = fast response, controlled
            return SpringAnimation(tension: 220, friction: 24, mass: 0.8)
            
        case .rapid:
            // Very high tension, lower friction = very fast with slight bounce
            return SpringAnimation(tension: 300, friction: 28, mass: 0.6)
        }
    }
    
    // MARK: - Timing Configuration
    
    /// Estimated duration for a typical zoom transition (0 -> target scale)
    var typicalDuration: TimeInterval {
        switch self {
        case .slow: return 0.6
        case .mellow: return 0.4
        case .quick: return 0.25
        case .rapid: return 0.15
        }
    }
    
    /// Zoom in duration
    var zoomInDuration: TimeInterval {
        switch self {
        case .slow: return 0.5
        case .mellow: return 0.35
        case .quick: return 0.2
        case .rapid: return 0.12
        }
    }
    
    /// Zoom out duration (slightly longer for natural feel)
    var zoomOutDuration: TimeInterval {
        switch self {
        case .slow: return 0.6
        case .mellow: return 0.45
        case .quick: return 0.28
        case .rapid: return 0.18
        }
    }
    
    /// Pan transition duration
    var panDuration: TimeInterval {
        switch self {
        case .slow: return 0.45
        case .mellow: return 0.3
        case .quick: return 0.2
        case .rapid: return 0.12
        }
    }
    
    // MARK: - Follow Mode Configuration
    
    /// Smoothing factor for cursor following (0 = no smoothing, 1 = instant)
    var followSmoothingFactor: CGFloat {
        switch self {
        case .slow: return 0.15
        case .mellow: return 0.25
        case .quick: return 0.4
        case .rapid: return 0.6
        }
    }
    
    /// Lookahead factor for predictive following
    var followLookaheadFactor: CGFloat {
        switch self {
        case .slow: return 0.05
        case .mellow: return 0.1
        case .quick: return 0.15
        case .rapid: return 0.2
        }
    }
    
    // MARK: - Compatibility
    
    /// Convert to legacy EasingCurve (for backward compatibility)
    var legacyEasing: EasingCurve {
        switch self {
        case .slow: return .easeInOut
        case .mellow: return .easeInOut
        case .quick: return .easeOut
        case .rapid: return .easeOut
        }
    }
}

// MARK: - Factory Methods

extension AnimationStyle {
    
    /// Create animation style from a speed preference (0-100)
    /// - Parameter speed: 0 = slowest, 100 = fastest
    static func fromSpeed(_ speed: Int) -> AnimationStyle {
        switch speed {
        case 0..<25: return .slow
        case 25..<50: return .mellow
        case 50..<75: return .quick
        default: return .rapid
        }
    }
    
    /// Get spring animation with custom adjustments
    func springWithAdjustment(
        tensionMultiplier: CGFloat = 1.0,
        frictionMultiplier: CGFloat = 1.0
    ) -> SpringAnimation {
        let base = spring
        return SpringAnimation(
            tension: base.tension * tensionMultiplier,
            friction: base.friction * frictionMultiplier,
            mass: base.mass
        )
    }
}

// MARK: - Identifiable

extension AnimationStyle: Identifiable {
    var id: String { rawValue }
}
