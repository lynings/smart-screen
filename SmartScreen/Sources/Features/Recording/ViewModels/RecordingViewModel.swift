import Foundation
import Observation

@Observable
@MainActor
final class RecordingViewModel {
    
    // MARK: - Dependencies
    
    private let captureEngine: CaptureEngineProtocol
    
    // MARK: - State
    
    private(set) var isRecording = false
    private(set) var isPaused = false
    private(set) var isStarting = false
    private(set) var error: RecordingError?
    
    var duration: TimeInterval {
        get async { await captureEngine.duration }
    }
    
    // MARK: - Initialization
    
    init(captureEngine: CaptureEngineProtocol) {
        self.captureEngine = captureEngine
    }
    
    // MARK: - Actions
    
    func startRecording(config: CaptureConfig) async {
        error = nil
        isStarting = true
        
        do {
            try await captureEngine.startCapture(config: config)
            isRecording = true
        } catch let recordingError as RecordingError {
            error = recordingError
        } catch {
            self.error = .captureSessionFailed(underlying: error)
        }
        
        isStarting = false
    }
    
    func stopRecording() async -> RecordingSession? {
        guard isRecording else { return nil }
        
        let session = await captureEngine.stopCapture()
        isRecording = false
        isPaused = false
        
        return session
    }
    
    func pauseRecording() async {
        guard isRecording, !isPaused else { return }
        await captureEngine.pauseCapture()
        isPaused = true
    }
    
    func resumeRecording() async {
        guard isRecording, isPaused else { return }
        await captureEngine.resumeCapture()
        isPaused = false
    }
    
    func clearError() {
        error = nil
    }
}
