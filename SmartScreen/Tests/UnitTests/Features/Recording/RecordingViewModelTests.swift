import XCTest
@testable import SmartScreen

@MainActor
final class RecordingViewModelTests: XCTestCase {
    
    // MARK: - Fixtures
    
    private func makeSUT(
        captureEngine: MockCaptureEngine = MockCaptureEngine()
    ) -> (sut: RecordingViewModel, engine: MockCaptureEngine) {
        let viewModel = RecordingViewModel(captureEngine: captureEngine)
        return (viewModel, captureEngine)
    }
    
    private func makeConfig(
        source: CaptureSource = .fullScreen(displayID: 1)
    ) -> CaptureConfig {
        CaptureConfig(source: source)
    }
    
    // MARK: - Initial State
    
    func test_should_not_be_recording_initially() {
        // given
        let (sut, _) = makeSUT()
        
        // when
        // (initial state)
        
        // then
        XCTAssertFalse(sut.isRecording)
        XCTAssertFalse(sut.isPaused)
        XCTAssertNil(sut.error)
    }
    
    // MARK: - startRecording
    
    func test_should_start_recording_when_permission_granted() async {
        // given
        let (sut, engine) = makeSUT()
        engine.hasPermission = true
        let config = makeConfig()
        
        // when
        await sut.startRecording(config: config)
        
        // then
        XCTAssertTrue(sut.isRecording)
        XCTAssertEqual(engine.startCaptureCallCount, 1)
        XCTAssertNil(sut.error)
    }
    
    func test_should_show_error_when_permission_denied() async {
        // given
        let (sut, engine) = makeSUT()
        engine.hasPermission = false
        let config = makeConfig()
        
        // when
        await sut.startRecording(config: config)
        
        // then
        XCTAssertFalse(sut.isRecording)
        XCTAssertEqual(sut.error, .permissionDenied)
    }
    
    func test_should_show_error_when_capture_fails() async {
        // given
        let (sut, engine) = makeSUT()
        engine.hasPermission = true
        engine.shouldFailOnStart = true
        engine.failureError = .diskFull
        let config = makeConfig()
        
        // when
        await sut.startRecording(config: config)
        
        // then
        XCTAssertFalse(sut.isRecording)
        XCTAssertEqual(sut.error, .diskFull)
    }
    
    func test_should_pass_config_to_capture_engine() async {
        // given
        let (sut, engine) = makeSUT()
        let audioDevice = AudioDevice(id: "mic1", name: "Built-in Mic")
        let config = CaptureConfig(
            source: .window(windowID: 123),
            audioDevice: audioDevice,
            fps: 60,
            resolution: .p4K
        )
        
        // when
        await sut.startRecording(config: config)
        
        // then
        XCTAssertEqual(engine.lastConfig?.fps, 60)
        XCTAssertEqual(engine.lastConfig?.resolution, .p4K)
        XCTAssertEqual(engine.lastConfig?.audioDevice?.id, "mic1")
    }
    
    // MARK: - stopRecording
    
    func test_should_stop_recording_and_return_session() async {
        // given
        let (sut, engine) = makeSUT()
        engine.hasPermission = true
        let expectedURL = URL(fileURLWithPath: "/tmp/test.mp4")
        engine.mockSession = RecordingSession(outputURL: expectedURL, duration: 120)
        
        await sut.startRecording(config: makeConfig())
        
        // when
        let session = await sut.stopRecording()
        
        // then
        XCTAssertFalse(sut.isRecording)
        XCTAssertEqual(engine.stopCaptureCallCount, 1)
        XCTAssertEqual(session?.outputURL, expectedURL)
        XCTAssertEqual(session?.duration, 120)
    }
    
    func test_should_return_nil_when_stop_called_without_recording() async {
        // given
        let (sut, engine) = makeSUT()
        
        // when
        let session = await sut.stopRecording()
        
        // then
        XCTAssertNil(session)
        XCTAssertEqual(engine.stopCaptureCallCount, 0)
    }
    
    // MARK: - pauseRecording
    
    func test_should_pause_recording_when_recording() async {
        // given
        let (sut, engine) = makeSUT()
        await sut.startRecording(config: makeConfig())
        
        // when
        await sut.pauseRecording()
        
        // then
        XCTAssertTrue(sut.isPaused)
        XCTAssertEqual(engine.pauseCaptureCallCount, 1)
    }
    
    func test_should_not_pause_when_not_recording() async {
        // given
        let (sut, engine) = makeSUT()
        
        // when
        await sut.pauseRecording()
        
        // then
        XCTAssertFalse(sut.isPaused)
        XCTAssertEqual(engine.pauseCaptureCallCount, 0)
    }
    
    // MARK: - resumeRecording
    
    func test_should_resume_recording_when_paused() async {
        // given
        let (sut, engine) = makeSUT()
        await sut.startRecording(config: makeConfig())
        await sut.pauseRecording()
        
        // when
        await sut.resumeRecording()
        
        // then
        XCTAssertFalse(sut.isPaused)
        XCTAssertEqual(engine.resumeCaptureCallCount, 1)
    }
    
    func test_should_not_resume_when_not_paused() async {
        // given
        let (sut, engine) = makeSUT()
        await sut.startRecording(config: makeConfig())
        
        // when
        await sut.resumeRecording()
        
        // then
        XCTAssertEqual(engine.resumeCaptureCallCount, 0)
    }
    
    // MARK: - clearError
    
    func test_should_clear_error() async {
        // given
        let (sut, engine) = makeSUT()
        engine.hasPermission = false
        await sut.startRecording(config: makeConfig())
        XCTAssertNotNil(sut.error)
        
        // when
        sut.clearError()
        
        // then
        XCTAssertNil(sut.error)
    }
}
