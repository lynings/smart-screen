import CoreGraphics

/// Capture source type for screen recording
enum CaptureSource: Equatable {
    case fullScreen(displayID: CGDirectDisplayID)
    case window(windowID: CGWindowID)
    case region(rect: CGRect)
}
