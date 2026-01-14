import Foundation
import SwiftUI

/// Protocol for cursor trajectory enhancement
protocol CursorEnhancerProtocol {
    var smoothingLevel: SmoothingLevel { get set }
    var highlightEnabled: Bool { get set }
    
    /// Smooth a trajectory of cursor points
    func smooth(_ points: [CursorPoint]) -> [CursorPoint]
    
    /// Generate highlight animation data for a click event
    func generateHighlight(for event: ClickEvent) -> HighlightAnimation
}

/// Animation data for click highlight
struct HighlightAnimation: Equatable {
    let position: CGPoint
    let color: Color
    let duration: TimeInterval
    let style: HighlightStyle
    
    enum HighlightStyle: Equatable {
        case pulse       // Single expanding ring
        case doubleRing  // Two expanding rings
    }
}
