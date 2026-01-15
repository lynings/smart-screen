import Foundation

/// Configuration for attention scoring system
struct AttentionConfig {
    /// Weight for click events
    let clickWeight: Double
    
    /// Weight for keyboard events (focus change, Tab, Enter)
    let keyboardWeight: Double
    
    /// Weight for hover/movement events
    let hoverWeight: Double
    
    /// Exponential decay time constant (seconds)
    /// Scores decay as: score *= exp(-dt / decayTau)
    let decayTau: TimeInterval
    
    /// Merge radius for attention regions (normalized coordinates)
    /// Events within this radius are considered same region
    let mergeRadius: CGFloat
    
    /// Confirmation threshold (T_confirm) in seconds
    /// New triggers must persist this long to interrupt Hold phase
    let confirmThreshold: TimeInterval
    
    init(
        clickWeight: Double = 1.0,
        keyboardWeight: Double = 0.9,
        hoverWeight: Double = 0.3,
        decayTau: TimeInterval = 0.7,
        mergeRadius: CGFloat = 0.08,
        confirmThreshold: TimeInterval = 0.18
    ) {
        self.clickWeight = clickWeight
        self.keyboardWeight = keyboardWeight
        self.hoverWeight = hoverWeight
        self.decayTau = decayTau
        self.mergeRadius = mergeRadius
        self.confirmThreshold = confirmThreshold
    }
}
