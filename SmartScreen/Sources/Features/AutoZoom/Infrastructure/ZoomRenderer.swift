import Foundation
import CoreGraphics

/// Renders zoomed video frames using Core Graphics
final class ZoomRenderer {
    
    // MARK: - Frame Rendering
    
    /// Render a zoomed frame
    /// - Parameters:
    ///   - source: Source image to zoom
    ///   - scale: Zoom scale (1.0 = no zoom, 2.0 = 2x zoom)
    ///   - center: Center point of zoom (normalized 0-1)
    ///   - outputSize: Output image size
    /// - Returns: Zoomed and cropped image, or nil if source is nil
    func renderFrame(
        source: CGImage?,
        scale: CGFloat,
        center: CGPoint,
        outputSize: CGSize
    ) -> CGImage? {
        guard let source else { return nil }
        
        let sourceSize = CGSize(width: source.width, height: source.height)
        let effectiveScale = max(1.0, scale)
        
        // Fast path: identical size + no zoom
        if effectiveScale == 1.0, outputSize == sourceSize {
            return source
        }
        
        // 1. Calculate crop rectangle
        let cropRect = calculateCropRect(
            scale: effectiveScale,
            center: center,
            sourceSize: sourceSize,
            outputSize: outputSize
        )
        
        // 2. Crop the source image
        guard let croppedImage = source.cropping(to: cropRect) else {
            return source
        }
        
        // 3. Scale cropped image to output size
        return scaleImage(croppedImage, to: outputSize)
    }
    
    // MARK: - Crop Calculation
    
    /// Calculate the crop rectangle for a given zoom level and center
    /// - Parameters:
    ///   - scale: Zoom scale (> 1.0)
    ///   - center: Center point of zoom (normalized 0-1, Y=0 is top)
    ///   - sourceSize: Size of source image
    /// - Returns: Rectangle to crop from source image
    func calculateCropRect(
        scale: CGFloat,
        center: CGPoint,
        sourceSize: CGSize,
        outputSize: CGSize
    ) -> CGRect {
        // At scale X, we show ~1/X of the image on the limiting dimension,
        // while preserving output aspect ratio to avoid stretching.
        let outputAspect = outputSize.height > 0 ? (outputSize.width / outputSize.height) : (sourceSize.width / max(1, sourceSize.height))
        
        // Confirmed visible extents at this scale
        let maxCropWidth = sourceSize.width / scale
        let maxCropHeight = sourceSize.height / scale
        
        // Start by fitting width, then clamp to height if needed.
        var cropWidth = maxCropWidth
        var cropHeight = cropWidth / outputAspect
        if cropHeight > maxCropHeight {
            cropHeight = maxCropHeight
            cropWidth = cropHeight * outputAspect
        }
        
        // Calculate center in pixel coordinates
        // Note: CGImage Y-axis is bottom-to-top, but our normalized coords are top-to-bottom
        // So we flip Y: normalizedY=0 (top) → pixelY=height, normalizedY=1 (bottom) → pixelY=0
        let centerX = clamp(center.x, 0, 1) * sourceSize.width
        let centerY = (1.0 - clamp(center.y, 0, 1)) * sourceSize.height
        
        // Calculate origin (bottom-left of crop rect in CGImage coordinates)
        var originX = centerX - cropWidth / 2
        var originY = centerY - cropHeight / 2
        
        // Clamp to source bounds
        originX = clamp(originX, 0, sourceSize.width - cropWidth)
        originY = clamp(originY, 0, sourceSize.height - cropHeight)
        
        return CGRect(
            x: originX,
            y: originY,
            width: cropWidth,
            height: cropHeight
        )
    }

    // Backwards-compatible overload (used by existing tests)
    func calculateCropRect(
        scale: CGFloat,
        center: CGPoint,
        sourceSize: CGSize
    ) -> CGRect {
        calculateCropRect(scale: scale, center: center, sourceSize: sourceSize, outputSize: sourceSize)
    }
    
    // MARK: - Image Scaling
    
    private func scaleImage(_ source: CGImage, to size: CGSize) -> CGImage? {
        let width = Int(size.width)
        let height = Int(size.height)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        // Use high quality interpolation
        context.interpolationQuality = .high
        
        // Draw scaled image
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return context.makeImage()
    }
    
    // MARK: - Helpers
    
    private func clamp(_ value: CGFloat, _ minValue: CGFloat, _ maxValue: CGFloat) -> CGFloat {
        min(max(value, minValue), maxValue)
    }
}
