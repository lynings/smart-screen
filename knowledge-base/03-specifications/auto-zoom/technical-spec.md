# Auto Zoom - 技术规格

> **层级**: L3 - 技术设计  
> **状态**: ✅ 已实现 (v4.0 - 智能行为分析)  
> **关联**: [功能规格](./functional-spec.md)

## 架构设计

### 整体流程

```
┌─────────────────────┐
│  CursorTrackSession │  输入：鼠标事件序列
└──────────┬──────────┘
           ↓
┌─────────────────────────┐
│ SmartZoomBehaviorAnalyzer│  行为分析 + 状态机
│  - 稳定性检测           │
│  - 频率抑制             │
│  - 大跨度处理           │
│  - 冷却机制             │
└──────────┬──────────────┘
           ↓
┌─────────────────────┐
│  SmartZoomTimeline  │  关键帧时间线
│  [SmartZoomKeyframe]│  - 平滑插值
└──────────┬──────────┘
           ↓
┌─────────────────────┐
│    ZoomRenderer     │  渲染缩放帧
│  - 裁剪区域计算     │
│  - CGImage 处理     │
└──────────┬──────────┘
           ↓
┌─────────────────────┐
│CombinedEffectsExport│  导出集成
│  - 光标增强         │
│  - Auto Zoom        │
└─────────────────────┘
```

## 核心组件

### 1. ZoomBehaviorState

状态机的状态定义：

```swift
enum ZoomBehaviorState: Equatable {
    /// 正常视图 (1.0x)，无活动
    case idle
    
    /// 检测到活动，等待光标稳定
    case observing(since: TimeInterval, position: CGPoint)
    
    /// 正在放大
    case zoomingIn(startTime: TimeInterval, from: CGFloat, to: CGFloat, center: CGPoint)
    
    /// 已放大，跟随光标
    case zoomed(center: CGPoint, scale: CGFloat)
    
    /// 正在缩小（检测到大跨度操作）
    case zoomingOut(startTime: TimeInterval, from: CGFloat, center: CGPoint)
    
    /// 冷却中，等待新的稳定
    case cooldown(since: TimeInterval, lastPosition: CGPoint)
}
```

### 2. ZoomBehaviorConfig

行为分析的配置参数：

```swift
struct ZoomBehaviorConfig: Equatable {
    // 稳定性检测
    let stabilizationTime: TimeInterval  // 光标稳定时间 (0.5s)
    let maxStableSpeed: CGFloat          // 最大稳定速度 (0.3)
    let stableAreaRadius: CGFloat        // 稳定区域半径 (0.05)
    
    // 抑制条件
    let largeMovementThreshold: CGFloat  // 大跨度阈值 (0.25)
    let maxClickFrequency: Double        // 最大点击频率 (3.0)
    let cooldownDuration: TimeInterval   // 冷却时间 (0.3s)
    
    // 动画参数
    let zoomInDuration: TimeInterval     // 放大时长 (0.4s)
    let zoomOutDuration: TimeInterval    // 缩小时长 (0.3s)
    let targetScale: CGFloat             // 目标缩放 (2.0)
    let easing: EasingCurve
    
    static let `default`: ZoomBehaviorConfig
    static func from(settings: AutoZoomSettings) -> ZoomBehaviorConfig
}
```

### 3. SmartZoomKeyframe

关键帧数据结构：

```swift
struct SmartZoomKeyframe: Equatable {
    let time: TimeInterval
    let scale: CGFloat
    let center: CGPoint  // Normalized (0-1)
    
    static let idle = SmartZoomKeyframe(time: 0, scale: 1.0, center: CGPoint(x: 0.5, y: 0.5))
}
```

### 4. SmartZoomTimeline

关键帧时间线，支持平滑插值：

```swift
struct SmartZoomTimeline: Equatable {
    let keyframes: [SmartZoomKeyframe]
    let duration: TimeInterval
    
    /// 获取指定时间的插值状态
    func state(at time: TimeInterval) -> (scale: CGFloat, center: CGPoint) {
        // 1. 找到前后关键帧
        // 2. 使用 ease-in-out 插值
        // 3. 同时插值 scale 和 center
    }
    
    static func empty(duration: TimeInterval) -> SmartZoomTimeline
}
```

### 5. SmartZoomBehaviorAnalyzer

核心行为分析器：

```swift
final class SmartZoomBehaviorAnalyzer {
    private let config: ZoomBehaviorConfig
    
    init(config: ZoomBehaviorConfig = .default)
    
    /// 分析 cursor session，生成智能缩放时间线
    func analyze(session: CursorTrackSession) -> SmartZoomTimeline {
        // 1. 构建活动事件序列
        // 2. 通过状态机处理事件
        // 3. 生成关键帧
    }
}
```

## 算法详解

### 状态机转换

```
┌─────────────────────────────────────────────────────────┐
│                     状态转换规则                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  idle ────────点击────────→ observing                   │
│                                                         │
│  observing ──停留0.5s────→ zoomingIn                    │
│           ──快速移动─────→ observing (重置)              │
│           ──高频点击─────→ observing (重置)              │
│                                                         │
│  zoomingIn ──动画完成────→ zoomed                       │
│            ──大跨度移动──→ zoomingOut                   │
│                                                         │
│  zoomed ────大跨度移动───→ zoomingOut                   │
│         ────小范围移动───→ zoomed (平滑平移)            │
│                                                         │
│  zoomingOut ─动画完成────→ cooldown                     │
│                                                         │
│  cooldown ──0.3s后───────→ observing                    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 稳定性检测 (AC-ST-01)

```swift
// 在 observing 状态下
if event.type == .click || event.type == .move {
    let distance = hypot(
        event.position.x - observePosition.x,
        event.position.y - observePosition.y
    )
    
    if distance > config.stableAreaRadius {
        // 移动出稳定区域，重置观察
        state = .observing(since: time, position: event.position)
    } else if time - since >= config.stabilizationTime {
        // 稳定超过 0.5s，触发缩放
        state = .zoomingIn(...)
    }
}
```

### 频率抑制 (AC-ST-02)

```swift
// 跟踪最近 1 秒的点击
recentClicks = recentClicks.filter { time - $0 < 1.0 }

if event.type == .click {
    recentClicks.append(time)
}

let clickFrequency = Double(recentClicks.count)
if clickFrequency > config.maxClickFrequency {
    // 高频点击，重置观察状态
    state = .observing(since: time, position: event.position)
}
```

### 大跨度处理 (AC-ST-03)

```swift
// 在 zoomed 状态下
if event.type == .click {
    let movementDistance = hypot(
        event.position.x - lastClickPosition.x,
        event.position.y - lastClickPosition.y
    )
    
    if movementDistance > config.largeMovementThreshold {
        // 大跨度移动，先 zoom out
        state = .zoomingOut(startTime: time, from: scale, center: center)
        keyframes.append(SmartZoomKeyframe(time: time, scale: scale, center: center))
        keyframes.append(SmartZoomKeyframe(
            time: time + config.zoomOutDuration,
            scale: 1.0,
            center: center
        ))
    }
}
```

### 关键帧插值

```swift
func state(at time: TimeInterval) -> (scale: CGFloat, center: CGPoint) {
    // 找到前后关键帧
    guard let afterIndex = keyframes.firstIndex(where: { $0.time > time }) else {
        return (keyframes.last!.scale, keyframes.last!.center)
    }
    
    if afterIndex == 0 {
        return (keyframes.first!.scale, keyframes.first!.center)
    }
    
    let before = keyframes[afterIndex - 1]
    let after = keyframes[afterIndex]
    
    // 使用 ease-in-out 插值
    let progress = (time - before.time) / (after.time - before.time)
    let easedProgress = CGFloat(EasingCurve.easeInOut.value(at: progress))
    
    let scale = before.scale + (after.scale - before.scale) * easedProgress
    let centerX = before.center.x + (after.center.x - before.center.x) * easedProgress
    let centerY = before.center.y + (after.center.y - before.center.y) * easedProgress
    
    return (scale, CGPoint(x: centerX, y: centerY))
}
```

### 边界约束 (AC-FR-02)

```swift
private func constrainCenter(_ position: CGPoint, scale: CGFloat) -> CGPoint {
    guard scale > 1.0 else { return position }
    
    // 计算可视区域尺寸
    let visibleWidth = 1.0 / scale
    let visibleHeight = 1.0 / scale
    let halfWidth = visibleWidth / 2
    let halfHeight = visibleHeight / 2
    
    // 约束中心点
    let constrainedX = max(halfWidth, min(1.0 - halfWidth, position.x))
    let constrainedY = max(halfHeight, min(1.0 - halfHeight, position.y))
    
    return CGPoint(x: constrainedX, y: constrainedY)
}
```

## 配置项

### ZoomBehaviorConfig

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `stabilizationTime` | TimeInterval | 0.5 | 光标稳定时间阈值 |
| `maxStableSpeed` | CGFloat | 0.3 | 最大稳定速度 |
| `stableAreaRadius` | CGFloat | 0.05 | 稳定区域半径 |
| `largeMovementThreshold` | CGFloat | 0.25 | 大跨度移动阈值 |
| `maxClickFrequency` | Double | 3.0 | 最大点击频率 |
| `cooldownDuration` | TimeInterval | 0.3 | 冷却时间 |
| `zoomInDuration` | TimeInterval | 0.4 | 放大动画时长 |
| `zoomOutDuration` | TimeInterval | 0.3 | 缩小动画时长 |
| `targetScale` | CGFloat | 2.0 | 目标缩放倍数 |
| `easing` | EasingCurve | .easeInOut | 缓动曲线 |

## 坐标系统

### 归一化坐标
- X: 0 = 左边, 1 = 右边
- Y: 0 = 顶部, 1 = 底部
- 用于：`center`, `position` 等

### CGImage 坐标
- X: 0 = 左边
- Y: 0 = 底部, height = 顶部
- 用于：`cropRect`

### 转换公式

```swift
// Normalized → CGImage
cgImageY = (1.0 - normalizedY) * imageHeight

// CGImage → Normalized
normalizedY = 1.0 - (cgImageY / imageHeight)
```

## 性能优化

### 内存管理
- 单帧处理，不累积历史数据
- 使用 `autoreleasepool` 处理帧循环

### 渲染优化
- 仅在缩放时创建裁剪图像
- 复用 CGContext

### 分析优化
- 预计算 SmartZoomTimeline，导出时直接查询
- 线性查找关键帧（通常数量少）

## 测试策略

### 单元测试覆盖

| 组件 | 测试数 | 覆盖重点 |
|------|--------|----------|
| SmartZoomBehaviorAnalyzer | 9 | 稳定触发、频率抑制、大跨度处理 |
| ZoomBehaviorState | 6 | 状态属性 |
| ZoomBehaviorConfig | 2 | 默认值、设置转换 |
| ActivityEvent | 2 | 事件类型 |

### 验证 AC

| AC | 测试方法 |
|----|----------|
| AC-ST-01 | `test_should_zoom_after_stabilization_time` |
| AC-ST-02 | `test_should_suppress_zoom_on_high_frequency_clicks` |
| AC-ST-03 | `test_should_zoom_out_on_large_movement` |
| AC-ST-04 | 冷却机制在状态机中实现 |
| AC-FR-02 | `test_should_constrain_zoom_center_at_edges` |
| AC-AN-02 | `test_should_interpolate_smoothly_between_keyframes` |

## 文件结构

```
Features/AutoZoom/
├── Domain/Models/
│   ├── ZoomBehaviorState.swift       # v4.0 状态机
│   ├── AutoZoomSettings.swift        # 配置
│   ├── EasingCurve.swift             # 缓动曲线
│   └── (legacy: AutoZoomSegment, ZoomTimeline)
├── Infrastructure/
│   ├── SmartZoomBehaviorAnalyzer.swift  # v4.0 行为分析器
│   ├── ZoomRenderer.swift               # 帧渲染
│   └── (legacy: ZoomSegmentGenerator)
├── ViewModels/
│   └── AutoZoomViewModel.swift
└── Views/
    └── AutoZoomSettingsView.swift

Features/Export/Infrastructure/
└── CombinedEffectsExporter.swift  (使用 SmartZoomBehaviorAnalyzer)
```

## 相关文档

- [功能规格](./functional-spec.md)
- [UI 规格](./ui-spec.md)
