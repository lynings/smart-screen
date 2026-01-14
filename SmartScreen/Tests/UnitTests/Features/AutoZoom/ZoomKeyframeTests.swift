import XCTest
@testable import SmartScreen

final class ZoomKeyframeTests: XCTestCase {
    
    // MARK: - Idle Keyframe Tests
    
    func test_should_create_idle_keyframe() {
        // given/when
        let keyframe = ZoomKeyframe.idle(at: 5.0)
        
        // then
        XCTAssertEqual(keyframe.time, 5.0)
        XCTAssertEqual(keyframe.scale, 1.0)
        XCTAssertEqual(keyframe.center, CGPoint(x: 0.5, y: 0.5))
    }
    
    // MARK: - Zoomed Keyframe Tests
    
    func test_should_create_zoomed_keyframe() {
        // given
        let center = CGPoint(x: 0.3, y: 0.7)
        
        // when
        let keyframe = ZoomKeyframe.zoomed(at: 2.0, scale: 2.5, center: center)
        
        // then
        XCTAssertEqual(keyframe.time, 2.0)
        XCTAssertEqual(keyframe.scale, 2.5)
        XCTAssertEqual(keyframe.center, center)
    }
    
    // MARK: - Interpolation Tests
    
    func test_should_interpolate_scale_at_midpoint() {
        // given
        let from = ZoomKeyframe(time: 0, scale: 1.0, center: CGPoint(x: 0.5, y: 0.5), easing: .linear)
        let to = ZoomKeyframe(time: 1.0, scale: 2.0, center: CGPoint(x: 0.5, y: 0.5), easing: .linear)
        
        // when
        let interpolated = ZoomKeyframe.interpolate(from: from, to: to, at: 0.5)
        
        // then
        XCTAssertEqual(interpolated.scale, 1.5, accuracy: 0.01)
    }
    
    func test_should_interpolate_center_at_midpoint() {
        // given
        let from = ZoomKeyframe(time: 0, scale: 2.0, center: CGPoint(x: 0.0, y: 0.0), easing: .linear)
        let to = ZoomKeyframe(time: 1.0, scale: 2.0, center: CGPoint(x: 1.0, y: 1.0), easing: .linear)
        
        // when
        let interpolated = ZoomKeyframe.interpolate(from: from, to: to, at: 0.5)
        
        // then
        XCTAssertEqual(interpolated.center.x, 0.5, accuracy: 0.01)
        XCTAssertEqual(interpolated.center.y, 0.5, accuracy: 0.01)
    }
    
    func test_should_return_from_keyframe_before_start() {
        // given
        let from = ZoomKeyframe(time: 1.0, scale: 1.0, center: CGPoint(x: 0.2, y: 0.2), easing: .linear)
        let to = ZoomKeyframe(time: 2.0, scale: 2.0, center: CGPoint(x: 0.8, y: 0.8), easing: .linear)
        
        // when
        let interpolated = ZoomKeyframe.interpolate(from: from, to: to, at: 0.5)
        
        // then - should clamp to from
        XCTAssertEqual(interpolated.scale, from.scale, accuracy: 0.01)
    }
    
    func test_should_return_to_keyframe_after_end() {
        // given
        let from = ZoomKeyframe(time: 1.0, scale: 1.0, center: CGPoint(x: 0.2, y: 0.2), easing: .linear)
        let to = ZoomKeyframe(time: 2.0, scale: 2.0, center: CGPoint(x: 0.8, y: 0.8), easing: .linear)
        
        // when
        let interpolated = ZoomKeyframe.interpolate(from: from, to: to, at: 3.0)
        
        // then - should clamp to 'to'
        XCTAssertEqual(interpolated.scale, to.scale, accuracy: 0.01)
    }
    
    func test_should_apply_easing_during_interpolation() {
        // given
        let from = ZoomKeyframe(time: 0, scale: 1.0, center: CGPoint(x: 0.5, y: 0.5), easing: .easeIn)
        let to = ZoomKeyframe(time: 1.0, scale: 2.0, center: CGPoint(x: 0.5, y: 0.5), easing: .easeIn)
        
        // when
        let interpolated = ZoomKeyframe.interpolate(from: from, to: to, at: 0.5)
        
        // then - easeIn at 50% should be less than 50% progress
        // Linear would give 1.5, easeIn should give less
        XCTAssertLessThan(interpolated.scale, 1.5)
    }
    
    // MARK: - Edge Cases
    
    func test_should_handle_same_time_keyframes() {
        // given
        let from = ZoomKeyframe(time: 1.0, scale: 1.0, center: CGPoint(x: 0.2, y: 0.2), easing: .linear)
        let to = ZoomKeyframe(time: 1.0, scale: 2.0, center: CGPoint(x: 0.8, y: 0.8), easing: .linear)
        
        // when
        let interpolated = ZoomKeyframe.interpolate(from: from, to: to, at: 1.0)
        
        // then - should return 'from' when times are equal
        XCTAssertEqual(interpolated.scale, from.scale)
    }
    
    func test_should_interpolate_both_scale_and_center_together() {
        // given
        let from = ZoomKeyframe(time: 0, scale: 1.0, center: CGPoint(x: 0.0, y: 0.0), easing: .linear)
        let to = ZoomKeyframe(time: 1.0, scale: 3.0, center: CGPoint(x: 1.0, y: 1.0), easing: .linear)
        
        // when
        let interpolated = ZoomKeyframe.interpolate(from: from, to: to, at: 0.25)
        
        // then - at 25% progress
        XCTAssertEqual(interpolated.scale, 1.5, accuracy: 0.01)
        XCTAssertEqual(interpolated.center.x, 0.25, accuracy: 0.01)
        XCTAssertEqual(interpolated.center.y, 0.25, accuracy: 0.01)
    }
}
