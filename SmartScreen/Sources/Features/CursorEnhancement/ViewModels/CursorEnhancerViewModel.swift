import Foundation
import Observation

@Observable
@MainActor
final class CursorEnhancerViewModel {
    
    // MARK: - Dependencies
    
    private let smoother: CursorSmoother
    private let highlighter: ClickHighlighter
    
    // MARK: - State
    
    var smoothingLevel: SmoothingLevel {
        didSet { smoother.setLevel(smoothingLevel) }
    }
    
    var highlightEnabled: Bool
    
    private(set) var activeHighlights: [HighlightAnimation] = []
    
    // MARK: - Initialization
    
    init(
        smoothingLevel: SmoothingLevel = .medium,
        highlightEnabled: Bool = true
    ) {
        self.smoothingLevel = smoothingLevel
        self.highlightEnabled = highlightEnabled
        self.smoother = CursorSmoother(level: smoothingLevel)
        self.highlighter = ClickHighlighter()
    }
    
    // MARK: - Actions
    
    func handleClick(_ event: ClickEvent) {
        guard highlightEnabled else { return }
        
        let animation = highlighter.generateHighlight(for: event)
        activeHighlights.append(animation)
        
        // Schedule removal after animation completes
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(animation.duration))
            removeHighlight(animation)
        }
    }
    
    func processPositions(_ positions: [CursorPoint]) -> [CursorPoint] {
        smoother.smooth(positions)
    }
    
    func clearHighlights() {
        activeHighlights.removeAll()
    }
    
    // MARK: - Private Helpers
    
    private func removeHighlight(_ animation: HighlightAnimation) {
        activeHighlights.removeAll { $0 == animation }
    }
}
