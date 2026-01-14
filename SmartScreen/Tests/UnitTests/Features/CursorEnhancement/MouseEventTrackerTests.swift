import XCTest
@testable import SmartScreen

@MainActor
final class MouseEventTrackerTests: XCTestCase {
    
    // MARK: - Initialization
    
    func test_should_not_be_tracking_initially() {
        // given/when
        let tracker = MouseEventTracker()
        
        // then
        XCTAssertFalse(tracker.isTracking)
    }
    
    func test_should_have_empty_events_initially() {
        // given/when
        let tracker = MouseEventTracker()
        
        // then
        XCTAssertTrue(tracker.events.isEmpty)
    }
    
    // MARK: - Start/Stop Tracking
    
    func test_should_set_tracking_flag_when_started() {
        // given
        let tracker = MouseEventTracker()
        
        // when
        tracker.startTracking()
        
        // then
        XCTAssertTrue(tracker.isTracking)
        tracker.stopTracking()
    }
    
    func test_should_clear_tracking_flag_when_stopped() {
        // given
        let tracker = MouseEventTracker()
        tracker.startTracking()
        
        // when
        tracker.stopTracking()
        
        // then
        XCTAssertFalse(tracker.isTracking)
    }
    
    func test_should_record_start_time_when_tracking_begins() {
        // given
        let tracker = MouseEventTracker()
        let beforeStart = Date()
        
        // when
        tracker.startTracking()
        let afterStart = Date()
        
        // then
        XCTAssertNotNil(tracker.startTime)
        XCTAssertGreaterThanOrEqual(tracker.startTime!, beforeStart)
        XCTAssertLessThanOrEqual(tracker.startTime!, afterStart)
        tracker.stopTracking()
    }
    
    // MARK: - Event Recording
    
    func test_should_add_event_when_tracking() {
        // given
        let tracker = MouseEventTracker()
        tracker.startTracking()
        let event = MouseEvent(type: .move, position: CGPoint(x: 100, y: 200), timestamp: 0.1)
        
        // when
        tracker.recordEvent(event)
        
        // then
        XCTAssertEqual(tracker.events.count, 1)
        XCTAssertEqual(tracker.events.first?.position, event.position)
        tracker.stopTracking()
    }
    
    func test_should_not_add_event_when_not_tracking() {
        // given
        let tracker = MouseEventTracker()
        let event = MouseEvent(type: .move, position: CGPoint(x: 100, y: 200), timestamp: 0.1)
        
        // when
        tracker.recordEvent(event)
        
        // then
        XCTAssertTrue(tracker.events.isEmpty)
    }
    
    func test_should_clear_events_when_reset() {
        // given
        let tracker = MouseEventTracker()
        tracker.startTracking()
        tracker.recordEvent(MouseEvent(type: .move, position: .zero, timestamp: 0))
        tracker.recordEvent(MouseEvent(type: .leftClick, position: .zero, timestamp: 0.1))
        
        // when
        tracker.reset()
        
        // then
        XCTAssertTrue(tracker.events.isEmpty)
        XCTAssertFalse(tracker.isTracking)
        XCTAssertNil(tracker.startTime)
    }
    
    // MARK: - Filtering
    
    func test_should_return_only_move_events() {
        // given
        let tracker = MouseEventTracker()
        tracker.startTracking()
        tracker.recordEvent(MouseEvent(type: .move, position: CGPoint(x: 10, y: 10), timestamp: 0.1))
        tracker.recordEvent(MouseEvent(type: .leftClick, position: CGPoint(x: 20, y: 20), timestamp: 0.2))
        tracker.recordEvent(MouseEvent(type: .move, position: CGPoint(x: 30, y: 30), timestamp: 0.3))
        
        // when
        let moveEvents = tracker.moveEvents
        
        // then
        XCTAssertEqual(moveEvents.count, 2)
        XCTAssertTrue(moveEvents.allSatisfy { $0.type == .move })
        tracker.stopTracking()
    }
    
    func test_should_return_only_click_events() {
        // given
        let tracker = MouseEventTracker()
        tracker.startTracking()
        tracker.recordEvent(MouseEvent(type: .move, position: CGPoint(x: 10, y: 10), timestamp: 0.1))
        tracker.recordEvent(MouseEvent(type: .leftClick, position: CGPoint(x: 20, y: 20), timestamp: 0.2))
        tracker.recordEvent(MouseEvent(type: .rightClick, position: CGPoint(x: 30, y: 30), timestamp: 0.3))
        
        // when
        let clickEvents = tracker.clickEvents
        
        // then
        XCTAssertEqual(clickEvents.count, 2)
        XCTAssertTrue(clickEvents.allSatisfy { $0.type != .move })
        tracker.stopTracking()
    }
}
