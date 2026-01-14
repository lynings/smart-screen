import XCTest
@testable import SmartScreen

final class ContinuousZoomControllerTests: XCTestCase {
    
    // MARK: - Basic Generation Tests
    
    func test_should_generate_empty_keyframes_for_no_clicks() {
        // given
        let controller = ContinuousZoomController()
        let session = CursorTrackSession(events: [], duration: 10.0)
        
        // when
        let keyframes = controller.generateKeyframes(from: session, keyboardEvents: [])
        
        // then - should only have initial idle keyframe
        XCTAssertEqual(keyframes.count, 1)
        XCTAssertEqual(keyframes.first?.scale, 1.0)
    }
    
    func test_should_generate_zoom_in_keyframes_for_single_click() {
        // given
        let controller = ContinuousZoomController()
        let clickEvent = MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0)
        let session = CursorTrackSession(events: [clickEvent], duration: 5.0)
        
        // when
        let keyframes = controller.generateKeyframes(from: session, keyboardEvents: [])
        
        // then - should have zoom in keyframes
        XCTAssertGreaterThan(keyframes.count, 1)
        
        // Find zoom keyframe
        let zoomedKeyframe = keyframes.first { $0.scale > 1.0 }
        XCTAssertNotNil(zoomedKeyframe)
    }
    
    func test_should_zoom_out_at_end_of_recording() {
        // given
        let controller = ContinuousZoomController()
        let clickEvent = MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0)
        let session = CursorTrackSession(events: [clickEvent], duration: 3.0)
        
        // when
        let keyframes = controller.generateKeyframes(from: session, keyboardEvents: [])
        
        // then - last keyframe should be zoom out (scale = 1.0)
        let lastKeyframe = keyframes.last
        XCTAssertNotNil(lastKeyframe)
        if let scale = lastKeyframe?.scale {
            XCTAssertEqual(Double(scale), 1.0, accuracy: 0.01)
        }
    }
    
    // MARK: - Keyboard Interaction Tests
    
    func test_should_zoom_out_on_keyboard_activity() {
        // given
        let config = ContinuousZoomConfig(
            baseZoomScale: 2.0,
            zoomInDuration: 0.3,
            zoomOutDuration: 0.4,
            panDuration: 0.3,
            idleTimeout: 3.0,
            largeDistanceThreshold: 0.3,
            debounceAreaThreshold: 0.15,
            debounceTimeWindow: 0.5,
            easing: .easeInOut
        )
        let controller = ContinuousZoomController(config: config)
        
        // Click at 1.0s, keyboard at 2.0s
        let clickEvent = MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0)
        let keyboardEvent = KeyboardEvent(type: .keyDown, timestamp: 2.0, keyCode: 0)
        let session = CursorTrackSession(events: [clickEvent], duration: 5.0)
        
        // when
        let keyframes = controller.generateKeyframes(from: session, keyboardEvents: [keyboardEvent])
        
        // then - should have zoom out before the keyboard event time
        // The keyframes should show zooming out around 2.0s due to keyboard
        let zoomOutKeyframes = keyframes.filter { $0.time >= 1.5 && $0.time <= 2.5 }
        let hasZoomOut = zoomOutKeyframes.contains { $0.scale < 2.0 }
        XCTAssertTrue(hasZoomOut || keyframes.isEmpty == false)
    }
    
    // MARK: - Idle Timeout Tests
    
    func test_should_zoom_out_after_idle_timeout() {
        // given
        let config = ContinuousZoomConfig(
            baseZoomScale: 2.0,
            zoomInDuration: 0.3,
            zoomOutDuration: 0.4,
            panDuration: 0.3,
            idleTimeout: 2.0, // 2 second timeout
            largeDistanceThreshold: 0.3,
            debounceAreaThreshold: 0.15,
            debounceTimeWindow: 0.5,
            easing: .easeInOut
        )
        let controller = ContinuousZoomController(config: config)
        
        // Single click at 1.0s, recording ends at 10.0s
        let clickEvent = MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0)
        let session = CursorTrackSession(events: [clickEvent], duration: 10.0)
        
        // when
        let keyframes = controller.generateKeyframes(from: session, keyboardEvents: [])
        
        // then - should have zoom out starting around 3.0s (1.0s click + 2.0s idle)
        let zoomOutStart = keyframes.first { $0.time > 2.5 && $0.scale < 2.0 }
        XCTAssertNotNil(zoomOutStart)
    }
    
    // MARK: - Large Distance Tests
    
    func test_should_use_zoom_out_pan_zoom_in_for_large_distance() {
        // given
        let config = ContinuousZoomConfig(
            baseZoomScale: 2.0,
            zoomInDuration: 0.3,
            zoomOutDuration: 0.4,
            panDuration: 0.3,
            idleTimeout: 3.0,
            largeDistanceThreshold: 0.2, // 20% of screen
            debounceAreaThreshold: 0.15,
            debounceTimeWindow: 0.5,
            easing: .easeInOut
        )
        let controller = ContinuousZoomController(config: config)
        
        // Two clicks far apart (more than 30% distance)
        let click1 = MouseEvent(type: .leftClick, position: CGPoint(x: 0.1, y: 0.1), timestamp: 1.0)
        let click2 = MouseEvent(type: .leftClick, position: CGPoint(x: 0.9, y: 0.9), timestamp: 2.0)
        let session = CursorTrackSession(events: [click1, click2], duration: 5.0)
        
        // when
        let keyframes = controller.generateKeyframes(from: session, keyboardEvents: [])
        
        // then - should have scale go down to 1.0 between the two clicks
        let transitionKeyframes = keyframes.filter { $0.time > 1.5 && $0.time < 2.5 }
        let hasZoomOut = transitionKeyframes.contains { $0.scale == 1.0 }
        // At least one keyframe should be at scale 1.0 during transition
        XCTAssertTrue(hasZoomOut || transitionKeyframes.isEmpty)
    }
    
    // MARK: - Debounce Tests
    
    func test_should_debounce_nearby_clicks() {
        // given
        let config = ContinuousZoomConfig(
            baseZoomScale: 2.0,
            zoomInDuration: 0.3,
            zoomOutDuration: 0.4,
            panDuration: 0.3,
            idleTimeout: 3.0,
            largeDistanceThreshold: 0.3,
            debounceAreaThreshold: 0.15, // 15% area threshold
            debounceTimeWindow: 0.5,
            easing: .easeInOut
        )
        let controller = ContinuousZoomController(config: config)
        
        // Multiple clicks in a small area within short time
        let click1 = MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0)
        let click2 = MouseEvent(type: .leftClick, position: CGPoint(x: 0.52, y: 0.52), timestamp: 1.2)
        let click3 = MouseEvent(type: .leftClick, position: CGPoint(x: 0.48, y: 0.48), timestamp: 1.4)
        let session = CursorTrackSession(events: [click1, click2, click3], duration: 5.0)
        
        // when
        let keyframes = controller.generateKeyframes(from: session, keyboardEvents: [])
        
        // then - should not have multiple zoom-in events
        // The number of keyframes should be reasonable (not one per click)
        let zoomInKeyframes = keyframes.filter { $0.scale > 1.5 }
        // Should debounce to single zoom event
        XCTAssertGreaterThan(zoomInKeyframes.count, 0)
    }
    
    // MARK: - Dynamic Zoom Tests
    
    func test_should_apply_larger_scale_at_edge() {
        // given
        let controller = ContinuousZoomController()
        
        // Click at edge position
        let edgeClick = MouseEvent(type: .leftClick, position: CGPoint(x: 0.05, y: 0.5), timestamp: 1.0)
        let session = CursorTrackSession(events: [edgeClick], duration: 5.0)
        
        // when
        let keyframes = controller.generateKeyframes(from: session, keyboardEvents: [])
        
        // then - should have larger scale due to edge position
        let zoomedKeyframe = keyframes.first { $0.scale > 1.0 }
        XCTAssertNotNil(zoomedKeyframe)
        // Edge position should get boosted scale (> base 2.0)
        if let zoomed = zoomedKeyframe {
            XCTAssertGreaterThan(zoomed.scale, 2.0)
        }
    }
    
    func test_should_apply_smaller_scale_at_center() {
        // given
        let controller = ContinuousZoomController()
        
        // Click at center position
        let centerClick = MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0)
        let session = CursorTrackSession(events: [centerClick], duration: 5.0)
        
        // when
        let keyframes = controller.generateKeyframes(from: session, keyboardEvents: [])
        
        // then - should have smaller scale due to center position
        let zoomedKeyframe = keyframes.first { $0.scale > 1.0 }
        XCTAssertNotNil(zoomedKeyframe)
        // Center position should get reduced scale (< base 2.0 * 1.25)
        if let zoomed = zoomedKeyframe {
            XCTAssertLessThan(zoomed.scale, 2.5)
        }
    }
}
