import Foundation

/// A unified event type for Auto Zoom Strategy B.
///
/// Notes:
/// - Positions are normalized (0-1) in the recording coordinate space.
/// - Keyboard events carry keyCode only; context (focus change) is added later.
enum UnifiedEvent: Equatable {
    case click(ClickEvent)
    case move(CursorPoint)
    case keyboard(KeyboardEvent)
    
    var timestamp: TimeInterval {
        switch self {
        case .click(let click): return click.timestamp
        case .move(let point): return point.timestamp
        case .keyboard(let key): return key.timestamp
        }
    }
    
    var position: CGPoint? {
        switch self {
        case .click(let click): return click.position
        case .move(let point): return point.position
        case .keyboard:
            return nil
        }
    }
}

/// A scored attention point on the timeline.
struct AttentionPoint: Equatable {
    let time: TimeInterval
    let position: CGPoint
    let score: Double
    let isHardTrigger: Bool
}

