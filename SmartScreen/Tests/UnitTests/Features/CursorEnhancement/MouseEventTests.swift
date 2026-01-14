import XCTest
@testable import SmartScreen

final class MouseEventTests: XCTestCase {
    
    // MARK: - Creation
    
    func test_should_create_mouse_move_event() {
        // given
        let position = CGPoint(x: 100, y: 200)
        let timestamp: TimeInterval = 1.5
        
        // when
        let event = MouseEvent(type: .move, position: position, timestamp: timestamp)
        
        // then
        XCTAssertEqual(event.type, .move)
        XCTAssertEqual(event.position, position)
        XCTAssertEqual(event.timestamp, timestamp)
    }
    
    func test_should_create_left_click_event() {
        // given
        let position = CGPoint(x: 50, y: 50)
        
        // when
        let event = MouseEvent(type: .leftClick, position: position, timestamp: 0)
        
        // then
        XCTAssertEqual(event.type, .leftClick)
    }
    
    func test_should_create_right_click_event() {
        // given
        let position = CGPoint(x: 50, y: 50)
        
        // when
        let event = MouseEvent(type: .rightClick, position: position, timestamp: 0)
        
        // then
        XCTAssertEqual(event.type, .rightClick)
    }
    
    func test_should_create_double_click_event() {
        // given
        let position = CGPoint(x: 50, y: 50)
        
        // when
        let event = MouseEvent(type: .doubleClick, position: position, timestamp: 0)
        
        // then
        XCTAssertEqual(event.type, .doubleClick)
    }
    
    // MARK: - Codable
    
    func test_should_encode_and_decode_mouse_event() throws {
        // given
        let event = MouseEvent(
            type: .leftClick,
            position: CGPoint(x: 100, y: 200),
            timestamp: 1.5
        )
        
        // when
        let encoder = JSONEncoder()
        let data = try encoder.encode(event)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MouseEvent.self, from: data)
        
        // then
        XCTAssertEqual(decoded.type, event.type)
        XCTAssertEqual(decoded.position.x, event.position.x, accuracy: 0.001)
        XCTAssertEqual(decoded.position.y, event.position.y, accuracy: 0.001)
        XCTAssertEqual(decoded.timestamp, event.timestamp, accuracy: 0.001)
    }
    
    // MARK: - Conversion to CursorPoint
    
    func test_should_convert_to_cursor_point() {
        // given
        let event = MouseEvent(
            type: .move,
            position: CGPoint(x: 100, y: 200),
            timestamp: 1.5
        )
        
        // when
        let cursorPoint = event.toCursorPoint()
        
        // then
        XCTAssertEqual(cursorPoint.position, event.position)
        XCTAssertEqual(cursorPoint.timestamp, event.timestamp)
    }
    
    // MARK: - Conversion to ClickEvent
    
    func test_should_convert_left_click_to_click_event() {
        // given
        let event = MouseEvent(type: .leftClick, position: CGPoint(x: 100, y: 200), timestamp: 1.5)
        
        // when
        let clickEvent = event.toClickEvent()
        
        // then
        XCTAssertNotNil(clickEvent)
        XCTAssertEqual(clickEvent?.type, .leftClick)
        XCTAssertEqual(clickEvent?.position, event.position)
    }
    
    func test_should_return_nil_for_move_event_conversion() {
        // given
        let event = MouseEvent(type: .move, position: CGPoint(x: 100, y: 200), timestamp: 1.5)
        
        // when
        let clickEvent = event.toClickEvent()
        
        // then
        XCTAssertNil(clickEvent)
    }
}
