# Recording Engine - 功能规格

> **层级**: L3 - 规格定义（How）  
> **优先级**: P1 - 核心功能  
> **状态**: ✅ 已实现  
> **关联**: [产品愿景](../../01-strategy-and-vision/product-vision.md) | [业务流程](../../02-business-and-domain/business-processes/workflow.md)

## 功能概述

### 功能描述
捕获屏幕（区域/窗口/全屏）、麦克风音频，生成合规视频文件（MP4/MOV）。

### 业务背景
- **需求来源**：P1 核心功能，构成可用产品的基础
- **解决的核心问题**：用户需要简单可靠的屏幕录制能力
- **预期效果**：一键开始录制，生成专业品质视频

## 功能范围

### 包含范围
- ✅ 全屏录制 `已实现`
- ✅ 窗口录制 `已实现`
- ✅ 区域录制 `已实现`
- ✅ 麦克风音频录制 `已实现`
- ✅ 录制暂停/恢复 `已实现`
- ✅ 录制配置（FPS、分辨率） `已实现`

### 不包含范围（后续迭代）
- ⏳ 系统音频录制（P3）
- ⏳ 摄像头叠加（P3）
- ⏳ 实时增强效果

## 用户故事

### US-1：选择录制区域
**作为** 用户  
**我希望** 选择录制范围（全屏/窗口/区域）  
**以便** 只录制需要的内容

**验收标准**：
- [x] 支持全屏模式选择
- [x] 支持窗口选择
- [x] 支持区域选择
- [ ] 区域选择支持拖拽调整 `待实现`

### US-2：开始/停止录制
**作为** 用户  
**我希望** 通过按钮或快捷键开始和停止录制  
**以便** 方便控制录制过程

**验收标准**：
- [x] 提供明显的开始/停止按钮
- [x] 启动时显示 "Starting..." 状态
- [ ] 支持全局快捷键（Cmd+Shift+R） `待实现`
- [x] 录制中显示时长指示器
- [x] 停止后自动保存文件

### US-3：录制麦克风音频
**作为** 用户  
**我希望** 同时录制我的声音  
**以便** 配合画面进行讲解

**验收标准**：
- [x] 支持配置麦克风设备
- [ ] 支持音量调节 `待实现`
- [ ] 支持静音开关 `待实现`
- [x] 音视频同步

### US-4：暂停/恢复录制
**作为** 用户  
**我希望** 中途暂停录制  
**以便** 处理意外情况后继续

**验收标准**：
- [x] 暂停功能正常
- [x] 恢复后无缝衔接
- [x] 暂停时间不计入总时长

## 业务规则

### BR-1：权限检查
- [x] 录制前必须获取屏幕录制权限
- [x] 权限被拒绝时提供引导说明（打开系统设置）
- [ ] 麦克风使用需要单独授权 `待实现`

### BR-2：长时录制
- [ ] 使用环形磁盘缓存避免内存溢出 `待实现`
- [ ] 每 5 分钟自动保存检查点 `待实现`
- [ ] 磁盘空间 < 500MB 时自动停止 `待实现`

### BR-3：异常处理
- [x] 权限错误时提示用户
- [ ] 设备断开时优雅降级 `待实现`
- [ ] 应用崩溃后可恢复临时文件 `待实现`

## 接口定义

### 核心协议

```swift
protocol CaptureEngineProtocol: AnyObject, Sendable {
    var isRecording: Bool { get async }
    var duration: TimeInterval { get async }
    
    func requestPermission() async -> Bool
    func startCapture(config: CaptureConfig) async throws
    func pauseCapture() async
    func resumeCapture() async
    func stopCapture() async -> RecordingSession
}
```

### 配置模型

```swift
struct CaptureConfig: Equatable {
    let source: CaptureSource
    let audioDevice: AudioDevice?
    let fps: Int
    let resolution: Resolution  // 默认使用屏幕实际像素分辨率
}

enum CaptureSource: Equatable {
    case fullScreen(displayID: CGDirectDisplayID)
    case window(windowID: CGWindowID)
    case region(rect: CGRect)
}

struct RecordingSession: Equatable {
    let outputURL: URL
    let duration: TimeInterval
    let cursorTrackSession: CursorTrackSession?  // 光标追踪数据（用于导出时增强）
}
```

> **实现说明**：
> - 默认分辨率使用屏幕实际像素（`screen.frame × backingScaleFactor`），确保光标位置精确匹配
> - 录制时自动启动 `MouseTrackerManager` 追踪鼠标事件
> - 停止录制时返回 `CursorTrackSession`，用于导出时渲染点击高亮

### 错误类型

```swift
enum RecordingError: LocalizedError, Equatable {
    case permissionDenied
    case deviceUnavailable(deviceType: String)
    case captureSessionFailed(underlying: Error)
    case diskFull
    case encodingFailed(reason: String)
}
```

## 实现状态

### 已完成
| 组件 | 文件 | 测试 |
|------|------|------|
| CaptureEngineProtocol | `Domain/Protocols/` | ✅ |
| CaptureConfig | `Domain/Models/` | ✅ 7 tests |
| RecordingError | `Domain/Models/` | ✅ 5 tests |
| RecordingSession | `Domain/Models/` | ✅ 3 tests |
| ScreenCaptureEngine | `Infrastructure/` | ✅ 2 tests |
| RecordingViewModel | `ViewModels/` | ✅ 12 tests |
| RecordingView | `Views/` | ✅ |

### 测试覆盖
- **总测试数**: 29 tests
- **通过率**: 100%

## 验收标准

### 功能验收
- [x] 支持区域/窗口/全屏三种模式
- [ ] 音视频同步（偏差 < 50ms） `需验证`
- [ ] 生成的文件可在 QuickTime/VLC 播放 `需验证`
- [x] 暂停/恢复功能正常

### 性能要求
- **CPU 占用**：< 30%（M1 芯片，1080p@30fps）`需验证`
- **内存占用**：< 300MB `需验证`
- **启动延迟**：< 500ms `需验证`

## 相关文档

- [UI 规格](./ui-spec.md)
- [技术设计](./technical-spec.md)
- [业务流程](../../02-business-and-domain/business-processes/workflow.md)
