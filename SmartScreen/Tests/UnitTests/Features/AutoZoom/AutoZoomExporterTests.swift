import XCTest
import AVFoundation
@testable import SmartScreen

final class AutoZoomExporterTests: XCTestCase {
    
    // MARK: - Initialization
    
    func test_should_create_exporter_with_default_settings() async {
        // given/when
        let exporter = AutoZoomExporter()
        
        // then
        XCTAssertEqual(exporter.settings, AutoZoomSettings())
    }
    
    func test_should_create_exporter_with_custom_settings() async {
        // given
        let settings = AutoZoomSettings(zoomLevel: 2.5, idleTimeout: 4.0)
        
        // when
        let exporter = AutoZoomExporter(settings: settings)
        
        // then
        XCTAssertEqual(exporter.settings.zoomLevel, 2.5)
        XCTAssertEqual(exporter.settings.idleTimeout, 4.0)
    }
    
    // MARK: - Export State
    
    func test_should_not_be_exporting_initially() async {
        // given/when
        let exporter = AutoZoomExporter()
        
        // then
        let isExporting = await exporter.isExporting
        XCTAssertFalse(isExporting)
    }
    
    func test_should_have_zero_progress_initially() async {
        // given/when
        let exporter = AutoZoomExporter()
        
        // then
        let progress = await exporter.progress
        XCTAssertEqual(progress, 0)
    }
    
    // MARK: - Segment Analysis
    
    func test_should_analyze_session_for_zoom_segments() {
        // given
        let exporter = AutoZoomExporter()
        let session = CursorTrackSession(
            events: [
                MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0),
                MouseEvent(type: .leftClick, position: CGPoint(x: 0.8, y: 0.2), timestamp: 5.0)
            ],
            duration: 10.0
        )
        let settings = AutoZoomSettings()
        
        // when
        let segments = exporter.analyzeSession(session, settings: settings)
        
        // then
        XCTAssertEqual(segments.count, 2)
    }
    
    func test_should_return_empty_segments_when_disabled() {
        // given
        let exporter = AutoZoomExporter()
        let session = CursorTrackSession(
            events: [
                MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0)
            ],
            duration: 10.0
        )
        let settings = AutoZoomSettings(isEnabled: false)
        
        // when
        let segments = exporter.analyzeSession(session, settings: settings)
        
        // then
        XCTAssertTrue(segments.isEmpty)
    }
    
    // MARK: - Scale at Time
    
    func test_should_return_scale_1_when_no_segments() {
        // given
        let exporter = AutoZoomExporter()
        let segments: [ZoomSegment] = []
        
        // when
        let scale = exporter.scale(at: 1.0, segments: segments)
        
        // then
        XCTAssertEqual(scale, 1.0)
    }
    
    func test_should_return_segment_scale_during_zoom() {
        // given
        let exporter = AutoZoomExporter()
        let segments = [
            ZoomSegment(
                startTime: 1.0,
                endTime: 4.0,
                center: CGPoint(x: 0.5, y: 0.5),
                scale: 2.0,
                easing: .linear
            )
        ]
        
        // when - at middle of segment (hold phase)
        let scale = exporter.scale(at: 2.5, segments: segments)
        
        // then
        XCTAssertEqual(scale, 2.0, accuracy: 0.01)
    }
    
    // MARK: - Center at Time
    
    func test_should_return_nil_center_when_no_active_segment() {
        // given
        let exporter = AutoZoomExporter()
        let segments: [ZoomSegment] = []
        
        // when
        let center = exporter.center(at: 1.0, segments: segments)
        
        // then
        XCTAssertNil(center)
    }
    
    func test_should_return_segment_center_during_zoom() {
        // given
        let exporter = AutoZoomExporter()
        let segments = [
            ZoomSegment(
                startTime: 1.0,
                endTime: 4.0,
                center: CGPoint(x: 0.7, y: 0.3),
                scale: 2.0,
                easing: .linear
            )
        ]
        
        // when
        let center = exporter.center(at: 2.5, segments: segments)
        
        // then
        XCTAssertEqual(center, CGPoint(x: 0.7, y: 0.3))
    }
}
