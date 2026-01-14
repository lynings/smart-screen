import XCTest
@testable import SmartScreen

final class HotspotAnalyzerTests: XCTestCase {
    
    // MARK: - Empty Input
    
    func test_should_return_empty_segments_for_empty_session() {
        // given
        let analyzer = HotspotAnalyzer()
        let session = CursorTrackSession(events: [], duration: 10.0)
        let settings = AutoZoomSettings()
        
        // when
        let segments = analyzer.analyze(session: session, settings: settings)
        
        // then
        XCTAssertTrue(segments.isEmpty)
    }
    
    func test_should_return_empty_segments_when_disabled() {
        // given
        let analyzer = HotspotAnalyzer()
        let session = CursorTrackSession(
            events: [
                MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0)
            ],
            duration: 10.0
        )
        let settings = AutoZoomSettings(isEnabled: false)
        
        // when
        let segments = analyzer.analyze(session: session, settings: settings)
        
        // then
        XCTAssertTrue(segments.isEmpty)
    }
    
    // MARK: - Single Click
    
    func test_should_create_segment_for_single_click() {
        // given
        let analyzer = HotspotAnalyzer()
        let session = CursorTrackSession(
            events: [
                MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 2.0)
            ],
            duration: 10.0
        )
        let settings = AutoZoomSettings(zoomLevel: 2.0)
        
        // when
        let segments = analyzer.analyze(session: session, settings: settings)
        
        // then
        XCTAssertEqual(segments.count, 1)
        
        let segment = segments.first!
        XCTAssertEqual(segment.center, CGPoint(x: 0.5, y: 0.5))
        XCTAssertEqual(segment.scale, 2.0)
    }
    
    func test_should_set_segment_timing_based_on_settings() {
        // given
        let analyzer = HotspotAnalyzer()
        let session = CursorTrackSession(
            events: [
                MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 2.0)
            ],
            duration: 10.0
        )
        let settings = AutoZoomSettings()
        
        // when
        let segments = analyzer.analyze(session: session, settings: settings)
        
        // then
        let segment = segments.first!
        // Segment should start slightly before click for anticipation
        XCTAssertLessThanOrEqual(segment.startTime, 2.0)
        // Total duration is the segment duration from settings
        XCTAssertGreaterThan(segment.duration, 0)
    }
    
    // MARK: - Multiple Clicks
    
    func test_should_create_multiple_segments_for_separate_clicks() {
        // given
        let analyzer = HotspotAnalyzer()
        let session = CursorTrackSession(
            events: [
                MouseEvent(type: .leftClick, position: CGPoint(x: 0.2, y: 0.2), timestamp: 1.0),
                MouseEvent(type: .leftClick, position: CGPoint(x: 0.8, y: 0.8), timestamp: 6.0)
            ],
            duration: 10.0
        )
        let settings = AutoZoomSettings()
        
        // when
        let segments = analyzer.analyze(session: session, settings: settings)
        
        // then
        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[0].center, CGPoint(x: 0.2, y: 0.2))
        XCTAssertEqual(segments[1].center, CGPoint(x: 0.8, y: 0.8))
    }
    
    // MARK: - Click Merging
    
    func test_should_merge_nearby_clicks_into_single_segment() {
        // given
        let analyzer = HotspotAnalyzer()
        let session = CursorTrackSession(
            events: [
                MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0),
                MouseEvent(type: .leftClick, position: CGPoint(x: 0.52, y: 0.52), timestamp: 1.5)
            ],
            duration: 10.0
        )
        let settings = AutoZoomSettings()
        
        // when
        let segments = analyzer.analyze(session: session, settings: settings)
        
        // then - nearby clicks (< 1s apart) should be merged
        XCTAssertEqual(segments.count, 1)
    }
    
    // MARK: - Move Events Ignored
    
    func test_should_ignore_move_events() {
        // given
        let analyzer = HotspotAnalyzer()
        let session = CursorTrackSession(
            events: [
                MouseEvent(type: .move, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0),
                MouseEvent(type: .move, position: CGPoint(x: 0.6, y: 0.6), timestamp: 2.0)
            ],
            duration: 10.0
        )
        let settings = AutoZoomSettings()
        
        // when
        let segments = analyzer.analyze(session: session, settings: settings)
        
        // then
        XCTAssertTrue(segments.isEmpty)
    }
    
    // MARK: - Different Click Types
    
    func test_should_handle_all_click_types() {
        // given
        let analyzer = HotspotAnalyzer()
        let session = CursorTrackSession(
            events: [
                MouseEvent(type: .leftClick, position: CGPoint(x: 0.2, y: 0.2), timestamp: 1.0),
                MouseEvent(type: .rightClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 5.0),
                MouseEvent(type: .doubleClick, position: CGPoint(x: 0.8, y: 0.8), timestamp: 9.0)
            ],
            duration: 15.0
        )
        let settings = AutoZoomSettings()
        
        // when
        let segments = analyzer.analyze(session: session, settings: settings)
        
        // then
        XCTAssertEqual(segments.count, 3)
    }
    
    // MARK: - Boundary Handling
    
    func test_should_clamp_segment_to_video_duration() {
        // given
        let analyzer = HotspotAnalyzer()
        let session = CursorTrackSession(
            events: [
                MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 9.5)
            ],
            duration: 10.0
        )
        let settings = AutoZoomSettings()  // Default settings
        
        // when
        let segments = analyzer.analyze(session: session, settings: settings)
        
        // then
        let segment = segments.first!
        XCTAssertLessThanOrEqual(segment.endTime, 10.0)
    }
}
