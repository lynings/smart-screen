# Auto Zoom - 功能规格

> **层级**: L3 - 规格定义（How）  
> **优先级**: P2 - 体验增强  
> **状态**: ✅ 已实现 (v3.1 - 完整跟随模式)  
> **关联**: [产品愿景](../../01-strategy-and-vision/product-vision.md)

## 功能概述

### 功能描述
根据鼠标点击事件自动放大画面，使用三阶段动画（Zoom In → Hold → Zoom Out）突出用户操作重点。支持点击合并、边界约束、游标跟随和预设配置。

### 业务背景
- **需求来源**：Screen Studio 核心差异化功能
- **解决的核心问题**：全屏录制时操作细节不够突出
- **预期效果**：自动突出重点，无需手动添加关键帧

## 功能范围

### 已实现范围 (Phase 1-3)
- ✅ 点击触发缩放（AC-TR-01）
- ✅ 无点击不创建 segment（AC-TR-02）
- ✅ 快速点击合并（AC-TR-03：< 0.3s 且 < 100px）
- ✅ 以点击为中心（AC-FR-01）
- ✅ 边界约束（AC-FR-02）
- ✅ 缩放范围限制（AC-FR-03：1.0x - 6.0x）
- ✅ 三阶段动画（AC-AN-01：25% 放大 + 50% 保持 + 25% 缩小）
- ✅ 平滑缓动（AC-AN-02：ease-in-out）
- ✅ 相邻 segment 合并（AC-AN-03）
- ✅ 预设支持（Subtle/Normal/Dramatic）
- ✅ 与光标增强效果集成
- ✅ 导出时应用效果
- ✅ **跟随模式**（AC-FU-01, AC-FU-02：游标跟随缩放中心）
- ✅ **跟随边界约束**（AC-FU-03）
- ✅ **高亮缩放**（AC-CE-01：缩放时高亮效果放大）

### 待实现范围 (后续迭代)
- ⏳ 游标自动隐藏（cursorAutoHide）- 需要复杂的视频处理
- ⏳ 实时预览
- ⏳ 手动编辑（时间轴 UI）
- ⏳ 竖屏模式焦点调整

## 用户故事

### US-1：自动缩放到点击区域 ✅ 已实现
**作为** 用户  
**我希望** 视频自动放大到我点击的区域  
**以便** 观众能看清操作细节

**验收标准**：
- [x] 点击时自动平滑放大
- [x] 放大倍数可配置（1.0x-6.0x）
- [x] 缩放过渡自然（基于 Easing 曲线）
- [x] 支持开/关此功能

### US-2：调整缩放参数 ✅ 已实现
**作为** 用户  
**我希望** 调整缩放强度和持续时间  
**以便** 适应不同内容风格

**验收标准**：
- [x] 缩放倍数可调（1.0x-6.0x）
- [x] 总时长可调（0.6s-3.0s）
- [x] 预设快捷选择（Subtle/Normal/Dramatic）
- [x] Easing 曲线可选

### US-3：游标跟随缩放 ✅ 已实现
**作为** 用户  
**我希望** 缩放中心能跟随游标移动  
**以便** 保持操作区域始终可见

**验收标准**：
- [x] 跟随模式开关（AC-FU-01）
- [x] 跟随时平滑过渡（AC-FU-02）
- [x] 边界约束防止内容超出画面（AC-FU-03）
- [x] 高亮效果随缩放放大（AC-CE-01）

## 已实现的技术规格 (v3.1)

### 架构组件

```
CursorTrackSession (输入)
        ↓
ZoomSegmentGenerator (点击分析 + 合并)
        ↓
ZoomTimeline [AutoZoomSegment] (时间线)
        ↓
ZoomRenderer (帧渲染)
        ↓
CombinedEffectsExporter (导出集成)
```

### 核心模型

#### AutoZoomSegment
```swift
struct AutoZoomSegment: Equatable, Identifiable {
    let id: UUID
    let timeRange: ClosedRange<TimeInterval>
    let focusCenter: CGPoint  // Normalized (0-1)
    let zoomScale: CGFloat
    let easing: EasingCurve
    
    // 三阶段动画 (25% + 50% + 25%)
    var zoomInDuration: TimeInterval { duration * 0.25 }
    var holdDuration: TimeInterval { duration * 0.50 }
    var zoomOutDuration: TimeInterval { duration * 0.25 }
    
    func state(at time: TimeInterval) -> ZoomState?
}
```

#### ZoomTimeline
```swift
struct ZoomTimeline {
    let segments: [AutoZoomSegment]
    let duration: TimeInterval
    
    func state(at time: TimeInterval) -> ZoomState
    func isZoomActive(at time: TimeInterval) -> Bool
}
```

#### AutoZoomSettings
```swift
struct AutoZoomSettings: Codable, Equatable {
    var isEnabled: Bool
    var zoomLevel: CGFloat      // 1.0 - 6.0
    var duration: TimeInterval   // 0.6 - 3.0 (total segment duration)
    var easing: EasingCurve
    
    // Phase 2: 跟随模式
    var followCursor: Bool      // AC-FU-01, AC-FU-02
    var cursorSmoothing: Double // 0.1 - 0.5
    
    // Phase 3: 游标增强
    var cursorScale: CGFloat    // 1.0 - 3.0, 高亮放大倍数
    var cursorAutoHide: Bool    // 待实现
    
    // holdTime = duration * 0.5 (computed)
    
    // 预设
    static let subtle: AutoZoomSettings   // 1.5x, 1.0s
    static let normal: AutoZoomSettings   // 2.0x, 1.2s
    static let dramatic: AutoZoomSettings // 2.5x, 1.5s
}
```

### 配置参数 (AC-CF-01)

| 参数 | 默认值 | 范围 |
|------|--------|------|
| `defaultDuration` | 1.2s | 0.6s - 3.0s |
| `defaultZoomScale` | 2.0x | 1.0x - 6.0x |
| `easing` | easeInOut | linear/easeIn/easeOut/easeInOut |
| `followCursor` | true | true/false |
| `cursorSmoothing` | 0.2 | 0.1 - 0.5 |
| `cursorScale` | 1.6x | 1.0x - 3.0x |

### 预设配置

| 预设 | 缩放倍数 | 总时长 |
|------|----------|--------|
| Subtle | 1.5x | 1.0s |
| Normal | 2.0x | 1.2s |
| Dramatic | 2.5x | 1.5s |

## 业务规则

### BR-1：点击触发 ✅ 已实现
- 仅鼠标点击事件触发缩放
- 无点击 = 无缩放 segment
- 左键、右键、双击均可触发

### BR-2：点击合并 (AC-TR-03) ✅ 已实现
- 时间间隔 < 0.3s
- 空间距离 < 100px
- 合并后使用点击质心作为焦点

### BR-3：边界约束 (AC-FR-02) ✅ 已实现
- 缩放后可视区域不超出画面边界
- 边缘点击自动调整中心点
- 使用 `clamp` 确保裁剪区域有效

### BR-4：三阶段动画 (AC-AN-01) ✅ 已实现
- Zoom In：占 25% 时长，1.0x → 目标倍数
- Hold：占 50% 时长，保持目标倍数
- Zoom Out：占 25% 时长，目标倍数 → 1.0x

### BR-5：Segment 合并 (AC-AN-03) ✅ 已实现
- 相邻 segment 间隔 < 0.3s
- 焦点距离 < 50px (normalized ~0.05)
- 合并后取最大缩放倍数

### BR-6：缩放范围限制 (AC-FR-03) ✅ 已实现
- 最小缩放：1.0x
- 最大缩放：6.0x
- 超出范围自动裁剪

### BR-7：跟随模式 (AC-FU-01, AC-FU-02) ✅ 已实现
- 静态模式：焦点保持在初始点击位置
- 跟随模式：焦点跟随游标实时移动
- 跟随时应用边界约束（AC-FU-03）
- 平滑过渡避免画面跳动

### BR-8：高亮缩放 (AC-CE-01) ✅ 已实现
- 缩放时高亮半径按 `cursorScale` 放大
- 保持高亮效果在缩放画面中清晰可见
- 默认放大 1.6 倍

## 验收标准

### 功能验收
- [x] 自动识别点击热点 (AC-TR-01)
- [x] 无点击时无缩放 (AC-TR-02)
- [x] 快速点击合并 (AC-TR-03)
- [x] 边界约束生效 (AC-FR-02)
- [x] 三阶段动画平滑 (AC-AN-01, AC-AN-02)
- [x] 导出界面显示 Auto Zoom 选项
- [x] 与光标增强效果正确集成

### 性能要求
- **分析耗时**：瞬时（< 100ms）
- **渲染速度**：与标准导出相当
- **内存占用**：单帧处理，无累积

## 测试覆盖

### 单元测试 (Phase 1-3)
- `AutoZoomSegmentTests`: 18 个测试 ✅ (含跟随模式测试)
- `ZoomSegmentGeneratorTests`: 13 个测试 ✅
- `ZoomTimelineTests`: 12 个测试 ✅
- `AutoZoomSettingsTests`: 9 个测试 ✅
- `EasingCurveTests`: 8 个测试 ✅

### 集成测试场景
- TC-1：单次点击缩放
- TC-2：多点击合并
- TC-3：边缘点击（边界处理）
- TC-4：与光标高亮集成
- TC-5：空录制（无点击）
- TC-6：跟随模式（游标移动时中心跟随）
- TC-7：跟随边界约束（角落位置）
- TC-8：高亮缩放（缩放时高亮放大）

## 文件结构

```
Features/AutoZoom/
├── Domain/
│   └── Models/
│       ├── EasingCurve.swift
│       ├── AutoZoomSettings.swift
│       ├── AutoZoomSegment.swift      # v3.0 新增
│       └── ZoomTimeline.swift         # v3.0 新增
├── Infrastructure/
│   ├── ZoomSegmentGenerator.swift     # v3.0 新增
│   ├── ZoomRenderer.swift
│   └── (legacy: HotspotAnalyzer, etc.)
├── ViewModels/
│   └── AutoZoomViewModel.swift
└── Views/
    └── AutoZoomSettingsView.swift

Features/Export/Infrastructure/
└── CombinedEffectsExporter.swift  (集成导出器)
```

## 相关文档

- [UI 规格](./ui-spec.md)
- [技术设计](./technical-spec.md)
- [光标增强规格](../cursor-enhancement/functional-spec.md)
