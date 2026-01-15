import Foundation
import CoreGraphics

/// Aggregates unified events into scored attention points (merge/debounce).
struct EventAggregator {
    
    struct Config: Equatable {
        let mergeTime: TimeInterval
        let mergeDistancePixels: CGFloat
        
        static let `default` = Config(mergeTime: 0.35, mergeDistancePixels: 120)
    }
    
    private let config: Config
    private let scorer: AttentionScorer
    
    init(config: Config = .default, scorer: AttentionScorer = AttentionScorer()) {
        self.config = config
        self.scorer = scorer
    }
    
    func aggregate(events: [UnifiedEvent], referenceSize: CGSize) -> [AttentionPoint] {
        guard !events.isEmpty else { return [] }
        
        // Strategy B v1: only aggregate click-derived attention points here.
        let clicks = events.compactMap { event -> ClickEvent? in
            guard case .click(let click) = event else { return nil }
            return click
        }.sorted { $0.timestamp < $1.timestamp }
        
        guard !clicks.isEmpty else { return [] }
        
        let maxDimension = max(referenceSize.width, referenceSize.height)
        let mergeDistanceNormalized = maxDimension > 0 ? (config.mergeDistancePixels / maxDimension) : 0
        
        var result: [AttentionPoint] = []
        var group: [ClickEvent] = [clicks[0]]
        
        for i in 1..<clicks.count {
            let current = clicks[i]
            let previous = group.last!
            
            let dt = current.timestamp - previous.timestamp
            let distance = hypot(current.position.x - previous.position.x, current.position.y - previous.position.y)
            
            if dt < config.mergeTime && distance < mergeDistanceNormalized {
                group.append(current)
            } else {
                if let point = mergeClickGroup(group) { result.append(point) }
                group = [current]
            }
        }
        
        if let point = mergeClickGroup(group) { result.append(point) }
        return result
    }
    
    private func mergeClickGroup(_ group: [ClickEvent]) -> AttentionPoint? {
        guard let first = group.first else { return nil }
        let centroid = group
            .map(\.position)
            .reduce(CGPoint.zero) { partial, p in
                CGPoint(x: partial.x + p.x, y: partial.y + p.y)
            }
        
        let count = CGFloat(group.count)
        let position = CGPoint(x: centroid.x / count, y: centroid.y / count)
        let score = scorer.eventWeight(for: .click(first))
        
        return AttentionPoint(
            time: first.timestamp,
            position: position,
            score: score,
            isHardTrigger: true
        )
    }
}

