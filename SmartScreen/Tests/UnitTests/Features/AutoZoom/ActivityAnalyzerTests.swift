import XCTest
@testable import SmartScreen

final class ActivityAnalyzerTests: XCTestCase {
    
    // MARK: - Empty Input
    
    func test_should_return_empty_windows_for_empty_session() {
        // given
        let analyzer = ActivityAnalyzer()
        let session = CursorTrackSession(events: [], duration: 10.0)
        
        // when
        let windows = analyzer.analyze(session: session)
        
        // then
        XCTAssertTrue(windows.isEmpty)
    }
    
    // MARK: - Window Generation
    
    func test_should_generate_windows_for_move_events() {
        // given
        let analyzer = ActivityAnalyzer()
        let events = (0..<30).map { i in
            MouseEvent(
                type: .move,
                position: CGPoint(x: 0.5 + Double(i) * 0.01, y: 0.5),
                timestamp: Double(i) * 0.1
            )
        }
        let session = CursorTrackSession(events: events, duration: 3.0)
        
        // when
        let windows = analyzer.analyze(session: session)
        
        // then
        XCTAssertFalse(windows.isEmpty)
    }
    
    // MARK: - Bounding Box Calculation
    
    func test_should_calculate_bounding_box() {
        // given
        let analyzer = ActivityAnalyzer()
        let events = [
            MouseEvent(type: .move, position: CGPoint(x: 0.2, y: 0.3), timestamp: 0.0),
            MouseEvent(type: .move, position: CGPoint(x: 0.4, y: 0.5), timestamp: 0.5),
            MouseEvent(type: .move, position: CGPoint(x: 0.3, y: 0.4), timestamp: 1.0)
        ]
        let session = CursorTrackSession(events: events, duration: 1.0)
        
        // when
        let windows = analyzer.analyze(session: session)
        
        // then
        guard let window = windows.first else {
            XCTFail("Expected at least one window")
            return
        }
        
        // Bounding box should contain all points
        XCTAssertLessThanOrEqual(window.boundingBox.minX, 0.2)
        XCTAssertGreaterThanOrEqual(window.boundingBox.maxX, 0.4)
        XCTAssertLessThanOrEqual(window.boundingBox.minY, 0.3)
        XCTAssertGreaterThanOrEqual(window.boundingBox.maxY, 0.5)
    }
    
    // MARK: - Click Detection
    
    func test_should_detect_click_in_window() {
        // given
        let analyzer = ActivityAnalyzer()
        let events = [
            MouseEvent(type: .move, position: CGPoint(x: 0.5, y: 0.5), timestamp: 0.0),
            MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 0.5),
            MouseEvent(type: .move, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0)
        ]
        let session = CursorTrackSession(events: events, duration: 1.0)
        
        // when
        let windows = analyzer.analyze(session: session)
        
        // then
        XCTAssertTrue(windows.contains { $0.hasClick })
    }
    
    // MARK: - Dwell Detection
    
    func test_should_detect_dwell_when_stationary() {
        // given
        let analyzer = ActivityAnalyzer()
        // Create events with very small movement (simulating dwell)
        let events = (0..<20).map { i in
            MouseEvent(
                type: .move,
                position: CGPoint(x: 0.5 + Double(i) * 0.001, y: 0.5),  // Very small movement
                timestamp: Double(i) * 0.1
            )
        }
        let session = CursorTrackSession(events: events, duration: 2.0)
        
        // when
        let windows = analyzer.analyze(session: session)
        
        // then - should have low velocity windows
        let lowVelocityWindows = windows.filter { $0.averageVelocity < 0.05 }
        XCTAssertFalse(lowVelocityWindows.isEmpty)
    }
    
    // MARK: - Velocity Calculation
    
    func test_should_calculate_higher_velocity_for_fast_movement() {
        // given
        let analyzer = ActivityAnalyzer()
        
        // Fast movement
        let fastEvents = [
            MouseEvent(type: .move, position: CGPoint(x: 0.1, y: 0.5), timestamp: 0.0),
            MouseEvent(type: .move, position: CGPoint(x: 0.9, y: 0.5), timestamp: 0.5),
            MouseEvent(type: .move, position: CGPoint(x: 0.1, y: 0.5), timestamp: 1.0)
        ]
        let fastSession = CursorTrackSession(events: fastEvents, duration: 1.0)
        
        // Slow movement
        let slowEvents = [
            MouseEvent(type: .move, position: CGPoint(x: 0.5, y: 0.5), timestamp: 0.0),
            MouseEvent(type: .move, position: CGPoint(x: 0.51, y: 0.5), timestamp: 0.5),
            MouseEvent(type: .move, position: CGPoint(x: 0.52, y: 0.5), timestamp: 1.0)
        ]
        let slowSession = CursorTrackSession(events: slowEvents, duration: 1.0)
        
        // when
        let fastWindows = analyzer.analyze(session: fastSession)
        let slowWindows = analyzer.analyze(session: slowSession)
        
        // then
        guard let fastWindow = fastWindows.first, let slowWindow = slowWindows.first else {
            XCTFail("Expected windows")
            return
        }
        
        XCTAssertGreaterThan(fastWindow.averageVelocity, slowWindow.averageVelocity)
    }
    
    // MARK: - Centroid Calculation
    
    func test_should_calculate_centroid() {
        // given
        let analyzer = ActivityAnalyzer()
        let events = [
            MouseEvent(type: .move, position: CGPoint(x: 0.0, y: 0.0), timestamp: 0.0),
            MouseEvent(type: .move, position: CGPoint(x: 1.0, y: 1.0), timestamp: 0.5),
            MouseEvent(type: .move, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0)
        ]
        let session = CursorTrackSession(events: events, duration: 1.0)
        
        // when
        let windows = analyzer.analyze(session: session)
        
        // then
        guard let window = windows.first else {
            XCTFail("Expected window")
            return
        }
        
        // Centroid should be around center
        XCTAssertEqual(window.centroid.x, 0.5, accuracy: 0.1)
        XCTAssertEqual(window.centroid.y, 0.5, accuracy: 0.1)
    }
}
