import XCTest
@testable import SmartScreen

/// Phase 1 Integration Tests: Attention Score Framework
/// Tests the integration of AttentionScorer, EventAggregator, and updated Config
final class Phase1IntegrationTests: XCTestCase {
    
    // MARK: - should_use_attention_scorer_for_event_filtering
    
    func test_should_use_attention_scorer_for_event_filtering() {
        // given
        var highScorer = AttentionScorer()
        var lowScorer = AttentionScorer()
        
        // High-attention event (click)
        let highAttentionClick = UnifiedEvent.click(
            ClickEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0)
        )
        
        // Low-attention event (small move) - at different location
        let lowAttentionMove = UnifiedEvent.move(
            CursorPoint(position: CGPoint(x: 0.3, y: 0.3), timestamp: 1.1)
        )
        
        // when
        let highRegion = highScorer.addEvent(highAttentionClick)
        let lowRegion = lowScorer.addEvent(lowAttentionMove)
        
        // then
        XCTAssertTrue(highScorer.shouldTriggerZoom(for: highRegion), "High attention should trigger zoom")
        XCTAssertFalse(lowScorer.shouldTriggerZoom(for: lowRegion), "Low attention should not trigger zoom")
    }
    
    // MARK: - should_use_new_config_defaults
    
    func test_should_use_new_config_defaults() {
        // given
        let config = ContinuousZoomConfig.default
        
        // when & then
        XCTAssertEqual(config.clickMergeTime, 0.35, "Should use new merge time")
        XCTAssertEqual(config.clickMergeDistancePixels, 120, "Should use new merge distance")
        XCTAssertEqual(config.holdBase, 0.6, "Should use new base hold duration")
        XCTAssertEqual(config.holdMin, 0.35, "Should have minimum hold duration")
        XCTAssertEqual(config.holdMax, 1.5, "Should have maximum hold duration")
        XCTAssertEqual(config.holdExtensionPerEvent, 0.4, "Should have hold extension per event")
    }
    
    // MARK: - should_integrate_attention_scorer_with_event_aggregator
    
    func test_should_integrate_attention_scorer_with_event_aggregator() {
        // given
        let aggregator = EventAggregator(
            config: EventAggregator.Config.default,
            scorer: AttentionScorer()
        )
        
        // Rapid clicks in same region (should merge)
        let click1 = UnifiedEvent.click(ClickEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0))
        let click2 = UnifiedEvent.click(ClickEvent(type: .leftClick, position: CGPoint(x: 0.52, y: 0.52), timestamp: 1.2))
        let click3 = UnifiedEvent.click(ClickEvent(type: .leftClick, position: CGPoint(x: 0.51, y: 0.51), timestamp: 1.3))
        
        // when
        let points = aggregator.aggregate(
            events: [click1, click2, click3],
            referenceSize: CGSize(width: 1920, height: 1080)
        )
        
        // then
        XCTAssertEqual(points.count, 1, "Rapid nearby clicks should be merged")
        XCTAssertTrue(points[0].isHardTrigger, "Merged click should be hard trigger")
        XCTAssertGreaterThan(points[0].score, 0.5, "Merged click should have high score")
    }
    
    // MARK: - should_apply_attention_decay
    
    func test_should_apply_attention_decay() {
        // given
        var scorer = AttentionScorer()
        let click = UnifiedEvent.click(ClickEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0))
        
        // when
        _ = scorer.addEvent(click)
        let initialRegions = scorer.activeRegions()
        let initialScore = initialRegions[0].score
        
        // Decay by 1 second (tau = 0.7)
        scorer.decayScores(to: 2.0)
        let decayedRegions = scorer.activeRegions()
        let decayedScore = decayedRegions[0].score
        
        // then
        XCTAssertLessThan(decayedScore, initialScore, "Score should decay over time")
        
        let expectedDecay = exp(-1.0 / 0.7) // exp(-dt / tau)
        XCTAssertEqual(decayedScore / initialScore, expectedDecay, accuracy: 0.001)
    }
    
    // MARK: - should_require_confirmation_before_interrupting_hold
    
    func test_should_require_confirmation_before_interrupting_hold() {
        // given
        var scorer = AttentionScorer()
        
        // Establish current region
        let currentClick = UnifiedEvent.click(ClickEvent(type: .leftClick, position: CGPoint(x: 0.3, y: 0.3), timestamp: 1.0))
        let currentRegion = scorer.addEvent(currentClick)
        
        // New medium-distance click
        let newClick = UnifiedEvent.click(ClickEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.1))
        let newRegion = scorer.addEvent(newClick)
        
        let holdStartTime: TimeInterval = 1.0
        
        // when
        let shouldInterruptBefore = scorer.shouldInterruptHold(
            newRegion: newRegion,
            currentRegion: currentRegion,
            holdStartTime: holdStartTime,
            currentTime: 1.15  // 0.05s after new click, before T_confirm (0.18s)
        )
        
        let shouldInterruptAfter = scorer.shouldInterruptHold(
            newRegion: newRegion,
            currentRegion: currentRegion,
            holdStartTime: holdStartTime,
            currentTime: 1.3  // 0.2s after new click, after T_confirm
        )
        
        // then
        XCTAssertFalse(shouldInterruptBefore, "Should not interrupt before T_confirm")
        XCTAssertTrue(shouldInterruptAfter, "Should interrupt after T_confirm")
    }
    
    // MARK: - should_immediately_interrupt_for_large_distance
    
    func test_should_immediately_interrupt_for_large_distance() {
        // given
        var scorer = AttentionScorer()
        
        let currentClick = UnifiedEvent.click(ClickEvent(type: .leftClick, position: CGPoint(x: 0.1, y: 0.1), timestamp: 1.0))
        let currentRegion = scorer.addEvent(currentClick)
        
        // Very large distance click (> 0.6)
        let farClick = UnifiedEvent.click(ClickEvent(type: .leftClick, position: CGPoint(x: 0.9, y: 0.9), timestamp: 1.05))
        let farRegion = scorer.addEvent(farClick)
        
        let holdStartTime: TimeInterval = 1.0
        
        // when
        let shouldInterrupt = scorer.shouldInterruptHold(
            newRegion: farRegion,
            currentRegion: currentRegion,
            holdStartTime: holdStartTime,
            currentTime: 1.06  // Only 0.01s after new click
        )
        
        // then
        XCTAssertTrue(shouldInterrupt, "Large distance should bypass T_confirm and interrupt immediately")
    }
    
    // MARK: - should_merge_events_in_same_attention_region
    
    func test_should_merge_events_in_same_attention_region() {
        // given
        var scorer = AttentionScorer(config: AttentionConfig(mergeRadius: 0.08))
        
        // Multiple clicks in same region
        let click1 = UnifiedEvent.click(ClickEvent(type: .leftClick, position: CGPoint(x: 0.50, y: 0.50), timestamp: 1.0))
        let click2 = UnifiedEvent.click(ClickEvent(type: .leftClick, position: CGPoint(x: 0.52, y: 0.52), timestamp: 1.1))
        let click3 = UnifiedEvent.click(ClickEvent(type: .leftClick, position: CGPoint(x: 0.51, y: 0.51), timestamp: 1.2))
        
        // when
        let region1 = scorer.addEvent(click1)
        let region2 = scorer.addEvent(click2)
        let region3 = scorer.addEvent(click3)
        
        // then
        XCTAssertEqual(region1.center, region2.center, "Should merge into same region")
        XCTAssertEqual(region2.center, region3.center, "Should continue merging")
        XCTAssertEqual(region3.eventCount, 3, "Should accumulate event count")
        XCTAssertEqual(region3.score, 3.0, accuracy: 0.001, "Should accumulate scores")
    }
}
