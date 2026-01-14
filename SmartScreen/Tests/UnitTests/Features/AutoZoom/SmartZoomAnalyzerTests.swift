import XCTest
@testable import SmartScreen

final class SmartZoomAnalyzerTests: XCTestCase {
    
    // MARK: - Empty Input
    
    func test_should_return_empty_segments_for_empty_session() {
        // given
        let analyzer = SmartZoomAnalyzer()
        let session = CursorTrackSession(events: [], duration: 10.0)
        let settings = AutoZoomSettings()
        
        // when
        let segments = analyzer.analyze(session: session, settings: settings)
        
        // then
        XCTAssertTrue(segments.isEmpty)
    }
    
    func test_should_return_empty_segments_when_disabled() {
        // given
        let analyzer = SmartZoomAnalyzer()
        let events = [
            MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0)
        ]
        let session = CursorTrackSession(events: events, duration: 5.0)
        let settings = AutoZoomSettings(isEnabled: false)
        
        // when
        let segments = analyzer.analyze(session: session, settings: settings)
        
        // then
        XCTAssertTrue(segments.isEmpty)
    }
    
    // MARK: - Click Triggered Zoom
    
    func test_should_create_segment_for_click() {
        // given
        let analyzer = SmartZoomAnalyzer()
        let events = [
            MouseEvent(type: .move, position: CGPoint(x: 0.5, y: 0.5), timestamp: 0.0),
            MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0),
            MouseEvent(type: .move, position: CGPoint(x: 0.5, y: 0.5), timestamp: 2.0)
        ]
        let session = CursorTrackSession(events: events, duration: 5.0)
        let settings = AutoZoomSettings()
        
        // when
        let segments = analyzer.analyze(session: session, settings: settings)
        
        // then
        XCTAssertFalse(segments.isEmpty)
        
        if let segment = segments.first {
            // Should be triggered by click
            if case .click = segment.trigger {
                // Good
            } else {
                XCTFail("Expected click trigger")
            }
        }
    }
    
    // MARK: - Focus Following
    
    func test_should_create_following_segment_for_movement() {
        // given
        let analyzer = SmartZoomAnalyzer()
        // Create movement from left to right
        var events: [MouseEvent] = []
        for i in 0..<30 {
            let x = 0.2 + Double(i) * 0.02  // Move from 0.2 to 0.8
            events.append(MouseEvent(
                type: .move,
                position: CGPoint(x: x, y: 0.5),
                timestamp: Double(i) * 0.1
            ))
        }
        // Add a click in the middle
        events.append(MouseEvent(
            type: .leftClick,
            position: CGPoint(x: 0.5, y: 0.5),
            timestamp: 1.5
        ))
        
        let session = CursorTrackSession(events: events, duration: 3.0)
        let settings = AutoZoomSettings()
        
        // when
        let segments = analyzer.analyze(session: session, settings: settings)
        
        // then
        XCTAssertFalse(segments.isEmpty)
        
        // Segment should have multiple keyframes for following
        if let segment = segments.first {
            XCTAssertGreaterThan(segment.keyframes.count, 2)
        }
    }
    
    // MARK: - Zoom Level Adaptation
    
    func test_should_adapt_zoom_level_to_activity_area() {
        // given
        let analyzer = SmartZoomAnalyzer()
        
        // Small activity area (should get higher zoom)
        let smallAreaEvents = [
            MouseEvent(type: .move, position: CGPoint(x: 0.49, y: 0.49), timestamp: 0.0),
            MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 0.5),
            MouseEvent(type: .move, position: CGPoint(x: 0.51, y: 0.51), timestamp: 1.0)
        ]
        let smallSession = CursorTrackSession(events: smallAreaEvents, duration: 2.0)
        
        // Large activity area (should get lower zoom)
        let largeAreaEvents = [
            MouseEvent(type: .move, position: CGPoint(x: 0.1, y: 0.1), timestamp: 0.0),
            MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 0.5),
            MouseEvent(type: .move, position: CGPoint(x: 0.9, y: 0.9), timestamp: 1.0)
        ]
        let largeSession = CursorTrackSession(events: largeAreaEvents, duration: 2.0)
        
        let settings = AutoZoomSettings()
        
        // when
        let smallSegments = analyzer.analyze(session: smallSession, settings: settings)
        let largeSegments = analyzer.analyze(session: largeSession, settings: settings)
        
        // then
        guard let smallSegment = smallSegments.first,
              let largeSegment = largeSegments.first else {
            XCTFail("Expected segments")
            return
        }
        
        XCTAssertGreaterThan(smallSegment.targetScale, largeSegment.targetScale)
    }
    
    // MARK: - Segment Merging
    
    func test_should_merge_nearby_triggers() {
        // given
        let analyzer = SmartZoomAnalyzer()
        // Two clicks very close together
        let events = [
            MouseEvent(type: .move, position: CGPoint(x: 0.5, y: 0.5), timestamp: 0.0),
            MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0),
            MouseEvent(type: .leftClick, position: CGPoint(x: 0.52, y: 0.52), timestamp: 1.2),
            MouseEvent(type: .move, position: CGPoint(x: 0.5, y: 0.5), timestamp: 2.0)
        ]
        let session = CursorTrackSession(events: events, duration: 5.0)
        let settings = AutoZoomSettings()
        
        // when
        let segments = analyzer.analyze(session: session, settings: settings)
        
        // then - nearby clicks should be merged into one segment
        XCTAssertEqual(segments.count, 1)
    }
}
