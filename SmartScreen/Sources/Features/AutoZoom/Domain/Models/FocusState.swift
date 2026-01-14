import Foundation

/// Current state of focus/zoom for a video frame
struct FocusState: Equatable {
    
    // MARK: - Properties
    
    /// Current focus center (normalized 0-1)
    let center: CGPoint
    
    /// Current zoom scale (1.0 = no zoom)
    let scale: CGFloat
    
    // MARK: - Computed Properties
    
    /// Visible rectangle in normalized coordinates
    var visibleRect: CGRect {
        let width = 1.0 / scale
        let height = 1.0 / scale
        let x = center.x - width / 2
        let y = center.y - height / 2
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    // MARK: - Boundary Checks
    
    /// Check if cursor is within visible bounds with margin
    func cursorInBounds(_ cursor: CGPoint, margin: CGFloat) -> Bool {
        let rect = visibleRect
        let insetRect = rect.insetBy(dx: rect.width * margin, dy: rect.height * margin)
        return insetRect.contains(cursor)
    }
    
    /// Calculate adjusted center to keep cursor in bounds
    func adjustedCenter(forCursor cursor: CGPoint, margin: CGFloat) -> CGPoint {
        let halfWidth = (1.0 / scale) / 2
        let halfHeight = (1.0 / scale) / 2
        let effectiveMargin = margin * (1.0 / scale)
        
        var newCenter = center
        
        // Adjust X
        let minX = cursor.x - halfWidth + effectiveMargin
        let maxX = cursor.x + halfWidth - effectiveMargin
        if center.x < minX {
            newCenter.x = minX
        } else if center.x > maxX {
            newCenter.x = maxX
        }
        
        // Adjust Y
        let minY = cursor.y - halfHeight + effectiveMargin
        let maxY = cursor.y + halfHeight - effectiveMargin
        if center.y < minY {
            newCenter.y = minY
        } else if center.y > maxY {
            newCenter.y = maxY
        }
        
        // Clamp to valid range (center must keep visible rect in bounds)
        newCenter.x = max(halfWidth, min(1.0 - halfWidth, newCenter.x))
        newCenter.y = max(halfHeight, min(1.0 - halfHeight, newCenter.y))
        
        return newCenter
    }
    
    // MARK: - Factory
    
    /// Default state (no zoom, centered)
    static let `default` = FocusState(center: CGPoint(x: 0.5, y: 0.5), scale: 1.0)
    
    /// Create from keyframe
    static func from(_ keyframe: FocusKeyframe) -> FocusState {
        FocusState(center: keyframe.center, scale: keyframe.scale)
    }
}
