import Foundation

enum ExportError: LocalizedError, Equatable {
    case sessionNotFound
    case exportFailed(reason: String)
    case cancelled
    case invalidPreset
    case invalidSourceFile
    
    var errorDescription: String? {
        switch self {
        case .sessionNotFound:
            return "Recording session not found"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .cancelled:
            return "Export was cancelled"
        case .invalidPreset:
            return "Invalid export preset"
        case .invalidSourceFile:
            return "Invalid source video file"
        }
    }
}
