import XCTest
@testable import SmartScreen

final class ClickEventTests: XCTestCase {
    
    // MARK: - Creation
    
    func test_should_create_left_click_event() {
        // given
        let position = CGPoint(x: 100, y: 200)
        let timestamp: TimeInterval = 1000
        
        // when
        let event = ClickEvent(type: .leftClick, position: position, timestamp: timestamp)
        
        // then
        XCTAssertEqual(event.type, .leftClick)
        XCTAssertEqual(event.position, position)
        XCTAssertEqual(event.timestamp, timestamp)
    }
    
    func test_should_create_double_click_event() {
        // given
        let position = CGPoint(x: 50, y: 50)
        
        // when
        let event = ClickEvent(type: .doubleClick, position: position, timestamp: 0)
        
        // then
        XCTAssertEqual(event.type, .doubleClick)
    }
    
    func test_should_create_right_click_event() {
        // given
        let position = CGPoint(x: 50, y: 50)
        
        // when
        let event = ClickEvent(type: .rightClick, position: position, timestamp: 0)
        
        // then
        XCTAssertEqual(event.type, .rightClick)
    }
    
    // MARK: - Click Type Properties
    
    func test_should_return_correct_color_for_left_click() {
        XCTAssertEqual(ClickType.leftClick.highlightColor, .blue)
    }
    
    func test_should_return_correct_color_for_double_click() {
        XCTAssertEqual(ClickType.doubleClick.highlightColor, .blue)
    }
    
    func test_should_return_correct_color_for_right_click() {
        XCTAssertEqual(ClickType.rightClick.highlightColor, .orange)
    }
    
    func test_should_return_correct_duration_for_click_types() {
        XCTAssertEqual(ClickType.leftClick.animationDuration, 0.3, accuracy: 0.001)
        XCTAssertEqual(ClickType.doubleClick.animationDuration, 0.4, accuracy: 0.001)
        XCTAssertEqual(ClickType.rightClick.animationDuration, 0.3, accuracy: 0.001)
    }
}
