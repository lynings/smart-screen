import XCTest
@testable import SmartScreen

final class ContinuousZoomAnalyzerTests: XCTestCase {
    
    // MARK: - Empty Session
    
    func test_should_return_empty_timeline_when_session_is_empty() {
        // given
        let sut = ContinuousZoomAnalyzer()
        let session = CursorTrackSession(events: [], duration: 10.0)
        let settings = AutoZoomSettings.default
        
        // when
        let timeline = sut.analyze(session: session, settings: settings)
        
        // then
        XCTAssertTrue(timeline.keyframes.isEmpty)
    }
    
    func test_should_return_empty_timeline_when_auto_zoom_disabled() {
        // given
        let sut = ContinuousZoomAnalyzer()
        let events = [
            MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0)
        ]
        let session = CursorTrackSession(events: events, duration: 5.0)
        var settings = AutoZoomSettings.default
        settings.isEnabled = false
        
        // when
        let timeline = sut.analyze(session: session, settings: settings)
        
        // then
        XCTAssertTrue(timeline.keyframes.isEmpty)
    }
    
    // MARK: - Click Triggers
    
    func test_should_generate_zoom_for_click_event() {
        // given
        let sut = ContinuousZoomAnalyzer()
        let events = [
            MouseEvent(type: .move, position: CGPoint(x: 0.5, y: 0.5), timestamp: 0.0),
            MouseEvent(type: .move, position: CGPoint(x: 0.5, y: 0.5), timestamp: 0.5),
            MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0),
            MouseEvent(type: .move, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.5),
            MouseEvent(type: .move, position: CGPoint(x: 0.5, y: 0.5), timestamp: 2.0)
        ]
        let session = CursorTrackSession(events: events, duration: 5.0)
        let settings = AutoZoomSettings.default
        
        // when
        let timeline = sut.analyze(session: session, settings: settings)
        
        // then
        XCTAssertFalse(timeline.keyframes.isEmpty)
        
        // Check that zoom is active around click time
        let stateAtClick = timeline.stateAt(time: 1.5)
        XCTAssertGreaterThan(stateAtClick.scale, 1.0)
    }
    
    // MARK: - Continuous Timeline
    
    func test_should_generate_continuous_timeline_for_multiple_clicks() {
        // given
        let sut = ContinuousZoomAnalyzer()
        var events: [MouseEvent] = []
        
        // Add movement and clicks
        for i in 0..<50 {
            let time = Double(i) * 0.1
            events.append(MouseEvent(type: .move, position: CGPoint(x: 0.5, y: 0.5), timestamp: time))
        }
        events.append(MouseEvent(type: .leftClick, position: CGPoint(x: 0.3, y: 0.3), timestamp: 1.0))
        events.append(MouseEvent(type: .leftClick, position: CGPoint(x: 0.7, y: 0.7), timestamp: 2.0))
        
        let session = CursorTrackSession(events: events.sorted { $0.timestamp < $1.timestamp }, duration: 5.0)
        let settings = AutoZoomSettings.default
        
        // when
        let timeline = sut.analyze(session: session, settings: settings)
        
        // then
        XCTAssertFalse(timeline.keyframes.isEmpty)
        
        // Check that timeline has reasonable scale values
        for keyframe in timeline.keyframes {
            // Scale should be within valid range
            XCTAssertGreaterThanOrEqual(keyframe.scale, 1.0)
            XCTAssertLessThanOrEqual(keyframe.scale, 3.0)
        }
        
        // Final keyframe should return to scale 1.0
        if let lastKeyframe = timeline.keyframes.last {
            XCTAssertEqual(lastKeyframe.scale, 1.0, accuracy: 0.01)
        }
    }
    
    // MARK: - State Interpolation
    
    func test_should_interpolate_state_between_keyframes() {
        // given
        let keyframes = [
            ZoomKeyframe(time: 0.0, scale: 1.0, center: CGPoint(x: 0.5, y: 0.5)),
            ZoomKeyframe(time: 1.0, scale: 2.0, center: CGPoint(x: 0.5, y: 0.5)),
            ZoomKeyframe(time: 2.0, scale: 2.0, center: CGPoint(x: 0.5, y: 0.5)),
            ZoomKeyframe(time: 3.0, scale: 1.0, center: CGPoint(x: 0.5, y: 0.5))
        ]
        let timeline = ContinuousZoomTimeline(keyframes: keyframes, duration: 3.0)
        
        // when
        let stateAtHalf = timeline.stateAt(time: 0.5)
        let stateAtOne = timeline.stateAt(time: 1.0)
        let stateAtTwoFive = timeline.stateAt(time: 2.5)
        
        // then
        XCTAssertGreaterThan(stateAtHalf.scale, 1.0)
        XCTAssertLessThan(stateAtHalf.scale, 2.0)
        XCTAssertEqual(stateAtOne.scale, 2.0, accuracy: 0.01)
        XCTAssertGreaterThan(stateAtTwoFive.scale, 1.0)
        XCTAssertLessThan(stateAtTwoFive.scale, 2.0)
    }
    
    // MARK: - Zoom Active Detection
    
    func test_should_detect_when_zoom_is_active() {
        // given
        let keyframes = [
            ZoomKeyframe(time: 0.0, scale: 1.0, center: CGPoint(x: 0.5, y: 0.5)),
            ZoomKeyframe(time: 1.0, scale: 2.0, center: CGPoint(x: 0.5, y: 0.5)),
            ZoomKeyframe(time: 2.0, scale: 1.0, center: CGPoint(x: 0.5, y: 0.5))
        ]
        let timeline = ContinuousZoomTimeline(keyframes: keyframes, duration: 2.0)
        
        // when/then
        XCTAssertFalse(timeline.isZoomActive(at: 0.0))
        XCTAssertTrue(timeline.isZoomActive(at: 1.0))
        XCTAssertFalse(timeline.isZoomActive(at: 2.0))
    }
    
    // MARK: - Center Following
    
    func test_should_follow_cursor_center_during_zoom() {
        // given
        let sut = ContinuousZoomAnalyzer()
        var events: [MouseEvent] = []
        
        // Click at left side
        events.append(MouseEvent(type: .leftClick, position: CGPoint(x: 0.2, y: 0.5), timestamp: 0.5))
        
        // Move to right side while zoomed
        for i in 0..<20 {
            let time = 0.6 + Double(i) * 0.1
            let x = 0.2 + CGFloat(i) * 0.03
            events.append(MouseEvent(type: .move, position: CGPoint(x: x, y: 0.5), timestamp: time))
        }
        
        let session = CursorTrackSession(events: events, duration: 5.0)
        let settings = AutoZoomSettings.default
        
        // when
        let timeline = sut.analyze(session: session, settings: settings)
        
        // then
        let stateAtStart = timeline.stateAt(time: 0.6)
        let stateAtEnd = timeline.stateAt(time: 2.0)
        
        // Center should have moved to follow cursor
        if stateAtStart.scale > 1.0 && stateAtEnd.scale > 1.0 {
            XCTAssertGreaterThan(stateAtEnd.center.x, stateAtStart.center.x)
        }
    }
}
