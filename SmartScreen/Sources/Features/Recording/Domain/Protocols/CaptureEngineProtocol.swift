import Foundation

/// Protocol defining the screen capture engine interface
protocol CaptureEngineProtocol: AnyObject, Sendable {
    /// Current recording state
    var isRecording: Bool { get async }
    
    /// Current recording duration in seconds
    var duration: TimeInterval { get async }
    
    /// Request screen recording permission
    /// - Returns: `true` if permission was granted
    func requestPermission() async -> Bool
    
    /// Start capturing with the given configuration
    /// - Parameter config: Capture configuration
    /// - Throws: `RecordingError` if capture fails
    func startCapture(config: CaptureConfig) async throws
    
    /// Pause the current capture session
    func pauseCapture() async
    
    /// Resume a paused capture session
    func resumeCapture() async
    
    /// Stop capturing and finalize the recording
    /// - Returns: The completed recording session
    func stopCapture() async -> RecordingSession
}
