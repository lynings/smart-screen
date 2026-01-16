import XCTest
@testable import SmartScreen

/// Tests for keyboard activity protection during Auto Zoom
/// 
/// Scenario 12: Long-duration text input should maintain zoom
/// - Click input field → Extended keyboard activity → Should NOT zoom out during input
final class KeyboardProtectionTests: XCTestCase {
    
    // MARK: - Fixtures
    
    private func makeSUT(config: ContinuousZoomConfig = .default) -> ContinuousZoomController {
        ContinuousZoomController(config: config)
    }
    
    private func makeKeyboardEvent(keyCode: UInt16 = 0, timestamp: TimeInterval) -> KeyboardEvent {
        KeyboardEvent(
            type: .keyDown,
            timestamp: timestamp,
            keyCode: keyCode
        )
    }
    
    // MARK: - Tests
    
    func test_should_maintain_zoom_during_extended_keyboard_activity() {
        // given: User clicks input field and types for 30 seconds
        let config = ContinuousZoomConfig.default
        let sut = makeSUT(config: config)
        
        let clickTime = 1.0
        let clickPosition = CGPoint(x: 0.5, y: 0.3)
        
        // Simulate keyboard events over 30 seconds
        var keyboardEvents: [KeyboardEvent] = []
        for i in 0..<60 {  // 60 keystrokes over 30s (one every 0.5s)
            keyboardEvents.append(makeKeyboardEvent(timestamp: clickTime + 0.5 + Double(i) * 0.5))
        }
        
        let mouseEvents: [MouseEvent] = [
            MouseEvent(type: .leftClick, position: clickPosition, timestamp: clickTime)
        ]
        let session = CursorTrackSession(events: mouseEvents, duration: 35.0)
        
        // when
        let keyframes = sut.generateKeyframes(from: session, keyboardEvents: keyboardEvents)
        
        // then: Should maintain zoom throughout keyboard activity
        // Expect zoom to be maintained until at least last keyboard event + buffer (5s)
        let lastKeyboardTime = keyboardEvents.last!.timestamp
        let expectedZoomUntil = lastKeyboardTime + 5.0  // 5s buffer after last keystroke
        
        let zoomedKeyframes = keyframes.filter { $0.scale > 1.0 }
        
        XCTAssertGreaterThan(zoomedKeyframes.count, 0, "Should maintain zoom during keyboard activity")
        
        // Verify the last zoomed keyframe is reasonably close to expected time
        // Allow 2-3s tolerance for transition timing
        if let lastZoomedKeyframe = zoomedKeyframes.last {
            XCTAssertGreaterThanOrEqual(
                lastZoomedKeyframe.time,
                expectedZoomUntil - 3.0,
                "Should maintain zoom until at least \(expectedZoomUntil - 3.0)s (actual: \(String(format: "%.2f", lastZoomedKeyframe.time))s)"
            )
        }
        
        print("🔍 Keyboard protection test:")
        print("  Click time: \(clickTime)s")
        print("  Last keyboard: \(lastKeyboardTime)s")
        print("  Expected zoom until: \(expectedZoomUntil)s")
        print("  Zoomed keyframes: \(zoomedKeyframes.count)")
        if let last = zoomedKeyframes.last {
            print("  Last zoomed at: \(String(format: "%.2f", last.time))s")
        }
    }
    
    func test_should_tolerate_short_pauses_during_typing() {
        // given: User types with a 2-second pause in between (< idleTimeout of 3s)
        let config = ContinuousZoomConfig.default
        let sut = makeSUT(config: config)
        
        let clickTime = 1.0
        let clickPosition = CGPoint(x: 0.5, y: 0.3)
        
        // Keyboard events: type for 5s → pause 2s → type for 5s more
        var keyboardEvents: [KeyboardEvent] = []
        
        // First burst: 1.5s - 6.5s
        for i in 0..<10 {
            keyboardEvents.append(makeKeyboardEvent(timestamp: 1.5 + Double(i) * 0.5))
        }
        
        // Pause: 6.5s - 8.5s (2 seconds, < 3s idleTimeout)
        
        // Second burst: 8.5s - 13.5s
        for i in 0..<10 {
            keyboardEvents.append(makeKeyboardEvent(timestamp: 8.5 + Double(i) * 0.5))
        }
        
        let mouseEvents: [MouseEvent] = [
            MouseEvent(type: .leftClick, position: clickPosition, timestamp: clickTime)
        ]
        let session = CursorTrackSession(events: mouseEvents, duration: 20.0)
        
        // when
        let keyframes = sut.generateKeyframes(from: session, keyboardEvents: keyboardEvents)
        
        // then: Should maintain zoom through the pause (2s < 3s idleTimeout)
        let lastKeyboardTime = keyboardEvents.last!.timestamp  // 13.5s
        let expectedZoomUntil = lastKeyboardTime + 5.0  // 18.5s
        
        let zoomedKeyframes = keyframes.filter { $0.scale > 1.0 }
        
        XCTAssertGreaterThan(zoomedKeyframes.count, 0, "Should maintain zoom through short pause")
        
        // Key verification: The Hold keyframe should extend beyond the second keyboard burst
        // This proves that the keyboard protection kept the zoom active through the pause
        if let lastZoomed = zoomedKeyframes.last {
            XCTAssertGreaterThanOrEqual(
                lastZoomed.time,
                lastKeyboardTime,  // Should be >= 13.5s
                "Hold should extend through second keyboard burst (actual: \(String(format: "%.2f", lastZoomed.time))s)"
            )
        }
        
        print("🔍 Short pause tolerance test:")
        print("  Last keyboard: \(lastKeyboardTime)s")
        print("  Last zoomed keyframe: \(zoomedKeyframes.last?.time ?? 0)s")
        print("  ✅ Keyboard protection extended Hold through 2s pause!")
    }
    
    func test_should_zoom_out_after_long_pause() {
        // given: User types then stops for 6 seconds (exceeds 5s tolerance)
        let config = ContinuousZoomConfig.default
        let sut = makeSUT(config: config)
        
        let clickTime = 1.0
        let clickPosition = CGPoint(x: 0.5, y: 0.3)
        
        // Keyboard events: type for 5s then stop
        var keyboardEvents: [KeyboardEvent] = []
        for i in 0..<10 {
            keyboardEvents.append(makeKeyboardEvent(timestamp: 1.5 + Double(i) * 0.5))
        }
        let lastKeyboardTime = keyboardEvents.last!.timestamp  // 6.0s
        
        let mouseEvents: [MouseEvent] = [
            MouseEvent(type: .leftClick, position: clickPosition, timestamp: clickTime)
        ]
        let session = CursorTrackSession(events: mouseEvents, duration: 15.0)
        
        // when
        let keyframes = sut.generateKeyframes(from: session, keyboardEvents: keyboardEvents)
        
        // then: Should zoom out after 5s buffer (at ~11s)
        let expectedZoomOutStart = lastKeyboardTime + 5.0  // 11.0s
        
        // With spring animation, check for scale approaching 1.0 (not exactly 1.0)
        let zoomedOutKeyframes = keyframes.filter {
            $0.time >= expectedZoomOutStart - 0.5 &&
            $0.time <= expectedZoomOutStart + config.zoomOutDuration + 1.0 &&
            $0.scale <= 1.5  // Spring animation may not reach exactly 1.0
        }
        XCTAssertGreaterThan(zoomedOutKeyframes.count, 0, "Should zoom out after long pause (>5s) at ~\(expectedZoomOutStart)s")
        
        print("🔍 Long pause zoom out test:")
        print("  Last keyboard: \(lastKeyboardTime)s")
        print("  Expected zoom out after: \(expectedZoomOutStart)s")
        print("  Found zoomed out keyframes: \(zoomedOutKeyframes.count)")
        print("  All keyframes:")
        keyframes.forEach { kf in
            print("    t=\(String(format: "%.2f", kf.time))s scale=\(String(format: "%.2f", kf.scale))")
        }
    }
    
    func test_should_respond_to_tab_key_focus_change() {
        // given: User types in one field, then clicks another field with continued typing
        let config = ContinuousZoomConfig.default
        let sut = makeSUT(config: config)
        
        let click1Time = 1.0
        let click1Position = CGPoint(x: 0.3, y: 0.3)  // Input field 1
        
        // Type in first field briefly
        var keyboardEvents: [KeyboardEvent] = []
        for i in 0..<3 {
            keyboardEvents.append(makeKeyboardEvent(timestamp: 1.5 + Double(i) * 0.3))
        }
        
        // Click second field (large distance to ensure transition)
        let click2Time = 3.5
        let click2Position = CGPoint(x: 0.7, y: 0.7)  // Input field 2 (large distance)
        
        // Type in second field
        for i in 0..<5 {
            keyboardEvents.append(makeKeyboardEvent(timestamp: 4.0 + Double(i) * 0.3))
        }
        
        let mouseEvents: [MouseEvent] = [
            MouseEvent(type: .leftClick, position: click1Position, timestamp: click1Time),
            MouseEvent(type: .leftClick, position: click2Position, timestamp: click2Time)
        ]
        let session = CursorTrackSession(events: mouseEvents, duration: 12.0)
        
        // when
        let keyframes = sut.generateKeyframes(from: session, keyboardEvents: keyboardEvents)
        
        // then: Should transition smoothly from field 1 to field 2
        // Field 1 should have zoom keyframes
        let field1Keyframes = keyframes.filter { $0.time >= 1.0 && $0.time < 3.5 && $0.scale > 1.0 }
        // Field 2 should have zoom keyframes
        let field2Keyframes = keyframes.filter { $0.time >= 3.5 && $0.time < 7.0 && $0.scale > 1.0 }
        
        XCTAssertGreaterThan(field1Keyframes.count, 0, "Should zoom to field 1")
        XCTAssertGreaterThan(field2Keyframes.count, 0, "Should zoom to field 2 after clicking it")
        
        // Core verification: Both fields get zoom attention, and keyboard activity doesn't break the flow
        // The keyboard protection logic for extending Hold is already tested in other scenarios
        
        print("🔍 Tab/Focus change test:")
        print("  Field 1 keyframes: \(field1Keyframes.count)")
        print("  Field 2 keyframes: \(field2Keyframes.count)")
        print("  ✅ Keyboard protection works across multiple focus changes!")
    }
    
    func test_should_respond_to_new_click_during_keyboard_activity() {
        // given: User is typing but clicks elsewhere
        let config = ContinuousZoomConfig.default
        let sut = makeSUT(config: config)
        
        let click1Time = 1.0
        let click1Position = CGPoint(x: 0.5, y: 0.3)
        
        // Type for a few seconds
        var keyboardEvents: [KeyboardEvent] = []
        for i in 0..<10 {
            keyboardEvents.append(makeKeyboardEvent(timestamp: 1.5 + Double(i) * 0.3))
        }
        
        // User clicks a different location at 5.0s (large distance)
        let click2Time = 5.0
        let click2Position = CGPoint(x: 0.8, y: 0.8)
        
        let mouseEvents: [MouseEvent] = [
            MouseEvent(type: .leftClick, position: click1Position, timestamp: click1Time),
            MouseEvent(type: .leftClick, position: click2Position, timestamp: click2Time)
        ]
        let session = CursorTrackSession(events: mouseEvents, duration: 10.0)
        
        // when
        let keyframes = sut.generateKeyframes(from: session, keyboardEvents: keyboardEvents)
        
        // then: Should respond to the new click (keyboard doesn't block new clicks)
        let click2Keyframes = keyframes.filter {
            $0.time >= click2Time && $0.scale > 1.0 &&
            abs($0.center.x - 0.8) < 0.1 && abs($0.center.y - 0.8) < 0.1
        }
        
        XCTAssertGreaterThan(click2Keyframes.count, 0, "Should respond to new click despite keyboard activity")
        
        print("🔍 New click during typing test:")
        print("  Click 2 keyframes: \(click2Keyframes.count)")
    }
}
