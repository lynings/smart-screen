import Foundation

/// Represents a keyboard event during recording
struct KeyboardEvent: Codable, Equatable {
    let timestamp: TimeInterval
    let keyCode: UInt16
    let isModifier: Bool
    
    /// Check if this is a modifier key (Shift, Control, Option, Command)
    static func isModifierKey(_ keyCode: UInt16) -> Bool {
        // Common modifier key codes
        let modifierKeyCodes: Set<UInt16> = [
            54, 55,  // Command
            56, 60,  // Shift
            58, 61,  // Option
            59, 62,  // Control
            63,      // Fn
            57       // Caps Lock
        ]
        return modifierKeyCodes.contains(keyCode)
    }
    
    init(timestamp: TimeInterval, keyCode: UInt16) {
        self.timestamp = timestamp
        self.keyCode = keyCode
        self.isModifier = Self.isModifierKey(keyCode)
    }
}
