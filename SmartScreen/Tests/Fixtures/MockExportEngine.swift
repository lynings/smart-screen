import Foundation
@testable import SmartScreen

final class MockExportEngine: ExportEngineProtocol, @unchecked Sendable {
    
    // MARK: - Configurable Behavior
    
    var shouldFail = false
    var failureError: ExportError = .exportFailed(reason: "Mock error")
    var mockProgress: Double = 0
    
    // MARK: - Call Tracking
    
    private(set) var exportCallCount = 0
    private(set) var cancelCallCount = 0
    private(set) var lastSession: RecordingSession?
    private(set) var lastPreset: ExportPreset?
    private(set) var lastOutputURL: URL?
    
    // MARK: - Protocol Conformance
    
    private var _isExporting = false
    
    var progress: Double {
        get async { mockProgress }
    }
    
    var isExporting: Bool {
        get async { _isExporting }
    }
    
    func export(session: RecordingSession, preset: ExportPreset, to url: URL) async throws {
        exportCallCount += 1
        lastSession = session
        lastPreset = preset
        lastOutputURL = url
        
        _isExporting = true
        
        if shouldFail {
            _isExporting = false
            throw failureError
        }
        
        _isExporting = false
    }
    
    func cancel() async {
        cancelCallCount += 1
        _isExporting = false
    }
}
