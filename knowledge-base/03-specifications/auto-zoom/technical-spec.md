# Auto Zoom - 技术规格

> **层级**: L3 - 技术设计  
> **状态**: ✅ 已实现 (v3.1 - 完整跟随模式)  
> **关联**: [功能规格](./functional-spec.md)

## 架构设计

### 整体流程

```
┌─────────────────────┐
│  CursorTrackSession │  输入：鼠标事件序列
└──────────┬──────────┘
           ↓
┌─────────────────────┐
│ ZoomSegmentGenerator│  分析点击事件，生成 segments
│  - 点击合并         │
│  - 边界约束         │
│  - 缩放范围限制     │
└──────────┬──────────┘
           ↓
┌─────────────────────┐
│    ZoomTimeline     │  管理 segments，查询时间点状态
│  [AutoZoomSegment]  │
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

### 1. AutoZoomSegment

表示一个缩放片段，包含时间范围、焦点和三阶段动画。支持静态中心和跟随模式。

```swift
struct AutoZoomSegment: Equatable, Identifiable {
    let id: UUID
    let timeRange: ClosedRange<TimeInterval>
    let focusCenter: CGPoint  // Normalized (0-1), 初始点击位置
    let zoomScale: CGFloat
    let easing: EasingCurve
    
    // MARK: - Animation Phases (25% + 50% + 25%)
    
    var zoomInDuration: TimeInterval { duration * 0.25 }
    var holdDuration: TimeInterval { duration * 0.50 }
    var zoomOutDuration: TimeInterval { duration * 0.25 }
    
    // MARK: - State Query
    
    /// 静态中心模式 (AC-FU-01)
    func state(at time: TimeInterval) -> ZoomState?
    
    /// 跟随模式 (AC-FU-02)
    func state(
        at time: TimeInterval,
        cursorPosition: CGPoint?,
        followCursor: Bool,
        smoothing: Double
    ) -> ZoomState? {
        // 如果 followCursor = true，使用 cursorPosition 作为中心
        // 并应用边界约束 (AC-FU-03)
    }
    
    // MARK: - Boundary Constraints (AC-FU-03)
    
    private func constrainedCenter(for cursor: CGPoint, at scale: CGFloat) -> CGPoint {
        // 确保缩放后可视区域不超出画面边界
    }
    
    // MARK: - Factory Methods
    
    static func fromClick(_ click: ClickEvent, duration: TimeInterval, zoomScale: CGFloat) -> AutoZoomSegment
    static func fromClicks(_ clicks: [ClickEvent], ...) -> AutoZoomSegment
}
```

### 2. ZoomSegmentGenerator

从点击事件生成 segments，处理合并和边界约束。

```swift
final class ZoomSegmentGenerator {
    
    struct Config {
        let defaultDuration: TimeInterval = 1.2      // AC-TR-01
        let defaultZoomScale: CGFloat = 2.0
        let clickMergeTime: TimeInterval = 0.3       // AC-TR-03
        let clickMergeDistancePixels: CGFloat = 100  // AC-TR-03
        let segmentMergeGap: TimeInterval = 0.3      // AC-AN-03
        let segmentMergeDistance: CGFloat = 0.05     // AC-AN-03
        let minZoomScale: CGFloat = 1.0              // AC-FR-03
        let maxZoomScale: CGFloat = 6.0              // AC-FR-03
        let easing: EasingCurve = .easeInOut
    }
    
    func generate(from session: CursorTrackSession, screenSize: CGSize) -> [AutoZoomSegment] {
        // 1. 合并相邻点击 (AC-TR-03)
        // 2. 为每组点击生成 segment
        // 3. 合并相邻 segments (AC-AN-03)
        // 4. 应用边界约束 (AC-FR-02)
    }
}
```

### 3. ZoomTimeline

管理 segments 并提供时间点状态查询，支持跟随模式。

```swift
struct ZoomTimeline {
    let segments: [AutoZoomSegment]
    let duration: TimeInterval
    
    /// 静态中心模式 (AC-FU-01)
    func state(at time: TimeInterval) -> ZoomState
    
    /// 跟随模式 (AC-FU-02)
    func state(
        at time: TimeInterval,
        cursorPosition: CGPoint?,
        followCursor: Bool,
        smoothing: Double
    ) -> ZoomState {
        // 查找当前活跃的 segment 并返回其状态
        // 如果 followCursor = true，传递 cursorPosition 到 segment
    }
    
    func isZoomActive(at time: TimeInterval) -> Bool
    
    // Statistics
    var segmentCount: Int
    var totalZoomTime: TimeInterval
    var zoomPercentage: Double
    
    // Factory
    static func from(session: CursorTrackSession, screenSize: CGSize, config: Config) -> ZoomTimeline
}
```

### 4. ZoomRenderer

渲染缩放后的帧。

```swift
final class ZoomRenderer {
    
    func renderFrame(
        source: CGImage,
        scale: CGFloat,
        center: CGPoint,
        outputSize: CGSize
    ) -> CGImage? {
        // 1. 计算裁剪区域
        // 2. 裁剪源图像
        // 3. 缩放到输出尺寸
    }
    
    func calculateCropRect(
        scale: CGFloat,
        center: CGPoint,
        sourceSize: CGSize
    ) -> CGRect {
        // 计算裁剪矩形，注意 Y 轴坐标转换
        // CGImage: Y=0 在底部
        // Normalized: Y=0 在顶部
    }
}
```

## 算法详解

### 点击合并算法 (AC-TR-03)

```swift
func mergeClicks(_ clicks: [ClickEvent], screenSize: CGSize) -> [[ClickEvent]] {
    let sorted = clicks.sorted { $0.timestamp < $1.timestamp }
    let normalizedDistance = 100.0 / max(screenSize.width, screenSize.height)
    
    var groups: [[ClickEvent]] = []
    var currentGroup: [ClickEvent] = [sorted[0]]
    
    for i in 1..<sorted.count {
        let current = sorted[i]
        let previous = currentGroup.last!
        
        let timeDiff = current.timestamp - previous.timestamp
        let distance = hypot(
            current.position.x - previous.position.x,
            current.position.y - previous.position.y
        )
        
        if timeDiff < 0.3 && distance < normalizedDistance {
            currentGroup.append(current)
        } else {
            groups.append(currentGroup)
            currentGroup = [current]
        }
    }
    groups.append(currentGroup)
    
    return groups
}
```

### 边界约束算法 (AC-FR-02)

```swift
func applyBoundaryConstraints(_ segment: AutoZoomSegment) -> AutoZoomSegment {
    let scale = segment.zoomScale
    guard scale > 1.0 else { return segment }
    
    // 计算可视区域尺寸
    let visibleWidth = 1.0 / scale
    let visibleHeight = 1.0 / scale
    let halfWidth = visibleWidth / 2
    let halfHeight = visibleHeight / 2
    
    // 约束中心点
    let constrainedX = max(halfWidth, min(1.0 - halfWidth, segment.focusCenter.x))
    let constrainedY = max(halfHeight, min(1.0 - halfHeight, segment.focusCenter.y))
    
    return AutoZoomSegment(
        timeRange: segment.timeRange,
        focusCenter: CGPoint(x: constrainedX, y: constrainedY),
        zoomScale: segment.zoomScale,
        easing: segment.easing
    )
}
```

### 三阶段动画算法 (AC-AN-01)

```swift
func state(at time: TimeInterval) -> ZoomState? {
    let relativeTime = time - startTime
    
    if relativeTime < zoomInDuration {
        // Zoom In (25%)
        let progress = relativeTime / zoomInDuration
        let easedProgress = easing.value(at: progress)
        let scale = 1.0 + (zoomScale - 1.0) * CGFloat(easedProgress)
        return ZoomState(scale: scale, center: focusCenter, phase: .zoomIn)
        
    } else if relativeTime < zoomInDuration + holdDuration {
        // Hold (50%)
        return ZoomState(scale: zoomScale, center: focusCenter, phase: .hold)
        
    } else {
        // Zoom Out (25%)
        let zoomOutStart = zoomInDuration + holdDuration
        let progress = (relativeTime - zoomOutStart) / zoomOutDuration
        let easedProgress = easing.value(at: progress)
        let scale = zoomScale - (zoomScale - 1.0) * CGFloat(easedProgress)
        return ZoomState(scale: scale, center: focusCenter, phase: .zoomOut)
    }
}
```

## 配置项

### ZoomSegmentGenerator.Config

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `defaultDuration` | TimeInterval | 1.2 | 默认 segment 时长 |
| `defaultZoomScale` | CGFloat | 2.0 | 默认缩放倍数 |
| `clickMergeTime` | TimeInterval | 0.3 | 点击合并时间阈值 |
| `clickMergeDistancePixels` | CGFloat | 100 | 点击合并距离阈值 (px) |
| `segmentMergeGap` | TimeInterval | 0.3 | segment 合并间隔阈值 |
| `segmentMergeDistance` | CGFloat | 0.05 | segment 合并距离阈值 |
| `minZoomScale` | CGFloat | 1.0 | 最小缩放倍数 |
| `maxZoomScale` | CGFloat | 6.0 | 最大缩放倍数 |
| `easing` | EasingCurve | .easeInOut | 缓动曲线 |

### AutoZoomSettings

| 参数 | 类型 | 范围 | 默认值 | 说明 |
|------|------|------|--------|------|
| `isEnabled` | Bool | - | true | 是否启用 Auto Zoom |
| `zoomLevel` | CGFloat | 1.0-6.0 | 2.0 | 缩放倍数 |
| `duration` | TimeInterval | 0.6-3.0 | 1.2 | 总 segment 时长 |
| `easing` | EasingCurve | - | .easeInOut | 缓动曲线 |
| `followCursor` | Bool | - | true | 跟随模式 (AC-FU-01, AC-FU-02) |
| `cursorSmoothing` | Double | 0.1-0.5 | 0.2 | 跟随平滑度 |
| `cursorScale` | CGFloat | 1.0-3.0 | 1.6 | 高亮缩放倍数 (AC-CE-01) |
| `cursorAutoHide` | Bool | - | false | 自动隐藏（待实现）|

## 坐标系统

### 归一化坐标
- X: 0 = 左边, 1 = 右边
- Y: 0 = 顶部, 1 = 底部
- 用于：`focusCenter`, `position` 等

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
- 预计算 ZoomTimeline，导出时直接查询
- 二分查找活跃 segment（大数据量时）

## 测试策略

### 单元测试覆盖

| 组件 | 测试数 | 覆盖重点 |
|------|--------|----------|
| AutoZoomSegment | 18 | 三阶段动画、合并逻辑、跟随模式 |
| ZoomSegmentGenerator | 13 | 点击合并、边界约束、缩放限制 |
| ZoomTimeline | 12 | 状态查询、统计计算 |
| AutoZoomSettings | 9 | 值范围、预设 |

### 验证 AC

| AC | 测试方法 |
|----|----------|
| AC-TR-01 | `test_should_create_segment_for_single_click` |
| AC-TR-02 | `test_should_return_empty_segments_when_no_clicks` |
| AC-TR-03 | `test_should_merge_rapid_clicks_within_300ms` |
| AC-FR-02 | `test_should_constrain_focus_when_click_at_corner` |
| AC-FR-03 | `test_should_clamp_zoom_scale_to_maximum` |
| AC-AN-01 | `test_should_have_correct_phase_durations` |
| AC-AN-03 | `test_should_merge_adjacent_segments_when_close` |
| AC-FU-01 | `test_should_use_focus_center_when_follow_disabled` |
| AC-FU-02 | `test_should_follow_cursor_when_enabled` |
| AC-FU-03 | `test_should_constrain_center_when_following_at_corner` |

## 文件结构

```
Features/AutoZoom/
├── Domain/Models/
│   ├── AutoZoomSegment.swift      # Segment 数据模型
│   ├── ZoomTimeline.swift         # 时间线管理
│   ├── AutoZoomSettings.swift     # 配置
│   └── EasingCurve.swift          # 缓动曲线
├── Infrastructure/
│   ├── ZoomSegmentGenerator.swift # Segment 生成器
│   └── ZoomRenderer.swift         # 帧渲染
├── ViewModels/
│   └── AutoZoomViewModel.swift
└── Views/
    └── AutoZoomSettingsView.swift
```

## 相关文档

- [功能规格](./functional-spec.md)
- [UI 规格](./ui-spec.md)
