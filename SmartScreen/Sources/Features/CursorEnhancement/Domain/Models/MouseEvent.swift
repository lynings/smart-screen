import Foundation

/// Type of mouse event
enum MouseEventType: String, Codable, Equatable {
    case move
    case leftClick
    case rightClick
    case doubleClick
}

/// Represents a mouse event with position and timestamp
struct MouseEvent: Codable, Equatable {
    let type: MouseEventType
    let position: CGPoint
    let timestamp: TimeInterval
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case type, x, y, timestamp
    }
    
    init(type: MouseEventType, position: CGPoint, timestamp: TimeInterval) {
        self.type = type
        self.position = position
        self.timestamp = timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(MouseEventType.self, forKey: .type)
        let x = try container.decode(CGFloat.self, forKey: .x)
        let y = try container.decode(CGFloat.self, forKey: .y)
        position = CGPoint(x: x, y: y)
        timestamp = try container.decode(TimeInterval.self, forKey: .timestamp)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(position.x, forKey: .x)
        try container.encode(position.y, forKey: .y)
        try container.encode(timestamp, forKey: .timestamp)
    }
    
    // MARK: - Conversion
    
    func toCursorPoint() -> CursorPoint {
        CursorPoint(position: position, timestamp: timestamp)
    }
    
    func toClickEvent() -> ClickEvent? {
        let clickType: ClickType?
        switch type {
        case .leftClick:
            clickType = .leftClick
        case .rightClick:
            clickType = .rightClick
        case .doubleClick:
            clickType = .doubleClick
        case .move:
            clickType = nil
        }
        
        guard let clickType else { return nil }
        return ClickEvent(type: clickType, position: position, timestamp: timestamp)
    }
}
