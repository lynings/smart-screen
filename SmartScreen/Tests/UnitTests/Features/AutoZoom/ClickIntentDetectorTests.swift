import XCTest
@testable import SmartScreen

final class ClickIntentDetectorTests: XCTestCase {
    
    private var sut: ClickIntentDetector!
    
    override func setUp() {
        super.setUp()
        sut = ClickIntentDetector()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Single Click Tests
    
    func test_should_detect_single_click_when_no_recent_activity() {
        // given
        let click = ClickEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0)
        
        // when
        let intent = sut.detectIntent(for: click, recentClicks: [])
        
        // then
        if case .singleClick(let position) = intent {
            XCTAssertEqual(position, click.position)
        } else {
            XCTFail("Expected single click intent")
        }
    }
    
    func test_should_detect_single_click_when_previous_click_is_far() {
        // given
        let oldClick = ClickEvent(type: .leftClick, position: CGPoint(x: 0.1, y: 0.1), timestamp: 0.5)
        let newClick = ClickEvent(type: .leftClick, position: CGPoint(x: 0.9, y: 0.9), timestamp: 1.5)
        
        // when
        let intent = sut.detectIntent(for: newClick, recentClicks: [oldClick])
        
        // then
        if case .singleClick(let position) = intent {
            XCTAssertEqual(position, newClick.position)
        } else {
            XCTFail("Expected single click intent")
        }
    }
    
    // MARK: - Double Click Tests
    
    func test_should_detect_double_click_when_two_clicks_same_position_fast() {
        // given
        let firstClick = ClickEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0)
        let secondClick = ClickEvent(type: .leftClick, position: CGPoint(x: 0.51, y: 0.51), timestamp: 1.2)
        
        // when
        let intent = sut.detectIntent(for: secondClick, recentClicks: [firstClick])
        
        // then
        if case .doubleClick(let position) = intent {
            XCTAssertEqual(position.x, 0.505, accuracy: 0.01)
            XCTAssertEqual(position.y, 0.505, accuracy: 0.01)
        } else {
            XCTFail("Expected double click intent, got \(intent)")
        }
    }
    
    func test_should_not_detect_double_click_when_too_slow() {
        // given
        let firstClick = ClickEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0)
        let secondClick = ClickEvent(type: .leftClick, position: CGPoint(x: 0.51, y: 0.51), timestamp: 1.5)
        
        // when
        let intent = sut.detectIntent(for: secondClick, recentClicks: [firstClick])
        
        // then
        if case .doubleClick = intent {
            XCTFail("Should not detect double click when too slow")
        }
        // Expected: rapid clicks or single click
    }
    
    // MARK: - Rapid Clicks Same Area Tests
    
    func test_should_detect_rapid_clicks_same_area() {
        // given - clicks are > 0.3s apart (beyond double-click window) but within 0.5s (rapid click window)
        let click1 = ClickEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0)
        let click2 = ClickEvent(type: .leftClick, position: CGPoint(x: 0.52, y: 0.48), timestamp: 1.35)
        let click3 = ClickEvent(type: .leftClick, position: CGPoint(x: 0.48, y: 0.52), timestamp: 1.7)
        
        // when
        let intent = sut.detectIntent(for: click3, recentClicks: [click1, click2])
        
        // then
        if case .rapidClicksSameArea(let centroid, let count) = intent {
            XCTAssertGreaterThanOrEqual(count, 2)  // At least click2 and click3
            XCTAssertEqual(centroid.x, 0.5, accuracy: 0.03)
            XCTAssertEqual(centroid.y, 0.5, accuracy: 0.03)
        } else {
            XCTFail("Expected rapid clicks same area intent, got \(intent)")
        }
    }
    
    // MARK: - Rapid Clicks Different Areas Tests
    
    func test_should_detect_rapid_clicks_different_areas() {
        // given
        let click1 = ClickEvent(type: .leftClick, position: CGPoint(x: 0.2, y: 0.2), timestamp: 1.0)
        let click2 = ClickEvent(type: .leftClick, position: CGPoint(x: 0.8, y: 0.8), timestamp: 1.4)
        
        // when
        let intent = sut.detectIntent(for: click2, recentClicks: [click1])
        
        // then
        if case .rapidClicksDifferentAreas(let positions) = intent {
            XCTAssertEqual(positions.count, 2)
        } else {
            XCTFail("Expected rapid clicks different areas intent, got \(intent)")
        }
    }
    
    // MARK: - Click Then Move Tests
    
    func test_should_detect_click_then_move() {
        // given
        let click = ClickEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0)
        let moves = [
            MouseEvent(type: .move, position: CGPoint(x: 0.52, y: 0.52), timestamp: 1.05),
            MouseEvent(type: .move, position: CGPoint(x: 0.6, y: 0.6), timestamp: 1.1),
            MouseEvent(type: .move, position: CGPoint(x: 0.7, y: 0.7), timestamp: 1.2)
        ]
        
        // when
        let intent = sut.detectIntent(for: click, recentClicks: [], recentMoves: moves)
        
        // then
        if case .clickThenMove(let position, let direction) = intent {
            XCTAssertEqual(position, click.position)
            XCTAssertGreaterThan(direction.x, 0)
            XCTAssertGreaterThan(direction.y, 0)
        } else {
            XCTFail("Expected click then move intent, got \(intent)")
        }
    }
    
    func test_should_not_detect_click_then_move_when_movement_is_small() {
        // given
        let click = ClickEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0)
        let moves = [
            MouseEvent(type: .move, position: CGPoint(x: 0.51, y: 0.51), timestamp: 1.05),
            MouseEvent(type: .move, position: CGPoint(x: 0.52, y: 0.52), timestamp: 1.1)
        ]
        
        // when
        let intent = sut.detectIntent(for: click, recentClicks: [], recentMoves: moves)
        
        // then
        if case .singleClick = intent {
            // Expected
        } else {
            XCTFail("Expected single click intent for small movement")
        }
    }
    
    // MARK: - Primary Position Tests
    
    func test_should_return_correct_primary_position() {
        // then
        let single = ClickIntent.singleClick(position: CGPoint(x: 0.5, y: 0.5))
        XCTAssertEqual(single.primaryPosition, CGPoint(x: 0.5, y: 0.5))
        
        let rapid = ClickIntent.rapidClicksSameArea(centroid: CGPoint(x: 0.3, y: 0.3), clickCount: 3)
        XCTAssertEqual(rapid.primaryPosition, CGPoint(x: 0.3, y: 0.3))
        
        let double = ClickIntent.doubleClick(position: CGPoint(x: 0.7, y: 0.7))
        XCTAssertEqual(double.primaryPosition, CGPoint(x: 0.7, y: 0.7))
    }
    
    // MARK: - Hold Duration Multiplier Tests
    
    func test_should_have_correct_hold_multipliers() {
        // then
        XCTAssertEqual(ClickIntent.singleClick(position: .zero).holdDurationMultiplier, 1.0)
        XCTAssertGreaterThan(
            ClickIntent.rapidClicksSameArea(centroid: .zero, clickCount: 3).holdDurationMultiplier,
            1.0
        )
        XCTAssertLessThan(
            ClickIntent.rapidClicksDifferentAreas(positions: []).holdDurationMultiplier,
            1.0
        )
        XCTAssertEqual(ClickIntent.doubleClick(position: .zero).holdDurationMultiplier, 1.5)
    }
    
    // MARK: - Should Enter Follow Mode Tests
    
    func test_should_enter_follow_mode_for_click_then_move() {
        // given
        let clickThenMove = ClickIntent.clickThenMove(
            clickPosition: CGPoint(x: 0.5, y: 0.5),
            moveDirection: CGPoint(x: 0.1, y: 0.1)
        )
        
        // then
        XCTAssertTrue(clickThenMove.shouldEnterFollowMode)
    }
    
    func test_should_not_enter_follow_mode_for_other_intents() {
        // then
        XCTAssertFalse(ClickIntent.singleClick(position: .zero).shouldEnterFollowMode)
        XCTAssertFalse(ClickIntent.doubleClick(position: .zero).shouldEnterFollowMode)
        XCTAssertFalse(ClickIntent.rapidClicksSameArea(centroid: .zero, clickCount: 2).shouldEnterFollowMode)
    }
    
    // MARK: - Grouped Click Tests
    
    func test_should_identify_grouped_clicks() {
        // then
        XCTAssertTrue(ClickIntent.rapidClicksSameArea(centroid: .zero, clickCount: 2).isGroupedClick)
        XCTAssertTrue(ClickIntent.rapidClicksDifferentAreas(positions: []).isGroupedClick)
        XCTAssertTrue(ClickIntent.doubleClick(position: .zero).isGroupedClick)
        XCTAssertFalse(ClickIntent.singleClick(position: .zero).isGroupedClick)
        XCTAssertFalse(ClickIntent.clickThenMove(clickPosition: .zero, moveDirection: .zero).isGroupedClick)
    }
    
    // MARK: - Sequence Analysis Tests
    
    func test_should_analyze_click_sequence() {
        // given
        let clicks = [
            ClickEvent(type: .leftClick, position: CGPoint(x: 0.2, y: 0.2), timestamp: 1.0),
            ClickEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 2.0),
            ClickEvent(type: .leftClick, position: CGPoint(x: 0.8, y: 0.8), timestamp: 3.0)
        ]
        
        // when
        let intents = sut.analyzeClickSequence(clicks)
        
        // then
        XCTAssertEqual(intents.count, 3)
    }
    
    // MARK: - State Management Tests
    
    func test_should_reset_state() {
        // given
        sut.recordClick(ClickEvent(type: .leftClick, position: .zero, timestamp: 1.0))
        sut.recordMove(MouseEvent(type: .move, position: .zero, timestamp: 1.1))
        
        // when
        sut.reset()
        
        // then - no crash, state is cleared (internal state is private)
        let intent = sut.detectIntent(
            for: ClickEvent(type: .leftClick, position: .zero, timestamp: 2.0),
            recentClicks: []
        )
        if case .singleClick(let position) = intent {
            XCTAssertEqual(position, .zero)
        } else {
            XCTFail("Expected single click intent")
        }
    }
}
