import Foundation
import CoreGraphics
import CoreImage

/// Configuration for motion blur effect
struct MotionBlurConfig: Equatable, Codable {
    /// Whether motion blur is enabled
    var isEnabled: Bool
    
    /// Minimum velocity (normalized per second) to trigger blur
    let velocityThreshold: CGFloat
    
    /// Maximum blur radius in pixels
    let maxBlurRadius: CGFloat
    
    /// Blur intensity scale (0-1)
    let intensityScale: CGFloat
    
    /// Direction sensitivity (0 = omnidirectional, 1 = directional)
    let directionalSensitivity: CGFloat
    
    static let `default` = MotionBlurConfig(
        isEnabled: false,  // Disabled by default
        velocityThreshold: 0.3,
        maxBlurRadius: 15.0,
        intensityScale: 0.6,
        directionalSensitivity: 0.8
    )
    
    static let subtle = MotionBlurConfig(
        isEnabled: true,
        velocityThreshold: 0.4,
        maxBlurRadius: 8.0,
        intensityScale: 0.4,
        directionalSensitivity: 0.7
    )
    
    static let dramatic = MotionBlurConfig(
        isEnabled: true,
        velocityThreshold: 0.2,
        maxBlurRadius: 20.0,
        intensityScale: 0.8,
        directionalSensitivity: 0.9
    )
}

/// Motion state for blur calculation
struct MotionState {
    /// Current center position (normalized 0-1)
    let center: CGPoint
    
    /// Current scale
    let scale: CGFloat
    
    /// Velocity of center movement (normalized units per second)
    let centerVelocity: CGPoint
    
    /// Rate of scale change (per second)
    let scaleVelocity: CGFloat
    
    /// Time stamp
    let timestamp: TimeInterval
    
    /// Calculate total motion intensity (0-1)
    var motionIntensity: CGFloat {
        let centerSpeed = hypot(centerVelocity.x, centerVelocity.y)
        let scaleChange = abs(scaleVelocity)
        
        // Combine pan and zoom velocities
        return min(1.0, centerSpeed * 2.0 + scaleChange * 0.5)
    }
    
    /// Calculate blur direction angle in radians
    var blurAngle: CGFloat {
        if abs(centerVelocity.x) < 0.001 && abs(centerVelocity.y) < 0.001 {
            return 0  // No direction for stationary
        }
        return atan2(centerVelocity.y, centerVelocity.x)
    }
    
    /// Whether motion is primarily zoom (vs pan)
    var isZoomMotion: Bool {
        let panSpeed = hypot(centerVelocity.x, centerVelocity.y)
        return abs(scaleVelocity) > panSpeed * 2
    }
}

/// Calculator for motion blur parameters
final class MotionBlurCalculator {
    
    private let config: MotionBlurConfig
    private var previousState: MotionState?
    
    init(config: MotionBlurConfig = .default) {
        self.config = config
    }
    
    /// Calculate motion state from keyframe transitions
    func calculateMotionState(
        currentCenter: CGPoint,
        currentScale: CGFloat,
        previousCenter: CGPoint,
        previousScale: CGFloat,
        deltaTime: TimeInterval
    ) -> MotionState {
        guard deltaTime > 0 else {
            return MotionState(
                center: currentCenter,
                scale: currentScale,
                centerVelocity: .zero,
                scaleVelocity: 0,
                timestamp: 0
            )
        }
        
        let dt = CGFloat(deltaTime)
        
        let centerVelocity = CGPoint(
            x: (currentCenter.x - previousCenter.x) / dt,
            y: (currentCenter.y - previousCenter.y) / dt
        )
        
        let scaleVelocity = (currentScale - previousScale) / dt
        
        return MotionState(
            center: currentCenter,
            scale: currentScale,
            centerVelocity: centerVelocity,
            scaleVelocity: scaleVelocity,
            timestamp: deltaTime
        )
    }
    
    /// Calculate blur parameters for rendering
    func calculateBlurParameters(for state: MotionState) -> MotionBlurParameters? {
        guard config.isEnabled else { return nil }
        
        let intensity = state.motionIntensity
        guard intensity > config.velocityThreshold else { return nil }
        
        // Scale intensity beyond threshold
        let normalizedIntensity = (intensity - config.velocityThreshold) / (1.0 - config.velocityThreshold)
        let effectiveIntensity = min(1.0, normalizedIntensity * config.intensityScale)
        
        let radius = config.maxBlurRadius * effectiveIntensity
        
        // Determine blur type
        if state.isZoomMotion {
            // Radial zoom blur
            return MotionBlurParameters(
                type: .zoom,
                radius: radius,
                angle: 0,
                center: state.center,
                intensity: effectiveIntensity
            )
        } else {
            // Directional motion blur
            return MotionBlurParameters(
                type: .directional,
                radius: radius,
                angle: state.blurAngle,
                center: state.center,
                intensity: effectiveIntensity * config.directionalSensitivity
            )
        }
    }
    
    /// Reset state
    func reset() {
        previousState = nil
    }
}

/// Parameters for applying motion blur effect
struct MotionBlurParameters {
    enum BlurType {
        case directional  // Linear motion blur
        case zoom         // Radial/zoom blur
    }
    
    let type: BlurType
    let radius: CGFloat
    let angle: CGFloat  // In radians, for directional blur
    let center: CGPoint  // Center for zoom blur
    let intensity: CGFloat
    
    /// Convert angle to CIMotionBlur angle (0 = horizontal)
    var ciAngle: CGFloat {
        // CIMotionBlur uses degrees, 0 = horizontal right
        return angle * 180.0 / .pi
    }
}

// MARK: - Core Image Filter Integration

extension MotionBlurParameters {
    
    /// Create a CIFilter for the motion blur effect
    /// - Parameter inputImage: The image to apply blur to
    /// - Returns: A configured CIFilter, or nil if blur shouldn't be applied
    func createFilter(for inputImage: CIImage) -> CIImage? {
        guard intensity > 0.01, radius > 0.5 else { return nil }
        
        switch type {
        case .directional:
            return createDirectionalBlur(for: inputImage)
        case .zoom:
            return createZoomBlur(for: inputImage)
        }
    }
    
    private func createDirectionalBlur(for inputImage: CIImage) -> CIImage? {
        guard let filter = CIFilter(name: "CIMotionBlur") else { return nil }
        
        filter.setValue(inputImage, forKey: kCIInputImageKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        filter.setValue(ciAngle, forKey: kCIInputAngleKey)
        
        return filter.outputImage
    }
    
    private func createZoomBlur(for inputImage: CIImage) -> CIImage? {
        guard let filter = CIFilter(name: "CIZoomBlur") else { return nil }
        
        // Convert normalized center to image coordinates
        let extent = inputImage.extent
        let imageCenter = CIVector(
            x: center.x * extent.width,
            y: center.y * extent.height
        )
        
        filter.setValue(inputImage, forKey: kCIInputImageKey)
        filter.setValue(imageCenter, forKey: kCIInputCenterKey)
        filter.setValue(radius * intensity, forKey: kCIInputAmountKey)
        
        return filter.outputImage
    }
}
