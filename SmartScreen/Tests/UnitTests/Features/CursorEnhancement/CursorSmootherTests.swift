import XCTest
@testable import SmartScreen

final class CursorSmootherTests: XCTestCase {
    
    // MARK: - Initialization
    
    func test_should_create_smoother_with_default_level() {
        // given/when
        let smoother = CursorSmoother()
        
        // then
        XCTAssertEqual(smoother.level, .medium)
    }
    
    func test_should_create_smoother_with_custom_level() {
        // given/when
        let smoother = CursorSmoother(level: .high)
        
        // then
        XCTAssertEqual(smoother.level, .high)
    }
    
    // MARK: - Single Point
    
    func test_should_return_same_point_for_single_input() {
        // given
        let smoother = CursorSmoother()
        let point = CursorPoint(position: CGPoint(x: 100, y: 200), timestamp: 0)
        
        // when
        let result = smoother.smooth([point])
        
        // then
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].position, point.position)
    }
    
    // MARK: - Empty Input
    
    func test_should_return_empty_for_empty_input() {
        // given
        let smoother = CursorSmoother()
        
        // when
        let result = smoother.smooth([])
        
        // then
        XCTAssertTrue(result.isEmpty)
    }
    
    // MARK: - Smoothing Effect
    
    func test_should_smooth_jittery_trajectory() {
        // given
        let smoother = CursorSmoother(level: .medium)
        let points = [
            CursorPoint(position: CGPoint(x: 0, y: 0), timestamp: 0),
            CursorPoint(position: CGPoint(x: 10, y: 5), timestamp: 0.016),
            CursorPoint(position: CGPoint(x: 8, y: 3), timestamp: 0.032),  // jitter back
            CursorPoint(position: CGPoint(x: 20, y: 10), timestamp: 0.048),
            CursorPoint(position: CGPoint(x: 18, y: 8), timestamp: 0.064), // jitter back
            CursorPoint(position: CGPoint(x: 30, y: 15), timestamp: 0.080)
        ]
        
        // when
        let smoothed = smoother.smooth(points)
        
        // then
        XCTAssertEqual(smoothed.count, points.count)
        
        // Verify smoothed trajectory has less variance
        // The smoothed points should be closer to a straight line
        let originalVariance = calculateVariance(points)
        let smoothedVariance = calculateVariance(smoothed)
        XCTAssertLessThan(smoothedVariance, originalVariance)
    }
    
    func test_should_preserve_timestamps_after_smoothing() {
        // given
        let smoother = CursorSmoother()
        let points = [
            CursorPoint(position: CGPoint(x: 0, y: 0), timestamp: 1.0),
            CursorPoint(position: CGPoint(x: 10, y: 10), timestamp: 2.0),
            CursorPoint(position: CGPoint(x: 20, y: 20), timestamp: 3.0)
        ]
        
        // when
        let smoothed = smoother.smooth(points)
        
        // then
        for (original, result) in zip(points, smoothed) {
            XCTAssertEqual(original.timestamp, result.timestamp)
        }
    }
    
    // MARK: - Level Effect
    
    func test_should_apply_more_smoothing_with_higher_level() {
        // given
        let lowSmoother = CursorSmoother(level: .low)
        let highSmoother = CursorSmoother(level: .high)
        let jitteryPoints = [
            CursorPoint(position: CGPoint(x: 0, y: 0), timestamp: 0),
            CursorPoint(position: CGPoint(x: 10, y: 10), timestamp: 0.016),
            CursorPoint(position: CGPoint(x: 5, y: 5), timestamp: 0.032),   // big jitter
            CursorPoint(position: CGPoint(x: 20, y: 20), timestamp: 0.048),
            CursorPoint(position: CGPoint(x: 15, y: 15), timestamp: 0.064)  // big jitter
        ]
        
        // when
        let lowSmoothed = lowSmoother.smooth(jitteryPoints)
        let highSmoothed = highSmoother.smooth(jitteryPoints)
        
        // then
        let lowVariance = calculateVariance(lowSmoothed)
        let highVariance = calculateVariance(highSmoothed)
        
        // Higher smoothing level should result in lower variance (smoother trajectory)
        XCTAssertLessThan(highVariance, lowVariance)
    }
    
    // MARK: - Helpers
    
    private func calculateVariance(_ points: [CursorPoint]) -> Double {
        guard points.count > 1 else { return 0 }
        
        // Calculate variance from the ideal straight line between first and last point
        let first = points.first!
        let last = points.last!
        
        var totalDeviation: Double = 0
        for i in 1..<(points.count - 1) {
            let point = points[i]
            let t = Double(i) / Double(points.count - 1)
            let idealX = first.position.x + t * (last.position.x - first.position.x)
            let idealY = first.position.y + t * (last.position.y - first.position.y)
            
            let dx = point.position.x - idealX
            let dy = point.position.y - idealY
            totalDeviation += sqrt(dx * dx + dy * dy)
        }
        
        return totalDeviation / Double(points.count - 2)
    }
}
