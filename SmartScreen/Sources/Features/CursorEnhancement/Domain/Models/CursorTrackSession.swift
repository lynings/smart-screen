import Foundation

/// Stores cursor tracking data for a recording session
struct CursorTrackSession: Codable {
    let events: [MouseEvent]
    let duration: TimeInterval
    
    // MARK: - Computed Properties
    
    var cursorPoints: [CursorPoint] {
        events
            .filter { $0.type == .move }
            .map { $0.toCursorPoint() }
    }
    
    var clickEvents: [ClickEvent] {
        events.compactMap { $0.toClickEvent() }
    }
    
    // MARK: - Trajectory Processing
    
    func smoothedTrajectory(level: SmoothingLevel) -> [CursorPoint] {
        let smoother = CursorSmoother(level: level)
        return smoother.smooth(cursorPoints)
    }
    
    /// Get interpolated position at a specific time
    func positionAt(time: TimeInterval) -> CGPoint? {
        let points = cursorPoints
        guard !points.isEmpty else { return nil }
        
        // Find surrounding points
        guard let afterIndex = points.firstIndex(where: { $0.timestamp >= time }) else {
            return points.last?.position
        }
        
        if afterIndex == 0 {
            return points.first?.position
        }
        
        let before = points[afterIndex - 1]
        let after = points[afterIndex]
        
        // Linear interpolation
        let timeDelta = after.timestamp - before.timestamp
        guard timeDelta > 0 else { return before.position }
        
        let t = (time - before.timestamp) / timeDelta
        let x = before.position.x + CGFloat(t) * (after.position.x - before.position.x)
        let y = before.position.y + CGFloat(t) * (after.position.y - before.position.y)
        
        return CGPoint(x: x, y: y)
    }
    
    /// Get smoothed position at a specific time
    func smoothedPositionAt(time: TimeInterval, level: SmoothingLevel) -> CGPoint? {
        let smoothed = smoothedTrajectory(level: level)
        guard !smoothed.isEmpty else { return nil }
        
        guard let afterIndex = smoothed.firstIndex(where: { $0.timestamp >= time }) else {
            return smoothed.last?.position
        }
        
        if afterIndex == 0 {
            return smoothed.first?.position
        }
        
        let before = smoothed[afterIndex - 1]
        let after = smoothed[afterIndex]
        
        let timeDelta = after.timestamp - before.timestamp
        guard timeDelta > 0 else { return before.position }
        
        let t = (time - before.timestamp) / timeDelta
        let x = before.position.x + CGFloat(t) * (after.position.x - before.position.x)
        let y = before.position.y + CGFloat(t) * (after.position.y - before.position.y)
        
        return CGPoint(x: x, y: y)
    }
    
    /// Get active click highlights at a specific time
    func activeHighlightsAt(time: TimeInterval) -> [ClickEvent] {
        clickEvents.filter { click in
            let highlightDuration = click.type.animationDuration
            return time >= click.timestamp && time <= click.timestamp + highlightDuration
        }
    }
    
    // MARK: - Persistence
    
    func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(self)
        try data.write(to: url)
    }
    
    static func load(from url: URL) throws -> CursorTrackSession {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(CursorTrackSession.self, from: data)
    }
}
