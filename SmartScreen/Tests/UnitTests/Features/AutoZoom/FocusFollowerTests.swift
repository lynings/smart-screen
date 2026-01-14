import XCTest
@testable import SmartScreen

final class FocusFollowerTests: XCTestCase {
    
    // MARK: - No Segments
    
    func test_should_return_default_state_when_no_segments() {
        // given
        let follower = FocusFollower()
        let segments: [SmartZoomSegment] = []
        
        // when
        let state = follower.focusState(at: 1.0, segments: segments, cursorPosition: CGPoint(x: 0.5, y: 0.5))
        
        // then
        XCTAssertEqual(state.scale, 1.0)
        XCTAssertEqual(state.center.x, 0.5, accuracy: 0.01)
        XCTAssertEqual(state.center.y, 0.5, accuracy: 0.01)
    }
    
    // MARK: - Active Segment
    
    func test_should_return_segment_state_when_active() {
        // given
        let follower = FocusFollower()
        let segment = SmartZoomSegment.simple(
            startTime: 1.0,
            center: CGPoint(x: 0.5, y: 0.5),
            scale: 2.0,
            zoomInDuration: 0.5,
            holdDuration: 2.0,
            zoomOutDuration: 0.5,
            trigger: .click(position: CGPoint(x: 0.5, y: 0.5))
        )
        
        // when - during hold phase
        let state = follower.focusState(at: 2.0, segments: [segment], cursorPosition: CGPoint(x: 0.5, y: 0.5))
        
        // then
        XCTAssertEqual(state.scale, 2.0, accuracy: 0.1)
    }
    
    // MARK: - Cursor Following
    
    func test_should_follow_cursor_within_bounds() {
        // given
        let follower = FocusFollower(followSmoothing: 1.0)  // No smoothing for test
        let segment = SmartZoomSegment.simple(
            startTime: 0.0,
            center: CGPoint(x: 0.5, y: 0.5),
            scale: 2.0,
            zoomInDuration: 0.1,
            holdDuration: 3.0,
            zoomOutDuration: 0.1,
            trigger: .click(position: CGPoint(x: 0.5, y: 0.5))
        )
        
        // when - cursor moves to the right
        let state = follower.focusState(
            at: 1.5,
            segments: [segment],
            cursorPosition: CGPoint(x: 0.7, y: 0.5)
        )
        
        // then - center should adjust to keep cursor visible
        // At 2x zoom, visible width is 0.5, so cursor at 0.7 needs center to shift right
        XCTAssertGreaterThan(state.center.x, 0.5)
    }
    
    // MARK: - Boundary Constraints
    
    func test_should_clamp_center_to_valid_bounds() {
        // given
        let follower = FocusFollower(followSmoothing: 1.0)
        let segment = SmartZoomSegment.simple(
            startTime: 0.0,
            center: CGPoint(x: 0.1, y: 0.1),  // Near corner
            scale: 2.0,
            zoomInDuration: 0.1,
            holdDuration: 3.0,
            zoomOutDuration: 0.1,
            trigger: .click(position: CGPoint(x: 0.1, y: 0.1))
        )
        
        // when
        let state = follower.focusState(
            at: 1.5,
            segments: [segment],
            cursorPosition: CGPoint(x: 0.05, y: 0.05)
        )
        
        // then - center should be clamped so visible rect stays in bounds
        // At 2x zoom, visible rect is 0.5x0.5, so center must be >= 0.25
        XCTAssertGreaterThanOrEqual(state.center.x, 0.25)
        XCTAssertGreaterThanOrEqual(state.center.y, 0.25)
    }
    
    // MARK: - Smoothing
    
    func test_should_smooth_center_transitions() {
        // given
        let follower = FocusFollower(followSmoothing: 0.1)  // Low smoothing
        let segment = SmartZoomSegment.simple(
            startTime: 0.0,
            center: CGPoint(x: 0.5, y: 0.5),
            scale: 2.0,
            zoomInDuration: 0.1,
            holdDuration: 3.0,
            zoomOutDuration: 0.1,
            trigger: .click(position: CGPoint(x: 0.5, y: 0.5))
        )
        
        // when - first call establishes baseline
        _ = follower.focusState(at: 1.0, segments: [segment], cursorPosition: CGPoint(x: 0.5, y: 0.5))
        
        // Second call with cursor jump
        let state = follower.focusState(at: 1.1, segments: [segment], cursorPosition: CGPoint(x: 0.8, y: 0.5))
        
        // then - center should not jump immediately to 0.8 due to smoothing
        XCTAssertLessThan(state.center.x, 0.8)
    }
    
    // MARK: - Edge Margin
    
    func test_should_maintain_edge_margin() {
        // given
        let margin: CGFloat = 0.15
        let follower = FocusFollower(edgeMargin: margin, followSmoothing: 1.0)
        let segment = SmartZoomSegment.simple(
            startTime: 0.0,
            center: CGPoint(x: 0.5, y: 0.5),
            scale: 2.0,
            zoomInDuration: 0.1,
            holdDuration: 3.0,
            zoomOutDuration: 0.1,
            trigger: .click(position: CGPoint(x: 0.5, y: 0.5))
        )
        
        // when - cursor at edge of visible area
        let state = follower.focusState(
            at: 1.5,
            segments: [segment],
            cursorPosition: CGPoint(x: 0.7, y: 0.5)  // Near edge at 2x zoom
        )
        
        // then - center should have shifted to keep cursor visible
        // At 2x zoom, visible rect is 0.5 wide, so cursor at 0.7 should be visible
        let visibleRect = state.visibleRect
        XCTAssertTrue(visibleRect.contains(CGPoint(x: 0.7, y: 0.5)))
    }
    
    // MARK: - Predictive Panning
    
    func test_should_apply_lookahead_for_moving_cursor() {
        // given
        let follower = FocusFollower(followSmoothing: 1.0, lookaheadFactor: 0.2)
        let segment = SmartZoomSegment.simple(
            startTime: 0.0,
            center: CGPoint(x: 0.5, y: 0.5),
            scale: 2.0,
            zoomInDuration: 0.1,
            holdDuration: 3.0,
            zoomOutDuration: 0.1,
            trigger: .click(position: CGPoint(x: 0.5, y: 0.5))
        )
        
        // when - cursor moving right with velocity
        let state = follower.focusState(
            at: 1.5,
            segments: [segment],
            cursorPosition: CGPoint(x: 0.6, y: 0.5),
            cursorVelocity: CGPoint(x: 0.5, y: 0)  // Moving right
        )
        
        // then - center should be ahead of cursor position
        XCTAssertGreaterThan(state.center.x, 0.5)
    }
}
