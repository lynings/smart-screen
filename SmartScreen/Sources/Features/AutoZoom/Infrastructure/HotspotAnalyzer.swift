import Foundation

/// Analyzes cursor track sessions to identify click hotspots and generate zoom segments
final class HotspotAnalyzer {
    
    // MARK: - Constants
    
    /// Minimum time between clicks to be considered separate hotspots (seconds)
    private let mergeThreshold: TimeInterval = 1.0
    
    /// Time before click to start zoom (anticipation)
    private let anticipationTime: TimeInterval = 0.2
    
    // MARK: - Analysis
    
    /// Analyze a cursor track session and generate zoom segments
    func analyze(session: CursorTrackSession, settings: AutoZoomSettings) -> [ZoomSegment] {
        guard settings.isEnabled else { return [] }
        
        // 1. Extract click events only
        let clicks = session.clickEvents
        guard !clicks.isEmpty else { return [] }
        
        // 2. Group nearby clicks into clusters
        let clusters = clusterClicks(clicks)
        
        // 3. Convert clusters to zoom segments
        let segments = clusters.compactMap { cluster in
            createSegment(from: cluster, settings: settings, videoDuration: session.duration)
        }
        
        return segments
    }
    
    // MARK: - Click Clustering
    
    private func clusterClicks(_ clicks: [ClickEvent]) -> [[ClickEvent]] {
        guard !clicks.isEmpty else { return [] }
        
        var clusters: [[ClickEvent]] = []
        var currentCluster: [ClickEvent] = [clicks[0]]
        
        for i in 1..<clicks.count {
            let prevClick = clicks[i - 1]
            let currentClick = clicks[i]
            
            // Check if clicks should be merged (within time threshold)
            if currentClick.timestamp - prevClick.timestamp < mergeThreshold {
                currentCluster.append(currentClick)
            } else {
                clusters.append(currentCluster)
                currentCluster = [currentClick]
            }
        }
        
        // Don't forget the last cluster
        clusters.append(currentCluster)
        
        return clusters
    }
    
    // MARK: - Segment Creation
    
    private func createSegment(
        from cluster: [ClickEvent],
        settings: AutoZoomSettings,
        videoDuration: TimeInterval
    ) -> ZoomSegment? {
        guard let firstClick = cluster.first else { return nil }
        
        // 1. Calculate center point (average of all clicks in cluster)
        let center = calculateCenter(of: cluster)
        
        // 2. Calculate timing
        let clickTime = firstClick.timestamp
        let startTime = max(0, clickTime - anticipationTime)
        
        // Total segment duration = zoomIn + hold + zoomOut
        let totalDuration = settings.duration + settings.holdTime + settings.duration
        var endTime = startTime + totalDuration
        
        // Clamp to video duration
        if endTime > videoDuration {
            endTime = videoDuration
        }
        
        return ZoomSegment(
            startTime: startTime,
            endTime: endTime,
            center: center,
            scale: settings.zoomLevel,
            easing: settings.easing
        )
    }
    
    private func calculateCenter(of cluster: [ClickEvent]) -> CGPoint {
        guard !cluster.isEmpty else { return .zero }
        
        let sumX = cluster.reduce(0.0) { $0 + $1.position.x }
        let sumY = cluster.reduce(0.0) { $0 + $1.position.y }
        
        return CGPoint(
            x: sumX / CGFloat(cluster.count),
            y: sumY / CGFloat(cluster.count)
        )
    }
}
