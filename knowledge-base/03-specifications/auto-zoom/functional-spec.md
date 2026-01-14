# Auto Zoom 2.0 - 功能规格

> **层级**: L3 - 规格定义（How）  
> **优先级**: P2 - 体验增强  
> **状态**: ✅ 已实现 (v4.0 - 连续缩放模式)  
> **关联**: [产品愿景](../../01-strategy-and-vision/product-vision.md)

## 功能概述

### 功能描述
Auto Zoom 2.0 采用**连续状态机 + 关键帧动画**架构，实现智能缩放。核心特性：
- **动态缩放级别**：边缘/角落放大更多，中心放大较少
- **持续跟随模式**：点击后跟随光标，3秒无移动才缩回
- **智能过渡**：大距离移动先缩回再过渡，小距离平滑跟随
- **频繁操作防抖**：在小区域内频繁点击时保持缩放不动
- **键盘事件响应**：检测到键盘输入时自动缩回正常大小

### 业务背景
- **需求来源**：Screen Studio 核心差异化功能
- **解决的核心问题**：全屏录制时操作细节不够突出
- **预期效果**：自动突出重点，保持流畅自然的缩放体验

## 功能范围

### 已实现范围 (v4.0)

#### 核心功能
- ✅ 点击触发缩放
- ✅ 动态缩放级别（边缘大、中心小）
- ✅ 持续跟随光标 + 3秒超时回归
- ✅ 大距离移动：先缩回 → 平移 → 再放大
- ✅ 频繁操作防抖
- ✅ 键盘事件触发缩回
- ✅ 平滑过渡动画（关键帧插值）

#### 配置选项
- ✅ 基础缩放级别（1.0x - 6.0x）
- ✅ 动态缩放开关
- ✅ 光标静止超时（1-10秒）
- ✅ 键盘缩回开关
- ✅ 高亮缩放倍数
- ✅ 预设支持（Subtle/Normal/Dramatic）

### 待实现范围 (后续迭代)
- ⏳ 实时预览
- ⏳ 手动编辑（时间轴 UI）
- ⏳ 游标自动隐藏

## 用户故事

### US-1：智能缩放到操作区域
**作为** 用户  
**我希望** 视频自动放大到我操作的区域  
**以便** 观众能看清操作细节

**验收标准**：
- [x] 点击时自动平滑放大
- [x] 边缘/角落位置缩放更大（可视区域小）
- [x] 中心位置缩放较小（可视区域大）
- [x] 支持开/关此功能

### US-2：持续跟随光标
**作为** 用户  
**我希望** 放大后画面能跟随光标移动  
**以便** 始终能看到当前操作位置

**验收标准**：
- [x] 放大后持续跟随光标
- [x] 光标静止3秒后自动缩回
- [x] 跟随时边界约束正常

### US-3：流畅的过渡动画
**作为** 用户  
**我希望** 缩放和过渡动画流畅自然  
**以便** 观看体验不会突兀

**验收标准**：
- [x] 大距离移动先缩回再过渡
- [x] 小距离移动平滑跟随
- [x] 频繁点击时保持缩放稳定

### US-4：键盘输入时缩回
**作为** 用户  
**我希望** 输入文字时画面自动缩回  
**以便** 能看到更多输入上下文

**验收标准**：
- [x] 检测到键盘输入时缩回
- [x] 可配置开关此行为

## 技术规格 (v4.0)

### 架构组件

```
Events (Mouse + Keyboard)
         ↓
┌─────────────────────────────┐
│  ContinuousZoomController   │  状态机 + 决策引擎
│  - 管理缩放状态              │
│  - 处理事件触发              │
│  - 决策缩放/过渡/回归        │
└─────────────────────────────┘
         ↓
┌─────────────────────────────┐
│   DynamicZoomCalculator     │  动态缩放计算
│  - 根据位置计算缩放级别      │
│  - 边缘大、中心小            │
└─────────────────────────────┘
         ↓
┌─────────────────────────────┐
│   ContinuousZoomTimeline    │  连续时间线
│  - 关键帧存储 [ZoomKeyframe]│
│  - 任意时间点插值查询        │
└─────────────────────────────┘
         ↓
       ZoomRenderer → CombinedEffectsExporter
```

### 核心模型

#### ZoomKeyframe
```swift
struct ZoomKeyframe: Equatable {
    let time: TimeInterval
    let scale: CGFloat
    let center: CGPoint
    let easing: EasingCurve
    
    static func interpolate(from:to:at:) -> ZoomKeyframe
}
```

#### ContinuousZoomTimeline
```swift
struct ContinuousZoomTimeline {
    private let keyframes: [ZoomKeyframe]
    
    func state(at time: TimeInterval) -> ContinuousZoomState
    var isEmpty: Bool
    var count: Int
    var duration: TimeInterval
}
```

#### AutoZoomSettings (v4.0)
```swift
struct AutoZoomSettings: Codable, Equatable {
    // 核心设置
    var isEnabled: Bool              // 开关
    var zoomLevel: CGFloat           // 基础缩放级别 (1.0-6.0)
    var easing: EasingCurve          // 缓动曲线
    
    // 动画时长
    var zoomInDuration: TimeInterval  // 放大动画时长 (0.1-1.0)
    var zoomOutDuration: TimeInterval // 缩小动画时长 (0.1-1.0)
    var panDuration: TimeInterval     // 平移动画时长 (0.1-1.0)
    
    // 连续缩放行为
    var idleTimeout: TimeInterval     // 静止超时 (1-10秒)
    var largeDistanceThreshold: CGFloat // 大距离阈值 (0.1-0.5)
    var dynamicZoomEnabled: Bool      // 动态缩放开关
    
    // 防抖
    var debounceAreaThreshold: CGFloat // 防抖区域阈值
    var debounceTimeWindow: TimeInterval // 防抖时间窗口
    
    // 键盘
    var zoomOutOnKeyboard: Bool       // 键盘时缩回
    
    // 高亮
    var cursorScale: CGFloat          // 高亮缩放 (1.0-3.0)
    
    // 预设
    static let subtle: AutoZoomSettings   // 1.5x, 4秒超时
    static let normal: AutoZoomSettings   // 2.0x, 3秒超时
    static let dramatic: AutoZoomSettings // 2.5x, 2.5秒超时
}
```

### 配置参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `zoomLevel` | 2.0x | 1.0-6.0 | 基础缩放级别 |
| `zoomInDuration` | 0.3s | 0.1-1.0 | 放大动画时长 |
| `zoomOutDuration` | 0.4s | 0.1-1.0 | 缩小动画时长 |
| `panDuration` | 0.3s | 0.1-1.0 | 平移动画时长 |
| `idleTimeout` | 3.0s | 1-10 | 静止超时 |
| `largeDistanceThreshold` | 0.3 | 0.1-0.5 | 大距离阈值 |
| `dynamicZoomEnabled` | true | - | 动态缩放开关 |
| `zoomOutOnKeyboard` | true | - | 键盘时缩回 |
| `cursorScale` | 1.6x | 1.0-3.0 | 高亮放大倍数 |

### 预设配置

| 预设 | 缩放级别 | 静止超时 | 适用场景 |
|------|----------|----------|----------|
| Subtle | 1.5x | 4秒 | 轻度提示 |
| Normal | 2.0x | 3秒 | 标准演示 |
| Dramatic | 2.5x | 2.5秒 | 强调效果 |

## 业务规则

### BR-1：动态缩放级别
- 基础缩放级别 × 位置因子 = 实际缩放
- 边缘位置：因子 1.25（放大更多）
- 中心位置：因子 0.85（放大较少）
- 角落位置：额外 +10% 加成

### BR-2：持续跟随 + 超时回归
- 点击后进入缩放状态
- 跟随光标移动，应用边界约束
- 光标静止超过 `idleTimeout` 后缩回
- 键盘输入（如果启用）立即缩回

### BR-3：大距离过渡
- 当前位置到目标位置距离 > `largeDistanceThreshold`
- 执行：缩回 → 平移 → 放大
- 避免画面剧烈跳动

### BR-4：频繁操作防抖
- 在 `debounceTimeWindow` 内的多次点击
- 如果活动区域 < `debounceAreaThreshold`
- 保持当前缩放状态不变

### BR-5：键盘响应
- 检测到键盘按下事件
- 如果 `zoomOutOnKeyboard` 启用
- 触发缩回动画

### BR-6：边界约束
- 缩放后可视区域不超出画面边界
- 跟随时实时约束中心点
- 使用 `clamp` 确保裁剪区域有效

## 测试覆盖

### 单元测试 (v4.0)
- `DynamicZoomCalculatorTests`: 动态缩放计算 ✅
- `ZoomKeyframeTests`: 关键帧插值 ✅
- `ContinuousZoomTimelineTests`: 时间线查询 ✅
- `ContinuousZoomControllerTests`: 状态机逻辑 ✅
- `AutoZoomSettingsTests`: 配置验证 ✅

### 集成测试场景
- TC-1：边缘点击（动态缩放更大）
- TC-2：中心点击（动态缩放较小）
- TC-3：持续跟随（光标移动时中心跟随）
- TC-4：静止超时（3秒后缩回）
- TC-5：大距离过渡（先缩后放）
- TC-6：频繁点击防抖
- TC-7：键盘输入缩回
- TC-8：与光标高亮集成

## 文件结构

```
Features/AutoZoom/
├── Domain/
│   └── Models/
│       ├── EasingCurve.swift
│       ├── AutoZoomSettings.swift         # v4.0 更新
│       ├── ZoomKeyframe.swift             # v4.0 新增
│       ├── ContinuousZoomTimeline.swift   # v4.0 新增
│       └── (legacy: AutoZoomSegment, ZoomTimeline)
├── Infrastructure/
│   ├── ContinuousZoomController.swift     # v4.0 新增
│   ├── DynamicZoomCalculator.swift        # v4.0 新增
│   ├── KeyboardEventTracker.swift         # v4.0 新增
│   ├── ZoomRenderer.swift
│   └── (legacy: ZoomSegmentGenerator, etc.)
├── ViewModels/
│   └── AutoZoomViewModel.swift            # v4.0 更新
└── Views/
    └── AutoZoomSettingsView.swift         # v4.0 更新

Features/Export/Infrastructure/
└── CombinedEffectsExporter.swift          # v4.0 更新（使用 ContinuousZoomTimeline）
```

## 相关文档

- [技术设计](./technical-spec.md)
- [光标增强规格](../cursor-enhancement/functional-spec.md)
