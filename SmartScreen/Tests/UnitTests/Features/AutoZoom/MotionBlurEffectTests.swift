import XCTest
@testable import SmartScreen

final class MotionBlurEffectTests: XCTestCase {
    
    // MARK: - MotionBlurConfig Tests
    
    func test_should_have_default_config_disabled() {
        // given/when
        let config = MotionBlurConfig.default
        
        // then
        XCTAssertFalse(config.isEnabled)
    }
    
    func test_should_have_presets_enabled() {
        // then
        XCTAssertTrue(MotionBlurConfig.subtle.isEnabled)
        XCTAssertTrue(MotionBlurConfig.dramatic.isEnabled)
    }
    
    func test_should_have_different_intensity_presets() {
        // given
        let subtle = MotionBlurConfig.subtle
        let dramatic = MotionBlurConfig.dramatic
        
        // then - dramatic should have higher blur
        XCTAssertGreaterThan(dramatic.maxBlurRadius, subtle.maxBlurRadius)
        XCTAssertGreaterThan(dramatic.intensityScale, subtle.intensityScale)
    }
    
    // MARK: - MotionState Tests
    
    func test_should_calculate_motion_intensity_for_pan() {
        // given
        let state = MotionState(
            center: CGPoint(x: 0.5, y: 0.5),
            scale: 2.0,
            centerVelocity: CGPoint(x: 0.5, y: 0.0),  // Fast horizontal pan
            scaleVelocity: 0,
            timestamp: 0.1
        )
        
        // when
        let intensity = state.motionIntensity
        
        // then
        XCTAssertGreaterThan(intensity, 0)
        XCTAssertLessThanOrEqual(intensity, 1.0)
    }
    
    func test_should_calculate_motion_intensity_for_zoom() {
        // given
        let state = MotionState(
            center: CGPoint(x: 0.5, y: 0.5),
            scale: 2.0,
            centerVelocity: .zero,
            scaleVelocity: 2.0,  // Fast zoom
            timestamp: 0.1
        )
        
        // when
        let intensity = state.motionIntensity
        
        // then
        XCTAssertGreaterThan(intensity, 0)
    }
    
    func test_should_detect_zoom_motion() {
        // given - zoom velocity higher than pan
        let zoomState = MotionState(
            center: CGPoint(x: 0.5, y: 0.5),
            scale: 2.0,
            centerVelocity: CGPoint(x: 0.1, y: 0.1),
            scaleVelocity: 3.0,
            timestamp: 0.1
        )
        
        let panState = MotionState(
            center: CGPoint(x: 0.5, y: 0.5),
            scale: 2.0,
            centerVelocity: CGPoint(x: 0.5, y: 0.5),
            scaleVelocity: 0.1,
            timestamp: 0.1
        )
        
        // then
        XCTAssertTrue(zoomState.isZoomMotion)
        XCTAssertFalse(panState.isZoomMotion)
    }
    
    func test_should_calculate_blur_angle() {
        // given - moving right
        let rightState = MotionState(
            center: CGPoint(x: 0.5, y: 0.5),
            scale: 2.0,
            centerVelocity: CGPoint(x: 1.0, y: 0.0),
            scaleVelocity: 0,
            timestamp: 0.1
        )
        
        // given - moving up
        let upState = MotionState(
            center: CGPoint(x: 0.5, y: 0.5),
            scale: 2.0,
            centerVelocity: CGPoint(x: 0.0, y: 1.0),
            scaleVelocity: 0,
            timestamp: 0.1
        )
        
        // then
        XCTAssertEqual(rightState.blurAngle, 0, accuracy: 0.01)
        XCTAssertEqual(upState.blurAngle, .pi / 2, accuracy: 0.01)
    }
    
    // MARK: - MotionBlurCalculator Tests
    
    func test_should_calculate_motion_state() {
        // given
        let calculator = MotionBlurCalculator()
        
        // when
        let state = calculator.calculateMotionState(
            currentCenter: CGPoint(x: 0.6, y: 0.5),
            currentScale: 2.0,
            previousCenter: CGPoint(x: 0.5, y: 0.5),
            previousScale: 2.0,
            deltaTime: 0.1
        )
        
        // then
        XCTAssertEqual(state.center, CGPoint(x: 0.6, y: 0.5))
        XCTAssertEqual(state.centerVelocity.x, 1.0, accuracy: 0.01)
        XCTAssertEqual(state.centerVelocity.y, 0, accuracy: 0.01)
    }
    
    func test_should_not_generate_blur_when_disabled() {
        // given
        let calculator = MotionBlurCalculator(config: .default)  // disabled
        let state = MotionState(
            center: CGPoint(x: 0.5, y: 0.5),
            scale: 2.0,
            centerVelocity: CGPoint(x: 1.0, y: 1.0),  // Fast motion
            scaleVelocity: 0,
            timestamp: 0.1
        )
        
        // when
        let params = calculator.calculateBlurParameters(for: state)
        
        // then
        XCTAssertNil(params)
    }
    
    func test_should_generate_blur_when_enabled_and_fast_motion() {
        // given
        let calculator = MotionBlurCalculator(config: .dramatic)
        let state = MotionState(
            center: CGPoint(x: 0.5, y: 0.5),
            scale: 2.0,
            centerVelocity: CGPoint(x: 0.5, y: 0.5),  // Fast motion
            scaleVelocity: 0,
            timestamp: 0.1
        )
        
        // when
        let params = calculator.calculateBlurParameters(for: state)
        
        // then
        XCTAssertNotNil(params)
        XCTAssertEqual(params?.type, .directional)
        XCTAssertGreaterThan(params?.radius ?? 0, 0)
    }
    
    func test_should_not_generate_blur_for_slow_motion() {
        // given
        let calculator = MotionBlurCalculator(config: .dramatic)
        let state = MotionState(
            center: CGPoint(x: 0.5, y: 0.5),
            scale: 2.0,
            centerVelocity: CGPoint(x: 0.05, y: 0.05),  // Slow motion
            scaleVelocity: 0,
            timestamp: 0.1
        )
        
        // when
        let params = calculator.calculateBlurParameters(for: state)
        
        // then
        XCTAssertNil(params)
    }
    
    func test_should_generate_zoom_blur_for_scale_change() {
        // given
        let calculator = MotionBlurCalculator(config: .dramatic)
        let state = MotionState(
            center: CGPoint(x: 0.5, y: 0.5),
            scale: 2.0,
            centerVelocity: CGPoint(x: 0.05, y: 0.05),  // Minimal pan
            scaleVelocity: 3.0,  // Fast zoom
            timestamp: 0.1
        )
        
        // when
        let params = calculator.calculateBlurParameters(for: state)
        
        // then
        XCTAssertNotNil(params)
        XCTAssertEqual(params?.type, .zoom)
    }
    
    // MARK: - MotionBlurParameters Tests
    
    func test_should_convert_angle_to_ci_angle() {
        // given
        let params = MotionBlurParameters(
            type: .directional,
            radius: 10,
            angle: .pi / 2,  // 90 degrees
            center: CGPoint(x: 0.5, y: 0.5),
            intensity: 0.5
        )
        
        // then
        XCTAssertEqual(params.ciAngle, 90, accuracy: 0.1)
    }
    
    func test_should_handle_zero_intensity() {
        // given
        let params = MotionBlurParameters(
            type: .directional,
            radius: 10,
            angle: 0,
            center: CGPoint(x: 0.5, y: 0.5),
            intensity: 0  // Zero intensity
        )
        
        // when - try to create filter (using a placeholder image)
        let testImage = CIImage(color: .black).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))
        let result = params.createFilter(for: testImage)
        
        // then - should return nil for zero intensity
        XCTAssertNil(result)
    }
    
    func test_should_handle_delta_time_zero() {
        // given
        let calculator = MotionBlurCalculator()
        
        // when
        let state = calculator.calculateMotionState(
            currentCenter: CGPoint(x: 0.6, y: 0.5),
            currentScale: 2.0,
            previousCenter: CGPoint(x: 0.5, y: 0.5),
            previousScale: 2.0,
            deltaTime: 0  // Zero delta time
        )
        
        // then - should have zero velocity
        XCTAssertEqual(state.centerVelocity, .zero)
        XCTAssertEqual(state.scaleVelocity, 0)
    }
}
