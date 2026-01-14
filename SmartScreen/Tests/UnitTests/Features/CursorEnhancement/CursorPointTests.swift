import XCTest
@testable import SmartScreen

final class CursorPointTests: XCTestCase {
    
    // MARK: - Creation
    
    func test_should_create_cursor_point_with_position_and_timestamp() {
        // given
        let position = CGPoint(x: 100, y: 200)
        let timestamp: TimeInterval = 1000
        
        // when
        let point = CursorPoint(position: position, timestamp: timestamp)
        
        // then
        XCTAssertEqual(point.position, position)
        XCTAssertEqual(point.timestamp, timestamp)
    }
    
    func test_should_calculate_distance_to_another_point() {
        // given
        let point1 = CursorPoint(position: CGPoint(x: 0, y: 0), timestamp: 0)
        let point2 = CursorPoint(position: CGPoint(x: 3, y: 4), timestamp: 1)
        
        // when
        let distance = point1.distance(to: point2)
        
        // then
        XCTAssertEqual(distance, 5.0, accuracy: 0.001)
    }
    
    func test_should_calculate_velocity_between_points() {
        // given
        let point1 = CursorPoint(position: CGPoint(x: 0, y: 0), timestamp: 0)
        let point2 = CursorPoint(position: CGPoint(x: 100, y: 0), timestamp: 0.1)
        
        // when
        let velocity = point1.velocity(to: point2)
        
        // then
        XCTAssertEqual(velocity, 1000.0, accuracy: 0.001) // 100 pixels / 0.1 seconds
    }
    
    func test_should_return_zero_velocity_when_same_timestamp() {
        // given
        let point1 = CursorPoint(position: CGPoint(x: 0, y: 0), timestamp: 1.0)
        let point2 = CursorPoint(position: CGPoint(x: 100, y: 0), timestamp: 1.0)
        
        // when
        let velocity = point1.velocity(to: point2)
        
        // then
        XCTAssertEqual(velocity, 0.0)
    }
}
