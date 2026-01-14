import XCTest
import SwiftUI
@testable import SmartScreen

final class ClickHighlighterTests: XCTestCase {
    
    // MARK: - Left Click
    
    func test_should_generate_pulse_animation_for_left_click() {
        // given
        let highlighter = ClickHighlighter()
        let event = ClickEvent(
            type: .leftClick,
            position: CGPoint(x: 100, y: 200),
            timestamp: 0
        )
        
        // when
        let animation = highlighter.generateHighlight(for: event)
        
        // then
        XCTAssertEqual(animation.style, .pulse)
        XCTAssertEqual(animation.position, event.position)
        XCTAssertEqual(animation.color, .blue)
        XCTAssertEqual(animation.duration, 0.3, accuracy: 0.001)
    }
    
    // MARK: - Double Click
    
    func test_should_generate_double_ring_animation_for_double_click() {
        // given
        let highlighter = ClickHighlighter()
        let event = ClickEvent(
            type: .doubleClick,
            position: CGPoint(x: 50, y: 50),
            timestamp: 0
        )
        
        // when
        let animation = highlighter.generateHighlight(for: event)
        
        // then
        XCTAssertEqual(animation.style, .doubleRing)
        XCTAssertEqual(animation.color, .blue)
        XCTAssertEqual(animation.duration, 0.4, accuracy: 0.001)
    }
    
    // MARK: - Right Click
    
    func test_should_generate_orange_pulse_for_right_click() {
        // given
        let highlighter = ClickHighlighter()
        let event = ClickEvent(
            type: .rightClick,
            position: CGPoint(x: 300, y: 400),
            timestamp: 0
        )
        
        // when
        let animation = highlighter.generateHighlight(for: event)
        
        // then
        XCTAssertEqual(animation.style, .pulse)
        XCTAssertEqual(animation.color, .orange)
        XCTAssertEqual(animation.duration, 0.3, accuracy: 0.001)
    }
    
    // MARK: - Enable/Disable
    
    func test_should_be_enabled_by_default() {
        // given/when
        let highlighter = ClickHighlighter()
        
        // then
        XCTAssertTrue(highlighter.isEnabled)
    }
    
    func test_should_allow_disabling_highlights() {
        // given
        var highlighter = ClickHighlighter()
        
        // when
        highlighter.isEnabled = false
        
        // then
        XCTAssertFalse(highlighter.isEnabled)
    }
}
