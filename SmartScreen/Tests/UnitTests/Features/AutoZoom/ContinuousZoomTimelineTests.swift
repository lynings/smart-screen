import XCTest
@testable import SmartScreen

final class ContinuousZoomTimelineTests: XCTestCase {
    
    // MARK: - Empty Timeline Tests
    
    func test_should_return_idle_state_for_empty_timeline() {
        // given
        let timeline = ContinuousZoomTimeline(keyframes: [])
        
        // when
        let state = timeline.state(at: 5.0)
        
        // then
        XCTAssertEqual(state.scale, 1.0)
        XCTAssertFalse(state.isActive)
    }
    
    func test_should_report_empty_for_no_keyframes() {
        // given
        let timeline = ContinuousZoomTimeline(keyframes: [])
        
        // when/then
        XCTAssertTrue(timeline.isEmpty)
        XCTAssertEqual(timeline.count, 0)
    }
    
    // MARK: - Single Keyframe Tests
    
    func test_should_return_keyframe_state_at_its_time() {
        // given
        let keyframe = ZoomKeyframe.zoomed(at: 1.0, scale: 2.0, center: CGPoint(x: 0.3, y: 0.7))
        let timeline = ContinuousZoomTimeline(keyframes: [keyframe])
        
        // when
        let state = timeline.state(at: 1.0)
        
        // then
        XCTAssertEqual(state.scale, 2.0)
        XCTAssertEqual(state.center, CGPoint(x: 0.3, y: 0.7))
    }
    
    func test_should_return_keyframe_state_before_its_time() {
        // given
        let keyframe = ZoomKeyframe.zoomed(at: 5.0, scale: 2.0, center: CGPoint(x: 0.3, y: 0.7))
        let timeline = ContinuousZoomTimeline(keyframes: [keyframe])
        
        // when
        let state = timeline.state(at: 1.0)
        
        // then - should use first keyframe for times before
        XCTAssertEqual(state.scale, 2.0)
    }
    
    // MARK: - Interpolation Tests
    
    func test_should_interpolate_between_keyframes() {
        // given
        let kf1 = ZoomKeyframe(time: 0, scale: 1.0, center: CGPoint(x: 0.5, y: 0.5), easing: .linear)
        let kf2 = ZoomKeyframe(time: 1.0, scale: 2.0, center: CGPoint(x: 0.5, y: 0.5), easing: .linear)
        let timeline = ContinuousZoomTimeline(keyframes: [kf1, kf2])
        
        // when
        let state = timeline.state(at: 0.5)
        
        // then
        XCTAssertEqual(state.scale, 1.5, accuracy: 0.01)
    }
    
    func test_should_interpolate_across_multiple_keyframes() {
        // given
        let kf1 = ZoomKeyframe(time: 0, scale: 1.0, center: CGPoint(x: 0.0, y: 0.0), easing: .linear)
        let kf2 = ZoomKeyframe(time: 1.0, scale: 2.0, center: CGPoint(x: 0.5, y: 0.5), easing: .linear)
        let kf3 = ZoomKeyframe(time: 2.0, scale: 1.0, center: CGPoint(x: 1.0, y: 1.0), easing: .linear)
        let timeline = ContinuousZoomTimeline(keyframes: [kf1, kf2, kf3])
        
        // when
        let stateAt1_5 = timeline.state(at: 1.5)
        
        // then - should be between kf2 and kf3
        XCTAssertEqual(stateAt1_5.scale, 1.5, accuracy: 0.01)
        XCTAssertEqual(stateAt1_5.center.x, 0.75, accuracy: 0.01)
        XCTAssertEqual(stateAt1_5.center.y, 0.75, accuracy: 0.01)
    }
    
    // MARK: - Phase Detection Tests
    
    func test_should_detect_zoom_in_phase() {
        // given
        let kf1 = ZoomKeyframe(time: 0, scale: 1.0, center: CGPoint(x: 0.5, y: 0.5), easing: .linear)
        let kf2 = ZoomKeyframe(time: 1.0, scale: 2.0, center: CGPoint(x: 0.5, y: 0.5), easing: .linear)
        let timeline = ContinuousZoomTimeline(keyframes: [kf1, kf2])
        
        // when
        let state = timeline.state(at: 0.5)
        
        // then
        XCTAssertEqual(state.phase, .zoomIn)
    }
    
    func test_should_detect_zoom_out_phase() {
        // given
        let kf1 = ZoomKeyframe(time: 0, scale: 2.0, center: CGPoint(x: 0.5, y: 0.5), easing: .linear)
        let kf2 = ZoomKeyframe(time: 1.0, scale: 1.0, center: CGPoint(x: 0.5, y: 0.5), easing: .linear)
        let timeline = ContinuousZoomTimeline(keyframes: [kf1, kf2])
        
        // when
        let state = timeline.state(at: 0.5)
        
        // then
        XCTAssertEqual(state.phase, .zoomOut)
    }
    
    func test_should_detect_hold_phase() {
        // given
        let kf1 = ZoomKeyframe(time: 0, scale: 2.0, center: CGPoint(x: 0.0, y: 0.0), easing: .linear)
        let kf2 = ZoomKeyframe(time: 1.0, scale: 2.0, center: CGPoint(x: 1.0, y: 1.0), easing: .linear)
        let timeline = ContinuousZoomTimeline(keyframes: [kf1, kf2])
        
        // when
        let state = timeline.state(at: 0.5)
        
        // then - scale not changing, just panning
        XCTAssertEqual(state.phase, ContinuousZoomState.Phase.hold)
    }
    
    // MARK: - Active State Tests
    
    func test_should_be_active_when_zoomed() {
        // given
        let kf1 = ZoomKeyframe(time: 0, scale: 1.0, center: CGPoint(x: 0.5, y: 0.5), easing: .linear)
        let kf2 = ZoomKeyframe(time: 1.0, scale: 2.0, center: CGPoint(x: 0.5, y: 0.5), easing: .linear)
        let timeline = ContinuousZoomTimeline(keyframes: [kf1, kf2])
        
        // when
        let state = timeline.state(at: 1.0)
        
        // then
        XCTAssertTrue(state.isActive)
    }
    
    func test_should_not_be_active_at_scale_1() {
        // given
        let kf = ZoomKeyframe.idle(at: 0)
        let timeline = ContinuousZoomTimeline(keyframes: [kf])
        
        // when
        let state = timeline.state(at: 0)
        
        // then
        XCTAssertFalse(state.isActive)
    }
    
    // MARK: - Sorting Tests
    
    func test_should_sort_keyframes_by_time() {
        // given - keyframes in wrong order
        let kf1 = ZoomKeyframe(time: 2.0, scale: 2.0, center: CGPoint(x: 0.5, y: 0.5), easing: .linear)
        let kf2 = ZoomKeyframe(time: 0.0, scale: 1.0, center: CGPoint(x: 0.5, y: 0.5), easing: .linear)
        let kf3 = ZoomKeyframe(time: 1.0, scale: 1.5, center: CGPoint(x: 0.5, y: 0.5), easing: .linear)
        let timeline = ContinuousZoomTimeline(keyframes: [kf1, kf2, kf3])
        
        // when
        let firstKf = timeline.keyframe(at: 0)
        
        // then - should be sorted
        XCTAssertEqual(firstKf?.time, 0.0)
    }
    
    // MARK: - Duration Tests
    
    func test_should_report_correct_duration() {
        // given
        let kf1 = ZoomKeyframe(time: 0, scale: 1.0, center: CGPoint(x: 0.5, y: 0.5), easing: .linear)
        let kf2 = ZoomKeyframe(time: 5.0, scale: 2.0, center: CGPoint(x: 0.5, y: 0.5), easing: .linear)
        let timeline = ContinuousZoomTimeline(keyframes: [kf1, kf2])
        
        // when
        let duration = timeline.duration
        
        // then
        XCTAssertEqual(duration, 5.0)
    }
    
    // MARK: - Range Query Tests
    
    func test_should_return_keyframes_in_range() {
        // given
        let kf1 = ZoomKeyframe(time: 0, scale: 1.0, center: CGPoint(x: 0.5, y: 0.5), easing: .linear)
        let kf2 = ZoomKeyframe(time: 1.0, scale: 2.0, center: CGPoint(x: 0.5, y: 0.5), easing: .linear)
        let kf3 = ZoomKeyframe(time: 2.0, scale: 1.0, center: CGPoint(x: 0.5, y: 0.5), easing: .linear)
        let timeline = ContinuousZoomTimeline(keyframes: [kf1, kf2, kf3])
        
        // when
        let inRange = timeline.keyframes(in: 0.5...1.5)
        
        // then
        XCTAssertEqual(inRange.count, 1)
        XCTAssertEqual(inRange.first?.time, 1.0)
    }
}
