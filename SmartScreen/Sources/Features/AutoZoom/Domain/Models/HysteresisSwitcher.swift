import Foundation

/// Prevents rapid target switching by requiring a candidate to remain dominant for a short duration.
///
/// Strategy B rule:
/// - Hard triggers (e.g. click) switch immediately.
/// - Soft candidates must persist for `holdDuration` and exceed the current score by `scoreMargin`.
struct HysteresisSwitcher {
    
    struct Decision: Equatable {
        let shouldSwitch: Bool
        let target: AttentionPoint?
    }
    
    let holdDuration: TimeInterval
    let scoreMargin: Double
    
    private var pending: PendingCandidate?
    
    init(holdDuration: TimeInterval = 0.25, scoreMargin: Double = 0.0) {
        self.holdDuration = holdDuration
        self.scoreMargin = scoreMargin
    }
    
    mutating func update(
        current: AttentionPoint,
        candidate: AttentionPoint,
        at time: TimeInterval
    ) -> Decision {
        // 1. Hard triggers bypass hysteresis (click should be responsive).
        if candidate.isHardTrigger {
            pending = nil
            return Decision(shouldSwitch: true, target: candidate)
        }
        
        // 2. Candidate must be meaningfully better than current.
        guard candidate.score >= current.score + scoreMargin else {
            pending = nil
            return Decision(shouldSwitch: false, target: nil)
        }
        
        // 3. Track persistence for the same candidate position (coarse).
        if let pending, isSameCandidate(pending.point, candidate) {
            // Already pending, check if persisted long enough.
            if time - pending.firstSeenAt >= holdDuration {
                self.pending = nil
                return Decision(shouldSwitch: true, target: candidate)
            }
            return Decision(shouldSwitch: false, target: nil)
        } else {
            // New pending candidate
            pending = PendingCandidate(point: candidate, firstSeenAt: time)
            return Decision(shouldSwitch: false, target: nil)
        }
    }
    
    // MARK: - Private
    
    private struct PendingCandidate {
        let point: AttentionPoint
        let firstSeenAt: TimeInterval
    }
    
    private func isSameCandidate(_ a: AttentionPoint, _ b: AttentionPoint) -> Bool {
        // For v1: treat equal position as the same candidate.
        // Later we can add spatial tolerance if needed.
        a.position == b.position
    }
}

