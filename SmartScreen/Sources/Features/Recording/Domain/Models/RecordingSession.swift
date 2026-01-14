import Foundation

/// Represents a completed recording session
struct RecordingSession: Equatable {
    let id: UUID
    let outputURL: URL
    let duration: TimeInterval
    let createdAt: Date
    let cursorTrackSession: CursorTrackSession?
    
    init(
        id: UUID = UUID(),
        outputURL: URL,
        duration: TimeInterval,
        createdAt: Date = Date(),
        cursorTrackSession: CursorTrackSession? = nil
    ) {
        self.id = id
        self.outputURL = outputURL
        self.duration = duration
        self.createdAt = createdAt
        self.cursorTrackSession = cursorTrackSession
    }
    
    static func == (lhs: RecordingSession, rhs: RecordingSession) -> Bool {
        lhs.id == rhs.id &&
        lhs.outputURL == rhs.outputURL &&
        lhs.duration == rhs.duration &&
        lhs.createdAt == rhs.createdAt
    }
}
