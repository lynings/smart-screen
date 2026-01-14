import XCTest
import AVFoundation
@testable import SmartScreen

final class CursorEnhancedExporterTests: XCTestCase {
    
    // MARK: - Initialization
    
    func test_should_create_exporter_with_default_settings() async {
        // given/when
        let exporter = CursorEnhancedExporter()
        
        // then
        XCTAssertEqual(exporter.smoothingLevel, .medium)
        XCTAssertTrue(exporter.highlightEnabled)
    }
    
    func test_should_create_exporter_with_custom_settings() async {
        // given/when
        let exporter = CursorEnhancedExporter(
            smoothingLevel: .high,
            highlightEnabled: false
        )
        
        // then
        XCTAssertEqual(exporter.smoothingLevel, .high)
        XCTAssertFalse(exporter.highlightEnabled)
    }
    
    // MARK: - Export State
    
    func test_should_not_be_exporting_initially() async {
        // given/when
        let exporter = CursorEnhancedExporter()
        
        // then
        let isExporting = await exporter.isExporting
        XCTAssertFalse(isExporting)
    }
    
    func test_should_have_zero_progress_initially() async {
        // given/when
        let exporter = CursorEnhancedExporter()
        
        // then
        let progress = await exporter.progress
        XCTAssertEqual(progress, 0)
    }
    
    // MARK: - Highlight Calculation
    
    func test_should_calculate_active_highlights_at_click_time() {
        // given
        let exporter = CursorEnhancedExporter()
        // Normalized coordinates (0-1)
        let cursorSession = CursorTrackSession(
            events: [
                MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0),
                MouseEvent(type: .rightClick, position: CGPoint(x: 0.75, y: 0.25), timestamp: 2.0)
            ],
            duration: 5.0
        )
        let videoSize = CGSize(width: 1920, height: 1080)
        
        // when - at time 1.15s (during first click animation)
        let highlights = exporter.activeHighlights(at: 1.15, cursorSession: cursorSession, videoSize: videoSize)
        
        // then
        XCTAssertEqual(highlights.count, 1)
        // Position should be converted from normalized (0.5, 0.5) to video (960, 540)
        XCTAssertEqual(highlights.first?.position.x ?? 0, 960, accuracy: 1)
        XCTAssertEqual(highlights.first?.position.y ?? 0, 540, accuracy: 1)
    }
    
    func test_should_return_empty_highlights_when_disabled() {
        // given
        let exporter = CursorEnhancedExporter(highlightEnabled: false)
        let cursorSession = CursorTrackSession(
            events: [
                MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0)
            ],
            duration: 5.0
        )
        let videoSize = CGSize(width: 1920, height: 1080)
        
        // when
        let highlights = exporter.activeHighlights(at: 1.15, cursorSession: cursorSession, videoSize: videoSize)
        
        // then
        XCTAssertTrue(highlights.isEmpty)
    }
    
    func test_should_return_empty_highlights_when_no_clicks() {
        // given
        let exporter = CursorEnhancedExporter()
        let cursorSession = CursorTrackSession(
            events: [
                MouseEvent(type: .move, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0)
            ],
            duration: 5.0
        )
        let videoSize = CGSize(width: 1920, height: 1080)
        
        // when
        let highlights = exporter.activeHighlights(at: 1.15, cursorSession: cursorSession, videoSize: videoSize)
        
        // then
        XCTAssertTrue(highlights.isEmpty)
    }
    
    func test_should_return_empty_highlights_after_animation_ends() {
        // given
        let exporter = CursorEnhancedExporter()
        let cursorSession = CursorTrackSession(
            events: [
                MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0)
            ],
            duration: 5.0
        )
        let videoSize = CGSize(width: 1920, height: 1080)
        
        // when - at time 5.0s (well after click animation duration ~0.3s)
        let highlights = exporter.activeHighlights(at: 5.0, cursorSession: cursorSession, videoSize: videoSize)
        
        // then
        XCTAssertTrue(highlights.isEmpty)
    }
    
    func test_should_convert_normalized_corners_to_video_coordinates() {
        // given
        let exporter = CursorEnhancedExporter()
        let videoSize = CGSize(width: 1920, height: 1080)
        
        // Test click at top-left corner (normalized 0, 0)
        let topLeftSession = CursorTrackSession(
            events: [MouseEvent(type: .leftClick, position: CGPoint(x: 0, y: 0), timestamp: 1.0)],
            duration: 5.0
        )
        let topLeftHighlights = exporter.activeHighlights(at: 1.1, cursorSession: topLeftSession, videoSize: videoSize)
        XCTAssertEqual(topLeftHighlights.first?.position.x ?? 0, 0, accuracy: 1)
        XCTAssertEqual(topLeftHighlights.first?.position.y ?? 0, 0, accuracy: 1)
        
        // Test click at bottom-right corner (normalized 1, 1)
        let bottomRightSession = CursorTrackSession(
            events: [MouseEvent(type: .leftClick, position: CGPoint(x: 1, y: 1), timestamp: 1.0)],
            duration: 5.0
        )
        let bottomRightHighlights = exporter.activeHighlights(at: 1.1, cursorSession: bottomRightSession, videoSize: videoSize)
        XCTAssertEqual(bottomRightHighlights.first?.position.x ?? 0, 1920, accuracy: 1)
        XCTAssertEqual(bottomRightHighlights.first?.position.y ?? 0, 1080, accuracy: 1)
    }
}
