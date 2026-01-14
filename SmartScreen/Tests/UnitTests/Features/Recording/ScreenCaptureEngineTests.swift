import XCTest
@testable import SmartScreen

final class ScreenCaptureEngineTests: XCTestCase {
    
    // MARK: - Initial State
    
    func test_should_not_be_recording_initially() async {
        // given
        let sut = ScreenCaptureEngine()
        
        // when
        let isRecording = await sut.isRecording
        
        // then
        XCTAssertFalse(isRecording)
    }
    
    func test_should_have_zero_duration_initially() async {
        // given
        let sut = ScreenCaptureEngine()
        
        // when
        let duration = await sut.duration
        
        // then
        XCTAssertEqual(duration, 0)
    }
}
