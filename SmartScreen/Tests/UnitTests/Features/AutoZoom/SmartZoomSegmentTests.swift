import XCTest
@testable import SmartScreen

final class SmartZoomSegmentTests: XCTestCase {
    
    // MARK: - Initialization
    
    func test_should_create_segment_with_keyframes() {
        // given
        let keyframes = [
            FocusKeyframe(time: 0.0, center: CGPoint(x: 0.5, y: 0.5), scale: 1.0, velocity: .zero),
            FocusKeyframe(time: 0.5, center: CGPoint(x: 0.5, y: 0.5), scale: 2.0, velocity: .zero),
            FocusKeyframe(time: 2.5, center: CGPoint(x: 0.5, y: 0.5), scale: 2.0, velocity: .zero),
            FocusKeyframe(time: 3.0, center: CGPoint(x: 0.5, y: 0.5), scale: 1.0, velocity: .zero)
        ]
        
        // when
        let segment = SmartZoomSegment(
            timeRange: 0.0...3.0,
            trigger: .click(position: CGPoint(x: 0.5, y: 0.5)),
            keyframes: keyframes,
            easing: .easeInOut
        )
        
        // then
        XCTAssertEqual(segment.duration, 3.0)
        XCTAssertEqual(segment.keyframes.count, 4)
    }
    
    // MARK: - Focus State Interpolation
    
    func test_should_return_first_keyframe_before_segment() {
        // given
        let segment = createTestSegment()
        
        // when
        let state = segment.focusAt(time: -1.0)
        
        // then
        XCTAssertEqual(state.scale, 1.0)
    }
    
    func test_should_interpolate_scale_during_zoom_in() {
        // given
        let segment = createTestSegment()
        
        // when - at 0.25s (middle of zoom-in phase)
        let state = segment.focusAt(time: 0.25)
        
        // then - scale should be between 1.0 and 2.0
        XCTAssertGreaterThan(state.scale, 1.0)
        XCTAssertLessThan(state.scale, 2.0)
    }
    
    func test_should_return_full_scale_during_hold() {
        // given
        let segment = createTestSegment()
        
        // when - at 1.5s (middle of hold phase)
        let state = segment.focusAt(time: 1.5)
        
        // then
        XCTAssertEqual(state.scale, 2.0, accuracy: 0.01)
    }
    
    func test_should_interpolate_scale_during_zoom_out() {
        // given
        let segment = createTestSegment()
        
        // when - at 2.75s (middle of zoom-out phase)
        let state = segment.focusAt(time: 2.75)
        
        // then - scale should be between 1.0 and 2.0
        XCTAssertGreaterThan(state.scale, 1.0)
        XCTAssertLessThan(state.scale, 2.0)
    }
    
    // MARK: - Center Following
    
    func test_should_interpolate_center_position() {
        // given
        let keyframes = [
            FocusKeyframe(time: 0.0, center: CGPoint(x: 0.3, y: 0.3), scale: 2.0, velocity: .zero),
            FocusKeyframe(time: 1.0, center: CGPoint(x: 0.7, y: 0.7), scale: 2.0, velocity: .zero)
        ]
        let segment = SmartZoomSegment(
            timeRange: 0.0...1.0,
            trigger: .activityCluster(region: CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4)),
            keyframes: keyframes,
            easing: .linear
        )
        
        // when - at 0.5s (middle)
        let state = segment.focusAt(time: 0.5)
        
        // then - center should be interpolated
        XCTAssertEqual(state.center.x, 0.5, accuracy: 0.05)
        XCTAssertEqual(state.center.y, 0.5, accuracy: 0.05)
    }
    
    // MARK: - Contains Time
    
    func test_should_contain_time_within_range() {
        // given
        let segment = createTestSegment()
        
        // when/then
        XCTAssertTrue(segment.contains(time: 0.0))
        XCTAssertTrue(segment.contains(time: 1.5))
        XCTAssertTrue(segment.contains(time: 3.0))
    }
    
    func test_should_not_contain_time_outside_range() {
        // given
        let segment = createTestSegment()
        
        // when/then
        XCTAssertFalse(segment.contains(time: -0.1))
        XCTAssertFalse(segment.contains(time: 3.1))
    }
    
    // MARK: - Helpers
    
    private func createTestSegment() -> SmartZoomSegment {
        let keyframes = [
            FocusKeyframe(time: 0.0, center: CGPoint(x: 0.5, y: 0.5), scale: 1.0, velocity: .zero),
            FocusKeyframe(time: 0.5, center: CGPoint(x: 0.5, y: 0.5), scale: 2.0, velocity: .zero),
            FocusKeyframe(time: 2.5, center: CGPoint(x: 0.5, y: 0.5), scale: 2.0, velocity: .zero),
            FocusKeyframe(time: 3.0, center: CGPoint(x: 0.5, y: 0.5), scale: 1.0, velocity: .zero)
        ]
        
        return SmartZoomSegment(
            timeRange: 0.0...3.0,
            trigger: .click(position: CGPoint(x: 0.5, y: 0.5)),
            keyframes: keyframes,
            easing: .easeInOut
        )
    }
}
