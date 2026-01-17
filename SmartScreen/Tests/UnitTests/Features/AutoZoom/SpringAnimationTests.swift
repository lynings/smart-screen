import XCTest
@testable import SmartScreen

final class SpringAnimationTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func test_should_initialize_with_default_values() {
        // given/when
        let spring = SpringAnimation()
        
        // then
        XCTAssertEqual(spring.tension, 170)
        XCTAssertEqual(spring.friction, 26)
        XCTAssertEqual(spring.mass, 1)
    }
    
    func test_should_clamp_invalid_values() {
        // given/when
        let spring = SpringAnimation(tension: -10, friction: -5, mass: 0)
        
        // then
        XCTAssertEqual(spring.tension, 1)  // Clamped to minimum 1
        XCTAssertEqual(spring.friction, 0) // Clamped to minimum 0
        XCTAssertEqual(spring.mass, 0.1)   // Clamped to minimum 0.1
    }
    
    // MARK: - Value Calculation Tests
    
    func test_should_return_start_value_at_time_zero() {
        // given
        let spring = SpringAnimation.default
        let from: CGFloat = 0
        let to: CGFloat = 100
        
        // when
        let value = spring.value(at: 0, from: from, to: to)
        
        // then
        XCTAssertEqual(value, from)
    }
    
    func test_should_approach_target_value_over_time() {
        // given
        let spring = SpringAnimation.default
        let from: CGFloat = 0
        let to: CGFloat = 100
        
        // when
        let valueAtHalfSecond = spring.value(at: 0.5, from: from, to: to)
        let valueAtOneSecond = spring.value(at: 1.0, from: from, to: to)
        
        // then
        XCTAssertGreaterThan(valueAtHalfSecond, from)
        XCTAssertGreaterThan(valueAtOneSecond, valueAtHalfSecond)
        XCTAssertLessThan(abs(valueAtOneSecond - to), abs(valueAtHalfSecond - to))
    }
    
    func test_should_settle_at_target_value() {
        // given
        let spring = SpringAnimation.default
        let from: CGFloat = 0
        let to: CGFloat = 100
        
        // when - use sufficiently large time for settling
        let finalValue = spring.value(at: 3.0, from: from, to: to)
        
        // then
        XCTAssertEqual(finalValue, to, accuracy: 0.5)
    }
    
    func test_should_return_target_when_displacement_is_zero() {
        // given
        let spring = SpringAnimation.default
        let value: CGFloat = 50
        
        // when
        let result = spring.value(at: 0.5, from: value, to: value)
        
        // then
        XCTAssertEqual(result, value)
    }
    
    // MARK: - Damping Ratio Tests
    
    func test_should_calculate_underdamped_behavior() {
        // given - low friction creates underdamped spring (bouncy)
        let spring = SpringAnimation(tension: 170, friction: 10, mass: 1)
        
        // then
        XCTAssertLessThan(spring.dampingRatio, 1)
    }
    
    func test_should_calculate_overdamped_behavior() {
        // given - high friction creates overdamped spring (sluggish)
        let spring = SpringAnimation(tension: 100, friction: 50, mass: 1)
        
        // then
        XCTAssertGreaterThan(spring.dampingRatio, 1)
    }
    
    func test_should_calculate_critically_damped_behavior() {
        // given - friction = 2 * sqrt(tension * mass) for critical damping
        let tension: CGFloat = 100
        let mass: CGFloat = 1
        let criticalFriction = 2 * sqrt(tension * mass)
        let spring = SpringAnimation(tension: tension, friction: criticalFriction, mass: mass)
        
        // then
        XCTAssertEqual(spring.dampingRatio, 1, accuracy: 0.01)
    }
    
    // MARK: - Velocity Tests
    
    func test_should_return_initial_velocity_at_time_zero() {
        // given
        let spring = SpringAnimation.default
        let initialVelocity: CGFloat = 50
        
        // when
        let velocity = spring.velocity(at: 0, from: 0, to: 100, initialVelocity: initialVelocity)
        
        // then
        XCTAssertEqual(velocity, initialVelocity)
    }
    
    func test_should_have_near_zero_velocity_when_settled() {
        // given
        let spring = SpringAnimation.default
        
        // when - use a sufficiently large time for settling
        let velocity = spring.velocity(at: 3.0, from: 0, to: 100)
        
        // then
        XCTAssertEqual(velocity, 0, accuracy: 1.0)
    }
    
    // MARK: - isSettled Tests
    
    func test_should_not_be_settled_initially() {
        // given
        let spring = SpringAnimation.default
        
        // when
        let settled = spring.isSettled(at: 0.01, from: 0, to: 100)
        
        // then
        XCTAssertFalse(settled)
    }
    
    func test_should_be_settled_after_settling_time() {
        // given
        let spring = SpringAnimation.default
        
        // when - use sufficiently large time for settling
        let settled = spring.isSettled(
            at: 3.0, 
            from: 0, 
            to: 100,
            positionThreshold: 0.1,
            velocityThreshold: 0.1
        )
        
        // then
        XCTAssertTrue(settled)
    }
    
    // MARK: - Progress Tests
    
    func test_should_return_zero_progress_at_start() {
        // given
        let spring = SpringAnimation.default
        
        // when
        let progress = spring.progress(at: 0)
        
        // then
        XCTAssertEqual(progress, 0)
    }
    
    func test_should_return_one_progress_when_settled() {
        // given
        let spring = SpringAnimation.default
        let settlingTime = spring.settlingTime
        
        // when
        let progress = spring.progress(at: settlingTime * 2)
        
        // then
        XCTAssertEqual(progress, 1, accuracy: 0.01)
    }
    
    // MARK: - CGPoint Extension Tests
    
    func test_should_animate_cgpoint() {
        // given
        let spring = SpringAnimation.default
        let from = CGPoint(x: 0, y: 0)
        let to = CGPoint(x: 100, y: 200)
        
        // when
        let value = spring.value(at: 0.5, from: from, to: to)
        
        // then
        XCTAssertGreaterThan(value.x, from.x)
        XCTAssertGreaterThan(value.y, from.y)
        XCTAssertLessThan(value.x, to.x * 1.5)  // Allow for overshoot
        XCTAssertLessThan(value.y, to.y * 1.5)
    }
    
    func test_should_calculate_cgpoint_velocity() {
        // given
        let spring = SpringAnimation.default
        let from = CGPoint(x: 0, y: 0)
        let to = CGPoint(x: 100, y: 100)
        
        // when
        let velocity = spring.velocity(at: 0.1, from: from, to: to)
        
        // then
        XCTAssertGreaterThan(velocity.x, 0)
        XCTAssertGreaterThan(velocity.y, 0)
    }
    
    func test_should_check_cgpoint_settled() {
        // given
        let spring = SpringAnimation.default
        let from = CGPoint(x: 0, y: 0)
        let to = CGPoint(x: 100, y: 100)
        
        // when - use sufficiently large time for settling
        let settledEarly = spring.isSettled(at: 0.1, from: from, to: to)
        let settledLater = spring.isSettled(
            at: 3.0, 
            from: from, 
            to: to,
            positionThreshold: 0.1,
            velocityThreshold: 0.1
        )
        
        // then
        XCTAssertFalse(settledEarly)
        XCTAssertTrue(settledLater)
    }
    
    // MARK: - Preset Tests
    
    func test_should_have_different_preset_characteristics() {
        // given
        let defaultSpring = SpringAnimation.default
        let gentleSpring = SpringAnimation.gentle
        let stiffSpring = SpringAnimation.stiff
        let slowSpring = SpringAnimation.slow
        
        // then - gentle should be more damped than wobbly
        XCTAssertGreaterThan(SpringAnimation.gentle.dampingRatio, SpringAnimation.wobbly.dampingRatio)
        
        // then - stiff should settle faster than slow
        XCTAssertLessThan(stiffSpring.settlingTime, slowSpring.settlingTime)
        
        // then - default should be balanced
        XCTAssertGreaterThan(defaultSpring.tension, gentleSpring.tension)
        XCTAssertLessThan(defaultSpring.tension, stiffSpring.tension)
    }
    
    // MARK: - Edge Cases
    
    func test_should_handle_negative_direction() {
        // given
        let spring = SpringAnimation.default
        let from: CGFloat = 100
        let to: CGFloat = 0
        
        // when
        let value = spring.value(at: 0.3, from: from, to: to)
        
        // then
        XCTAssertLessThan(value, from)
        XCTAssertGreaterThan(value, to - 20)  // Allow for undershoot
    }
    
    func test_should_handle_small_displacements() {
        // given
        let spring = SpringAnimation.default
        let from: CGFloat = 0.5
        let to: CGFloat = 0.51
        
        // when
        let value = spring.value(at: 0.5, from: from, to: to)
        
        // then
        XCTAssertGreaterThan(value, from)
        XCTAssertLessThanOrEqual(value, to * 1.1)
    }
}

// MARK: - NativeSpring Tests

final class NativeSpringTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func test_should_initialize_with_default_values() {
        // given/when
        let spring = NativeSpring()
        
        // then
        XCTAssertEqual(spring.duration, 0.5)
        XCTAssertEqual(spring.bounce, 0.0)
    }
    
    func test_should_clamp_invalid_duration() {
        // given/when
        let spring = NativeSpring(duration: -1.0, bounce: 0.0)
        
        // then
        XCTAssertEqual(spring.duration, 0.01)  // Clamped to minimum 0.01
    }
    
    func test_should_clamp_bounce_values() {
        // given/when
        let springOverBounce = NativeSpring(duration: 0.5, bounce: 2.0)
        let springUnderBounce = NativeSpring(duration: 0.5, bounce: -2.0)
        
        // then
        XCTAssertEqual(springOverBounce.bounce, 1.0)   // Clamped to max 1.0
        XCTAssertEqual(springUnderBounce.bounce, -1.0) // Clamped to min -1.0
    }
    
    // MARK: - Value Calculation Tests
    
    func test_should_return_zero_at_time_zero() {
        // given
        let spring = NativeSpring.default
        
        // when
        let value = spring.value(target: 100, time: 0)
        
        // then
        XCTAssertEqual(value, 0, accuracy: 0.1)
    }
    
    func test_should_approach_target_over_time() {
        // given
        let spring = NativeSpring.default
        
        // when
        let valueEarly = spring.value(target: 100, time: 0.1)
        let valueLater = spring.value(target: 100, time: 0.5)
        
        // then
        XCTAssertGreaterThan(valueLater, valueEarly)
    }
    
    func test_should_settle_near_target() {
        // given
        let spring = NativeSpring.smooth
        
        // when - use duration * 3 for full settling
        let finalValue = spring.value(target: 100, time: spring.duration * 3)
        
        // then
        XCTAssertEqual(finalValue, 100, accuracy: 1.0)
    }
    
    // MARK: - Progress Tests
    
    func test_should_return_zero_progress_at_start() {
        // given
        let spring = NativeSpring.default
        
        // when
        let progress = spring.progress(at: 0)
        
        // then
        XCTAssertEqual(progress, 0, accuracy: 0.01)
    }
    
    func test_should_return_near_one_progress_after_duration() {
        // given
        let spring = NativeSpring.snappy
        
        // when
        let progress = spring.progress(at: spring.duration * 2)
        
        // then
        XCTAssertGreaterThan(progress, 0.9)
        XCTAssertLessThanOrEqual(progress, 1.0)
    }
    
    func test_should_clamp_progress_to_zero_one_range() {
        // given
        let spring = NativeSpring.bouncy  // Has bounce, might overshoot
        
        // when
        let progressEarly = spring.progress(at: 0.1)
        let progressLate = spring.progress(at: 2.0)
        
        // then
        XCTAssertGreaterThanOrEqual(progressEarly, 0)
        XCTAssertLessThanOrEqual(progressLate, 1.0)
    }
    
    // MARK: - Velocity Tests
    
    func test_should_have_positive_velocity_during_animation() {
        // given
        let spring = NativeSpring.default
        
        // when
        let velocity = spring.velocity(target: 100, time: 0.1)
        
        // then
        XCTAssertGreaterThan(velocity, 0)
    }
    
    func test_should_have_near_zero_velocity_when_settled() {
        // given
        let spring = NativeSpring.smooth
        
        // when
        let velocity = spring.velocity(target: 100, time: spring.duration * 3)
        
        // then
        XCTAssertEqual(velocity, 0, accuracy: 5.0)
    }
    
    // MARK: - isSettled Tests
    
    func test_should_not_be_settled_initially() {
        // given
        let spring = NativeSpring.default
        
        // when
        let settled = spring.isSettled(at: 0.01)
        
        // then
        XCTAssertFalse(settled)
    }
    
    func test_should_be_settled_after_sufficient_time() {
        // given
        let spring = NativeSpring.snappy
        
        // when
        let settled = spring.isSettled(at: spring.duration * 3, threshold: 0.01)
        
        // then
        XCTAssertTrue(settled)
    }
    
    // MARK: - CGPoint Extension Tests
    
    func test_should_animate_cgpoint_from_to() {
        // given
        let spring = NativeSpring.default
        let from = CGPoint(x: 0, y: 0)
        let to = CGPoint(x: 100, y: 200)
        
        // when
        let value = spring.value(at: 0.3, from: from, to: to)
        
        // then
        XCTAssertGreaterThan(value.x, from.x)
        XCTAssertGreaterThan(value.y, from.y)
        XCTAssertLessThan(value.x, to.x * 1.2)  // Within bounds
        XCTAssertLessThan(value.y, to.y * 1.2)
    }
    
    // MARK: - Preset Tests
    
    func test_snappy_should_be_faster_than_smooth() {
        // given
        let snappy = NativeSpring.snappy
        let smooth = NativeSpring.smooth
        
        // then
        XCTAssertLessThan(snappy.duration, smooth.duration)
    }
    
    func test_bouncy_should_have_positive_bounce() {
        // given
        let bouncy = NativeSpring.bouncy
        
        // then
        XCTAssertGreaterThan(bouncy.bounce, 0)
    }
    
    func test_gentle_should_have_longer_duration() {
        // given
        let gentle = NativeSpring.gentle
        let snappy = NativeSpring.snappy
        
        // then
        XCTAssertGreaterThan(gentle.duration, snappy.duration)
    }
    
    func test_smooth_should_have_no_bounce() {
        // given
        let smooth = NativeSpring.smooth
        
        // then
        XCTAssertEqual(smooth.bounce, 0)
    }
    
    // MARK: - Physics Parameters Tests
    
    func test_should_expose_stiffness_and_damping() {
        // given
        let spring = NativeSpring.default
        
        // then - stiffness and damping should be positive
        XCTAssertGreaterThan(spring.stiffness, 0)
        XCTAssertGreaterThan(spring.damping, 0)
    }
    
    func test_snappy_should_have_higher_stiffness_than_gentle() {
        // given
        let snappy = NativeSpring.snappy
        let gentle = NativeSpring.gentle
        
        // then
        XCTAssertGreaterThan(snappy.stiffness, gentle.stiffness)
    }
    
    // MARK: - Value With From/To Tests
    
    func test_should_calculate_value_between_from_and_to() {
        // given
        let spring = NativeSpring.default
        let from: CGFloat = 50
        let to: CGFloat = 150
        
        // when
        let value = spring.value(at: spring.duration, from: from, to: to)
        
        // then - should be closer to target
        XCTAssertGreaterThan(value, from)
        XCTAssertLessThan(abs(value - to), abs(from - to))
    }
    
    func test_should_return_target_when_from_equals_to() {
        // given
        let spring = NativeSpring.default
        let value: CGFloat = 100
        
        // when
        let result = spring.value(at: 0.5, from: value, to: value)
        
        // then
        XCTAssertEqual(result, value)
    }
}
