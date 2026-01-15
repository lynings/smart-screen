import XCTest
@testable import SmartScreen

/// Tests for merging mixed click types (left, right, double clicks)
final class MixedClickTypesTests: XCTestCase {
    
    // MARK: - Helpers
    
    private func makeSession(with events: [(type: ClickType, position: CGPoint, timestamp: TimeInterval)], duration: TimeInterval? = nil) -> CursorTrackSession {
        let mouseEvents = events.map { event in
            let mouseType: MouseEventType
            switch event.type {
            case .leftClick:
                mouseType = .leftClick
            case .rightClick:
                mouseType = .rightClick
            case .doubleClick:
                mouseType = .doubleClick
            }
            return MouseEvent(
                type: mouseType,
                position: event.position,
                timestamp: event.timestamp
            )
        }
        let sessionDuration = duration ?? (events.last.map { $0.timestamp + 2.0 } ?? 0)
        return CursorTrackSession(
            events: mouseEvents,
            duration: sessionDuration
        )
    }
    
    // MARK: - should_merge_left_and_right_clicks_in_same_region
    
    func test_should_merge_left_and_right_clicks_in_same_region() {
        // given
        let config = ContinuousZoomConfig(
            zoomInDuration: 0.3,
            holdBase: 0.8,
            clickMergeTime: 0.3,
            clickMergeDistancePixels: 100
        )
        let controller = ContinuousZoomController(config: config)
        
        // Rapid left and right clicks in same area (should be merged)
        let events: [(ClickType, CGPoint, TimeInterval)] = [
            (.leftClick, CGPoint(x: 0.5, y: 0.5), 1.0),
            (.rightClick, CGPoint(x: 0.51, y: 0.51), 1.1),
            (.leftClick, CGPoint(x: 0.49, y: 0.52), 1.2)
        ]
        
        let session = makeSession(with: events)
        
        // when
        let keyframes = controller.generateKeyframes(
            from: session,
            keyboardEvents: [],
            referenceSize: CGSize(width: 1920, height: 1080)
        )
        
        // then
        print("\n🔍 Mixed click types keyframes:")
        for kf in keyframes.filter({ $0.time >= 0.5 && $0.time <= 2.5 }) {
            print(String(format: "  t=%.2fs scale=%.2f center=(%.3f, %.3f)", 
                         kf.time, kf.scale, kf.center.x, kf.center.y))
        }
        
        // Should have only ONE zoom segment (all clicks merged)
        let zoomSegments = keyframes.filter { $0.scale > 1.5 }
        
        // All zoomed keyframes should be at approximately the same position
        if let firstZoom = zoomSegments.first {
            for kf in zoomSegments {
                let distance = hypot(kf.center.x - firstZoom.center.x, kf.center.y - firstZoom.center.y)
                XCTAssertLessThan(distance, 0.1, 
                                 "All clicks should be merged to same position at t=\(kf.time)")
            }
        }
        
        // Should not have multiple zoom-in phases
        let zoomInStarts = keyframes.filter { $0.scale == 1.0 && $0.time > 0 && $0.time < 2.0 }
        XCTAssertLessThanOrEqual(zoomInStarts.count, 1, 
                                "Should have at most one zoom-in (all clicks merged)")
    }
    
    // MARK: - should_create_separate_segments_for_distant_clicks_regardless_of_type
    
    func test_should_create_separate_segments_for_distant_clicks_regardless_of_type() {
        // given
        let config = ContinuousZoomConfig(
            zoomInDuration: 0.3,
            holdBase: 0.8,
            largeDistanceThreshold: 0.3
        )
        let controller = ContinuousZoomController(config: config)
        
        // Left click then right click at distant locations (should NOT be merged)
        let events: [(ClickType, CGPoint, TimeInterval)] = [
            (.leftClick, CGPoint(x: 0.2, y: 0.2), 1.0),
            (.rightClick, CGPoint(x: 0.8, y: 0.8), 2.5)  // Far away
        ]
        
        let session = makeSession(with: events)
        
        // when
        let keyframes = controller.generateKeyframes(
            from: session,
            keyboardEvents: [],
            referenceSize: CGSize(width: 1920, height: 1080)
        )
        
        // then
        // Should have transition between the two distant clicks
        let positions = keyframes.filter { $0.time >= 1.0 && $0.time <= 3.5 && $0.scale > 1.5 }
            .map { $0.center }
        
        // Should see both positions represented
        let hasFirstPosition = positions.contains { hypot($0.x - 0.2, $0.y - 0.2) < 0.1 }
        let hasSecondPosition = positions.contains { hypot($0.x - 0.8, $0.y - 0.8) < 0.1 }
        
        XCTAssertTrue(hasFirstPosition, "Should zoom to first click position")
        XCTAssertTrue(hasSecondPosition, "Should zoom to second click position")
    }
    
    // MARK: - should_treat_double_click_same_as_single_click
    
    func test_should_treat_double_click_same_as_single_click() {
        // given
        let config = ContinuousZoomConfig(
            zoomInDuration: 0.3,
            holdBase: 0.8
        )
        let controller = ContinuousZoomController(config: config)
        
        // Double click should trigger zoom just like single click
        let events: [(ClickType, CGPoint, TimeInterval)] = [
            (.doubleClick, CGPoint(x: 0.5, y: 0.5), 1.0)
        ]
        
        let session = makeSession(with: events)
        
        // when
        let keyframes = controller.generateKeyframes(
            from: session,
            keyboardEvents: [],
            referenceSize: CGSize(width: 1920, height: 1080)
        )
        
        // then
        let zoomedKeyframes = keyframes.filter { $0.scale > 1.5 }
        XCTAssertFalse(zoomedKeyframes.isEmpty, "Double click should trigger zoom")
        
        // Should zoom to the double-click position
        if let firstZoom = zoomedKeyframes.first {
            let distance = hypot(firstZoom.center.x - 0.5, firstZoom.center.y - 0.5)
            XCTAssertLessThan(distance, 0.1, "Should zoom to double-click position")
        }
    }
    
    // MARK: - should_merge_mixed_click_types_within_time_and_distance_threshold
    
    func test_should_merge_mixed_click_types_within_time_and_distance_threshold() {
        // given
        let config = ContinuousZoomConfig(
            zoomInDuration: 0.3,
            holdBase: 0.6,
            clickMergeTime: 0.35,
            clickMergeDistancePixels: 120
        )
        let controller = ContinuousZoomController(config: config)
        
        // Complex scenario: mix of all click types in quick succession
        let events: [(ClickType, CGPoint, TimeInterval)] = [
            (.leftClick, CGPoint(x: 0.4, y: 0.4), 1.0),
            (.doubleClick, CGPoint(x: 0.41, y: 0.41), 1.15),  // 0.15s later, very close
            (.rightClick, CGPoint(x: 0.42, y: 0.39), 1.25),   // 0.25s later, still close
            (.leftClick, CGPoint(x: 0.39, y: 0.41), 1.3)      // 0.3s later, within threshold
        ]
        
        let session = makeSession(with: events)
        
        // when
        let keyframes = controller.generateKeyframes(
            from: session,
            keyboardEvents: [],
            referenceSize: CGSize(width: 1920, height: 1080)
        )
        
        // then
        let zoomedKeyframes = keyframes.filter { $0.time >= 1.0 && $0.time <= 2.5 && $0.scale > 1.5 }
        
        print("\n🔍 Complex mixed clicks - zoomed keyframes count: \(zoomedKeyframes.count)")
        
        // All clicks should be merged to approximately the same center
        if let firstZoom = zoomedKeyframes.first {
            let maxDistance = zoomedKeyframes.map { kf in
                hypot(kf.center.x - firstZoom.center.x, kf.center.y - firstZoom.center.y)
            }.max() ?? 0
            
            XCTAssertLessThan(maxDistance, 0.15, 
                             "All mixed click types should be merged to similar position (max distance: \(maxDistance))")
        }
    }
}
