import XCTest
@testable import SmartScreen

final class SmartZoomBehaviorAnalyzerTests: XCTestCase {
    
    var sut: SmartZoomBehaviorAnalyzer!
    var config: ZoomBehaviorConfig!
    
    override func setUp() {
        super.setUp()
        config = .default
        sut = SmartZoomBehaviorAnalyzer(config: config)
    }
    
    override func tearDown() {
        sut = nil
        config = nil
        super.tearDown()
    }
    
    // MARK: - Empty Session
    
    func test_should_return_empty_timeline_for_empty_session() {
        // given
        let session = CursorTrackSession(events: [], duration: 10.0)
        
        // when
        let timeline = sut.analyze(session: session)
        
        // then
        XCTAssertTrue(timeline.keyframes.isEmpty)
        XCTAssertEqual(timeline.duration, 10.0)
    }
    
    // MARK: - Stabilization Behavior
    
    func test_should_not_zoom_immediately_on_click() {
        // given - single click without stabilization time
        let session = CursorTrackSession(events: [
            MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0)
        ], duration: 2.0)
        
        // when
        let timeline = sut.analyze(session: session)
        
        // then - should start observing but not zoom yet
        let stateAt1_2 = timeline.state(at: 1.2)
        XCTAssertEqual(stateAt1_2.scale, 1.0, accuracy: 0.01) // Still at 1.0x
    }
    
    func test_should_zoom_after_stabilization_time() {
        // given - click followed by cursor staying in area
        let session = CursorTrackSession(events: [
            MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0),
            MouseEvent(type: .move, position: CGPoint(x: 0.51, y: 0.51), timestamp: 1.3),
            MouseEvent(type: .move, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.5),
            MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.6) // Confirm position
        ], duration: 5.0)
        
        // when
        let timeline = sut.analyze(session: session)
        
        // then - should zoom after stabilization (0.5s default + animation time)
        let stateAfterZoom = timeline.state(at: 2.5)
        XCTAssertGreaterThan(stateAfterZoom.scale, 1.0) // Should be zoomed
    }
    
    // MARK: - Large Movement Behavior
    
    func test_should_zoom_out_on_large_movement() {
        // given - click, stabilize, zoom, then large movement
        let events: [MouseEvent] = [
            // First stable click
            MouseEvent(type: .leftClick, position: CGPoint(x: 0.2, y: 0.2), timestamp: 0.5),
            MouseEvent(type: .move, position: CGPoint(x: 0.2, y: 0.2), timestamp: 0.8),
            MouseEvent(type: .leftClick, position: CGPoint(x: 0.2, y: 0.2), timestamp: 1.2), // Triggers zoom
            // Large movement (> 0.25 normalized distance)
            MouseEvent(type: .leftClick, position: CGPoint(x: 0.8, y: 0.8), timestamp: 2.5)
        ]
        let session = CursorTrackSession(events: events, duration: 5.0)
        
        // when
        let timeline = sut.analyze(session: session)
        
        // then - should have keyframes showing zoom out before re-zoom
        let keyframeCount = timeline.keyframes.count
        XCTAssertGreaterThan(keyframeCount, 2) // Multiple transitions
    }
    
    // MARK: - High Frequency Click Suppression
    
    func test_should_suppress_zoom_on_high_frequency_clicks() {
        // given - rapid clicks (> 3 per second)
        let events: [MouseEvent] = (0..<5).map { i in
            MouseEvent(
                type: .leftClick,
                position: CGPoint(x: 0.5, y: 0.5),
                timestamp: Double(i) * 0.2 // 5 clicks per second
            )
        }
        let session = CursorTrackSession(events: events, duration: 2.0)
        
        // when
        let timeline = sut.analyze(session: session)
        
        // then - should stay at 1.0x due to high frequency
        let stateAt1 = timeline.state(at: 1.0)
        XCTAssertEqual(stateAt1.scale, 1.0, accuracy: 0.01)
    }
    
    // MARK: - Timeline Interpolation
    
    func test_should_interpolate_smoothly_between_keyframes() {
        // given - timeline with two keyframes
        let keyframes = [
            SmartZoomKeyframe(time: 0, scale: 1.0, center: CGPoint(x: 0.5, y: 0.5)),
            SmartZoomKeyframe(time: 1.0, scale: 2.0, center: CGPoint(x: 0.3, y: 0.3))
        ]
        let timeline = SmartZoomTimeline(keyframes: keyframes, duration: 2.0)
        
        // when - query at midpoint
        let stateMid = timeline.state(at: 0.5)
        
        // then - should be interpolated
        XCTAssertGreaterThan(stateMid.scale, 1.0)
        XCTAssertLessThan(stateMid.scale, 2.0)
    }
    
    func test_should_return_first_keyframe_before_timeline() {
        // given
        let keyframes = [
            SmartZoomKeyframe(time: 1.0, scale: 2.0, center: CGPoint(x: 0.5, y: 0.5))
        ]
        let timeline = SmartZoomTimeline(keyframes: keyframes, duration: 5.0)
        
        // when
        let stateBefore = timeline.state(at: 0.5)
        
        // then
        XCTAssertEqual(stateBefore.scale, 2.0)
    }
    
    func test_should_return_last_keyframe_after_timeline() {
        // given
        let keyframes = [
            SmartZoomKeyframe(time: 0, scale: 1.0, center: CGPoint(x: 0.5, y: 0.5)),
            SmartZoomKeyframe(time: 1.0, scale: 2.0, center: CGPoint(x: 0.3, y: 0.3))
        ]
        let timeline = SmartZoomTimeline(keyframes: keyframes, duration: 5.0)
        
        // when
        let stateAfter = timeline.state(at: 3.0)
        
        // then
        XCTAssertEqual(stateAfter.scale, 2.0)
        XCTAssertEqual(stateAfter.center.x, 0.3, accuracy: 0.001)
    }
    
    // MARK: - Boundary Constraints
    
    func test_should_constrain_zoom_center_at_edges() {
        // given - click at corner
        let events: [MouseEvent] = [
            MouseEvent(type: .leftClick, position: CGPoint(x: 0.1, y: 0.1), timestamp: 0.5),
            MouseEvent(type: .move, position: CGPoint(x: 0.1, y: 0.1), timestamp: 0.8),
            MouseEvent(type: .leftClick, position: CGPoint(x: 0.1, y: 0.1), timestamp: 1.2)
        ]
        let session = CursorTrackSession(events: events, duration: 5.0)
        
        // when
        let timeline = sut.analyze(session: session)
        
        // then - center should be constrained (at 2x zoom, min is 0.25)
        for keyframe in timeline.keyframes where keyframe.scale > 1.0 {
            let minAllowed = 1.0 / (keyframe.scale * 2) // Half of visible width
            XCTAssertGreaterThanOrEqual(keyframe.center.x, minAllowed)
            XCTAssertGreaterThanOrEqual(keyframe.center.y, minAllowed)
        }
    }
}
