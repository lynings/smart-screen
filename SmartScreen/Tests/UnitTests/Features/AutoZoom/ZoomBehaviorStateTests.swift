import XCTest
@testable import SmartScreen

final class ZoomBehaviorStateTests: XCTestCase {
    
    // MARK: - State Properties
    
    func test_idle_should_not_be_zoomed() {
        // given
        let state = ZoomBehaviorState.idle
        
        // then
        XCTAssertFalse(state.isZoomed)
        XCTAssertEqual(state.currentScale, 1.0)
    }
    
    func test_observing_should_not_be_zoomed() {
        // given
        let state = ZoomBehaviorState.observing(since: 1.0, position: CGPoint(x: 0.5, y: 0.5))
        
        // then
        XCTAssertFalse(state.isZoomed)
        XCTAssertEqual(state.currentScale, 1.0)
    }
    
    func test_zoomed_should_be_zoomed() {
        // given
        let state = ZoomBehaviorState.zoomed(center: CGPoint(x: 0.5, y: 0.5), scale: 2.0)
        
        // then
        XCTAssertTrue(state.isZoomed)
        XCTAssertEqual(state.currentScale, 2.0)
    }
    
    func test_zoomingIn_should_be_zoomed() {
        // given
        let state = ZoomBehaviorState.zoomingIn(
            startTime: 1.0,
            from: 1.0,
            to: 2.0,
            center: CGPoint(x: 0.5, y: 0.5)
        )
        
        // then
        XCTAssertTrue(state.isZoomed)
    }
    
    func test_zoomingOut_should_not_be_zoomed() {
        // given
        let state = ZoomBehaviorState.zoomingOut(
            startTime: 1.0,
            from: 2.0,
            center: CGPoint(x: 0.5, y: 0.5)
        )
        
        // then
        XCTAssertFalse(state.isZoomed)
    }
    
    func test_cooldown_should_not_be_zoomed() {
        // given
        let state = ZoomBehaviorState.cooldown(since: 1.0, lastPosition: CGPoint(x: 0.5, y: 0.5))
        
        // then
        XCTAssertFalse(state.isZoomed)
        XCTAssertEqual(state.currentScale, 1.0)
    }
}

// MARK: - Config Tests

final class ZoomBehaviorConfigTests: XCTestCase {
    
    func test_default_config_has_valid_values() {
        // given
        let config = ZoomBehaviorConfig.default
        
        // then
        XCTAssertEqual(config.stabilizationTime, 0.5)
        XCTAssertEqual(config.maxStableSpeed, 0.3)
        XCTAssertEqual(config.stableAreaRadius, 0.05)
        XCTAssertEqual(config.largeMovementThreshold, 0.25)
        XCTAssertEqual(config.maxClickFrequency, 3.0)
        XCTAssertEqual(config.cooldownDuration, 0.3)
        XCTAssertEqual(config.zoomInDuration, 0.4)
        XCTAssertEqual(config.zoomOutDuration, 0.3)
        XCTAssertEqual(config.targetScale, 2.0)
    }
    
    func test_config_from_settings() {
        // given
        let settings = AutoZoomSettings(
            isEnabled: true,
            zoomLevel: 2.5,
            duration: 1.6,
            easing: .easeOut
        )
        
        // when
        let config = ZoomBehaviorConfig.from(settings: settings)
        
        // then
        XCTAssertEqual(config.targetScale, 2.5)
        XCTAssertEqual(config.zoomInDuration, 0.4) // 1.6 * 0.25
        XCTAssertEqual(config.easing, .easeOut)
    }
}

// MARK: - Activity Event Tests

final class ActivityEventTests: XCTestCase {
    
    func test_click_event_type() {
        // given
        let event = ActivityEvent(
            type: .click,
            position: CGPoint(x: 0.5, y: 0.5),
            timestamp: 1.0
        )
        
        // then
        XCTAssertEqual(event.type, .click)
    }
    
    func test_move_event_type() {
        // given
        let event = ActivityEvent(
            type: .move,
            position: CGPoint(x: 0.3, y: 0.7),
            timestamp: 2.0
        )
        
        // then
        XCTAssertEqual(event.type, .move)
        XCTAssertEqual(event.position.x, 0.3)
        XCTAssertEqual(event.position.y, 0.7)
    }
}
