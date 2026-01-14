import Foundation
import CoreGraphics
import SwiftUI

/// Represents an active highlight to be rendered
struct ActiveHighlight {
    let position: CGPoint
    let style: HighlightAnimation.HighlightStyle
    let color: CGColor
    let progress: Double  // 0.0 to 1.0
    
    init(position: CGPoint, style: HighlightAnimation.HighlightStyle, color: Color, progress: Double) {
        self.position = position
        self.style = style
        self.color = NSColor(color).cgColor
        self.progress = progress
    }
    
    init(position: CGPoint, style: HighlightAnimation.HighlightStyle, color: CGColor, progress: Double) {
        self.position = position
        self.style = style
        self.color = color
        self.progress = progress
    }
}

/// Renders click highlights onto video frames using Core Graphics
/// Note: The system cursor is already captured by ScreenCaptureKit (showsCursor = true)
///       This renderer only adds click highlight effects around the existing cursor
final class CursorRenderer {
    
    // MARK: - Properties
    
    let highlightRadius: CGFloat
    
    // MARK: - Initialization
    
    init(highlightRadius: CGFloat = 30) {
        self.highlightRadius = highlightRadius
    }
    
    // MARK: - Frame Rendering
    
    /// Render click highlights onto a video frame
    /// - Parameters:
    ///   - source: Source video frame (already contains system cursor)
    ///   - highlights: Active click highlight animations to draw
    ///   - highlightScale: Scale factor for highlight size (AC-CE-01), default 1.0
    /// - Returns: Enhanced frame with click highlights, or original frame if no highlights
    func renderFrame(
        source: CGImage?,
        highlights: [ActiveHighlight],
        highlightScale: CGFloat = 1.0
    ) -> CGImage? {
        guard let source else { return nil }
        
        // No highlights to draw, return original frame
        if highlights.isEmpty {
            return source
        }
        
        let width = source.width
        let height = source.height
        
        guard let context = createContext(width: width, height: height) else {
            return source
        }
        
        // 1. Draw source image (already contains system cursor)
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // 2. Draw click highlights around cursor position with optional scaling
        let scaledRadius = highlightRadius * highlightScale
        for highlight in highlights {
            drawHighlight(
                in: context,
                at: highlight.position,
                style: highlight.style,
                color: highlight.color,
                progress: highlight.progress,
                radius: scaledRadius
            )
        }
        
        return context.makeImage()
    }
    
    // MARK: - Highlight Drawing
    
    func drawHighlight(
        in context: CGContext,
        at position: CGPoint,
        style: HighlightAnimation.HighlightStyle,
        color: CGColor,
        progress: Double,
        radius: CGFloat? = nil
    ) {
        context.saveGState()
        
        // Calculate animation values
        let scale = 0.5 + progress * 1.5  // Expand from 50% to 200%
        let opacity = 1.0 - progress      // Fade out
        
        let baseRadius = radius ?? highlightRadius
        let currentRadius = baseRadius * scale
        
        // Extract color components
        let components = color.components ?? [0, 0, 1, 1]
        let red = components.count > 0 ? components[0] : 0
        let green = components.count > 1 ? components[1] : 0
        let blue = components.count > 2 ? components[2] : 0
        
        // Draw primary ring
        let ringColor = CGColor(
            red: red,
            green: green,
            blue: blue,
            alpha: opacity * 0.8
        )
        
        context.setStrokeColor(ringColor)
        context.setLineWidth(3.0)
        context.addEllipse(in: CGRect(
            x: position.x - currentRadius,
            y: position.y - currentRadius,
            width: currentRadius * 2,
            height: currentRadius * 2
        ))
        context.strokePath()
        
        // Draw center dot
        let dotRadius: CGFloat = 4
        let dotColor = CGColor(
            red: red,
            green: green,
            blue: blue,
            alpha: opacity * 0.5
        )
        context.setFillColor(dotColor)
        context.fillEllipse(in: CGRect(
            x: position.x - dotRadius,
            y: position.y - dotRadius,
            width: dotRadius * 2,
            height: dotRadius * 2
        ))
        
        // Draw secondary ring for double-click style
        if style == .doubleRing {
            let outerRadius = currentRadius * 1.5
            let outerColor = CGColor(
                red: red,
                green: green,
                blue: blue,
                alpha: opacity * 0.5
            )
            
            context.setStrokeColor(outerColor)
            context.setLineWidth(2.0)
            context.addEllipse(in: CGRect(
                x: position.x - outerRadius,
                y: position.y - outerRadius,
                width: outerRadius * 2,
                height: outerRadius * 2
            ))
            context.strokePath()
        }
        
        context.restoreGState()
    }
    
    // MARK: - Private Helpers
    
    private func createContext(width: Int, height: Int) -> CGContext? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        return CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }
}
