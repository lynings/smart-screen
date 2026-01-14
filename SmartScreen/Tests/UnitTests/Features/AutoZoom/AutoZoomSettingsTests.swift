import XCTest
@testable import SmartScreen

final class AutoZoomSettingsTests: XCTestCase {
    
    // MARK: - Default Values
    
    func test_should_create_settings_with_defaults() {
        // given/when
        let settings = AutoZoomSettings()
        
        // then
        XCTAssertTrue(settings.isEnabled)
        XCTAssertEqual(settings.zoomLevel, 2.0)
        XCTAssertEqual(settings.duration, 1.2)
        XCTAssertEqual(settings.holdTime, 0.6, accuracy: 0.001) // 50% of duration
        XCTAssertEqual(settings.easing, .easeInOut)
    }
    
    // MARK: - Custom Values
    
    func test_should_create_settings_with_custom_values() {
        // given/when
        let settings = AutoZoomSettings(
            isEnabled: false,
            zoomLevel: 2.5,
            duration: 1.5,
            easing: .linear
        )
        
        // then
        XCTAssertFalse(settings.isEnabled)
        XCTAssertEqual(settings.zoomLevel, 2.5)
        XCTAssertEqual(settings.duration, 1.5)
        XCTAssertEqual(settings.holdTime, 0.75, accuracy: 0.001) // 50% of 1.5
        XCTAssertEqual(settings.easing, .linear)
    }
    
    // MARK: - Validation
    
    func test_should_clamp_zoom_level_to_minimum() {
        // given/when
        let settings = AutoZoomSettings(zoomLevel: 0.5)
        
        // then
        XCTAssertEqual(settings.zoomLevel, 1.0)
    }
    
    func test_should_clamp_zoom_level_to_maximum() {
        // given/when
        let settings = AutoZoomSettings(zoomLevel: 10.0)
        
        // then
        XCTAssertEqual(settings.zoomLevel, 6.0)
    }
    
    func test_should_clamp_duration_to_minimum() {
        // given/when
        let settings = AutoZoomSettings(duration: 0.1)
        
        // then
        XCTAssertEqual(settings.duration, 0.6)
    }
    
    func test_should_clamp_duration_to_maximum() {
        // given/when
        let settings = AutoZoomSettings(duration: 5.0)
        
        // then
        XCTAssertEqual(settings.duration, 3.0)
    }
    
    // MARK: - Presets
    
    func test_should_have_subtle_preset() {
        // given/when
        let settings = AutoZoomSettings.subtle
        
        // then
        XCTAssertEqual(settings.zoomLevel, 1.5)
        XCTAssertEqual(settings.duration, 1.0)
    }
    
    func test_should_have_normal_preset() {
        // given/when
        let settings = AutoZoomSettings.normal
        
        // then
        XCTAssertEqual(settings.zoomLevel, 2.0)
        XCTAssertEqual(settings.duration, 1.2)
    }
    
    func test_should_have_dramatic_preset() {
        // given/when
        let settings = AutoZoomSettings.dramatic
        
        // then
        XCTAssertEqual(settings.zoomLevel, 2.5)
        XCTAssertEqual(settings.duration, 1.5)
    }
}
