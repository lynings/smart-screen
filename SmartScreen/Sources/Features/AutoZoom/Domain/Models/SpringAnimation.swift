import Foundation
import CoreGraphics

/// Spring animation model based on damped harmonic oscillator physics
///
/// Uses the differential equation: x''(t) + (friction/mass) * x'(t) + (tension/mass) * x(t) = 0
/// This creates natural-feeling animations with inertia and smooth deceleration.
struct SpringAnimation: Equatable, Codable {
    
    // MARK: - Properties
    
    /// Spring stiffness (tension) - higher values = faster oscillation
    let tension: CGFloat
    
    /// Damping coefficient (friction) - higher values = less oscillation
    let friction: CGFloat
    
    /// Mass of the animated object - higher values = more inertia
    let mass: CGFloat
    
    // MARK: - Computed Properties
    
    /// Angular frequency (ω₀ = √(tension/mass))
    private var angularFrequency: CGFloat {
        sqrt(tension / mass)
    }
    
    /// Damping ratio (ζ = friction / (2 * √(tension * mass)))
    /// < 1: underdamped (oscillates)
    /// = 1: critically damped (fastest without oscillation)
    /// > 1: overdamped (slow approach)
    var dampingRatio: CGFloat {
        friction / (2 * sqrt(tension * mass))
    }
    
    /// Damped frequency (ωd = ω₀ * √(1 - ζ²)) for underdamped case
    private var dampedFrequency: CGFloat {
        let zeta = dampingRatio
        guard zeta < 1 else { return 0 }
        return angularFrequency * sqrt(1 - zeta * zeta)
    }
    
    /// Estimated settling time (when amplitude < threshold)
    var settlingTime: TimeInterval {
        let zeta = dampingRatio
        let omega0 = angularFrequency
        
        // Time for amplitude to decay to ~2% (4 time constants)
        if zeta >= 1 {
            // Overdamped or critically damped
            return TimeInterval(4.0 / (zeta * omega0))
        } else {
            // Underdamped
            return TimeInterval(4.0 / (zeta * omega0))
        }
    }
    
    // MARK: - Initialization
    
    init(tension: CGFloat = 170, friction: CGFloat = 26, mass: CGFloat = 1) {
        self.tension = max(1, tension)
        self.friction = max(0, friction)
        self.mass = max(0.1, mass)
    }
    
    // MARK: - Animation Calculation
    
    /// Calculate the animated value at a given time
    /// - Parameters:
    ///   - time: Time since animation start (seconds)
    ///   - from: Starting value
    ///   - to: Target value
    ///   - initialVelocity: Initial velocity (default 0)
    /// - Returns: The interpolated value at the given time
    func value(
        at time: TimeInterval,
        from: CGFloat,
        to: CGFloat,
        initialVelocity: CGFloat = 0
    ) -> CGFloat {
        guard time > 0 else { return from }
        
        let displacement = to - from
        guard abs(displacement) > 0.0001 else { return to }
        
        let t = CGFloat(time)
        let zeta = dampingRatio
        let omega0 = angularFrequency
        
        // Normalized initial conditions
        let x0: CGFloat = 1.0  // Start at full displacement
        let v0 = initialVelocity / displacement  // Normalized velocity
        
        let position: CGFloat
        
        if zeta < 1 {
            // Underdamped: oscillates before settling
            let omegaD = dampedFrequency
            let decay = exp(-zeta * omega0 * t)
            
            let A = x0
            let B = (v0 + zeta * omega0 * x0) / omegaD
            
            position = decay * (A * cos(omegaD * t) + B * sin(omegaD * t))
            
        } else if zeta == 1 {
            // Critically damped: fastest approach without oscillation
            let decay = exp(-omega0 * t)
            position = decay * (x0 + (v0 + omega0 * x0) * t)
            
        } else {
            // Overdamped: slow exponential approach
            let sqrtTerm = sqrt(zeta * zeta - 1)
            let r1 = -omega0 * (zeta - sqrtTerm)
            let r2 = -omega0 * (zeta + sqrtTerm)
            
            let c2 = (v0 - r1 * x0) / (r2 - r1)
            let c1 = x0 - c2
            
            position = c1 * exp(r1 * t) + c2 * exp(r2 * t)
        }
        
        // Convert from normalized (1 -> 0) to actual (from -> to)
        return to - displacement * position
    }
    
    /// Calculate the velocity at a given time
    func velocity(
        at time: TimeInterval,
        from: CGFloat,
        to: CGFloat,
        initialVelocity: CGFloat = 0
    ) -> CGFloat {
        guard time > 0 else { return initialVelocity }
        
        let displacement = to - from
        guard abs(displacement) > 0.0001 else { return 0 }
        
        let t = CGFloat(time)
        let zeta = dampingRatio
        let omega0 = angularFrequency
        
        let x0: CGFloat = 1.0
        let v0 = initialVelocity / displacement
        
        let velocity: CGFloat
        
        if zeta < 1 {
            // Underdamped
            let omegaD = dampedFrequency
            let decay = exp(-zeta * omega0 * t)
            
            let A = x0
            let B = (v0 + zeta * omega0 * x0) / omegaD
            
            let dDecay = -zeta * omega0 * decay
            let cosVal = cos(omegaD * t)
            let sinVal = sin(omegaD * t)
            
            velocity = dDecay * (A * cosVal + B * sinVal) +
                       decay * (-A * omegaD * sinVal + B * omegaD * cosVal)
            
        } else if zeta == 1 {
            // Critically damped
            let decay = exp(-omega0 * t)
            let factor = v0 + omega0 * x0
            velocity = decay * (factor - omega0 * (x0 + factor * t))
            
        } else {
            // Overdamped
            let sqrtTerm = sqrt(zeta * zeta - 1)
            let r1 = -omega0 * (zeta - sqrtTerm)
            let r2 = -omega0 * (zeta + sqrtTerm)
            
            let c2 = (v0 - r1 * x0) / (r2 - r1)
            let c1 = x0 - c2
            
            velocity = c1 * r1 * exp(r1 * t) + c2 * r2 * exp(r2 * t)
        }
        
        return -displacement * velocity
    }
    
    /// Check if the animation has settled (reached target within threshold)
    func isSettled(
        at time: TimeInterval,
        from: CGFloat,
        to: CGFloat,
        positionThreshold: CGFloat = 0.001,
        velocityThreshold: CGFloat = 0.001
    ) -> Bool {
        let currentValue = value(at: time, from: from, to: to)
        let currentVelocity = velocity(at: time, from: from, to: to)
        
        let positionDelta = abs(currentValue - to)
        let normalizedVelocity = abs(currentVelocity / max(abs(to - from), 1))
        
        return positionDelta < positionThreshold && normalizedVelocity < velocityThreshold
    }
    
    /// Calculate progress (0-1) at a given time, clamped
    func progress(at time: TimeInterval) -> CGFloat {
        let val = value(at: time, from: 0, to: 1)
        return max(0, min(1, val))
    }
}

// MARK: - CGPoint Extension

extension SpringAnimation {
    
    /// Animate a CGPoint from one position to another
    func value(
        at time: TimeInterval,
        from: CGPoint,
        to: CGPoint,
        initialVelocity: CGPoint = .zero
    ) -> CGPoint {
        CGPoint(
            x: value(at: time, from: from.x, to: to.x, initialVelocity: initialVelocity.x),
            y: value(at: time, from: from.y, to: to.y, initialVelocity: initialVelocity.y)
        )
    }
    
    /// Calculate velocity for a CGPoint animation
    func velocity(
        at time: TimeInterval,
        from: CGPoint,
        to: CGPoint,
        initialVelocity: CGPoint = .zero
    ) -> CGPoint {
        CGPoint(
            x: velocity(at: time, from: from.x, to: to.x, initialVelocity: initialVelocity.x),
            y: velocity(at: time, from: from.y, to: to.y, initialVelocity: initialVelocity.y)
        )
    }
    
    /// Check if a CGPoint animation has settled
    func isSettled(
        at time: TimeInterval,
        from: CGPoint,
        to: CGPoint,
        positionThreshold: CGFloat = 0.001,
        velocityThreshold: CGFloat = 0.001
    ) -> Bool {
        isSettled(at: time, from: from.x, to: to.x, 
                  positionThreshold: positionThreshold, velocityThreshold: velocityThreshold) &&
        isSettled(at: time, from: from.y, to: to.y, 
                  positionThreshold: positionThreshold, velocityThreshold: velocityThreshold)
    }
}

// MARK: - Presets

extension SpringAnimation {
    
    /// Default spring - balanced feel
    static let `default` = SpringAnimation(tension: 170, friction: 26, mass: 1)
    
    /// Gentle spring - slow and smooth
    static let gentle = SpringAnimation(tension: 120, friction: 14, mass: 1)
    
    /// Wobbly spring - bouncy feel
    static let wobbly = SpringAnimation(tension: 180, friction: 12, mass: 1)
    
    /// Stiff spring - fast and snappy
    static let stiff = SpringAnimation(tension: 210, friction: 20, mass: 1)
    
    /// Slow spring - very gentle transitions
    static let slow = SpringAnimation(tension: 100, friction: 20, mass: 1.5)
    
    /// Molasses spring - extremely slow
    static let molasses = SpringAnimation(tension: 80, friction: 30, mass: 2)
}
