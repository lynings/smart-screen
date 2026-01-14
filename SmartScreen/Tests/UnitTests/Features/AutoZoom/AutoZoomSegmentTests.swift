import XCTest
@testable import SmartScreen

final class AutoZoomSegmentTests: XCTestCase {
    
    // MARK: - AC-TR-01: Click Trigger
    
    func test_should_create_segment_centered_on_click_time() {
        // given
        let click = ClickEvent(
            type: .leftClick,
            position: CGPoint(x: 0.5, y: 0.5),
            timestamp: 5.0
        )
        
        // when
        let segment = AutoZoomSegment.fromClick(click, duration: 1.2)
        
        // then - segment should be centered on click time [t - 0.6, t + 0.6]
        XCTAssertEqual(segment.startTime, 4.4, accuracy: 0.001)
        XCTAssertEqual(segment.endTime, 5.6, accuracy: 0.001)
        XCTAssertEqual(segment.duration, 1.2, accuracy: 0.001)
    }
    
    func test_should_create_segment_with_click_position_as_focus() {
        // given
        let click = ClickEvent(
            type: .leftClick,
            position: CGPoint(x: 0.3, y: 0.7),
            timestamp: 5.0
        )
        
        // when
        let segment = AutoZoomSegment.fromClick(click)
        
        // then - focus should be at click position
        XCTAssertEqual(segment.focusCenter.x, 0.3, accuracy: 0.001)
        XCTAssertEqual(segment.focusCenter.y, 0.7, accuracy: 0.001)
    }
    
    func test_should_clamp_start_time_to_zero_for_early_clicks() {
        // given
        let click = ClickEvent(
            type: .leftClick,
            position: CGPoint(x: 0.5, y: 0.5),
            timestamp: 0.3
        )
        
        // when
        let segment = AutoZoomSegment.fromClick(click, duration: 1.2)
        
        // then - start time should be clamped to 0
        XCTAssertEqual(segment.startTime, 0, accuracy: 0.001)
        XCTAssertEqual(segment.endTime, 0.9, accuracy: 0.001)
    }
    
    // MARK: - AC-TR-03: Click Merging
    
    func test_should_create_segment_from_multiple_clicks_with_centroid() {
        // given
        let clicks = [
            ClickEvent(type: .leftClick, position: CGPoint(x: 0.4, y: 0.4), timestamp: 5.0),
            ClickEvent(type: .leftClick, position: CGPoint(x: 0.6, y: 0.6), timestamp: 5.1)
        ]
        
        // when
        let segment = AutoZoomSegment.fromClicks(clicks, duration: 1.2)
        
        // then - focus should be centroid of click positions
        XCTAssertEqual(segment.focusCenter.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(segment.focusCenter.y, 0.5, accuracy: 0.001)
    }
    
    func test_should_extend_time_range_for_multiple_clicks() {
        // given
        let clicks = [
            ClickEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 5.0),
            ClickEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 5.2)
        ]
        
        // when
        let segment = AutoZoomSegment.fromClicks(clicks, duration: 1.2)
        
        // then - time range should cover all clicks
        XCTAssertEqual(segment.startTime, 4.4, accuracy: 0.001) // 5.0 - 0.6
        XCTAssertEqual(segment.endTime, 5.8, accuracy: 0.001) // 5.2 + 0.6
    }
    
    // MARK: - AC-AN-01: Three-Phase Animation
    
    func test_should_have_correct_phase_durations() {
        // given
        let segment = AutoZoomSegment(
            timeRange: 0...1.2,
            focusCenter: CGPoint(x: 0.5, y: 0.5),
            zoomScale: 2.0
        )
        
        // then - 25% zoom in, 50% hold, 25% zoom out
        XCTAssertEqual(segment.zoomInDuration, 0.3, accuracy: 0.001)
        XCTAssertEqual(segment.holdDuration, 0.6, accuracy: 0.001)
        XCTAssertEqual(segment.zoomOutDuration, 0.3, accuracy: 0.001)
    }
    
    func test_should_return_zoom_in_state_during_first_quarter() {
        // given
        let segment = AutoZoomSegment(
            timeRange: 0...1.2,
            focusCenter: CGPoint(x: 0.5, y: 0.5),
            zoomScale: 2.0,
            easing: .linear
        )
        
        // when - at 0.15s (middle of zoom in phase)
        let state = segment.state(at: 0.15)
        
        // then
        XCTAssertNotNil(state)
        XCTAssertEqual(state?.phase, .zoomIn)
        XCTAssertEqual(Double(state?.scale ?? 0), 1.5, accuracy: 0.01) // Halfway between 1.0 and 2.0
    }
    
    func test_should_return_hold_state_during_middle_half() {
        // given
        let segment = AutoZoomSegment(
            timeRange: 0...1.2,
            focusCenter: CGPoint(x: 0.5, y: 0.5),
            zoomScale: 2.0
        )
        
        // when - at 0.6s (middle of hold phase)
        let state = segment.state(at: 0.6)
        
        // then
        XCTAssertNotNil(state)
        XCTAssertEqual(state?.phase, .hold)
        XCTAssertEqual(Double(state?.scale ?? 0), 2.0, accuracy: 0.01)
    }
    
    func test_should_return_zoom_out_state_during_last_quarter() {
        // given
        let segment = AutoZoomSegment(
            timeRange: 0...1.2,
            focusCenter: CGPoint(x: 0.5, y: 0.5),
            zoomScale: 2.0,
            easing: .linear
        )
        
        // when - at 1.05s (middle of zoom out phase)
        let state = segment.state(at: 1.05)
        
        // then
        XCTAssertNotNil(state)
        XCTAssertEqual(state?.phase, .zoomOut)
        XCTAssertEqual(Double(state?.scale ?? 0), 1.5, accuracy: 0.01) // Halfway between 2.0 and 1.0
    }
    
    func test_should_return_nil_outside_time_range() {
        // given
        let segment = AutoZoomSegment(
            timeRange: 1.0...2.0,
            focusCenter: CGPoint(x: 0.5, y: 0.5),
            zoomScale: 2.0
        )
        
        // then
        XCTAssertNil(segment.state(at: 0.5))
        XCTAssertNil(segment.state(at: 2.5))
    }
    
    // MARK: - AC-AN-03: Segment Merging
    
    func test_should_allow_merge_when_close_in_time_and_space() {
        // given
        let segment1 = AutoZoomSegment(
            timeRange: 0...1.0,
            focusCenter: CGPoint(x: 0.5, y: 0.5),
            zoomScale: 2.0
        )
        let segment2 = AutoZoomSegment(
            timeRange: 1.2...2.2,
            focusCenter: CGPoint(x: 0.52, y: 0.52),
            zoomScale: 2.0
        )
        
        // then - gap is 0.2s < 0.3s, distance is ~0.028 < 0.05
        XCTAssertTrue(segment1.canMerge(with: segment2, maxGap: 0.3, maxDistance: 0.05))
    }
    
    func test_should_not_allow_merge_when_gap_too_large() {
        // given
        let segment1 = AutoZoomSegment(
            timeRange: 0...1.0,
            focusCenter: CGPoint(x: 0.5, y: 0.5),
            zoomScale: 2.0
        )
        let segment2 = AutoZoomSegment(
            timeRange: 1.5...2.5,
            focusCenter: CGPoint(x: 0.5, y: 0.5),
            zoomScale: 2.0
        )
        
        // then - gap is 0.5s > 0.3s
        XCTAssertFalse(segment1.canMerge(with: segment2, maxGap: 0.3, maxDistance: 0.05))
    }
    
    func test_should_not_allow_merge_when_distance_too_large() {
        // given
        let segment1 = AutoZoomSegment(
            timeRange: 0...1.0,
            focusCenter: CGPoint(x: 0.2, y: 0.2),
            zoomScale: 2.0
        )
        let segment2 = AutoZoomSegment(
            timeRange: 1.2...2.2,
            focusCenter: CGPoint(x: 0.8, y: 0.8),
            zoomScale: 2.0
        )
        
        // then - distance is ~0.85 > 0.05
        XCTAssertFalse(segment1.canMerge(with: segment2, maxGap: 0.3, maxDistance: 0.05))
    }
    
    func test_should_merge_segments_correctly() {
        // given
        let segment1 = AutoZoomSegment(
            timeRange: 0...1.0,
            focusCenter: CGPoint(x: 0.4, y: 0.4),
            zoomScale: 2.0
        )
        let segment2 = AutoZoomSegment(
            timeRange: 1.2...2.2,
            focusCenter: CGPoint(x: 0.6, y: 0.6),
            zoomScale: 2.5
        )
        
        // when
        let merged = segment1.merged(with: segment2)
        
        // then
        XCTAssertEqual(merged.startTime, 0, accuracy: 0.001)
        XCTAssertEqual(merged.endTime, 2.2, accuracy: 0.001)
        XCTAssertEqual(merged.focusCenter.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(merged.focusCenter.y, 0.5, accuracy: 0.001)
        XCTAssertEqual(merged.zoomScale, 2.5, accuracy: 0.001) // Max of both
    }
    
    // MARK: - AC-FU-01: Static Center Mode
    
    func test_should_use_focus_center_when_follow_disabled() {
        // given
        let segment = AutoZoomSegment(
            timeRange: 0...1.2,
            focusCenter: CGPoint(x: 0.3, y: 0.7),
            zoomScale: 2.0
        )
        let cursorPosition = CGPoint(x: 0.8, y: 0.2) // Different from focus center
        
        // when - follow cursor disabled
        let state = segment.state(
            at: 0.6,
            cursorPosition: cursorPosition,
            followCursor: false,
            smoothing: 0.2
        )
        
        // then - should use original focus center, not cursor position
        XCTAssertNotNil(state)
        XCTAssertEqual(Double(state?.center.x ?? 0), 0.3, accuracy: 0.001)
        XCTAssertEqual(Double(state?.center.y ?? 0), 0.7, accuracy: 0.001)
    }
    
    // MARK: - AC-FU-02: Follow Cursor Mode
    
    func test_should_follow_cursor_when_enabled() {
        // given
        let segment = AutoZoomSegment(
            timeRange: 0...1.2,
            focusCenter: CGPoint(x: 0.3, y: 0.7),
            zoomScale: 2.0
        )
        let cursorPosition = CGPoint(x: 0.5, y: 0.5) // Center of screen
        
        // when - follow cursor enabled
        let state = segment.state(
            at: 0.6,
            cursorPosition: cursorPosition,
            followCursor: true,
            smoothing: 0.2
        )
        
        // then - should use cursor position, not original focus center
        XCTAssertNotNil(state)
        XCTAssertEqual(Double(state?.center.x ?? 0), 0.5, accuracy: 0.001)
        XCTAssertEqual(Double(state?.center.y ?? 0), 0.5, accuracy: 0.001)
    }
    
    // MARK: - AC-FU-03: Boundary Constraints
    
    func test_should_constrain_center_when_following_at_corner() {
        // given
        let segment = AutoZoomSegment(
            timeRange: 0...1.2,
            focusCenter: CGPoint(x: 0.5, y: 0.5),
            zoomScale: 2.0  // At 2x zoom, visible area is 0.5x0.5
        )
        let cursorPosition = CGPoint(x: 0.1, y: 0.1) // Near top-left corner
        
        // when - follow cursor enabled
        let state = segment.state(
            at: 0.6,
            cursorPosition: cursorPosition,
            followCursor: true,
            smoothing: 0.2
        )
        
        // then - center should be constrained to keep visible area in bounds
        // At 2x zoom, center must be at least 0.25 from edge
        XCTAssertNotNil(state)
        XCTAssertGreaterThanOrEqual(state?.center.x ?? 0, 0.25)
        XCTAssertGreaterThanOrEqual(state?.center.y ?? 0, 0.25)
    }
    
    func test_should_constrain_center_when_following_at_bottom_right() {
        // given
        let segment = AutoZoomSegment(
            timeRange: 0...1.2,
            focusCenter: CGPoint(x: 0.5, y: 0.5),
            zoomScale: 2.0
        )
        let cursorPosition = CGPoint(x: 0.9, y: 0.9) // Near bottom-right corner
        
        // when - follow cursor enabled
        let state = segment.state(
            at: 0.6,
            cursorPosition: cursorPosition,
            followCursor: true,
            smoothing: 0.2
        )
        
        // then - center should be constrained to keep visible area in bounds
        XCTAssertNotNil(state)
        XCTAssertLessThanOrEqual(state?.center.x ?? 1, 0.75)
        XCTAssertLessThanOrEqual(state?.center.y ?? 1, 0.75)
    }
}
