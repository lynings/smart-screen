import Foundation
import CoreGraphics

/// One-Euro filter for adaptive low-pass smoothing.
///
/// Reference: Casiez et al. "The 1€ Filter: A Simple Speed-based Low-pass Filter for Noisy Input in Interactive Systems"
struct OneEuroFilter {
    
    // MARK: - Configuration
    
    let minCutoff: Double
    let beta: Double
    let dCutoff: Double
    
    // MARK: - State
    
    private var lastTimestamp: TimeInterval?
    private var xPrev: Double?
    private var dxPrev: Double = 0
    
    // MARK: - Initialization
    
    init(
        minCutoff: Double,
        beta: Double,
        dCutoff: Double
    ) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.dCutoff = dCutoff
    }
    
    // MARK: - Filtering
    
    mutating func filter(value: Double, timestamp: TimeInterval) -> Double {
        guard let lastTimestamp, let xPrev else {
            self.lastTimestamp = timestamp
            self.xPrev = value
            self.dxPrev = 0
            return value
        }
        
        let dt = timestamp - lastTimestamp
        guard dt > 0 else {
            // Non-increasing timestamps: keep previous filtered value.
            return xPrev
        }
        
        // 1. Estimate derivative
        let dx = (value - xPrev) / dt
        
        // 2. Filter derivative
        let alphaD = alpha(cutoff: dCutoff, dt: dt)
        let dxHat = lowPass(current: dx, previous: dxPrev, alpha: alphaD)
        
        // 3. Compute adaptive cutoff
        let cutoff = minCutoff + beta * abs(dxHat)
        
        // 4. Filter signal
        let alphaX = alpha(cutoff: cutoff, dt: dt)
        let xHat = lowPass(current: value, previous: xPrev, alpha: alphaX)
        
        // 5. Update state
        self.lastTimestamp = timestamp
        self.xPrev = xHat
        self.dxPrev = dxHat
        
        return xHat
    }
    
    mutating func filter(value: CGFloat, timestamp: TimeInterval) -> CGFloat {
        CGFloat(filter(value: Double(value), timestamp: timestamp))
    }
    
    // MARK: - Private Helpers
    
    private func alpha(cutoff: Double, dt: TimeInterval) -> Double {
        guard cutoff > 0 else { return 1 }
        let tau = 1.0 / (2.0 * Double.pi * cutoff)
        return 1.0 / (1.0 + tau / dt)
    }
    
    private func lowPass(current: Double, previous: Double, alpha: Double) -> Double {
        alpha * current + (1.0 - alpha) * previous
    }
}

