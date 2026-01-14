import XCTest
@testable import SmartScreen

final class CursorTrackSessionTests: XCTestCase {
    
    // MARK: - Creation
    
    func test_should_create_session_with_events() {
        // given
        let events = [
            MouseEvent(type: .move, position: CGPoint(x: 10, y: 10), timestamp: 0.1),
            MouseEvent(type: .leftClick, position: CGPoint(x: 20, y: 20), timestamp: 0.2)
        ]
        let duration: TimeInterval = 10.0
        
        // when
        let session = CursorTrackSession(events: events, duration: duration)
        
        // then
        XCTAssertEqual(session.events.count, 2)
        XCTAssertEqual(session.duration, duration)
    }
    
    func test_should_create_empty_session() {
        // given/when
        let session = CursorTrackSession(events: [], duration: 0)
        
        // then
        XCTAssertTrue(session.events.isEmpty)
        XCTAssertEqual(session.duration, 0)
    }
    
    // MARK: - Cursor Points Extraction
    
    func test_should_extract_cursor_points_from_move_events() {
        // given
        let events = [
            MouseEvent(type: .move, position: CGPoint(x: 10, y: 10), timestamp: 0.1),
            MouseEvent(type: .leftClick, position: CGPoint(x: 20, y: 20), timestamp: 0.2),
            MouseEvent(type: .move, position: CGPoint(x: 30, y: 30), timestamp: 0.3)
        ]
        let session = CursorTrackSession(events: events, duration: 1.0)
        
        // when
        let cursorPoints = session.cursorPoints
        
        // then
        XCTAssertEqual(cursorPoints.count, 2)
        XCTAssertEqual(cursorPoints[0].position, CGPoint(x: 10, y: 10))
        XCTAssertEqual(cursorPoints[1].position, CGPoint(x: 30, y: 30))
    }
    
    // MARK: - Click Events Extraction
    
    func test_should_extract_click_events() {
        // given
        let events = [
            MouseEvent(type: .move, position: CGPoint(x: 10, y: 10), timestamp: 0.1),
            MouseEvent(type: .leftClick, position: CGPoint(x: 20, y: 20), timestamp: 0.2),
            MouseEvent(type: .rightClick, position: CGPoint(x: 30, y: 30), timestamp: 0.3)
        ]
        let session = CursorTrackSession(events: events, duration: 1.0)
        
        // when
        let clickEvents = session.clickEvents
        
        // then
        XCTAssertEqual(clickEvents.count, 2)
        XCTAssertEqual(clickEvents[0].type, .leftClick)
        XCTAssertEqual(clickEvents[1].type, .rightClick)
    }
    
    // MARK: - Smoothed Trajectory
    
    func test_should_return_smoothed_trajectory() {
        // given
        let events = [
            MouseEvent(type: .move, position: CGPoint(x: 0, y: 0), timestamp: 0.0),
            MouseEvent(type: .move, position: CGPoint(x: 10, y: 10), timestamp: 0.1),
            MouseEvent(type: .move, position: CGPoint(x: 5, y: 5), timestamp: 0.2),  // jitter
            MouseEvent(type: .move, position: CGPoint(x: 20, y: 20), timestamp: 0.3)
        ]
        let session = CursorTrackSession(events: events, duration: 1.0)
        
        // when
        let smoothed = session.smoothedTrajectory(level: .medium)
        
        // then
        XCTAssertEqual(smoothed.count, 4)
    }
    
    // MARK: - Position at Time
    
    func test_should_return_position_at_specific_time() {
        // given
        let events = [
            MouseEvent(type: .move, position: CGPoint(x: 0, y: 0), timestamp: 0.0),
            MouseEvent(type: .move, position: CGPoint(x: 100, y: 100), timestamp: 1.0)
        ]
        let session = CursorTrackSession(events: events, duration: 1.0)
        
        // when
        let position = session.positionAt(time: 0.5)
        
        // then
        XCTAssertNotNil(position)
        // Should interpolate to approximately (50, 50)
        XCTAssertEqual(position!.x, 50, accuracy: 1.0)
        XCTAssertEqual(position!.y, 50, accuracy: 1.0)
    }
    
    func test_should_return_nil_when_no_events() {
        // given
        let session = CursorTrackSession(events: [], duration: 1.0)
        
        // when
        let position = session.positionAt(time: 0.5)
        
        // then
        XCTAssertNil(position)
    }
    
    // MARK: - Codable
    
    func test_should_encode_and_decode_session() throws {
        // given
        let events = [
            MouseEvent(type: .move, position: CGPoint(x: 10, y: 10), timestamp: 0.1),
            MouseEvent(type: .leftClick, position: CGPoint(x: 20, y: 20), timestamp: 0.2)
        ]
        let session = CursorTrackSession(events: events, duration: 5.0)
        
        // when
        let encoder = JSONEncoder()
        let data = try encoder.encode(session)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CursorTrackSession.self, from: data)
        
        // then
        XCTAssertEqual(decoded.events.count, session.events.count)
        XCTAssertEqual(decoded.duration, session.duration)
    }
    
    // MARK: - File Persistence
    
    func test_should_save_and_load_from_file() throws {
        // given
        let events = [
            MouseEvent(type: .move, position: CGPoint(x: 10, y: 10), timestamp: 0.1),
            MouseEvent(type: .leftClick, position: CGPoint(x: 20, y: 20), timestamp: 0.2)
        ]
        let session = CursorTrackSession(events: events, duration: 5.0)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_cursor_session.json")
        
        // when
        try session.save(to: tempURL)
        let loaded = try CursorTrackSession.load(from: tempURL)
        
        // then
        XCTAssertEqual(loaded.events.count, session.events.count)
        XCTAssertEqual(loaded.duration, session.duration)
        
        // cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }
}
