# Export Engine - 功能规格

> **层级**: L3 - 规格定义（How）  
> **优先级**: P1 - 核心功能  
> **状态**: ✅ 已实现  
> **关联**: [产品愿景](../../01-strategy-and-vision/product-vision.md)

## 功能概述

### 功能描述
导出 MP4/MOV 视频文件，支持多种预设配置，满足不同平台需求。

### 业务背景
- **需求来源**：P1 核心功能，录制完成后必须导出
- **解决的核心问题**：用户需要将录制内容导出为可分享的格式
- **预期效果**：一键导出，适配各平台

## 功能范围

### 包含范围
- ✅ MP4/MOV 格式导出 `已实现`
- ✅ 预设管理（Web/高清/社媒） `已实现`
- ✅ 自定义分辨率和帧率 `已实现`
- ✅ 导出进度显示 `已实现`
- ✅ 取消导出 `已实现`
- ✅ 选择保存位置 `已实现`
- ✅ 导出成功提示（Show in Finder） `已实现`

### 不包含范围（后续迭代）
- ⏳ GIF 导出（P3）
- ⏳ 批量导出（P3）
- ⏳ 云端上传（P3）

## 用户故事

### US-1：选择预设导出
**作为** 用户  
**我希望** 选择预设快速导出  
**以便** 不需要了解技术参数

**验收标准**：
- [x] 提供 Web、高清、社媒等预设
- [x] 预设显示信息（分辨率、格式）
- [x] 点击导出弹出保存对话框
- [x] 导出成功后显示成功界面
- [x] 支持 "Show in Finder" 打开文件位置

### US-2：自定义导出参数
**作为** 进阶用户  
**我希望** 自定义导出参数  
**以便** 满足特殊需求

**验收标准**：
- [x] 支持自定义分辨率
- [x] 支持自定义帧率（15-60fps）
- [x] 支持自定义码率
- [ ] 保存为自定义预设 `待实现`

### US-3：查看导出进度
**作为** 用户  
**我希望** 看到导出进度  
**以便** 了解剩余时间

**验收标准**：
- [x] 显示进度百分比
- [ ] 显示预估剩余时间 `待实现`
- [x] 支持取消导出
- [ ] 后台导出时显示通知 `待实现`

## 预设配置

| 预设名称 | 分辨率 | FPS | 码率 | 格式 | 状态 |
|----------|--------|-----|------|------|------|
| Web | 1920×1080 | 30 | 8Mbps | MP4 | ✅ |
| High Quality | 3840×2160 | 60 | 25Mbps | MOV | ✅ |
| Social | 1080×1080 | 30 | 6Mbps | MP4 | ✅ |
| Vertical | 1080×1920 | 30 | 8Mbps | MP4 | ✅ |
| Compact | 1280×720 | 30 | 4Mbps | MP4 | ✅ |

## 接口定义

### 核心协议

```swift
protocol ExportEngineProtocol: AnyObject, Sendable {
    var progress: Double { get async }
    var isExporting: Bool { get async }
    
    func export(session: RecordingSession, preset: ExportPreset, to url: URL) async throws
    func cancel() async
}
```

### 预设模型

```swift
struct ExportPreset: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let resolution: Resolution
    let fps: Int
    let bitrate: Int
    let format: ExportFormat
    let isBuiltIn: Bool
}

enum ExportFormat: String, Codable, CaseIterable {
    case mp4
    case mov
}
```

### 错误类型

```swift
enum ExportError: LocalizedError, Equatable {
    case sessionNotFound
    case exportFailed(reason: String)
    case cancelled
    case invalidPreset
}
```

## 实现状态

### 已完成
| 组件 | 文件 | 测试 |
|------|------|------|
| ExportEngineProtocol | `Domain/Protocols/` | ✅ |
| ExportPreset | `Domain/Models/` | ✅ 6 tests |
| ExportError | `Domain/Models/` | ✅ 3 tests |
| ExportEngine | `Infrastructure/` | ✅ |
| ExportViewModel | `ViewModels/` | ✅ 6 tests |
| ExportView | `Views/` | ✅ |

### 测试覆盖
- **总测试数**: 15 tests
- **通过率**: 100%

## 验收标准

### 功能验收
- [x] 支持 MP4/MOV 格式
- [x] 预设导出正常工作
- [x] 进度显示
- [x] 取消导出

### 性能要求
- **导出速度**：≥ 2x 实时（1080p@30fps）`需验证`
- **CPU 占用**：< 80%（导出时）`需验证`
- **取消响应**：< 1 秒 `需验证`

## 相关文档

- [UI 规格](./ui-spec.md)
- [技术设计](./technical-spec.md)
