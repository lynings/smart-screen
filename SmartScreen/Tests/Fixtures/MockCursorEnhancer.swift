import Foundation
@testable import SmartScreen

final class MockCursorEnhancer: CursorEnhancerProtocol {
    
    // MARK: - State
    
    var smoothingLevel: SmoothingLevel = .medium
    var highlightEnabled: Bool = true
    
    // MARK: - Call Tracking
    
    private(set) var smoothCallCount = 0
    private(set) var lastSmoothedPoints: [CursorPoint] = []
    private(set) var generateHighlightCallCount = 0
    private(set) var lastClickEvent: ClickEvent?
    
    // MARK: - Configurable Results
    
    var smoothResult: [CursorPoint] = []
    var highlightResult = HighlightAnimation(
        position: .zero,
        color: .blue,
        duration: 0.3,
        style: .pulse
    )
    
    // MARK: - Protocol Methods
    
    func smooth(_ points: [CursorPoint]) -> [CursorPoint] {
        smoothCallCount += 1
        lastSmoothedPoints = points
        return smoothResult.isEmpty ? points : smoothResult
    }
    
    func generateHighlight(for event: ClickEvent) -> HighlightAnimation {
        generateHighlightCallCount += 1
        lastClickEvent = event
        return highlightResult
    }
}
