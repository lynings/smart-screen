# Auto Zoom - 功能规格

> **层级**: L3 - 规格定义（How）  
> **优先级**: P2 - 体验增强  
> **状态**: ✅ 已实现 (v4.0 - 智能行为分析)  
> **关联**: [产品愿景](../../01-strategy-and-vision/product-vision.md)

## 功能概述

### 功能描述
根据用户行为智能决定何时放大画面。系统会：
1. **等待光标稳定**：点击后观察光标是否在某区域停留超过 0.5s
2. **抑制频繁操作**：高频点击或大跨度移动时保持正常视图
3. **平滑切换**：大跨度移动时先 zoom out 到 1.0x，等待稳定后再 zoom in

### 业务背景
- **需求来源**：Screen Studio 核心差异化功能
- **解决的核心问题**：全屏录制时操作细节不够突出
- **预期效果**：自动突出重点，避免频繁跳动，无需手动添加关键帧

## 功能范围

### 已实现范围 (v4.0 智能行为分析)
- ✅ **稳定触发**（AC-ST-01）：光标停留 > 0.5s 后触发缩放
- ✅ **频率抑制**（AC-ST-02）：高频点击（> 3次/秒）时不缩放
- ✅ **跨度检测**（AC-ST-03）：大跨度移动（> 25% 屏幕）时先 zoom out
- ✅ **冷却时间**（AC-ST-04）：zoom out 后等待 0.3s 再允许新缩放
- ✅ 边界约束（AC-FR-02）
- ✅ 缩放范围限制（AC-FR-03：1.0x - 6.0x）
- ✅ 平滑缓动（AC-AN-02：ease-in-out）
- ✅ 预设支持（Subtle/Normal/Dramatic）
- ✅ 与光标增强效果集成
- ✅ 导出时应用效果

### 待实现范围 (后续迭代)
- ⏳ 游标自动隐藏（cursorAutoHide）- 需要复杂的视频处理
- ⏳ 实时预览
- ⏳ 手动编辑（时间轴 UI）
- ⏳ 竖屏模式焦点调整

## 用户故事

### US-1：智能自动缩放 ✅ 已实现
**作为** 用户  
**我希望** 视频在我聚焦某区域时自动放大  
**以便** 观众能看清操作细节，同时避免画面频繁跳动

**验收标准**：
- [x] 光标停留 0.5s 后才触发缩放（AC-ST-01）
- [x] 放大倍数可配置（1.0x-6.0x）
- [x] 缩放过渡自然（基于 Easing 曲线）
- [x] 支持开/关此功能

### US-2：频繁操作时保持稳定 ✅ 已实现
**作为** 用户  
**我希望** 快速点击或大范围移动时画面保持稳定  
**以便** 避免眩晕感，保持观看舒适

**验收标准**：
- [x] 高频点击（> 3次/秒）时不缩放（AC-ST-02）
- [x] 大跨度移动时先 zoom out（AC-ST-03）
- [x] zoom out 后有冷却时间（AC-ST-04）

### US-3：调整缩放参数 ✅ 已实现
**作为** 用户  
**我希望** 调整缩放强度和持续时间  
**以便** 适应不同内容风格

**验收标准**：
- [x] 缩放倍数可调（1.0x-6.0x）
- [x] 总时长可调（0.6s-3.0s）
- [x] 预设快捷选择（Subtle/Normal/Dramatic）
- [x] Easing 曲线可选

## 已实现的技术规格 (v4.0)

### 架构组件

```
CursorTrackSession (输入)
        ↓
SmartZoomBehaviorAnalyzer (行为分析 + 状态机)
        ↓
SmartZoomTimeline [SmartZoomKeyframe] (关键帧时间线)
        ↓
ZoomRenderer (帧渲染)
        ↓
CombinedEffectsExporter (导出集成)
```

### 状态机

```
┌─────────────────────────────────────────────────────────┐
│                     Smart Zoom 状态机                    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   idle ──点击──→ observing ──停留0.5s──→ zoomingIn     │
│     ↑               │                        │          │
│     │               │快速移动                │          │
│     └───────────────┘                        ↓          │
│                                           zoomed       │
│     ↑                                        │          │
│     │   cooldown ←──zoom out完成──← zoomingOut         │
│     │      │                           ↑               │
│     │      └─────0.3s后───→ observing  │大跨度移动     │
│     │                                   │               │
│     └───────────────────────────────────┘               │
└─────────────────────────────────────────────────────────┘
```

### 核心模型

#### ZoomBehaviorState
```swift
enum ZoomBehaviorState {
    case idle                    // 正常视图
    case observing(since, pos)   // 观察中，等待稳定
    case zoomingIn(...)          // 正在放大
    case zoomed(center, scale)   // 已放大
    case zoomingOut(...)         // 正在缩小
    case cooldown(since, pos)    // 冷却中
}
```

#### SmartZoomKeyframe
```swift
struct SmartZoomKeyframe: Equatable {
    let time: TimeInterval
    let scale: CGFloat
    let center: CGPoint  // Normalized (0-1)
}
```

#### SmartZoomTimeline
```swift
struct SmartZoomTimeline {
    let keyframes: [SmartZoomKeyframe]
    let duration: TimeInterval
    
    func state(at time: TimeInterval) -> (scale: CGFloat, center: CGPoint)
}
```

#### ZoomBehaviorConfig
```swift
struct ZoomBehaviorConfig {
    let stabilizationTime: TimeInterval  // 0.5s
    let maxStableSpeed: CGFloat          // 0.3
    let stableAreaRadius: CGFloat        // 0.05
    let largeMovementThreshold: CGFloat  // 0.25
    let maxClickFrequency: Double        // 3.0
    let cooldownDuration: TimeInterval   // 0.3s
    let zoomInDuration: TimeInterval     // 0.4s
    let zoomOutDuration: TimeInterval    // 0.3s
    let targetScale: CGFloat             // 2.0
    let easing: EasingCurve
}
```

### 配置参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `stabilizationTime` | 0.5s | 光标稳定时间阈值 |
| `maxStableSpeed` | 0.3 | 最大稳定速度（归一化） |
| `stableAreaRadius` | 0.05 | 稳定区域半径（归一化） |
| `largeMovementThreshold` | 0.25 | 大跨度移动阈值（屏幕比例） |
| `maxClickFrequency` | 3.0 | 最大点击频率（次/秒） |
| `cooldownDuration` | 0.3s | zoom out 后冷却时间 |
| `zoomInDuration` | 0.4s | 放大动画时长 |
| `zoomOutDuration` | 0.3s | 缩小动画时长 |
| `targetScale` | 2.0x | 目标缩放倍数 |

### 预设配置

| 预设 | 缩放倍数 | 总时长 |
|------|----------|--------|
| Subtle | 1.5x | 1.0s |
| Normal | 2.0x | 1.2s |
| Dramatic | 2.5x | 1.5s |

## 业务规则

### BR-1：稳定触发 (AC-ST-01) ✅ 已实现
- 点击后进入观察状态
- 光标在稳定区域（半径 5%）停留 > 0.5s 才触发缩放
- 防止误触和瞬时操作

### BR-2：频率抑制 (AC-ST-02) ✅ 已实现
- 监控最近 1 秒内的点击次数
- 点击频率 > 3 次/秒时，重置观察状态
- 保持正常视图，避免频繁缩放

### BR-3：大跨度处理 (AC-ST-03) ✅ 已实现
- 已缩放状态下检测到大跨度移动（> 25% 屏幕）
- 先 zoom out 到 1.0x
- 再进入冷却状态，等待新的稳定

### BR-4：冷却机制 (AC-ST-04) ✅ 已实现
- zoom out 完成后进入 0.3s 冷却期
- 冷却期间不响应新的缩放触发
- 冷却结束后进入观察状态

### BR-5：边界约束 (AC-FR-02) ✅ 已实现
- 缩放后可视区域不超出画面边界
- 边缘点击自动调整中心点
- 使用 `clamp` 确保裁剪区域有效

### BR-6：缩放范围限制 (AC-FR-03) ✅ 已实现
- 最小缩放：1.0x
- 最大缩放：6.0x
- 超出范围自动裁剪

### BR-7：平滑插值 (AC-AN-02) ✅ 已实现
- 关键帧之间使用 ease-in-out 插值
- 缩放和位置同时平滑过渡
- 避免画面跳动

### BR-8：高亮缩放 (AC-CE-01) ✅ 已实现
- 缩放时高亮半径按 `cursorScale` 放大
- 保持高亮效果在缩放画面中清晰可见
- 默认放大 1.6 倍

## 验收标准

### 功能验收
- [x] 光标稳定后才缩放 (AC-ST-01)
- [x] 高频点击时不缩放 (AC-ST-02)
- [x] 大跨度移动先 zoom out (AC-ST-03)
- [x] zoom out 后有冷却期 (AC-ST-04)
- [x] 边界约束生效 (AC-FR-02)
- [x] 平滑插值过渡 (AC-AN-02)
- [x] 导出界面显示 Auto Zoom 选项
- [x] 与光标增强效果正确集成

### 性能要求
- **分析耗时**：瞬时（< 100ms）
- **渲染速度**：与标准导出相当
- **内存占用**：单帧处理，无累积

## 测试覆盖

### 单元测试 (v4.0)
- `SmartZoomBehaviorAnalyzerTests`: 9 个测试 ✅
  - 空 session 返回空时间线
  - 单次点击不立即缩放
  - 稳定后触发缩放
  - 大跨度移动触发 zoom out
  - 高频点击抑制缩放
  - 关键帧插值
  - 边界约束
- `ZoomBehaviorStateTests`: 6 个测试 ✅
- `ZoomBehaviorConfigTests`: 2 个测试 ✅
- `ActivityEventTests`: 2 个测试 ✅

### 集成测试场景
- TC-1：单次稳定点击缩放
- TC-2：快速移动不缩放
- TC-3：大跨度移动先 zoom out
- TC-4：与光标高亮集成
- TC-5：空录制（无点击）
- TC-6：边缘点击（边界处理）
- TC-7：高频点击抑制
- TC-8：冷却期行为

## 文件结构

```
Features/AutoZoom/
├── Domain/
│   └── Models/
│       ├── EasingCurve.swift
│       ├── AutoZoomSettings.swift
│       ├── ZoomBehaviorState.swift    # v4.0 新增
│       └── (legacy: AutoZoomSegment, ZoomTimeline)
├── Infrastructure/
│   ├── SmartZoomBehaviorAnalyzer.swift  # v4.0 新增
│   ├── ZoomRenderer.swift
│   └── (legacy: ZoomSegmentGenerator, etc.)
├── ViewModels/
│   └── AutoZoomViewModel.swift
└── Views/
    └── AutoZoomSettingsView.swift

Features/Export/Infrastructure/
└── CombinedEffectsExporter.swift  (集成导出器，使用 SmartZoomBehaviorAnalyzer)
```

## 相关文档

- [UI 规格](./ui-spec.md)
- [技术设计](./technical-spec.md)
- [光标增强规格](../cursor-enhancement/functional-spec.md)
