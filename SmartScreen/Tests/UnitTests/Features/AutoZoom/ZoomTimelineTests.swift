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
        
        // when - at 0.15s (middle of 25% zoom in phase)
        let state = timeline.state(at: 0.15)
        
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
        
        // when - at 0.6s (middle of 50% hold phase)
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
        
        // when - at 1.05s (middle of 25% zoom out phase)
        let state = timeline.state(at: 1.05)
        
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
}
