import XCTest
import CoreGraphics
@testable import SmartScreen

final class ZoomRendererTests: XCTestCase {
    
    // MARK: - No Zoom
    
    func test_should_return_original_frame_when_scale_is_1() {
        // given
        let renderer = ZoomRenderer()
        let sourceImage = createTestImage(width: 100, height: 100)
        
        // when
        let result = renderer.renderFrame(
            source: sourceImage,
            scale: 1.0,
            center: CGPoint(x: 0.5, y: 0.5),
            outputSize: CGSize(width: 100, height: 100)
        )
        
        // then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.width, 100)
        XCTAssertEqual(result?.height, 100)
    }
    
    // MARK: - Zoom Applied
    
    func test_should_return_zoomed_frame_when_scale_greater_than_1() {
        // given
        let renderer = ZoomRenderer()
        let sourceImage = createTestImage(width: 200, height: 200)
        
        // when
        let result = renderer.renderFrame(
            source: sourceImage,
            scale: 2.0,
            center: CGPoint(x: 0.5, y: 0.5),
            outputSize: CGSize(width: 200, height: 200)
        )
        
        // then
        XCTAssertNotNil(result)
        // Output should be same size as source (zoomed and cropped)
        XCTAssertEqual(result?.width, 200)
        XCTAssertEqual(result?.height, 200)
    }
    
    // MARK: - Nil Input
    
    func test_should_return_nil_for_nil_source() {
        // given
        let renderer = ZoomRenderer()
        
        // when
        let result = renderer.renderFrame(
            source: nil,
            scale: 2.0,
            center: CGPoint(x: 0.5, y: 0.5),
            outputSize: CGSize(width: 100, height: 100)
        )
        
        // then
        XCTAssertNil(result)
    }
    
    // MARK: - Center Point Clamping
    
    func test_should_clamp_center_to_valid_range() {
        // given
        let renderer = ZoomRenderer()
        let sourceImage = createTestImage(width: 100, height: 100)
        
        // when - center outside valid range
        let result = renderer.renderFrame(
            source: sourceImage,
            scale: 2.0,
            center: CGPoint(x: -0.5, y: 1.5),  // Invalid center
            outputSize: CGSize(width: 100, height: 100)
        )
        
        // then - should still render without crash
        XCTAssertNotNil(result)
    }
    
    // MARK: - Crop Rect Calculation
    
    func test_should_calculate_crop_rect_for_center_zoom() {
        // given
        let renderer = ZoomRenderer()
        let sourceSize = CGSize(width: 1920, height: 1080)
        
        // when - 2x zoom at center
        let cropRect = renderer.calculateCropRect(
            scale: 2.0,
            center: CGPoint(x: 0.5, y: 0.5),
            sourceSize: sourceSize
        )
        
        // then - at 2x zoom, we see 1/2 of the image
        // Crop should be centered: 960/2=480 from each edge horizontally
        XCTAssertEqual(cropRect.width, 960, accuracy: 1)
        XCTAssertEqual(cropRect.height, 540, accuracy: 1)
        XCTAssertEqual(cropRect.origin.x, 480, accuracy: 1)
        XCTAssertEqual(cropRect.origin.y, 270, accuracy: 1)
    }
    
    func test_should_calculate_crop_rect_for_top_left_corner_zoom() {
        // given
        let renderer = ZoomRenderer()
        let sourceSize = CGSize(width: 1920, height: 1080)
        
        // when - 2x zoom at top-left corner (y=0 is top in our coordinate system)
        let cropRect = renderer.calculateCropRect(
            scale: 2.0,
            center: CGPoint(x: 0.0, y: 0.0),
            sourceSize: sourceSize
        )
        
        // then - In CGImage, y=0 is bottom, so our top (y=0) maps to CGImage top (y=height)
        // Crop rect should be at x=0, y=540 (top half of image in CGImage coords)
        XCTAssertEqual(cropRect.origin.x, 0, accuracy: 1)
        XCTAssertEqual(cropRect.origin.y, 540, accuracy: 1) // Top half in CGImage
    }
    
    func test_should_calculate_crop_rect_for_bottom_left_corner_zoom() {
        // given
        let renderer = ZoomRenderer()
        let sourceSize = CGSize(width: 1920, height: 1080)
        
        // when - 2x zoom at bottom-left corner (y=1 is bottom in our coordinate system)
        let cropRect = renderer.calculateCropRect(
            scale: 2.0,
            center: CGPoint(x: 0.0, y: 1.0),
            sourceSize: sourceSize
        )
        
        // then - Our bottom (y=1) maps to CGImage bottom (y=0)
        XCTAssertEqual(cropRect.origin.x, 0, accuracy: 1)
        XCTAssertEqual(cropRect.origin.y, 0, accuracy: 1) // Bottom half in CGImage
    }
    
    // MARK: - Helpers
    
    private func createTestImage(width: Int, height: Int) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        
        // Fill with white
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        return context.makeImage()!
    }
}
