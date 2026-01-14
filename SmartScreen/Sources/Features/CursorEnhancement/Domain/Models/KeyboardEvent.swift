import Foundation

/// Represents a keyboard event during recording
struct KeyboardEvent: Codable, Equatable {
    let timestamp: TimeInterval
    let type: KeyboardEventType
    
    /// Duration of keyboard activity window (for debouncing)
    static let activityWindowDuration: TimeInterval = 0.5
}

/// Types of keyboard events
enum KeyboardEventType: String, Codable {
    case keyDown
    case keyUp
}
