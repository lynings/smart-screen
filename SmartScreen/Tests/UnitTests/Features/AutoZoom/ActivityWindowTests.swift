import XCTest
@testable import SmartScreen

final class ActivityWindowTests: XCTestCase {
    
    // MARK: - Initialization
    
    func test_should_create_window_with_values() {
        // given/when
        let window = ActivityWindow(
            timeRange: 0.0...1.0,
            boundingBox: CGRect(x: 0.2, y: 0.3, width: 0.3, height: 0.2),
            centroid: CGPoint(x: 0.35, y: 0.4),
            intensity: 10.0,
            averageVelocity: 0.1,
            hasClick: true,
            dwellDuration: nil
        )
        
        // then
        XCTAssertEqual(window.timeRange, 0.0...1.0)
        XCTAssertEqual(window.centroid.x, 0.35, accuracy: 0.001)
        XCTAssertEqual(window.intensity, 10.0)
        XCTAssertTrue(window.hasClick)
    }
    
    // MARK: - Area Ratio
    
    func test_should_calculate_area_ratio() {
        // given
        let window = ActivityWindow(
            timeRange: 0.0...1.0,
            boundingBox: CGRect(x: 0.0, y: 0.0, width: 0.5, height: 0.4),
            centroid: CGPoint(x: 0.25, y: 0.2),
            intensity: 5.0,
            averageVelocity: 0.05,
            hasClick: false,
            dwellDuration: nil
        )
        
        // when
        let ratio = window.areaRatio
        
        // then - 0.5 * 0.4 = 0.2 = 20%
        XCTAssertEqual(ratio, 0.2, accuracy: 0.001)
    }
    
    // MARK: - Activity Classification
    
    func test_should_identify_high_activity() {
        // given
        let highActivity = ActivityWindow(
            timeRange: 0.0...1.0,
            boundingBox: CGRect(x: 0.0, y: 0.0, width: 0.1, height: 0.1),
            centroid: .zero,
            intensity: 15.0,  // High intensity
            averageVelocity: 0.2,
            hasClick: true,
            dwellDuration: nil
        )
        
        // when/then
        XCTAssertTrue(highActivity.isHighActivity)
    }
    
    func test_should_identify_low_activity() {
        // given
        let lowActivity = ActivityWindow(
            timeRange: 0.0...1.0,
            boundingBox: CGRect(x: 0.0, y: 0.0, width: 0.5, height: 0.5),
            centroid: .zero,
            intensity: 2.0,  // Low intensity
            averageVelocity: 0.01,
            hasClick: false,
            dwellDuration: nil
        )
        
        // when/then
        XCTAssertFalse(lowActivity.isHighActivity)
    }
    
    // MARK: - Dwell Detection
    
    func test_should_identify_dwell() {
        // given
        let dwellWindow = ActivityWindow(
            timeRange: 0.0...1.0,
            boundingBox: CGRect(x: 0.4, y: 0.4, width: 0.02, height: 0.02),
            centroid: CGPoint(x: 0.41, y: 0.41),
            intensity: 3.0,
            averageVelocity: 0.005,  // Very low velocity
            hasClick: false,
            dwellDuration: 0.8  // Significant dwell
        )
        
        // when/then
        XCTAssertTrue(dwellWindow.isDwell)
    }
    
    func test_should_not_identify_dwell_when_moving() {
        // given
        let movingWindow = ActivityWindow(
            timeRange: 0.0...1.0,
            boundingBox: CGRect(x: 0.0, y: 0.0, width: 0.3, height: 0.3),
            centroid: CGPoint(x: 0.15, y: 0.15),
            intensity: 10.0,
            averageVelocity: 0.2,  // Moving
            hasClick: false,
            dwellDuration: nil
        )
        
        // when/then
        XCTAssertFalse(movingWindow.isDwell)
    }
    
    // MARK: - Suggested Zoom Level
    
    func test_should_suggest_high_zoom_for_small_area() {
        // given - small activity area (< 5%)
        let window = ActivityWindow(
            timeRange: 0.0...1.0,
            boundingBox: CGRect(x: 0.4, y: 0.4, width: 0.1, height: 0.04),  // 0.4%
            centroid: CGPoint(x: 0.45, y: 0.42),
            intensity: 5.0,
            averageVelocity: 0.05,
            hasClick: true,
            dwellDuration: nil
        )
        
        // when
        let zoom = window.suggestedZoomLevel
        
        // then - should suggest high zoom (>= 2.5x with click boost)
        XCTAssertGreaterThanOrEqual(zoom, 2.5)
    }
    
    func test_should_suggest_medium_zoom_for_medium_area() {
        // given - medium activity area (5-15%)
        let window = ActivityWindow(
            timeRange: 0.0...1.0,
            boundingBox: CGRect(x: 0.3, y: 0.3, width: 0.3, height: 0.3),  // 9%
            centroid: CGPoint(x: 0.45, y: 0.45),
            intensity: 5.0,
            averageVelocity: 0.1,
            hasClick: false,
            dwellDuration: nil
        )
        
        // when
        let zoom = window.suggestedZoomLevel
        
        // then - should suggest medium zoom (around 2.0x, with velocity factor)
        XCTAssertGreaterThanOrEqual(zoom, 1.5)
        XCTAssertLessThanOrEqual(zoom, 2.2)
    }
    
    func test_should_suggest_low_zoom_for_large_area() {
        // given - large activity area (> 30%)
        let window = ActivityWindow(
            timeRange: 0.0...1.0,
            boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.6, height: 0.6),  // 36%
            centroid: CGPoint(x: 0.4, y: 0.4),
            intensity: 5.0,
            averageVelocity: 0.3,
            hasClick: false,
            dwellDuration: nil
        )
        
        // when
        let zoom = window.suggestedZoomLevel
        
        // then - should suggest no zoom (1.0x)
        XCTAssertEqual(zoom, 1.0, accuracy: 0.1)
    }
    
    func test_should_reduce_zoom_for_high_velocity() {
        // given - small area but high velocity
        let window = ActivityWindow(
            timeRange: 0.0...1.0,
            boundingBox: CGRect(x: 0.4, y: 0.4, width: 0.1, height: 0.1),  // 1%
            centroid: CGPoint(x: 0.45, y: 0.45),
            intensity: 5.0,
            averageVelocity: 0.8,  // Very high velocity
            hasClick: false,
            dwellDuration: nil
        )
        
        // when
        let zoom = window.suggestedZoomLevel
        
        // then - should reduce zoom due to high velocity
        XCTAssertLessThan(zoom, 2.5)
    }
}
