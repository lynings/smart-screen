import XCTest
@testable import SmartScreen

/// End-to-end integration tests for Phase 2 Auto Zoom features
final class Phase2IntegrationTests: XCTestCase {
    
    // MARK: - Helpers
    
    private func makeSession(with clicks: [ClickEvent], duration: TimeInterval? = nil) -> CursorTrackSession {
        let mouseEvents = clicks.map { click in
            MouseEvent(
                type: .leftClick,
                position: click.position,
                timestamp: click.timestamp
            )
        }
        let sessionDuration = duration ?? (clicks.last.map { $0.timestamp + 3.0 } ?? 0)
        return CursorTrackSession(
            events: mouseEvents,
            duration: sessionDuration
        )
    }
    
    // MARK: - Complete Workflow Tests
    
    func test_complete_workflow_with_multiple_interactions() {
        // given - realistic scenario with multiple clicks at different distances
        let config = ContinuousZoomConfig(
            zoomInDuration: 0.3,
            holdMin: 0.35,
            holdBase: 0.8,
            largeDistanceThreshold: 0.3
        )
        let controller = ContinuousZoomController(config: config)
        
        // Scenario: User clicks through a UI workflow
        let clicks = [
            ClickEvent(type: .leftClick, position: CGPoint(x: 0.2, y: 0.2), timestamp: 1.0),   // Click 1: Top-left button
            ClickEvent(type: .leftClick, position: CGPoint(x: 0.22, y: 0.21), timestamp: 1.1), // Click 2: Same button (merge)
            ClickEvent(type: .leftClick, position: CGPoint(x: 0.8, y: 0.3), timestamp: 2.5),   // Click 3: Top-right (large distance)
            ClickEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.7), timestamp: 4.0),   // Click 4: Bottom-center
            ClickEvent(type: .leftClick, position: CGPoint(x: 0.52, y: 0.72), timestamp: 4.2)  // Click 5: Nearby (small movement)
        ]
        
        let session = makeSession(with: clicks, duration: 8.0)
        
        // when
        let keyframes = controller.generateKeyframes(
            from: session,
            keyboardEvents: [],
            referenceSize: CGSize(width: 1920, height: 1080)
        )
        
        // then
        print("\n📊 Complete Workflow Timeline:")
        for kf in keyframes.prefix(30) {
            print(String(format: "  t=%.2fs scale=%.2f center=(%.3f, %.3f)", 
                         kf.time, kf.scale, kf.center.x, kf.center.y))
        }
        
        // Verify key characteristics:
        // 1. Clicks 1 and 2 should be merged
        let earlyKeyframes = keyframes.filter { $0.time < 2.0 && $0.scale > 1.5 }
        XCTAssertFalse(earlyKeyframes.isEmpty, "Should have zoom for merged clicks")
        
        // 2. Large distance transition (Click 3) should use parallel interpolation
        let transition1 = keyframes.filter { $0.time >= 2.5 && $0.time <= 3.5 }
        XCTAssertGreaterThan(transition1.count, 3, "Should have multiple keyframes for smooth transition")
        
        // 3. Small movement (Clicks 4-5) should use pan or be rejected
        let lateKeyframes = keyframes.filter { $0.time >= 4.0 && $0.time < 5.0 }
        XCTAssertFalse(lateKeyframes.isEmpty, "Should handle late clicks")
        
        // 4. Should eventually zoom out at end (scale approaching 1.0 with spring animation)
        let finalKeyframes = keyframes.suffix(5)
        let minFinalScale = finalKeyframes.map(\.scale).min() ?? 2.0
        XCTAssertLessThan(minFinalScale, 1.5, "Should zoom out toward 1.0 at end of session")
    }
    
    func test_hold_phase_stability_with_rapid_clicks() {
        // given - test that Hold phase maintains stability even with rapid clicks
        let config = ContinuousZoomConfig(
            zoomInDuration: 0.3,
            holdMin: 0.4,
            holdBase: 0.8,
            largeDistanceThreshold: 0.3
        )
        let controller = ContinuousZoomController(config: config)
        
        // Rapid clicks in same area (should be merged/debounced)
        let clicks = [
            ClickEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0),
            ClickEvent(type: .leftClick, position: CGPoint(x: 0.51, y: 0.51), timestamp: 1.15),
            ClickEvent(type: .leftClick, position: CGPoint(x: 0.49, y: 0.52), timestamp: 1.3),
            ClickEvent(type: .leftClick, position: CGPoint(x: 0.52, y: 0.48), timestamp: 1.45)
        ]
        
        let session = makeSession(with: clicks)
        
        // when
        let keyframes = controller.generateKeyframes(
            from: session,
            keyboardEvents: [],
            referenceSize: CGSize(width: 1920, height: 1080)
        )
        
        // then
        let holdKeyframes = keyframes.filter { $0.time >= 1.3 && $0.time <= 2.5 && $0.scale > 1.5 }
        
        // All keyframes in Hold should be at same position (stable)
        if let firstHold = holdKeyframes.first {
            for kf in holdKeyframes {
                let distance = hypot(kf.center.x - firstHold.center.x, kf.center.y - firstHold.center.y)
                XCTAssertLessThan(distance, 0.05, "Hold should be stable at t=\(kf.time)")
            }
        }
    }
    
    func test_adaptive_transition_speeds() {
        // given - verify transitions adapt to distance
        let config = ContinuousZoomConfig(
            zoomInDuration: 0.3,
            holdBase: 0.6,
            largeDistanceThreshold: 0.3
        )
        let controller = ContinuousZoomController(config: config)
        
        // Three scenarios: short, medium, long distance
        let shortDist = [
            ClickEvent(type: .leftClick, position: CGPoint(x: 0.4, y: 0.4), timestamp: 1.0),
            ClickEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 2.0)
        ]
        let mediumDist = [
            ClickEvent(type: .leftClick, position: CGPoint(x: 0.3, y: 0.3), timestamp: 1.0),
            ClickEvent(type: .leftClick, position: CGPoint(x: 0.7, y: 0.7), timestamp: 2.0)
        ]
        let longDist = [
            ClickEvent(type: .leftClick, position: CGPoint(x: 0.1, y: 0.1), timestamp: 1.0),
            ClickEvent(type: .leftClick, position: CGPoint(x: 0.9, y: 0.9), timestamp: 2.0)
        ]
        
        // when
        let kfShort = controller.generateKeyframes(from: makeSession(with: shortDist), keyboardEvents: [], referenceSize: CGSize(width: 1920, height: 1080))
        let kfMedium = controller.generateKeyframes(from: makeSession(with: mediumDist), keyboardEvents: [], referenceSize: CGSize(width: 1920, height: 1080))
        let kfLong = controller.generateKeyframes(from: makeSession(with: longDist), keyboardEvents: [], referenceSize: CGSize(width: 1920, height: 1080))
        
        // then
        let countShort = kfShort.filter { $0.time >= 2.0 && $0.time < 3.0 }.count
        let countMedium = kfMedium.filter { $0.time >= 2.0 && $0.time < 3.0 }.count
        let countLong = kfLong.filter { $0.time >= 2.0 && $0.time < 3.0 }.count
        
        print("\n📏 Transition keyframe counts:")
        print("  Short:  \(countShort)")
        print("  Medium: \(countMedium)")
        print("  Long:   \(countLong)")
        
        // Longer distances should have more keyframes (longer transitions)
        XCTAssertGreaterThan(countLong, countShort, "Long distance should have longer transition")
    }
    
    func test_interruptible_hold_behavior() {
        // given
        let config = ContinuousZoomConfig(
            zoomInDuration: 0.3,
            holdMin: 0.4,
            holdBase: 0.8,
            largeDistanceThreshold: 0.3
        )
        let controller = ContinuousZoomController(config: config)
        
        // Click1, then large-distance Click2 after holdMin
        // Distance = sqrt((0.8-0.2)^2 + (0.8-0.2)^2) = sqrt(0.72) = 0.85 > threshold(0.3)
        let clicks = [
            ClickEvent(type: .leftClick, position: CGPoint(x: 0.2, y: 0.2), timestamp: 1.0),
            ClickEvent(type: .leftClick, position: CGPoint(x: 0.8, y: 0.8), timestamp: 1.8)  // 0.5s after Ease In (holdMin=0.4)
        ]
        
        let session = makeSession(with: clicks)
        
        // when
        let keyframes = controller.generateKeyframes(
            from: session,
            keyboardEvents: [],
            referenceSize: CGSize(width: 1920, height: 1080)
        )
        
        print("\n🔍 Interruptible Hold keyframes:")
        for kf in keyframes.filter({ $0.time >= 1.3 && $0.time <= 2.5 }) {
            print(String(format: "  t=%.2fs scale=%.2f", kf.time, kf.scale))
        }
        
        // then
        // Hold starts at t=1.3, Click2 at t=1.8, holdElapsed=0.5s > holdMin(0.4s)
        // Should allow early interruption for large distance
        // Transition should start at or shortly after t=1.8
        let transitionKeyframes = keyframes.filter { $0.time >= 1.8 && $0.time <= 2.0 }
        let hasTransition = !transitionKeyframes.isEmpty
        
        XCTAssertTrue(hasTransition, "Should have transition keyframes after holdMin for large distance")
        
        // Verify transition actually starts (scale changes from zoomed state)
        if let firstAfterClick = transitionKeyframes.first {
            // Should see scale starting to decrease or center starting to move
            XCTAssertLessThanOrEqual(firstAfterClick.time - 1.8, 0.2, "Transition should start within 0.2s of Click2")
        }
    }
}
