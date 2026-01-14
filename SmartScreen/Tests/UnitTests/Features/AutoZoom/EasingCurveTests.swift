import XCTest
@testable import SmartScreen

final class EasingCurveTests: XCTestCase {
    
    // MARK: - Linear
    
    func test_should_return_linear_value_at_start() {
        // given
        let curve = EasingCurve.linear
        
        // when
        let value = curve.value(at: 0.0)
        
        // then
        XCTAssertEqual(value, 0.0, accuracy: 0.001)
    }
    
    func test_should_return_linear_value_at_middle() {
        // given
        let curve = EasingCurve.linear
        
        // when
        let value = curve.value(at: 0.5)
        
        // then
        XCTAssertEqual(value, 0.5, accuracy: 0.001)
    }
    
    func test_should_return_linear_value_at_end() {
        // given
        let curve = EasingCurve.linear
        
        // when
        let value = curve.value(at: 1.0)
        
        // then
        XCTAssertEqual(value, 1.0, accuracy: 0.001)
    }
    
    // MARK: - EaseIn
    
    func test_should_return_easeIn_value_slower_at_start() {
        // given
        let curve = EasingCurve.easeIn
        
        // when
        let value = curve.value(at: 0.5)
        
        // then
        // EaseIn starts slow, so at t=0.5, value should be < 0.5
        XCTAssertLessThan(value, 0.5)
    }
    
    // MARK: - EaseOut
    
    func test_should_return_easeOut_value_faster_at_start() {
        // given
        let curve = EasingCurve.easeOut
        
        // when
        let value = curve.value(at: 0.5)
        
        // then
        // EaseOut starts fast, so at t=0.5, value should be > 0.5
        XCTAssertGreaterThan(value, 0.5)
    }
    
    // MARK: - EaseInOut
    
    func test_should_return_easeInOut_value_at_middle() {
        // given
        let curve = EasingCurve.easeInOut
        
        // when
        let value = curve.value(at: 0.5)
        
        // then
        // EaseInOut should be exactly 0.5 at the middle
        XCTAssertEqual(value, 0.5, accuracy: 0.001)
    }
    
    func test_should_return_easeInOut_slower_at_start() {
        // given
        let curve = EasingCurve.easeInOut
        
        // when
        let value = curve.value(at: 0.25)
        
        // then
        // At t=0.25, value should be < 0.25 (slow start)
        XCTAssertLessThan(value, 0.25)
    }
    
    // MARK: - Clamping
    
    func test_should_clamp_negative_progress() {
        // given
        let curve = EasingCurve.linear
        
        // when
        let value = curve.value(at: -0.5)
        
        // then
        XCTAssertEqual(value, 0.0, accuracy: 0.001)
    }
    
    func test_should_clamp_progress_over_one() {
        // given
        let curve = EasingCurve.linear
        
        // when
        let value = curve.value(at: 1.5)
        
        // then
        XCTAssertEqual(value, 1.0, accuracy: 0.001)
    }
}
