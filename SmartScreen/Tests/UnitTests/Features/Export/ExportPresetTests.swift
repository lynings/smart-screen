import XCTest
@testable import SmartScreen

final class ExportPresetTests: XCTestCase {
    
    // MARK: - Built-in Presets
    
    func test_should_have_web_preset_with_correct_settings() {
        // given
        let sut = ExportPreset.web
        
        // then
        XCTAssertEqual(sut.name, "Web")
        XCTAssertEqual(sut.resolution, .p1080)
        XCTAssertEqual(sut.fps, 30)
        XCTAssertEqual(sut.bitrate, 8_000_000)
        XCTAssertEqual(sut.format, .mp4)
        XCTAssertTrue(sut.isBuiltIn)
    }
    
    func test_should_have_high_quality_preset_with_correct_settings() {
        // given
        let sut = ExportPreset.highQuality
        
        // then
        XCTAssertEqual(sut.name, "High Quality")
        XCTAssertEqual(sut.resolution, .p4K)
        XCTAssertEqual(sut.fps, 60)
        XCTAssertEqual(sut.bitrate, 25_000_000)
        XCTAssertEqual(sut.format, .mov)
        XCTAssertTrue(sut.isBuiltIn)
    }
    
    func test_should_have_social_preset_with_square_resolution() {
        // given
        let sut = ExportPreset.social
        
        // then
        XCTAssertEqual(sut.name, "Social")
        XCTAssertEqual(sut.resolution, .custom(width: 1080, height: 1080))
        XCTAssertEqual(sut.fps, 30)
        XCTAssertEqual(sut.format, .mp4)
    }
    
    func test_should_have_compact_preset_for_quick_sharing() {
        // given
        let sut = ExportPreset.compact
        
        // then
        XCTAssertEqual(sut.name, "Compact")
        XCTAssertEqual(sut.resolution, .p720)
        XCTAssertEqual(sut.bitrate, 4_000_000)
    }
    
    // MARK: - Custom Preset
    
    func test_should_create_custom_preset() {
        // given
        let sut = ExportPreset(
            name: "My Preset",
            resolution: .custom(width: 1280, height: 720),
            fps: 24,
            bitrate: 5_000_000,
            format: .mp4,
            isBuiltIn: false
        )
        
        // then
        XCTAssertEqual(sut.name, "My Preset")
        XCTAssertFalse(sut.isBuiltIn)
    }
    
    // MARK: - Estimated File Size
    
    func test_should_calculate_estimated_file_size() {
        // given
        let sut = ExportPreset.web
        let durationSeconds: TimeInterval = 60
        
        // when
        let estimatedSize = sut.estimatedFileSize(forDuration: durationSeconds)
        
        // then
        // 8 Mbps * 60 seconds = 480 Mb = 60 MB
        XCTAssertEqual(estimatedSize, 60_000_000, accuracy: 1_000_000)
    }
}

final class ExportErrorTests: XCTestCase {
    
    func test_should_return_correct_description_for_session_not_found() {
        // given
        let sut = ExportError.sessionNotFound
        
        // then
        XCTAssertEqual(sut.errorDescription, "Recording session not found")
    }
    
    func test_should_return_correct_description_for_export_failed() {
        // given
        let sut = ExportError.exportFailed(reason: "Disk full")
        
        // then
        XCTAssertEqual(sut.errorDescription, "Export failed: Disk full")
    }
    
    func test_should_return_correct_description_for_cancelled() {
        // given
        let sut = ExportError.cancelled
        
        // then
        XCTAssertEqual(sut.errorDescription, "Export was cancelled")
    }
}
