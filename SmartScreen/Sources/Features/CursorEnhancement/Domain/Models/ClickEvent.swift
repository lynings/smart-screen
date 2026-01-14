import Foundation
import SwiftUI

/// Type of mouse click
enum ClickType: String, Equatable {
    case leftClick
    case doubleClick
    case rightClick
    
    var highlightColor: Color {
        switch self {
        case .leftClick, .doubleClick: return .blue
        case .rightClick: return .orange
        }
    }
    
    var animationDuration: TimeInterval {
        switch self {
        case .leftClick: return 0.3
        case .doubleClick: return 0.4
        case .rightClick: return 0.3
        }
    }
}

/// Represents a mouse click event
struct ClickEvent: Equatable {
    let type: ClickType
    let position: CGPoint
    let timestamp: TimeInterval
}
