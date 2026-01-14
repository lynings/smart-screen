import XCTest
@testable import SmartScreen

final class DynamicZoomCalculatorTests: XCTestCase {
    
    // MARK: - Center Position Tests
    
    func test_should_return_smaller_scale_at_center() {
        // given
        let calculator = DynamicZoomCalculator(baseScale: 2.0)
        let centerPosition = CGPoint(x: 0.5, y: 0.5)
        
        // when
        let scale = calculator.zoomScale(at: centerPosition)
        
        // then - center should have minimum scale factor
        XCTAssertEqual(scale, 2.0 * 0.85, accuracy: 0.01)
    }
    
    // MARK: - Edge Position Tests
    
    func test_should_return_larger_scale_at_left_edge() {
        // given
        let calculator = DynamicZoomCalculator(baseScale: 2.0)
        let edgePosition = CGPoint(x: 0.0, y: 0.5)
        
        // when
        let scale = calculator.zoomScale(at: edgePosition)
        
        // then - edge should have maximum scale factor
        XCTAssertEqual(scale, 2.0 * 1.25, accuracy: 0.01)
    }
    
    func test_should_return_larger_scale_at_right_edge() {
        // given
        let calculator = DynamicZoomCalculator(baseScale: 2.0)
        let edgePosition = CGPoint(x: 1.0, y: 0.5)
        
        // when
        let scale = calculator.zoomScale(at: edgePosition)
        
        // then
        XCTAssertEqual(scale, 2.0 * 1.25, accuracy: 0.01)
    }
    
    func test_should_return_larger_scale_at_top_edge() {
        // given
        let calculator = DynamicZoomCalculator(baseScale: 2.0)
        let edgePosition = CGPoint(x: 0.5, y: 0.0)
        
        // when
        let scale = calculator.zoomScale(at: edgePosition)
        
        // then
        XCTAssertEqual(scale, 2.0 * 1.25, accuracy: 0.01)
    }
    
    func test_should_return_larger_scale_at_bottom_edge() {
        // given
        let calculator = DynamicZoomCalculator(baseScale: 2.0)
        let edgePosition = CGPoint(x: 0.5, y: 1.0)
        
        // when
        let scale = calculator.zoomScale(at: edgePosition)
        
        // then
        XCTAssertEqual(scale, 2.0 * 1.25, accuracy: 0.01)
    }
    
    // MARK: - Corner Position Tests
    
    func test_should_return_boosted_scale_at_corner() {
        // given
        let calculator = DynamicZoomCalculator(baseScale: 2.0)
        let cornerPosition = CGPoint(x: 0.0, y: 0.0)
        
        // when
        let scale = calculator.zoomScaleWithCornerBoost(at: cornerPosition)
        
        // then - corner gets base edge scale + 10% boost
        let expectedBaseScale = 2.0 * 1.25
        let expectedWithBoost = expectedBaseScale * 1.1
        XCTAssertEqual(scale, expectedWithBoost, accuracy: 0.01)
    }
    
    func test_should_not_boost_non_corner_edge() {
        // given
        let calculator = DynamicZoomCalculator(baseScale: 2.0)
        let edgePosition = CGPoint(x: 0.0, y: 0.5) // left edge, not corner
        
        // when
        let scale = calculator.zoomScaleWithCornerBoost(at: edgePosition)
        
        // then - should be same as zoomScale (no boost)
        XCTAssertEqual(scale, calculator.zoomScale(at: edgePosition), accuracy: 0.001)
    }
    
    // MARK: - Position Detection Tests
    
    func test_should_detect_corner_position() {
        // given
        let calculator = DynamicZoomCalculator()
        
        // when/then - all corners should be detected
        XCTAssertTrue(calculator.isCornerPosition(CGPoint(x: 0.1, y: 0.1)))
        XCTAssertTrue(calculator.isCornerPosition(CGPoint(x: 0.9, y: 0.1)))
        XCTAssertTrue(calculator.isCornerPosition(CGPoint(x: 0.1, y: 0.9)))
        XCTAssertTrue(calculator.isCornerPosition(CGPoint(x: 0.9, y: 0.9)))
    }
    
    func test_should_not_detect_center_as_corner() {
        // given
        let calculator = DynamicZoomCalculator()
        let centerPosition = CGPoint(x: 0.5, y: 0.5)
        
        // when
        let isCorner = calculator.isCornerPosition(centerPosition)
        
        // then
        XCTAssertFalse(isCorner)
    }
    
    func test_should_detect_edge_position() {
        // given
        let calculator = DynamicZoomCalculator()
        
        // when/then
        XCTAssertTrue(calculator.isEdgePosition(CGPoint(x: 0.05, y: 0.5)))  // left edge
        XCTAssertTrue(calculator.isEdgePosition(CGPoint(x: 0.95, y: 0.5))) // right edge
        XCTAssertTrue(calculator.isEdgePosition(CGPoint(x: 0.5, y: 0.05)))  // top edge
        XCTAssertTrue(calculator.isEdgePosition(CGPoint(x: 0.5, y: 0.95))) // bottom edge
        XCTAssertFalse(calculator.isEdgePosition(CGPoint(x: 0.5, y: 0.5)))  // center
    }
    
    // MARK: - Intermediate Position Tests
    
    func test_should_return_intermediate_scale_between_edge_and_center() {
        // given
        let calculator = DynamicZoomCalculator(baseScale: 2.0)
        let intermediatePosition = CGPoint(x: 0.25, y: 0.5) // halfway between left edge and center
        
        // when
        let scale = calculator.zoomScale(at: intermediatePosition)
        
        // then - should be between edge (2.5) and center (1.7)
        XCTAssertGreaterThan(scale, 2.0 * 0.85) // greater than center
        XCTAssertLessThan(scale, 2.0 * 1.25)    // less than edge
    }
}
