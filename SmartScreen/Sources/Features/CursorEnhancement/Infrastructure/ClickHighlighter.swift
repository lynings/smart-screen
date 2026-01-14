import Foundation
import SwiftUI

/// Generates highlight animations for click events
struct ClickHighlighter {
    
    // MARK: - Properties
    
    var isEnabled: Bool = true
    
    // MARK: - Highlight Generation
    
    func generateHighlight(for event: ClickEvent) -> HighlightAnimation {
        let style: HighlightAnimation.HighlightStyle
        
        switch event.type {
        case .leftClick:
            style = .pulse
        case .doubleClick:
            style = .doubleRing
        case .rightClick:
            style = .pulse
        }
        
        return HighlightAnimation(
            position: event.position,
            color: event.type.highlightColor,
            duration: event.type.animationDuration,
            style: style
        )
    }
}
