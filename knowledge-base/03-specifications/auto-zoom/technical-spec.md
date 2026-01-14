# Auto Zoom 2.0 - 技术规格

> **层级**: L3 - 技术设计  
> **状态**: ✅ 已实现 (v4.0 - 连续缩放模式)  
> **关联**: [功能规格](./functional-spec.md)

## 架构设计

### 整体流程

```
┌─────────────────────────────────────────────────────┐
│              事件输入层                              │
│  ┌─────────────────┐  ┌─────────────────────────┐  │
│  │MouseEventTracker│  │ KeyboardEventTracker    │  │
│  │  - 点击事件      │  │  - 键盘事件              │  │
│  │  - 移动轨迹      │  │  - 用于触发缩回          │  │
│  └────────┬────────┘  └───────────┬─────────────┘  │
└───────────┼───────────────────────┼─────────────────┘
            ↓                       ↓
┌─────────────────────────────────────────────────────┐
│              决策引擎层                              │
│  ┌─────────────────────────────────────────────┐   │
│  │       ContinuousZoomController              │   │
│  │  - 状态机管理（idle/zoomed/transitioning）  │   │
│  │  - 事件处理（点击/移动/键盘/超时）          │   │
│  │  - 过渡决策（平滑跟随 vs 先缩回再过渡）     │   │
│  │  - 防抖逻辑                                  │   │
│  └────────────────────┬────────────────────────┘   │
│                       ↓                             │
│  ┌─────────────────────────────────────────────┐   │
│  │       DynamicZoomCalculator                 │   │
│  │  - 位置感知缩放级别                          │   │
│  │  - 边缘/角落 → 放大更多                      │   │
│  │  - 中心 → 放大较少                           │   │
│  └────────────────────┬────────────────────────┘   │
└───────────────────────┼─────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│              时间线层                                │
│  ┌─────────────────────────────────────────────┐   │
│  │       ContinuousZoomTimeline                │   │
│  │  - 关键帧存储 [ZoomKeyframe]                │   │
│  │  - 任意时间点插值                            │   │
│  │  - 相位检测（zoomIn/hold/zoomOut/idle）     │   │
│  └────────────────────┬────────────────────────┘   │
└───────────────────────┼─────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│              渲染导出层                              │
│  ┌─────────────────┐  ┌─────────────────────────┐  │
│  │  ZoomRenderer   │  │ CombinedEffectsExporter │  │
│  │  - 裁剪计算     │  │  - 光标增强              │  │
│  │  - 帧渲染       │  │  - Auto Zoom            │  │
│  └─────────────────┘  └─────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

## 核心组件

### 1. ZoomKeyframe

表示时间线上的一个关键帧，包含时间、缩放、中心和缓动曲线。

```swift
struct ZoomKeyframe: Equatable {
    let time: TimeInterval
    let scale: CGFloat
    let center: CGPoint  // Normalized (0-1)
    let easing: EasingCurve
    
    // 工厂方法
    static func idle(at time: TimeInterval) -> ZoomKeyframe
    static func zoomed(at:scale:center:easing:) -> ZoomKeyframe
    
    // 插值
    static func interpolate(from:to:at:) -> ZoomKeyframe
}
```

### 2. ContinuousZoomTimeline

管理关键帧序列，提供任意时间点的状态查询。

```swift
struct ContinuousZoomTimeline {
    private let keyframes: [ZoomKeyframe]
    
    // 状态查询
    func state(at time: TimeInterval) -> ContinuousZoomState
    
    // 辅助方法
    var isEmpty: Bool
    var count: Int
    var duration: TimeInterval
    func keyframe(at index: Int) -> ZoomKeyframe?
    func keyframes(in range: ClosedRange<TimeInterval>) -> [ZoomKeyframe]
    
    // 工厂方法
    static func from(cursorSession:keyboardEvents:config:) -> ContinuousZoomTimeline
}
```

### 3. ContinuousZoomState

表示某一时刻的缩放状态。

```swift
struct ContinuousZoomState: Equatable {
    let scale: CGFloat
    let center: CGPoint
    let isActive: Bool
    let phase: Phase
    
    enum Phase {
        case idle
        case zoomIn
        case hold
        case zoomOut
    }
    
    static let idle: ContinuousZoomState
}
```

### 4. DynamicZoomCalculator

根据屏幕位置计算动态缩放级别。

```swift
struct DynamicZoomCalculator {
    let baseScale: CGFloat
    let minScaleFactor: CGFloat  // 中心位置因子 (0.85)
    let maxScaleFactor: CGFloat  // 边缘位置因子 (1.25)
    
    // 计算方法
    func zoomScale(at position: CGPoint) -> CGFloat
    func zoomScaleWithCornerBoost(at position: CGPoint) -> CGFloat
    
    // 位置检测
    func isCornerPosition(_ position: CGPoint) -> Bool
    func isEdgePosition(_ position: CGPoint) -> Bool
}
```

**算法说明**：
```
edgeDistance = min(position.x, 1-x, position.y, 1-y)
normalizedDistance = edgeDistance / 0.5  // 0=边缘, 1=中心
scaleFactor = maxScaleFactor - (max - min) * normalizedDistance
actualScale = baseScale * scaleFactor

角落额外 +10% 加成
```

### 5. ContinuousZoomController

状态机 + 决策引擎，核心控制器。

```swift
final class ContinuousZoomController {
    private let config: ContinuousZoomConfig
    private let dynamicZoom: DynamicZoomCalculator
    
    // 主入口
    func generateKeyframes(
        from cursorSession: CursorTrackSession,
        keyboardEvents: [KeyboardEvent]
    ) -> [ZoomKeyframe]
}
```

**状态转换**：
```
idle → zoomingIn   : 检测到点击
zoomingIn → zoomed : 放大动画完成
zoomed → following : 光标移动
following → zoomed : 光标静止
zoomed → zoomingOut: 超时 or 键盘输入
zoomingOut → idle  : 缩小动画完成

特殊过渡：
zoomed → transitioning → zoomed : 大距离移动（先缩回再放大）
```

### 6. ContinuousZoomConfig

配置参数集合。

```swift
struct ContinuousZoomConfig {
    let baseZoomScale: CGFloat
    let zoomInDuration: TimeInterval
    let zoomOutDuration: TimeInterval
    let panDuration: TimeInterval
    let idleTimeout: TimeInterval
    let largeDistanceThreshold: CGFloat
    let debounceAreaThreshold: CGFloat
    let debounceTimeWindow: TimeInterval
    let easing: EasingCurve
    
    static let `default`: ContinuousZoomConfig
}
```

### 7. KeyboardEventTracker

键盘事件监听器。

```swift
@MainActor
final class KeyboardEventTracker {
    private(set) var events: [KeyboardEvent]
    
    func startTracking()
    func stopTracking()
    
    var lastEventTime: TimeInterval?
    func hasRecentActivity(within:at:) -> Bool
}

struct KeyboardEvent: Equatable {
    let type: KeyboardEventType  // .keyDown, .keyUp
    let timestamp: TimeInterval
    let keyCode: UInt16
}
```

## 核心算法

### 1. 动态缩放计算

```swift
func zoomScaleWithCornerBoost(at position: CGPoint) -> CGFloat {
    // 1. 计算到边缘的距离
    let edgeDistanceX = min(position.x, 1.0 - position.x)
    let edgeDistanceY = min(position.y, 1.0 - position.y)
    let minEdgeDistance = min(edgeDistanceX, edgeDistanceY)
    
    // 2. 归一化 (0=边缘, 1=中心)
    let normalizedDistance = minEdgeDistance / 0.5
    
    // 3. 计算缩放因子
    let scaleFactor = maxScaleFactor - (max - min) * normalizedDistance
    let baseZoom = baseScale * scaleFactor
    
    // 4. 角落加成
    if isCornerPosition(position) {
        return baseZoom * 1.1
    }
    return baseZoom
}
```

### 2. 过渡决策

```swift
func decideTransition(currentCenter: CGPoint, targetPosition: CGPoint) -> TransitionType {
    let distance = hypot(currentCenter.x - targetPosition.x,
                         currentCenter.y - targetPosition.y)
    
    if distance > config.largeDistanceThreshold {
        // 大距离：先缩回，再平移，再放大
        return .zoomOutThenPan
    } else {
        // 小距离：平滑跟随
        return .smoothPan
    }
}
```

### 3. 防抖逻辑

```swift
func shouldDebounce(currentClick: ClickEvent, previousClicks: [ClickEvent]) -> Bool {
    // 获取时间窗口内的点击
    let recentClicks = previousClicks.filter {
        currentClick.timestamp - $0.timestamp < config.debounceTimeWindow
    }
    
    guard recentClicks.count >= 2 else { return false }
    
    // 计算活动区域
    let positions = recentClicks.map(\.position) + [currentClick.position]
    let boundingBox = calculateBoundingBox(positions)
    let areaRatio = boundingBox.width * boundingBox.height
    
    // 区域小于阈值则防抖
    return areaRatio < config.debounceAreaThreshold
}
```

### 4. 关键帧插值

```swift
static func interpolate(from: ZoomKeyframe, to: ZoomKeyframe, at time: TimeInterval) -> ZoomKeyframe {
    // 1. 计算进度
    let duration = to.time - from.time
    let elapsed = time - from.time
    let progress = clamp(elapsed / duration, 0, 1)
    
    // 2. 应用缓动
    let easedProgress = to.easing.value(at: progress)
    
    // 3. 插值各属性
    let scale = from.scale + (to.scale - from.scale) * easedProgress
    let centerX = from.center.x + (to.center.x - from.center.x) * easedProgress
    let centerY = from.center.y + (to.center.y - from.center.y) * easedProgress
    
    return ZoomKeyframe(time: time, scale: scale, center: CGPoint(x: centerX, y: centerY), easing: to.easing)
}
```

## 关键帧生成流程

```swift
func generateKeyframes(from session: CursorTrackSession, keyboardEvents: [KeyboardEvent]) -> [ZoomKeyframe] {
    var keyframes: [ZoomKeyframe] = [.idle(at: 0)]
    var state: ZoomControlState = .idle
    var lastZoomCenter: CGPoint?
    var lastActivityTime: TimeInterval = 0
    
    for click in session.clickEvents.sorted(by: { $0.timestamp < $1.timestamp }) {
        // 1. 检查键盘活动 → 缩回
        if hasKeyboardActivity(at: click.timestamp, events: keyboardEvents) {
            if case .zoomed = state {
                keyframes += generateZoomOut(from: lastZoomCenter, startTime: ...)
                state = .idle
            }
            continue
        }
        
        // 2. 检查超时 → 缩回
        if click.timestamp - lastActivityTime > config.idleTimeout {
            if case .zoomed = state {
                keyframes += generateZoomOut(...)
                state = .idle
            }
        }
        
        // 3. 根据当前状态决策
        switch state {
        case .idle:
            // 放大到点击位置
            let scale = dynamicZoom.zoomScaleWithCornerBoost(at: click.position)
            keyframes += generateZoomIn(to: click.position, scale: scale, ...)
            state = .zoomed(at: click.position)
            
        case .zoomed(let currentCenter):
            let distance = hypot(...)
            
            // 防抖检查
            if shouldDebounce(...) {
                continue
            }
            
            if distance > config.largeDistanceThreshold {
                // 大距离：缩回 → 平移 → 放大
                keyframes += generateLargeDistanceTransition(...)
            } else {
                // 小距离：平滑过渡
                keyframes += generateSmoothTransition(...)
            }
            state = .zoomed(at: click.position)
        }
        
        lastActivityTime = click.timestamp
        lastZoomCenter = click.position
    }
    
    // 4. 添加跟随关键帧
    keyframes = addFollowingKeyframes(to: keyframes, session: session)
    
    // 5. 结尾处理
    if case .zoomed = state {
        keyframes += generateZoomOut(...)
    }
    
    return keyframes.sorted { $0.time < $1.time }
}
```

## CombinedEffectsExporter 集成

```swift
actor CombinedEffectsExporter {
    func export(
        videoURL: URL,
        cursorSession: CursorTrackSession,
        keyboardEvents: [KeyboardEvent],  // v4.0 新增
        to outputURL: URL
    ) async throws {
        // 1. 生成连续缩放时间线
        let zoomTimeline = ContinuousZoomTimeline.from(
            cursorSession: cursorSession,
            keyboardEvents: keyboardEvents,
            config: autoZoomSettings.toContinuousZoomConfig()
        )
        
        // 2. 逐帧处理
        while let frame = readNextFrame() {
            let time = frame.presentationTime.seconds
            
            // 查询缩放状态
            let zoomState = zoomTimeline.state(at: time)
            
            // 渲染缩放
            let zoomedImage = zoomRenderer.renderFrame(
                source: frame,
                scale: zoomState.scale,
                center: zoomState.center,
                outputSize: videoSize
            )
            
            // 渲染高亮（带缩放因子）
            let highlightScale = zoomState.scale > 1.0 ? cursorScale : 1.0
            let finalImage = cursorRenderer.renderFrame(
                source: zoomedImage,
                highlights: highlights,
                highlightScale: highlightScale
            )
            
            writeFrame(finalImage)
        }
    }
}
```

## 测试策略

### 单元测试

| 组件 | 测试类 | 覆盖要点 |
|------|--------|----------|
| DynamicZoomCalculator | DynamicZoomCalculatorTests | 边缘/中心/角落缩放计算 |
| ZoomKeyframe | ZoomKeyframeTests | 创建、插值、缓动 |
| ContinuousZoomTimeline | ContinuousZoomTimelineTests | 状态查询、相位检测 |
| ContinuousZoomController | ContinuousZoomControllerTests | 状态转换、防抖、键盘响应 |
| AutoZoomSettings | AutoZoomSettingsTests | 配置验证、预设 |

### 集成测试

- TC-1：完整导出流程（含键盘事件）
- TC-2：大距离过渡动画验证
- TC-3：防抖行为验证
- TC-4：光标高亮缩放验证

## 文件结构

```
Features/AutoZoom/
├── Domain/
│   └── Models/
│       ├── EasingCurve.swift
│       ├── AutoZoomSettings.swift           # v4.0 更新
│       ├── ZoomKeyframe.swift               # v4.0 新增
│       ├── ContinuousZoomTimeline.swift     # v4.0 新增
│       └── (legacy: AutoZoomSegment, ZoomTimeline)
├── Infrastructure/
│   ├── ContinuousZoomController.swift       # v4.0 新增
│   ├── DynamicZoomCalculator.swift          # v4.0 新增
│   ├── KeyboardEventTracker.swift           # v4.0 新增
│   ├── ZoomRenderer.swift
│   └── (legacy)
├── ViewModels/
│   └── AutoZoomViewModel.swift              # v4.0 更新
└── Views/
    └── AutoZoomSettingsView.swift           # v4.0 更新

Tests/UnitTests/Features/AutoZoom/
├── DynamicZoomCalculatorTests.swift         # v4.0 新增
├── ZoomKeyframeTests.swift                  # v4.0 新增
├── ContinuousZoomTimelineTests.swift        # v4.0 新增
├── ContinuousZoomControllerTests.swift      # v4.0 新增
└── AutoZoomSettingsTests.swift              # v4.0 更新
```

## 相关文档

- [功能规格](./functional-spec.md)
- [光标增强技术设计](../cursor-enhancement/functional-spec.md)
