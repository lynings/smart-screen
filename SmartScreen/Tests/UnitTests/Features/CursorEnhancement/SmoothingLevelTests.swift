import XCTest
@testable import SmartScreen

final class SmoothingLevelTests: XCTestCase {
    
    // MARK: - Smoothing Factor
    
    func test_should_return_low_smoothing_factor_for_low_level() {
        // given
        let level = SmoothingLevel.low
        
        // when
        let factor = level.smoothingFactor
        
        // then
        XCTAssertEqual(factor, 0.3, accuracy: 0.001)
    }
    
    func test_should_return_medium_smoothing_factor_for_medium_level() {
        // given
        let level = SmoothingLevel.medium
        
        // when
        let factor = level.smoothingFactor
        
        // then
        XCTAssertEqual(factor, 0.5, accuracy: 0.001)
    }
    
    func test_should_return_high_smoothing_factor_for_high_level() {
        // given
        let level = SmoothingLevel.high
        
        // when
        let factor = level.smoothingFactor
        
        // then
        XCTAssertEqual(factor, 0.7, accuracy: 0.001)
    }
    
    // MARK: - Display Name
    
    func test_should_return_correct_display_names() {
        XCTAssertEqual(SmoothingLevel.low.displayName, "Low")
        XCTAssertEqual(SmoothingLevel.medium.displayName, "Medium")
        XCTAssertEqual(SmoothingLevel.high.displayName, "High")
    }
    
    // MARK: - All Cases
    
    func test_should_have_three_levels() {
        XCTAssertEqual(SmoothingLevel.allCases.count, 3)
    }
}
