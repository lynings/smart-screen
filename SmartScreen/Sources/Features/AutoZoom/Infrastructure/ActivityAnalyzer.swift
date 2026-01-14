import Foundation

/// Analyzes cursor movement to identify activity patterns
final class ActivityAnalyzer {
    
    // MARK: - Configuration
    
    /// Window size for analysis (seconds)
    private let windowSize: TimeInterval = 1.0
    
    /// Step size between windows (seconds)
    private let windowStep: TimeInterval = 0.25
    
    /// Minimum events required for a valid window
    private let minEventsPerWindow: Int = 2
    
    // MARK: - Analysis
    
    /// Analyze a cursor track session and generate activity windows
    func analyze(session: CursorTrackSession) -> [ActivityWindow] {
        let events = session.events
        guard !events.isEmpty else { return [] }
        
        var windows: [ActivityWindow] = []
        var windowStart: TimeInterval = 0
        
        while windowStart < session.duration {
            let windowEnd = min(windowStart + windowSize, session.duration)
            let timeRange = windowStart...windowEnd
            
            // Get events in this window
            let windowEvents = events.filter { timeRange.contains($0.timestamp) }
            
            if windowEvents.count >= minEventsPerWindow {
                if let window = createWindow(from: windowEvents, timeRange: timeRange) {
                    windows.append(window)
                }
            }
            
            windowStart += windowStep
        }
        
        return windows
    }
    
    // MARK: - Window Creation
    
    private func createWindow(
        from events: [MouseEvent],
        timeRange: ClosedRange<TimeInterval>
    ) -> ActivityWindow? {
        guard !events.isEmpty else { return nil }
        
        let positions = events.map(\.position)
        
        // 1. Calculate bounding box
        let boundingBox = calculateBoundingBox(positions: positions)
        
        // 2. Calculate centroid
        let centroid = calculateCentroid(positions: positions)
        
        // 3. Calculate intensity
        let duration = timeRange.upperBound - timeRange.lowerBound
        let intensity = duration > 0 ? Double(events.count) / duration : 0
        
        // 4. Calculate average velocity
        let velocity = calculateAverageVelocity(events: events)
        
        // 5. Check for clicks
        let hasClick = events.contains { $0.type != .move }
        
        // 6. Detect dwell
        let dwellDuration = detectDwell(events: events, velocity: velocity)
        
        return ActivityWindow(
            timeRange: timeRange,
            boundingBox: boundingBox,
            centroid: centroid,
            intensity: intensity,
            averageVelocity: velocity,
            hasClick: hasClick,
            dwellDuration: dwellDuration
        )
    }
    
    // MARK: - Calculations
    
    private func calculateBoundingBox(positions: [CGPoint]) -> CGRect {
        guard !positions.isEmpty else { return .zero }
        
        var minX = positions[0].x
        var maxX = positions[0].x
        var minY = positions[0].y
        var maxY = positions[0].y
        
        for position in positions {
            minX = min(minX, position.x)
            maxX = max(maxX, position.x)
            minY = min(minY, position.y)
            maxY = max(maxY, position.y)
        }
        
        // Ensure minimum size
        let width = max(maxX - minX, 0.01)
        let height = max(maxY - minY, 0.01)
        
        return CGRect(x: minX, y: minY, width: width, height: height)
    }
    
    private func calculateCentroid(positions: [CGPoint]) -> CGPoint {
        guard !positions.isEmpty else { return .zero }
        
        let sumX = positions.reduce(0.0) { $0 + $1.x }
        let sumY = positions.reduce(0.0) { $0 + $1.y }
        
        return CGPoint(
            x: sumX / CGFloat(positions.count),
            y: sumY / CGFloat(positions.count)
        )
    }
    
    private func calculateAverageVelocity(events: [MouseEvent]) -> CGFloat {
        guard events.count >= 2 else { return 0 }
        
        var totalDistance: CGFloat = 0
        var totalTime: TimeInterval = 0
        
        for i in 1..<events.count {
            let prev = events[i - 1]
            let curr = events[i]
            
            let dx = curr.position.x - prev.position.x
            let dy = curr.position.y - prev.position.y
            let distance = hypot(dx, dy)
            let timeDelta = curr.timestamp - prev.timestamp
            
            totalDistance += distance
            totalTime += timeDelta
        }
        
        return totalTime > 0 ? totalDistance / CGFloat(totalTime) : 0
    }
    
    private func detectDwell(events: [MouseEvent], velocity: CGFloat) -> TimeInterval? {
        // Dwell is detected when velocity is very low
        guard velocity < ActivityWindow.dwellVelocityThreshold else { return nil }
        guard events.count >= 2 else { return nil }
        
        // Calculate time span of low-velocity movement
        let firstTime = events.first!.timestamp
        let lastTime = events.last!.timestamp
        let duration = lastTime - firstTime
        
        return duration >= ActivityWindow.minDwellDuration ? duration : nil
    }
}
