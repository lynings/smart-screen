import Foundation
import CoreGraphics

/// Detected click intent representing user's intended action
enum ClickIntent: Equatable {
    /// Single isolated click - standard zoom behavior
    case singleClick(position: CGPoint)
    
    /// Rapid consecutive clicks in the same area - merge and extend hold
    case rapidClicksSameArea(centroid: CGPoint, clickCount: Int)
    
    /// Rapid consecutive clicks in different areas - smooth pan between
    case rapidClicksDifferentAreas(positions: [CGPoint])
    
    /// Click followed by immediate movement - enter follow mode
    case clickThenMove(clickPosition: CGPoint, moveDirection: CGPoint)
    
    /// Double click - potential zoom level change
    case doubleClick(position: CGPoint)
    
    var primaryPosition: CGPoint {
        switch self {
        case .singleClick(let position):
            return position
        case .rapidClicksSameArea(let centroid, _):
            return centroid
        case .rapidClicksDifferentAreas(let positions):
            return positions.last ?? .zero
        case .clickThenMove(let clickPosition, _):
            return clickPosition
        case .doubleClick(let position):
            return position
        }
    }
}

/// Configuration for click intent detection
struct ClickIntentConfig {
    /// Maximum time between clicks to consider as rapid (seconds)
    let rapidClickWindow: TimeInterval
    
    /// Maximum distance (normalized) to consider clicks as "same area"
    let sameAreaThreshold: CGFloat
    
    /// Maximum time for double-click detection (seconds)
    let doubleClickWindow: TimeInterval
    
    /// Minimum movement distance (normalized) to trigger follow mode
    let followModeMovementThreshold: CGFloat
    
    /// Time window to detect movement after click (seconds)
    let followModeDetectionWindow: TimeInterval
    
    static let `default` = ClickIntentConfig(
        rapidClickWindow: 0.5,
        sameAreaThreshold: 0.15,
        doubleClickWindow: 0.3,
        followModeMovementThreshold: 0.05,
        followModeDetectionWindow: 0.3
    )
}

/// Analyzes click patterns to determine user intent
final class ClickIntentDetector {
    
    // MARK: - Properties
    
    private let config: ClickIntentConfig
    private var recentClicks: [ClickEvent] = []
    private var recentMoves: [MouseEvent] = []
    private let maxHistoryDuration: TimeInterval = 2.0
    
    // MARK: - Initialization
    
    init(config: ClickIntentConfig = .default) {
        self.config = config
    }
    
    // MARK: - Intent Detection
    
    /// Analyze a click event in context and determine intent
    func detectIntent(
        for click: ClickEvent,
        recentClicks: [ClickEvent],
        recentMoves: [MouseEvent] = []
    ) -> ClickIntent {
        
        // 1. Check for double-click
        if let doubleClickIntent = detectDoubleClick(click, recentClicks: recentClicks) {
            return doubleClickIntent
        }
        
        // 2. Check for click-then-move pattern
        if let followIntent = detectClickThenMove(click, recentMoves: recentMoves) {
            return followIntent
        }
        
        // 3. Check for rapid clicks pattern
        if let rapidClickIntent = detectRapidClicks(click, recentClicks: recentClicks) {
            return rapidClickIntent
        }
        
        // 4. Default: single isolated click
        return .singleClick(position: click.position)
    }
    
    /// Analyze a batch of clicks and detect intentions
    func analyzeClickSequence(_ clicks: [ClickEvent], moves: [MouseEvent] = []) -> [ClickIntent] {
        guard !clicks.isEmpty else { return [] }
        
        var intents: [ClickIntent] = []
        var processedIndices: Set<Int> = []
        
        for (index, click) in clicks.enumerated() {
            guard !processedIndices.contains(index) else { continue }
            
            let precedingClicks = Array(clicks[0..<index])
            let relevantMoves = moves.filter { $0.timestamp > click.timestamp && 
                                               $0.timestamp < click.timestamp + config.followModeDetectionWindow }
            
            let intent = detectIntent(for: click, recentClicks: precedingClicks, recentMoves: relevantMoves)
            
            // Mark processed indices for rapid clicks
            if case .rapidClicksSameArea(_, let count) = intent, count > 1 {
                for i in max(0, index - count + 1)...index {
                    processedIndices.insert(i)
                }
            } else if case .rapidClicksDifferentAreas(let positions) = intent, positions.count > 1 {
                for i in max(0, index - positions.count + 1)...index {
                    processedIndices.insert(i)
                }
            } else if case .doubleClick = intent {
                if index > 0 {
                    processedIndices.insert(index - 1)
                }
                processedIndices.insert(index)
            } else {
                processedIndices.insert(index)
            }
            
            intents.append(intent)
        }
        
        return intents
    }
    
    // MARK: - Private Detection Methods
    
    private func detectDoubleClick(_ click: ClickEvent, recentClicks: [ClickEvent]) -> ClickIntent? {
        guard let lastClick = recentClicks.last else { return nil }
        
        let timeDelta = click.timestamp - lastClick.timestamp
        let distance = hypot(click.position.x - lastClick.position.x, 
                            click.position.y - lastClick.position.y)
        
        // Double-click: same position, within time window
        if timeDelta < config.doubleClickWindow && distance < config.sameAreaThreshold * 0.5 {
            let centroid = CGPoint(
                x: (click.position.x + lastClick.position.x) / 2,
                y: (click.position.y + lastClick.position.y) / 2
            )
            return .doubleClick(position: centroid)
        }
        
        return nil
    }
    
    private func detectClickThenMove(_ click: ClickEvent, recentMoves: [MouseEvent]) -> ClickIntent? {
        // Look for significant movement shortly after the click
        let movesAfterClick = recentMoves.filter { 
            $0.timestamp > click.timestamp && 
            $0.timestamp < click.timestamp + config.followModeDetectionWindow 
        }
        
        guard !movesAfterClick.isEmpty else { return nil }
        
        // Find the first significant movement
        for move in movesAfterClick {
            let distance = hypot(move.position.x - click.position.x, 
                               move.position.y - click.position.y)
            
            if distance >= config.followModeMovementThreshold {
                let direction = CGPoint(
                    x: move.position.x - click.position.x,
                    y: move.position.y - click.position.y
                )
                return .clickThenMove(clickPosition: click.position, moveDirection: direction)
            }
        }
        
        return nil
    }
    
    private func detectRapidClicks(_ click: ClickEvent, recentClicks: [ClickEvent]) -> ClickIntent? {
        // Find all clicks within the rapid click window
        let rapidClicks = recentClicks.filter { 
            click.timestamp - $0.timestamp < config.rapidClickWindow 
        }
        
        guard !rapidClicks.isEmpty else { return nil }
        
        let allClicks = rapidClicks + [click]
        
        // Calculate centroid and spread
        let centroid = calculateCentroid(allClicks.map { $0.position })
        let maxDistanceFromCentroid = allClicks.map { 
            hypot($0.position.x - centroid.x, $0.position.y - centroid.y) 
        }.max() ?? 0
        
        if maxDistanceFromCentroid < config.sameAreaThreshold {
            // All clicks in same area - merge them
            return .rapidClicksSameArea(centroid: centroid, clickCount: allClicks.count)
        } else {
            // Clicks in different areas - track all positions
            return .rapidClicksDifferentAreas(positions: allClicks.map { $0.position })
        }
    }
    
    private func calculateCentroid(_ positions: [CGPoint]) -> CGPoint {
        guard !positions.isEmpty else { return .zero }
        
        let sum = positions.reduce(CGPoint.zero) { 
            CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) 
        }
        
        return CGPoint(
            x: sum.x / CGFloat(positions.count),
            y: sum.y / CGFloat(positions.count)
        )
    }
    
    // MARK: - State Management
    
    /// Reset detector state
    func reset() {
        recentClicks.removeAll()
        recentMoves.removeAll()
    }
    
    /// Add a click event to history
    func recordClick(_ click: ClickEvent) {
        recentClicks.append(click)
        pruneOldEvents()
    }
    
    /// Add a move event to history
    func recordMove(_ move: MouseEvent) {
        recentMoves.append(move)
        pruneOldEvents()
    }
    
    private func pruneOldEvents() {
        let cutoffTime = Date().timeIntervalSinceReferenceDate - maxHistoryDuration
        recentClicks.removeAll { $0.timestamp < cutoffTime }
        recentMoves.removeAll { $0.timestamp < cutoffTime }
    }
}

// MARK: - Intent to Behavior Mapping

extension ClickIntent {
    
    /// Suggested hold duration multiplier based on intent
    var holdDurationMultiplier: CGFloat {
        switch self {
        case .singleClick:
            return 1.0
        case .rapidClicksSameArea(_, let count):
            return min(2.0, 1.0 + CGFloat(count - 1) * 0.3)
        case .rapidClicksDifferentAreas:
            return 0.8  // Shorter hold for panning
        case .clickThenMove:
            return 0.5  // Enter follow mode quickly
        case .doubleClick:
            return 1.5  // Longer hold for emphasis
        }
    }
    
    /// Whether this intent should trigger follow mode
    var shouldEnterFollowMode: Bool {
        if case .clickThenMove = self {
            return true
        }
        return false
    }
    
    /// Whether this intent represents grouped clicks
    var isGroupedClick: Bool {
        switch self {
        case .rapidClicksSameArea, .rapidClicksDifferentAreas, .doubleClick:
            return true
        default:
            return false
        }
    }
}
