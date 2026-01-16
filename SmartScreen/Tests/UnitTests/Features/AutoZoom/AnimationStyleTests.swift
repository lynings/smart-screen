import XCTest
@testable import SmartScreen

final class AnimationStyleTests: XCTestCase {
    
    // MARK: - Enum Cases Tests
    
    func test_should_have_four_animation_styles() {
        // given/when
        let allCases = AnimationStyle.allCases
        
        // then
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.slow))
        XCTAssertTrue(allCases.contains(.mellow))
        XCTAssertTrue(allCases.contains(.quick))
        XCTAssertTrue(allCases.contains(.rapid))
    }
    
    // MARK: - Display Properties Tests
    
    func test_should_have_display_names() {
        // then
        XCTAssertEqual(AnimationStyle.slow.displayName, "Slow")
        XCTAssertEqual(AnimationStyle.mellow.displayName, "Mellow")
        XCTAssertEqual(AnimationStyle.quick.displayName, "Quick")
        XCTAssertEqual(AnimationStyle.rapid.displayName, "Rapid")
    }
    
    func test_should_have_descriptions() {
        // then
        XCTAssertFalse(AnimationStyle.slow.description.isEmpty)
        XCTAssertFalse(AnimationStyle.mellow.description.isEmpty)
        XCTAssertFalse(AnimationStyle.quick.description.isEmpty)
        XCTAssertFalse(AnimationStyle.rapid.description.isEmpty)
    }
    
    // MARK: - Spring Configuration Tests
    
    func test_should_have_progressively_faster_springs() {
        // given
        let slowSpring = AnimationStyle.slow.spring
        let mellowSpring = AnimationStyle.mellow.spring
        let quickSpring = AnimationStyle.quick.spring
        let rapidSpring = AnimationStyle.rapid.spring
        
        // then - tension should increase from slow to rapid
        XCTAssertLessThan(slowSpring.tension, mellowSpring.tension)
        XCTAssertLessThan(mellowSpring.tension, quickSpring.tension)
        XCTAssertLessThan(quickSpring.tension, rapidSpring.tension)
    }
    
    func test_should_have_decreasing_mass_for_faster_styles() {
        // given
        let slowSpring = AnimationStyle.slow.spring
        let rapidSpring = AnimationStyle.rapid.spring
        
        // then
        XCTAssertGreaterThan(slowSpring.mass, rapidSpring.mass)
    }
    
    // MARK: - Timing Configuration Tests
    
    func test_should_have_progressively_shorter_durations() {
        // given
        let slow = AnimationStyle.slow
        let mellow = AnimationStyle.mellow
        let quick = AnimationStyle.quick
        let rapid = AnimationStyle.rapid
        
        // then - typical duration should decrease
        XCTAssertGreaterThan(slow.typicalDuration, mellow.typicalDuration)
        XCTAssertGreaterThan(mellow.typicalDuration, quick.typicalDuration)
        XCTAssertGreaterThan(quick.typicalDuration, rapid.typicalDuration)
    }
    
    func test_should_have_zoom_in_duration() {
        // given/when
        let durations = AnimationStyle.allCases.map { $0.zoomInDuration }
        
        // then - all durations should be positive
        for duration in durations {
            XCTAssertGreaterThan(duration, 0)
        }
    }
    
    func test_should_have_zoom_out_longer_than_zoom_in() {
        // given/when/then
        for style in AnimationStyle.allCases {
            XCTAssertGreaterThanOrEqual(style.zoomOutDuration, style.zoomInDuration)
        }
    }
    
    // MARK: - Follow Mode Configuration Tests
    
    func test_should_have_increasing_follow_smoothing() {
        // given
        let slow = AnimationStyle.slow
        let rapid = AnimationStyle.rapid
        
        // then - rapid should have higher smoothing factor (more responsive)
        XCTAssertLessThan(slow.followSmoothingFactor, rapid.followSmoothingFactor)
    }
    
    func test_should_have_increasing_lookahead() {
        // given
        let slow = AnimationStyle.slow
        let rapid = AnimationStyle.rapid
        
        // then - rapid should have higher lookahead (more predictive)
        XCTAssertLessThan(slow.followLookaheadFactor, rapid.followLookaheadFactor)
    }
    
    // MARK: - Legacy Compatibility Tests
    
    func test_should_map_to_legacy_easing() {
        // then - all styles should have valid legacy easing
        for style in AnimationStyle.allCases {
            let easing = style.legacyEasing
            XCTAssertTrue([.linear, .easeIn, .easeOut, .easeInOut].contains(easing))
        }
    }
    
    // MARK: - Factory Method Tests
    
    func test_should_create_from_speed_slow() {
        // when
        let style = AnimationStyle.fromSpeed(10)
        
        // then
        XCTAssertEqual(style, .slow)
    }
    
    func test_should_create_from_speed_mellow() {
        // when
        let style = AnimationStyle.fromSpeed(35)
        
        // then
        XCTAssertEqual(style, .mellow)
    }
    
    func test_should_create_from_speed_quick() {
        // when
        let style = AnimationStyle.fromSpeed(60)
        
        // then
        XCTAssertEqual(style, .quick)
    }
    
    func test_should_create_from_speed_rapid() {
        // when
        let style = AnimationStyle.fromSpeed(90)
        
        // then
        XCTAssertEqual(style, .rapid)
    }
    
    func test_should_create_adjusted_spring() {
        // given
        let style = AnimationStyle.mellow
        
        // when
        let adjusted = style.springWithAdjustment(
            tensionMultiplier: 1.5,
            frictionMultiplier: 0.8
        )
        
        // then
        XCTAssertEqual(adjusted.tension, style.spring.tension * 1.5)
        XCTAssertEqual(adjusted.friction, style.spring.friction * 0.8)
        XCTAssertEqual(adjusted.mass, style.spring.mass)
    }
    
    // MARK: - Codable Tests
    
    func test_should_encode_and_decode() throws {
        // given
        let original = AnimationStyle.quick
        
        // when
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnimationStyle.self, from: encoded)
        
        // then
        XCTAssertEqual(original, decoded)
    }
    
    // MARK: - Identifiable Tests
    
    func test_should_have_unique_ids() {
        // given/when
        let ids = AnimationStyle.allCases.map { $0.id }
        let uniqueIds = Set(ids)
        
        // then
        XCTAssertEqual(ids.count, uniqueIds.count)
    }
}
