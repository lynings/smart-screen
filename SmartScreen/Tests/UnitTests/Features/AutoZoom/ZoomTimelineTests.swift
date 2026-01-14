import XCTest
@testable import SmartScreen

final class ZoomTimelineTests: XCTestCase {
    
    // MARK: - Empty Timeline
    
    func test_should_return_idle_state_for_empty_timeline() {
        // given
        let timeline = ZoomTimeline.empty(duration: 10.0)
        
        // when
        let state = timeline.state(at: 5.0)
        
        // then
        XCTAssertEqual(state.scale, 1.0)
        XCTAssertFalse(state.isActive)
        XCTAssertNil(state.phase)
    }
    
    // MARK: - Single Segment
    
    func test_should_return_active_state_during_segment() {
        // given
        let segment = AutoZoomSegment(
            timeRange: 2.0...3.2,
            focusCenter: CGPoint(x: 0.5, y: 0.5),
            zoomScale: 2.0
        )
        let timeline = ZoomTimeline(segments: [segment], duration: 10.0)
        
        // when
        let state = timeline.state(at: 2.6) // Middle of segment
        
        // then
        XCTAssertTrue(state.isActive)
        XCTAssertGreaterThan(state.scale, 1.0)
    }
    
    func test_should_return_idle_state_outside_segment() {
        // given
        let segment = AutoZoomSegment(
            timeRange: 2.0...3.2,
            focusCenter: CGPoint(x: 0.5, y: 0.5),
            zoomScale: 2.0
        )
        let timeline = ZoomTimeline(segments: [segment], duration: 10.0)
        
        // when
        let beforeState = timeline.state(at: 1.0)
        let afterState = timeline.state(at: 5.0)
        
        // then
        XCTAssertFalse(beforeState.isActive)
        XCTAssertEqual(beforeState.scale, 1.0)
        XCTAssertFalse(afterState.isActive)
        XCTAssertEqual(afterState.scale, 1.0)
    }
    
    // MARK: - Multiple Segments
    
    func test_should_find_correct_segment_with_multiple_segments() {
        // given
        let segment1 = AutoZoomSegment(
            timeRange: 1.0...2.2,
            focusCenter: CGPoint(x: 0.3, y: 0.5),
            zoomScale: 2.0
        )
        let segment2 = AutoZoomSegment(
            timeRange: 5.0...6.2,
            focusCenter: CGPoint(x: 0.7, y: 0.5),
            zoomScale: 2.5
        )
        let timeline = ZoomTimeline(segments: [segment1, segment2], duration: 10.0)
        
        // when
        let state1 = timeline.state(at: 1.6) // Middle of segment1
        let state2 = timeline.state(at: 5.6) // Middle of segment2
        
        // then
        XCTAssertTrue(state1.isActive)
        XCTAssertEqual(state1.center.x, 0.3, accuracy: 0.01)
        
        XCTAssertTrue(state2.isActive)
        XCTAssertEqual(state2.center.x, 0.7, accuracy: 0.01)
    }
    
    // MARK: - Statistics
    
    func test_should_calculate_segment_count() {
        // given
        let segments = [
            AutoZoomSegment(timeRange: 1.0...2.0, focusCenter: .zero, zoomScale: 2.0),
            AutoZoomSegment(timeRange: 5.0...6.0, focusCenter: .zero, zoomScale: 2.0)
        ]
        let timeline = ZoomTimeline(segments: segments, duration: 10.0)
        
        // then
        XCTAssertEqual(timeline.segmentCount, 2)
    }
    
    func test_should_calculate_total_zoom_time() {
        // given
        let segments = [
            AutoZoomSegment(timeRange: 1.0...2.0, focusCenter: .zero, zoomScale: 2.0),
            AutoZoomSegment(timeRange: 5.0...6.5, focusCenter: .zero, zoomScale: 2.0)
        ]
        let timeline = ZoomTimeline(segments: segments, duration: 10.0)
        
        // then
        XCTAssertEqual(timeline.totalZoomTime, 2.5, accuracy: 0.001)
    }
    
    func test_should_calculate_zoom_percentage() {
        // given
        let segments = [
            AutoZoomSegment(timeRange: 0...2.0, focusCenter: .zero, zoomScale: 2.0)
        ]
        let timeline = ZoomTimeline(segments: segments, duration: 10.0)
        
        // then
        XCTAssertEqual(timeline.zoomPercentage, 20.0, accuracy: 0.001)
    }
    
    // MARK: - Phase Detection
    
    func test_should_detect_zoom_in_phase() {
        // given
        let segment = AutoZoomSegment(
            timeRange: 0...1.2,
            focusCenter: CGPoint(x: 0.5, y: 0.5),
            zoomScale: 2.0
        )
        let timeline = ZoomTimeline(segments: [segment], duration: 5.0)
        
        // when - at 0.09s (middle of 15% zoom in phase = 0.18s)
        let state = timeline.state(at: 0.09)
        
        // then
        XCTAssertEqual(state.phase, .zoomIn)
    }
    
    func test_should_detect_hold_phase() {
        // given
        let segment = AutoZoomSegment(
            timeRange: 0...1.2,
            focusCenter: CGPoint(x: 0.5, y: 0.5),
            zoomScale: 2.0
        )
        let timeline = ZoomTimeline(segments: [segment], duration: 5.0)
        
        // when - at 0.6s (middle of 70% hold phase)
        let state = timeline.state(at: 0.6)
        
        // then
        XCTAssertEqual(state.phase, .hold)
    }
    
    func test_should_detect_zoom_out_phase() {
        // given
        let segment = AutoZoomSegment(
            timeRange: 0...1.2,
            focusCenter: CGPoint(x: 0.5, y: 0.5),
            zoomScale: 2.0
        )
        let timeline = ZoomTimeline(segments: [segment], duration: 5.0)
        
        // when - at 1.11s (middle of 15% zoom out phase, starts at 1.02s)
        let state = timeline.state(at: 1.11)
        
        // then
        XCTAssertEqual(state.phase, .zoomOut)
    }
    
    // MARK: - Factory Methods
    
    func test_should_create_timeline_from_session() {
        // given
        let session = CursorTrackSession(events: [
            MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 2.0)
        ], duration: 10.0)
        let screenSize = CGSize(width: 1920, height: 1080)
        
        // when
        let timeline = ZoomTimeline.from(session: session, screenSize: screenSize)
        
        // then
        XCTAssertEqual(timeline.segmentCount, 1)
        XCTAssertEqual(timeline.duration, 10.0, accuracy: 0.001)
    }
    
    func test_should_return_idle_for_zoom_check_outside_segments() {
        // given
        let segment = AutoZoomSegment(
            timeRange: 2.0...3.2,
            focusCenter: CGPoint(x: 0.5, y: 0.5),
            zoomScale: 2.0
        )
        let timeline = ZoomTimeline(segments: [segment], duration: 10.0)
        
        // then
        XCTAssertFalse(timeline.isZoomActive(at: 1.0))
        XCTAssertTrue(timeline.isZoomActive(at: 2.5))
        XCTAssertFalse(timeline.isZoomActive(at: 5.0))
    }
    
    // MARK: - Gap Transition (方案 A: 平滑过渡)
    
    func test_should_maintain_zoom_during_short_gap_between_segments() {
        // given - two segments with short gap
        let segment1 = AutoZoomSegment(
            timeRange: 1.0...2.0,
            focusCenter: CGPoint(x: 0.3, y: 0.5),
            zoomScale: 2.0
        )
        let segment2 = AutoZoomSegment(
            timeRange: 2.3...3.3,
            focusCenter: CGPoint(x: 0.7, y: 0.5),
            zoomScale: 2.0
        )
        let timeline = ZoomTimeline(
            segments: [segment1, segment2],
            duration: 10.0,
            transitionDuration: 0.5
        )
        
        // when - in the gap between segments
        let state = timeline.state(at: 2.15)
        
        // then - should maintain zoom (gap transition) instead of idle
        XCTAssertTrue(state.isActive)
        XCTAssertEqual(state.scale, 2.0, accuracy: 0.01)
    }
    
    func test_should_interpolate_center_during_gap_transition() {
        // given - two segments with short gap and different centers
        let segment1 = AutoZoomSegment(
            timeRange: 1.0...2.0,
            focusCenter: CGPoint(x: 0.3, y: 0.5),
            zoomScale: 2.0
        )
        let segment2 = AutoZoomSegment(
            timeRange: 2.2...3.2,
            focusCenter: CGPoint(x: 0.7, y: 0.5),
            zoomScale: 2.0
        )
        let timeline = ZoomTimeline(
            segments: [segment1, segment2],
            duration: 10.0,
            transitionDuration: 0.4
        )
        
        // when - in the middle of gap
        let state = timeline.state(at: 2.1)
        
        // then - center should be interpolated between 0.3 and 0.7
        XCTAssertTrue(state.isActive)
        XCTAssertGreaterThan(state.center.x, 0.3)
        XCTAssertLessThan(state.center.x, 0.7)
    }
    
    func test_should_return_idle_for_long_gap_between_segments() {
        // given - two segments with long gap
        let segment1 = AutoZoomSegment(
            timeRange: 1.0...2.0,
            focusCenter: CGPoint(x: 0.3, y: 0.5),
            zoomScale: 2.0
        )
        let segment2 = AutoZoomSegment(
            timeRange: 5.0...6.0,
            focusCenter: CGPoint(x: 0.7, y: 0.5),
            zoomScale: 2.0
        )
        let timeline = ZoomTimeline(
            segments: [segment1, segment2],
            duration: 10.0,
            transitionDuration: 0.3
        )
        
        // when - in the gap (too long for transition)
        let state = timeline.state(at: 3.5)
        
        // then - should be idle
        XCTAssertFalse(state.isActive)
        XCTAssertEqual(state.scale, 1.0)
    }
    
    // MARK: - Keyboard Activity
    
    func test_should_return_idle_when_keyboard_is_active() {
        // given
        let segment = AutoZoomSegment(
            timeRange: 1.0...3.0,
            focusCenter: CGPoint(x: 0.5, y: 0.5),
            zoomScale: 2.0
        )
        let timeline = ZoomTimeline(segments: [segment], duration: 10.0)
        
        // when - keyboard is active during segment
        let state = timeline.state(
            at: 2.0,
            cursorPosition: CGPoint(x: 0.5, y: 0.5),
            followCursor: false,
            smoothing: 0.2,
            hasKeyboardActivity: true
        )
        
        // then - should force idle state (no zoom while typing)
        XCTAssertEqual(state.scale, 1.0)
        XCTAssertFalse(state.isActive)
    }
    
    func test_should_zoom_normally_when_no_keyboard_activity() {
        // given
        let segment = AutoZoomSegment(
            timeRange: 1.0...3.0,
            focusCenter: CGPoint(x: 0.5, y: 0.5),
            zoomScale: 2.0
        )
        let timeline = ZoomTimeline(segments: [segment], duration: 10.0)
        
        // when - no keyboard activity during segment
        let state = timeline.state(
            at: 2.0,
            cursorPosition: CGPoint(x: 0.5, y: 0.5),
            followCursor: false,
            smoothing: 0.2,
            hasKeyboardActivity: false
        )
        
        // then - should zoom normally
        XCTAssertGreaterThan(state.scale, 1.0)
        XCTAssertTrue(state.isActive)
    }
}
