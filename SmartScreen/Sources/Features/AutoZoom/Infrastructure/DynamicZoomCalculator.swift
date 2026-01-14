import Foundation
import CoreGraphics

/// Calculates dynamic zoom scale based on screen position
/// Edge/corner positions get larger zoom, center positions get smaller zoom
struct DynamicZoomCalculator {
    
    // MARK: - Configuration
    
    /// Base zoom scale (e.g., 2.0x)
    let baseScale: CGFloat
    
    /// Minimum scale factor (applied at center)
    let minScaleFactor: CGFloat
    
    /// Maximum scale factor (applied at corners)
    let maxScaleFactor: CGFloat
    
    // MARK: - Initialization
    
    init(
        baseScale: CGFloat = 2.0,
        minScaleFactor: CGFloat = 0.85,
        maxScaleFactor: CGFloat = 1.25
    ) {
        self.baseScale = baseScale
        self.minScaleFactor = minScaleFactor
        self.maxScaleFactor = maxScaleFactor
    }
    
    // MARK: - Calculation
    
    /// Calculate dynamic zoom scale based on position
    /// - Parameter position: Normalized position (0-1)
    /// - Returns: Adjusted zoom scale
    func zoomScale(at position: CGPoint) -> CGFloat {
        // 1. Calculate distance to nearest edge (0 at edge, 0.5 at center)
        let edgeDistanceX = min(position.x, 1.0 - position.x)
        let edgeDistanceY = min(position.y, 1.0 - position.y)
        let minEdgeDistance = min(edgeDistanceX, edgeDistanceY)
        
        // 2. Normalize to 0-1 range (0 at edge, 1 at center)
        let normalizedDistance = minEdgeDistance / 0.5
        
        // 3. Calculate scale factor (larger at edges, smaller at center)
        // Using inverse relationship: closer to edge = higher factor
        let scaleFactor = maxScaleFactor - (maxScaleFactor - minScaleFactor) * normalizedDistance
        
        // 4. Apply to base scale
        return baseScale * scaleFactor
    }
    
    /// Calculate zoom scale with corner boost
    /// Corners get extra zoom since they have the smallest visible area
    func zoomScaleWithCornerBoost(at position: CGPoint) -> CGFloat {
        let baseZoom = zoomScale(at: position)
        
        // Check if position is in a corner (both x and y near edges)
        let isNearCorner = isCornerPosition(position)
        
        if isNearCorner {
            // Apply additional 10% boost for corners
            return baseZoom * 1.1
        }
        
        return baseZoom
    }
    
    /// Check if position is near a corner
    func isCornerPosition(_ position: CGPoint, threshold: CGFloat = 0.2) -> Bool {
        let isNearHorizontalEdge = position.x < threshold || position.x > (1.0 - threshold)
        let isNearVerticalEdge = position.y < threshold || position.y > (1.0 - threshold)
        return isNearHorizontalEdge && isNearVerticalEdge
    }
    
    /// Check if position is near any edge
    func isEdgePosition(_ position: CGPoint, threshold: CGFloat = 0.15) -> Bool {
        return position.x < threshold ||
               position.x > (1.0 - threshold) ||
               position.y < threshold ||
               position.y > (1.0 - threshold)
    }
}
