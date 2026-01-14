import XCTest
@testable import SmartScreen

final class RecordingErrorTests: XCTestCase {
    
    // MARK: - errorDescription
    
    func test_should_return_permission_message_when_permission_denied() {
        // given
        let sut = RecordingError.permissionDenied
        
        // when
        let description = sut.errorDescription
        
        // then
        XCTAssertEqual(description, "Screen recording permission is required")
    }
    
    func test_should_return_disk_full_message_when_disk_full() {
        // given
        let sut = RecordingError.diskFull
        
        // when
        let description = sut.errorDescription
        
        // then
        XCTAssertEqual(description, "Disk is full")
    }
    
    func test_should_return_device_unavailable_message_when_device_unavailable() {
        // given
        let sut = RecordingError.deviceUnavailable(deviceType: "Microphone")
        
        // when
        let description = sut.errorDescription
        
        // then
        XCTAssertEqual(description, "Microphone device is unavailable")
    }
    
    func test_should_return_capture_failed_message_when_capture_session_failed() {
        // given
        let underlyingError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let sut = RecordingError.captureSessionFailed(underlying: underlyingError)
        
        // when
        let description = sut.errorDescription
        
        // then
        XCTAssertEqual(description, "Capture failed: Test error")
    }
    
    func test_should_return_encoding_failed_message_when_encoding_failed() {
        // given
        let sut = RecordingError.encodingFailed(reason: "Invalid codec")
        
        // when
        let description = sut.errorDescription
        
        // then
        XCTAssertEqual(description, "Encoding failed: Invalid codec")
    }
}
