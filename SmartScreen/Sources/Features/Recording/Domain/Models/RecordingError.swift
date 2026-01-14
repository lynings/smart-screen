import Foundation

enum RecordingError: LocalizedError, Equatable {
    case permissionDenied
    case deviceUnavailable(deviceType: String)
    case captureSessionFailed(underlying: Error)
    case diskFull
    case encodingFailed(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen recording permission is required"
        case .diskFull:
            return "Disk is full"
        case .deviceUnavailable(let deviceType):
            return "\(deviceType) device is unavailable"
        case .captureSessionFailed(let error):
            return "Capture failed: \(error.localizedDescription)"
        case .encodingFailed(let reason):
            return "Encoding failed: \(reason)"
        }
    }
    
    static func == (lhs: RecordingError, rhs: RecordingError) -> Bool {
        switch (lhs, rhs) {
        case (.permissionDenied, .permissionDenied),
             (.diskFull, .diskFull),
             (.captureSessionFailed, .captureSessionFailed):
            return true
        case (.deviceUnavailable(let lhs), .deviceUnavailable(let rhs)):
            return lhs == rhs
        case (.encodingFailed(let lhs), .encodingFailed(let rhs)):
            return lhs == rhs
        default:
            return false
        }
    }
}
