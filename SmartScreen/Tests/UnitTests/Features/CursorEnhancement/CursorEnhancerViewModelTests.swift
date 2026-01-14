import XCTest
@testable import SmartScreen

@MainActor
final class CursorEnhancerViewModelTests: XCTestCase {
    
    // MARK: - Initialization
    
    func test_should_initialize_with_default_settings() {
        // given/when
        let sut = CursorEnhancerViewModel()
        
        // then
        XCTAssertEqual(sut.smoothingLevel, .medium)
        XCTAssertTrue(sut.highlightEnabled)
        XCTAssertTrue(sut.activeHighlights.isEmpty)
    }
    
    func test_should_initialize_with_custom_settings() {
        // given/when
        let sut = CursorEnhancerViewModel(smoothingLevel: .high, highlightEnabled: false)
        
        // then
        XCTAssertEqual(sut.smoothingLevel, .high)
        XCTAssertFalse(sut.highlightEnabled)
    }
    
    // MARK: - Smoothing Level
    
    func test_should_update_smoothing_level() {
        // given
        let sut = CursorEnhancerViewModel()
        
        // when
        sut.smoothingLevel = .low
        
        // then
        XCTAssertEqual(sut.smoothingLevel, .low)
    }
    
    // MARK: - Highlight Toggle
    
    func test_should_toggle_highlight_enabled() {
        // given
        let sut = CursorEnhancerViewModel()
        XCTAssertTrue(sut.highlightEnabled)
        
        // when
        sut.highlightEnabled = false
        
        // then
        XCTAssertFalse(sut.highlightEnabled)
    }
    
    // MARK: - Click Event Handling
    
    func test_should_add_highlight_when_click_event_received() async {
        // given
        let sut = CursorEnhancerViewModel()
        let event = ClickEvent(
            type: .leftClick,
            position: CGPoint(x: 100, y: 200),
            timestamp: 0
        )
        
        // when
        sut.handleClick(event)
        
        // then
        XCTAssertEqual(sut.activeHighlights.count, 1)
        XCTAssertEqual(sut.activeHighlights.first?.position, event.position)
    }
    
    func test_should_not_add_highlight_when_disabled() {
        // given
        let sut = CursorEnhancerViewModel()
        sut.highlightEnabled = false
        let event = ClickEvent(
            type: .leftClick,
            position: CGPoint(x: 100, y: 200),
            timestamp: 0
        )
        
        // when
        sut.handleClick(event)
        
        // then
        XCTAssertTrue(sut.activeHighlights.isEmpty)
    }
    
    // MARK: - Cursor Position Processing
    
    func test_should_smooth_cursor_positions() {
        // given
        let sut = CursorEnhancerViewModel()
        let positions = [
            CursorPoint(position: CGPoint(x: 0, y: 0), timestamp: 0),
            CursorPoint(position: CGPoint(x: 10, y: 10), timestamp: 0.016),
            CursorPoint(position: CGPoint(x: 20, y: 20), timestamp: 0.032)
        ]
        
        // when
        let smoothed = sut.processPositions(positions)
        
        // then
        XCTAssertEqual(smoothed.count, positions.count)
    }
}
