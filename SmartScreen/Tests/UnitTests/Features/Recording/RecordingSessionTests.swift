import XCTest
@testable import SmartScreen

final class RecordingSessionTests: XCTestCase {
    
    // MARK: - Creation
    
    func test_should_create_session_with_generated_id() {
        // given
        let outputURL = URL(fileURLWithPath: "/tmp/test.mp4")
        
        // when
        let sut = RecordingSession(outputURL: outputURL, duration: 60)
        
        // then
        XCTAssertNotNil(sut.id)
        XCTAssertEqual(sut.outputURL, outputURL)
        XCTAssertEqual(sut.duration, 60)
    }
    
    func test_should_create_session_with_custom_id() {
        // given
        let customID = UUID()
        let outputURL = URL(fileURLWithPath: "/tmp/test.mp4")
        
        // when
        let sut = RecordingSession(id: customID, outputURL: outputURL, duration: 120)
        
        // then
        XCTAssertEqual(sut.id, customID)
    }
    
    func test_should_set_created_at_to_current_time() {
        // given
        let outputURL = URL(fileURLWithPath: "/tmp/test.mp4")
        let beforeCreation = Date()
        
        // when
        let sut = RecordingSession(outputURL: outputURL, duration: 30)
        let afterCreation = Date()
        
        // then
        XCTAssertGreaterThanOrEqual(sut.createdAt, beforeCreation)
        XCTAssertLessThanOrEqual(sut.createdAt, afterCreation)
    }
}
