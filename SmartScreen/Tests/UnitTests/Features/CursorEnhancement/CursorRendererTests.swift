import XCTest
import CoreGraphics
@testable import SmartScreen

final class CursorRendererTests: XCTestCase {
    
    // MARK: - Initialization
    
    func test_should_create_renderer_with_default_settings() {
        // given/when
        let renderer = CursorRenderer()
        
        // then
        XCTAssertEqual(renderer.highlightRadius, 30)
    }
    
    func test_should_create_renderer_with_custom_settings() {
        // given/when
        let renderer = CursorRenderer(highlightRadius: 40)
        
        // then
        XCTAssertEqual(renderer.highlightRadius, 40)
    }
    
    // MARK: - Highlight Drawing
    
    func test_should_draw_pulse_highlight() {
        // given
        let renderer = CursorRenderer()
        let context = createTestContext(width: 100, height: 100)
        let position = CGPoint(x: 50, y: 50)
        let blueColor = CGColor(red: 0, green: 0, blue: 1, alpha: 1)
        
        // when
        renderer.drawHighlight(in: context, at: position, style: .pulse, color: blueColor, progress: 0.5)
        
        // then
        let image = context.makeImage()
        XCTAssertNotNil(image)
        XCTAssertTrue(hasNonTransparentPixels(in: image!))
    }
    
    func test_should_draw_double_ring_highlight() {
        // given
        let renderer = CursorRenderer()
        let context = createTestContext(width: 100, height: 100)
        let position = CGPoint(x: 50, y: 50)
        let blueColor = CGColor(red: 0, green: 0, blue: 1, alpha: 1)
        
        // when
        renderer.drawHighlight(in: context, at: position, style: .doubleRing, color: blueColor, progress: 0.5)
        
        // then
        let image = context.makeImage()
        XCTAssertNotNil(image)
        XCTAssertTrue(hasNonTransparentPixels(in: image!))
    }
    
    func test_should_fade_highlight_as_progress_increases() {
        // given
        let renderer = CursorRenderer()
        let context1 = createTestContext(width: 100, height: 100)
        let context2 = createTestContext(width: 100, height: 100)
        let position = CGPoint(x: 50, y: 50)
        let blueColor = CGColor(red: 0, green: 0, blue: 1, alpha: 1)
        
        // when
        renderer.drawHighlight(in: context1, at: position, style: .pulse, color: blueColor, progress: 0.1)
        renderer.drawHighlight(in: context2, at: position, style: .pulse, color: blueColor, progress: 0.9)
        
        // then
        let image1 = context1.makeImage()!
        let image2 = context2.makeImage()!
        
        // Higher progress should result in more transparent (faded) highlight
        let alpha1 = maxAlpha(in: image1)
        let alpha2 = maxAlpha(in: image2)
        XCTAssertGreaterThan(alpha1, alpha2)
    }
    
    // MARK: - Frame Rendering
    
    func test_should_render_frame_with_highlights() {
        // given
        let renderer = CursorRenderer()
        let whiteColor = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        let blueColor = CGColor(red: 0, green: 0, blue: 1, alpha: 1)
        let sourceImage = createTestImage(width: 200, height: 200, color: whiteColor)
        let highlights = [
            ActiveHighlight(position: CGPoint(x: 50, y: 50), style: .pulse, color: blueColor, progress: 0.3)
        ]
        
        // when
        let result = renderer.renderFrame(
            source: sourceImage,
            highlights: highlights
        )
        
        // then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.width, sourceImage.width)
        XCTAssertEqual(result?.height, sourceImage.height)
    }
    
    func test_should_return_original_frame_when_no_highlights() {
        // given
        let renderer = CursorRenderer()
        let whiteColor = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        let sourceImage = createTestImage(width: 200, height: 200, color: whiteColor)
        
        // when
        let result = renderer.renderFrame(
            source: sourceImage,
            highlights: []
        )
        
        // then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.width, sourceImage.width)
        XCTAssertEqual(result?.height, sourceImage.height)
    }
    
    func test_should_return_nil_when_source_is_nil() {
        // given
        let renderer = CursorRenderer()
        
        // when
        let result = renderer.renderFrame(
            source: nil,
            highlights: []
        )
        
        // then
        XCTAssertNil(result)
    }
    
    // MARK: - Helpers
    
    private func createTestContext(width: Int, height: Int) -> CGContext {
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
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context
    }
    
    private func createTestImage(width: Int, height: Int, color: CGColor) -> CGImage {
        let context = createTestContext(width: width, height: height)
        context.setFillColor(color)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }
    
    private func hasNonTransparentPixels(in image: CGImage) -> Bool {
        guard let dataProvider = image.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return false
        }
        
        let bytesPerPixel = 4
        let totalPixels = image.width * image.height
        
        for i in 0..<totalPixels {
            let alphaIndex = i * bytesPerPixel + 3
            if bytes[alphaIndex] > 0 {
                return true
            }
        }
        return false
    }
    
    private func maxAlpha(in image: CGImage) -> UInt8 {
        guard let dataProvider = image.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return 0
        }
        
        let bytesPerPixel = 4
        let totalPixels = image.width * image.height
        var maxAlpha: UInt8 = 0
        
        for i in 0..<totalPixels {
            let alphaIndex = i * bytesPerPixel + 3
            maxAlpha = max(maxAlpha, bytes[alphaIndex])
        }
        return maxAlpha
    }
}
