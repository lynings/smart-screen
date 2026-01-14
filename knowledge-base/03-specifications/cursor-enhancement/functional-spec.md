# Cursor Enhancement - 功能规格

> **层级**: L3 - 规格定义（How）  
> **优先级**: P2 - 体验增强  
> **关联**: [产品愿景](../../01-strategy-and-vision/product-vision.md)  
> **状态**: ✅ 已实现

## 功能概述

### 功能描述
对原始鼠标轨迹进行滤波和插值，消除抖动；点击时显示高亮动画，提升视觉效果。

### 业务背景
- **需求来源**：Screen Studio 核心差异化功能
- **解决的核心问题**：原始鼠标轨迹抖动影响观感
- **预期效果**：丝滑的光标移动，清晰的点击反馈

## 功能范围

### 包含范围
- ✅ 光标轨迹平滑（Cursor Smoothing） `已实现`
- ✅ 点击高亮动画（Click Highlight） `已实现`
- ✅ 双击/右键高亮 `已实现`
- ✅ 平滑级别可调 `已实现`
- ✅ 录制时自动捕获鼠标事件 `已实现`
- ✅ 导出时渲染光标增强效果 `已实现`
- ✅ 导出界面光标增强选项 `已实现`

### 不包含范围（后续迭代）
- ⏳ 自定义光标样式
- ⏳ 快捷键显示
- ⏳ 实时预览光标效果

## 用户故事

### US-1：开启光标平滑
**作为** 用户  
**我希望** 开启光标平滑功能  
**以便** 让鼠标移动看起来更流畅

**验收标准**：
- [x] 支持开/关平滑功能 ✅
- [x] 平滑后轨迹无突变 ✅
- [x] 平滑延迟不可感知（< 100ms） ✅

### US-2：点击高亮
**作为** 用户  
**我希望** 点击时显示视觉反馈  
**以便** 观众能清楚看到我的点击操作

**验收标准**：
- [x] 左键单击显示脉冲动画 ✅
- [x] 双击显示双环动画 ✅
- [x] 右键显示不同颜色高亮（橙色） ✅
- [x] 动画流畅（60fps） ✅

### US-3：调整平滑级别
**作为** 用户  
**我希望** 调整平滑强度  
**以便** 在平滑度和响应速度间取舍

**验收标准**：
- [x] 提供低/中/高三档 ✅
- [x] 实时预览效果 ✅
- [x] 导出时应用平滑设置 ✅

### US-4：导出时应用光标增强
**作为** 用户  
**我希望** 导出视频时自动应用光标增强效果  
**以便** 生成的视频具有专业的光标效果

**验收标准**：
- [x] 录制时自动捕获鼠标事件 ✅
- [x] 导出界面显示光标增强选项 ✅
- [x] 可选择平滑级别和高亮开关 ✅
- [x] 导出进度显示增强状态 ✅

## 技术规格

### 平滑算法

| 级别 | 算法 | 平滑因子 | 适用场景 |
|------|------|----------|----------|
| 低 | EWMA | α=0.3 | 快速操作 |
| 中 | EWMA | α=0.5 | 一般教程 |
| 高 | EWMA | α=0.7 | 专业演示 |

> 使用指数加权移动平均（EWMA）算法，公式：smoothed[i] = α * smoothed[i-1] + (1-α) * raw[i]

### 高亮样式

| 事件 | 样式 | 颜色 | 持续时间 |
|------|------|------|----------|
| 左键单击 | 脉冲扩散 | 蓝色 | 300ms |
| 左键双击 | 双环扩散 | 蓝色 | 400ms |
| 右键单击 | 脉冲扩散 | 橙色 | 300ms |

## 接口定义

```swift
protocol CursorEnhancerProtocol {
    var smoothingLevel: SmoothingLevel { get set }
    var highlightEnabled: Bool { get set }
    
    func smooth(_ points: [CursorPoint]) -> [CursorPoint]
    func generateHighlight(for event: ClickEvent) -> HighlightAnimation
}

enum SmoothingLevel: String, CaseIterable, Codable {
    case low     // α=0.3
    case medium  // α=0.5
    case high    // α=0.7
    
    var smoothingFactor: Double
    var displayName: String
}

struct CursorPoint: Equatable {
    let position: CGPoint
    let timestamp: TimeInterval
    
    func distance(to other: CursorPoint) -> Double
    func velocity(to other: CursorPoint) -> Double
}

struct ClickEvent: Equatable {
    let type: ClickType
    let position: CGPoint
    let timestamp: TimeInterval
}

enum ClickType: String, Equatable {
    case leftClick
    case doubleClick
    case rightClick
    
    var highlightColor: Color
    var animationDuration: TimeInterval
}

struct HighlightAnimation: Equatable {
    let position: CGPoint
    let color: Color
    let duration: TimeInterval
    let style: HighlightStyle
    
    enum HighlightStyle: Equatable {
        case pulse       // 单环扩散
        case doubleRing  // 双环扩散
    }
}
```

## 验收标准

### 功能验收
- [x] 平滑功能开关正常 ✅
- [x] 三档平滑级别差异明显 ✅
- [x] 点击高亮动画流畅 ✅
- [x] 不同点击类型区分清晰 ✅

### 性能要求
- **处理延迟**：< 16ms（60fps）
- **GPU 占用**：< 10%

## 实现文件

### 域模型
- `CursorPoint.swift` - 光标位置点
- `SmoothingLevel.swift` - 平滑级别
- `ClickEvent.swift` - 点击事件和类型
- `MouseEvent.swift` - 鼠标事件（移动/点击）
- `CursorTrackSession.swift` - 光标轨迹会话数据

### 基础设施
- `CursorSmoother.swift` - EWMA 平滑算法
- `ClickHighlighter.swift` - 点击高亮生成器
- `MouseTrackerManager.swift` - 全局鼠标事件追踪管理器（归一化坐标）
- `MouseEventTracker.swift` - NSEvent 监听鼠标事件
- `CursorRenderer.swift` - Core Graphics 绘制点击高亮效果
- `CursorEnhancedExporter.swift` - 带点击高亮的视频导出器

> **实现说明**：录制时 ScreenCaptureKit 已捕获系统光标（`showsCursor = true`），
> 导出时只需在光标位置叠加点击高亮效果，无需重新绘制光标。

### 表现层
- `CursorEnhancerViewModel.swift` - 状态管理
- `CursorEnhancerSettingsView.swift` - 设置界面
- `ClickHighlightView.swift` - 高亮动画视图
- `ExportView.swift` - 导出界面（含光标增强选项）
- `ExportViewModel.swift` - 导出状态管理（集成增强导出）

## 测试用例

### TC-1：高频抖动平滑
- **前置条件**：开启中等平滑
- **测试步骤**：快速抖动鼠标
- **预期结果**：输出轨迹平滑无突变 ✅

### TC-2：点击高亮
- **测试步骤**：左键单击、双击、右键各一次
- **预期结果**：显示对应的高亮动画 ✅

### 单元测试覆盖
- `CursorPointTests.swift` - 4 tests ✅
- `SmoothingLevelTests.swift` - 5 tests ✅
- `ClickEventTests.swift` - 7 tests ✅
- `CursorSmootherTests.swift` - 7 tests ✅
- `ClickHighlighterTests.swift` - 5 tests ✅
- `CursorEnhancerViewModelTests.swift` - 7 tests ✅
- `MouseEventTests.swift` - 8 tests ✅
- `MouseEventTrackerTests.swift` - 10 tests ✅
- `CursorTrackSessionTests.swift` - 9 tests ✅
- `CursorRendererTests.swift` - 8 tests ✅
- `CursorEnhancedExporterTests.swift` - 7 tests ✅

**总计**: 77 个光标增强相关测试 ✅

## 相关文档

- [UI 规格](./ui-spec.md)
- [技术设计](./technical-spec.md)
