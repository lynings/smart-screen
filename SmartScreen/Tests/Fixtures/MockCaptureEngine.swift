import Foundation
@testable import SmartScreen

final class MockCaptureEngine: CaptureEngineProtocol, @unchecked Sendable {
    
    // MARK: - Configurable Behavior
    
    var hasPermission = true
    var shouldFailOnStart = false
    var failureError: RecordingError = .permissionDenied
    var mockDuration: TimeInterval = 0
    var mockSession: RecordingSession?
    
    // MARK: - Call Tracking
    
    private(set) var requestPermissionCallCount = 0
    private(set) var startCaptureCallCount = 0
    private(set) var pauseCaptureCallCount = 0
    private(set) var resumeCaptureCallCount = 0
    private(set) var stopCaptureCallCount = 0
    private(set) var lastConfig: CaptureConfig?
    
    // MARK: - Protocol Conformance
    
    private var _isRecording = false
    
    var isRecording: Bool {
        get async { _isRecording }
    }
    
    var duration: TimeInterval {
        get async { mockDuration }
    }
    
    func requestPermission() async -> Bool {
        requestPermissionCallCount += 1
        return hasPermission
    }
    
    func startCapture(config: CaptureConfig) async throws {
        startCaptureCallCount += 1
        lastConfig = config
        
        guard hasPermission else {
            throw RecordingError.permissionDenied
        }
        
        if shouldFailOnStart {
            throw failureError
        }
        
        _isRecording = true
    }
    
    func pauseCapture() async {
        pauseCaptureCallCount += 1
    }
    
    func resumeCapture() async {
        resumeCaptureCallCount += 1
    }
    
    func stopCapture() async -> RecordingSession {
        stopCaptureCallCount += 1
        _isRecording = false
        
        return mockSession ?? RecordingSession(
            outputURL: URL(fileURLWithPath: "/tmp/mock-recording.mp4"),
            duration: mockDuration
        )
    }
}
