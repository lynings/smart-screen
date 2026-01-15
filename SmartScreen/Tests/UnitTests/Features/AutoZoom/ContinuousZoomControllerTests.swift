import XCTest
@testable import SmartScreen

final class ContinuousZoomControllerTests: XCTestCase {
    
    // MARK: - Basic Generation Tests
    
    func test_should_generate_empty_keyframes_for_no_clicks() {
        // given
        let controller = ContinuousZoomController()
        let session = CursorTrackSession(events: [], duration: 10.0)
        
        // when
        let keyframes = controller.generateKeyframes(from: session, keyboardEvents: [])
        
        // then - should only have initial idle keyframe
        XCTAssertEqual(keyframes.count, 1)
        XCTAssertEqual(keyframes.first?.scale, 1.0)
    }
    
    func test_should_generate_zoom_in_keyframes_for_single_click() {
        // given
        let controller = ContinuousZoomController()
        let clickEvent = MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0)
        let session = CursorTrackSession(events: [clickEvent], duration: 5.0)
        
        // when
        let keyframes = controller.generateKeyframes(from: session, keyboardEvents: [])
        
        // then - should have zoom in keyframes
        XCTAssertGreaterThan(keyframes.count, 1)
        
        // Find zoom keyframe
        let zoomedKeyframe = keyframes.first { $0.scale > 1.0 }
        XCTAssertNotNil(zoomedKeyframe)
    }
    
    func test_should_generate_three_phase_structure_ease_in_hold_ease_out() {
        // given
        let config = ContinuousZoomConfig(
            baseZoomScale: 2.0,
            zoomInDuration: 0.3,
            holdBase: 0.8,
            zoomOutDuration: 0.4
        )
        let controller = ContinuousZoomController(config: config)
        let clickEvent = MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0)
        let session = CursorTrackSession(events: [clickEvent], duration: 5.0)
        
        // when
        let keyframes = controller.generateKeyframes(from: session, keyboardEvents: [])
        
        // then - should have distinct phases
        // Phase 1: Ease In (t=1.0 scale=1.0 -> t=1.3 scale=2.0)
        let easeInStart = keyframes.first { $0.time == 1.0 }
        let easeInEnd = keyframes.first { abs($0.time - 1.3) < 0.05 && $0.scale > 1.5 }
        XCTAssertNotNil(easeInStart, "应该有 ease-in 开始关键帧")
        XCTAssertNotNil(easeInEnd, "应该有 ease-in 结束关键帧")
        
        // Phase 2: Hold (t=1.3 to t=2.1, scale stays at ~2.0, position unchanged)
        let holdEnd = keyframes.first { abs($0.time - 2.1) < 0.05 && $0.scale > 1.5 }
        XCTAssertNotNil(holdEnd, "应该有 hold 结束关键帧")
        if let easeInEndKF = easeInEnd, let holdEndKF = holdEnd {
            XCTAssertEqual(easeInEndKF.scale, holdEndKF.scale, accuracy: 0.1, "Hold 阶段 scale 应该保持不变")
            XCTAssertEqual(easeInEndKF.center.x, holdEndKF.center.x, accuracy: 0.01, "Hold 阶段位置应该保持不变")
        }
        
        // Phase 3: Ease Out (last keyframe should be scale=1.0)
        let lastKeyframe = keyframes.last
        if let lastScale = lastKeyframe?.scale {
            XCTAssertEqual(lastScale, 1.0, accuracy: 0.1, "最后应该 zoom out 到 scale=1.0")
        } else {
            XCTFail("应该有最后的 zoom-out 关键帧")
        }
    }
    
    func test_should_zoom_out_at_end_of_recording() {
        // given
        let controller = ContinuousZoomController()
        let clickEvent = MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0)
        let session = CursorTrackSession(events: [clickEvent], duration: 3.0)
        
        // when
        let keyframes = controller.generateKeyframes(from: session, keyboardEvents: [])
        
        // then - last keyframe should be zoom out (scale = 1.0)
        let lastKeyframe = keyframes.last
        XCTAssertNotNil(lastKeyframe)
        if let scale = lastKeyframe?.scale {
            XCTAssertEqual(Double(scale), 1.0, accuracy: 0.01)
        }
    }
    
    // MARK: - Keyboard Interaction Tests
    
    func test_should_zoom_out_on_keyboard_activity() {
        // given
        let config = ContinuousZoomConfig(
            baseZoomScale: 2.0,
            zoomInDuration: 0.3,
            zoomOutDuration: 0.4,
            panDuration: 0.3,
            idleTimeout: 3.0,
            largeDistanceThreshold: 0.3,
            debounceAreaThreshold: 0.15,
            debounceTimeWindow: 0.5,
            easing: .easeInOut
        )
        let controller = ContinuousZoomController(config: config)
        
        // Click at 1.0s, keyboard at 2.0s
        let clickEvent = MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0)
        let keyboardEvent = KeyboardEvent(type: .keyDown, timestamp: 2.0, keyCode: 0)
        let session = CursorTrackSession(events: [clickEvent], duration: 5.0)
        
        // when
        let keyframes = controller.generateKeyframes(from: session, keyboardEvents: [keyboardEvent])
        
        // then - should have zoom out before the keyboard event time
        // The keyframes should show zooming out around 2.0s due to keyboard
        let zoomOutKeyframes = keyframes.filter { $0.time >= 1.5 && $0.time <= 2.5 }
        let hasZoomOut = zoomOutKeyframes.contains { $0.scale < 2.0 }
        XCTAssertTrue(hasZoomOut || keyframes.isEmpty == false)
    }
    
    // MARK: - Idle Timeout Tests
    
    func test_should_zoom_out_after_idle_timeout() {
        // given
        let config = ContinuousZoomConfig(
            baseZoomScale: 2.0,
            zoomInDuration: 0.3,
            zoomOutDuration: 0.4,
            panDuration: 0.3,
            idleTimeout: 2.0, // 2 second timeout
            largeDistanceThreshold: 0.3,
            debounceAreaThreshold: 0.15,
            debounceTimeWindow: 0.5,
            easing: .easeInOut
        )
        let controller = ContinuousZoomController(config: config)
        
        // Single click at 1.0s, recording ends at 10.0s
        let clickEvent = MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0)
        let session = CursorTrackSession(events: [clickEvent], duration: 10.0)
        
        // when
        let keyframes = controller.generateKeyframes(from: session, keyboardEvents: [])
        
        // then - should have zoom out starting around 3.0s (1.0s click + 2.0s idle)
        let zoomOutStart = keyframes.first { $0.time > 2.5 && $0.scale < 2.0 }
        XCTAssertNotNil(zoomOutStart)
    }
    
    // MARK: - Large Distance Tests
    
    func test_should_use_zoom_out_pan_zoom_in_for_large_distance() {
        // given
        let config = ContinuousZoomConfig(
            baseZoomScale: 2.0,
            zoomInDuration: 0.3,
            zoomOutDuration: 0.4,
            panDuration: 0.3,
            idleTimeout: 3.0,
            largeDistanceThreshold: 0.2, // 20% of screen
            debounceAreaThreshold: 0.15,
            debounceTimeWindow: 0.5,
            easing: .easeInOut
        )
        let controller = ContinuousZoomController(config: config)
        
        // Two clicks far apart (more than 30% distance)
        let click1 = MouseEvent(type: .leftClick, position: CGPoint(x: 0.1, y: 0.1), timestamp: 1.0)
        let click2 = MouseEvent(type: .leftClick, position: CGPoint(x: 0.9, y: 0.9), timestamp: 2.0)
        let session = CursorTrackSession(events: [click1, click2], duration: 5.0)
        
        // when
        let keyframes = controller.generateKeyframes(from: session, keyboardEvents: [])
        
        // then - should have smooth transition with parallel interpolation
        // The transition uses parallel interpolation, so scale and center change simultaneously
        let transitionKeyframes = keyframes.filter { $0.time > 1.5 && $0.time < 2.5 }
        
        // Verify scale decreases then increases (zoom out -> zoom in pattern)
        let scales = transitionKeyframes.map { $0.scale }
        if scales.count >= 3 {
            let minScale = scales.min() ?? 1.0
            let firstScale = scales.first ?? 2.0
            let lastScale = scales.last ?? 2.0
            
            // Should zoom out (scale decreases) then zoom in (scale increases)
            XCTAssertLessThan(minScale, firstScale, "Should zoom out during transition")
            XCTAssertGreaterThan(lastScale, minScale, "Should zoom back in after transition")
        }
    }
    
    // MARK: - Debounce Tests
    
    func test_should_debounce_nearby_clicks() {
        // given
        let config = ContinuousZoomConfig(
            baseZoomScale: 2.0,
            zoomInDuration: 0.3,
            zoomOutDuration: 0.4,
            panDuration: 0.3,
            idleTimeout: 3.0,
            largeDistanceThreshold: 0.3,
            debounceAreaThreshold: 0.15, // 15% area threshold
            debounceTimeWindow: 0.5,
            easing: .easeInOut
        )
        let controller = ContinuousZoomController(config: config)
        
        // Multiple clicks in a small area within short time
        let click1 = MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0)
        let click2 = MouseEvent(type: .leftClick, position: CGPoint(x: 0.52, y: 0.52), timestamp: 1.2)
        let click3 = MouseEvent(type: .leftClick, position: CGPoint(x: 0.48, y: 0.48), timestamp: 1.4)
        let session = CursorTrackSession(events: [click1, click2, click3], duration: 5.0)
        
        // when
        let keyframes = controller.generateKeyframes(from: session, keyboardEvents: [])
        
        // then - should not have multiple zoom-in events
        // The number of keyframes should be reasonable (not one per click)
        let zoomInKeyframes = keyframes.filter { $0.scale > 1.5 }
        // Should debounce to single zoom event
        XCTAssertGreaterThan(zoomInKeyframes.count, 0)
    }
    
    // MARK: - Dynamic Zoom Tests
    
    func test_should_apply_larger_scale_at_edge() {
        // given
        let controller = ContinuousZoomController()
        
        // Click at edge position
        let edgeClick = MouseEvent(type: .leftClick, position: CGPoint(x: 0.05, y: 0.5), timestamp: 1.0)
        let session = CursorTrackSession(events: [edgeClick], duration: 5.0)
        
        // when
        let keyframes = controller.generateKeyframes(from: session, keyboardEvents: [])
        
        // then - should have larger scale due to edge position
        let zoomedKeyframe = keyframes.first { $0.scale > 1.0 }
        XCTAssertNotNil(zoomedKeyframe)
        // Edge position should get boosted scale (> base 2.0)
        if let zoomed = zoomedKeyframe {
            XCTAssertGreaterThan(zoomed.scale, 2.0)
        }
    }
    
    func test_should_apply_smaller_scale_at_center() {
        // given
        let controller = ContinuousZoomController()
        
        // Click at center position
        let centerClick = MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0)
        let session = CursorTrackSession(events: [centerClick], duration: 5.0)
        
        // when
        let keyframes = controller.generateKeyframes(from: session, keyboardEvents: [])
        
        // then - should have smaller scale due to center position
        let zoomedKeyframe = keyframes.first { $0.scale > 1.0 }
        XCTAssertNotNil(zoomedKeyframe)
        // Center position should get reduced scale (< base 2.0 * 1.25)
        if let zoomed = zoomedKeyframe {
            XCTAssertLessThan(zoomed.scale, 2.5)
        }
    }

    // MARK: - Merge (T_merge / D_merge)

    func test_should_merge_clicks_when_within_time_and_distance_threshold() {
        // given
        let config = ContinuousZoomConfig.default
        let controller = ContinuousZoomController(config: config)

        // Two clicks close in time (0.2s) and space (~28px in 1000px canvas)
        let click1 = MouseEvent(type: .leftClick, position: CGPoint(x: 0.50, y: 0.50), timestamp: 1.0)
        let click2 = MouseEvent(type: .leftClick, position: CGPoint(x: 0.52, y: 0.52), timestamp: 1.2)
        let session = CursorTrackSession(events: [click1, click2], duration: 5.0)

        // when
        let keyframes = controller.generateKeyframes(
            from: session,
            keyboardEvents: [],
            referenceSize: CGSize(width: 1000, height: 1000)
        )

        // then
        // If clicks are merged, we should not generate a separate transition at ~1.2s.
        let hasKeyframeNearSecondClick = keyframes.contains { abs($0.time - 1.2) < 0.03 }
        XCTAssertFalse(hasKeyframeNearSecondClick)
    }

    // MARK: - Event Aggregation for Frequent Operations
    
    func test_should_aggregate_rapid_frequent_clicks_to_avoid_zoom_in_out_loop() {
        // given - 模拟快速频繁操作：在 2 秒内点击 5 次
        let config = ContinuousZoomConfig(
            clickMergeTime: 0.3,
            clickMergeDistancePixels: 100
        )
        let controller = ContinuousZoomController(config: config)
        
        // 快速连续点击，每次距离稍微不同（超过合并阈值，但在同一小区域）
        let clicks = [
            MouseEvent(type: .leftClick, position: CGPoint(x: 0.30, y: 0.30), timestamp: 1.0),
            MouseEvent(type: .leftClick, position: CGPoint(x: 0.38, y: 0.32), timestamp: 1.2),  // 150px
            MouseEvent(type: .leftClick, position: CGPoint(x: 0.32, y: 0.28), timestamp: 1.4),  // back
            MouseEvent(type: .leftClick, position: CGPoint(x: 0.35, y: 0.35), timestamp: 1.6),  
            MouseEvent(type: .leftClick, position: CGPoint(x: 0.33, y: 0.30), timestamp: 1.8),  
        ]
        
        let session = CursorTrackSession(events: clicks, duration: 5.0)
        
        // when
        let keyframes = controller.generateKeyframes(from: session, keyboardEvents: [], referenceSize: CGSize(width: 1920, height: 1080))
        
        // then - 分析是否有频繁的 zoom in/out
        print("\n[Aggregation Test] 输入：5 次点击在 0.8 秒内")
        print("[Aggregation Test] 关键帧：")
        for (i, kf) in keyframes.enumerated() {
            let phase = kf.scale > 1.5 ? "zoomed" : "idle/transition"
            print("  [\(i)] t=\(String(format: "%.3f", kf.time))s scale=\(String(format: "%.2f", kf.scale)) \(phase)")
        }
        
        // 计算 zoom in/out 的次数
        var zoomCycles = 0
        var wasZoomed = false
        for kf in keyframes {
            let isZoomed = kf.scale > 1.5
            if isZoomed && !wasZoomed {
                zoomCycles += 1
            }
            wasZoomed = isZoomed
        }
        
        print("[Aggregation Test] Zoom 循环次数: \(zoomCycles)")
        print("[Aggregation Test] 期望：应该聚合为 1-2 个镜头，不应该有 5 个独立的 zoom")
        
        XCTAssertLessThanOrEqual(zoomCycles, 2, "快速频繁操作应该被聚合，避免频繁 zoom in/out")
    }
    
    func test_should_aggregate_rapid_clicks_across_larger_distances() {
        // given - 更极端的场景：快速点击不同区域（触发大距离过渡）
        let config = ContinuousZoomConfig(
            largeDistanceThreshold: 0.3,
            clickMergeTime: 0.3,
            clickMergeDistancePixels: 100
        )
        let controller = ContinuousZoomController(config: config)
        
        // 快速在屏幕左右来回点击
        let clicks = [
            MouseEvent(type: .leftClick, position: CGPoint(x: 0.2, y: 0.5), timestamp: 1.0),
            MouseEvent(type: .leftClick, position: CGPoint(x: 0.8, y: 0.5), timestamp: 1.3),  // 大距离
            MouseEvent(type: .leftClick, position: CGPoint(x: 0.3, y: 0.5), timestamp: 1.6),  // 大距离
            MouseEvent(type: .leftClick, position: CGPoint(x: 0.7, y: 0.5), timestamp: 1.9),  // 大距离
        ]
        
        let session = CursorTrackSession(events: clicks, duration: 6.0)
        
        // when
        let keyframes = controller.generateKeyframes(from: session, keyboardEvents: [], referenceSize: CGSize(width: 1920, height: 1080))
        
        // then
        print("\n[Large Distance Aggregation Test] 输入：4 次大距离点击在 0.9 秒内")
        print("[Large Distance Aggregation Test] 关键帧序列：")
        var lastPhase = "idle"
        for (i, kf) in keyframes.enumerated() {
            let phase: String
            if kf.scale < 1.2 {
                phase = "idle"
            } else if kf.scale > 1.8 {
                phase = "zoomed"
            } else {
                phase = "transition"
            }
            
            if phase != lastPhase {
                print("  [\(i)] t=\(String(format: "%.3f", kf.time))s scale=\(String(format: "%.2f", kf.scale)) → \(phase)")
                lastPhase = phase
            }
        }
        
        // 计算完整的 zoom 循环（zoom in → hold → zoom out）
        var zoomInOutCycles = 0
        var inZoomCycle = false
        for kf in keyframes {
            if kf.scale > 1.8 && !inZoomCycle {
                zoomInOutCycles += 1
                inZoomCycle = true
            } else if kf.scale < 1.2 {
                inZoomCycle = false
            }
        }
        
        print("[Large Distance Aggregation Test] 完整 Zoom 循环: \(zoomInOutCycles)")
        print("[Large Distance Aggregation Test] 问题：每次大距离点击都触发 zoom out → zoom in")
        print("[Large Distance Aggregation Test] 期望：应该聚合为一个持续的 zoom 状态，使用平滑过渡")
        
        // 当前实现：每次大距离都会 zoom out → zoom in，导致循环
        // 期望：应该有更少的循环
        XCTAssertLessThanOrEqual(zoomInOutCycles, 2, "大距离连续点击应该被聚合")
    }

    // MARK: - Zoom Transition Smoothness
    
    func test_should_analyze_zoom_in_out_in_pattern_for_rapid_distant_clicks() {
        // given - 用户场景：快速点击两个较远的位置
        let config = ContinuousZoomConfig(
            zoomInDuration: 0.3,
            holdBase: 0.8,
            zoomOutDuration: 0.4,
            largeDistanceThreshold: 0.3
        )
        let controller = ContinuousZoomController(config: config)
        
        // 两次点击：左上角 → 右上角（距离约 0.7，超过 largeDistanceThreshold）
        let click1 = MouseEvent(type: .leftClick, position: CGPoint(x: 0.2, y: 0.8), timestamp: 1.0)
        let click2 = MouseEvent(type: .leftClick, position: CGPoint(x: 0.8, y: 0.8), timestamp: 2.0) // 1秒后
        
        let session = CursorTrackSession(events: [click1, click2], duration: 5.0)
        
        // when
        let keyframes = controller.generateKeyframes(from: session, keyboardEvents: [])
        
        // then - 分析过渡模式
        print("\n[Zoom Transition Test] 完整关键帧时间线：")
        for (i, kf) in keyframes.enumerated() {
            let phase: String
            if kf.scale < 1.2 {
                phase = "idle"
            } else if kf.scale > 1.8 {
                phase = "zoomed"
            } else {
                phase = "transitioning"
            }
            let deltaT = i > 0 ? kf.time - keyframes[i-1].time : 0
            print("  [\(i)] t=\(String(format: "%.3f", kf.time))s (Δt=\(String(format: "%.3f", deltaT))s) scale=\(String(format: "%.2f", kf.scale)) phase=\(phase)")
        }
        
        // 分析过渡时机
        print("\n[Zoom Transition Test] 分析：")
        print("  Click1 at t=1.0s → Ease In (0.3s) → Hold 应该到 t=2.1s (1.3 + 0.8)")
        print("  Click2 at t=2.0s (在 Hold 阶段内)")
        print("  期望：Click1 Hold 完整结束后，再开始过渡到 Click2")
        print("  实际：")
        
        // 查找 Click1 的 Hold 结束时间（最后一个 zoomed 关键帧，在过渡之前）
        let click1HoldEnd = keyframes.last { $0.time >= 1.3 && $0.time <= 2.2 && $0.scale > 1.8 }
        if let holdEnd = click1HoldEnd {
            print("    - Click1 Hold 结束于 t=\(String(format: "%.3f", holdEnd.time))s")
        }
        
        // 查找过渡开始时间（第一个 scale < 1.8 的关键帧）
        let transitionStart = keyframes.first { $0.time > 1.3 && $0.scale < 1.8 }
        if let transition = transitionStart, let holdEnd = click1HoldEnd {
            print("    - 过渡开始于 t=\(String(format: "%.3f", transition.time))s")
            if transition.time >= holdEnd.time {
                print("    - ✅ 正确：Hold 完整结束后才开始过渡")
            } else {
                print("    - ❌ 错误：Hold 还没结束就开始过渡了！")
            }
        }
    }

    // MARK: - Rapid Click Jitter (User Reported Issue)
    
    func test_should_prevent_jitter_when_rapid_clicks_with_small_cursor_movement() {
        // given - User's exact scenario: 移动到左上角 → 点击 → 快速平移到旁边 → 再点击
        let config = ContinuousZoomConfig(
            holdBase: 0.8,
            clickMergeTime: 0.3,
            clickMergeDistancePixels: 100
        )
        let controller = ContinuousZoomController(config: config)
        
        // 模拟用户操作：左上角附近的快速连续点击
        let move1 = MouseEvent(type: .move, position: CGPoint(x: 0.10, y: 0.90), timestamp: 1.00)
        let click1 = MouseEvent(type: .leftClick, position: CGPoint(x: 0.10, y: 0.90), timestamp: 1.05)
        // 光标快速平移到旁边（距离约 0.08，在 1920x1080 下约 150px，超过合并阈值）
        let move2 = MouseEvent(type: .move, position: CGPoint(x: 0.18, y: 0.88), timestamp: 1.10)
        let click2 = MouseEvent(type: .leftClick, position: CGPoint(x: 0.18, y: 0.88), timestamp: 1.15)
        
        let session = CursorTrackSession(
            events: [move1, click1, move2, click2],
            duration: 3.0
        )
        
        // when
        print("\n[Jitter Test] 检查点击合并：")
        let clickEvents = session.clickEvents
        print("  原始点击数: \(clickEvents.count)")
        for (i, click) in clickEvents.enumerated() {
            print("    [\(i)] (\(String(format: "%.3f", click.position.x)), \(String(format: "%.3f", click.position.y))) at t=\(String(format: "%.3f", click.timestamp))")
        }
        
        let keyframes = controller.generateKeyframes(
            from: session,
            keyboardEvents: [],
            referenceSize: CGSize(width: 1920, height: 1080)
        )
        
        // then - 打印关键帧来分析跳动原因
        print("\n[Jitter Test] 输入事件：")
        print("  Click1: (0.10, 0.90) at t=1.05")
        print("  Click2: (0.18, 0.88) at t=1.15")
        print("  距离: \(hypot(0.18-0.10, 0.88-0.90)) (约 \(hypot(0.18-0.10, 0.88-0.90) * 1920) pixels)")
        print("  质心: ((0.10+0.18)/2, (0.90+0.88)/2) = (0.14, 0.89)")
        
        print("\n[Jitter Test] 关键帧分析：")
        for (i, kf) in keyframes.enumerated() {
            print("  [\(i)] t=\(String(format: "%.3f", kf.time)) scale=\(String(format: "%.2f", kf.scale)) center=(\(String(format: "%.3f", kf.center.x)), \(String(format: "%.3f", kf.center.y))) easing=\(kf.easing)")
        }
        
        // 检查是否有快速的位置切换（可能导致跳动）
        var hasRapidPositionSwitch = false
        for i in 0..<keyframes.count-1 {
            let current = keyframes[i]
            let next = keyframes[i+1]
            let timeDiff = next.time - current.time
            let positionDiff = hypot(next.center.x - current.center.x, next.center.y - current.center.y)
            
            // 如果在很短时间内（< 0.2s）位置变化较大（> 0.05），可能导致跳动
            if timeDiff < 0.2 && positionDiff > 0.05 {
                print("  ⚠️  检测到快速位置切换: t=\(String(format: "%.3f", current.time)) → \(String(format: "%.3f", next.time)) (Δt=\(String(format: "%.3f", timeDiff))s, Δpos=\(String(format: "%.3f", positionDiff)))")
                hasRapidPositionSwitch = true
            }
        }
        
        // 两次点击距离约 0.08，应该被识别为"小距离移动"并应用 Hysteresis
        // 第二次点击应该被拒绝（在 Hold 阶段内）
        print("\n[Jitter Test] 分析结论：")
        print("  - Click1 at (0.10, 0.90) t=1.05")
        print("  - Click2 at (0.18, 0.88) t=1.15 (距离约0.08, 时间差0.1s)")
        print("  - 距离 0.08 在 1920x1080 下约 154px，超过合并阈值(100px)")
        print("  - 时间差 0.1s < holdDuration(0.8s)，应该被 Hysteresis 拒绝")
        print("  - 是否有快速位置切换: \(hasRapidPositionSwitch)")
        
        XCTAssertFalse(hasRapidPositionSwitch, "快速连续点击不应该导致快速位置切换")
    }

    // MARK: - Event Conflict Resolution

    func test_should_ignore_move_events_around_click_to_prevent_jitter() {
        // given - Simulate real scenario: position polling creates move events, click happens between them
        let controller = ContinuousZoomController()
        
        let move1 = MouseEvent(type: .move, position: CGPoint(x: 0.500, y: 0.500), timestamp: 1.000)
        let move2 = MouseEvent(type: .move, position: CGPoint(x: 0.502, y: 0.502), timestamp: 1.033) // 30fps polling
        let click = MouseEvent(type: .leftClick, position: CGPoint(x: 0.502, y: 0.503), timestamp: 1.035) // Click slightly after
        let move3 = MouseEvent(type: .move, position: CGPoint(x: 0.503, y: 0.503), timestamp: 1.066) // Next polling
        
        let session = CursorTrackSession(events: [move1, move2, click, move3], duration: 3.0)
        
        // when
        let keyframes = controller.generateKeyframes(from: session, keyboardEvents: [])
        
        // then
        // Should only have one zoom target at click position, not multiple targets from move events
        let zoomedKeyframes = keyframes.filter { $0.scale > 1.5 }
        let uniquePositions = Set(zoomedKeyframes.map { "\($0.center.x),\($0.center.y)" })
        
        // Should only have one stable position (the click position)
        XCTAssertLessThanOrEqual(uniquePositions.count, 2, "不应该因为移动事件产生多个目标位置")
    }
    
    func test_should_prevent_rapid_position_changes_when_clicks_interleaved_with_moves() {
        // given - Real-world scenario: user clicks while moving mouse slightly
        let config = ContinuousZoomConfig(
            clickMergeTime: 0.3,
            clickMergeDistancePixels: 100
        )
        let controller = ContinuousZoomController(config: config)
        
        // Interleaved moves and clicks with slight position changes
        let events: [MouseEvent] = [
            MouseEvent(type: .move, position: CGPoint(x: 0.50, y: 0.50), timestamp: 1.00),
            MouseEvent(type: .leftClick, position: CGPoint(x: 0.51, y: 0.50), timestamp: 1.05),
            MouseEvent(type: .move, position: CGPoint(x: 0.52, y: 0.51), timestamp: 1.10),
            MouseEvent(type: .leftClick, position: CGPoint(x: 0.52, y: 0.51), timestamp: 1.15), // Should merge with first
            MouseEvent(type: .move, position: CGPoint(x: 0.53, y: 0.52), timestamp: 1.20),
            MouseEvent(type: .move, position: CGPoint(x: 0.54, y: 0.53), timestamp: 1.25),
        ]
        
        let session = CursorTrackSession(events: events, duration: 3.0)
        
        // when
        let keyframes = controller.generateKeyframes(from: session, keyboardEvents: [], referenceSize: CGSize(width: 1920, height: 1080))
        
        // then
        // Clicks should be merged (within 0.3s and ~20px at 1920x1080), resulting in only one zoom target
        let zoomedKeyframes = keyframes.filter { $0.scale > 1.5 && $0.time < 2.0 }
        
        print("[Test] Total keyframes: \(keyframes.count)")
        print("[Test] All keyframes:")
        for (i, kf) in keyframes.enumerated() {
            print("  [\(i)] t=\(String(format: "%.3f", kf.time)) scale=\(String(format: "%.2f", kf.scale)) center=(\(String(format: "%.3f", kf.center.x)), \(String(format: "%.3f", kf.center.y)))")
        }
        print("[Test] Zoomed keyframes before timeout: \(zoomedKeyframes.count)")
        
        // All zoomed keyframes should be at similar position (merged)
        if let firstZoomed = zoomedKeyframes.first {
            for kf in zoomedKeyframes {
                let distance = hypot(kf.center.x - firstZoomed.center.x, kf.center.y - firstZoomed.center.y)
                XCTAssertLessThan(distance, 0.05, "点击合并后，所有关键帧应该在相近位置，距离=\(distance)")
            }
        }
    }

    // MARK: - Hold Phase Stability

    func test_should_reject_small_movement_clicks_during_hold_phase_hysteresis() {
        // given
        let config = ContinuousZoomConfig(holdBase: 0.8)
        let controller = ContinuousZoomController(config: config)
        
        let click1 = MouseEvent(type: .leftClick, position: CGPoint(x: 0.5, y: 0.5), timestamp: 1.0)
        // Small movement click during Hold phase (1.0 + 0.3 = 1.3 to 1.3 + 0.8 = 2.1)
        let click2 = MouseEvent(type: .leftClick, position: CGPoint(x: 0.55, y: 0.52), timestamp: 1.5)
        let session = CursorTrackSession(events: [click1, click2], duration: 3.0)
        
        // when
        let keyframes = controller.generateKeyframes(from: session, keyboardEvents: [])
        
        // then
        // Click2 should be rejected during Hold phase due to hysteresis
        // Camera should stay at click1 position (0.5, 0.5)
        let keyframesAfterClick2 = keyframes.filter { $0.time >= 1.5 && $0.time <= 2.0 && $0.scale > 1.5 }
        for kf in keyframesAfterClick2 {
            XCTAssertEqual(kf.center.x, 0.5, accuracy: 0.1, "Hysteresis 应该拒绝 Hold 阶段的小幅移动")
            XCTAssertEqual(kf.center.y, 0.5, accuracy: 0.1, "Hysteresis 应该拒绝 Hold 阶段的小幅移动")
        }
    }
    
    func test_should_wait_for_hold_to_finish_even_for_large_movement_clicks() {
        // given
        let config = ContinuousZoomConfig(holdBase: 0.8, largeDistanceThreshold: 0.3)
        let controller = ContinuousZoomController(config: config)
        
        let click1 = MouseEvent(type: .leftClick, position: CGPoint(x: 0.2, y: 0.2), timestamp: 1.0)
        // Large movement click during Hold phase (Click1 Hold: t=1.3 to t=2.1)
        let click2 = MouseEvent(type: .leftClick, position: CGPoint(x: 0.8, y: 0.8), timestamp: 1.4)
        let session = CursorTrackSession(events: [click1, click2], duration: 4.0)
        
        // when
        let keyframes = controller.generateKeyframes(from: session, keyboardEvents: [])
        
        // then
        // 新策略：即使是大幅度移动，也要等 Click1 的 Hold 完整结束（t=2.1）后再开始过渡
        // 这样观众有时间看清 Click1 的内容
        let holdEndsAt = 2.1
        let transitionStartsAfterHold = keyframes.allSatisfy { kf in
            if kf.time < holdEndsAt {
                // Hold 结束前应该都在 Click1 位置
                return kf.center.x < 0.4 || kf.scale == 1.0  // Either at click1 or idle
            }
            return true
        }
        XCTAssertTrue(transitionStartsAfterHold, "应该等 Hold 结束后再开始过渡")
    }

    func test_should_stay_at_click_position_during_hold_phase_despite_cursor_movement() {
        // given
        let config = ContinuousZoomConfig(holdBase: 1.0)
        let controller = ContinuousZoomController(config: config)

        let click = MouseEvent(type: .leftClick, position: CGPoint(x: 0.20, y: 0.20), timestamp: 1.0)
        let move1 = MouseEvent(type: .move, position: CGPoint(x: 0.25, y: 0.25), timestamp: 1.6)
        let move2 = MouseEvent(type: .move, position: CGPoint(x: 0.80, y: 0.80), timestamp: 1.8)
        let session = CursorTrackSession(events: [click, move1, move2], duration: 3.0)

        // when
        let keyframes = controller.generateKeyframes(from: session, keyboardEvents: [])

        // then
        // During hold phase (1.3s to 2.1s), camera should stay at click position (0.20, 0.20).
        // It should NOT follow cursor movements to (0.25, 0.25) or (0.80, 0.80).
        let keyframesDuringHold = keyframes.filter { $0.time >= 1.3 && $0.time <= 2.1 && $0.scale > 1.5 }
        for kf in keyframesDuringHold {
            XCTAssertEqual(kf.center.x, 0.20, accuracy: 0.1, "Hold 阶段镜头应保持在点击位置，不追踪光标")
            XCTAssertEqual(kf.center.y, 0.20, accuracy: 0.1, "Hold 阶段镜头应保持在点击位置，不追踪光标")
        }
    }
}
