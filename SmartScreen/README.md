# SmartScreen

> Screen Studio 的开源平替，专为 Mac 用户打造的本地智能录屏工具

## ✨ 功能特性

- **🎬 屏幕录制** - 全屏录制，支持系统音频和麦克风
- **🎯 光标增强** - 点击高亮动画，让操作更清晰
- **🔍 Auto Zoom** - 智能识别点击区域自动放大，突出操作重点
- **📤 视频导出** - 支持多种预设，一键导出高质量视频

## 系统要求

- macOS 14.0+ (Sonoma)
- Apple Silicon (M1/M2/M3/M4) 或 Intel Mac
- Xcode 15.0+

## 快速开始

### 1. 构建应用

```bash
cd SmartScreen
./scripts/build-app.sh
```

首次构建会提示创建代码签名证书，按照提示操作即可。

### 2. 运行应用

```bash
open SmartScreen.app
```

### 3. 权限设置

首次运行需要授权：
- **屏幕录制权限**：系统偏好设置 → 隐私与安全性 → 屏幕录制
- **麦克风权限**：系统偏好设置 → 隐私与安全性 → 麦克风
- **辅助功能权限**：系统偏好设置 → 隐私与安全性 → 辅助功能（用于鼠标跟踪）

### 4. 运行测试

```bash
swift test
```

## 使用指南

### 录制

1. 点击 **Start Recording** 开始录制
2. 进行屏幕操作（点击会被自动记录）
3. 点击 **Stop Recording** 结束录制

### 导出

1. 录制完成后点击 **Export**
2. 配置导出选项：
   - **Export Preset**: 选择画质预设（Web/HD/4K）
   - **Cursor Enhancement**: 开启点击高亮
   - **Auto Zoom**: 开启智能缩放
     - Follow Cursor: 游标跟随模式
     - Highlight Scale: 高亮放大比例
3. 点击 **Export** 保存视频

## 项目结构

```
SmartScreen/
├── Package.swift              # Swift Package 配置
├── scripts/
│   └── build-app.sh          # 构建脚本
├── Sources/
│   ├── App/                   # 应用入口
│   ├── Core/                  # 核心模块
│   └── Features/              # 功能模块
│       ├── Recording/         # 录屏功能
│       ├── Export/            # 导出功能
│       ├── CursorEnhancement/ # 光标增强
│       └── AutoZoom/          # 智能缩放
└── Tests/
    ├── Fixtures/              # 测试夹具
    └── UnitTests/             # 单元测试
```

## 技术栈

| 技术 | 用途 |
|------|------|
| Swift 5.9+ | 编程语言 |
| SwiftUI | UI 框架 |
| @Observable | 状态管理 |
| ScreenCaptureKit | 屏幕捕获 |
| AVFoundation | 音视频处理 |
| Core Graphics | 图像渲染 |

## 功能状态

| 功能 | 状态 |
|------|------|
| 屏幕录制 | ✅ 已实现 |
| 音频录制 | ✅ 已实现 |
| 视频导出 | ✅ 已实现 |
| 光标增强 | ✅ 已实现 |
| Auto Zoom | ✅ 已实现 (v3.1) |
| 实时预览 | ⏳ 待实现 |
| 时间轴编辑 | ⏳ 待实现 |

## 开发规范

- **架构**: 分层架构 (Presentation → Domain → Infrastructure)
- **测试**: TDD + Given-When-Then 结构
- **提交**: Semantic commit messages

详见 [knowledge-base/04-AI-assets/AI-coding/rules/](../knowledge-base/04-AI-assets/AI-coding/rules/)

## License

MIT
