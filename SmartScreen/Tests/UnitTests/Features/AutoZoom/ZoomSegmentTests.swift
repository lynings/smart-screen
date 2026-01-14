import XCTest
@testable import SmartScreen

final class ZoomSegmentTests: XCTestCase {
    
    // MARK: - Initialization
    
    func test_should_create_segment_with_values() {
        // given/when
        let segment = ZoomSegment(
            startTime: 1.0,
            endTime: 3.0,
            center: CGPoint(x: 100, y: 200),
            scale: 2.0,
            easing: .easeInOut
        )
        
        // then
        XCTAssertEqual(segment.startTime, 1.0)
        XCTAssertEqual(segment.endTime, 3.0)
        XCTAssertEqual(segment.center, CGPoint(x: 100, y: 200))
        XCTAssertEqual(segment.scale, 2.0)
        XCTAssertEqual(segment.easing, .easeInOut)
    }
    
    // MARK: - Duration
    
    func test_should_calculate_duration() {
        // given
        let segment = ZoomSegment(
            startTime: 1.0,
            endTime: 3.5,
            center: .zero,
            scale: 2.0,
            easing: .linear
        )
        
        // when
        let duration = segment.duration
        
        // then
        XCTAssertEqual(duration, 2.5)
    }
    
    // MARK: - Contains Time
    
    func test_should_contain_time_within_range() {
        // given
        let segment = ZoomSegment(
            startTime: 1.0,
            endTime: 3.0,
            center: .zero,
            scale: 2.0,
            easing: .linear
        )
        
        // when/then
        XCTAssertTrue(segment.contains(time: 1.0))
        XCTAssertTrue(segment.contains(time: 2.0))
        XCTAssertTrue(segment.contains(time: 3.0))
    }
    
    func test_should_not_contain_time_outside_range() {
        // given
        let segment = ZoomSegment(
            startTime: 1.0,
            endTime: 3.0,
            center: .zero,
            scale: 2.0,
            easing: .linear
        )
        
        // when/then
        XCTAssertFalse(segment.contains(time: 0.5))
        XCTAssertFalse(segment.contains(time: 3.5))
    }
    
    // MARK: - Progress Calculation
    
    func test_should_calculate_progress_at_start() {
        // given
        let segment = ZoomSegment(
            startTime: 1.0,
            endTime: 3.0,
            center: .zero,
            scale: 2.0,
            easing: .linear
        )
        
        // when
        let progress = segment.progress(at: 1.0)
        
        // then
        XCTAssertEqual(progress, 0.0, accuracy: 0.001)
    }
    
    func test_should_calculate_progress_at_middle() {
        // given
        let segment = ZoomSegment(
            startTime: 1.0,
            endTime: 3.0,
            center: .zero,
            scale: 2.0,
            easing: .linear
        )
        
        // when
        let progress = segment.progress(at: 2.0)
        
        // then
        XCTAssertEqual(progress, 0.5, accuracy: 0.001)
    }
    
    func test_should_calculate_progress_at_end() {
        // given
        let segment = ZoomSegment(
            startTime: 1.0,
            endTime: 3.0,
            center: .zero,
            scale: 2.0,
            easing: .linear
        )
        
        // when
        let progress = segment.progress(at: 3.0)
        
        // then
        XCTAssertEqual(progress, 1.0, accuracy: 0.001)
    }
    
    // MARK: - Scale at Time
    
    func test_should_return_scale_1_before_segment() {
        // given
        let segment = ZoomSegment(
            startTime: 1.0,
            endTime: 3.0,
            center: .zero,
            scale: 2.0,
            easing: .linear
        )
        
        // when
        let scale = segment.scale(at: 0.5)
        
        // then
        XCTAssertEqual(scale, 1.0, accuracy: 0.001)
    }
    
    func test_should_interpolate_scale_during_zoom_in() {
        // given
        let segment = ZoomSegment(
            startTime: 1.0,
            endTime: 3.0,
            center: .zero,
            scale: 2.0,
            easing: .linear
        )
        
        // when - at t=1.2, we're 10% through (within zoomIn phase = first 20%)
        let scale = segment.scale(at: 1.2)
        
        // then - scale should be interpolating from 1.0 to 2.0
        XCTAssertGreaterThan(scale, 1.0)
        XCTAssertLessThan(scale, 2.0)
    }
    
    func test_should_return_full_scale_during_hold() {
        // given
        let segment = ZoomSegment(
            startTime: 1.0,
            endTime: 3.0,
            center: .zero,
            scale: 2.0,
            easing: .linear
        )
        
        // when - at middle of segment (hold phase)
        let scale = segment.scale(at: 2.0)
        
        // then
        XCTAssertEqual(scale, 2.0, accuracy: 0.001)
    }
}
