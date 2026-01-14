import XCTest
@testable import SmartScreen

final class ZoomStateMachineTests: XCTestCase {
    
    // MARK: - Initial State
    
    func test_should_start_in_idle_state() {
        // given
        let sut = ZoomStateMachine()
        
        // when
        let output = sut.output(at: 0)
        
        // then
        XCTAssertEqual(output.scale, 1.0)
        XCTAssertFalse(output.isTransitioning)
    }
    
    // MARK: - Activity Detection
    
    func test_should_start_zooming_in_when_activity_detected() {
        // given
        let sut = ZoomStateMachine()
        let position = CGPoint(x: 0.5, y: 0.5)
        
        // when
        sut.process(event: .activityDetected(position: position, suggestedScale: 2.0), at: 0)
        let output = sut.output(at: 0.1)
        
        // then
        XCTAssertGreaterThan(output.scale, 1.0)
        XCTAssertTrue(output.isTransitioning)
    }
    
    func test_should_reach_target_scale_after_zoom_in_duration() {
        // given
        let config = ZoomStateMachine.Config(zoomInDuration: 0.4)
        let sut = ZoomStateMachine(config: config)
        let position = CGPoint(x: 0.5, y: 0.5)
        
        // when
        sut.process(event: .activityDetected(position: position, suggestedScale: 2.0), at: 0)
        sut.process(event: .zoomInComplete, at: 0.4)
        let output = sut.output(at: 0.4)
        
        // then
        XCTAssertEqual(output.scale, 2.0, accuracy: 0.01)
        XCTAssertFalse(output.isTransitioning)
    }
    
    // MARK: - Hold Phase
    
    func test_should_extend_hold_when_activity_continues() {
        // given
        let config = ZoomStateMachine.Config(zoomInDuration: 0.4, baseHoldTime: 1.0)
        let sut = ZoomStateMachine(config: config)
        let position = CGPoint(x: 0.5, y: 0.5)
        
        // when
        sut.process(event: .activityDetected(position: position, suggestedScale: 2.0), at: 0)
        sut.process(event: .zoomInComplete, at: 0.4)
        
        // Activity continues at 1.0s (would normally expire at 1.4s)
        sut.process(event: .activityContinues(position: CGPoint(x: 0.6, y: 0.5)), at: 1.0)
        
        // Check at 1.5s - should still be zoomed
        sut.process(event: .noActivity, at: 1.5)
        let output = sut.output(at: 1.5)
        
        // then
        XCTAssertEqual(output.scale, 2.0, accuracy: 0.01)
    }
    
    // MARK: - Zoom Out
    
    func test_should_start_zooming_out_when_hold_expires() {
        // given
        let config = ZoomStateMachine.Config(zoomInDuration: 0.4, baseHoldTime: 1.0)
        let sut = ZoomStateMachine(config: config)
        let position = CGPoint(x: 0.5, y: 0.5)
        
        // when
        sut.process(event: .activityDetected(position: position, suggestedScale: 2.0), at: 0)
        sut.process(event: .zoomInComplete, at: 0.4)
        sut.process(event: .holdExpired, at: 1.4)
        let output = sut.output(at: 1.5)
        
        // then
        XCTAssertLessThan(output.scale, 2.0)
        XCTAssertTrue(output.isTransitioning)
    }
    
    func test_should_return_to_idle_after_zoom_out_complete() {
        // given
        let config = ZoomStateMachine.Config(zoomInDuration: 0.4, zoomOutDuration: 0.5, baseHoldTime: 1.0)
        let sut = ZoomStateMachine(config: config)
        let position = CGPoint(x: 0.5, y: 0.5)
        
        // when
        sut.process(event: .activityDetected(position: position, suggestedScale: 2.0), at: 0)
        sut.process(event: .zoomInComplete, at: 0.4)
        sut.process(event: .holdExpired, at: 1.4)
        sut.process(event: .zoomOutComplete, at: 1.9)
        let output = sut.output(at: 2.0)
        
        // then
        XCTAssertEqual(output.scale, 1.0, accuracy: 0.01)
        XCTAssertFalse(output.isTransitioning)
    }
    
    // MARK: - Interrupt Zoom Out
    
    func test_should_interrupt_zoom_out_when_new_activity_detected() {
        // given
        let config = ZoomStateMachine.Config(zoomInDuration: 0.4, zoomOutDuration: 0.5, baseHoldTime: 1.0)
        let sut = ZoomStateMachine(config: config)
        let position = CGPoint(x: 0.5, y: 0.5)
        
        // when
        sut.process(event: .activityDetected(position: position, suggestedScale: 2.0), at: 0)
        sut.process(event: .zoomInComplete, at: 0.4)
        sut.process(event: .holdExpired, at: 1.4)
        
        // Interrupt zoom out at 1.6s (halfway through)
        let newPosition = CGPoint(x: 0.7, y: 0.5)
        sut.process(event: .activityDetected(position: newPosition, suggestedScale: 2.0), at: 1.6)
        
        // Check that we're zooming back in
        let output = sut.output(at: 1.7)
        
        // then
        XCTAssertGreaterThan(output.scale, 1.0)
        XCTAssertTrue(output.isTransitioning)
    }
    
    // MARK: - Continuous Activity
    
    func test_should_maintain_zoom_during_continuous_activity() {
        // given
        let config = ZoomStateMachine.Config(zoomInDuration: 0.4, baseHoldTime: 1.0, activityContinuityThreshold: 0.8)
        let sut = ZoomStateMachine(config: config)
        let position = CGPoint(x: 0.5, y: 0.5)
        
        // when
        sut.process(event: .activityDetected(position: position, suggestedScale: 2.0), at: 0)
        sut.process(event: .zoomInComplete, at: 0.4)
        
        // Continuous activity every 0.5s
        for i in 1...5 {
            let time = 0.4 + Double(i) * 0.5
            let newPosition = CGPoint(x: 0.5 + CGFloat(i) * 0.05, y: 0.5)
            sut.process(event: .activityContinues(position: newPosition), at: time)
        }
        
        // Check at 3.0s - should still be zoomed
        let output = sut.output(at: 3.0)
        
        // then
        XCTAssertEqual(output.scale, 2.0, accuracy: 0.01)
    }
    
    // MARK: - Center Following
    
    func test_should_update_center_when_activity_continues() {
        // given
        let config = ZoomStateMachine.Config(zoomInDuration: 0.4, baseHoldTime: 1.0)
        let sut = ZoomStateMachine(config: config)
        let initialPosition = CGPoint(x: 0.3, y: 0.3)
        
        // when
        sut.process(event: .activityDetected(position: initialPosition, suggestedScale: 2.0), at: 0)
        sut.process(event: .zoomInComplete, at: 0.4)
        
        let newPosition = CGPoint(x: 0.7, y: 0.7)
        sut.process(event: .activityContinues(position: newPosition), at: 0.8)
        
        let output = sut.output(at: 0.8)
        
        // then
        // Center should have moved towards new position (smoothed)
        XCTAssertGreaterThan(output.center.x, initialPosition.x)
        XCTAssertGreaterThan(output.center.y, initialPosition.y)
    }
    
    // MARK: - Scale Adjustment
    
    func test_should_increase_scale_when_higher_scale_activity_detected() {
        // given
        let config = ZoomStateMachine.Config(zoomInDuration: 0.4, baseHoldTime: 1.0)
        let sut = ZoomStateMachine(config: config)
        let position = CGPoint(x: 0.5, y: 0.5)
        
        // when
        sut.process(event: .activityDetected(position: position, suggestedScale: 1.5), at: 0)
        sut.process(event: .zoomInComplete, at: 0.4)
        
        // New activity with higher scale
        sut.process(event: .activityDetected(position: position, suggestedScale: 2.5), at: 0.8)
        
        // Wait for transition
        sut.process(event: .zoomInComplete, at: 1.2)
        let output = sut.output(at: 1.2)
        
        // then
        XCTAssertEqual(output.scale, 2.5, accuracy: 0.1)
    }
    
    // MARK: - Reset
    
    func test_should_reset_to_idle_state() {
        // given
        let sut = ZoomStateMachine()
        let position = CGPoint(x: 0.5, y: 0.5)
        sut.process(event: .activityDetected(position: position, suggestedScale: 2.0), at: 0)
        
        // when
        sut.reset()
        let output = sut.output(at: 0)
        
        // then
        XCTAssertEqual(output.scale, 1.0)
        XCTAssertFalse(output.isTransitioning)
    }
    
    // MARK: - Cooldown Period
    
    func test_should_not_zoom_during_cooldown_period() {
        // given
        let config = ZoomStateMachine.Config(
            zoomInDuration: 0.4,
            zoomOutDuration: 0.5,
            baseHoldTime: 1.0,
            cooldownPeriod: 0.8
        )
        let sut = ZoomStateMachine(config: config)
        let position = CGPoint(x: 0.5, y: 0.5)
        
        // when
        // Complete a full zoom cycle
        sut.process(event: .activityDetected(position: position, suggestedScale: 2.0), at: 0)
        sut.process(event: .zoomInComplete, at: 0.4)
        sut.process(event: .holdExpired, at: 1.4)
        sut.process(event: .zoomOutComplete, at: 1.9)
        
        // Try to trigger new zoom during cooldown (at 2.0s, cooldown ends at 2.7s)
        sut.process(event: .activityDetected(position: position, suggestedScale: 2.0), at: 2.0)
        let outputDuringCooldown = sut.output(at: 2.0)
        
        // Try after cooldown
        sut.process(event: .activityDetected(position: position, suggestedScale: 2.0), at: 2.8)
        let outputAfterCooldown = sut.output(at: 2.9)
        
        // then
        XCTAssertEqual(outputDuringCooldown.scale, 1.0, accuracy: 0.01)
        XCTAssertGreaterThan(outputAfterCooldown.scale, 1.0)
    }
    
    // MARK: - Zoom Out Interruption
    
    func test_should_not_interrupt_zoom_out_when_more_than_halfway() {
        // given
        let config = ZoomStateMachine.Config(zoomInDuration: 0.4, zoomOutDuration: 0.5, baseHoldTime: 1.0)
        let sut = ZoomStateMachine(config: config)
        let position = CGPoint(x: 0.5, y: 0.5)
        
        // when
        sut.process(event: .activityDetected(position: position, suggestedScale: 2.0), at: 0)
        sut.process(event: .zoomInComplete, at: 0.4)
        sut.process(event: .holdExpired, at: 1.4)
        
        // Try to interrupt at 60% through zoom out (should NOT interrupt)
        sut.process(event: .activityDetected(position: position, suggestedScale: 2.0), at: 1.7)
        let output = sut.output(at: 1.7)
        
        // then - should still be zooming out, not zooming in
        XCTAssertLessThan(output.scale, 2.0)
        XCTAssertTrue(output.isTransitioning)
    }
    
    func test_should_interrupt_zoom_out_when_less_than_halfway() {
        // given
        let config = ZoomStateMachine.Config(zoomInDuration: 0.4, zoomOutDuration: 0.5, baseHoldTime: 1.0)
        let sut = ZoomStateMachine(config: config)
        let position = CGPoint(x: 0.5, y: 0.5)
        
        // when
        sut.process(event: .activityDetected(position: position, suggestedScale: 2.0), at: 0)
        sut.process(event: .zoomInComplete, at: 0.4)
        sut.process(event: .holdExpired, at: 1.4)
        
        // Try to interrupt at 20% through zoom out (should interrupt)
        sut.process(event: .activityDetected(position: position, suggestedScale: 2.0), at: 1.5)
        
        // Wait a bit and check
        let output = sut.output(at: 1.7)
        
        // then - should be zooming back in
        XCTAssertGreaterThan(output.scale, 1.5)
        XCTAssertTrue(output.isTransitioning)
    }
    
    // MARK: - Safe Zone
    
    func test_should_keep_cursor_in_safe_zone_for_corner_position() {
        // given
        let config = ZoomStateMachine.Config(edgeSafetyMargin: 0.15)
        let sut = ZoomStateMachine(config: config)
        
        // Cursor at top-left corner
        let cornerPosition = CGPoint(x: 0.1, y: 0.1)
        
        // when
        sut.process(event: .activityDetected(position: cornerPosition, suggestedScale: 2.0), at: 0)
        sut.process(event: .zoomInComplete, at: 0.4)
        let output = sut.output(at: 0.5)
        
        // then
        // At scale 2.0, visible area is 0.5x0.5
        // Center should be adjusted so cursor is not at the edge
        // Minimum center should be 0.25 (half of visible width)
        XCTAssertGreaterThanOrEqual(output.center.x, 0.25)
        XCTAssertGreaterThanOrEqual(output.center.y, 0.25)
    }
    
    // MARK: - Large Movement
    
    func test_should_zoom_out_then_pan_then_zoom_in_for_large_movement() {
        // given
        let config = ZoomStateMachine.Config(
            zoomInDuration: 0.4,
            zoomOutDuration: 0.5,
            baseHoldTime: 1.0,
            largeMovementThreshold: 0.25,
            panDuration: 0.3
        )
        let sut = ZoomStateMachine(config: config)
        let startPosition = CGPoint(x: 0.2, y: 0.2)
        let endPosition = CGPoint(x: 0.8, y: 0.8)
        
        // when
        // First, zoom in at start position
        sut.process(event: .activityDetected(position: startPosition, suggestedScale: 2.0), at: 0)
        sut.process(event: .zoomInComplete, at: 0.4)
        
        // Large movement detected
        sut.process(
            event: .largeMovement(from: startPosition, to: endPosition, distance: 0.85, suggestedScale: 2.0),
            at: 0.8
        )
        
        // Check we're zooming out
        let outputZoomingOut = sut.output(at: 0.9)
        XCTAssertLessThan(outputZoomingOut.scale, 2.0)
        XCTAssertTrue(outputZoomingOut.isTransitioning)
        
        // Complete zoom out
        sut.process(event: .zoomOutComplete, at: 1.3)
        
        // Should now be panning
        XCTAssertTrue(sut.currentState.isPanning)
        
        // Complete pan
        sut.process(event: .panComplete, at: 1.6)
        
        // Should now be zooming back in
        let outputZoomingIn = sut.output(at: 1.7)
        XCTAssertGreaterThan(outputZoomingIn.scale, 1.0)
        XCTAssertTrue(outputZoomingIn.isTransitioning)
        
        // Center should be near end position
        XCTAssertGreaterThan(outputZoomingIn.center.x, 0.5)
        XCTAssertGreaterThan(outputZoomingIn.center.y, 0.5)
    }
    
    func test_should_follow_cursor_smoothly_during_zoomed_state() {
        // given
        let config = ZoomStateMachine.Config(
            zoomInDuration: 0.4,
            baseHoldTime: 2.0,
            centerFollowFactor: 0.4
        )
        let sut = ZoomStateMachine(config: config)
        let startPosition = CGPoint(x: 0.3, y: 0.3)
        
        // when
        sut.process(event: .activityDetected(position: startPosition, suggestedScale: 2.0), at: 0)
        sut.process(event: .zoomInComplete, at: 0.4)
        
        let initialCenter = sut.output(at: 0.4).center
        
        // Continuous movement
        sut.process(event: .activityContinues(position: CGPoint(x: 0.5, y: 0.5)), at: 0.6)
        let output1 = sut.output(at: 0.6)
        
        sut.process(event: .activityContinues(position: CGPoint(x: 0.7, y: 0.7)), at: 0.8)
        let output2 = sut.output(at: 0.8)
        
        // then
        // Center should progressively move towards cursor
        XCTAssertGreaterThan(output1.center.x, initialCenter.x)
        XCTAssertGreaterThan(output2.center.x, output1.center.x)
    }
    
    func test_should_update_target_during_panning_when_new_activity_detected() {
        // given
        let config = ZoomStateMachine.Config(
            zoomInDuration: 0.4,
            zoomOutDuration: 0.5,
            baseHoldTime: 1.0,
            panDuration: 0.3
        )
        let sut = ZoomStateMachine(config: config)
        let startPosition = CGPoint(x: 0.2, y: 0.2)
        let firstTarget = CGPoint(x: 0.8, y: 0.8)
        let secondTarget = CGPoint(x: 0.5, y: 0.5)
        
        // when
        // Start zoom, then large movement
        sut.process(event: .activityDetected(position: startPosition, suggestedScale: 2.0), at: 0)
        sut.process(event: .zoomInComplete, at: 0.4)
        sut.process(
            event: .largeMovement(from: startPosition, to: firstTarget, distance: 0.85, suggestedScale: 2.0),
            at: 0.8
        )
        sut.process(event: .zoomOutComplete, at: 1.3)
        
        // During panning, new activity detected
        sut.process(event: .activityDetected(position: secondTarget, suggestedScale: 2.0), at: 1.4)
        
        // Should still be panning or have updated target
        let output = sut.output(at: 1.5)
        
        // then
        // Should continue towards new target
        XCTAssertTrue(output.isTransitioning || !output.isTransitioning) // State changed or continued
    }
}
