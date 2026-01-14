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
        XCTAssertEqual(settings.idleTimeout, 3.0)
        XCTAssertEqual(settings.easing, .easeInOut)
        XCTAssertTrue(settings.dynamicZoomEnabled)
        XCTAssertTrue(settings.zoomOutOnKeyboard)
    }
    
    // MARK: - Custom Values
    
    func test_should_create_settings_with_custom_values() {
        // given/when
        let settings = AutoZoomSettings(
            isEnabled: false,
            zoomLevel: 2.5,
            easing: .linear,
            idleTimeout: 5.0,
            dynamicZoomEnabled: false,
            zoomOutOnKeyboard: false
        )
        
        // then
        XCTAssertFalse(settings.isEnabled)
        XCTAssertEqual(settings.zoomLevel, 2.5)
        XCTAssertEqual(settings.idleTimeout, 5.0)
        XCTAssertEqual(settings.easing, .linear)
        XCTAssertFalse(settings.dynamicZoomEnabled)
        XCTAssertFalse(settings.zoomOutOnKeyboard)
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
    
    func test_should_clamp_idle_timeout_to_minimum() {
        // given/when
        let settings = AutoZoomSettings(idleTimeout: 0.5)
        
        // then
        XCTAssertEqual(settings.idleTimeout, 1.0) // Min is 1.0
    }
    
    func test_should_clamp_idle_timeout_to_maximum() {
        // given/when
        let settings = AutoZoomSettings(idleTimeout: 15.0)
        
        // then
        XCTAssertEqual(settings.idleTimeout, 10.0) // Max is 10.0
    }
    
    // MARK: - Presets
    
    func test_should_have_subtle_preset() {
        // given/when
        let settings = AutoZoomSettings.subtle
        
        // then
        XCTAssertEqual(settings.zoomLevel, 1.5)
        XCTAssertEqual(settings.idleTimeout, 4.0)
    }
    
    func test_should_have_normal_preset() {
        // given/when
        let settings = AutoZoomSettings.normal
        
        // then
        XCTAssertEqual(settings.zoomLevel, 2.0)
        XCTAssertEqual(settings.idleTimeout, 3.0)
    }
    
    func test_should_have_dramatic_preset() {
        // given/when
        let settings = AutoZoomSettings.dramatic
        
        // then
        XCTAssertEqual(settings.zoomLevel, 2.5)
        XCTAssertEqual(settings.idleTimeout, 2.5)
    }
    
    // MARK: - Config Conversion
    
    func test_should_convert_to_continuous_zoom_config() {
        // given
        let settings = AutoZoomSettings(
            zoomLevel: 2.5,
            idleTimeout: 4.0
        )
        
        // when
        let config = settings.toContinuousZoomConfig()
        
        // then
        XCTAssertEqual(config.baseZoomScale, 2.5)
        XCTAssertEqual(config.idleTimeout, 4.0)
    }
}
