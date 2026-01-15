import Foundation
import CoreGraphics

/// Scores unified events for Strategy B attention accumulation.
/// Maintains attention regions and provides decision logic for zoom triggering and hold interruption.
struct AttentionScorer {
    
    // MARK: - Configuration
    
    private let config: AttentionConfig
    
    // MARK: - State
    
    private var regions: [AttentionRegion] = []
    
    // MARK: - Legacy Weights (for backward compatibility)
    
    var clickWeight: Double { config.clickWeight }
    var typingWeight: Double { config.keyboardWeight }
    var largeMoveWeight: Double = 0.6
    var smallMoveWeight: Double { config.hoverWeight }
    
    // MARK: - Keyboard Context (minimal v1)
    
    /// Key codes for modifier keys on macOS hardware.
    /// - Note: This is not layout-dependent.
    private let modifierKeyCodes: Set<UInt16> = [
        55, 54, // Command (left/right)
        56, 60, // Shift (left/right)
        58, 61, // Option (left/right)
        59, 62, // Control (left/right)
        63      // Fn
    ]
    
    // MARK: - Initialization
    
    init(config: AttentionConfig = AttentionConfig()) {
        self.config = config
    }
    
    // MARK: - Event Weight (legacy method renamed)
    
    func eventWeight(for event: UnifiedEvent) -> Double {
        switch event {
        case .click:
            return config.clickWeight
            
        case .keyboard(let key):
            guard key.type == .keyDown else { return 0 }
            if modifierKeyCodes.contains(key.keyCode) {
                return 0
            }
            return config.keyboardWeight
            
        case .move:
            // Movement scoring needs velocity context; default to small jitter weight.
            return config.hoverWeight
        }
    }
    
    // MARK: - Region Management
    
    /// Add an event and return the affected region
    mutating func addEvent(_ event: UnifiedEvent) -> AttentionRegion {
        let time = event.timestamp
        let weight = eventWeight(for: event)
        
        // For keyboard events without position, use last known region or create at center
        guard let position = event.position else {
            // Keyboard event: update most recent region or create at center
            if !regions.isEmpty {
                let index = regions.count - 1
                regions[index].update(addingScore: weight, at: time)
                return regions[index]
            } else {
                let newRegion = AttentionRegion(
                    center: CGPoint(x: 0.5, y: 0.5),
                    score: weight,
                    lastUpdateTime: time,
                    eventCount: 1
                )
                regions.append(newRegion)
                return newRegion
            }
        }
        
        // Find existing region within merge radius
        if let index = regions.firstIndex(where: { region in
            let distance = hypot(region.center.x - position.x, region.center.y - position.y)
            return distance <= config.mergeRadius
        }) {
            // Update existing region
            regions[index].update(addingScore: weight, at: time)
            return regions[index]
        } else {
            // Create new region
            let newRegion = AttentionRegion(
                center: position,
                score: weight,
                lastUpdateTime: time,
                eventCount: 1
            )
            regions.append(newRegion)
            return newRegion
        }
    }
    
    /// Decay all region scores to current time
    mutating func decayScores(to currentTime: TimeInterval) {
        for i in 0..<regions.count {
            regions[i].decay(to: currentTime, tau: config.decayTau)
        }
        
        // Remove regions with very low scores
        regions.removeAll { $0.score < 0.01 }
    }
    
    /// Get all active regions
    func activeRegions() -> [AttentionRegion] {
        return regions
    }
    
    // MARK: - Decision Logic
    
    /// Determine if a region's attention score warrants triggering a zoom
    func shouldTriggerZoom(for region: AttentionRegion) -> Bool {
        // Threshold: score must be significant enough
        // Default: click (1.0) or keyboard (0.9) should trigger
        // Small moves (0.3) should not
        let threshold: Double = 0.5
        return region.score >= threshold
    }
    
    /// Determine if a new event should interrupt the current Hold phase
    func shouldInterruptHold(
        newRegion: AttentionRegion,
        currentRegion: AttentionRegion,
        holdStartTime: TimeInterval,
        currentTime: TimeInterval
    ) -> Bool {
        let distance = hypot(
            newRegion.center.x - currentRegion.center.x,
            newRegion.center.y - currentRegion.center.y
        )
        
        // 1. Large distance: immediate interrupt (clear user intent)
        if distance > 0.6 {
            return true
        }
        
        // 2. Check confirmation time
        let confirmationElapsed = currentTime - newRegion.lastUpdateTime
        let isConfirmed = confirmationElapsed >= config.confirmThreshold
        
        // If not confirmed yet, don't interrupt
        guard isConfirmed else {
            return false
        }
        
        // 3. After confirmation, check priority
        // - High priority (score >= 1.25x): always interrupt
        // - Medium distance (> 0.2): interrupt even with equal priority
        // - Close distance + equal priority: don't interrupt (hysteresis)
        let isHighPriority = newRegion.score >= currentRegion.score * 1.25
        let isMediumDistance = distance > 0.2
        
        return isHighPriority || isMediumDistance
    }
}

