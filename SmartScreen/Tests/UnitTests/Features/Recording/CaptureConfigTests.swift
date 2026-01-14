import XCTest
import CoreGraphics
@testable import SmartScreen

final class CaptureConfigTests: XCTestCase {
    
    // MARK: - CaptureSource
    
    func test_should_create_fullscreen_source_with_display_id() {
        // given
        let displayID: CGDirectDisplayID = 1
        
        // when
        let sut = CaptureSource.fullScreen(displayID: displayID)
        
        // then
        if case .fullScreen(let id) = sut {
            XCTAssertEqual(id, displayID)
        } else {
            XCTFail("Expected fullScreen case")
        }
    }
    
    func test_should_create_window_source_with_window_id() {
        // given
        let windowID: CGWindowID = 123
        
        // when
        let sut = CaptureSource.window(windowID: windowID)
        
        // then
        if case .window(let id) = sut {
            XCTAssertEqual(id, windowID)
        } else {
            XCTFail("Expected window case")
        }
    }
    
    func test_should_create_region_source_with_rect() {
        // given
        let rect = CGRect(x: 0, y: 0, width: 800, height: 600)
        
        // when
        let sut = CaptureSource.region(rect: rect)
        
        // then
        if case .region(let r) = sut {
            XCTAssertEqual(r, rect)
        } else {
            XCTFail("Expected region case")
        }
    }
    
    // MARK: - CaptureConfig
    
    func test_should_create_config_with_default_values() {
        // given
        let source = CaptureSource.fullScreen(displayID: 1)
        
        // when
        let sut = CaptureConfig(source: source)
        
        // then
        XCTAssertEqual(sut.fps, 30)
        XCTAssertEqual(sut.resolution, .p1080)
        XCTAssertNil(sut.audioDevice)
    }
    
    func test_should_create_config_with_custom_values() {
        // given
        let source = CaptureSource.fullScreen(displayID: 1)
        let audioDevice = AudioDevice(id: "test", name: "Test Mic")
        
        // when
        let sut = CaptureConfig(
            source: source,
            audioDevice: audioDevice,
            fps: 60,
            resolution: .p4K
        )
        
        // then
        XCTAssertEqual(sut.fps, 60)
        XCTAssertEqual(sut.resolution, .p4K)
        XCTAssertEqual(sut.audioDevice?.id, "test")
    }
    
    // MARK: - Resolution
    
    func test_should_return_correct_dimensions_for_1080p() {
        // given
        let sut = Resolution.p1080
        
        // when
        let width = sut.width
        let height = sut.height
        
        // then
        XCTAssertEqual(width, 1920)
        XCTAssertEqual(height, 1080)
    }
    
    func test_should_return_correct_dimensions_for_4k() {
        // given
        let sut = Resolution.p4K
        
        // when
        let width = sut.width
        let height = sut.height
        
        // then
        XCTAssertEqual(width, 3840)
        XCTAssertEqual(height, 2160)
    }
}
